////////////////////////////////////////////////////////////
//  RISC-V CPU Side Project
//  Author  : WsWSC
//  Created : 2026
//  License : Personal / Educational Use
////////////////////////////////////////////////////////////

// ============================================================
// Control flags
// ============================================================
`define JumpEnable      1'b1
`define JumpDisable     1'b0
`define FlushEnable     1'b1
`define FlushDisable    1'b0
`define StallEnable   1'b1
`define StallDisable  1'b0

`define WriteEnable     1'b1
`define WriteDisable    1'b0
`define ReadEnable      1'b1
`define ReadDisable     1'b0


// ============================================================
// Bus widths / sizes
// ============================================================
// Reg related
`define RegAddrBus      4:0
`define RegBus          31:0
`define DoubleRegBus    63:0
`define RegNum          32
`define RegNumLog2      5

// Mem related
`define MemAddrBus      31:0
`define MemDataBus      31:0
`define MemNum          4096

// Inst related
`define InstAddrBus     31:0
`define InstDataBus     31:0

// ============================================================
// Common constants
// ============================================================
`define ZeroWord        32'b0
`define ZeroReg         5'b0
`define ZeroAddr        32'b0


// ============================================================
// Instruction encodings (opcode / funct3 groups)
// ============================================================
// I-type (opcode = 0010011)
`define INST_TYPE_I     7'b0010011
`define INST_ADDI       3'b000
`define INST_SLTI       3'b010
`define INST_SLTIU      3'b011
`define INST_XORI       3'b100
`define INST_ORI        3'b110
`define INST_ANDI       3'b111
`define INST_SLLI       3'b001
`define INST_SRI        3'b101

// R/M-type (opcode = 0110011)
`define INST_TYPE_R_M   7'b0110011
// R type inst
`define INST_ADD_SUB    3'b000
`define INST_SLL        3'b001
`define INST_SLT        3'b010
`define INST_SLTU       3'b011
`define INST_XOR        3'b100
`define INST_SR         3'b101
`define INST_OR         3'b110
`define INST_AND        3'b111
// M type inst  
`define FUNCT7_TYPE_M   7'b000_0001
`define INST_MUL        3'b000
`define INST_MULH       3'b001
`define INST_MULHSU     3'b010
`define INST_MULHU      3'b011
`define INST_DIV        3'b100
`define INST_DIVU       3'b101
`define INST_REM        3'b110
`define INST_REMU       3'b111

// Branch (opcode = 1100011) 
`define INST_TYPE_B     7'b1100011
`define INST_BEQ        3'b000
`define INST_BNE        3'b001
`define INST_BLT        3'b100
`define INST_BGE        3'b101
`define INST_BLTU       3'b110
`define INST_BGEU       3'b111

// L-type loads (opcode = 0000011)
`define INST_TYPE_L     7'b0000011
`define INST_LB         3'b000
`define INST_LH         3'b001
`define INST_LW         3'b010
`define INST_LBU        3'b100
`define INST_LHU        3'b101

// S-type stores (opcode = 0100011)
`define INST_TYPE_S     7'b0100011
`define INST_SB         3'b000
`define INST_SH         3'b001
`define INST_SW         3'b010

// Jumps / U-type / fence (opcode constants)
`define INST_JAL        7'b1101111
`define INST_JALR       7'b1100111

`define INST_LUI        7'b0110111
`define INST_AUIPC      7'b0010111
`define INST_NOP        32'h00000013
`define INST_NOP_OP     7'b0000001
`define INST_MRET       32'h30200073
`define INST_RET        32'h00008067

`define INST_FENCE      7'b0001111
`define INST_TYPE_SYSTEM 7'b1110011
`define INST_ECALL      32'h73
`define INST_EBREAK     32'h00100073

// SYSTEM CSR instruction funct3
`define INST_CSRRW      3'b001
`define INST_CSRRS      3'b010
`define INST_CSRRC      3'b011
`define INST_CSRRWI     3'b101
`define INST_CSRRSI     3'b110
`define INST_CSRRCI     3'b111

// ============================================================
// CSR addresses
// ============================================================
`define CSR_MSTATUS     12'h300
`define CSR_MIE         12'h304
`define CSR_MTVEC       12'h305
`define CSR_MEPC        12'h341
`define CSR_MCAUSE      12'h342
`define CSR_MTVAL       12'h343
`define CSR_MIP         12'h344

// ============================================================
// Trap cause values
// ============================================================
`define TRAP_CAUSE_ILLEGAL_INST 32'd2
`define TRAP_CAUSE_BREAKPOINT 32'd3
`define TRAP_CAUSE_LOAD_MISALIGNED  32'd4
`define TRAP_CAUSE_STORE_MISALIGNED 32'd6
`define TRAP_CAUSE_ECALL_M    32'd11
`define TRAP_CAUSE_M_EXTERNAL 32'h8000000b
