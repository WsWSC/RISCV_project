////////////////////////////////////////////////////////////
//  RISC-V CPU Side Project
//  Author  : WsWSC
//  Created : 2026
//  License : Personal / Educational Use
////////////////////////////////////////////////////////////

`include "defines.v"

module ctrl(
    // from ex
    input  wire[31:0]   jump_addr_i     ,
    input  wire         jump_en_i       ,
    input  wire         flush_flag_i    ,

    // to pc_reg & if_id & id_ex
    output reg[31:0]    jump_addr_o     ,
    output reg          jump_en_o       ,
    output reg          flush_flag_o    
);

    // pass jump control signals & generate flush flag for pipeline control
    always @(*) begin
        jump_addr_o = jump_addr_i   ;
        jump_en_o   = jump_en_i     ;

        if (jump_en_i || flush_flag_i) begin
            flush_flag_o = `FlushEnable  ;
        end else begin
            flush_flag_o = `FlushDisable ;
        end
    end

endmodule