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
    output reg  [63:0] div_result64_o   ,   // {remainder[63:32], quotient[31:0]}
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
    // Signed determine at START (RISC-V M)
    // DIV / REM   : signed
    // DIVU / REMU : unsigned
    // ============================================================
    wire start_is_signed = (div_funct3_i == `INST_DIV) || (div_funct3_i == `INST_REM);

    wire op1_is_neg = start_is_signed && div_op1_i[31];
    wire op2_is_neg = start_is_signed && div_op2_i[31];

    wire quot_sign_next = op1_is_neg ^ op2_is_neg; // quotient sign
    wire rem_sign_next  = op1_is_neg;              // remainder sign

    wire [31:0] op1_mag = op1_is_neg ? abs32(div_op1_i) : div_op1_i;
    wire [31:0] op2_mag = op2_is_neg ? abs32(div_op2_i) : div_op2_i;


    // ============================================================
    // Special cases (per RISC-V spec semantics)
    // ============================================================
    wire div_by_zero     = (div_op2_i == 32'd0);
    wire signed_overflow = start_is_signed &&
                           (div_op1_i == 32'h8000_0000) &&
                           (div_op2_i == 32'hFFFF_FFFF); // INT_MIN / -1


    // ============================================================
    // FSM
    // ============================================================
    localparam STATE_IDLE = 2'd0;
    localparam STATE_RUN  = 2'd1;
    localparam STATE_END  = 2'd2;

    reg [1:0] state;
    reg [5:0] step;


    // ============================================================
    //  Internal Signals
    // ============================================================
    reg         div_is_signed_r;
    reg         quot_sign;
    reg         rem_sign;

    reg [31:0]  div_op1_shift;      // shifts left each cycle (feeds MSB into remainder)
    reg [31:0]  div_op2_const;      // constant divisor magnitude

    reg [32:0]  remainder;          // 33-bit remainder accumulator
    reg [31:0]  quotient;           // 32-bit quotient

    // One-iteration combinational next-state
    wire [32:0] remainder_shift = {remainder[31:0], div_op1_shift[31]};
    wire [32:0] div_op2_33      = {1'b0, div_op2_const};

    wire        ge_div_op2      = (remainder_shift >= div_op2_33);
    wire [32:0] remainder_next  = ge_div_op2 ? (remainder_shift - div_op2_33) : remainder_shift;
    wire [31:0] quotient_next   = {quotient[30:0], ge_div_op2};

    // Final corrected results (based on the "next" values at last iteration)
    wire [31:0] quot_mag_final  = quotient_next;
    wire [31:0] rem_mag_final   = remainder_next[31:0];

    wire [31:0] quot_final = (div_is_signed_r && quot_sign) ? neg32(quot_mag_final) : quot_mag_final;
    wire [31:0] rem_final  = (div_is_signed_r && rem_sign ) ? neg32(rem_mag_final ) : rem_mag_final;

    wire [63:0] pack_qr_final = {rem_final, quot_final}; // {remainder, quotient}


    // ============================================================
    //  Main FSM
    // ============================================================
    always @(posedge clk) begin
        if (!rst_n) begin
            state           <= STATE_IDLE;
            div_busy_o      <= 1'b0 ;
            div_ready_o     <= 1'b0 ;
            div_result64_o  <= 64'd0;

            div_rd_waddr_o  <= 5'd0 ;
            div_funct3_o    <= 3'd0 ;

            step            <= 6'd0 ;

            div_is_signed_r <= 1'b0 ;
            quot_sign       <= 1'b0 ;
            rem_sign        <= 1'b0 ;

            div_op1_shift   <= 32'd0;
            div_op2_const   <= 32'd0;
            remainder       <= 33'd0;
            quotient        <= 32'd0;
        end else begin
            div_ready_o <= 1'b0; // default (pulse in END)

            case (state)
                STATE_IDLE: begin
                    div_busy_o <= 1'b0;

                    if (div_start_i) begin
                        // latch control
                        div_funct3_o    <= div_funct3_i;
                        div_rd_waddr_o  <= div_reg_waddr_i;
                        div_is_signed_r <= start_is_signed;

                        // fast special-case handling
                        if (div_by_zero) begin                  // quotient = all 1s, remainder = dividend
                            div_result64_o <= {div_op1_i, 32'hFFFF_FFFF};
                            state          <= STATE_END;
                            div_busy_o     <= 1'b1;

                        end else if (signed_overflow) begin     // INT_MIN / -1 => quotient=INT_MIN, remainder=0
                            div_result64_o <= {32'd0, 32'h8000_0000};
                            state          <= STATE_END;
                            div_busy_o     <= 1'b1;

                        end else begin                          // init datapath
                            quot_sign     <= quot_sign_next;
                            rem_sign      <= rem_sign_next;

                            div_op1_shift <= op1_mag;
                            div_op2_const <= op2_mag;

                            remainder     <= 33'd0;
                            quotient      <= 32'd0;
                            step          <= 6'd0;

                            state         <= STATE_RUN;
                            div_busy_o    <= 1'b1;
                        end
                    end
                end

                STATE_RUN: begin
                    div_busy_o <= 1'b1;

                    // 1-bit iteration
                    remainder     <= remainder_next;
                    quotient      <= quotient_next;
                    div_op1_shift <= div_op1_shift << 1;

                    if (step == LATENCY - 1) begin
                        // always output {remainder, quotient} for EX to select
                        div_result64_o <= pack_qr_final;
                        state          <= STATE_END;
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
