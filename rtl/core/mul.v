////////////////////////////////////////////////////////////
//  RISC-V CPU Side Project
//  Author  : WsWSC
//  Created : 2026
//  License : Personal / Educational Use
////////////////////////////////////////////////////////////

`include "defines.v"

module mul #(
    parameter integer LATENCY = 32      // keep 32 for RV32
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
    // functions
    // ------------------------------------------------------------
    function [31:0] abs32;              // Compute |x| in 32-bit 2's complement
        input [31:0] x;
        begin
            abs32 = x[31] ? (~x + 32'd1) : x;
        end
    endfunction

    function [63:0] neg64;              // 64-bit 2's complement negate
        input [63:0] x;
        begin
            neg64 = ~x + 64'd1;
        end
    endfunction

    // ------------------------------------------------------------
    // signed/unsigned select (combinational)
    // ------------------------------------------------------------
    wire op1_is_signed = (funct3 == `INST_MUL)    ||
                         (funct3 == `INST_MULH)   ||
                         (funct3 == `INST_MULHSU);

    wire op2_is_signed = (funct3 == `INST_MUL)    ||
                         (funct3 == `INST_MULH);

    wire op1_neg = op1_is_signed && op1[31];
    wire op2_neg = op2_is_signed && op2[31];

    wire sign_neg_next = op1_neg ^ op2_neg;

    wire [31:0] op1_mag_next = op1_neg ? abs32(op1) : op1;
    wire [31:0] op2_mag_next = op2_neg ? abs32(op2) : op2;

    // ------------------------------------------------------------
    // state + datapath regs
    // ------------------------------------------------------------
    localparam IDLE = 1'b0;
    localparam RUN  = 1'b1;

    reg        state;
    reg [5:0]  step;                    // 0 ~ 31

    reg        sign_neg;                // latched final sign
    reg [63:0] acc;                     // accumulator
    reg [63:0] mcand;                   // multiplicand (shift left)
    reg [31:0] mplier;                  // multiplier   (shift right)

    // "final_acc" as stable combinational view of the NEXT acc value
    // computed from CURRENT (old) acc/mcand/mplier[0].
    wire [63:0] acc_next = acc + (mplier[0] ? mcand : 64'd0);

    // ------------------------------------------------------------
    // main FSM (sequential)
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
                IDLE: begin
                    busy <= 1'b0;

                    if (start) begin
                        // latch sign + magnitudes at start
                        sign_neg <= sign_neg_next;

                        acc    <= 64'd0;
                        mcand  <= {32'd0, op1_mag_next};
                        mplier <= op2_mag_next;
                        step   <= 6'd0;

                        busy  <= 1'b1;
                        state <= RUN;
                    end
                end

                RUN: begin
                    busy <= 1'b1;

                    // do one iteration using current mplier[0]
                    acc    <= acc_next;
                    mcand  <= mcand << 1;
                    mplier <= mplier >> 1;

                    if (step == (LATENCY - 1)) begin
                        // acc_next is the correct "final_acc" for this last step
                        result64 <= sign_neg ? neg64(acc_next) : acc_next;
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
