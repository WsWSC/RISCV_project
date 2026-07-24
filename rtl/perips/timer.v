////////////////////////////////////////////////////////////
//  RISC-V CPU Side Project
//  Author  : WsWSC
//  Created : 2026
//  License : Personal / Educational Use
////////////////////////////////////////////////////////////

`include "defines.v"

module timer (
    input  wire                 clk,
    input  wire                 rst_n,

    input  wire                 w_en_i,
    input  wire [3:0]           w_sel_i,
    input  wire [`MemAddrBus]   w_addr_i,
    input  wire [`MemDataBus]   w_data_i,

    input  wire [`MemAddrBus]   r_addr_i,

    output reg  [`MemDataBus]   r_data_o,
    output wire                 timer_irq_o
);

    // ============================================================
    //  Internal Signals
    // ============================================================
    localparam [1:0]   TIMER_REG_CTRL     = 2'b00;
    localparam [1:0]   TIMER_REG_COUNT    = 2'b01;
    localparam [1:0]   TIMER_REG_COMPARE  = 2'b10;
    localparam [1:0]   TIMER_REG_STATUS   = 2'b11;

    reg [`MemDataBus]  timer_ctrl          ;
    reg [`MemDataBus]  timer_count         ;
    reg [`MemDataBus]  timer_compare       ;

    wire               timer_enable        ;
    wire               timer_clear         ;
    wire               compare_hit         ;

    assign timer_enable = timer_ctrl[0];
    assign timer_clear  = (w_en_i == `WriteEnable) &&
                          (w_addr_i[3:2] == TIMER_REG_CTRL) &&
                          w_sel_i[0] && w_data_i[1];
    assign compare_hit  = (timer_count >= timer_compare);
    assign timer_irq_o  = (timer_enable && compare_hit) ? `InterruptAssert : `InterruptDeassert;


    // ============================================================
    //  Write Mask
    // ============================================================
    function [`MemDataBus] apply_wstrb;
        input [`MemDataBus] old_data;
        input [`MemDataBus] new_data;
        input [3:0]         byte_sel;
        begin
            apply_wstrb = old_data;
            if (byte_sel[0]) begin
                apply_wstrb[ 7: 0] = new_data[ 7: 0];
            end
            if (byte_sel[1]) begin
                apply_wstrb[15: 8] = new_data[15: 8];
            end
            if (byte_sel[2]) begin
                apply_wstrb[23:16] = new_data[23:16];
            end
            if (byte_sel[3]) begin
                apply_wstrb[31:24] = new_data[31:24];
            end
        end
    endfunction


    // ============================================================
    //  Main logic
    // ============================================================
    always @(posedge clk) begin
        if (!rst_n) begin
            timer_ctrl    <= `ZeroWord;
            timer_count   <= `ZeroWord;
            timer_compare <= 32'hffff_ffff;
        end else begin
            if (w_en_i == `WriteEnable) begin
                case (w_addr_i[3:2])
                    TIMER_REG_CTRL: begin
                        timer_ctrl <= apply_wstrb(timer_ctrl, w_data_i, w_sel_i) & 32'hffff_fffd;
                    end

                    TIMER_REG_COUNT: begin
                        timer_count <= apply_wstrb(timer_count, w_data_i, w_sel_i);
                    end

                    TIMER_REG_COMPARE: begin
                        timer_compare <= apply_wstrb(timer_compare, w_data_i, w_sel_i);
                    end

                    default: begin
                    end
                endcase
            end

            if (timer_clear) begin
                timer_count <= `ZeroWord;
            end else if ((w_en_i != `WriteEnable) && timer_enable) begin
                timer_count <= timer_count + 1'b1;
            end
        end
    end

    always @(*) begin
        if (!rst_n) begin
            r_data_o = `ZeroWord;
        end else begin
            case (r_addr_i[3:2])
                TIMER_REG_CTRL: begin
                    r_data_o = timer_ctrl;
                end

                TIMER_REG_COUNT: begin
                    r_data_o = timer_count;
                end

                TIMER_REG_COMPARE: begin
                    r_data_o = timer_compare;
                end

                TIMER_REG_STATUS: begin
                    r_data_o = {31'b0, compare_hit};
                end

                default: begin
                    r_data_o = `ZeroWord;
                end
            endcase
        end
    end

endmodule
