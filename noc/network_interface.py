from migen import *
from litex.soc.interconnect import stream
from litex.soc.interconnect.csr import *

class NetworkInterface(Module, AutoCSR):
    def __init__(self, router_in, router_out):
        # router_in: stream vindo do roteador (RX para o nó)
        # router_out: stream saindo do nó para o roteador (TX)

        # FIFOs
        self.tx_fifo = stream.SyncFIFO([("data", 8)], depth=16)
        self.rx_fifo = stream.SyncFIFO([("data", 8)], depth=16)

        # Conecta FIFOs aos streams externos
        self.comb += [
            router_out.valid.eq(self.tx_fifo.source.valid),
            router_out.data.eq(self.tx_fifo.source.data),
            self.tx_fifo.source.ready.eq(router_out.ready),

            self.rx_fifo.sink.valid.eq(router_in.valid),
            self.rx_fifo.sink.data.eq(router_in.data),
            router_in.ready.eq(self.rx_fifo.sink.ready),
        ]

        # Registros CSR
        self.tx_data = CSRStorage(8, reset=0, name="tx_data")
        self.rx_data = CSR(8, name="rx_data") # Mudado de CSRStatus para CSR puro
        self.status  = CSRStatus(2, reset=0, name="status")

        # Escrita da CPU -> TX FIFO
        # Usamos comb para garantir que valid seja um pulso exato de 1 ciclo do clock
        self.comb += [
            self.tx_fifo.sink.valid.eq(self.tx_data.re), # .re = Pulso de ESCRITA da CPU
            self.tx_fifo.sink.data.eq(self.tx_data.storage)
        ]

        # Leitura da CPU <- RX FIFO
        self.comb += [
            self.rx_data.w.eq(self.rx_fifo.source.data),
            self.rx_fifo.source.ready.eq(self.rx_data.we), # .we = Pulso de LEITURA da CPU
        ]

        # Atualiza Status de Controle (Sem atrasos de clock)
        self.comb += [
            self.status.status[0].eq(~self.tx_fifo.sink.ready),   # TX full
            self.status.status[1].eq(~self.rx_fifo.source.valid), # RX empty
        ]
