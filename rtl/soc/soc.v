////////////////////////////////////////////////////////////
//  RISC-V CPU Side Project
//  Author  : WsWSC
//  Created : 2026
//  License : Personal / Educational Use
////////////////////////////////////////////////////////////

module soc(
    input   wire        clk,
    input   wire        rst_n,
    input   wire        external_irq_i
);

    // ============================================================
    //  Wire Declarations
    // ============================================================

    // core to inst_rom
    wire[31:0]  core_inst_addr_o ;

    // inst_rom to core
    wire[31:0]  inst_rom_inst_o  ;

    // data_ram read (from id)
    wire        core_data_ram_r_en_o        ;
    wire[31:0]  core_data_ram_r_addr_o      ;
    wire[31:0]  data_ram_data_ram_r_data_i  ;

    // data_ram write (from ex)
    wire        core_data_ram_w_en_o    ;
    wire[3:0]   core_data_ram_w_sel_o   ;
    wire[31:0]  core_data_ram_w_addr_o  ;
    wire[31:0]  core_data_ram_w_data_o  ;


    // ============================================================
    //  Module Instantiation & Interconnection
    // ============================================================

    core core_inst(
        .clk                (clk                        ),
        .rst_n              (rst_n                      ),
        .inst_i             (inst_rom_inst_o            ),

        .inst_addr_o        (core_inst_addr_o           ),

        .data_ram_r_en_o    (core_data_ram_r_en_o       ),
        .data_ram_r_addr_o  (core_data_ram_r_addr_o     ),
        .data_ram_r_data_i  (data_ram_data_ram_r_data_i ),

        .data_ram_w_en_o    (core_data_ram_w_en_o       ),
        .data_ram_w_sel_o   (core_data_ram_w_sel_o      ),
        .data_ram_w_addr_o  (core_data_ram_w_addr_o     ),
        .data_ram_w_data_o  (core_data_ram_w_data_o     ),

        .external_irq_i     (external_irq_i             )
    );

    inst_rom inst_rom_inst(
        .clk                (clk                ),
        .rst_n              (rst_n              ),

        // write data, #todo
        .w_en_i             (1'b0               ),
        .w_addr_i           (32'b0              ),
        .w_data_i           (32'b0              ),

        // read data, always enable
        //.r_en_i             (1'b1),
        .r_addr_i           (core_inst_addr_o   ),

        .r_data_o           (inst_rom_inst_o    )
    );

    data_ram data_ram_inst(
        .clk                (clk                        ),
        .rst_n              (rst_n                      ),

        // write data
        .w_en_i             (core_data_ram_w_en_o       ),
        .w_sel_i            (core_data_ram_w_sel_o      ),
        .w_addr_i           (core_data_ram_w_addr_o     ),
        .w_data_i           (core_data_ram_w_data_o     ),

        // read data    
        //.r_en_i             (data_ram_r_en_o            ),
        .r_addr_i           (core_data_ram_r_addr_o     ),

        .r_data_o           (data_ram_data_ram_r_data_i )
    );

endmodule
