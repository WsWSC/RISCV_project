////////////////////////////////////////////////////////////
//  RISC-V CPU Side Project
//  Author  : WsWSC
//  Created : 2026
//  License : Personal / Educational Use
////////////////////////////////////////////////////////////

`include "defines.v"

module data_mem (
    input  wire                 clk,
    input  wire                 rst_n,

    input  wire                 w_en_i,
    input  wire [`MemAddrBus]   w_addr_i,
    input  wire [`MemDataBus]   w_data_i,

    input  wire [`MemAddrBus]   r_addr_i,
    output reg  [`MemDataBus]   r_data_o
);

    reg [`MemDataBus] ram [0:`MemNum - 1];

    always @(posedge clk) begin
        if (rst_n && (w_en_i == `WriteEnable)) begin
            ram[w_addr_i[31:2]] <= w_data_i;
        end
    end

    always @(*) begin
        if (!rst_n) begin
            r_data_o = `ZeroWord;
        end else begin
            r_data_o = ram[r_addr_i[31:2]];
        end
    end

endmodule