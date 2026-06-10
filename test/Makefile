TOPLEVEL_LANG = vhdl
TOPLEVEL = reg_file_mips
VHDL_SOURCES = ../src/reg_file_mips.vhd
MODULE = test_reg_file

SIM = ghdl
SIM_ARGS= --vcd=sim.vcd

include $(shell cocotb-config --makefiles)/Makefile.sim

rom:
    $(MAKE) TOPLEVEL=mips_rom \
            MODULE=test_mips_rom \
            VHDL_SOURCES=../src/mips_rom.vhd

ram:
    $(MAKE) TOPLEVEL=mips_ram \
            MODULE=test_mips_ram \
            VHDL_SOURCES=../src/mips_ram.vhd

ula:
    $(MAKE) TOPLEVEL=ULA \
            MODULE=test_ula \
            VHDL_SOURCES="../src/ula_fullAdder.vhd ../src/ula_logicUnit.vhd ../src/ula_1bit.vhd ../src/ula_32bits.vhd ../src/ula_flags.vhd ../src/ula.vhd"

regfile:
    $(MAKE) TOPLEVEL=reg_file_mips \
            MODULE=test_reg_file \
            VHDL_SOURCES=../src/reg_file_mips.vhd