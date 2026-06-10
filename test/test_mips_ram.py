#!/usr/bin/env python3

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer


def word_addr(byte_addr: int) -> int:
    return byte_addr >> 2


@cocotb.test()
async def test_mips_ram(dut):
    # Clock
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())

    # Estado inicial
    dut.reset.value   = 0
    dut.word_we.value = 0
    dut.addr.value    = 0
    dut.data_in.value = 0

    # Aguarda um ciclo para estabilizar
    await RisingEdge(dut.clk)

    # Verifica que a RAM comeca zerada (64 palavras: byte-addr 0..252)
    for a in [0, 4, 16, 60, 252]:
        dut.addr.value = a
        await Timer(1, unit="ns")
        got = int(dut.data_out.value)
        assert got == 0, f"addr=0x{a:08X}: esperado 0, obtido 0x{got:08X}"

    # Escreve alguns valores em enderecos diferentes (dentro das 64 palavras)
    tests = [
        (0x00000000, 0x12345678),
        (0x00000004, 0xDEADBEEF),
        (0x000000FC, 0xA5A5A5A5),  # ultima palavra (word-address 63)
    ]

    for addr, data in tests:
        dut.addr.value    = addr
        dut.data_in.value = data
        dut.word_we.value = 1
        await RisingEdge(dut.clk)
        dut.word_we.value = 0

        # Leitura assincrona logo apos a escrita
        await Timer(1, unit="ns")
        got = int(dut.data_out.value)
        assert got == data, (
            f"write/read addr=0x{addr:08X}: esperado 0x{data:08X}, obtido 0x{got:08X}"
        )

    # Confere que o enderecamento ignora os 2 bits menos significativos:
    # addr 0x00000000 e 0x00000003 mapeiam para a mesma palavra
    dut.addr.value = 0x00000003
    await Timer(1, unit="ns")
    got = int(dut.data_out.value)
    assert got == 0x12345678, (
        f"enderecamento desalinhado: esperado 0x12345678, obtido 0x{got:08X}"
    )

    # Confere que escrita nao ocorre com word_we = 0
    dut.addr.value    = 0x00000004
    dut.data_in.value = 0xCAFEBABE
    dut.word_we.value = 0
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")
    got = int(dut.data_out.value)
    assert got == 0xDEADBEEF, (
        f"write enable desligado: esperado 0xDEADBEEF, obtido 0x{got:08X}"
    )
