////////////////////////////////////////////////////////////
//  RISC-V CPU Side Project
//  Author  : WsWSC
//  Created : 2026
//  License : Personal / Educational Use
////////////////////////////////////////////////////////////

`include "defines.v"

module if_id(
    input  wire         clk,
    input  wire         rst_n,

    // from ctrl    
    input  wire         hold_flag_i,

    // from ifetch
    input  wire[31:0]   inst_addr_i,
    input  wire[31:0]   inst_i,

    // to id
    output wire[31:0]   inst_addr_o,
    output wire[31:0]   inst_o
);

    // pass instruction addr & instruction
    dff_set #(.DW(32)) dff1(.clk(clk), .rst_n(rst_n), .hold_flag_i(hold_flag_i), .set_data(32'b0)    , .data_i(inst_addr_i), .data_o(inst_addr_o) );
    dff_set #(.DW(32)) dff2(.clk(clk), .rst_n(rst_n), .hold_flag_i(hold_flag_i), .set_data(`INST_NOP), .data_i(inst_i)     , .data_o(inst_o)      );

endmodule