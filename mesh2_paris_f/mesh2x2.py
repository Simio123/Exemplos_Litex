# =====================================================================
# mesh2x2.py — Malha (mesh) NoC 2x2 baseada no SoCPuro original
# =====================================================================
#
# Estende noc.py para 4 nós (SoCs completos, cada um com sua CPU RISC-V
# "ibex") conectados por uma malha 2x2 de roteadores XY (router.py).
#
# Layout (x cresce p/ direita, y cresce p/ baixo):
#
#       x=0        x=1
#   y=0  N0 -----E/W----- N1
#         |                |
#        N/S              N/S
#         |                |
#   y=1  N2 -----E/W----- N3
#
# Cada nó fala com sua porta Local do roteador através da NoCInterface
# (periférico CSR), então o firmware em C de cada CPU pode enviar/receber
# pacotes para os outros 3 nós escrevendo/lendo alguns registradores.
#
# ---------------------------------------------------------------------

import os
from migen import *
from litex.build.generic_platform import *
from litex.build.sim import SimPlatform
from litex.build.sim.config import SimConfig
from litex.soc.integration.soc_core import *
from litex.soc.integration.builder import *
from litex.soc.interconnect import stream
from litex.soc.cores.uart import UART
from litex.soc.interconnect.csr import CSRStatus

# --- ANTIGO IMPORT ---
# from router import Router, NoCInterface

# --- NOVO IMPORT (Mantemos o NoCInterface antigo e trazemos o ParIS) ---
from router import NoCInterface
from paris_router import ParISRouterMigen
from litex.soc.integration.common import get_mem_data

# ---------------------------------------------------------------------
# PHY Falso para enganar a BIOS sem quebrar o simulador
# ---------------------------------------------------------------------
class DummyUARTPHY(Module):
    def __init__(self):
        self.sink   = stream.Endpoint([("data", 8)])
        self.source = stream.Endpoint([("data", 8)])
        
        self.comb += [
            self.sink.ready.eq(1),   
            self.source.valid.eq(0), 
        ]

# ---------------------------------------------------------------------
# 1. Posições dos 4 nós na malha e portas TCP da UART de cada um
# ---------------------------------------------------------------------
NODES = [
    dict(id=0, x=0, y=0, uart_port=5000), 
    dict(id=1, x=1, y=0, uart_port=None),
    dict(id=2, x=0, y=1, uart_port=None),
    dict(id=3, x=1, y=1, uart_port=None),
]

def node_at(x, y):
    for n in NODES:
        if n["x"] == x and n["y"] == y:
            return n
    return None

# ---------------------------------------------------------------------
# 2. Pinos virtuais: um clock + uma UART por nó (serial0..serial3)
# ---------------------------------------------------------------------
def make_io():
    return [
        ("sys_clk", 0, Pins(1)),
        ("serial", 0,
            Subsignal("source_valid", Pins(1)),
            Subsignal("source_ready", Pins(1)),
            Subsignal("source_data",  Pins(8)),
            Subsignal("sink_valid",   Pins(1)),
            Subsignal("sink_ready",   Pins(1)),
            Subsignal("sink_data",    Pins(8)),
        ),
    ]

class Platform(SimPlatform):
    def __init__(self):
        SimPlatform.__init__(self, "SIM", make_io())

# ---------------------------------------------------------------------
# 3. MeshNode — igual ao SoCPuro original, + roteador + interface CSR
# ---------------------------------------------------------------------
class MeshNode(SoCCore):
    def __init__(self, platform, node, sys_clk_freq, rom_init=None):
        x, y = node["x"], node["y"]

        uart_kwargs = dict(uart_name="sim") if node["id"] == 0 else dict(with_uart=False)

        SoCCore.__init__(self, platform, clk_freq=sys_clk_freq,
            cpu_type               = "vexriscv",
            cpu_variant            = "minimal",
            ident                  = f"NoC Node x{x} y{y}",
            integrated_rom_size    = 0x10000, 
            integrated_main_ram_size = 0x4000,
            integrated_rom_init    = rom_init or [],
            **uart_kwargs,
        )
        
        if node["id"] != 0:
            self.submodules.uart_phy = DummyUARTPHY()
            self.submodules.uart = UART(self.uart_phy)
            self.irq.add("uart", use_loc_if_exists=True)

        self.submodules.noc = NoCInterface()
        self.noc_coords = CSRStatus(8, name="noc_coords", description="Y[7:4] X[3:0]")
        self.comb += self.noc_coords.status.eq((y << 4) | x)

        # ==============================================================
        # --- CÓDIGO ANTIGO COMENTADO (Roteador Original) ---
        # ==============================================================
        # self.submodules.router = Router(x, y)
        # self.comb += [
        #     self.router.local_in.valid.eq(self.noc.to_router.valid),
        #     self.router.local_in.data.eq(self.noc.to_router.data),
        #     self.router.local_in.dest_x.eq(self.noc.to_router.dest_x),
        #     self.router.local_in.dest_y.eq(self.noc.to_router.dest_y),
        #     self.noc.to_router.ready.eq(self.router.local_in.ready),
        #
        #     self.noc.from_router.valid.eq(self.router.local_out.valid),
        #     self.noc.from_router.data.eq(self.router.local_out.data),
        #     self.router.local_out.ready.eq(self.noc.from_router.ready),
        # ]

        # ==============================================================
        # --- NOVO CÓDIGO (Integração ParIS) ---
        # ==============================================================
        self.submodules.router = ParISRouterMigen(x_id=x, y_id=y, data_width=32, fifo_depth=4)
        PORT_L = 0 
        
        self.comb += [
            # Liga a CPU (noc.to_router) na entrada Local do ParIS (sink_ports[0])
            self.router.sink_ports[PORT_L].valid.eq(self.noc.to_router.valid),
            self.router.sink_ports[PORT_L].data.eq(self.noc.to_router.data),
            self.router.sink_ports[PORT_L].dest_x.eq(self.noc.to_router.dest_x),
            self.router.sink_ports[PORT_L].dest_y.eq(self.noc.to_router.dest_y),
            # Como a interface da CPU só manda 1 pacote por vez, ele é sempre Início (bop) e Fim (eop)
            self.router.sink_ports[PORT_L].bop.eq(1), 
            self.router.sink_ports[PORT_L].eop.eq(1),
            self.noc.to_router.ready.eq(self.router.sink_ports[PORT_L].ready),

            # Liga a saída Local do ParIS (source_ports[0]) de volta na CPU (noc.from_router)
            self.noc.from_router.valid.eq(self.router.source_ports[PORT_L].valid),
            self.noc.from_router.data.eq(self.router.source_ports[PORT_L].data),
            self.router.source_ports[PORT_L].ready.eq(self.noc.from_router.ready),
        ]


# ---------------------------------------------------------------------
# 4. MeshTop — instancia os 4 nós e liga a malha (E/W e N/S)
# ---------------------------------------------------------------------
class MeshTop(Module):
    def __init__(self, platform, sys_clk_freq, rom_inits=None):
        rom_inits = rom_inits or {}
        self.clock_domains.cd_sys = ClockDomain()
        self.comb += self.cd_sys.clk.eq(platform.request("sys_clk"))

        self.nodes = {}
        for n in NODES:
            node_soc = MeshNode(platform, n, sys_clk_freq, rom_init=rom_inits.get(n["id"]))
            self.nodes[(n["x"], n["y"])] = node_soc
            setattr(self.submodules, f"node{n['id']}", node_soc)

        # Portas do ParIS
        PORT_N, PORT_E, PORT_S, PORT_W = 1, 2, 3, 4

        for n in NODES:
            x, y = n["x"], n["y"]
            router = self.nodes[(x, y)].router

            # ==============================================================
            # --- CÓDIGO ANTIGO COMENTADO (Roteador Original) ---
            # ==============================================================
            # east = node_at(x + 1, y)
            # if east:
            #     r_east = self.nodes[(x + 1, y)].router
            #     self.comb += router.ports_out["E"].connect_to(r_east.ports_in["W"])
            #     self.comb += r_east.ports_out["W"].connect_to(router.ports_in["E"])
            # else:
            #     self.comb += router.ports_out["E"].tie_off()
            #     self.comb += router.ports_in["E"].tie_off()
            #
            # south = node_at(x, y + 1)
            # if south:
            #     r_south = self.nodes[(x, y + 1)].router
            #     self.comb += router.ports_out["S"].connect_to(r_south.ports_in["N"])
            #     self.comb += r_south.ports_out["N"].connect_to(router.ports_in["S"])
            # else:
            #     self.comb += router.ports_out["S"].tie_off()
            #     self.comb += router.ports_in["S"].tie_off()
            #
            # if node_at(x - 1, y) is None:
            #     self.comb += router.ports_out["W"].tie_off()
            #     self.comb += router.ports_in["W"].tie_off()
            # if node_at(x, y - 1) is None:
            #     self.comb += router.ports_out["N"].tie_off()
            #     self.comb += router.ports_in["N"].tie_off()

            # ==============================================================
            # --- NOVO CÓDIGO (Integração ParIS) ---
            # ==============================================================
            east = node_at(x + 1, y)
            if east:
                r_east = self.nodes[(x + 1, y)].router
                self.comb += router.source_ports[PORT_E].connect(r_east.sink_ports[PORT_W])
                self.comb += r_east.source_ports[PORT_W].connect(router.sink_ports[PORT_E])
            else:
                self.comb += router.source_ports[PORT_E].ready.eq(1) # Se for borda, finge que sempre aceita
                self.comb += router.sink_ports[PORT_E].valid.eq(0)   # Nunca recebe lixo da borda

            south = node_at(x, y + 1)
            if south:
                r_south = self.nodes[(x, y + 1)].router
                self.comb += router.source_ports[PORT_S].connect(r_south.sink_ports[PORT_N])
                self.comb += r_south.source_ports[PORT_N].connect(router.sink_ports[PORT_S])
            else:
                self.comb += router.source_ports[PORT_S].ready.eq(1)
                self.comb += router.sink_ports[PORT_S].valid.eq(0)

            if node_at(x - 1, y) is None: # Borda Esquerda
                self.comb += router.source_ports[PORT_W].ready.eq(1)
                self.comb += router.sink_ports[PORT_W].valid.eq(0)
            if node_at(x, y - 1) is None: # Borda Topo
                self.comb += router.source_ports[PORT_N].ready.eq(1)
                self.comb += router.sink_ports[PORT_N].valid.eq(0)

# ---------------------------------------------------------------------
# 5. Fase 1 — gera o binário da APLICAÇÃO de cada nó isoladamente
# ---------------------------------------------------------------------
def build_node_software(node, sys_clk_freq, output_dir):
    platform = Platform()
    soc = MeshNode(platform, node, sys_clk_freq)
    builder = Builder(soc, output_dir=output_dir,
                       csr_csv=os.path.join(output_dir, "csr.csv"),
                       compile_software=True, compile_gateware=False)
    
    builder.add_software_package("noc_app", src_dir=os.path.abspath("noc_app"))
    builder.build(build=False, run=False)
    
    noc_app_bin = os.path.join(builder.software_dir, "noc_app", "noc_app.bin")
    bios_bin    = os.path.join(builder.software_dir, "bios", "bios.bin")
    return noc_app_bin, bios_bin

# ---------------------------------------------------------------------
# 6. Fase 2 — build final: gateware combinado com as 4 CPUs + malha
# ---------------------------------------------------------------------
def main():
    sys_clk_freq = int(10e6)

    rom_inits = {}
    for n in NODES:
        noc_app_bin, bios_bin = build_node_software(n, sys_clk_freq,
                                        output_dir=f"build/node{n['id']}_sw")
        rom_inits[n["id"]] = get_mem_data(noc_app_bin, endianness="little")

    platform = Platform()
    top = MeshTop(platform, sys_clk_freq, rom_inits=rom_inits)

    sim_config = SimConfig()
    sim_config.add_clocker("sys_clk", freq_hz=sys_clk_freq)
    for n in NODES:
        if n["uart_port"] is not None:
            sim_config.add_module("serial2tcp", "serial",
                                   args={"port": n["uart_port"]})

    print(f"\nSubindo a malha 2x2. Terminal do nó 0: telnet localhost {NODES[0]['uart_port']}\n")

    platform.build(top, sim_config=sim_config, run=True, trace=True, trace_fst=False)
    
    print("CPU reset:", hex(top.node0.cpu.reset_address))
    print("\nMalha 2x2 rodando! Terminal (nó 0, x=0 y=0):")
    print(f"  litex_term socket://127.0.0.1:{NODES[0]['uart_port']}")

if __name__ == "__main__":
    main()
