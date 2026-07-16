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
# IMPORTANTE — sobre o fluxo de build do LiteX:
# ---------------------------------------------------------------------
# O Builder do LiteX (a classe usada no noc.py original) foi desenhado
# em torno de UM SoCCore = UMA CPU = UM binário de BIOS por build. Ele
# não sabe, nativamente, compilar/linkar 4 BIOS diferentes para 4 CPUs
# dentro da mesma simulação Verilator.
#
# Para deixar isso funcionando de ponta a ponta você tem duas opções
# realistas:
#
#   (A) TESTAR O ROTEADOR ISOLADO (recomendado para começar)
#       Use router.py + test_router.py (já incluídos) para validar a
#       lógica de roteamento/arbitragem sem precisar compilar 4 CPUs.
#       É o que eu já fiz aqui antes de te mandar o código.
#
#   (B) SIMULAÇÃO COMPLETA COM AS 4 CPUS
#       Gere o software (BIOS) de cada nó separadamente (fase 1,
#       build_node_software() abaixo), depois construa o hardware
#       combinado uma única vez, apontando integrated_rom_init de cada
#       nó para o .bin já compilado daquele nó (fase 2, main()).
#       Isso evita pedir ao Builder para "adivinhar" múltiplos SoCs.
#
# O código abaixo implementa o padrão (B). Dependendo da versão exata
# do LiteX instalada na sua máquina, pequenos ajustes de API podem ser
# necessários (ex.: nome exato de kwargs do Builder) — o essencial,
# que é a malha/roteador/CSR, já foi testado e funciona.

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
from router import Router, NoCInterface

# ---------------------------------------------------------------------
# PHY Falso para enganar a BIOS sem quebrar o simulador
# ---------------------------------------------------------------------
class DummyUARTPHY(Module):
    def __init__(self):
        # A UART espera um fluxo de saída (sink) e entrada (source)
        self.sink   = stream.Endpoint([("data", 8)])
        self.source = stream.Endpoint([("data", 8)])
        
        self.comb += [
            self.sink.ready.eq(1),   # Finge que sempre pode receber (descarta o dado)
            self.source.valid.eq(0), # Finge que nunca tem nada a dizer para a CPU
        ]

# ---------------------------------------------------------------------
# 1. Posições dos 4 nós na malha e portas TCP da UART de cada um
# ---------------------------------------------------------------------
NODES = [
    dict(id=0, x=0, y=0, uart_port=5000),  # único nó com UART real (ver make_io)
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
        # LIMITAÇÃO CONHECIDA do simulador do LiteX: o módulo C
        # "serial2tcp" tem, no próprio código-fonte, uma comparação de
        # string fixa contra o nome literal "serial" (veja
        # litex/build/sim/core/modules/serial2tcp/serial2tcp.c). Isso
        # significa que só é possível ter UM UART "sim" real por
        # simulação — não dá pra ter serial0..serial3 nem
        # ("serial",0..3). Por isso só o nó (0,0) recebe um UART de
        # verdade aqui; os outros 3 continuam rodando (CPU + ROM + RAM
        # + roteador), só não têm terminal individual.
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

        # 1. Inicializa o SoC com a UART DESLIGADA
        SoCCore.__init__(self, platform, clk_freq=sys_clk_freq,
            cpu_type               = "vexriscv",
            cpu_variant            = "standard",
            ident                  = f"NoC Node x{x} y{y}",
            with_uart              = False,  # Impede o LiteX de gerar pinos bugados
            integrated_rom_size    = 0x10000, # AUMENTADO PARA 64KB PARA CABER O APP
            integrated_main_ram_size = 0x4000,
            integrated_rom_init    = rom_init or [],
        )

        # 2. Injetamos a UART manualmente!
        if node["id"] == 0:
            # O Nó 0 usa o terminal do simulador real
            self.add_uart(uart_name="sim")
        else:
            # Os Nós 1, 2 e 3 recebem nossa UART falsa.
            self.submodules.uart_phy = DummyUARTPHY()
            self.submodules.uart = UART(self.uart_phy)
            
            # Os CSRs são descobertos automaticamente pelo AutoCSR.
            # Precisamos apenas registrar a interrupção no controlador (IRQ):
            self.irq.add("uart", use_loc_if_exists=True)

        # Roteador deste nó + interface CSR para a CPU usar a malha
        self.submodules.router = Router(x, y)
        self.submodules.noc    = NoCInterface()

        # --- NOVO: Registrador que diz à CPU quem ela é! ---
        self.noc_coords = CSRStatus(8, name="noc_coords", description="Y[7:4] X[3:0]")
        self.comb += self.noc_coords.status.eq((y << 4) | x)
        # ---------------------------------------------------

        self.comb += [
            self.router.local_in.valid.eq(self.noc.to_router.valid),
            self.router.local_in.data.eq(self.noc.to_router.data),
            self.router.local_in.dest_x.eq(self.noc.to_router.dest_x),
            self.router.local_in.dest_y.eq(self.noc.to_router.dest_y),
            self.noc.to_router.ready.eq(self.router.local_in.ready),

            self.noc.from_router.valid.eq(self.router.local_out.valid),
            self.noc.from_router.data.eq(self.router.local_out.data),
            self.router.local_out.ready.eq(self.noc.from_router.ready),
        ]
        # OBS: como self.submodules.noc é um AutoCSR, o LiteX já descobre
        # e registra os CSRs dele automaticamente — nada mais a fazer aqui.

# ---------------------------------------------------------------------
# 4. MeshTop — instancia os 4 nós e liga a malha (E/W e N/S)
# ---------------------------------------------------------------------
class MeshTop(Module):
    def __init__(self, platform, sys_clk_freq, rom_inits=None):
        rom_inits = rom_inits or {}

        self.submodules.crg = CRG(platform.request("sys_clk"))

        self.nodes = {}
        for n in NODES:
            node_soc = MeshNode(platform, n, sys_clk_freq,
                                 rom_init=rom_inits.get(n["id"]))
            self.nodes[(n["x"], n["y"])] = node_soc
            setattr(self.submodules, f"node{n['id']}", node_soc)

        # ---- Conecta os links físicos da malha entre roteadores vizinhos ----
        for n in NODES:
            x, y = n["x"], n["y"]
            router = self.nodes[(x, y)].router

            east = node_at(x + 1, y)
            if east:
                r_east = self.nodes[(x + 1, y)].router
                self.comb += router.ports_out["E"].connect_to(r_east.ports_in["W"])
                self.comb += r_east.ports_out["W"].connect_to(router.ports_in["E"])
            else:
                self.comb += router.ports_out["E"].tie_off()
                self.comb += router.ports_in["E"].tie_off()

            south = node_at(x, y + 1)
            if south:
                r_south = self.nodes[(x, y + 1)].router
                self.comb += router.ports_out["S"].connect_to(r_south.ports_in["N"])
                self.comb += r_south.ports_out["N"].connect_to(router.ports_in["S"])
            else:
                self.comb += router.ports_out["S"].tie_off()
                self.comb += router.ports_in["S"].tie_off()

            # W e N de quem já tem vizinho a Leste/Sul cuidando da ligação
            # acima já foram amarrados pelo lado do vizinho; só falta
            # amarrar W/N de quem está na borda esquerda/topo.
            if node_at(x - 1, y) is None:
                self.comb += router.ports_out["W"].tie_off()
                self.comb += router.ports_in["W"].tie_off()
            if node_at(x, y - 1) is None:
                self.comb += router.ports_out["N"].tie_off()
                self.comb += router.ports_in["N"].tie_off()

# ---------------------------------------------------------------------
# 5. Fase 1 — gera o binário da APLICAÇÃO de cada nó isoladamente
# ---------------------------------------------------------------------
def build_node_software(node, sys_clk_freq, output_dir):
    """Builda SOMENTE o software de um nó (sem rodar simulação), para
    obter o .bin que vai virar o conteúdo inicial da ROM desse nó na
    malha combinada."""
    platform = Platform()
    soc = MeshNode(platform, node, sys_clk_freq)
    builder = Builder(soc, output_dir=output_dir,
                       csr_csv=os.path.join(output_dir, "csr.csv"),
                       compile_software=True, compile_gateware=False)
    
    # --- NOVO: Adiciona o nosso aplicativo ao build do LiteX ---
    builder.add_software_package("noc_app", src_dir=os.path.abspath("noc_app"))
    builder.build(build=False, run=False)
    
    # Retorna o nosso binário para ser injetado na ROM!
    return os.path.join(builder.software_dir, "noc_app", "noc_app.bin")

# ---------------------------------------------------------------------
# 6. Fase 2 — build final: gateware combinado com as 4 CPUs + malha
# ---------------------------------------------------------------------
def main():
    sys_clk_freq = int(10e6)

    # Fase 1: software de cada nó (gera noc_app.bin individualmente)
    rom_inits = {}
    for n in NODES:
        bios_bin = build_node_software(n, sys_clk_freq,
                                        output_dir=f"build/node{n['id']}_sw")
        rom_inits[n["id"]] = get_mem_data(bios_bin, endianness="little")

    # Fase 2: hardware combinado (as 4 CPUs + a malha, num único Verilator)
    platform = Platform()
    top = MeshTop(platform, sys_clk_freq, rom_inits=rom_inits)

    sim_config = SimConfig()
    sim_config.add_clocker("sys_clk", freq_hz=sys_clk_freq)
    for n in NODES:
        if n["uart_port"] is not None:
            sim_config.add_module("serial2tcp", "serial",
                                   args={"port": n["uart_port"]})

    platform.build(top, sim_config=sim_config, run=True)
    print("\nMalha 2x2 rodando! Terminal (nó 0, x=0 y=0):")
    print(f"  telnet localhost {NODES[0]['uart_port']}")
    print("\nOs nós 1-3 estão rodando (CPU+ROM+RAM+roteador) mas sem UART")
    print("individual nesta simulação (limitação do serial2tcp do LiteX,")
    print("veja o comentário em make_io()). Para observá-los, faça-os")
    print("enviar mensagens pela malha até o nó 0, que pode retransmitir")
    print("no seu UART.")

if __name__ == "__main__":
    main()
