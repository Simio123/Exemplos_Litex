# =====================================================================
# router.py — Roteador NoC adaptado nativamente para ParIS/LiteX Stream
# =====================================================================

from functools import reduce
from operator import or_
from migen import *
from litex.soc.interconnect import stream
from migen.genlib.roundrobin import RoundRobin
from litex.soc.interconnect.csr import CSRStorage, CSRStatus, CSR, AutoCSR

# Constantes para indexação das portas do ParIS
PORT_L = 0  # Local
PORT_N = 1  # Norte
PORT_E = 2  # Leste
PORT_S = 3  # Sul
PORT_W = 4  # Oeste

def get_flit_layout(dw=32):
    """Retorna o layout padrão de Flits do ParIS"""
    return [
        ("data",   dw),
        ("dest_x", 4),
        ("dest_y", 4),
        ("bop",    1),
        ("eop",    1),
    ]

# =====================================================================
# ParISRouterMigen — Roteador Principal
# =====================================================================
class ParISRouterMigen(Module):
    def __init__(self, x_id, y_id, data_width=32, fifo_depth=4):
        self.x_id = x_id
        self.y_id = y_id
        
        flit_layout = get_flit_layout(data_width)
        
        self.sink_ports   = [stream.Endpoint(flit_layout) for _ in range(5)]
        self.source_ports = [stream.Endpoint(flit_layout) for _ in range(5)]
        
        # 1. CANAIS DE ENTRADA
        input_fifos = []
        for i in range(5):
            fifo = stream.SyncFIFO(flit_layout, depth=fifo_depth)
            self.submodules += fifo
            input_fifos.append(fifo)
            self.comb += self.sink_ports[i].connect(fifo.sink)

        # 2. ALGORITMO DE ROTEAMENTO XY
        req_matrix = [[Signal() for _ in range(5)] for _ in range(5)]
        
        for in_port in range(5):
            fifo = input_fifos[in_port]
            Xdest = fifo.source.dest_x
            Ydest = fifo.source.dest_y
            rok   = fifo.source.valid 
            
            self.comb += [
                If(rok,
                    If(Xdest > x_id, req_matrix[PORT_E][in_port].eq(1)),
                    If(Xdest < x_id, req_matrix[PORT_W][in_port].eq(1)),
                    If(Xdest == x_id,
                        If(Ydest < y_id,  req_matrix[PORT_N][in_port].eq(1)),
                        If(Ydest > y_id,  req_matrix[PORT_S][in_port].eq(1)),
                        If(Ydest == y_id, req_matrix[PORT_L][in_port].eq(1))
                    )
                )
            ]

        # 3. ARBITRAGEM ROUND-ROBIN E MATRIZ CROSSBAR
        for out_port in range(5):
            port_requests = [req_matrix[out_port][in_port] for in_port in range(5)]
            
            arbiter = RoundRobin(5)
            self.submodules += arbiter
            self.comb += arbiter.request.eq(Cat(*port_requests))
            
            source = self.source_ports[out_port]
            
            cases = {}
            for in_port in range(5):
                fifo = input_fifos[in_port]
                cases[in_port] = [
                    source.data.eq(fifo.source.data),
                    source.dest_x.eq(fifo.source.dest_x),
                    source.dest_y.eq(fifo.source.dest_y),
                    source.bop.eq(fifo.source.bop),
                    source.eop.eq(fifo.source.eop),
                    source.valid.eq(fifo.source.valid),
                    fifo.source.ready.eq(source.ready & (arbiter.grant == in_port))
                ]
                
            cases["default"] = [source.valid.eq(0)]
            self.comb += Case(arbiter.grant, cases)

# Renomeia para manter a compatibilidade de nomes com o MeshTile
Router = ParISRouterMigen

# =====================================================================
# NoCInterface — CSR para a CPU
# =====================================================================
class NoCInterface(Module, AutoCSR):
    def __init__(self, dw=32):
        self.tx_dest = CSRStorage(4,  name="tx_dest")
        self.tx_data = CSRStorage(dw, name="tx_data")
        self.tx_send = CSR(name="tx_send")  
        self.tx_busy = CSRStatus(1,   name="tx_busy")

        self.rx_data  = CSRStatus(dw, name="rx_data")
        self.rx_valid = CSRStatus(1,  name="rx_valid")
        self.rx_ack   = CSR(name="rx_ack")  

        layout = get_flit_layout(dw)
        self.to_router   = stream.Endpoint(layout)
        self.from_router = stream.Endpoint(layout)

        # ---- TX ----
        tx_pending = Signal()
        self.sync += [
            If(self.tx_send.re,
                tx_pending.eq(1)
            ).Elif(self.to_router.ready & self.to_router.valid,
                tx_pending.eq(0)
            )
        ]
        self.comb += [
            self.to_router.data.eq(self.tx_data.storage),
            self.to_router.dest_x.eq(self.tx_dest.storage[0:2]),
            self.to_router.dest_y.eq(self.tx_dest.storage[2:4]),
            self.to_router.bop.eq(1), # Flit único é sempre início...
            self.to_router.eop.eq(1), # ...e fim do pacote
            self.to_router.valid.eq(tx_pending),
            self.tx_busy.status.eq(tx_pending),
        ]

        # ---- RX ----
        rx_pending = Signal()
        rx_buf = Signal(dw)
        
        self.comb += self.from_router.ready.eq(~rx_pending)
        
        self.sync += [
            If(self.from_router.valid & self.from_router.ready,
                rx_pending.eq(1),
                rx_buf.eq(self.from_router.data),
            ).Elif(self.rx_ack.re,
                rx_pending.eq(0)
            )
        ]
        
        self.comb += [
            self.rx_valid.status.eq(rx_pending),
            self.rx_data.status.eq(rx_buf),
        ]

# =====================================================================
# LocalMux — Compartilhamento da Porta Local
# =====================================================================
class LocalMux(Module):
    def __init__(self, num_cores=2, dw=32):
        assert num_cores in (1, 2), "Suporta 1 ou 2 núcleos"
        self.num_cores = num_cores

        layout = get_flit_layout(dw)
        self.core_to_router   = [stream.Endpoint(layout) for _ in range(num_cores)]
        self.core_from_router = [stream.Endpoint(layout) for _ in range(num_cores)]

        self.to_router   = stream.Endpoint(layout)
        self.from_router = stream.Endpoint(layout)

        # ---- TX ----
        already = None
        grants = []
        for i in range(num_cores):
            c = self.core_to_router[i]
            grant = c.valid if already is None else (c.valid & ~already)
            already = c.valid if already is None else (already | c.valid)
            grants.append(grant)

        stmt = None
        for i, c in enumerate(self.core_to_router):
            body = [
                self.to_router.data.eq(c.data),
                self.to_router.dest_x.eq(c.dest_x),
                self.to_router.dest_y.eq(c.dest_y),
                self.to_router.bop.eq(c.bop),
                self.to_router.eop.eq(c.eop),
            ]
            stmt = If(grants[i], *body) if stmt is None else stmt.Elif(grants[i], *body)
        if stmt is not None:
            self.comb += stmt

        self.comb += self.to_router.valid.eq(reduce(or_, [c.valid for c in self.core_to_router]))
        for i, c in enumerate(self.core_to_router):
            self.comb += c.ready.eq(grants[i] & self.to_router.ready)

        # ---- RX ----
        if num_cores == 1:
            self.comb += self.from_router.connect(self.core_from_router[0])
        else:
            core_sel = self.from_router.data[dw - 1]
            for i, c in enumerate(self.core_from_router):
                self.comb += [
                    c.data.eq(self.from_router.data),
                    c.dest_x.eq(self.from_router.dest_x),
                    c.dest_y.eq(self.from_router.dest_y),
                    c.bop.eq(self.from_router.bop),
                    c.eop.eq(self.from_router.eop),
                    c.valid.eq(self.from_router.valid & (core_sel == i)),
                ]
            self.comb += If(core_sel == 0,
                self.from_router.ready.eq(self.core_from_router[0].ready)
            ).Else(
                self.from_router.ready.eq(self.core_from_router[1].ready)
            )
