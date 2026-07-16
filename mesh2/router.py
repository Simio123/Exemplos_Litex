# =====================================================================
# router.py — Roteador NoC (Network-on-Chip) XY genérico, em Migen
# =====================================================================
#
# Este módulo é independente de LiteX/SoC: é só a "malha" de verdade.
# Pode ser simulado isoladamente (veja test_router.py) e depois plugado
# em qualquer SoC através da NoCInterface (interface CSR para a CPU).
#
# Formato do pacote (1 flit = 1 pacote, sem fragmentação):
#   dest_x (2 bits), dest_y (2 bits) : coordenadas do roteador destino
#   data   (dw bits)                 : carga útil
#
# Cada roteador tem 5 portas: Norte, Sul, Leste, Oeste e Local (CPU).
# Roteamento XY: primeiro anda no eixo X (E/W) até dest_x==x,
#                depois anda no eixo Y (N/S) até dest_y==y,
#                quando dest_x==x e dest_y==y, entrega em Local.
#
# Isso garante ausência de deadlock (é uma rota determinística e sem
# ciclos de dependência entre canais), a um custo de não balancear
# carga entre caminhos alternativos — perfeitamente adequado para uma
# malha pequena (2x2) usada em ensino/pesquisa.

from functools import reduce
from operator import or_
from migen import *

DIRS = ("N", "S", "E", "W", "L")
# Ordem de prioridade fixa usada na arbitragem de cada porta de saída.
# ("L" primeiro: prioriza pacotes que ESTÃO chegando à CPU local, então
# eles não ficam presos atrás de tráfego de passagem.)
PRIORITY = ("L", "N", "S", "E", "W")


class Link:
    """Canal ponto-a-ponto (handshake valid/ready) entre dois roteadores,
    ou entre um roteador e a CPU (porta Local)."""

    def __init__(self, dw=32, name=""):
        self.valid  = Signal(name=f"{name}_valid")
        self.ready  = Signal(name=f"{name}_ready")
        self.dest_x = Signal(2, name=f"{name}_dest_x")
        self.dest_y = Signal(2, name=f"{name}_dest_y")
        self.data   = Signal(dw, name=f"{name}_data")

    def connect_to(self, other):
        """Liga fisicamente esta porta de SAÍDA à porta de ENTRADA `other`
        de um roteador vizinho (ou vice-versa)."""
        return [
            other.valid.eq(self.valid),
            self.ready.eq(other.ready),
            other.dest_x.eq(self.dest_x),
            other.dest_y.eq(self.dest_y),
            other.data.eq(self.data),
        ]

    def tie_off(self):
        """Usado quando não existe vizinho físico nessa direção
        (ex.: bordas da malha). A entrada nunca terá dado válido; a
        saída é sempre aceita (ready=1) para nunca travar o roteador."""
        return [self.valid.eq(0), self.ready.eq(1)]


class Router(Module):
    """Roteador XY de 5 portas para uma malha NxM.

    x, y: coordenadas deste roteador na malha (0-indexado).
    dw:   largura do payload de dados, em bits.
    """

    def __init__(self, x, y, dw=32):
        self.x, self.y = x, y

        self.ports_in  = {d: Link(dw, f"r{x}{y}_in_{d}")  for d in DIRS}
        self.ports_out = {d: Link(dw, f"r{x}{y}_out_{d}") for d in DIRS}

        # Atalhos para o nó (MeshNode) ligar a interface da CPU:
        self.local_in  = self.ports_in["L"]   # CPU  -> roteador (envio)
        self.local_out = self.ports_out["L"]  # roteador -> CPU  (recebimento)

        # ---- 1) Função de roteamento XY: pra cada ENTRADA, quais SAÍDAs
        #         ela deseja, dado seu cabeçalho (dest_x, dest_y). ----
        want = {}
        for din, link in self.ports_in.items():
            dx, dy = link.dest_x, link.dest_y
            here = (dx == x) & (dy == y)
            want[din] = {
                "L": here,
                "E": (~here) & (dx > x),
                "W": (~here) & (dx < x),
                "S": (~here) & (dx == x) & (dy > y),
                "N": (~here) & (dx == x) & (dy < y),
            }

        # ---- 2) Para cada SAÍDA: arbitragem de prioridade fixa entre
        #         todas as entradas que a desejam neste ciclo, e mux
        #         dos dados/cabeçalho do vencedor. ----
        # grants[din] acumula, por entrada, a condição de "eu ganhei
        # alguma saída neste ciclo" -> usado depois para dirigir ready.
        grants = {din: [] for din in DIRS}

        for dout in DIRS:
            out_link = self.ports_out[dout]
            reqs = [(din, self.ports_in[din], self.ports_in[din].valid & want[din][dout])
                    for din in PRIORITY]

            # out.valid = OR de todos os pedidos para esta saída
            self.comb += out_link.valid.eq(reduce(or_, [r[2] for r in reqs]))

            # Mux (If/Elif em ordem de prioridade) dos dados/cabeçalho
            stmt = None
            for din, in_link, req in reqs:
                body = [
                    out_link.data.eq(in_link.data),
                    out_link.dest_x.eq(in_link.dest_x),
                    out_link.dest_y.eq(in_link.dest_y),
                ]
                stmt = If(req, *body) if stmt is None else stmt.Elif(req, *body)
            if stmt is not None:
                self.comb += stmt

            # Quem ganhou esta saída = primeiro pedido ativo, na ordem
            # de prioridade (os de prioridade maior "bloqueiam" os
            # seguintes através do acumulador `already`).
            already = None
            for din, in_link, req in reqs:
                grant = req if already is None else (req & ~already)
                already = req if already is None else (already | req)
                grants[din].append(grant & out_link.ready)

        # ---- 3) ready de cada ENTRADA = OR de "ganhei alguma saída
        #         E essa saída pôde aceitar o dado" (mutuamente
        #         exclusivo por construção: cada entrada só deseja
        #         UMA saída por vez). ----
        for din in DIRS:
            self.comb += self.ports_in[din].ready.eq(reduce(or_, grants[din]))


# =====================================================================
# NoCInterface — periférico mapeado em memória (CSR) que dá à CPU
# acesso à porta Local do roteador.
# =====================================================================
#
# Requer litex (usa CSRStorage/CSRStatus/CSR/AutoCSR). Não é necessário
# para simular/testar o roteador isoladamente (por isso está importado
# aqui embaixo, separado do resto do arquivo).

from litex.soc.interconnect.csr import CSRStorage, CSRStatus, CSR, AutoCSR


class NoCInterface(Module, AutoCSR):
    """
    Registradores expostos à CPU (endereços definidos automaticamente
    pelo LiteX, disponíveis em C via generated/csr.h):

      tx_dest  : destino do próximo pacote -> bits[1:0]=x, bits[3:2]=y
      tx_data  : payload a enviar
      tx_send  : escrever 1 dispara o envio (pulso)
      tx_busy  : 1 enquanto o pacote ainda não foi aceito pelo roteador
                 (a CPU deve aguardar tx_busy==0 antes de enviar outro)

      rx_data  : payload do último pacote recebido
      rx_valid : 1 quando há um pacote esperando para ser lido
      rx_ack   : escrever 1 confirma a leitura e libera o roteador
                 para aceitar o próximo pacote
    """

    def __init__(self, dw=32):
        self.tx_dest = CSRStorage(4,  name="tx_dest", description="Destino {y[3:2], x[1:0]}")
        self.tx_data = CSRStorage(dw, name="tx_data", description="Dado a enviar")
        self.tx_send = CSR(name="tx_send")  # escrever 1 = pulso de envio
        self.tx_busy = CSRStatus(1,   name="tx_busy", description="1 = envio ainda pendente")

        self.rx_data  = CSRStatus(dw, name="rx_data",  description="Payload recebido")
        self.rx_valid = CSRStatus(1,  name="rx_valid", description="1 = há pacote esperando")
        self.rx_ack   = CSR(name="rx_ack")  # escrever 1 = confirma leitura

        # Ligações para a porta Local do roteador (o MeshNode conecta
        # self.to_router <-> router.local_in e
        # self.from_router <-> router.local_out).
        self.to_router   = Link(dw, "to_router")
        self.from_router = Link(dw, "from_router")

        # ---- Caminho de transmissão (TX) ----
        tx_pending = Signal()
        self.sync += [
            If(self.tx_send.re,
                tx_pending.eq(1)
            ).Elif(self.to_router.ready,
                tx_pending.eq(0)
            )
        ]
        self.comb += [
            self.to_router.data.eq(self.tx_data.storage),
            self.to_router.dest_x.eq(self.tx_dest.storage[0:2]),
            self.to_router.dest_y.eq(self.tx_dest.storage[2:4]),
            self.to_router.valid.eq(tx_pending),
            self.tx_busy.status.eq(tx_pending),
        ]

        # ---- Caminho de recepção (RX) ----
        rx_pending = Signal()
        rx_buf = Signal(dw)
        self.sync += [
            If(self.from_router.valid & ~rx_pending,
                rx_pending.eq(1),
                rx_buf.eq(self.from_router.data),
            ).Elif(self.rx_ack.re,
                rx_pending.eq(0)
            )
        ]
        self.comb += [
            self.from_router.ready.eq(~rx_pending),
            self.rx_valid.status.eq(rx_pending),
            self.rx_data.status.eq(rx_buf),
        ]
