library ieee;
use ieee.std_logic_1164.all;

-- ULA de 1 bit
-- control[2]=1 inverte B e aciona carry_in=1 (subtracao)
-- control[1]=1 seleciona saida aritmetica; =0 seleciona logica
entity ula_1bit is
port(
    a, b, cin : in  std_logic;
    control   : in  std_logic_vector(2 downto 0);
    outi, cout: out std_logic
);
end ula_1bit;

architecture behv1 of ula_1bit is

    component fa is
    port(
        a, b, cin : in  std_logic;
        s, cout   : out std_logic
    );
    end component;

    component ula_logicUnit is
    port(
        a, b    : in  std_logic;
        control : in  std_logic_vector(2 downto 0);
        result  : out std_logic
    );
    end component;

    signal b_arith  : std_logic;
    signal fa_sum   : std_logic;
    signal fa_cout  : std_logic;
    signal logic_r  : std_logic;

begin
    -- Inverte B apenas para aritmetica (subtracoa: control[2]='1')
    b_arith <= b xor control(2);

    i_fa : fa
        port map(a => a, b => b_arith, cin => cin, s => fa_sum, cout => fa_cout);

    -- Logica recebe B original (sem inversao)
    i_logic : ula_logicUnit
        port map(a => a, b => b, control => control, result => logic_r);

    -- Seleciona saida: aritmetica quando control[1]='1'
    outi <= fa_sum  when control(1) = '1' else logic_r;
    cout <= fa_cout when control(1) = '1' else '0';

end behv1;
