////////////////////////////////////////////////////////////
//  RISC-V CPU Side Project
//  Author  : WsWSC
//  Created : 2026
//  License : Personal / Educational Use
////////////////////////////////////////////////////////////

`include "defines.v"

module div #(
    parameter integer LATENCY = 32
)(
    input  wire        clk,
    input  wire        rst_n,

    // from EX
    input  wire        div_start_i      ,
    input  wire [2:0]  div_funct3_i     ,
    input  wire [31:0] div_op1_i        ,   // dividend (rs1)
    input  wire [31:0] div_op2_i        ,   // divisor  (rs2)
    input  wire [4:0]  div_reg_waddr_i  ,

    // to EX
    output reg         div_busy_o       ,
    output reg         div_ready_o      ,
    output reg  [31:0] div_result_o     , // quotient (DIV/DIVU) or remainder (REM/REMU)
    output reg  [4:0]  div_rd_waddr_o   ,
    output reg  [2:0]  div_funct3_o
);

    // ============================================================
    // 2's complement helpers
    // ============================================================
    function [31:0] abs32;
        input [31:0] x;
        begin
            abs32 = x[31] ? (~x + 32'd1) : x;
        end
    endfunction

    function [31:0] neg32;
        input [31:0] x;
        begin
            neg32 = ~x + 32'd1;
        end
    endfunction


    // ============================================================
    // signed determine (RISC-V M)
    // DIV / REM   : signed
    // DIVU / REMU : unsigned
    // ============================================================
    wire div_is_signed = (div_funct3_i == `INST_DIV) || (div_funct3_i == `INST_REM);

    wire div_op1_is_neg = div_is_signed && div_op1_i[31];
    wire div_op2_is_neg  = div_is_signed && div_op2_i[31];

    wire quot_sign_next = div_op1_is_neg ^ div_op2_is_neg; // quotient sign
    wire rem_sign_next  = div_op1_is_neg;                  // remainder sign

    wire [31:0] div_op1_mag = div_op1_is_neg ? abs32(div_op1_i) : div_op1_i;
    wire [31:0] div_op2_mag  = div_op2_is_neg  ? abs32(div_op2_i) : div_op2_i;


    // ============================================================
    // FSM
    // ============================================================
    localparam STATE_IDLE = 2'd0;
    localparam STATE_RUN  = 2'd1;
    localparam STATE_END  = 2'd2;

    reg [1:0] state;
    reg [5:0] step;


    // ============================================================
    // Datapath regs (restoring division, 1 bit per cycle)
    // ============================================================
    reg        quot_sign;
    reg        rem_sign;

    reg [31:0] div_op1_shift;   // shifts left each cycle
    reg [31:0] div_op2_const;    // constant

    reg [32:0] remainder;        // 33-bit remainder accumulator
    reg [31:0] quotient;         // 32-bit quotient

    // One-iteration combinational next-state
    wire [32:0] remainder_shift = {remainder[31:0], div_op1_shift[31]};
    wire [32:0] div_op2_33      = {1'b0, div_op2_const};

    wire        ge_div_op2       = (remainder_shift >= div_op2_33);
    wire [32:0] remainder_next   = ge_div_op2 ? (remainder_shift - div_op2_33) : remainder_shift;
    wire [31:0] quotient_next    = {quotient[30:0], ge_div_op2};


    // ============================================================
    // Special cases (RISC-V spec)
    // ============================================================
    wire div_by_zero      = (div_op2_i == 32'd0);
    wire signed_overflow  = div_is_signed && (div_op1_i == 32'h8000_0000) && (div_op2_i == 32'hFFFF_FFFF);


    // ============================================================
    // Main FSM logic
    // ============================================================
    always @(posedge clk) begin
        if (!rst_n) begin
            state          <= STATE_IDLE;
            div_busy_o     <= 1'b0;
            div_ready_o    <= 1'b0;
            div_result_o   <= 32'd0;

            div_rd_waddr_o <= 5'd0;
            div_funct3_o   <= 3'd0;

            step           <= 6'd0;

            quot_sign      <= 1'b0;
            rem_sign       <= 1'b0;

            div_op1_shift <= 32'd0;
            div_op2_const  <= 32'd0;
            remainder      <= 33'd0;
            quotient       <= 32'd0;
        end else begin
            div_ready_o <= 1'b0; // default

            case (state)
                STATE_IDLE: begin
                    div_busy_o <= 1'b0;

                    if (div_start_i) begin
                        // latch control
                        div_funct3_o   <= div_funct3_i;
                        div_rd_waddr_o <= div_reg_waddr_i;

                        // fast special-case handling
                        if (div_by_zero) begin
                            // DIV/DIVU: quotient = -1; REM/REMU: remainder = dividend
                            if ((div_funct3_i == `INST_DIV) || (div_funct3_i == `INST_DIVU)) begin
                                div_result_o <= 32'hFFFF_FFFF;
                            end else begin
                                div_result_o <= div_op1_i;
                            end
                            state      <= STATE_END;
                            div_busy_o <= 1'b1;
                        end
                        else if (signed_overflow) begin
                            // INT_MIN / -1 => quotient=INT_MIN, remainder=0
                            if (div_funct3_i == `INST_DIV) begin
                                div_result_o <= 32'h8000_0000;
                            end else begin
                                // REM
                                div_result_o <= 32'd0;
                            end
                            state      <= STATE_END;
                            div_busy_o <= 1'b1;
                        end
                        else begin
                            // init datapath
                            quot_sign      <= quot_sign_next;
                            rem_sign       <= rem_sign_next;

                            div_op1_shift <= div_op1_mag;
                            div_op2_const  <= div_op2_mag;

                            remainder      <= 33'd0;
                            quotient       <= 32'd0;
                            step           <= 6'd0;

                            state          <= STATE_RUN;
                            div_busy_o     <= 1'b1;
                        end
                    end
                end

                STATE_RUN: begin
                    div_busy_o <= 1'b1;

                    // 1-bit iteration
                    remainder      <= remainder_next;
                    quotient       <= quotient_next;
                    div_op1_shift <= div_op1_shift << 1;

                    if (step == LATENCY - 1) begin
                        // finalize result
                        if ((div_funct3_o == `INST_DIV) || (div_funct3_o == `INST_DIVU)) begin
                            // quotient
                            if (div_is_signed && quot_sign) begin
                                div_result_o <= neg32(quotient_next);
                            end else begin
                                div_result_o <= quotient_next;
                            end
                        end else begin
                            // remainder
                            if (div_is_signed && rem_sign) begin
                                div_result_o <= neg32(remainder_next[31:0]);
                            end else begin
                                div_result_o <= remainder_next[31:0];
                            end
                        end

                        state <= STATE_END;
                    end else begin
                        step <= step + 6'd1;
                    end
                end

                STATE_END: begin
                    state       <= STATE_IDLE;
                    div_busy_o  <= 1'b0;
                    div_ready_o <= 1'b1;
                    step        <= 6'd0;
                end

                default: begin
                    state <= STATE_IDLE;
                end
            endcase
        end
    end

endmodule
