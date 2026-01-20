////////////////////////////////////////////////////////////
//  RISC-V CPU Side Project
//  Author  : WsWSC
//  Created : 2026
//  License : Personal / Educational Use
////////////////////////////////////////////////////////////

module rom(
    input   wire[31:0]  inst_addr_i,

    output  reg[31:0]   inst_o
);

    // rom memory, 32 * 4096 bit
    reg[31:0] rom_mem[0:4095];

    always @(*) begin
        inst_o = rom_mem[inst_addr_i >> 2];
    end   


endmodule