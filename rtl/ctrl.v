////////////////////////////////////////////////////////////
//  RISC-V CPU Side Project
//  Author  : WsWSC
//  Created : 2026
//  License : Personal / Educational Use
////////////////////////////////////////////////////////////

module ctrl(
    input   wire        jump_flag_i ,
    input   wire        hold_flag_i ,
    input   wire[31:0]  jump_addr_i ,

    output  wire        hold_flag_o ,
    output  wire        jump_flag_o ,
    output  wire[31:0]  jump_addr_o ,
    output  wire        jump_en     
);



endmodule