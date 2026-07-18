# =====================================================================
# router.py — Roteador NoC (Network-on-Chip) XY genérico, em Migen
# =====================================================================

from functools import reduce
from operator import or_
from migen import *

DIRS = ("N", "S", "E", "W", "L")
PRIORITY = ("L", "N", "S", "E", "W")


class Link:
    def __init__(self, dw=32, name=""):
        self.valid  = Signal(name=f"{name}_valid")
        self.ready  = Signal(name=f"{name}_ready")
        self.dest_x = Signal(2, name=f"{name}_dest_x")
        self.dest_y = Signal(2, name=f"{name}_dest_y")
        self.data   = Signal(dw, name=f"{name}_data")

    def connect_to(self, other):
        return [
            other.valid.eq(self.valid),
            self.ready.eq(other.ready),
            other.dest_x.eq(self.dest_x),
            other.dest_y.eq(self.dest_y),
            other.data.eq(self.data),
        ]

    def tie_off(self):
        return [self.valid.eq(0), self.ready.eq(1)]


class Router(Module):
    def __init__(self, x, y, dw=32):
        self.x, self.y = x, y

        self.ports_in  = {d: Link(dw, f"r{x}{y}_in_{d}")  for d in DIRS}
        self.ports_out = {d: Link(dw, f"r{x}{y}_out_{d}") for d in DIRS}

        self.local_in  = self.ports_in["L"]   
        self.local_out = self.ports_out["L"]  

        # ---- 1) Função de roteamento XY ----
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

        # ---- 2) Para cada SAÍDA: arbitragem e buffers registrados ----
        grants = {din: [] for din in DIRS}

        for dout in DIRS:
            out_link = self.ports_out[dout]
            reqs = [(din, self.ports_in[din], self.ports_in[din].valid & want[din][dout])
                    for din in PRIORITY]

            # Fios combinatórios internos da arbitragem
            comb_valid = Signal()
            comb_data  = Signal(dw)
            comb_dx    = Signal(2)
            comb_dy    = Signal(2)

            self.comb += comb_valid.eq(reduce(or_, [r[2] for r in reqs]))

            stmt = None
            for din, in_link, req in reqs:
                body = [
                    comb_data.eq(in_link.data),
                    comb_dx.eq(in_link.dest_x),
                    comb_dy.eq(in_link.dest_y),
                ]
                stmt = If(req, *body) if stmt is None else stmt.Elif(req, *body)
            if stmt is not None:
                self.comb += stmt

            # REGISTRADORES DE SAÍDA (Isolamento síncrono completo)
            reg_valid = Signal(name=f"r{x}{y}_{dout}_reg_valid")
            reg_data  = Signal(dw, name=f"r{x}{y}_{dout}_reg_data")
            reg_dx    = Signal(2, name=f"r{x}{y}_{dout}_reg_dx")
            reg_dy    = Signal(2, name=f"r{x}{y}_{dout}_reg_dy")

            # REGRA DE CONTROLE LOCAL:
            # O registrador avança se estiver vazio, ou se o nó vizinho estiver lendo-o agora.
            # No entanto, para fins de habilitar o ready das ENTRADAS, usaremos estritamente ~reg_valid
            # para cortar dependências circulares com o vizinho no mesmo ciclo.
            self.sync += [
                If(~reg_valid | out_link.ready,
                    reg_valid.eq(comb_valid),
                    reg_data.eq(comb_data),
                    reg_dx.eq(comb_dx),
                    reg_dy.eq(comb_dy)
                ).Elif(out_link.ready,
                    reg_valid.eq(0)
                )
            ]

            # Liga os registradores físicos para as portas externas da NoC
            self.comb += [
                out_link.valid.eq(reg_valid),
                out_link.data.eq(reg_data),
                out_link.dest_x.eq(reg_dx),
                out_link.dest_y.eq(reg_dy)
            ]

            # CORTE TOTAL DE LOOP: O grant avalia APENAS se o registrador interno local está livre.
            # Zero fios combinatórios vindos do vizinho entram neste cálculo.
            already = None
            for din, in_link, req in reqs:
                grant = req if already is None else (req & ~already)
                already = req if already is None else (already | req)
                
                # A entrada ganha direito de gravar se houver requisição e a saída local estiver vazia
                grants[din].append(grant & ~reg_valid)

        # ---- 3) ready de cada ENTRADA ----
        for din in DIRS:
            self.comb += self.ports_in[din].ready.eq(reduce(or_, grants[din]))


# =====================================================================
# NoCInterface — periférico mapeado em memória (CSR) para a CPU
# =====================================================================
from litex.soc.interconnect.csr import CSRStorage, CSRStatus, CSR, AutoCSR

# =====================================================================
# NoCInterface — periférico mapeado em memória (CSR) para a CPU
# =====================================================================
from litex.soc.interconnect.csr import CSRStorage, CSRStatus, CSR, AutoCSR

class NoCInterface(Module, AutoCSR):
    def __init__(self, dw=32):
        self.tx_dest = CSRStorage(4,  name="tx_dest")
        self.tx_data = CSRStorage(dw, name="tx_data")
        self.tx_send = CSR(name="tx_send")  
        self.tx_busy = CSRStatus(1,   name="tx_busy")

        self.rx_data  = CSRStatus(dw, name="rx_data")
        self.rx_valid = CSRStatus(1,  name="rx_valid")
        self.rx_ack   = CSR(name="rx_ack")  

        self.to_router   = Link(dw, "to_router")
        self.from_router = Link(dw, "from_router")

        # ---- Caminho de transmissão (TX) ----
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
            self.to_router.valid.eq(tx_pending),
            self.tx_busy.status.eq(tx_pending),
        ]

        # ---- Caminho de recepção (RX) ----
        rx_pending = Signal()
        rx_buf = Signal(dw)
        
        # Garante que o ready fique ativo de forma síncrona estável
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
