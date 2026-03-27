
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-------------------------------------------------

entity ula_numeric is
  port (
    A             : in  std_logic_vector(31 downto 0);
    B             : in  std_logic_vector(31 downto 0);
    control       : in  std_logic_vector(2 downto 0);

    result        : out std_logic_vector(31 downto 0);
    flag_neg      : out std_logic;
    flag_zero     : out std_logic;
    flag_overflow : out std_logic
  );
end entity ula_numeric;

-------------------------------------------------

architecture behv of ula_numeric is
  signal result_s  : std_logic_vector(31 downto 0);
  signal c_out31_s : std_logic;
  signal c_out30_s : std_logic;
begin

  process(A, B, control)
    variable full_sum : unsigned(32 downto 0);
    variable part_sum : unsigned(31 downto 0);
    variable b_inv    : std_logic_vector(31 downto 0);
  begin
    b_inv := not B;

    case control is
      when "010" =>  -- ADD: result = A + B
        full_sum  := ('0' & unsigned(A)) + ('0' & unsigned(B));
        part_sum  := ('0' & unsigned(A(30 downto 0))) + ('0' & unsigned(B(30 downto 0)));
        result_s  <= std_logic_vector(full_sum(31 downto 0));
        c_out31_s <= full_sum(32);
        c_out30_s <= part_sum(31);

      when "011" =>  -- SUB: result = A - B  (= A + ~B + 1)
        full_sum  := ('0' & unsigned(A)) + ('0' & unsigned(b_inv)) + 1;
        part_sum  := ('0' & unsigned(A(30 downto 0))) + ('0' & unsigned(b_inv(30 downto 0))) + 1;
        result_s  <= std_logic_vector(full_sum(31 downto 0));
        c_out31_s <= full_sum(32);
        c_out30_s <= part_sum(31);

      when "100" =>  -- AND
        result_s  <= A and B;
        c_out31_s <= '0';
        c_out30_s <= '0';

      when "101" =>  -- OR
        result_s  <= A or B;
        c_out31_s <= '0';
        c_out30_s <= '0';

      when "110" =>  -- NOR
        result_s  <= not (A or B);
        c_out31_s <= '0';
        c_out30_s <= '0';

      when "111" =>  -- XOR
        result_s  <= A xor B;
        c_out31_s <= '0';
        c_out30_s <= '0';

      when others =>
        result_s  <= (others => '0');
        c_out31_s <= '0';
        c_out30_s <= '0';
    end case;
  end process;

  result        <= result_s;
  flag_neg      <= result_s(31);
  flag_zero     <= '1' when result_s = x"00000000" else '0';
  flag_overflow <= c_out31_s xor c_out30_s;

end architecture behv;
