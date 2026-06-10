library IEEE;
use IEEE.std_logic_1164.all;
use ieee.numeric_std.all;

entity mips_rom is
   generic (
          dataWidth: natural := 32;
          addrWidth: natural := 6   -- 64 palavras (suficiente para o programa)
   );
   port (
          addr : in  std_logic_vector (addrWidth-1 DOWNTO 0);
          data : out std_logic_vector (dataWidth-1 DOWNTO 0)
   );
end entity;

architecture bhv of mips_rom is

  type blocoMemoria is array(0 TO 2**addrWidth - 1) of std_logic_vector(dataWidth-1 DOWNTO 0);

  -- Atributo para forcar uso de blocos M10K (memoria dedicada do FPGA)
  attribute rom_style : string;
  attribute rom_style of memROM : signal is "M10K";

  function initMemory
        return blocoMemoria is variable tmp : blocoMemoria := (others => (others => '0'));
  begin
      -- =====================================================
      -- Programa de teste MIPS
      -- Resultado visivel: LEDR mostra $t0 (PC[11:2])
      -- =====================================================

      -- [0] addiu $t0, $0, 5        # $t0 = 5
      tmp(0)  := "001001" & "00000" & "01000" & x"0005";

      -- [1] addiu $t1, $0, 3        # $t1 = 3
      tmp(1)  := "001001" & "00000" & "01001" & x"0003";

      -- [2] addu  $t2, $t0, $t1     # $t2 = 5+3 = 8
      tmp(2)  := "000000" & "01000" & "01001" & "01010" & "00000" & "100001";

      -- [3] subu  $t3, $t0, $t1     # $t3 = 5-3 = 2
      tmp(3)  := "000000" & "01000" & "01001" & "01011" & "00000" & "100011";

      -- [4] and   $t4, $t0, $t1     # $t4 = 5 AND 3 = 1
      tmp(4)  := "000000" & "01000" & "01001" & "01100" & "00000" & "100100";

      -- [5] or    $t5, $t0, $t1     # $t5 = 5 OR  3 = 7
      tmp(5)  := "000000" & "01000" & "01001" & "01101" & "00000" & "100101";

      -- [6] xor   $t6, $t0, $t1     # $t6 = 5 XOR 3 = 6
      tmp(6)  := "000000" & "01000" & "01001" & "01110" & "00000" & "100110";

      -- [7] nor   $t7, $t0, $t1     # $t7 = NOR(5,3)
      tmp(7)  := "000000" & "01000" & "01001" & "01111" & "00000" & "100111";

      -- [8] sw    $t2, 0($0)         # MEM[0] = 8
      tmp(8)  := "101011" & "00000" & "01010" & x"0000";

      -- [9] sw    $t3, 4($0)         # MEM[4] = 2
      tmp(9)  := "101011" & "00000" & "01011" & x"0004";

      -- [10] lw   $s0, 0($0)         # $s0 = MEM[0] = 8  (verifica sw+lw)
      tmp(10) := "100011" & "00000" & "10000" & x"0000";

      -- [11] lw   $s1, 4($0)         # $s1 = MEM[4] = 2
      tmp(11) := "100011" & "00000" & "10001" & x"0004";

      -- [12] addu $s2, $s0, $s1      # $s2 = 8+2 = 10  (verifica lw resultado)
      tmp(12) := "000000" & "10000" & "10001" & "10010" & "00000" & "100001";

      -- [13] beq  $s0, $s0, +1       # branch always (testa BEQ taken)
      tmp(13) := "000100" & "10000" & "10000" & x"0001";

      -- [14] addiu $t0, $0, 0xDEAD   # NÃO deve executar (branch pulou)
      tmp(14) := "001001" & "00000" & "01000" & x"DEAD";

      -- [15] bne  $t0, $t1, +1       # 5 != 3 -> branch taken (testa BNE)
      tmp(15) := "000101" & "01000" & "01001" & x"0001";

      -- [16] addiu $t0, $0, 0xBEEF   # NÃO deve executar
      tmp(16) := "001001" & "00000" & "01000" & x"BEEF";

      -- [17] sll  $t0, $t2, 1        # $t0 = $t2 << 1 = 8<<1 = 16
      tmp(17) := "000000" & "00000" & "01010" & "01000" & "00001" & "000000";

      -- [18] srl  $t0, $t0, 2        # $t0 = 16>>2 = 4
      tmp(18) := "000000" & "00000" & "01000" & "01000" & "00010" & "000010";

      -- [19] sltu $t0, $t1, $t2      # $t0 = ($t1 < $t2) = (3 < 8) = 1
      tmp(19) := "000000" & "01001" & "01010" & "01000" & "00000" & "101011";

      -- [20] j 0                     # loop volta ao inicio
      tmp(20) := "000010" & "00000000000000000000000000";

      return tmp;
    end initMemory;

    signal memROM : blocoMemoria := initMemory;

begin
    data <= memROM (to_integer(unsigned(addr)));
end architecture;
