////////////////////////////////////////////////////////////
//  RISC-V CPU Side Project
//  Author  : WsWSC
//  Created : 2026
//  License : Personal / Educational Use
////////////////////////////////////////////////////////////

`include "defines.v"

module inst_rom (
    input  wire                 clk,
    input  wire                 rst_n,

    // write interface
    input  wire                 w_en_i,
    input  wire [`MemAddrBus]   w_addr_i,
    input  wire [`MemDataBus]   w_data_i,

    // read interface
    input  wire [`MemAddrBus]   r_addr_i,
    output reg  [`MemDataBus]   r_data_o
);

    // ============================================================
    //  Internal Signals
    // ============================================================
    reg [`MemAddrBus] rom_mem [0:`MemNum - 1];

    // ============================================================
    //  Main logic
    // ============================================================
    // write data
    always @(posedge clk) begin
        if (w_en_i == `WriteEnable) begin
            rom_mem[w_addr_i[31:2]] <= w_data_i;
        end
    end

    // combinational read
    always @(*) begin
        if (!rst_n) begin
            r_data_o = `ZeroWord;
        end else begin
            r_data_o = rom_mem[r_addr_i[31:2]];
        end
    end

endmodule

