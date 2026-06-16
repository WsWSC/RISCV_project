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

    // from csr_reg
    input  wire[31:0]   csr_mtvec_i         ,   // trap handler base addr.
    input  wire[31:0]   csr_mepc_i          ,   // return PC for mret
    input  wire[31:0]   csr_mcause_i        ,   // saved current trap cause
    input  wire[31:0]   csr_mtval_i         ,   // saved current trap value
    input  wire[31:0]   csr_mstatus_i       ,   // MIE / MPIE state
    input  wire[31:0]   csr_mie_i           ,   // interrupt enable bits
    input  wire[31:0]   csr_mip_i           ,   // interrupt pending bits

    // trap request from core, merged from id_ex/ex
    input  wire         trap_en_i           ,   // trap request
    input  wire[31:0]   trap_pc_i           ,   // faulting PC
    input  wire[31:0]   trap_cause_i        ,   // trap cause
    input  wire[31:0]   trap_tval_i         ,   // trap value
    input  wire         mret_en_i           ,   // mret request

    // from core
    input  wire         external_irq_i      ,   // external IRQ, e.g. UART/GPIO/timer

    // from pc_reg
    input  wire[31:0]   irq_pc_i            ,   // PC saved to mepc

    // to csr_reg
    output wire         trap_w_en_o         ,   // trap CSR write enable
    output reg [31:0]   trap_mepc_o         ,   // write to mepc
    output reg [31:0]   trap_mcause_o       ,   // write to mcause
    output reg [31:0]   trap_mtval_o        ,   // write to mtval
    output wire[31:0]   trap_mstatus_o      ,   // write to mstatus

    // to ctrl
    output wire         clint_hold_req_o    ,   // hold pipeline
    output wire         trap_jump_en_o      ,   // jump request
    output wire[31:0]   trap_jump_addr_o        // jump target
);

    // ============================================================
    //  Internal Signals
    // ============================================================
    reg         jump_pending                ;
    reg[31:0]   jump_addr                   ;
    wire[31:0]  mtvec_base                  ;
    reg         sync_trap_taken             ;
    reg         external_irq_taken          ;
    reg         mret_taken                  ;
    reg         clint_entry_en              ;
    reg[31:0]   next_jump_addr              ;

    assign mtvec_base = {csr_mtvec_i[31:2], 2'b00}  ;

    // ============================================================
    //  Event Detect
    // ============================================================
    // Priority: synchronous trap > external interrupt > mret
    always @(*) begin
        sync_trap_taken    = `WriteDisable  ;
        external_irq_taken = `WriteDisable  ;
        mret_taken         = `WriteDisable  ;
        clint_entry_en     = `WriteDisable  ;
        next_jump_addr     = csr_mepc_i     ;

        // Priority: synchronous trap > external interrupt > mret
        if (jump_pending == `JumpDisable) begin
            if (trap_en_i) begin
                sync_trap_taken = `WriteEnable     ;
                clint_entry_en  = `WriteEnable     ;
                next_jump_addr  = mtvec_base       ;
            end else if (((external_irq_i == `InterruptAssert) || csr_mip_i[11]) &&
                         csr_mstatus_i[3] && csr_mie_i[11]) begin
                external_irq_taken = `WriteEnable  ;
                clint_entry_en     = `WriteEnable  ;
                next_jump_addr     = mtvec_base    ;
            end else if (mret_en_i) begin
                mret_taken      = `WriteEnable     ;
                clint_entry_en  = `WriteEnable     ;
                next_jump_addr  = csr_mepc_i       ;
            end
        end
    end

    // ============================================================
    //  Jump Request Register
    // ============================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            jump_pending <= `JumpDisable    ;
            jump_addr    <= `ZeroAddr       ;
        end else if (clint_entry_en) begin
            jump_pending <= `JumpEnable     ;
            jump_addr    <= next_jump_addr  ;
        end else begin
            jump_pending <= `JumpDisable    ;
            jump_addr    <= `ZeroAddr       ;
        end
    end

    // ============================================================
    //  CSR Write Enable
    // ============================================================
    assign clint_hold_req_o = clint_entry_en ;
    assign trap_w_en_o      = clint_entry_en ;

    // ============================================================
    //  Trap CSR Data
    // ============================================================
    always @(*) begin
        trap_mepc_o    = csr_mepc_i                 ;
        trap_mcause_o  = csr_mcause_i               ;
        trap_mtval_o   = csr_mtval_i                ;

        if (sync_trap_taken) begin
            trap_mepc_o    = trap_pc_i              ;
            trap_mcause_o  = trap_cause_i           ;
            trap_mtval_o   = trap_tval_i            ;
        end else if (external_irq_taken) begin
            trap_mepc_o    = irq_pc_i               ;
            trap_mcause_o  = `TRAP_CAUSE_M_EXTERNAL ;
            trap_mtval_o   = `ZeroWord              ;
        end
    end

    assign trap_mstatus_o =
        (sync_trap_taken || external_irq_taken) ?
        {csr_mstatus_i[31:8], csr_mstatus_i[3], csr_mstatus_i[6:4], 1'b0, csr_mstatus_i[2:0]} :
        {csr_mstatus_i[31:8], 1'b1, csr_mstatus_i[6:4], csr_mstatus_i[7], csr_mstatus_i[2:0]};

    // ============================================================
    //  Jump Output
    // ============================================================
    assign trap_jump_en_o   = jump_pending ;
    assign trap_jump_addr_o = jump_addr    ;

endmodule
