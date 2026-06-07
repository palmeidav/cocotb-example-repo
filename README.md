# Processador MIPS Single-Cycle — APS-1

Implementação completa de um processador MIPS de 32 bits, single-cycle, em VHDL. O processador é capaz de executar um subconjunto das instruções MIPS e foi validado com testes automatizados via cocotb e sintetizado em FPGA (DE10-Lite / Cyclone V).

---

## O que o projeto faz

O processador busca instruções de uma memória ROM, decodifica e executa cada instrução em um único ciclo de clock. Ele suporta operações aritméticas, lógicas, de memória, desvio condicional e salto, implementando o datapath clássico MIPS.

---

## Arquitetura

O datapath segue o modelo MIPS single-cycle com os seguintes estágios em um único ciclo:

```
ROM → Decodificador → Banco de Registradores → ULA → RAM → Write-back
```

### Componentes implementados

| Arquivo | Componente | Descrição |
|---|---|---|
| `ula_fullAdder.vhd` | `fa` | Somador completo de 1 bit |
| `ula_logicUnit.vhd` | `ula_logicUnit` | Unidade lógica de 1 bit (AND, OR, NOR, XOR) |
| `ula_1bit.vhd` | `ula_1bit` | ULA de 1 bit (aritmética + lógica) |
| `ula_32bits.vhd` | `ula_32bits` | ULA de 32 bits (32 instâncias da ula_1bit) |
| `ula_flags.vhd` | `flags` | Gerador de flags (zero, negativo, overflow) |
| `ula.vhd` | `ULA` | ULA completa estrutural de 32 bits |
| `reg_file_mips.vhd` | `reg_file_mips` | Banco de 32 registradores de 32 bits |
| `sign_extender.vhd` | `sign_extender` | Extensão de sinal de 16 para 32 bits |
| `zero_extender.vhd` | `zero_extender` | Extensão com zero de 16 para 32 bits |
| `arith_machine.vhd` | `arith_machine` | Máquina aritmética (ULA + banco de registradores) |
| `mips_rom.vhd` | `mips_rom` | Memória de instrução (ROM, 1024 × 32 bits) |
| `mips_ram.vhd` | `mips_ram` | Memória de dados (RAM, 1024 × 32 bits, com suporte a byte/halfword) |
| `mips_word_toplevel.vhd` | `mips_word_toplevel` | Processador MIPS completo (toplevel final) |
| `toplevel_ula.vhd` | `toplevel_ula` | Toplevel para teste da ULA no hardware |

---

## Instruções suportadas

### Rubrica C (obrigatório)

| Tipo | Instruções |
|---|---|
| R-type | `add`, `addu`, `sub`, `subu`, `and`, `or`, `xor`, `nor`, `sll`, `srl`, `sltu`, `jr` |
| I-type | `addi`, `addiu`, `andi`, `ori`, `xori`, `sltiu`, `lw`, `sw`, `lbu`, `lhu`, `sb`, `sh`, `beq`, `bne` |
| J-type | `j`, `jal` |

### Pontos extras

| Tipo | Instruções |
|---|---|
| R-type | `slt`, `sra` |
| I-type | `slti`, `lb`, `lh`, `lui` |

---

## Estrutura do repositório

```
.
├── src/                        # Código VHDL
│   ├── mips_word_toplevel.vhd  # Processador completo
│   ├── mips_rom.vhd            # Memória de instrução
│   ├── mips_ram.vhd            # Memória de dados
│   ├── ula.vhd                 # ULA estrutural
│   ├── ula_32bits.vhd
│   ├── ula_1bit.vhd
│   ├── ula_fullAdder.vhd
│   ├── ula_logicUnit.vhd
│   ├── ula_flags.vhd
│   ├── reg_file_mips.vhd
│   ├── arith_machine.vhd
│   ├── sign_extender.vhd
│   ├── zero_extender.vhd
│   └── toplevel_ula.vhd        # Teste de hardware da ULA
├── test/                       # Testes cocotb
│   ├── Makefile
│   ├── test_mips_rom.py
│   ├── test_mips_ram.py
│   ├── test_ula.py
│   └── test_reg_file.py
├── .github/workflows/
│   └── cocotb.yml              # CI — roda testes automaticamente no push
└── mips_word_toplevel.qsf      # Projeto Quartus
```

---

## Como rodar os testes (cocotb)

Usando Docker (igual ao CI):

```bash
# Testar a ROM
docker run --rm -v $(pwd):/var/www rafaelcorsi/pl-descomp-cocotb:latest \
  make -C /var/www/test/ TOPLEVEL=mips_rom MODULE=test_mips_rom VHDL_SOURCES=../src/mips_rom.vhd

# Testar a RAM
docker run --rm -v $(pwd):/var/www rafaelcorsi/pl-descomp-cocotb:latest \
  make -C /var/www/test/ TOPLEVEL=mips_ram MODULE=test_mips_ram VHDL_SOURCES=../src/mips_ram.vhd
```

Ou via Makefile dentro do container:

```bash
make -C test/ rom
make -C test/ ram
```

---

## Como compilar no Quartus

1. Abra o Quartus Prime
2. **File → Open Project** → selecione `mips_word_toplevel.qsf`
3. **Ctrl+L** para compilar
4. Para gerar o RTL: **Tools → Netlist Viewers → RTL Viewer**

---

## CI — Integração Contínua

A cada `push`, o GitHub Actions executa automaticamente os testes de cocotb para ROM e RAM usando GHDL + cocotb dentro de um container Docker. O status pode ser acompanhado na aba **Actions** do repositório.

---
