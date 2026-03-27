library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-------------------------------------------------
-- Toplevel para testar a maquina aritmetica MIPS
--
-- BTN avanca o contador de instrucoes (0-7)
-- Instrucoes pre-definidas testam: ADD, SUB, AND, OR
-- LED[9:0] exibe ula_out[9:0]
-- HEX0     exibe o numero da instrucao atual
-------------------------------------------------

entity toplevel_mips is
port(
    clk  : in  std_logic;
    btn  : in  std_logic;              -- avanca instrucao (borda de subida)
    rst  : in  std_logic;              -- reset ativo alto
    led  : out std_logic_vector(9 downto 0);
    hex0 : out std_logic_vector(6 downto 0)  -- display 7-seg (active low)
);
end toplevel_mips;

-------------------------------------------------

architecture behv1 of toplevel_mips is

    constant NUM_INSTR : integer := 8;

    -- --------------------------------------------------------
    -- Declaracao da maquina aritmetica
    -- --------------------------------------------------------
    component arith_machine is
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
    end component;

    -- --------------------------------------------------------
    -- Tipos dos ROMs de instrucao e controle
    -- --------------------------------------------------------
    type instr_rom_t is array (0 to NUM_INSTR-1) of std_logic_vector(31 downto 0);
    type bit1_rom_t  is array (0 to NUM_INSTR-1) of std_logic;
    type bit2_rom_t  is array (0 to NUM_INSTR-1) of std_logic_vector(1 downto 0);
    type bit3_rom_t  is array (0 to NUM_INSTR-1) of std_logic_vector(2 downto 0);

    -- --------------------------------------------------------
    -- ROM de instrucoes (campos: rs[25:21] rt[20:16] rd[15:11] imm[15:0])
    --
    --  0: R1 <- R0 + sign_ext(5) = 5   rs=00000 rt=00001 imm=0x0005
    --  1: R2 <- R0 + sign_ext(3) = 3   rs=00000 rt=00010 imm=0x0003
    --  2: R3 <- R1 + R2          = 8   rs=00001 rt=00010 rd=00011
    --  3: R4 <- R1 - R2          = 2   rs=00001 rt=00010 rd=00100
    --  4: R5 <- R1 AND R2        = 1   rs=00001 rt=00010 rd=00101
    --  5: R6 <- R1 OR  R2        = 7   rs=00001 rt=00010 rd=00110
    --  6: out <- R3 + R0 (exibe R3=8)  rs=00011 rt=00000 (so write)
    --  7: out <- R4 + R0 (exibe R4=2)  rs=00100 rt=00000 (so write)
    -- --------------------------------------------------------
    constant INSTR_ROM : instr_rom_t := (
        0 => x"00010005",   -- rs=R0 rt=R1 imm=5
        1 => x"00020003",   -- rs=R0 rt=R2 imm=3
        2 => x"00221800",   -- rs=R1 rt=R2 rd=R3
        3 => x"00222000",   -- rs=R1 rt=R2 rd=R4
        4 => x"00222800",   -- rs=R1 rt=R2 rd=R5
        5 => x"00223000",   -- rs=R1 rt=R2 rd=R6
        6 => x"00600000",   -- rs=R3 rt=R0
        7 => x"00800000"    -- rs=R4 rt=R0
    );

    -- rd_src: 0=W_addr<-rt  1=W_addr<-rd
    constant RD_SRC_ROM : bit1_rom_t := ('0','0','1','1','1','1','0','0');

    -- wr_enable: instrucoes 6 e 7 apenas leem (sem escrita)
    constant WR_EN_ROM  : bit1_rom_t := ('1','1','1','1','1','1','0','0');

    -- ula_src2: "01"=sign_ext  "00"=registrador B
    constant SRC2_ROM   : bit2_rom_t := ("01","01","00","00","00","00","00","00");

    -- ula_op: 010=ADD  011=SUB  100=AND  101=OR
    constant OP_ROM     : bit3_rom_t := ("010","010","010","011","100","101","010","010");

    -- --------------------------------------------------------
    -- Tabela 7-segmentos (active low, DE10)
    -- HEX[6:0] = {g,f,e,d,c,b,a}
    -- --------------------------------------------------------
    type seg7_t is array (0 to 9) of std_logic_vector(6 downto 0);
    constant SEG7 : seg7_t := (
        0 => "1000000",   -- 0
        1 => "1111001",   -- 1
        2 => "0100100",   -- 2
        3 => "0110000",   -- 3
        4 => "0011001",   -- 4
        5 => "0010010",   -- 5
        6 => "0000010",   -- 6
        7 => "1111000",   -- 7
        8 => "0000000",   -- 8
        9 => "0010000"    -- 9
    );

    -- --------------------------------------------------------
    -- Sinais internos
    -- --------------------------------------------------------
    signal cnt       : integer range 0 to NUM_INSTR-1 := 0;
    signal btn_prev  : std_logic := '0';
    signal btn_pulse : std_logic;

    signal instr_s    : std_logic_vector(31 downto 0);
    signal rd_src_s   : std_logic;
    signal wr_en_s    : std_logic;
    signal ula_src2_s : std_logic_vector(1 downto 0);
    signal ula_op_s   : std_logic_vector(2 downto 0);
    signal ula_out_s  : std_logic_vector(31 downto 0);

begin

    -- --------------------------------------------------------
    -- Deteccao de borda de subida do botao
    -- --------------------------------------------------------
    process(clk)
    begin
        if rising_edge(clk) then
            btn_prev <= btn;
        end if;
    end process;

    btn_pulse <= btn and (not btn_prev);

    -- --------------------------------------------------------
    -- Contador de instrucoes: avanca em cada pulso do botao
    -- --------------------------------------------------------
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                cnt <= 0;
            elsif btn_pulse = '1' then
                if cnt = NUM_INSTR - 1 then
                    cnt <= 0;
                else
                    cnt <= cnt + 1;
                end if;
            end if;
        end if;
    end process;

    -- --------------------------------------------------------
    -- Selecao de instrucao e controles pelo contador
    -- --------------------------------------------------------
    instr_s    <= INSTR_ROM(cnt);
    rd_src_s   <= RD_SRC_ROM(cnt);
    wr_en_s    <= WR_EN_ROM(cnt);
    ula_src2_s <= SRC2_ROM(cnt);
    ula_op_s   <= OP_ROM(cnt);

    -- --------------------------------------------------------
    -- Instanciacao da maquina aritmetica
    -- --------------------------------------------------------
    i_arith : arith_machine
    port map(
        instr     => instr_s,
        rd_src    => rd_src_s,
        wr_enable => wr_en_s,
        ula_src2  => ula_src2_s,
        ula_op    => ula_op_s,
        clk       => clk,
        reset     => rst,
        overflow  => open,
        zero      => open,
        negative  => open,
        ula_out   => ula_out_s
    );

    -- --------------------------------------------------------
    -- Saidas: LED exibe os 10 bits baixos do resultado
    -- --------------------------------------------------------
    led <= ula_out_s(9 downto 0);

    -- --------------------------------------------------------
    -- Display 7-seg: exibe numero da instrucao atual (0-7)
    -- --------------------------------------------------------
    hex0 <= SEG7(cnt);

end behv1;
