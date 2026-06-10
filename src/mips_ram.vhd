library IEEE;
use IEEE.std_logic_1164.all;
use ieee.numeric_std.all;

entity mips_ram IS
   port ( clk      : in  std_logic;
          addr     : in  std_logic_vector(31 downto 0);
          data_in  : in  std_logic_vector(31 downto 0);
          data_out : out std_logic_vector(31 downto 0);
          word_we  : in  std_logic;
          byte_we  : in  std_logic;
          half_we  : in  std_logic;
          reset    : in  std_logic
        );
end entity;

architecture bhv OF mips_ram IS
  type blocoMemoria IS ARRAY(0 TO 63) OF std_logic_vector(31 DOWNTO 0);

  -- Atributo para forcar uso de blocos M10K (memoria dedicada do FPGA)
  attribute ramstyle : string;
  attribute ramstyle of memRAM : signal is "M10K";

  signal memRAM     : blocoMemoria := (others => (others => '0'));
  signal addr_local : std_logic_vector(5 downto 0);

begin

  addr_local <= addr(7 downto 2);

  process(clk)
    variable idx : integer;
  begin
      if rising_edge(clk) then
          idx := to_integer(unsigned(addr_local));

          if word_we = '1' then
              memRAM(idx) <= data_in;

          elsif half_we = '1' then
              if addr(1) = '0' then
                  memRAM(idx)(15 downto  0) <= data_in(15 downto 0);
              else
                  memRAM(idx)(31 downto 16) <= data_in(15 downto 0);
              end if;

          elsif byte_we = '1' then
              case addr(1 downto 0) is
                  when "00"   => memRAM(idx)( 7 downto  0) <= data_in(7 downto 0);
                  when "01"   => memRAM(idx)(15 downto  8) <= data_in(7 downto 0);
                  when "10"   => memRAM(idx)(23 downto 16) <= data_in(7 downto 0);
                  when others => memRAM(idx)(31 downto 24) <= data_in(7 downto 0);
              end case;
          end if;
      end if;
  end process;

  data_out <= memRAM(to_integer(unsigned(addr_local)));

end architecture;
