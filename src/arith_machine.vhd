library ieee;
use ieee.std_logic_1164.all;

-------------------------------------------------

entity arith_machine is
port(
  instr     : in  std_logic_vector(31 downto 0);

  rd_src    : in  std_logic;
  wr_enable : in  std_logic;
  ula_src2  : in  std_logic_vector(1 downto 0);
  ula_op    : in  std_logic_vector(2 downto 0);

  clk       : in  std_logic;
  reset     : in  std_logic;

  overflow  : out std_logic;
  zero      : out std_logic;
  negative  : out std_logic;
  ula_out   : out std_logic_vector(31 downto 0)
);
end arith_machine;

-------------------------------------------------

architecture behv1 of arith_machine is

    -- --------------------------------------------------------
    -- Declaracao dos componentes
    -- --------------------------------------------------------

    component reg_file is
    port(
       clk    : in  std_logic;
       rst    : in  std_logic;
       A_addr : in  std_logic_vector(4 downto 0);
       B_addr : in  std_logic_vector(4 downto 0);
       W_addr : in  std_logic_vector(4 downto 0);
       W_data : in  std_logic_vector(31 downto 0);
       W_en   : in  std_logic;
       A_data : out std_logic_vector(31 downto 0);
       B_data : out std_logic_vector(31 downto 0)
    );
    end component;

    component ula_numeric is
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

    component sign_extender is
    port(
        in_16  : in  std_logic_vector(15 downto 0);
        out_32 : out std_logic_vector(31 downto 0)
    );
    end component;

    component zero_extender is
    port(
        in_16  : in  std_logic_vector(15 downto 0);
        out_32 : out std_logic_vector(31 downto 0)
    );
    end component;

    -- --------------------------------------------------------
    -- Sinais internos
    -- --------------------------------------------------------

    -- Campos decodificados da instrucao
    signal rs    : std_logic_vector(4 downto 0);   -- instr[25:21]
    signal rt    : std_logic_vector(4 downto 0);   -- instr[20:16]
    signal rd    : std_logic_vector(4 downto 0);   -- instr[15:11]
    signal imm16 : std_logic_vector(15 downto 0);  -- instr[15:0]

    -- Mux W_addr
    signal w_addr_s : std_logic_vector(4 downto 0);

    -- Saidas do banco de registradores
    signal a_data_s : std_logic_vector(31 downto 0);
    signal b_data_s : std_logic_vector(31 downto 0);

    -- Saidas dos extenders
    signal sign_ext_s : std_logic_vector(31 downto 0);
    signal zero_ext_s : std_logic_vector(31 downto 0);

    -- Mux B da ULA e resultado
    signal ula_b_s   : std_logic_vector(31 downto 0);
    signal ula_out_s : std_logic_vector(31 downto 0);

begin

    -- --------------------------------------------------------
    -- Decodificacao dos campos da instrucao
    -- --------------------------------------------------------
    rs    <= instr(25 downto 21);
    rt    <= instr(20 downto 16);
    rd    <= instr(15 downto 11);
    imm16 <= instr(15 downto 0);

    -- --------------------------------------------------------
    -- Mux W_addr: rd_src=0 -> rt (tipo I), rd_src=1 -> rd (tipo R)
    -- --------------------------------------------------------
    w_addr_s <= rd when rd_src = '1' else rt;

    -- --------------------------------------------------------
    -- Instanciacao: banco de registradores
    -- W_data recebe o resultado da ULA (escrita de volta)
    -- --------------------------------------------------------
    i_reg_file : reg_file
    port map(
        clk    => clk,
        rst    => reset,
        A_addr => rs,
        B_addr => rt,
        W_addr => w_addr_s,
        W_data => ula_out_s,
        W_en   => wr_enable,
        A_data => a_data_s,
        B_data => b_data_s
    );

    -- --------------------------------------------------------
    -- Instanciacao: extenders de imediato
    -- --------------------------------------------------------
    i_sign_ext : sign_extender
    port map(
        in_16  => imm16,
        out_32 => sign_ext_s
    );

    i_zero_ext : zero_extender
    port map(
        in_16  => imm16,
        out_32 => zero_ext_s
    );

    -- --------------------------------------------------------
    -- Mux B da ULA (ula_src2):
    --   "00" -> B_data   (registrador rt)
    --   "01" -> sign_ext (imediato com extensao de sinal)
    --   "10" -> zero_ext (imediato com extensao de zero)
    --   "11" -> B_data   (default)
    -- --------------------------------------------------------
    with ula_src2 select
        ula_b_s <= b_data_s   when "00",
                   sign_ext_s when "01",
                   zero_ext_s when "10",
                   b_data_s   when others;

    -- --------------------------------------------------------
    -- Instanciacao: ULA
    -- --------------------------------------------------------
    i_ula : ula_numeric
    port map(
        A             => a_data_s,
        B             => ula_b_s,
        control       => ula_op,
        result        => ula_out_s,
        flag_neg      => negative,
        flag_zero     => zero,
        flag_overflow => overflow
    );

    ula_out <= ula_out_s;

end behv1;
