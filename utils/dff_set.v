////////////////////////////////////////////////////////////
//  RISC-V CPU Side Project
//  Author  : WsWSC
//  Created : 2026
//  License : Personal / Educational Use
////////////////////////////////////////////////////////////

`ifndef __DFF_SET_V__
`define __DFF_SET_V__

`include "../rtl/defines.v"

// module reuse
module dff_set #(
    parameter DW = 32
)
(
    input  wire             clk         ,
    input  wire             rst_n       ,
    input  wire             hold_flag_i ,
    input  wire[DW-1:0]     set_data    ,
    input  wire[DW-1:0]     data_i      ,

    output reg [DW-1:0]     data_o
);

    always @(posedge clk) begin
        if(rst_n == 1'b0 || hold_flag_i == `HoldEnable)
            data_o <= set_data;     // reset data_o
        else    
            data_o <= data_i;
    end

endmodule

`endif