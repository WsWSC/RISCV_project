////////////////////////////////////////////////////////////
//  RISC-V CPU Side Project
//  Author  : WsWSC
//  Created : 2026
//  License : Personal / Educational Use
////////////////////////////////////////////////////////////

module soc(
    input   wire        clk,
    input   wire        rst_n
);

    // ============================================================
    //  Wire Declarations
    // ============================================================

    // core to inst_mem
    wire[31:0]  core_inst_addr_o    ;

    // inst_mem to core
    wire[31:0]  inst_mem_inst_o     ;

    // data mem read (from id)
    wire        data_mem_r_en_o     ;
    wire[31:0]  data_mem_r_addr_o   ;
    wire[31:0]  data_mem_r_data_i   ;

    // data mem write (from ex)
    wire        data_mem_w_en_o     ;
    wire[3:0]   data_mem_w_sel_o    ;
    wire[31:0]  data_mem_w_addr_o   ;
    wire[31:0]  data_mem_w_data_o   ;


    // ============================================================
    //  Module Instantiation & Interconnection
    // ============================================================

    core core_inst(
        .clk                (clk                ),
        .rst_n              (rst_n              ),
        .inst_i             (inst_mem_inst_o    ),

        .inst_addr_o        (core_inst_addr_o   ),

        .data_mem_r_en_o    (data_mem_r_en_o    ),
        .data_mem_r_addr_o  (data_mem_r_addr_o  ),
        .data_mem_r_data_i  (data_mem_r_data_i  ),

        .data_mem_w_en_o    (data_mem_w_en_o    ),
        .data_mem_w_sel_o   (data_mem_w_sel_o   ),
        .data_mem_w_addr_o  (data_mem_w_addr_o  ),
        .data_mem_w_data_o  (data_mem_w_data_o  )
    );

    inst_mem inst_mem_inst(
        .clk                (clk                ),
        .rst_n              (rst_n              ),

        // write data, #todo
        .w_en_i             (1'b0               ),
        .w_addr_i           (32'b0              ),
        .w_data_i           (32'b0              ),

        // read data, always enable
        .r_en_i             (1'b1),
        .r_addr_i           (core_inst_addr_o   ),

        .r_data_o           (inst_mem_inst_o    )
    );

    data_mem data_mem_inst(
        .clk                (clk                ),
        .rst_n              (rst_n              ),

        // write data   
        .w_en_i             (data_mem_w_en_o ? data_mem_w_sel_o : 4'b0000),
        .w_addr_i           (data_mem_w_addr_o  ),
        .w_data_i           (data_mem_w_data_o  ),

        // read data    
        .r_en_i             (data_mem_r_en_o    ),
        .r_addr_i           (data_mem_r_addr_o  ),

        .r_data_o           (data_mem_r_data_i  )
    );

endmodule