////////////////////////////////////////////////////////////
//  RISC-V CPU Side Project
//  Author  : WsWSC
//  Created : 2026
//  License : Personal / Educational Use
////////////////////////////////////////////////////////////

`include "defines.v"

module mul #(
    parameter integer LATENCY = 32
)(
    input  wire        clk,
    input  wire        rst_n,

    // from EX
    input  wire        mul_start_i      ,
    input  wire [2:0]  funct3_i         ,
    input  wire [31:0] op1_i            ,
    input  wire [31:0] op2_i            ,
    input  wire [4:0]  reg_waddr_i      ,

    // to EX
    output reg         mul_busy_o       ,
    output reg         mul_ready_o      ,
    output reg  [63:0] mul_result64_o   ,
    output reg  [4:0]  rd_waddr_o       ,
    output reg  [2:0]  funct3_o         
);

    // ------------------------------------------------------------
    // 2's complement functions
    // ------------------------------------------------------------
    function [31:0] abs32;
        input [31:0] x;
        begin
            abs32 = x[31] ? (~x + 32'd1) : x;
        end
    endfunction

    function [63:0] neg64;
        input [63:0] x;
        begin
            neg64 = ~x + 64'd1;
        end
    endfunction

    // ------------------------------------------------------------
    // signed determined
    // ------------------------------------------------------------
    wire op1_is_signed = (funct3_i == `INST_MUL)  ||
                         (funct3_i == `INST_MULH) ||
                         (funct3_i == `INST_MULHSU);

    wire op2_is_signed = (funct3_i == `INST_MUL)  ||
                         (funct3_i == `INST_MULH);

    wire op1_is_neg = op1_is_signed && op1_i[31];
    wire op2_is_neg = op2_is_signed && op2_i[31];

    wire sign_next = op1_is_neg ^ op2_is_neg;

    wire [31:0] op1_mag = op1_is_neg ? abs32(op1_i) : op1_i;
    wire [31:0] op2_mag = op2_is_neg ? abs32(op2_i) : op2_i;

    // ------------------------------------------------------------
    // FSM + datapath
    // ------------------------------------------------------------
    localparam STATE_IDLE = 2'd0;
    localparam STATE_RUN  = 2'd1;
    localparam STATE_END  = 2'd2;

    reg [1:0]  state        ;
    reg [5:0]  step         ;
    
    reg        sign         ;
    reg [63:0] acc          ;
    reg [63:0] mcand        ;
    reg [31:0] mplier       ;

    wire [63:0] acc_next = acc + (mplier[0] ? mcand : 64'd0);

    // ------------------------------------------------------------
    // Main FSM
    // ------------------------------------------------------------
    always @(posedge clk) begin
        if (!rst_n) begin
            state          <= STATE_IDLE;
            mul_busy_o     <= 1'b0;
            mul_ready_o    <= 1'b0;
            mul_result64_o <= 64'd0;

            rd_waddr_o <= 5'd0;
            funct3_o   <= 3'd0;

            step   <= 6'd0;
            sign   <= 1'b0;
            acc    <= 64'd0;
            mcand  <= 64'd0;
            mplier <= 32'd0;
        end
        else begin
            mul_ready_o <= 1'b0;  // default

            case (state)
                STATE_IDLE: begin               // IDLE
                    mul_busy_o <= 1'b0;

                    if (mul_start_i) begin
                        // latch control
                        funct3_o   <= funct3_i;
                        rd_waddr_o <= reg_waddr_i;

                        // init datapath
                        sign   <= sign_next;
                        acc    <= 64'd0;
                        mcand  <= {32'd0, op1_mag};
                        mplier <= op2_mag;
                        step   <= 6'd0;

                        state      <= STATE_RUN;
                        mul_busy_o <= 1'b1;
                    end

                end

                STATE_RUN: begin                // RUN
                    mul_busy_o <= 1'b1;

                    acc    <= acc_next;
                    mcand  <= mcand << 1;
                    mplier <= mplier >> 1;

                    if (step == LATENCY - 1) begin
                        state <= STATE_END;
                        mul_result64_o <= sign ? neg64(acc_next) : acc_next;
                    end
                    else begin
                        step <= step + 6'd1;
                    end

                end

                STATE_END: begin                // END                     
                    state <= STATE_IDLE;
                    mul_busy_o  <= 1'b0;
                    mul_ready_o <= 1'b1;
                    
                    step <= 6'd0;

                end

            endcase
        end
    end

endmodule
