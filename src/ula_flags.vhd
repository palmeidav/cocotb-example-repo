library ieee;
use ieee.std_logic_1164.all;

entity flags is
port(
    c_out31      : in  std_logic;
    c_out30      : in  std_logic;
    ula_out      : in  std_logic_vector(31 downto 0);
    flag_neg     : out std_logic;
    flag_zero    : out std_logic;
    flag_overflow: out std_logic
);
end flags;

architecture behv1 of flags is
    signal zero_check : std_logic;
begin
    flag_overflow <= c_out31 xor c_out30;

    flag_neg <= ula_out(31);

    zero_check <= ula_out(0)  or ula_out(1)  or ula_out(2)  or ula_out(3)  or
                  ula_out(4)  or ula_out(5)  or ula_out(6)  or ula_out(7)  or
                  ula_out(8)  or ula_out(9)  or ula_out(10) or ula_out(11) or
                  ula_out(12) or ula_out(13) or ula_out(14) or ula_out(15) or
                  ula_out(16) or ula_out(17) or ula_out(18) or ula_out(19) or
                  ula_out(20) or ula_out(21) or ula_out(22) or ula_out(23) or
                  ula_out(24) or ula_out(25) or ula_out(26) or ula_out(27) or
                  ula_out(28) or ula_out(29) or ula_out(30) or ula_out(31);

    flag_zero <= not zero_check;

end behv1;
