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
    input  wire         stall_flag_i    ,

    // from ifetch
    input  wire[31:0]   inst_addr_i     ,
    input  wire[31:0]   inst_i          ,

    // to id
    output wire[31:0]   inst_addr_o     ,
    output wire[31:0]   inst_o          
);

    reg inst_valid;

    always @(posedge clk) begin
        if (!rst_n) begin
            inst_valid <= 1'b0;
        end else if (flush_flag_i == `FlushEnable) begin    // flush
            inst_valid <= 1'b0;
        end else if (stall_flag_i == `StallEnable) begin    // stall
            inst_valid <= inst_valid;
        end else begin
            inst_valid <= 1'b1;
        end
    end

    // output instruction: NOP when invalid (reset/flush window), otherwise pass inst_i
    assign inst_o = inst_valid ? inst_i : `INST_NOP;

    // pass addr & instruction
    dff_set #(.DW(32)) dff1(.clk(clk), .rst_n(rst_n), .flush_flag_i(flush_flag_i), .stall_flag_i(stall_flag_i), .set_data(32'b0), .data_i(inst_addr_i), .data_o(inst_addr_o) );
    //dff_set #(.DW(32)) dff2(.clk(clk), .rst_n(rst_n), .flush_flag_i(flush_flag_i), stall_flag_i(stall_flag_i), .set_data(`INST_NOP), .data_i(inst_i)     , .data_o(inst_o)      );

endmodule