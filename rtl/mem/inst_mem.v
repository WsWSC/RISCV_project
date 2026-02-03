////////////////////////////////////////////////////////////
//  RISC-V CPU Side Project
//  Author  : WsWSC
//  Created : 2026
//  License : Personal / Educational Use
////////////////////////////////////////////////////////////

`include "defines.v"

module inst_mem(
    input  wire                 clk         ,
    input  wire                 rst_n       ,

    // write data
    input  wire                 w_en_i      ,
    input  wire[`MemAddrBus]    w_addr_i    ,
    input  wire[`MemDataBus]    w_data_i    ,

    // read data
    input  wire                 r_en_i      ,
    input  wire[`MemAddrBus]    r_addr_i    ,

    output wire[`MemDataBus]    r_data_o    
);

    wire [11:0] w_idx = w_addr_i[13:2];
    wire [11:0] r_idx = r_addr_i[13:2];

    dual_ram #(
        .DW         (32),
        .AW         (12),
        .MEM_NUM    (4096)
    ) dual_ram_inst
    (
        .clk         (clk       ),
        .rst_n       (rst_n     ),

        // write data   
        .w_en_i      (w_en_i    ),
        .w_addr_i    (w_idx     ),
        .w_data_i    (w_data_i  ),

        // read data    
        .r_en_i      (r_en_i    ),
        .r_addr_i    (r_idx     ),

        .r_data_o    (r_data_o  )
    );

endmodule