# =====================================================================
# mesh2x2.py — Malha (mesh) NoC 2x2, com N núcleos RISC-V por roteador
# =====================================================================

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
from litex.soc.integration.common import get_mem_data

# Importa as constantes e módulos do router.py
from router import Router, NoCInterface, LocalMux, PORT_N, PORT_S, PORT_E, PORT_W, PORT_L

CORES_PER_TILE = 2  # <- núcleos por roteador. Suportado: 1 ou 2.

# ---------------------------------------------------------------------
# PHY Falso para os núcleos sem UART real
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
# 1. Posições dos 4 roteadores (tiles) na malha
# ---------------------------------------------------------------------
TILES = [
    dict(id=0, x=0, y=0),
    dict(id=1, x=1, y=0),
    dict(id=2, x=0, y=1),
    dict(id=3, x=1, y=1),
]

def tile_at(x, y):
    for t in TILES:
        if t["x"] == x and t["y"] == y:
            return t
    return None

CORES = []
_gid = 0
for t in TILES:
    for c in range(CORES_PER_TILE):
        CORES.append(dict(
            global_id=_gid,
            tile_x=t["x"], tile_y=t["y"], tile_id=t["id"],
            core_id=c,
            uart_port=5000 if _gid == 0 else None,
        ))
        _gid += 1

def core_by_global_id(gid):
    return CORES[gid]

# ---------------------------------------------------------------------
# 2. Pinos virtuais
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
# 3. MeshCore — um único SoC RISC-V
# ---------------------------------------------------------------------
class MeshCore(SoCCore):
    def __init__(self, platform, core, sys_clk_freq, rom_init=None):
        x, y, cid = core["tile_x"], core["tile_y"], core["core_id"]

        uart_kwargs = dict(uart_name="sim") if core["global_id"] == 0 else dict(with_uart=False)

        SoCCore.__init__(self, platform, clk_freq=sys_clk_freq,
            cpu_type               = "vexriscv",
            cpu_variant            = "minimal",
            ident                  = f"NoC x{x}y{y}c{cid}",
            integrated_rom_size    = 0x10000,
            integrated_main_ram_size = 0x4000,
            integrated_rom_init    = rom_init or [],
            **uart_kwargs,
        )

        if core["global_id"] != 0:
            self.submodules.uart_phy = DummyUARTPHY()
            self.submodules.uart = UART(self.uart_phy)
            self.irq.add("uart", use_loc_if_exists=True)

        self.submodules.noc = NoCInterface()

        self.noc_coords = CSRStatus(8, name="noc_coords", description="Y[7:4] X[3:0]")
        self.comb += self.noc_coords.status.eq((y << 4) | x)
        self.core_id_csr = CSRStatus(8, name="core_id", description="Indice deste nucleo no roteador")
        self.comb += self.core_id_csr.status.eq(cid)

# ---------------------------------------------------------------------
# 4. MeshTile — 1 Router + CORES_PER_TILE MeshCore + 1 LocalMux
# ---------------------------------------------------------------------
class MeshTile(Module):
    def __init__(self, platform, tile, sys_clk_freq, rom_inits, fifo_depth=4):
        x, y = tile["x"], tile["y"]

        # Adicionado o parâmetro fifo_depth para controle das buffers
        self.submodules.router = Router(x, y, fifo_depth=fifo_depth)
        self.submodules.mux = LocalMux(num_cores=CORES_PER_TILE)

        self.cores = []
        for c in CORES:
            if c["tile_x"] != x or c["tile_y"] != y:
                continue
            core_soc = MeshCore(platform, c, sys_clk_freq,
                                 rom_init=rom_inits.get(c["global_id"]))
            self.cores.append(core_soc)
            setattr(self.submodules, f"core{c['core_id']}", core_soc)

            i = c["core_id"]
            self.comb += core_soc.noc.to_router.connect(self.mux.core_to_router[i])
            self.comb += self.mux.core_from_router[i].connect(core_soc.noc.from_router)

        self.comb += self.mux.to_router.connect(self.router.sink_ports[PORT_L])
        self.comb += self.router.source_ports[PORT_L].connect(self.mux.from_router)

# ---------------------------------------------------------------------
# 5. MeshTop — instancia os 4 tiles e liga a malha (E/W e N/S)
# ---------------------------------------------------------------------
class MeshTop(Module):
    def __init__(self, platform, sys_clk_freq, rom_inits=None):
        rom_inits = rom_inits or {}
        self.clock_domains.cd_sys = ClockDomain()
        self.comb += self.cd_sys.clk.eq(platform.request("sys_clk"))

        self.tiles = {}
        for t in TILES:
            tile = MeshTile(platform, t, sys_clk_freq, rom_inits)
            self.tiles[(t["x"], t["y"])] = tile
            setattr(self.submodules, f"tile{t['id']}", tile)

        for t in TILES:
            x, y = t["x"], t["y"]
            router = self.tiles[(x, y)].router

            # LESTE (E)
            east = tile_at(x + 1, y)
            if east:
                r_east = self.tiles[(x + 1, y)].router
                self.comb += router.source_ports[PORT_E].connect(r_east.sink_ports[PORT_W])
                self.comb += r_east.source_ports[PORT_W].connect(router.sink_ports[PORT_E])
            else:
                self.comb += router.source_ports[PORT_E].ready.eq(1) 
                self.comb += router.sink_ports[PORT_E].valid.eq(0)   

            # SUL (S)
            south = tile_at(x, y + 1)
            if south:
                r_south = self.tiles[(x, y + 1)].router
                self.comb += router.source_ports[PORT_S].connect(r_south.sink_ports[PORT_N])
                self.comb += r_south.source_ports[PORT_N].connect(router.sink_ports[PORT_S])
            else:
                self.comb += router.source_ports[PORT_S].ready.eq(1)
                self.comb += router.sink_ports[PORT_S].valid.eq(0)

            # Bordas OESTE e NORTE
            if tile_at(x - 1, y) is None:
                self.comb += router.source_ports[PORT_W].ready.eq(1)
                self.comb += router.sink_ports[PORT_W].valid.eq(0)
            if tile_at(x, y - 1) is None:
                self.comb += router.source_ports[PORT_N].ready.eq(1)
                self.comb += router.sink_ports[PORT_N].valid.eq(0)

# ---------------------------------------------------------------------
# 6. Fase 1 — compilador C
# ---------------------------------------------------------------------
def build_core_software(core, sys_clk_freq, output_dir):
    platform = Platform()
    soc = MeshCore(platform, core, sys_clk_freq)
    builder = Builder(soc, output_dir=output_dir,
                       csr_csv=os.path.join(output_dir, "csr.csv"),
                       compile_software=True, compile_gateware=False)

    builder.add_software_package("noc_app", src_dir=os.path.abspath("noc_app"))
    builder.build(build=False, run=False)

    noc_app_bin = os.path.join(builder.software_dir, "noc_app", "noc_app.bin")
    return noc_app_bin

# ---------------------------------------------------------------------
# 7. Fase 2 — build final do sistema
# ---------------------------------------------------------------------
def main():
    sys_clk_freq = int(10e6)

    rom_inits = {}
    for c in CORES:
        noc_app_bin = build_core_software(
            c, sys_clk_freq,
            output_dir=f"build/tile{c['tile_id']}_core{c['core_id']}_sw")
        rom_inits[c["global_id"]] = get_mem_data(noc_app_bin, endianness="little")

    platform = Platform()
    top = MeshTop(platform, sys_clk_freq, rom_inits=rom_inits)

    sim_config = SimConfig()
    sim_config.add_clocker("sys_clk", freq_hz=sys_clk_freq)
    sim_config.add_module("serial2tcp", "serial", args={"port": 5000})

    print(f"\nSubindo a malha 2x2 com {CORES_PER_TILE} nucleo(s) por roteador "
          f"({len(CORES)} CPUs no total). Terminal do nucleo global 0: "
          f"telnet localhost 5000\n")

    platform.build(top, sim_config=sim_config, run=True, trace=True, trace_fst=False)

if __name__ == "__main__":
    main()
