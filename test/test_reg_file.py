import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer


async def init(dut):
    """Inicia clock e reseta todos os registradores."""
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    dut.rst.value    = 1
    dut.W_en.value   = 0
    dut.W_addr.value = 0
    dut.W_data.value = 0
    dut.A_addr.value = 0
    dut.B_addr.value = 0
    await RisingEdge(dut.clk)
    dut.rst.value = 0
    await Timer(1, units="ns")


async def write_reg(dut, addr, data):
    """Escreve data no registrador addr na proxima borda de subida."""
    dut.W_addr.value = addr
    dut.W_data.value = data
    dut.W_en.value   = 1
    await RisingEdge(dut.clk)
    dut.W_en.value   = 0
    await Timer(1, units="ns")


async def read_A(dut, addr):
    """Leitura combinacional pela porta A."""
    dut.A_addr.value = addr
    await Timer(1, units="ns")
    return int(dut.A_data.value)


async def read_B(dut, addr):
    """Leitura combinacional pela porta B."""
    dut.B_addr.value = addr
    await Timer(1, units="ns")
    return int(dut.B_data.value)


# ---------------------------------------------------------------------------
# caso1 -- reset zera todos os registradores
# ---------------------------------------------------------------------------
@cocotb.test()
async def test_reset(dut):
    """Apos reset, todos os registradores devem ser 0."""
    await init(dut)

    # Escreve em alguns registradores
    for i in range(1, 5):
        await write_reg(dut, i, 0xDEADBEEF)

    # Aplica reset
    dut.rst.value = 1
    await RisingEdge(dut.clk)
    dut.rst.value = 0
    await Timer(1, units="ns")

    # Verifica que todos estao zerados
    for i in range(32):
        val = await read_A(dut, i)
        assert val == 0, (
            f"Apos reset, R[{i}] deveria ser 0, obtido 0x{val:08X}"
        )


# ---------------------------------------------------------------------------
# caso2 -- escrita e leitura basica
# ---------------------------------------------------------------------------
@cocotb.test()
async def test_write_read(dut):
    """Escrita sincrona e leitura assincrona de registradores."""
    await init(dut)

    cases = [
        ( 1, 0x00000001),
        ( 5, 0xDEADBEEF),
        (10, 0x12345678),
        (31, 0xFFFFFFFF),
    ]
    for addr, data in cases:
        await write_reg(dut, addr, data)
        val = await read_A(dut, addr)
        assert val == data, (
            f"R[{addr}]: esperado 0x{data:08X}, obtido 0x{val:08X}"
        )


# ---------------------------------------------------------------------------
# caso3 -- R[0] e sempre 0 (escrita ignorada)
# ---------------------------------------------------------------------------
@cocotb.test()
async def test_r0_always_zero(dut):
    """Escrita em R[0] deve ser ignorada — R[0] e sempre 0."""
    await init(dut)

    await write_reg(dut, 0, 0xDEADBEEF)
    val = await read_A(dut, 0)
    assert val == 0, f"R[0] deveria ser sempre 0, obtido 0x{val:08X}"


# ---------------------------------------------------------------------------
# caso4 -- W_en=0 impede escrita
# ---------------------------------------------------------------------------
@cocotb.test()
async def test_w_en_disabled(dut):
    """Com W_en=0, o registrador nao deve ser alterado."""
    await init(dut)

    # Escreve valor inicial em R[7]
    await write_reg(dut, 7, 0xABCD1234)

    # Tenta sobrescrever com W_en=0
    dut.W_addr.value = 7
    dut.W_data.value = 0xDEADBEEF
    dut.W_en.value   = 0
    await RisingEdge(dut.clk)
    await Timer(1, units="ns")

    val = await read_A(dut, 7)
    assert val == 0xABCD1234, (
        f"R[7] nao deveria mudar com W_en=0, obtido 0x{val:08X}"
    )


# ---------------------------------------------------------------------------
# caso5 -- duas portas de leitura independentes
# ---------------------------------------------------------------------------
@cocotb.test()
async def test_two_read_ports(dut):
    """A_data e B_data leem registradores diferentes simultaneamente."""
    await init(dut)

    await write_reg(dut, 3, 0xAAAAAAAA)
    await write_reg(dut, 4, 0x55555555)

    dut.A_addr.value = 3
    dut.B_addr.value = 4
    await Timer(1, units="ns")

    a_val = int(dut.A_data.value)
    b_val = int(dut.B_data.value)

    assert a_val == 0xAAAAAAAA, (
        f"A_data: esperado 0xAAAAAAAA, obtido 0x{a_val:08X}"
    )
    assert b_val == 0x55555555, (
        f"B_data: esperado 0x55555555, obtido 0x{b_val:08X}"
    )


# ---------------------------------------------------------------------------
# caso6 -- escreve e verifica todos os 31 registradores (R1-R31)
# ---------------------------------------------------------------------------
@cocotb.test()
async def test_write_all_registers(dut):
    """Escreve em R[1]-R[31] e verifica cada um; R[0] permanece 0."""
    await init(dut)

    for i in range(1, 32):
        await write_reg(dut, i, i * 0x01010101)

    for i in range(1, 32):
        expected = (i * 0x01010101) & 0xFFFFFFFF
        val = await read_A(dut, i)
        assert val == expected, (
            f"R[{i}]: esperado 0x{expected:08X}, obtido 0x{val:08X}"
        )

    # R[0] ainda deve ser 0
    val = await read_A(dut, 0)
    assert val == 0, f"R[0] deveria ser 0, obtido 0x{val:08X}"
