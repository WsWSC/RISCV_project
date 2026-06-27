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
    //  Internal Signals
    // ============================================================
    localparam [31:0]  RAM_BASE       = 32'h0000_0000;
    localparam [31:0]  RAM_SIZE       = (`MemNum << 2);
    localparam [31:0]  RAM_END        = RAM_BASE + RAM_SIZE;

    wire               rib_r_ram_sel  ;
    wire               rib_w_ram_sel  ;

    // select data_ram for in-range load
    assign rib_r_ram_sel = (rib_r_en_i == `ReadEnable) &&
                           (rib_r_addr_i >= RAM_BASE) &&
                           (rib_r_addr_i <  RAM_END);

    // select data_ram for in-range store
    assign rib_w_ram_sel = (rib_w_en_i == `WriteEnable) &&
                           (rib_w_addr_i >= RAM_BASE) &&
                           (rib_w_addr_i <  RAM_END);


    // ============================================================
    //  Main logic
    // ============================================================
    always @(*) begin
        // out-of-range access: read zero, ignore write
        ram_w_en_o   = rib_w_ram_sel ? rib_w_en_i   : `WriteDisable;
        ram_w_sel_o  = rib_w_ram_sel ? rib_w_sel_i  : 4'b0;
        ram_w_addr_o = rib_w_ram_sel ? rib_w_addr_i : `ZeroAddr;
        ram_w_data_o = rib_w_ram_sel ? rib_w_data_i : `ZeroWord;

        // in-range access: pass through to data_ram
        ram_r_addr_o = rib_r_ram_sel ? rib_r_addr_i : `ZeroAddr;
        rib_r_data_o = rib_r_ram_sel ? ram_r_data_i : `ZeroWord;
    end

endmodule
