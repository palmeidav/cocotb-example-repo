library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Toplevel para testar a ULA na DE10-Lite
--
-- SW[9:5]  -> A[4:0]  (5 bits baixos de A)
-- SW[4:0]  -> B[4:0]  (5 bits baixos de B)
-- KEY[2:0] -> control[2:0]
--
-- LEDR[9:0] -> result[9:0]
-- LEDR[9]   -> flag_neg
-- HEX0      -> result[3:0]  em 7-seg
-- HEX1      -> result[7:4]  em 7-seg

entity toplevel_ula is
port(
    SW   : in  std_logic_vector(9 downto 0);
    KEY  : in  std_logic_vector(2 downto 0);
    LEDR : out std_logic_vector(9 downto 0);
    HEX0 : out std_logic_vector(6 downto 0);
    HEX1 : out std_logic_vector(6 downto 0)
);
end toplevel_ula;

architecture bhv of toplevel_ula is

    component ULA is
    port(
        A             : in  std_logic_vector(31 downto 0);
        B             : in  std_logic_vector(31 downto 0);
        control       : in  std_logic_vector(2 downto 0);
        result        : out std_logic_vector(31 downto 0);
        flag_neg      : out std_logic;
        flag_zero     : out std_logic;
        flag_overflow : out std_logic
    );
    end component;

    type seg7_t is array(0 to 15) of std_logic_vector(6 downto 0);
    constant SEG7 : seg7_t := (
        0  => "1000000",
        1  => "1111001",
        2  => "0100100",
        3  => "0110000",
        4  => "0011001",
        5  => "0010010",
        6  => "0000010",
        7  => "1111000",
        8  => "0000000",
        9  => "0010000",
        10 => "0001000",
        11 => "0000011",
        12 => "1000110",
        13 => "0100001",
        14 => "0000110",
        15 => "0001110"
    );

    signal A_s      : std_logic_vector(31 downto 0);
    signal B_s      : std_logic_vector(31 downto 0);
    signal result_s : std_logic_vector(31 downto 0);
    signal flag_neg_s : std_logic;

begin

    A_s <= (31 downto 5 => '0') & SW(9 downto 5);
    B_s <= (31 downto 5 => '0') & SW(4 downto 0);

    i_ula : ULA
        port map(
            A             => A_s,
            B             => B_s,
            control       => KEY,
            result        => result_s,
            flag_neg      => flag_neg_s,
            flag_zero     => open,
            flag_overflow => open
        );

    LEDR(8 downto 0) <= result_s(8 downto 0);
    LEDR(9)          <= flag_neg_s;

    HEX0 <= SEG7(to_integer(unsigned(result_s(3 downto 0))));
    HEX1 <= SEG7(to_integer(unsigned(result_s(7 downto 4))));

end bhv;
