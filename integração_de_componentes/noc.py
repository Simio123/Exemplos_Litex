# 1. IMPORTAÇÕES

from migen import *
# Migen: É a linguagem base. Permite escrever hardware usando Python.

from litex.build.generic_platform import *
# Contém as classes básicas para definir pinos físicos (I/O) de uma placa.

from litex.build.sim import SimPlatform
from litex.build.sim.config import SimConfig
# Ferramentas específicas para simulação. Permitem criar uma "placa virtual".

from litex.soc.integration.soc_core import *
from litex.soc.integration.builder import *
# O coração do LiteX (SoCCore) traz as CPUs e memórias. 
# O Builder converte o Python em Verilog e compila a BIOS em C.





# 2. PINOS VIRTUAIS (Interface com o Mundo)

# Criação de "pinos" que o simulador vai usar para falar com o chip.
_io = [
    # Pino de Clock: O relógio do sistema.
    ("sys_clk", 0, Pins(1)), 
    
    # Pinos da Porta Serial (UART): Usada para o terminal (Interface em fluxo/Stream).
    ("serial", 0,
        Subsignal("source_valid", Pins(1)), # Avisa que tem dado para enviar
        Subsignal("source_ready", Pins(1)), # Terminal avisa que pode receber
        Subsignal("source_data",  Pins(8)), # Os 8 bits do caractere enviado
        
        Subsignal("sink_valid",   Pins(1)), # Terminal avisa que digitou algo
        Subsignal("sink_ready",   Pins(1)), # SoC avisa que está pronto para ler
        Subsignal("sink_data",    Pins(8)), # Os 8 bits recebidos
    ),
]





# 3. A PLATAFORMA (A Placa Mãe Virtual)

class Platform(SimPlatform):
    def __init__(self):
        # Inicializa a placa chamada "SIM" e conecta nossos pinos nela.
        SimPlatform.__init__(self, "SIM", _io)






# 4. O SISTEMA EM UM CHIP (O Processador)

class SoCPuro(SoCCore):
    def __init__(self):
        platform = Platform()
        sys_clk_freq = int(1e6) # Velocidade de 1MHz para a simulação

        # CRG (Clock and Reset Generator): Transforma o pino virtual no clock oficial.
        self.crg = CRG(platform.request("sys_clk"))

        # Instancia o Cérebro, a Memória e a Comunicação!
        SoCCore.__init__(self, platform, clk_freq=sys_clk_freq,
                         cpu_type="ibex",         # O Processador RISC-V 32 bits
                         #cpu_variant="minimal", # Deixa o processador mais básico e menor
                         ident="Teste",    # O nome que aparece no boot
                         uart_name="sim",             # Conecta a UART no simulador
                         integrated_rom_size=0x8000,  # 32KB de ROM (Guarda a BIOS)
                         integrated_main_ram_size=0x4000) # 16KB de RAM (Para variáveis)






# 5. O MOTOR DE EXECUÇÃO (Builder)

def main():
    # Carrega o projeto do chip
    soc = SoCPuro()

    # Configura o Verilator (O simulador)
    sim_config = SimConfig()
    sim_config.add_clocker("sys_clk", freq_hz=int(1e6)) # Pulsa o clock a 1MHz
    sim_config.add_module("serial2console", "serial")   # Liga a serial na tela do Linux

    # Prepara o construtor (Gera arquivos na pasta 'build')
    builder = Builder(soc, output_dir="build", csr_csv="csr.csv")
    
    # Roda a conversão para Verilog, compila o C e abre o simulador interativo
    builder.build(sim_config=sim_config, interactive=True, run=True)

# Garante que o script rode corretamente via terminal
if __name__ == "__main__":
    main()
