////////////////////////////////////////////////////////////
//  RISC-V CPU Side Project
//  Author  : WsWSC
//  Created : 2026
//  License : Personal / Educational Use
////////////////////////////////////////////////////////////

module soc(
    input  wire         clk,
    input  wire         rst_n,
    input  wire         external_irq_i,
    input  wire         uart_rx_i,
    output wire         uart_tx_o
);

    // ============================================================
    //  Internal Signals
    // ============================================================
    // core to inst_rom
    wire[31:0]  core_inst_addr_o ;
    wire        rib_if_stall_o    ;

    // rib to core instruction fetch
    wire[31:0]  rib_if_r_data_o  ;

    // rib to inst_rom
    wire[31:0]  rib_rom_r_addr_o ;
    wire[31:0]  inst_rom_r_data_o;

    // core to rib read
    wire        core_data_ram_r_en_o        ;
    wire[31:0]  core_data_ram_r_addr_o      ;
    wire[31:0]  rib_data_ram_r_data_o       ;

    // core to rib write
    wire        core_data_ram_w_en_o    ;
    wire[3:0]   core_data_ram_w_sel_o   ;
    wire[31:0]  core_data_ram_w_addr_o  ;
    wire[31:0]  core_data_ram_w_data_o  ;

    // rib to data_ram read
    wire[31:0]  rib_data_ram_r_addr_o    ;
    wire[31:0]  data_ram_r_data_o        ;

    // rib to data_ram write
    wire        rib_data_ram_w_en_o      ;
    wire[3:0]   rib_data_ram_w_sel_o     ;
    wire[31:0]  rib_data_ram_w_addr_o    ;
    wire[31:0]  rib_data_ram_w_data_o    ;

    // rib to timer read
    wire[31:0]  rib_timer_r_addr_o       ;
    wire[31:0]  timer_r_data_o           ;
    wire        timer_irq_o              ;

    // rib to timer write
    wire        rib_timer_w_en_o         ;
    wire[3:0]   rib_timer_w_sel_o        ;
    wire[31:0]  rib_timer_w_addr_o       ;
    wire[31:0]  rib_timer_w_data_o       ;

    // rib to uart read
    wire[31:0]  rib_uart_r_addr_o        ;
    wire[31:0]  uart_r_data_o            ;

    // rib to uart write
    wire        rib_uart_w_en_o          ;
    wire[3:0]   rib_uart_w_sel_o         ;
    wire[31:0]  rib_uart_w_addr_o        ;
    wire[31:0]  rib_uart_w_data_o        ;


    // ============================================================
    //  Module Instantiation & Interconnection
    // ============================================================
    core core_inst(
        .clk                (clk                        ),
        .rst_n              (rst_n                      ),
        .inst_i             (rib_if_r_data_o            ),

        .inst_addr_o        (core_inst_addr_o           ),
        .inst_stall_i       (rib_if_stall_o             ),

        .data_ram_r_en_o    (core_data_ram_r_en_o       ),
        .data_ram_r_addr_o  (core_data_ram_r_addr_o     ),
        .data_ram_r_data_i  (rib_data_ram_r_data_o      ),

        .data_ram_w_en_o    (core_data_ram_w_en_o       ),
        .data_ram_w_sel_o   (core_data_ram_w_sel_o      ),
        .data_ram_w_addr_o  (core_data_ram_w_addr_o     ),
        .data_ram_w_data_o  (core_data_ram_w_data_o     ),

        .external_irq_i     (external_irq_i             ),
        .timer_irq_i        (timer_irq_o                )
    );

    inst_rom inst_rom_inst(
        .clk                (clk                ),
        .rst_n              (rst_n              ),

        // write disabled
        .w_en_i             (1'b0               ),
        .w_addr_i           (32'b0              ),
        .w_data_i           (32'b0              ),

        // read data
        .r_addr_i           (rib_rom_r_addr_o   ),

        .r_data_o           (inst_rom_r_data_o  )
    );

    rib rib_inst(
        .clk                (clk                    ),
        .rst_n              (rst_n                  ),

        // master 0: instruction fetch
        .m0_if_r_addr_i     (core_inst_addr_o       ),
        .m0_if_r_data_o     (rib_if_r_data_o        ),
        .m0_if_stall_o      (rib_if_stall_o         ),

        // master 1: load/store memory access
        .m1_mem_r_en_i      (core_data_ram_r_en_o   ),
        .m1_mem_r_addr_i    (core_data_ram_r_addr_o ),
        .m1_mem_r_data_o    (rib_data_ram_r_data_o  ),

        .m1_mem_w_en_i      (core_data_ram_w_en_o   ),
        .m1_mem_w_sel_i     (core_data_ram_w_sel_o  ),
        .m1_mem_w_addr_i    (core_data_ram_w_addr_o ),
        .m1_mem_w_data_i    (core_data_ram_w_data_o ),

        // slave 1: data_ram
        .s1_ram_w_en_o      (rib_data_ram_w_en_o    ),
        .s1_ram_w_sel_o     (rib_data_ram_w_sel_o   ),
        .s1_ram_w_addr_o    (rib_data_ram_w_addr_o  ),
        .s1_ram_w_data_o    (rib_data_ram_w_data_o  ),

        .s1_ram_r_addr_o    (rib_data_ram_r_addr_o  ),
        .s1_ram_r_data_i    (data_ram_r_data_o      ),

        // slave 2: timer
        .s2_timer_w_en_o    (rib_timer_w_en_o       ),
        .s2_timer_w_sel_o   (rib_timer_w_sel_o      ),
        .s2_timer_w_addr_o  (rib_timer_w_addr_o     ),
        .s2_timer_w_data_o  (rib_timer_w_data_o     ),

        .s2_timer_r_addr_o  (rib_timer_r_addr_o     ),
        .s2_timer_r_data_i  (timer_r_data_o         ),

        // slave 3: uart
        .s3_uart_w_en_o     (rib_uart_w_en_o        ),
        .s3_uart_w_sel_o    (rib_uart_w_sel_o       ),
        .s3_uart_w_addr_o   (rib_uart_w_addr_o      ),
        .s3_uart_w_data_o   (rib_uart_w_data_o      ),

        .s3_uart_r_addr_o   (rib_uart_r_addr_o      ),
        .s3_uart_r_data_i   (uart_r_data_o          ),

        // slave 0: inst_rom
        .s0_rom_r_addr_o    (rib_rom_r_addr_o       ),
        .s0_rom_r_data_i    (inst_rom_r_data_o      )
    );

    data_ram data_ram_inst(
        .clk                (clk                        ),
        .rst_n              (rst_n                      ),

        // write data
        .w_en_i             (rib_data_ram_w_en_o        ),
        .w_sel_i            (rib_data_ram_w_sel_o       ),
        .w_addr_i           (rib_data_ram_w_addr_o      ),
        .w_data_i           (rib_data_ram_w_data_o      ),

        // read data
        .r_addr_i           (rib_data_ram_r_addr_o      ),

        .r_data_o           (data_ram_r_data_o          )
    );

    timer timer_inst(
        .clk                (clk                        ),
        .rst_n              (rst_n                      ),

        // write data
        .w_en_i             (rib_timer_w_en_o           ),
        .w_sel_i            (rib_timer_w_sel_o          ),
        .w_addr_i           (rib_timer_w_addr_o         ),
        .w_data_i           (rib_timer_w_data_o         ),

        // read data
        .r_addr_i           (rib_timer_r_addr_o         ),

        .r_data_o           (timer_r_data_o             ),
        .timer_irq_o        (timer_irq_o                )
    );

    uart uart_inst(
        .clk                (clk                        ),
        .rst_n              (rst_n                      ),

        // write data
        .w_en_i             (rib_uart_w_en_o            ),
        .w_sel_i            (rib_uart_w_sel_o           ),
        .w_addr_i           (rib_uart_w_addr_o          ),
        .w_data_i           (rib_uart_w_data_o          ),

        // read data
        .r_addr_i           (rib_uart_r_addr_o          ),

        .r_data_o           (uart_r_data_o              ),
        .tx_pin_o           (uart_tx_o                  ),
        .rx_pin_i           (uart_rx_i                  )
    );

endmodule
