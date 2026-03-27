library ieee;
use ieee.std_logic_1164.all;

entity sign_extender is
port(
    in_16  : in  std_logic_vector(15 downto 0);
    out_32 : out std_logic_vector(31 downto 0)
);
end sign_extender;

architecture behv1 of sign_extender is
begin
    -- Replica o bit de sinal (bit 15) nos 16 bits superiores
    out_32 <= (31 downto 16 => in_16(15)) & in_16;
end behv1;
