library ieee;
use ieee.std_logic_1164.all;

-- Unidade logica de 1 bit
-- Encoding (estrutural): 000=AND  001=OR  100=NOR  101=XOR
entity ula_logicUnit is
port(
    a, b    : in  std_logic;
    control : in  std_logic_vector(2 downto 0);
    result  : out std_logic
);
end ula_logicUnit;

architecture behv1 of ula_logicUnit is
begin
    with control select
        result <= a and b     when "000",
                  a or  b     when "001",
                  not(a or b) when "100",
                  a xor b     when "101",
                  '0'         when others;
end behv1;
