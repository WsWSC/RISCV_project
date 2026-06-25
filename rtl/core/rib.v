////////////////////////////////////////////////////////////
//  RISC-V CPU Side Project
//  Author  : WsWSC
//  Created : 2026
//  License : Personal / Educational Use
////////////////////////////////////////////////////////////

`include "defines.v"

module rib(
    input  wire                 clk,
    input  wire                 rst_n,

    // from core data access
    input  wire                 rib_r_en_i,
    input  wire [`MemAddrBus]   rib_r_addr_i,
    output reg  [`MemDataBus]   rib_r_data_o,

    input  wire                 rib_w_en_i,
    input  wire [3:0]           rib_w_sel_i,
    input  wire [`MemAddrBus]   rib_w_addr_i,
    input  wire [`MemDataBus]   rib_w_data_i,

    // to data_ram
    output reg                  ram_w_en_o,
    output reg  [3:0]           ram_w_sel_o,
    output reg  [`MemAddrBus]   ram_w_addr_o,
    output reg  [`MemDataBus]   ram_w_data_o,

    output reg  [`MemAddrBus]   ram_r_addr_o,
    input  wire [`MemDataBus]   ram_r_data_i
);

    // ============================================================
    //  Main logic
    // ============================================================
    always @(*) begin
        ram_w_en_o   = rib_w_en_i;
        ram_w_sel_o  = rib_w_sel_i;
        ram_w_addr_o = rib_w_addr_i;
        ram_w_data_o = rib_w_data_i;

        ram_r_addr_o = rib_r_addr_i;
        rib_r_data_o = ram_r_data_i;
    end

endmodule
