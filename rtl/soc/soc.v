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

    // core to rom
    wire[31:0]  core_inst_addr_o;

    // rom to core
    wire[31:0]  rom_inst_o;


    // ============================================================
    //  Module Instantiation & Interconnection
    // ============================================================

    core core_inst(
        .clk            (clk),
        .rst_n          (rst_n),
        .inst_i         (rom_inst_o),
        
        .inst_addr_o    (core_inst_addr_o)
    );

    rom rom_inst(
        .inst_addr_i    (core_inst_addr_o),

        .inst_o         (rom_inst_o)
    );

endmodule