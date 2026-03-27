import cocotb
from cocotb.triggers import Timer

# ---------------------------------------------------------------------------
# Tabela de controle:
#   010 -> A + B
#   011 -> A - B
#   100 -> A AND B
#   101 -> A OR B
#   110 -> A NOR B
#   111 -> A XOR B
# ---------------------------------------------------------------------------

MASK32 = 0xFFFF_FFFF


def flag_neg(result: int) -> int:
    return (result >> 31) & 1


def flag_zero(result: int) -> int:
    return 1 if (result & MASK32) == 0 else 0


def overflow_add(a: int, b: int, result: int) -> int:
    """Overflow em adicao: sinais iguais nas entradas, diferente na saida."""
    sa = (a >> 31) & 1
    sb = (b >> 31) & 1
    sr = (result >> 31) & 1
    return 1 if (sa == sb) and (sr != sa) else 0


def overflow_sub(a: int, b: int, result: int) -> int:
    """Overflow em subtracao A-B: sinais diferentes nas entradas,
    e sinal da saida diferente do sinal de A."""
    sa = (a >> 31) & 1
    sb = (b >> 31) & 1
    sr = (result >> 31) & 1
    return 1 if (sa != sb) and (sr != sa) else 0


async def apply(dut, A, B, control, expected_result,
                expected_neg, expected_zero, expected_overflow):
    dut.A.value       = A
    dut.B.value       = B
    dut.control.value = control
    await Timer(10, units="ns")

    assert dut.result.value == expected_result, (
        f"control={control:03b} A=0x{A:08X} B=0x{B:08X}: "
        f"esperado result=0x{expected_result:08X}, "
        f"obtido=0x{int(dut.result.value):08X}"
    )
    assert dut.flag_neg.value == expected_neg, (
        f"control={control:03b} A=0x{A:08X} B=0x{B:08X}: "
        f"esperado flag_neg={expected_neg}, obtido={dut.flag_neg.value}"
    )
    assert dut.flag_zero.value == expected_zero, (
        f"control={control:03b} A=0x{A:08X} B=0x{B:08X}: "
        f"esperado flag_zero={expected_zero}, obtido={dut.flag_zero.value}"
    )
    assert dut.flag_overflow.value == expected_overflow, (
        f"control={control:03b} A=0x{A:08X} B=0x{B:08X}: "
        f"esperado flag_overflow={expected_overflow}, obtido={dut.flag_overflow.value}"
    )


# ---------------------------------------------------------------------------
# ADD  control=010  result = A + B
# ---------------------------------------------------------------------------
@cocotb.test()
async def test_dut_add(dut):
    """control=010: result = A + B"""
    cases = [
        (0x00000000, 0x00000000),   # 0 + 0 = 0
        (0x00000001, 0x00000001),   # 1 + 1 = 2
        (0x00000005, 0x00000003),   # 5 + 3 = 8
        (0xFFFFFFFF, 0x00000001),   # -1 + 1 = 0  (wrap)
        (0x7FFFFFFE, 0x00000001),   # max_pos - 1 + 1 = max_pos
    ]
    for A, B in cases:
        res = (A + B) & MASK32
        await apply(dut, A, B, control=0b010,
                    expected_result=res,
                    expected_neg=flag_neg(res),
                    expected_zero=flag_zero(res),
                    expected_overflow=overflow_add(A, B, res))


# ---------------------------------------------------------------------------
# SUB  control=011  result = A - B
# ---------------------------------------------------------------------------
@cocotb.test()
async def test_dut_sub(dut):
    """control=011: result = A - B"""
    cases = [
        (0x00000005, 0x00000003),   # 5 - 3 = 2
        (0x00000005, 0x00000005),   # 5 - 5 = 0  -> flag_zero=1
        (0x00000003, 0x00000005),   # 3 - 5 = -2 -> flag_neg=1
        (0x00000000, 0x00000001),   # 0 - 1 = -1 = 0xFFFFFFFF
        (0x80000000, 0x00000001),   # min_neg - 1 -> overflow
    ]
    for A, B in cases:
        res = (A - B) & MASK32
        await apply(dut, A, B, control=0b011,
                    expected_result=res,
                    expected_neg=flag_neg(res),
                    expected_zero=flag_zero(res),
                    expected_overflow=overflow_sub(A, B, res))


# ---------------------------------------------------------------------------
# AND  control=100  result = A AND B
# ---------------------------------------------------------------------------
@cocotb.test()
async def test_dut_and(dut):
    """control=100: result = A AND B"""
    cases = [
        (0x00000000, 0xFFFFFFFF),   # 0 AND all_ones = 0
        (0xFFFFFFFF, 0xFFFFFFFF),   # all_ones AND all_ones = all_ones
        (0xF0F0F0F0, 0x0F0F0F0F),   # mascara alternada = 0
        (0xFFFF0000, 0xFFFFFFFF),   # mascara alta = 0xFFFF0000
    ]
    for A, B in cases:
        res = (A & B) & MASK32
        await apply(dut, A, B, control=0b100,
                    expected_result=res,
                    expected_neg=flag_neg(res),
                    expected_zero=flag_zero(res),
                    expected_overflow=0)


# ---------------------------------------------------------------------------
# OR   control=101  result = A OR B
# ---------------------------------------------------------------------------
@cocotb.test()
async def test_dut_or(dut):
    """control=101: result = A OR B"""
    cases = [
        (0x00000000, 0x00000000),   # 0 OR 0 = 0
        (0x00000000, 0xFFFFFFFF),   # 0 OR all_ones = all_ones
        (0xF0F0F0F0, 0x0F0F0F0F),   # complementares = all_ones
        (0xFFFF0000, 0x0000FFFF),   # metades = all_ones
    ]
    for A, B in cases:
        res = (A | B) & MASK32
        await apply(dut, A, B, control=0b101,
                    expected_result=res,
                    expected_neg=flag_neg(res),
                    expected_zero=flag_zero(res),
                    expected_overflow=0)


# ---------------------------------------------------------------------------
# NOR  control=110  result = NOT(A OR B)
# ---------------------------------------------------------------------------
@cocotb.test()
async def test_dut_nor(dut):
    """control=110: result = NOR(A, B) = NOT(A OR B)"""
    cases = [
        (0x00000000, 0x00000000),   # NOR(0,0) = all_ones
        (0xFFFFFFFF, 0x00000000),   # NOR(all_ones, 0) = 0
        (0xFFFFFFFF, 0xFFFFFFFF),   # NOR(all_ones, all_ones) = 0
        (0xF0F0F0F0, 0x0F0F0F0F),   # NOR(complementares) = 0
        (0x00000000, 0x0000FFFF),   # NOR(0, meia_palavra) = 0xFFFF0000
    ]
    for A, B in cases:
        res = (~(A | B)) & MASK32
        await apply(dut, A, B, control=0b110,
                    expected_result=res,
                    expected_neg=flag_neg(res),
                    expected_zero=flag_zero(res),
                    expected_overflow=0)


# ---------------------------------------------------------------------------
# XOR  control=111  result = A XOR B
# ---------------------------------------------------------------------------
@cocotb.test()
async def test_dut_xor(dut):
    """control=111: result = A XOR B"""
    cases = [
        (0x00000000, 0x00000000),   # 0 XOR 0 = 0
        (0xFFFFFFFF, 0x00000000),   # all_ones XOR 0 = all_ones
        (0xFFFFFFFF, 0xFFFFFFFF),   # A XOR A = 0
        (0xF0F0F0F0, 0x0F0F0F0F),   # complementares = all_ones
        (0xAAAAAAAA, 0x55555555),   # padrao alternado = all_ones
    ]
    for A, B in cases:
        res = (A ^ B) & MASK32
        await apply(dut, A, B, control=0b111,
                    expected_result=res,
                    expected_neg=flag_neg(res),
                    expected_zero=flag_zero(res),
                    expected_overflow=0)


# ---------------------------------------------------------------------------
# FLAG_NEG  flag_neg = result[31]
# ---------------------------------------------------------------------------
@cocotb.test()
async def test_dut_flag_neg(dut):
    """flag_neg=1 quando MSB do resultado e 1"""
    # Negativo via OR: 0 OR 0x80000000
    res = 0x80000000
    await apply(dut, 0x00000000, 0x80000000, control=0b101,
                expected_result=res,
                expected_neg=1, expected_zero=0, expected_overflow=0)

    # Negativo via subtracao: 0 - 1 = 0xFFFFFFFF
    res = (0 - 1) & MASK32
    await apply(dut, 0x00000000, 0x00000001, control=0b011,
                expected_result=res,
                expected_neg=1, expected_zero=0,
                expected_overflow=overflow_sub(0, 1, res))

    # Positivo: MSB = 0
    res = 0x00000005
    await apply(dut, 0x00000002, 0x00000003, control=0b010,
                expected_result=res,
                expected_neg=0, expected_zero=0, expected_overflow=0)


# ---------------------------------------------------------------------------
# FLAG_ZERO  flag_zero = 1 sse result == 0
# ---------------------------------------------------------------------------
@cocotb.test()
async def test_dut_flag_zero(dut):
    """flag_zero=1 somente quando result == 0x00000000"""
    # A - A = 0
    await apply(dut, 0x12345678, 0x12345678, control=0b011,
                expected_result=0x00000000,
                expected_neg=0, expected_zero=1, expected_overflow=0)

    # A AND ~A = 0
    await apply(dut, 0xF0F0F0F0, 0x0F0F0F0F, control=0b100,
                expected_result=0x00000000,
                expected_neg=0, expected_zero=1, expected_overflow=0)

    # A XOR A = 0
    await apply(dut, 0xDEADBEEF, 0xDEADBEEF, control=0b111,
                expected_result=0x00000000,
                expected_neg=0, expected_zero=1, expected_overflow=0)

    # Resultado nao-zero: flag_zero=0
    await apply(dut, 0x00000001, 0x00000000, control=0b010,
                expected_result=0x00000001,
                expected_neg=0, expected_zero=0, expected_overflow=0)


# ---------------------------------------------------------------------------
# FLAG_OVERFLOW  overflow = 1 em estouro de sinal (complemento de 2)
# ---------------------------------------------------------------------------
@cocotb.test()
async def test_dut_flag_overflow(dut):
    """flag_overflow: pos+pos->neg e neg+neg->pos geram overflow"""
    # Pos + Pos -> Neg: 0x7FFFFFFF + 1 = 0x80000000
    A, B = 0x7FFFFFFF, 0x00000001
    res = (A + B) & MASK32
    await apply(dut, A, B, control=0b010,
                expected_result=res,
                expected_neg=1, expected_zero=0, expected_overflow=1)

    # Neg + Neg -> Pos: 0x80000000 + 0x80000000 = 0
    A, B = 0x80000000, 0x80000000
    res = (A + B) & MASK32
    await apply(dut, A, B, control=0b010,
                expected_result=res,
                expected_neg=0, expected_zero=1, expected_overflow=1)

    # Sem overflow: 1 + 1 = 2
    A, B = 0x00000001, 0x00000001
    res = (A + B) & MASK32
    await apply(dut, A, B, control=0b010,
                expected_result=res,
                expected_neg=0, expected_zero=0, expected_overflow=0)

    # Overflow na subtracao: min_neg - 1 = pos
    A, B = 0x80000000, 0x00000001
    res = (A - B) & MASK32
    await apply(dut, A, B, control=0b011,
                expected_result=res,
                expected_neg=flag_neg(res), expected_zero=flag_zero(res),
                expected_overflow=overflow_sub(A, B, res))
