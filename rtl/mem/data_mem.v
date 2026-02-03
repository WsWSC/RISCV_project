////////////////////////////////////////////////////////////
//  RISC-V CPU Side Project
//  Author  : WsWSC
//  Created : 2026
//  License : Personal / Educational Use
////////////////////////////////////////////////////////////

`include "defines.v"

module data_ram (
    input  wire                 clk         ,
    input  wire                 rst_n       ,

    // write data
    input  wire[3:0]            w_en_i      ,
    input  wire[`MemAddrBus]    w_addr_i    ,
    input  wire[`MemDataBus]    w_data_i    ,

    // read data
    input  wire                 r_en_i      ,
    input  wire[`MemAddrBus]    r_addr_i    ,

    output wire[`MemDataBus]    r_data_o    
);

    wire [11:0] w_idx = w_addr_i[13:2];
    wire [11:0] r_idx = r_addr_i[13:2];

    // byte 0
    dual_ram #(
        .DW         (8),
        .AW         (12),
        .MEM_NUM    (4096)
    ) data_ram_byte0
    (
        .clk        (clk                ),
        .rst_n      (rst_n              ),
        
        // write data               
        .w_en_i     (w_en_i[0]          ),
        .w_addr_i   (w_addr_i           ),
        .w_data_i   (w_data_i[7:0]      ),
        
        // read data            
        .r_en_i     (r_en_i             ),
        .r_addr_i   (r_addr_i           ),
        
        .r_data_o   (r_data_o[7:0]      )
    );

    // byte 1
    dual_ram #(
        .DW         (8),
        .AW         (12),
        .MEM_NUM    (4096)
    ) data_ram_byte1
    (
        .clk        (clk                ),
        .rst_n      (rst_n              ),

        // write data        
        .w_en_i     (w_en_i[1]          ),
        .w_addr_i   (w_addr_i           ),
        .w_data_i   (w_data_i[15:8]     ),

        // read data       
        .r_en_i     (r_en_i             ),
        .r_addr_i   (r_addr_i           ),

        .r_data_o   (r_data_o[15:8]     )
    );

    // byte 2
    dual_ram #(
        .DW         (8),
        .AW         (12),
        .MEM_NUM    (4096)
    ) data_ram_byte2
    (
        .clk        (clk                ),
        .rst_n      (rst_n              ),

        // write data        
        .w_en_i     (w_en_i[2]          ),
        .w_addr_i   (w_addr_i           ),
        .w_data_i   (w_data_i[23:16]    ),

        // read data       
        .r_en_i     (r_en_i             ),
        .r_addr_i   (r_addr_i           ),

        .r_data_o   (r_data_o[23:16]    )
    );

    // byte 3
    dual_ram #(
        .DW         (8),
        .AW         (12),
        .MEM_NUM    (4096)
    ) data_ram_byte3
    (
        .clk        (clk                ),
        .rst_n      (rst_n              ),

        // write data        
        .w_en_i     (w_en_i[3]          ),
        .w_addr_i   (w_addr_i           ),
        .w_data_i   (w_data_i[31:24]    ),

        // read data       
        .r_en_i     (r_en_i             ),
        .r_addr_i   (r_addr_i           ),

        .r_data_o   (r_data_o[31:24]    )
    );


    
endmodule