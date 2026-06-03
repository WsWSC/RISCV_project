////////////////////////////////////////////////////////////
//  RISC-V CPU Side Project
//  Author  : WsWSC
//  Created : 2026
//  License : Personal / Educational Use
////////////////////////////////////////////////////////////

`include "defines.v"

module clint(
    input  wire         clk                 ,
    input  wire         rst_n               ,

    // from CSR direct outputs
    input  wire[31:0]   csr_mtvec_i         ,
    input  wire[31:0]   csr_mepc_i          ,
    input  wire[31:0]   csr_mstatus_i       ,

    // trap request
    input  wire         trap_en_i           ,
    input  wire[31:0]   trap_pc_i           ,
    input  wire[31:0]   trap_cause_i        ,
    input  wire[31:0]   trap_tval_i         ,

    // to csr_reg trap write port
    output wire         trap_w_en_o         ,
    output wire[31:0]   trap_mepc_o         ,
    output wire[31:0]   trap_mcause_o       ,
    output wire[31:0]   trap_mtval_o        ,
    output wire[31:0]   trap_mstatus_o      ,

    // to ctrl
    output wire         trap_jump_en_o      ,
    output wire[31:0]   trap_jump_addr_o
);

    assign trap_w_en_o     = `WriteDisable;
    assign trap_mepc_o     = `ZeroWord;
    assign trap_mcause_o   = `ZeroWord;
    assign trap_mtval_o    = `ZeroWord;
    assign trap_mstatus_o  = `ZeroWord;
    assign trap_jump_en_o  = `JumpDisable;
    assign trap_jump_addr_o = `ZeroAddr;

endmodule
