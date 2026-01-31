////////////////////////////////////////////////////////////
//  RISC-V CPU Side Project
//  Author  : WsWSC
//  Created : 2026
//  License : Personal / Educational Use
////////////////////////////////////////////////////////////

`include "defines.v"

module id_ex(
    input  wire         clk,
    input  wire         rst_n,

    // from ctrl
    input  wire         hold_flag_i,

    // from id
    input  wire[31:0]   inst_addr_i,
    input  wire[31:0]   inst_i,
    input  wire[31:0]   op1_i,
    input  wire[31:0]   op2_i,
    input  wire[4:0]    rd_addr_i,
    input  wire         reg_wen_i,

    // to ex
    output wire[31:0]   inst_addr_o,
    output wire[31:0]   inst_o,
    output wire[31:0]   op1_o,
    output wire[31:0]   op2_o,
    output wire[4:0]    rd_addr_o,
    output wire         reg_wen_o
);

    // pass instruction addr & instruction
    dff_set #(.DW(32)) dff1(.clk(clk), .rst_n(rst_n), .hold_flag_i(hold_flag_i), .set_data(`ZeroWord)    , .data_i(inst_addr_i), .data_o(inst_addr_o) );
    dff_set #(.DW(32)) dff2(.clk(clk), .rst_n(rst_n), .hold_flag_i(hold_flag_i), .set_data(`INST_NOP)    , .data_i(inst_i)     , .data_o(inst_o)      );
    dff_set #(.DW(32)) dff3(.clk(clk), .rst_n(rst_n), .hold_flag_i(hold_flag_i), .set_data(`ZeroWord)    , .data_i(op1_i)      , .data_o(op1_o)       );
    dff_set #(.DW(32)) dff4(.clk(clk), .rst_n(rst_n), .hold_flag_i(hold_flag_i), .set_data(`ZeroWord)    , .data_i(op2_i)      , .data_o(op2_o)       );
    dff_set #(.DW(5) ) dff5(.clk(clk), .rst_n(rst_n), .hold_flag_i(hold_flag_i), .set_data(`ZeroReg)     , .data_i(rd_addr_i)  , .data_o(rd_addr_o)   );
    dff_set #(.DW(1) ) dff6(.clk(clk), .rst_n(rst_n), .hold_flag_i(hold_flag_i), .set_data(`WriteDisable), .data_i(reg_wen_i)  , .data_o(reg_wen_o)   );

endmodule