//////////////////////////////////////////////////
// risc v side project                          //
//                                              //
// create by WsWSC                              //
//////////////////////////////////////////////////

// module reuse
module dff_set(
    parameter DW = 32
)
(
    input wire clk,
    input wire rst,
    input wire [DW-1:0] set_data,
    input wire [DW-1:0] data_i,
    
    output reg [DW-1:0] data_o
);

    always @(posedge clk) begin
        if(rst == 1'b0)
            data_o <= set_data;     //reset data_o
        else    
            data_o <= data_i;
    end

endmodule