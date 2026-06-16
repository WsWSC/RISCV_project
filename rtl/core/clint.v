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
    output reg [31:0]   trap_mepc_o         ,
    output reg [31:0]   trap_mcause_o       ,
    output reg [31:0]   trap_mtval_o        ,
    output wire[31:0]   trap_mstatus_o      ,

    // to ctrl
    output wire         clint_hold_req_o    ,
    output wire         trap_jump_en_o      ,
    output wire[31:0]   trap_jump_addr_o
);

    // Priority: synchronous trap > external interrupt > mret
    reg         jump_pending                   ;
    reg[31:0]  jump_addr                       ;

    wire[31:0]  mtvec_base                     ;

    reg         sync_trap_taken                ;
    reg         external_irq_taken             ;
    reg         mret_taken                     ;
    reg         clint_entry_en                 ;
    reg[31:0]   next_jump_addr                 ;

    assign mtvec_base = {csr_mtvec_i[31:2], 2'b00};

    always @(*) begin
        sync_trap_taken    = `WriteDisable;
        external_irq_taken = `WriteDisable;
        mret_taken         = `WriteDisable;
        clint_entry_en     = `WriteDisable;
        next_jump_addr     = csr_mepc_i;

        if (jump_pending == `JumpDisable) begin
            if (trap_en_i) begin
                sync_trap_taken = `WriteEnable;
                clint_entry_en  = `WriteEnable;
                next_jump_addr  = mtvec_base;
            end else if (((external_irq_i == `InterruptAssert) || csr_mip_i[11]) &&
                         csr_mstatus_i[3] && csr_mie_i[11]) begin
                external_irq_taken = `WriteEnable;
                clint_entry_en     = `WriteEnable;
                next_jump_addr     = mtvec_base;
            end else if (mret_en_i) begin
                mret_taken      = `WriteEnable;
                clint_entry_en  = `WriteEnable;
                next_jump_addr  = csr_mepc_i;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (rst_n == 1'b0) begin
            jump_pending <= `JumpDisable ;
            jump_addr    <= `ZeroAddr    ;
        end else if (clint_entry_en) begin
            jump_pending <= `JumpEnable  ;
            jump_addr    <= next_jump_addr;
        end else begin
            jump_pending <= `JumpDisable ;
            jump_addr    <= `ZeroAddr    ;
        end
    end

    assign clint_hold_req_o = clint_entry_en;
    assign trap_w_en_o      = clint_entry_en;

    always @(*) begin
        trap_mepc_o    = csr_mepc_i;
        trap_mcause_o  = csr_mcause_i;
        trap_mtval_o   = csr_mtval_i;

        if (sync_trap_taken) begin
            trap_mepc_o    = trap_pc_i;
            trap_mcause_o  = trap_cause_i;
            trap_mtval_o   = trap_tval_i;
        end else if (external_irq_taken) begin
            trap_mepc_o    = irq_pc_i;
            trap_mcause_o  = `TRAP_CAUSE_M_EXTERNAL;
            trap_mtval_o   = `ZeroWord;
        end
    end

    assign trap_mstatus_o =
        (sync_trap_taken || external_irq_taken) ?
        {csr_mstatus_i[31:8], csr_mstatus_i[3], csr_mstatus_i[6:4], 1'b0, csr_mstatus_i[2:0]} :
        {csr_mstatus_i[31:8], 1'b1, csr_mstatus_i[6:4], csr_mstatus_i[7], csr_mstatus_i[2:0]};

    assign trap_jump_en_o   = jump_pending;
    assign trap_jump_addr_o = jump_addr;

endmodule
