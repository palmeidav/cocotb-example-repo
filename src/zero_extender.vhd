library ieee;
use ieee.std_logic_1164.all;

entity zero_extender is
port(
    in_16  : in  std_logic_vector(15 downto 0);
    out_32 : out std_logic_vector(31 downto 0)
);
end zero_extender;

architecture behv1 of zero_extender is
begin
    -- Preenche os 16 bits superiores com zero
    out_32 <= (31 downto 16 => '0') & in_16;
end behv1;
