# Projeto SoC RISC-V com LiteX (Processador Ibex)

Este projeto consiste na implementação e simulação de um **System-on-Chip (SoC)** utilizando o framework **LiteX**. O sistema foi desenvolvido em **Python/Migen**, configurado com o processador **Ibex** (um core **RISC-V de 32 bits** desenvolvido pela **lowRISC** em **SystemVerilog**) e utiliza o simulador **Verilator** para executar software *bare-metal* escrito em C.

---

## 🚀 Estrutura do Projeto

- **`noc.py`**: Script Python responsável por descrever a arquitetura do SoC, configurar os periféricos virtuais e gerar o hardware para simulação utilizando o Verilator.
- **`main.c`**: Programa em C que será compilado para a arquitetura RISC-V e executado diretamente no processador Ibex.
- **`Makefile`**: Automatiza a compilação do software utilizando o toolchain RISC-V.

---

## 💻 Como Executar o Projeto

### 1. Gerar o Hardware (SoC com Ibex) no terminal 1

```bash
python3 noc.py
```

### 2. Compilar o Software em C

```bash
make
```

### 3. Carregar o Binário e Executar no terminal 2

```bash
litex_term socket://127.0.0.1:5000 --kernel app.bin
```

