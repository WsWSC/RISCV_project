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
    input  wire[31:0]   csr_mstatus_i       ,   // MIE / MPIE state
    input  wire[31:0]   csr_mie_i           ,   // interrupt enable bits
    input  wire[31:0]   csr_mip_i           ,   // interrupt pending bits

    // from id_ex
    input  wire         id_ex_trap_en_i     ,   // trap request
    input  wire[31:0]   id_ex_trap_pc_i     ,   // faulting PC
    input  wire[31:0]   id_ex_trap_cause_i  ,   // trap cause
    input  wire[31:0]   id_ex_trap_tval_i   ,   // trap value
    input  wire         mret_en_i           ,   // mret request

    // from ex
    input  wire         ex_trap_en_i        ,   // trap request
    input  wire[31:0]   ex_trap_cause_i     ,   // trap cause
    input  wire[31:0]   ex_trap_tval_i      ,   // trap value

    // from core
    input  wire         external_irq_i      ,   // external IRQ, e.g. UART/GPIO/timer

    // from pc_reg
    input  wire[31:0]   irq_pc_i            ,   // PC saved to mepc

    // to csr_reg
    output reg          csr_w_en_o          ,
    output reg [11:0]   csr_w_addr_o        ,
    output reg [31:0]   csr_w_data_o        ,

    // to ctrl
    output wire         clint_hold_req_o    ,   // hold pipeline
    output wire         trap_jump_en_o      ,   // jump request
    output wire[31:0]   trap_jump_addr_o        // jump target
);

    // ============================================================
    // FSM
    // ============================================================
    localparam S_EVENT_IDLE = 2'd0;
    localparam S_EVENT_TRAP = 2'd1;
    localparam S_EVENT_IRQ  = 2'd2;
    localparam S_EVENT_MRET = 2'd3;

    localparam S_CSR_IDLE          = 3'd0;
    localparam S_CSR_WRITE_MEPC    = 3'd1;
    localparam S_CSR_WRITE_MCAUSE  = 3'd2;
    localparam S_CSR_WRITE_MTVAL   = 3'd3;
    localparam S_CSR_WRITE_MSTATUS = 3'd4;
    localparam S_CSR_JUMP          = 3'd5;

    reg[1:0]   event_state                 ;
    reg[2:0]   csr_state                   ;

    // ============================================================
    //  Internal Signals
    // ============================================================
    reg[31:0]  saved_mepc                  ;
    reg[31:0]  saved_mcause                ;
    reg[31:0]  saved_mtval                 ;
    reg[31:0]  saved_mstatus               ;
    reg[31:0]  saved_jump_addr             ;

    wire[31:0] mtvec_base                  ;
    wire       trap_en                     ;
    wire[31:0] trap_cause                  ;
    wire[31:0] trap_tval                   ;
    wire       irq_taken                   ;
    wire       sync_trap_taken             ;
    wire       mret_taken                  ;
    wire       event_detect                ;
    wire       csr_write_state             ;
    wire[31:0] trap_mstatus                ;
    wire[31:0] mret_mstatus                ;

    assign mtvec_base = {csr_mtvec_i[31:2], 2'b00};

    assign trap_en    = ex_trap_en_i || id_ex_trap_en_i                         ;
    assign trap_cause = ex_trap_en_i ? ex_trap_cause_i : id_ex_trap_cause_i     ;
    assign trap_tval  = ex_trap_en_i ? ex_trap_tval_i  : id_ex_trap_tval_i      ;

    assign irq_taken =
        (((external_irq_i == `InterruptAssert) || csr_mip_i[11]) &&
         csr_mstatus_i[3] && csr_mie_i[11]);

    assign sync_trap_taken = (csr_state == S_CSR_IDLE) && trap_en;
    assign mret_taken      = (csr_state == S_CSR_IDLE) && !trap_en &&
                             !irq_taken && mret_en_i;

    // Priority: synchronous trap > external interrupt > mret
    assign event_detect =
        (csr_state == S_CSR_IDLE) &&
        (trap_en || irq_taken || mret_en_i);

    assign csr_write_state =
        (csr_state == S_CSR_WRITE_MEPC)    ||
        (csr_state == S_CSR_WRITE_MCAUSE)  ||
        (csr_state == S_CSR_WRITE_MTVAL)   ||
        (csr_state == S_CSR_WRITE_MSTATUS);

    assign trap_mstatus =
        {csr_mstatus_i[31:8], csr_mstatus_i[3],
         csr_mstatus_i[6:4], 1'b0, csr_mstatus_i[2:0]};

    assign mret_mstatus =
        {csr_mstatus_i[31:8], 1'b1,
         csr_mstatus_i[6:4], csr_mstatus_i[7], csr_mstatus_i[2:0]};

    // ============================================================
    //  Main FSM
    // ============================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            event_state    <= S_EVENT_IDLE;
            csr_state      <= S_CSR_IDLE  ;
            saved_mepc     <= `ZeroWord   ;
            saved_mcause   <= `ZeroWord   ;
            saved_mtval    <= `ZeroWord   ;
            saved_mstatus  <= `ZeroWord   ;
            saved_jump_addr<= `ZeroAddr   ;
        end else begin
            case (csr_state)
                S_CSR_IDLE: begin
                    if (sync_trap_taken) begin
                        event_state     <= S_EVENT_TRAP;
                        csr_state       <= S_CSR_WRITE_MEPC;
                        saved_mepc      <= id_ex_trap_pc_i;
                        saved_mcause    <= trap_cause;
                        saved_mtval     <= trap_tval;
                        saved_mstatus   <= trap_mstatus;
                        saved_jump_addr <= mtvec_base;
                    end else if (irq_taken) begin
                        event_state     <= S_EVENT_IRQ;
                        csr_state       <= S_CSR_WRITE_MEPC;
                        saved_mepc      <= irq_pc_i;
                        saved_mcause    <= `TRAP_CAUSE_M_EXTERNAL;
                        saved_mtval     <= `ZeroWord;
                        saved_mstatus   <= trap_mstatus;
                        saved_jump_addr <= mtvec_base;
                    end else if (mret_taken) begin
                        event_state     <= S_EVENT_MRET;
                        csr_state       <= S_CSR_WRITE_MSTATUS;
                        saved_mepc      <= csr_mepc_i;
                        saved_mcause    <= `ZeroWord;
                        saved_mtval     <= `ZeroWord;
                        saved_mstatus   <= mret_mstatus;
                        saved_jump_addr <= csr_mepc_i;
                    end
                end

                S_CSR_WRITE_MEPC: begin
                    csr_state <= S_CSR_WRITE_MCAUSE;
                end

                S_CSR_WRITE_MCAUSE: begin
                    csr_state <= S_CSR_WRITE_MTVAL;
                end

                S_CSR_WRITE_MTVAL: begin
                    csr_state <= S_CSR_WRITE_MSTATUS;
                end

                S_CSR_WRITE_MSTATUS: begin
                    csr_state <= S_CSR_JUMP;
                end

                S_CSR_JUMP: begin
                    event_state <= S_EVENT_IDLE;
                    csr_state   <= S_CSR_IDLE;
                end

                default: begin
                    event_state <= S_EVENT_IDLE;
                    csr_state   <= S_CSR_IDLE;
                end
            endcase
        end
    end

    // ============================================================
    //  CSR Write
    // ============================================================
    always @(*) begin
        csr_w_en_o   = `WriteDisable;
        csr_w_addr_o = 12'b0;
        csr_w_data_o = `ZeroWord;

        case (csr_state)
            S_CSR_WRITE_MEPC: begin
                csr_w_en_o   = `WriteEnable;
                csr_w_addr_o = `CSR_MEPC;
                csr_w_data_o = saved_mepc;
            end

            S_CSR_WRITE_MCAUSE: begin
                csr_w_en_o   = `WriteEnable;
                csr_w_addr_o = `CSR_MCAUSE;
                csr_w_data_o = saved_mcause;
            end

            S_CSR_WRITE_MTVAL: begin
                csr_w_en_o   = `WriteEnable;
                csr_w_addr_o = `CSR_MTVAL;
                csr_w_data_o = saved_mtval;
            end

            S_CSR_WRITE_MSTATUS: begin
                csr_w_en_o   = `WriteEnable;
                csr_w_addr_o = `CSR_MSTATUS;
                csr_w_data_o = saved_mstatus;
            end

            default: begin
            end
        endcase
    end

    // ============================================================
    //  Hold / Jump Output
    // ============================================================
    assign clint_hold_req_o = event_detect || csr_write_state;
    assign trap_jump_en_o   = (csr_state == S_CSR_JUMP);
    assign trap_jump_addr_o = saved_jump_addr;

endmodule
