//////////////////////////////////////////////////
// risc v side project                          //
//                                              //
// create by WsWSC                              //
//////////////////////////////////////////////////

`include "defines.v"
`include "dff_set.v"

module if_id(
    input wire clk,
    input wire rst,
    input wire[31:0] inst_i,
    input wire[31:0] inst_addr_i,

    output reg[31:0] inst_addr_o,
    output reg[31:0] inst_o
);

    // no op
    dff_set #(32) dff1(.clk(clk), .rst(rst), .set_data(`INST_NOP), .data_i(inst_i), 
        .data_o(inst_o) );
    dff_set #(32) dff2(.clk(clk), .rst(rst), .set_data(32'b0), .data_i(inst_addr_i),
        .data_o(inst_addr_o) );

endmodule