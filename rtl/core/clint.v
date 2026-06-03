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

    assign trap_w_en_o      = trap_en_i;
    assign trap_mepc_o      = trap_pc_i;
    assign trap_mcause_o    = trap_cause_i;
    assign trap_mtval_o     = trap_tval_i;
    assign trap_mstatus_o   = {csr_mstatus_i[31:8], csr_mstatus_i[3], csr_mstatus_i[6:4], 1'b0, csr_mstatus_i[2:0]};
    assign trap_jump_en_o   = trap_en_i;
    assign trap_jump_addr_o = csr_mtvec_i;

endmodule
