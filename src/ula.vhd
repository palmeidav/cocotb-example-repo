library ieee;
use ieee.std_logic_1164.all;

-- ULA completa estrutural de 32 bits
--
-- Encoding externo (compativel com ula_numeric):
--   010=ADD  011=SUB  100=AND  101=OR  110=NOR  111=XOR
--
-- Mapeamento para encoding interno (estrutural):
--   ADD->010  SUB->110  AND->000  OR->001  NOR->100  XOR->101
entity ULA is
  port (
    A             : in  std_logic_vector(31 downto 0);
    B             : in  std_logic_vector(31 downto 0);
    control       : in  std_logic_vector(2 downto 0);
    result        : out std_logic_vector(31 downto 0);
    flag_neg      : out std_logic;
    flag_zero     : out std_logic;
    flag_overflow : out std_logic
  );
end entity ULA;

architecture bhv of ULA is

    component ula_32bits is
    port(
        a, b    : in  std_logic_vector(31 downto 0);
        control : in  std_logic_vector(2 downto 0);
        outi    : out std_logic_vector(31 downto 0);
        cout    : out std_logic;
        cout30  : out std_logic
    );
    end component;

    component flags is
    port(
        c_out31      : in  std_logic;
        c_out30      : in  std_logic;
        ula_out      : in  std_logic_vector(31 downto 0);
        flag_neg     : out std_logic;
        flag_zero    : out std_logic;
        flag_overflow: out std_logic
    );
    end component;

    signal ctrl_int  : std_logic_vector(2 downto 0);
    signal result_s  : std_logic_vector(31 downto 0);
    signal c_out31_s : std_logic;
    signal c_out30_s : std_logic;

begin

    -- Traducao do encoding externo para o encoding estrutural interno
    with control select
        ctrl_int <= "010" when "010",   -- ADD
                    "110" when "011",   -- SUB
                    "000" when "100",   -- AND
                    "001" when "101",   -- OR
                    "100" when "110",   -- NOR
                    "101" when "111",   -- XOR
                    "010" when others;

    i_ula32 : ula_32bits
        port map(
            a      => A,
            b      => B,
            control => ctrl_int,
            outi   => result_s,
            cout   => c_out31_s,
            cout30 => c_out30_s
        );

    i_flags : flags
        port map(
            c_out31       => c_out31_s,
            c_out30       => c_out30_s,
            ula_out       => result_s,
            flag_neg      => flag_neg,
            flag_zero     => flag_zero,
            flag_overflow => flag_overflow
        );

    result <= result_s;

end bhv;
