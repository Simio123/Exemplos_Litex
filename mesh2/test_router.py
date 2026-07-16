from migen import *
from migen.sim import run_simulation
from router import Router, DIRS


class Harness(Module):
    """Liga as 4 direções externas do roteador a stubs simples (tie-off),
    deixando N/S/E/W livres para o testbench dirigir manualmente."""
    def __init__(self, x=0, y=0):
        self.submodules.dut = Router(x, y)


def tb(dut):
    r = dut.dut

    # Amarra tudo em zero por padrão (sem vizinhos conectados)
    for d in DIRS:
        yield r.ports_in[d].valid.eq(0)
        yield r.ports_out[d].ready.eq(1)

    yield

    # ---- Teste 1: pacote chegando do Oeste, destinado a este roteador (Local) ----
    yield r.ports_in["W"].valid.eq(1)
    yield r.ports_in["W"].dest_x.eq(r.x)
    yield r.ports_in["W"].dest_y.eq(r.y)
    yield r.ports_in["W"].data.eq(0xAA)
    yield
    local_valid = yield r.ports_out["L"].valid
    local_data  = yield r.ports_out["L"].data
    w_ready     = yield r.ports_in["W"].ready
    assert local_valid == 1, "pacote deveria ter sido entregue em Local"
    assert local_data == 0xAA, f"dado incorreto: {hex(local_data)}"
    assert w_ready == 1, "entrada W deveria ter sido aceita (ready=1)"
    print("[OK] Teste 1: entrega Local a partir de W")

    yield r.ports_in["W"].valid.eq(0)
    yield

    # ---- Teste 2: pacote saindo do Local, destinado a (x+1, y) -> deve sair por E ----
    yield r.ports_in["L"].valid.eq(1)
    yield r.ports_in["L"].dest_x.eq(r.x + 1)
    yield r.ports_in["L"].dest_y.eq(r.y)
    yield r.ports_in["L"].data.eq(0x55)
    yield
    e_valid = yield r.ports_out["E"].valid
    e_data  = yield r.ports_out["E"].data
    assert e_valid == 1, "pacote deveria sair pela porta Leste"
    assert e_data == 0x55
    print("[OK] Teste 2: roteamento Local -> Leste")
    yield r.ports_in["L"].valid.eq(0)
    yield

    # ---- Teste 3: arbitragem — N e W querem a mesma saída (S), L tem prioridade maior
    #      mas não está competindo aqui; testamos N vs W disputando S.
    yield r.ports_in["N"].valid.eq(1)
    yield r.ports_in["N"].dest_x.eq(r.x)
    yield r.ports_in["N"].dest_y.eq(r.y + 1)
    yield r.ports_in["N"].data.eq(0x11)

    yield r.ports_in["W"].valid.eq(1)
    yield r.ports_in["W"].dest_x.eq(r.x)
    yield r.ports_in["W"].dest_y.eq(r.y + 1)
    yield r.ports_in["W"].data.eq(0x22)
    yield
    s_data = yield r.ports_out["S"].data
    n_ready = yield r.ports_in["N"].ready
    w_ready = yield r.ports_in["W"].ready
    # prioridade fixa PRIORITY = (L,N,S,E,W) -> N ganha de W
    assert s_data == 0x11, f"N deveria ganhar a arbitragem, veio {hex(s_data)}"
    assert n_ready == 1 and w_ready == 0
    print("[OK] Teste 3: arbitragem de prioridade (N vence W)")


if __name__ == "__main__":
    dut = Harness(x=0, y=0)
    run_simulation(dut, tb(dut), vcd_name=None)
    print("\nTodos os testes do roteador passaram.")
