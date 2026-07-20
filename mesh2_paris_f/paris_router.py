from migen import *
from litex.soc.interconnect import stream
from migen.genlib.roundrobin import RoundRobin

# Constantes para indexação das portas (Igual ao projeto ParIS)
PORT_L = 0  # Local
PORT_N = 1  # Norte
PORT_E = 2  # Leste
PORT_S = 3  # Sul
PORT_W = 4  # Oeste

class ParISRouterMigen(Module):
    def __init__(self, x_id, y_id, data_width=32, fifo_depth=4):
        self.x_id = x_id
        self.y_id = y_id
        
        # Definição do layout do link (Flit contendo dados + controle bop/eop)
        # BOP = Begin of Packet (Início), EOP = End of Packet (Fim)
        flit_layout = [
            ("data",   data_width),
            ("dest_x", 4),
            ("dest_y", 4),
            ("bop",    1),
            ("eop",    1),
        ]
        
        # 5 Portas Físicas de Entrada (Sinks) e 5 de Saída (Sources)
        self.sink_ports   = [stream.Endpoint(flit_layout) for _ in range(5)]
        self.source_ports = [stream.Endpoint(flit_layout) for _ in range(5)]
        
        # =====================================================================
        # 1. CANAIS DE ENTRADA (Equivalente ao Xin.vhd + ifc.vhd + fifo.vhd)
        # =====================================================================
        # Instancia uma FIFO síncrona para cada uma das 5 portas de entrada
        input_fifos = []
        for i in range(5):
            fifo = stream.SyncFIFO(flit_layout, depth=fifo_depth)
            self.submodules += fifo
            input_fifos.append(fifo)
            # Conecta a entrada física do roteador direto na entrada da FIFO
            self.comb += self.sink_ports[i].connect(fifo.sink)

        # =====================================================================
        # 2. ALGORITMO DE ROTEAMENTO XY (Equivalente ao ic.vhd + routing_xy.vhd)
        # =====================================================================
        # Matriz de requisições: req[porta_saida][porta_entrada]
        req_matrix = [[Signal() for _ in range(5)] for _ in range(5)]
        
        for in_port in range(5):
            fifo = input_fifos[in_port]
            
            # Atalhos para os sinais de controle da FIFO de entrada
            Xdest = fifo.source.dest_x
            Ydest = fifo.source.dest_y
            rok   = fifo.source.valid # FIFO não está vazia (Read OK)
            
            # Lógica combinacional do Algoritmo XY
            self.comb += [
                If(rok,
                    # Se Xdest for diferente do ID deste roteador, move no eixo X
                    If(Xdest > x_id, req_matrix[PORT_E][in_port].eq(1)),   # Vai para Leste
                    If(Xdest < x_id, req_matrix[PORT_W][in_port].eq(1)),   # Vai para Oeste
                    # Se Xdest for igual, avalia o eixo Y
                    If(Xdest == x_id,
                        If(Ydest < y_id,  req_matrix[PORT_N][in_port].eq(1)), # Vai para Norte (Y cresce p/ baixo)
                        If(Ydest > y_id,  req_matrix[PORT_S][in_port].eq(1)), # Vai para Sul
                        If(Ydest == y_id, req_matrix[PORT_L][in_port].eq(1))  # Chegou ao destino local!
                    )
                )
            ]

        # =====================================================================
        # 3. ARBITRAGEM ROUND-ROBIN E MATRIZ CROSSBAR (Xout.vhd + arb_rr.vhd + X.vhd)
        # =====================================================================
        for out_port in range(5):
            # Coleta todas as requisições destinadas a esta porta de saída específica
            port_requests = [req_matrix[out_port][in_port] for in_port in range(5)]
            
            # Instancia o módulo nativo de arbitragem RoundRobin do Migen
            arbiter = RoundRobin(5)
            self.submodules += arbiter
            
            # Alimenta o árbitro com as requisições pendentes
            self.comb += arbiter.request.eq(Cat(*port_requests))
            
            # Mux Crossbar: Seleciona os dados do canal vencedor para colocar na saída
            source = self.source_ports[out_port]
            
            # Lógica de seleção baseada no encoder do árbitro
            cases = {}
            for in_port in range(5):
                fifo = input_fifos[in_port]
                # Se o canal de entrada 'in_port' ganhar a arbitragem, conecta os fios
                cases[in_port] = [
                    source.data.eq(fifo.source.data),
                    source.dest_x.eq(fifo.source.dest_x),
                    source.dest_y.eq(fifo.source.dest_y),
                    source.bop.eq(fifo.source.bop),
                    source.eop.eq(fifo.source.eop),
                    # O sinal 'valid' da saída depende do dado estar válido na FIFO
                    source.valid.eq(fifo.source.valid),
                    # O sinal 'ready' (ack) da FIFO só bate se a saída aceitar o flit
                    fifo.source.ready.eq(source.ready & (arbiter.grant == in_port))
                ]
                
            # Caso ninguém esteja requisitando a porta de saída, ela fica ociosa
            cases["default"] = [
                source.valid.eq(0),
            ]
            
            # Aplica o chaveamento da matriz (Mux)
            self.comb += Case(arbiter.grant, cases)
