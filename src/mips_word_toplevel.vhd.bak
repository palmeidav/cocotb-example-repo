library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity mips_word_toplevel is
    port (
        clk   : in std_logic;
        reset : in std_logic
    );
end entity;

architecture bhv of mips_word_toplevel is

    component mips_rom is
        generic (
            dataWidth : natural := 32;
            addrWidth : natural := 10
        );
        port (
            addr : in  std_logic_vector(9 downto 0);
            data : out std_logic_vector(31 downto 0)
        );
    end component;

    component mips_ram is
        generic (
            dataWidth       : natural := 32;
            addrWidth       : natural := 32;
            memoryAddrWidth : natural := 10
        );
        port (
            clk      : in  std_logic;
            addr     : in  std_logic_vector(31 downto 0);
            data_in  : in  std_logic_vector(31 downto 0);
            data_out : out std_logic_vector(31 downto 0);
            word_we  : in  std_logic;
            byte_we  : in  std_logic := '0';
            half_we  : in  std_logic := '0';
            reset    : in  std_logic
        );
    end component;

    component reg_file_mips is
        port (
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

    component ULA is
        port (
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
        port (
            in_16  : in  std_logic_vector(15 downto 0);
            out_32 : out std_logic_vector(31 downto 0)
        );
    end component;

    component zero_extender is
        port (
            in_16  : in  std_logic_vector(15 downto 0);
            out_32 : out std_logic_vector(31 downto 0)
        );
    end component;

    -- PC
    signal pc        : std_logic_vector(31 downto 0) := (others => '0');
    signal pc_plus4  : std_logic_vector(31 downto 0);
    signal pc_next   : std_logic_vector(31 downto 0);

    -- Instruction fields
    signal inst      : std_logic_vector(31 downto 0);
    signal opcode    : std_logic_vector(5 downto 0);
    signal rs        : std_logic_vector(4 downto 0);
    signal rt        : std_logic_vector(4 downto 0);
    signal rd_f      : std_logic_vector(4 downto 0);
    signal funct     : std_logic_vector(5 downto 0);
    signal imm16     : std_logic_vector(15 downto 0);
    signal target26  : std_logic_vector(25 downto 0);

    -- Register file
    signal w_addr_s  : std_logic_vector(4 downto 0);
    signal w_data_s  : std_logic_vector(31 downto 0);
    signal a_data_s  : std_logic_vector(31 downto 0);
    signal b_data_s  : std_logic_vector(31 downto 0);

    -- Extenders
    signal sign_ext_s : std_logic_vector(31 downto 0);
    signal zero_ext_s : std_logic_vector(31 downto 0);

    -- ALU
    signal alu_b_s    : std_logic_vector(31 downto 0);
    signal alu_out_s  : std_logic_vector(31 downto 0);
    signal alu_zero_s : std_logic;

    -- Data memory
    signal mem_out_s  : std_logic_vector(31 downto 0);

    -- Branch / Jump addresses
    signal branch_addr : std_logic_vector(31 downto 0);
    signal jump_addr   : std_logic_vector(31 downto 0);

    -- Control signals (from decoder)
    signal alu_op        : std_logic_vector(2 downto 0);
    signal write_enable  : std_logic;
    signal rd_src        : std_logic;
    signal alu_src2      : std_logic_vector(1 downto 0);
    signal control_type  : std_logic_vector(1 downto 0);
    signal word_we       : std_logic;
    signal byte_we       : std_logic;
    signal half_we       : std_logic;
    signal mem_read      : std_logic;
    signal is_bne        : std_logic;
    signal is_jal        : std_logic;
    signal is_shift      : std_logic;
    signal shift_left_f  : std_logic;
    signal is_sltu       : std_logic;
    signal is_sltiu      : std_logic;
    signal is_slt_r      : std_logic;
    signal is_slti       : std_logic;
    signal is_slt        : std_logic;
    signal is_lbu        : std_logic;
    signal is_lhu        : std_logic;
    signal is_lb         : std_logic;
    signal is_lh         : std_logic;
    signal is_lui        : std_logic;
    signal is_sra        : std_logic;

    signal branch_taken  : std_logic;
    signal shamt         : std_logic_vector(4 downto 0);
    signal shift_result_s: std_logic_vector(31 downto 0);
    signal slt_result_s  : std_logic_vector(31 downto 0);
    signal lui_result_s  : std_logic_vector(31 downto 0);
    signal mem_byte_s    : std_logic_vector(31 downto 0);
    signal mem_half_s    : std_logic_vector(31 downto 0);
    signal mem_lb_s      : std_logic_vector(31 downto 0);
    signal mem_lh_s      : std_logic_vector(31 downto 0);
    signal mem_wb_s      : std_logic_vector(31 downto 0);

begin

    -- Instruction field slicing
    opcode   <= inst(31 downto 26);
    rs       <= inst(25 downto 21);
    rt       <= inst(20 downto 16);
    rd_f     <= inst(15 downto 11);
    funct    <= inst(5  downto  0);
    imm16    <= inst(15 downto  0);
    target26 <= inst(25 downto  0);
    shamt    <= inst(10 downto  6);

    -- PC arithmetic
    pc_plus4   <= std_logic_vector(unsigned(pc) + 4);
    branch_addr <= std_logic_vector(unsigned(pc_plus4) +
                                    unsigned(sign_ext_s(29 downto 0) & "00"));
    jump_addr  <= pc_plus4(31 downto 28) & target26 & "00";

    -- -------------------------------------------------------
    -- MIPS Instruction Decoder
    -- -------------------------------------------------------
    process(opcode, funct)
    begin
        alu_op       <= "010";   -- ADD default
        write_enable <= '0';
        rd_src       <= '0';
        alu_src2     <= "00";
        control_type <= "00";
        word_we      <= '0';
        mem_read     <= '0';
        is_bne       <= '0';
        is_jal       <= '0';
        is_shift     <= '0';
        shift_left_f <= '0';
        is_sltu      <= '0';
        is_sltiu     <= '0';
        is_slt_r     <= '0';
        is_slti      <= '0';
        is_lbu       <= '0';
        is_lhu       <= '0';
        is_lb        <= '0';
        is_lh        <= '0';
        is_lui       <= '0';
        is_sra       <= '0';
        byte_we      <= '0';
        half_we      <= '0';

        case opcode is
            when "000000" =>             -- R-type
                rd_src       <= '1';
                write_enable <= '1';
                case funct is
                    when "100000" => alu_op <= "010";            -- ADD
                    when "100001" => alu_op <= "010";            -- ADDU
                    when "100010" => alu_op <= "011";            -- SUB
                    when "100011" => alu_op <= "011";            -- SUBU
                    when "100100" => alu_op <= "100";            -- AND
                    when "100101" => alu_op <= "101";            -- OR
                    when "100110" => alu_op <= "111";            -- XOR
                    when "100111" => alu_op <= "110";            -- NOR
                    when "000000" =>                             -- SLL
                        is_shift     <= '1';
                        shift_left_f <= '1';
                    when "000010" =>                             -- SRL
                        is_shift     <= '1';
                        shift_left_f <= '0';
                    when "000011" =>                             -- SRA
                        is_shift <= '1';
                        is_sra   <= '1';
                    when "101010" =>                             -- SLT (signed)
                        is_slt_r <= '1';
                    when "101011" =>                             -- SLTU (unsigned)
                        is_sltu <= '1';
                    when "001000" =>                             -- JR
                        write_enable <= '0';
                        rd_src       <= '0';
                        control_type <= "11";
                    when others => null;
                end case;

            when "001000" =>             -- ADDI
                write_enable <= '1';
                alu_src2     <= "01";

            when "001001" =>             -- ADDIU
                write_enable <= '1';
                alu_src2     <= "01";

            when "001010" =>             -- SLTI (signed)
                write_enable <= '1';
                alu_src2     <= "01";
                is_slti      <= '1';

            when "001011" =>             -- SLTIU (unsigned)
                write_enable <= '1';
                alu_src2     <= "01";
                is_sltiu     <= '1';

            when "001111" =>             -- LUI
                write_enable <= '1';
                is_lui       <= '1';

            when "001100" =>             -- ANDI
                alu_op       <= "100";
                write_enable <= '1';
                alu_src2     <= "10";

            when "001101" =>             -- ORI
                alu_op       <= "101";
                write_enable <= '1';
                alu_src2     <= "10";

            when "001110" =>             -- XORI
                alu_op       <= "111";
                write_enable <= '1';
                alu_src2     <= "10";    -- zero extend

            when "100000" =>             -- LB (signed byte)
                write_enable <= '1';
                alu_src2     <= "01";
                mem_read     <= '1';
                is_lb        <= '1';

            when "100001" =>             -- LH (signed halfword)
                write_enable <= '1';
                alu_src2     <= "01";
                mem_read     <= '1';
                is_lh        <= '1';

            when "100011" =>             -- LW
                write_enable <= '1';
                alu_src2     <= "01";
                mem_read     <= '1';

            when "100100" =>             -- LBU
                write_enable <= '1';
                alu_src2     <= "01";
                mem_read     <= '1';
                is_lbu       <= '1';

            when "100101" =>             -- LHU
                write_enable <= '1';
                alu_src2     <= "01";
                mem_read     <= '1';
                is_lhu       <= '1';

            when "101000" =>             -- SB
                alu_src2 <= "01";
                byte_we  <= '1';

            when "101001" =>             -- SH
                alu_src2 <= "01";
                half_we  <= '1';

            when "101011" =>             -- SW
                alu_src2 <= "01";
                word_we  <= '1';

            when "000100" =>             -- BEQ
                alu_op       <= "011";
                control_type <= "01";

            when "000101" =>             -- BNE
                alu_op       <= "011";
                control_type <= "01";
                is_bne       <= '1';

            when "000010" =>             -- J
                control_type <= "10";

            when "000011" =>             -- JAL
                write_enable <= '1';
                control_type <= "10";
                is_jal       <= '1';

            when others => null;
        end case;
    end process;

    -- -------------------------------------------------------
    -- is_slt: qualquer instrucao set-less-than
    is_slt <= is_sltu or is_sltiu or is_slt_r or is_slti;

    -- SLT/SLTU: result=1 se condicao satisfeita, senao 0
    slt_result_s <=
        x"00000001" when (is_sltu  = '1' and unsigned(a_data_s) < unsigned(b_data_s))   else
        x"00000001" when (is_sltiu = '1' and unsigned(a_data_s) < unsigned(sign_ext_s)) else
        x"00000001" when (is_slt_r = '1' and   signed(a_data_s) <   signed(b_data_s))   else
        x"00000001" when (is_slti  = '1' and   signed(a_data_s) <   signed(sign_ext_s)) else
        x"00000000";

    -- LUI: imm16 nos 16 bits altos, zeros nos 16 baixos
    lui_result_s <= imm16 & x"0000";

    -- Extração byte/halfword do dado lido da memória (addr[1:0] indica offset)
    mem_byte_s <=
        x"000000" & mem_out_s( 7 downto  0) when alu_out_s(1 downto 0) = "00" else
        x"000000" & mem_out_s(15 downto  8) when alu_out_s(1 downto 0) = "01" else
        x"000000" & mem_out_s(23 downto 16) when alu_out_s(1 downto 0) = "10" else
        x"000000" & mem_out_s(31 downto 24);

    mem_half_s <=
        x"0000" & mem_out_s(15 downto 0) when alu_out_s(1) = '0' else
        x"0000" & mem_out_s(31 downto 16);

    -- LB/LH: sign-extend byte/halfword selecionado
    mem_lb_s <=
        std_logic_vector(resize(signed(mem_out_s( 7 downto  0)), 32)) when alu_out_s(1 downto 0) = "00" else
        std_logic_vector(resize(signed(mem_out_s(15 downto  8)), 32)) when alu_out_s(1 downto 0) = "01" else
        std_logic_vector(resize(signed(mem_out_s(23 downto 16)), 32)) when alu_out_s(1 downto 0) = "10" else
        std_logic_vector(resize(signed(mem_out_s(31 downto 24)), 32));

    mem_lh_s <=
        std_logic_vector(resize(signed(mem_out_s(15 downto  0)), 32)) when alu_out_s(1) = '0' else
        std_logic_vector(resize(signed(mem_out_s(31 downto 16)), 32));

    mem_wb_s <= mem_byte_s when is_lbu = '1' else
                mem_half_s when is_lhu = '1' else
                mem_lb_s   when is_lb  = '1' else
                mem_lh_s   when is_lh  = '1' else
                mem_out_s;

    -- Shift result: SLL ou SRL usando shamt e B_data (rt)
    shift_result_s <=
        std_logic_vector(shift_left (unsigned(b_data_s),  to_integer(unsigned(shamt)))) when shift_left_f = '1' else
        std_logic_vector(shift_right(  signed(b_data_s),  to_integer(unsigned(shamt)))) when is_sra       = '1' else
        std_logic_vector(shift_right(unsigned(b_data_s),  to_integer(unsigned(shamt))));

    -- -------------------------------------------------------
    -- Branch condition
    -- BEQ taken if zero=1; BNE taken if zero=0
    -- -------------------------------------------------------
    branch_taken <= alu_zero_s xor is_bne;

    -- -------------------------------------------------------
    -- Next PC MUX
    -- control_type: 00=PC+4  01=branch  10=jump  11=JR
    -- -------------------------------------------------------
    process(control_type, branch_taken, pc_plus4, branch_addr, jump_addr, a_data_s)
    begin
        case control_type is
            when "01" =>
                if branch_taken = '1' then
                    pc_next <= branch_addr;
                else
                    pc_next <= pc_plus4;
                end if;
            when "10"   => pc_next <= jump_addr;
            when "11"   => pc_next <= a_data_s;
            when others => pc_next <= pc_plus4;
        end case;
    end process;

    -- PC register
    process(clk, reset)
    begin
        if reset = '1' then
            pc <= (others => '0');
        elsif rising_edge(clk) then
            pc <= pc_next;
        end if;
    end process;

    -- -------------------------------------------------------
    -- MUX: ALU second operand
    -- "00" = B_data   "01" = sign_ext   "10" = zero_ext
    -- -------------------------------------------------------
    with alu_src2 select
        alu_b_s <= b_data_s   when "00",
                   sign_ext_s when "01",
                   zero_ext_s when "10",
                   b_data_s   when others;

    -- -------------------------------------------------------
    -- MUX: Register write address
    -- JAL -> R31,  R-type -> rd,  I-type -> rt
    -- -------------------------------------------------------
    w_addr_s <= "11111" when is_jal = '1' else
                rd_f    when rd_src  = '1' else
                rt;

    -- -------------------------------------------------------
    -- MUX: Register write data
    -- JAL -> PC+4,  LW -> mem_out,  others -> alu_out
    -- -------------------------------------------------------
    w_data_s <= pc_plus4       when is_jal   = '1' else
                lui_result_s   when is_lui   = '1' else
                mem_wb_s       when mem_read  = '1' else
                slt_result_s   when is_slt   = '1' else
                shift_result_s when is_shift  = '1' else
                alu_out_s;

    -- -------------------------------------------------------
    -- Component instantiations
    -- -------------------------------------------------------

    i_rom : mips_rom
        port map (
            addr => pc(11 downto 2),
            data => inst
        );

    i_regfile : reg_file_mips
        port map (
            clk    => clk,
            rst    => reset,
            A_addr => rs,
            B_addr => rt,
            W_addr => w_addr_s,
            W_data => w_data_s,
            W_en   => write_enable,
            A_data => a_data_s,
            B_data => b_data_s
        );

    i_sign_ext : sign_extender
        port map (
            in_16  => imm16,
            out_32 => sign_ext_s
        );

    i_zero_ext : zero_extender
        port map (
            in_16  => imm16,
            out_32 => zero_ext_s
        );

    i_alu : ULA
        port map (
            A             => a_data_s,
            B             => alu_b_s,
            control       => alu_op,
            result        => alu_out_s,
            flag_neg      => open,
            flag_zero     => alu_zero_s,
            flag_overflow => open
        );

    i_ram : mips_ram
        port map (
            clk      => clk,
            addr     => alu_out_s,
            data_in  => b_data_s,
            data_out => mem_out_s,
            word_we  => word_we,
            byte_we  => byte_we,
            half_we  => half_we,
            reset    => reset
        );

end architecture;
