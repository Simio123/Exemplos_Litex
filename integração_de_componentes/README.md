# Exemplo LiteX: SoC RISC-V com Ibex

Este exemplo demonstra como criar um **System-on-Chip (SoC)** utilizando o **LiteX**. O projeto instancia um processador **Ibex (RISC-V 32 bits)**, memória integrada, uma interface serial (UART) para comunicação com o terminal e executa tudo em um ambiente de simulação usando o **Verilator**.

---

## 📄 Arquivo

- `soc.py`: Define a plataforma virtual, configura o SoC e inicia a simulação.

---

## ▶️ Como Executar

Execute o script:

```bash
python3 soc.py
```

Ao final da execução, o LiteX irá:

- Gerar o hardware em Verilog;
- Compilar a BIOS;
- Construir os arquivos na pasta `build/`;
- Iniciar a simulação interativa do SoC.

---

## 📂 Arquivos Gerados

```text
build/
csr.csv
```

A pasta `build/` contém os arquivos gerados pelo LiteX, incluindo o hardware em Verilog e os artefatos necessários para a simulação.
