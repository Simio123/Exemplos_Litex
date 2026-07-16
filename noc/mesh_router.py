from migen import *
from litex.soc.interconnect import stream

class MeshRouter(Module):
    def __init__(self, n=4, data_width=8, fifo_depth=16):
        self.ports_in = [stream.Endpoint([("data", data_width)]) for _ in range(n)]
        self.ports_out = [stream.Endpoint([("data", data_width)]) for _ in range(n)]

        # FIFOs de entrada (usando stream.SyncFIFO do LiteX)
        self.fifos_in = [stream.SyncFIFO([("data", data_width)], depth=fifo_depth) for _ in range(n)]
        for i in range(n):
            self.comb += [
                self.fifos_in[i].sink.valid.eq(self.ports_in[i].valid),
                self.fifos_in[i].sink.data.eq(self.ports_in[i].data),
                self.ports_in[i].ready.eq(self.fifos_in[i].sink.ready)
            ]

        # FIFOs de saída
        self.fifos_out = [stream.SyncFIFO([("data", data_width)], depth=fifo_depth) for _ in range(n)]
        for j in range(n):
            self.comb += [
                self.ports_out[j].valid.eq(self.fifos_out[j].source.valid),
                self.ports_out[j].data.eq(self.fifos_out[j].source.data),
                self.fifos_out[j].source.ready.eq(self.ports_out[j].ready)
            ]

        # Destino (primeiro byte)
        dest = [Signal(2) for _ in range(n)]
        for i in range(n):
            self.comb += dest[i].eq(self.fifos_in[i].source.data[0:2])

        # Crossbar com prioridade fixa (i=0 maior)
        for j in range(n):
            cond = [Signal() for _ in range(n)]
            for i in range(n):
                self.comb += cond[i].eq(self.fifos_in[i].source.valid & (dest[i] == j))

            chosen = Signal(max=n)
            found = Signal()
            out_valid = Signal()
            out_data = Signal(data_width)

            self.comb += [
                If(cond[0],
                    chosen.eq(0), found.eq(1)
                ).Elif(cond[1],
                    chosen.eq(1), found.eq(1)
                ).Elif(cond[2],
                    chosen.eq(2), found.eq(2)
                ).Elif(cond[3],
                    chosen.eq(3), found.eq(3)
                )
            ]

            # Mux
            self.comb += [
                If(found,
                    If(chosen == 0,
                        out_valid.eq(self.fifos_in[0].source.valid),
                        out_data.eq(self.fifos_in[0].source.data),
                        self.fifos_in[0].source.ready.eq(self.fifos_out[j].sink.ready)
                    ).Elif(chosen == 1,
                        out_valid.eq(self.fifos_in[1].source.valid),
                        out_data.eq(self.fifos_in[1].source.data),
                        self.fifos_in[1].source.ready.eq(self.fifos_out[j].sink.ready)
                    ).Elif(chosen == 2,
                        out_valid.eq(self.fifos_in[2].source.valid),
                        out_data.eq(self.fifos_in[2].source.data),
                        self.fifos_in[2].source.ready.eq(self.fifos_out[j].sink.ready)
                    ).Elif(chosen == 3,
                        out_valid.eq(self.fifos_in[3].source.valid),
                        out_data.eq(self.fifos_in[3].source.data),
                        self.fifos_in[3].source.ready.eq(self.fifos_out[j].sink.ready)
                    ).Else(
                        out_valid.eq(0),
                        out_data.eq(0),
                        [self.fifos_in[i].source.ready.eq(0) for i in range(n)]
                    ),
                    out_valid.eq(0),
                    out_data.eq(0),
                    [self.fifos_in[i].source.ready.eq(0) for i in range(n)]
                )
            ]

            self.comb += [
                self.fifos_out[j].sink.valid.eq(out_valid),
                self.fifos_out[j].sink.data.eq(out_data)
            ]
