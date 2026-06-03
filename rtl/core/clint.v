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
    input  wire[31:0]   csr_mcause_i        ,
    input  wire[31:0]   csr_mtval_i         ,
    input  wire[31:0]   csr_mstatus_i       ,

    // trap request
    input  wire         trap_en_i           ,
    input  wire[31:0]   trap_pc_i           ,
    input  wire[31:0]   trap_cause_i        ,
    input  wire[31:0]   trap_tval_i         ,
    input  wire         mret_en_i           ,

    // external interrupt
    input  wire         external_irq_i      ,
    input  wire[31:0]   irq_pc_i            ,

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

    assign trap_w_en_o = trap_en_i || mret_en_i;

    assign trap_mepc_o   = trap_en_i ? trap_pc_i    : csr_mepc_i;
    assign trap_mcause_o = trap_en_i ? trap_cause_i : csr_mcause_i;
    assign trap_mtval_o  = trap_en_i ? trap_tval_i  : csr_mtval_i;
    assign trap_mstatus_o =
        trap_en_i ? {csr_mstatus_i[31:8], csr_mstatus_i[3], csr_mstatus_i[6:4], 1'b0, csr_mstatus_i[2:0]} :
                    {csr_mstatus_i[31:8], 1'b1, csr_mstatus_i[6:4], csr_mstatus_i[7], csr_mstatus_i[2:0]};

    assign trap_jump_en_o   = trap_en_i || mret_en_i;
    assign trap_jump_addr_o = trap_en_i ? csr_mtvec_i : csr_mepc_i;

endmodule
