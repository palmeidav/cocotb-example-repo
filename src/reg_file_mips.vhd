library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity reg_file_mips is
port(
   clk     : in  std_logic;
   rst     : in  std_logic;
   A_addr  : in  std_logic_vector(4 downto 0);
   B_addr  : in  std_logic_vector(4 downto 0);
   W_addr  : in  std_logic_vector(4 downto 0);
   W_data  : in  std_logic_vector(31 downto 0);
   W_en    : in  std_logic;
   A_data  : out std_logic_vector(31 downto 0);
   B_data  : out std_logic_vector(31 downto 0)
);
end reg_file_mips;

architecture behv1 of reg_file_mips is

    type reg_array is array (0 to 31) of std_logic_vector(31 downto 0);
    signal R : reg_array := (others => (others => '0'));

begin

    -- Leitura combinacional (assincrona)
    A_data <= R(to_integer(unsigned(A_addr)));
    B_data <= R(to_integer(unsigned(B_addr)));

    -- Escrita sincrona
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                R <= (others => (others => '0'));
            elsif W_en = '1' and W_addr /= "00000" then
                R(to_integer(unsigned(W_addr))) <= W_data;
            end if;
        end if;
    end process;

end behv1;
