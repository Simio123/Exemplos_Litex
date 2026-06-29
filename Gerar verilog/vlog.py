# Importa os elementos básicos do Migen.
from migen import *

# Importa o conversor Migen -> Verilog.
from migen.fhdl import verilog


# Define um módulo de hardware.
class Somador(Module):
    def __init__(self):

        # Entradas de 8 bits.
        self.a = Signal(8)
        self.b = Signal(8)

        # Saída de 8 bits.
        self.soma = Signal(8)

        # Lógica combinacional:
        # soma = a + b
        #
        # Equivalente em Verilog:
        # assign soma = a + b;
        self.comb += self.soma.eq(self.a + self.b)


# Instancia o circuito.
dut = Somador()

# Converte o circuito para Verilog.
verilog_output = verilog.convert(
    dut,
    ios={
        dut.a,
        dut.b,
        dut.soma
    },
    name="somador"  # nome do módulo Verilog
)

# Mostra o Verilog na tela.
print(verilog_output)

# Salva o Verilog em arquivo.
with open("somador.v", "w") as f:
    f.write(str(verilog_output))

print("\nArquivo 'somador.v' gerado com sucesso!")
