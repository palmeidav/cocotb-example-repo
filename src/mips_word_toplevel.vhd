library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- MIPS single-cycle processor - Rubrica C
-- Instrucoes suportadas:
--   R-type : addu, subu, and, or, xor, nor, sll, srl, sltu, jr
--   I-type : addiu, andi, ori, xori, sltiu, lw, lbu, lhu, sw, sb, sh, beq, bne
--   J-type : j, jal

entity mips_word_toplevel is
    port (
        clk   : in  std_logic;
        reset : in  std_logic;
        ledr  : out std_logic_vector(9 downto 0);
        hex0  : out std_logic_vector(6 downto 0);
        hex1  : out std_logic_vector(6 downto 0)
    );
end entity;

architecture bhv of mips_word_toplevel is

    -- ----------------------------------------------------------
    -- Componentes
    -- ----------------------------------------------------------
    component mips_rom is
        generic (dataWidth : natural := 32; addrWidth : natural := 6);
        port (addr : in  std_logic_vector(5  downto 0);
              data : out std_logic_vector(31 downto 0));
    end component;

    component mips_ram is
        port (clk      : in  std_logic;
              addr     : in  std_logic_vector(31 downto 0);
              data_in  : in  std_logic_vector(31 downto 0);
              data_out : out std_logic_vector(31 downto 0);
              word_we  : in  std_logic;
              byte_we  : in  std_logic;
              half_we  : in  std_logic;
              reset    : in  std_logic);
    end component;

    component reg_file_mips is
        port (clk    : in  std_logic;
              rst    : in  std_logic;
              A_addr : in  std_logic_vector(4  downto 0);
              B_addr : in  std_logic_vector(4  downto 0);
              W_addr : in  std_logic_vector(4  downto 0);
              W_data : in  std_logic_vector(31 downto 0);
              W_en   : in  std_logic;
              A_data : out std_logic_vector(31 downto 0);
              B_data : out std_logic_vector(31 downto 0));
    end component;

    component ula_numeric is
        port (A             : in  std_logic_vector(31 downto 0);
              B             : in  std_logic_vector(31 downto 0);
              control       : in  std_logic_vector(2  downto 0);
              result        : out std_logic_vector(31 downto 0);
              flag_neg      : out std_logic;
              flag_zero     : out std_logic;
              flag_overflow : out std_logic);
    end component;

    component sign_extender is
        port (in_16  : in  std_logic_vector(15 downto 0);
              out_32 : out std_logic_vector(31 downto 0));
    end component;

    component zero_extender is
        port (in_16  : in  std_logic_vector(15 downto 0);
              out_32 : out std_logic_vector(31 downto 0));
    end component;

    -- ----------------------------------------------------------
    -- PC
    -- ----------------------------------------------------------
    signal pc         : std_logic_vector(31 downto 0) := (others => '0');
    signal pc_plus4   : std_logic_vector(31 downto 0);
    signal pc_next    : std_logic_vector(31 downto 0);
    signal branch_addr: std_logic_vector(31 downto 0);
    signal jump_addr  : std_logic_vector(31 downto 0);

    -- ----------------------------------------------------------
    -- Campos da instrucao
    -- ----------------------------------------------------------
    signal inst     : std_logic_vector(31 downto 0);
    signal opcode   : std_logic_vector(5  downto 0);
    signal rs       : std_logic_vector(4  downto 0);
    signal rt       : std_logic_vector(4  downto 0);
    signal rd_f     : std_logic_vector(4  downto 0);
    signal funct    : std_logic_vector(5  downto 0);
    signal imm16    : std_logic_vector(15 downto 0);
    signal target26 : std_logic_vector(25 downto 0);
    signal shamt    : std_logic_vector(4  downto 0);

    -- ----------------------------------------------------------
    -- Banco de registradores
    -- ----------------------------------------------------------
    signal w_addr_s : std_logic_vector(4  downto 0);
    signal w_data_s : std_logic_vector(31 downto 0);
    signal a_data_s : std_logic_vector(31 downto 0);
    signal b_data_s : std_logic_vector(31 downto 0);

    -- ----------------------------------------------------------
    -- ULA
    -- ----------------------------------------------------------
    signal alu_b_s   : std_logic_vector(31 downto 0);
    signal alu_out_s : std_logic_vector(31 downto 0);
    signal alu_zero_s: std_logic;

    -- ----------------------------------------------------------
    -- Extensores
    -- ----------------------------------------------------------
    signal sign_ext_s: std_logic_vector(31 downto 0);
    signal zero_ext_s: std_logic_vector(31 downto 0);

    -- ----------------------------------------------------------
    -- Memoria de dados
    -- ----------------------------------------------------------
    signal mem_out_s : std_logic_vector(31 downto 0);
    signal mem_wb_s  : std_logic_vector(31 downto 0);
    signal mem_byte_s: std_logic_vector(31 downto 0);
    signal mem_half_s: std_logic_vector(31 downto 0);

    -- ----------------------------------------------------------
    -- Sinais de controle
    -- ----------------------------------------------------------
    signal alu_op       : std_logic_vector(2 downto 0);
    signal write_enable : std_logic;
    signal rd_src       : std_logic;
    signal alu_src2     : std_logic_vector(1 downto 0);
    signal control_type : std_logic_vector(1 downto 0);
    signal word_we      : std_logic;
    signal byte_we      : std_logic;
    signal half_we      : std_logic;
    signal mem_read     : std_logic;
    signal is_bne       : std_logic;
    signal is_jal       : std_logic;
    signal is_shift     : std_logic;
    signal shift_left_f : std_logic;
    signal is_sltu      : std_logic;
    signal is_slt       : std_logic;
    signal is_sltiu     : std_logic;
    signal is_lbu       : std_logic;
    signal is_lhu       : std_logic;
    signal branch_taken : std_logic;

    -- Resultados especiais
    signal shift_result_s: std_logic_vector(31 downto 0);
    signal slt_result_s  : std_logic_vector(31 downto 0);
    signal mem_byte_off_s: std_logic_vector(31 downto 0);
    signal mem_half_off_s: std_logic_vector(31 downto 0);

    -- ----------------------------------------------------------
    -- Divisor de clock: 50 MHz / 10_000_000 = 5 instrucoes/s
    -- ----------------------------------------------------------
    signal div_cnt       : unsigned(23 downto 0) := (others => '0');
    signal tick          : std_logic;

    -- Sinais de escrita gateados pelo tick
    signal word_we_gated : std_logic;
    signal byte_we_gated : std_logic;
    signal half_we_gated : std_logic;

begin

    -- ----------------------------------------------------------
    -- Decodificacao dos campos da instrucao
    -- ----------------------------------------------------------
    opcode   <= inst(31 downto 26);
    rs       <= inst(25 downto 21);
    rt       <= inst(20 downto 16);
    rd_f     <= inst(15 downto 11);
    funct    <= inst(5  downto  0);
    imm16    <= inst(15 downto  0);
    target26 <= inst(25 downto  0);
    shamt    <= inst(10 downto  6);

    -- ----------------------------------------------------------
    -- Calculos de PC
    -- ----------------------------------------------------------
    pc_plus4    <= std_logic_vector(unsigned(pc) + 4);
    branch_addr <= std_logic_vector(unsigned(pc_plus4) +
                                    unsigned(sign_ext_s(29 downto 0) & "00"));
    jump_addr   <= pc_plus4(31 downto 28) & target26 & "00";

    -- ----------------------------------------------------------
    -- Decoder: Rubrica C apenas
    -- ----------------------------------------------------------
    process(opcode, funct)
    begin
        -- defaults
        alu_op       <= "010";
        write_enable <= '0';
        rd_src       <= '0';
        alu_src2     <= "00";
        control_type <= "00";
        word_we      <= '0';
        byte_we      <= '0';
        half_we      <= '0';
        mem_read     <= '0';
        is_bne       <= '0';
        is_jal       <= '0';
        is_shift     <= '0';
        shift_left_f <= '0';
        is_sltu      <= '0';
        is_slt       <= '0';
        is_sltiu     <= '0';
        is_lbu       <= '0';
        is_lhu       <= '0';

        case opcode is

            when "000000" =>  -- R-type
                rd_src       <= '1';
                write_enable <= '1';
                case funct is
                    when "100000" => alu_op <= "010";             -- add  (bonus)
                    when "100001" => alu_op <= "010";             -- addu
                    when "100010" => alu_op <= "011";             -- sub  (bonus)
                    when "100011" => alu_op <= "011";             -- subu
                    when "100100" => alu_op <= "100";             -- and
                    when "100101" => alu_op <= "101";             -- or
                    when "100110" => alu_op <= "111";             -- xor
                    when "100111" => alu_op <= "110";             -- nor
                    when "101010" => is_slt  <= '1';              -- slt  (bonus)
                    when "101011" => is_sltu <= '1';              -- sltu
                    when "000000" => is_shift <= '1'; shift_left_f <= '1'; -- sll
                    when "000010" => is_shift <= '1';             -- srl
                    when "001000" =>                              -- jr
                        write_enable <= '0';
                        rd_src       <= '0';
                        control_type <= "11";
                    when others => null;
                end case;

            when "001000" =>  -- addi (bonus)
                write_enable <= '1'; alu_src2 <= "01";

            when "001001" =>  -- addiu
                write_enable <= '1'; alu_src2 <= "01";

            when "001100" =>  -- andi
                alu_op <= "100"; write_enable <= '1'; alu_src2 <= "10";

            when "001101" =>  -- ori
                alu_op <= "101"; write_enable <= '1'; alu_src2 <= "10";

            when "001110" =>  -- xori
                alu_op <= "111"; write_enable <= '1'; alu_src2 <= "10";

            when "001011" =>  -- sltiu
                write_enable <= '1'; alu_src2 <= "01"; is_sltiu <= '1';

            when "100011" =>  -- lw
                write_enable <= '1'; alu_src2 <= "01"; mem_read <= '1';

            when "100100" =>  -- lbu
                write_enable <= '1'; alu_src2 <= "01";
                mem_read <= '1'; is_lbu <= '1';

            when "100101" =>  -- lhu
                write_enable <= '1'; alu_src2 <= "01";
                mem_read <= '1'; is_lhu <= '1';

            when "101011" =>  -- sw
                alu_src2 <= "01"; word_we <= '1';

            when "101000" =>  -- sb
                alu_src2 <= "01"; byte_we <= '1';

            when "101001" =>  -- sh
                alu_src2 <= "01"; half_we <= '1';

            when "000100" =>  -- beq
                alu_op <= "011"; control_type <= "01";

            when "000101" =>  -- bne
                alu_op <= "011"; control_type <= "01"; is_bne <= '1';

            when "000010" =>  -- j
                control_type <= "10";

            when "000011" =>  -- jal
                write_enable <= '1'; control_type <= "10"; is_jal <= '1';

            when others => null;
        end case;
    end process;

    -- ----------------------------------------------------------
    -- SLTU / SLTIU
    -- ----------------------------------------------------------
    slt_result_s <=
        x"00000001" when (is_slt   = '1' and   signed(a_data_s) <   signed(b_data_s))   else
        x"00000001" when (is_sltu  = '1' and unsigned(a_data_s) < unsigned(b_data_s))   else
        x"00000001" when (is_sltiu = '1' and unsigned(a_data_s) < unsigned(sign_ext_s)) else
        x"00000000";

    -- ----------------------------------------------------------
    -- Shift: SLL / SRL
    -- ----------------------------------------------------------
    shift_result_s <=
        std_logic_vector(shift_left (unsigned(b_data_s), to_integer(unsigned(shamt)))) when shift_left_f = '1' else
        std_logic_vector(shift_right(unsigned(b_data_s), to_integer(unsigned(shamt))));

    -- ----------------------------------------------------------
    -- Load byte/halfword com offset de endereco
    -- ----------------------------------------------------------
    mem_byte_off_s <=
        x"000000" & mem_out_s( 7 downto  0) when alu_out_s(1 downto 0) = "00" else
        x"000000" & mem_out_s(15 downto  8) when alu_out_s(1 downto 0) = "01" else
        x"000000" & mem_out_s(23 downto 16) when alu_out_s(1 downto 0) = "10" else
        x"000000" & mem_out_s(31 downto 24);

    mem_half_off_s <=
        x"0000" & mem_out_s(15 downto  0) when alu_out_s(1) = '0' else
        x"0000" & mem_out_s(31 downto 16);

    mem_wb_s <= mem_byte_off_s when is_lbu = '1' else
                mem_half_off_s when is_lhu = '1' else
                mem_out_s;

    -- ----------------------------------------------------------
    -- Branch taken
    -- ----------------------------------------------------------
    branch_taken <= alu_zero_s xor is_bne;

    -- ----------------------------------------------------------
    -- MUX: proximo PC
    -- ----------------------------------------------------------
    process(control_type, branch_taken, pc_plus4, branch_addr, jump_addr, a_data_s)
    begin
        case control_type is
            when "01"   =>
                if branch_taken = '1' then pc_next <= branch_addr;
                else                        pc_next <= pc_plus4;
                end if;
            when "10"   => pc_next <= jump_addr;
            when "11"   => pc_next <= a_data_s;
            when others => pc_next <= pc_plus4;
        end case;
    end process;

    -- Divisor de clock
    process(clk, reset)
    begin
        if reset = '1' then
            div_cnt <= (others => '0');
        elsif rising_edge(clk) then
            if div_cnt = 9_999_999 then
                div_cnt <= (others => '0');
            else
                div_cnt <= div_cnt + 1;
            end if;
        end if;
    end process;

    tick <= '1' when div_cnt = 0 else '0';

    -- Sinais de escrita na RAM gateados pelo tick
    word_we_gated <= word_we and tick;
    byte_we_gated <= byte_we and tick;
    half_we_gated <= half_we and tick;

    -- Registrador PC (avanca so no tick)
    process(clk, reset)
    begin
        if reset = '1' then
            pc <= (others => '0');
        elsif rising_edge(clk) then
            if tick = '1' then
                pc <= pc_next;
            end if;
        end if;
    end process;

    -- ----------------------------------------------------------
    -- MUX: operando B da ULA
    -- ----------------------------------------------------------
    with alu_src2 select
        alu_b_s <= b_data_s   when "00",
                   sign_ext_s when "01",
                   zero_ext_s when "10",
                   b_data_s   when others;

    -- ----------------------------------------------------------
    -- MUX: endereco de escrita no banco
    -- ----------------------------------------------------------
    w_addr_s <= "11111" when is_jal  = '1' else
                rd_f    when rd_src  = '1' else
                rt;

    -- ----------------------------------------------------------
    -- MUX: dado de escrita no banco
    -- ----------------------------------------------------------
    w_data_s <= pc_plus4        when is_jal   = '1' else
                mem_wb_s        when mem_read  = '1' else
                slt_result_s    when (is_slt or is_sltu or is_sltiu) = '1' else
                shift_result_s  when is_shift  = '1' else
                alu_out_s;

    -- ----------------------------------------------------------
    -- Instancias
    -- ----------------------------------------------------------
    i_rom : mips_rom
        port map (addr => pc(7 downto 2), data => inst);

    i_rf : reg_file_mips
        port map (clk    => clk,    rst    => reset,
                  A_addr => rs,     B_addr => rt,
                  W_addr => w_addr_s, W_data => w_data_s,
                  W_en   => write_enable and tick,
                  A_data => a_data_s, B_data => b_data_s);

    i_se : sign_extender
        port map (in_16 => imm16, out_32 => sign_ext_s);

    i_ze : zero_extender
        port map (in_16 => imm16, out_32 => zero_ext_s);

    i_alu : ula_numeric
        port map (A => a_data_s, B => alu_b_s, control => alu_op,
                  result => alu_out_s, flag_neg => open,
                  flag_zero => alu_zero_s, flag_overflow => open);

    i_ram : mips_ram
        port map (clk => clk, addr => alu_out_s,
                  data_in => b_data_s, data_out => mem_out_s,
                  word_we => word_we_gated, byte_we => byte_we_gated,
                  half_we => half_we_gated, reset => reset);

    -- ----------------------------------------------------------
    -- Saidas de debug: LEDs = ULA[9:0], displays = PC em hex
    -- ----------------------------------------------------------
    ledr <= alu_out_s(9 downto 0);

    with pc(3 downto 0) select
        hex0 <= "1000000" when x"0", "1111001" when x"1",
                "0100100" when x"2", "0110000" when x"3",
                "0011001" when x"4", "0010010" when x"5",
                "0000010" when x"6", "1111000" when x"7",
                "0000000" when x"8", "0010000" when x"9",
                "0001000" when x"A", "0000011" when x"B",
                "1000110" when x"C", "0100001" when x"D",
                "0000110" when x"E", "0001110" when others;

    with pc(7 downto 4) select
        hex1 <= "1000000" when x"0", "1111001" when x"1",
                "0100100" when x"2", "0110000" when x"3",
                "0011001" when x"4", "0010010" when x"5",
                "0000010" when x"6", "1111000" when x"7",
                "0000000" when x"8", "0010000" when x"9",
                "0001000" when x"A", "0000011" when x"B",
                "1000110" when x"C", "0100001" when x"D",
                "0000110" when x"E", "0001110" when others;

end architecture;
