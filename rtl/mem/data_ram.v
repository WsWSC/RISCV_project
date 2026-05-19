////////////////////////////////////////////////////////////
//  RISC-V CPU Side Project
//  Author  : WsWSC
//  Created : 2026
//  License : Personal / Educational Use
////////////////////////////////////////////////////////////

`include "defines.v"

module data_ram (
    input  wire                 clk,
    input  wire                 rst_n,

    input  wire                 w_en_i,
    input  wire [3:0]           w_sel_i,
    input  wire [`MemAddrBus]   w_addr_i,
    input  wire [`MemDataBus]   w_data_i,

    input  wire [`MemAddrBus]   r_addr_i,

    output reg  [`MemDataBus]   r_data_o
);

    // ============================================================
    //  Wire Declarations
    // ============================================================
    reg [`MemDataBus] ram [0:`MemNum - 1];


    // ============================================================
    //  Main logic
    // ============================================================
    always @(posedge clk) begin
        if (rst_n && (w_en_i == `WriteEnable)) begin
            if (w_sel_i[0]) begin
                ram[w_addr_i[31:2]][ 7: 0] <= w_data_i[ 7: 0];
            end
            if (w_sel_i[1]) begin
                ram[w_addr_i[31:2]][15: 8] <= w_data_i[15: 8];
            end
            if (w_sel_i[2]) begin
                ram[w_addr_i[31:2]][23:16] <= w_data_i[23:16];
            end
            if (w_sel_i[3]) begin
                ram[w_addr_i[31:2]][31:24] <= w_data_i[31:24];
            end
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
