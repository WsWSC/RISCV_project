////////////////////////////////////////////////////////////
//  RISC-V CPU Side Project
//  Author  : WsWSC
//  Created : 2026
//  License : Personal / Educational Use
////////////////////////////////////////////////////////////

`include "defines.v"

module mul #(
    parameter integer LATENCY = 32   // keep 32 for RV32
)(
    input  wire        clk,
    input  wire        rst_n,

    input  wire        start,
    input  wire [2:0]  funct3,
    input  wire [31:0] op1,
    input  wire [31:0] op2,

    output reg         busy,
    output reg         done,
    output reg  [63:0] result64
);

    // ------------------------------------------------------------
    // helpers
    // ------------------------------------------------------------
    function [31:0] abs32;          // Compute |x| for a 32-bit two's complement value
        input [31:0] x;
        begin
            abs32 = x[31] ? (~x + 32'd1) : x;
        end
    endfunction

    function [63:0] neg64;          // 64-bit 值取負
        input [63:0] x;
        begin
            neg64 = ~x + 64'd1;
        end
    endfunction

    // funct3 signed / unsigned
    wire op1_is_signed = (funct3 == `INST_MUL)    ||
                         (funct3 == `INST_MULH)   ||
                         (funct3 == `INST_MULHSU);

    wire op2_is_signed = (funct3 == `INST_MUL)    || 
                         (funct3 == `INST_MULH);  

    // ------------------------------------------------------------
    // state + datapath regs
    // ------------------------------------------------------------
    localparam IDLE = 1'b0;
    localparam RUN  = 1'b1;

    reg        state;
    reg [5:0]  step;      // 32 steps for shift-add

    reg        sign_neg;  // final sign
    reg [63:0] acc;       // accumulator
    reg [63:0] mcand;     // multiplicand (shift left)
    reg [31:0] mplier;    // multiplier   (shift right)

    // ------------------------------------------------------------
    // main FSM
    // ------------------------------------------------------------
    always @(posedge clk) begin
        if (!rst_n) begin
            state    <= IDLE;
            busy     <= 1'b0;
            done     <= 1'b0;
            result64 <= 64'd0;

            step     <= 6'd0;
            sign_neg <= 1'b0;
            acc      <= 64'd0;
            mcand    <= 64'd0;
            mplier   <= 32'd0;
        end else begin
            done <= 1'b0; // pulse

            case (state)
                // -----------------------------
                // IDLE: wait for start
                // -----------------------------
                IDLE: begin
                    busy <= 1'b0;

                    if (start) begin                
                        // convert to unsigned magnitudes, then do unsigned shift-add
                        reg op1_neg, op2_neg;
                        reg [31:0] a_mag, b_mag;

                        op1_neg = op1_is_signed && op1[31];
                        op2_neg = op2_is_signed && op2[31];

                        sign_neg = op1_neg ^ op2_neg;           // sign

                        a_mag = op1_neg ? abs32(op1) : op1;     // absolute unsigned value
                        b_mag = op2_neg ? abs32(op2) : op2;

                        // init datapath
                        acc    <= 64'd0;
                        mcand  <= {32'd0, a_mag};
                        mplier <= b_mag;
                        step   <= 6'd0;

                        busy  <= 1'b1;
                        state <= RUN;
                    end
                end

                // -----------------------------
                // RUN: 32 iterations
                // -----------------------------
                RUN: begin
                    busy <= 1'b1;

                    // one shift-add step
                    if (mplier[0]) 
                        acc <= acc + mcand;

                    mcand  <= mcand << 1;
                    mplier <= mplier >> 1;

                    // step count
                    if (step == (LATENCY - 1)) begin
                        // finish this cycle
                        // NOTE: acc written with nonblocking; need a stable final value:
                        // easiest: compute final using current mplier[0] decision
                        // by using a temporary "final_acc" wire-like reg.
                        reg [63:0] final_acc;
                        final_acc = acc + (mplier[0] ? mcand : 64'd0);

                        result64 <= sign_neg ? neg64(final_acc) : final_acc;
                        done     <= 1'b1;
                        busy     <= 1'b0;
                        state    <= IDLE;
                    end else begin
                        step <= step + 6'd1;
                    end
                end
            endcase
        end
    end

endmodule
