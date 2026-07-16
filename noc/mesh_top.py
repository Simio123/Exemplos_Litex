from migen import *
from litex.build.generic_platform import *
from litex.build.sim import SimPlatform
from litex.build.sim.config import SimConfig
from litex.soc.integration.soc_core import SoCCore
from litex.soc.integration.builder import Builder
from litex.soc.cores.uart import UART

from mesh_router import MeshRouter
from network_interface import NetworkInterface

# ---------- CRG local ----------
class CRG(Module):
    def __init__(self, clk):
        self.clock_domains.cd_sys = ClockDomain()
        self.comb += self.cd_sys.clk.eq(clk)
        self.comb += self.cd_sys.rst.eq(0)

# ---------- Plataforma virtual ----------
_io = [
    ("sys_clk", 0, Pins(1)),
]

for i in range(4):
    s_name = "serial" if i == 0 else f"serial{i}"
    _io.append(
        (s_name, 0,
            Subsignal("source_valid", Pins(1)),
            Subsignal("source_ready", Pins(1)),
            Subsignal("source_data",  Pins(8)),
            Subsignal("sink_valid",   Pins(1)),
            Subsignal("sink_ready",   Pins(1)),
            Subsignal("sink_data",    Pins(8)),
        )
    )

class Platform(SimPlatform):
    def __init__(self):
        SimPlatform.__init__(self, "SIM", _io)

# ---------- Nó da mesh ----------
class SoCNode(SoCCore):
    def __init__(self, platform, node_id, router_in, router_out, uart_pads):
        sys_clk_freq = int(1e6)
        
        SoCCore.__init__(self, platform, clk_freq=sys_clk_freq,
                         cpu_type="ibex",
                         ident=f"Node{node_id}",
                         with_uart=False, 
                         integrated_rom_size=0x8000,
                         integrated_main_ram_size=0x4000)

        self.add_uart(name="uart", uart_name="sim", uart_pads=uart_pads)
        self.submodules.network = NetworkInterface(router_in, router_out)
        self.add_constant("NODE_ID", node_id)

# ---------- Top Level ----------
class MeshTop(SoCCore):
    def __init__(self, platform):
        SoCCore.__init__(self, platform, clk_freq=int(1e6),
                         cpu_type=None,
                         with_uart=False,
                         with_timer=False,
                         with_ctrl=False)

        self.submodules.crg = CRG(platform.request("sys_clk"))
        
        self.submodules.router = MeshRouter(n=4)
        self.nodes = []
        for i in range(4):
            s_name = "serial" if i == 0 else f"serial{i}"
            pads = platform.request(s_name, 0)
            
            # ✅ ANTI-SEGFAULT: Força o Verilator a manter os pinos vivos
            for sig_name, sig in pads.flatten():
                sig.attr.add("keep")
            
            node = SoCNode(platform, i,
                           router_in=self.router.ports_out[i],
                           router_out=self.router.ports_in[i],
                           uart_pads=pads)
            
            node.finalize() 
            node.autocsr_exclude = list(node.__dict__.keys()) 

            setattr(self.submodules, f"node{i}", node)
            self.nodes.append(node)

# ---------- Main ----------
def main():
    platform = Platform()
    top = MeshTop(platform)

    sim_config = SimConfig()
    sim_config.add_clocker("sys_clk", freq_hz=int(1e6))
    
    for i in range(4):
        serial_name = "serial" if i == 0 else f"serial{i}"
        sim_config.add_module("serial2console", serial_name)

    builder = Builder(top, output_dir="build_mesh", csr_csv="csr_mesh.csv")
    builder.build(sim_config=sim_config, interactive=False, run=False)

if __name__ == "__main__":
    main()
