////////////////////////////////////////////////////////////
//  RISC-V CPU Side Project
//  Author  : WsWSC
//  Created : 2026
//  License : Personal / Educational Use
////////////////////////////////////////////////////////////

`ifndef __DFF_SET_V__
`define __DFF_SET_V__

`include "defines.v"

module dff_set #(
    parameter DW = 32
)
(
    input  wire             clk             ,
    input  wire             rst_n           ,
    input  wire             flush_flag_i    ,
    input  wire             stall_flag_i    ,
    input  wire[DW-1:0]     set_data        ,
    input  wire[DW-1:0]     data_i          ,

    output reg [DW-1:0]     data_o
);

    // ============================================================
    //  Main logic
    // ============================================================
    always @(posedge clk) begin
        if (!rst_n) begin
            data_o <= set_data;
        end else if (flush_flag_i == `FlushEnable) begin        // flush
            data_o <= set_data;
        end else if (stall_flag_i == `StallEnable) begin        // hold
            data_o <= data_o;
        end else begin
            data_o <= data_i;
        end
    end

endmodule

`endif
