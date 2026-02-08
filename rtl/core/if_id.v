////////////////////////////////////////////////////////////
//  RISC-V CPU Side Project
//  Author  : WsWSC
//  Created : 2026
//  License : Personal / Educational Use
////////////////////////////////////////////////////////////

`include "defines.v"

module if_id(
    input  wire         clk             ,
    input  wire         rst_n           ,

    // from ctrl    
    input  wire         flush_flag_i    ,

    // from ifetch
    input  wire[31:0]   inst_addr_i     ,
    input  wire[31:0]   inst_i          ,

    // to id
    output wire[31:0]   inst_addr_o     ,
    output wire[31:0]   inst_o          
);

    // flush_flag_i enable, insert nop in same cycle
    reg inst_mem_flag;

    always @(posedge clk) begin
        if (!rst_n || flush_flag_i) begin
            inst_mem_flag <= 1'b0;    
        end else begin
            inst_mem_flag <= 1'b1;
        end
        
    end

    assign inst_o = inst_mem_flag ? inst_i : `INST_NOP;

    // pass addr & instruction
    dff_set #(.DW(32)) dff1(.clk(clk), .rst_n(rst_n), .flush_flag_i(flush_flag_i), .set_data(32'b0)    , .data_i(inst_addr_i), .data_o(inst_addr_o) );
    //dff_set #(.DW(32)) dff2(.clk(clk), .rst_n(rst_n), .flush_flag_i(flush_flag_i), .set_data(`INST_NOP), .data_i(inst_i)     , .data_o(inst_o)      );

endmodule