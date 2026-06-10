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
