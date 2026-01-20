////////////////////////////////////////////////////////////
//  RISC-V CPU Side Project
//  Author  : WsWSC
//  Created : 2026
//  License : Personal / Educational Use
////////////////////////////////////////////////////////////

// module reuse
module dff_set #(
    parameter DW = 32
)
(
    input wire clk,
    input wire rst_n,
    input wire [DW-1:0] set_data,
    input wire [DW-1:0] data_i,
    
    output reg [DW-1:0] data_o
);

    always @(posedge clk) begin
        if(rst_n == 1'b0)
            data_o <= set_data;     // reset data_o
        else    
            data_o <= data_i;
    end

endmodule