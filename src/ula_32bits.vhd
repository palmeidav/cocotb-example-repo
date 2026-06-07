library ieee;
use ieee.std_logic_1164.all;

entity ula_32bits is
port(
    a, b    : in  std_logic_vector(31 downto 0);
    control : in  std_logic_vector( 2 downto 0);
    outi    : out std_logic_vector(31 downto 0);
    cout    : out std_logic;
    cout30  : out std_logic
);
end ula_32bits;

architecture behv1 of ula_32bits is

    component ula_1bit is
    port(
        a, b, cin : in  std_logic;
        control   : in  std_logic_vector(2 downto 0);
        outi, cout: out std_logic
    );
    end component;

    signal carry : std_logic_vector(32 downto 0);

begin
    -- carry_in = control[2]: 1 para subtracao, 0 para demais
    carry(0) <= control(2);

    GEN_ULA: for i in 0 to 31 generate
        ULA_BIT: ula_1bit
            port map(
                a       => a(i),
                b       => b(i),
                cin     => carry(i),
                control => control,
                outi    => outi(i),
                cout    => carry(i + 1)
            );
    end generate GEN_ULA;

    cout   <= carry(32);   -- c_out31
    cout30 <= carry(31);   -- c_out30 (para calculo de overflow)

end behv1;
