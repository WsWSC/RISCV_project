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
    input  wire[31:0]   csr_mie_i           ,
    input  wire[31:0]   csr_mip_i           ,

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
    output wire         clint_hold_req_o    ,
    output wire         trap_jump_en_o      ,
    output wire[31:0]   trap_jump_addr_o
);

    // Priority: synchronous trap > external interrupt > mret
    reg         jump_pending;
    reg[31:0]  jump_addr;

    wire clint_idle = (jump_pending == `JumpDisable);
    wire sync_trap_taken = clint_idle && trap_en_i;
    wire external_irq_pending = external_irq_i || csr_mip_i[11];
    wire external_irq_taken = clint_idle && (!sync_trap_taken) && external_irq_pending && csr_mstatus_i[3] && csr_mie_i[11];
    wire mret_taken = clint_idle && (!sync_trap_taken) && (!external_irq_taken) && mret_en_i;
    wire clint_entry_en = sync_trap_taken || external_irq_taken || mret_taken;
    wire[31:0] mtvec_base = {csr_mtvec_i[31:2], 2'b00};

    always @(posedge clk or negedge rst_n) begin
        if (rst_n == 1'b0) begin
            jump_pending <= `JumpDisable;
            jump_addr    <= `ZeroAddr;
        end else if (clint_entry_en) begin
            jump_pending <= `JumpEnable;
            jump_addr    <= (sync_trap_taken || external_irq_taken) ? mtvec_base : csr_mepc_i;
        end else begin
            jump_pending <= `JumpDisable;
            jump_addr    <= `ZeroAddr;
        end
    end

    assign clint_hold_req_o = clint_entry_en;
    assign trap_w_en_o = clint_entry_en;

    assign trap_mepc_o =
        sync_trap_taken    ? trap_pc_i :
        external_irq_taken ? irq_pc_i  :
                              csr_mepc_i;

    assign trap_mcause_o =
        sync_trap_taken    ? trap_cause_i :
        external_irq_taken ? `TRAP_CAUSE_M_EXTERNAL :
                              csr_mcause_i;

    assign trap_mtval_o =
        sync_trap_taken    ? trap_tval_i :
        external_irq_taken ? `ZeroWord   :
                              csr_mtval_i;

    assign trap_mstatus_o =
        (sync_trap_taken || external_irq_taken) ? {csr_mstatus_i[31:8], csr_mstatus_i[3], csr_mstatus_i[6:4], 1'b0, csr_mstatus_i[2:0]} :
                                            {csr_mstatus_i[31:8], 1'b1, csr_mstatus_i[6:4], csr_mstatus_i[7], csr_mstatus_i[2:0]};

    assign trap_jump_en_o   = jump_pending;
    assign trap_jump_addr_o = jump_addr;

endmodule
