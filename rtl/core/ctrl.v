////////////////////////////////////////////////////////////
//  RISC-V CPU Side Project
//  Author  : WsWSC
//  Created : 2026
//  License : Personal / Educational Use
////////////////////////////////////////////////////////////

`include "defines.v"

module ctrl(
    // from ex
    input  wire         flush_req_i     ,
    input  wire         stall_req_i     ,
    input  wire[31:0]   jump_addr_i     ,
    input  wire         jump_en_i       ,

    // to pc_reg & if_id & id_ex
    output reg          flush_flag_o    ,       // NOP
    output reg          stall_flag_o    ,       // stall
    output reg[31:0]    jump_addr_o     ,
    output reg          jump_en_o       
);

    // ============================================================
    //  Main logic
    // ============================================================
    // pass jump control signals & generate flush flag for pipeline control
    always @(*) begin
        // default
        flush_flag_o = `FlushDisable ;
        stall_flag_o = `StallDisable ;
        jump_addr_o  = jump_addr_i   ;
        jump_en_o    = jump_en_i     ;

        if (jump_en_i || flush_req_i) begin     // jump
            flush_flag_o = `FlushEnable;
            stall_flag_o = `StallDisable;        
        end else if (stall_req_i) begin         // stall
            flush_flag_o = `FlushDisable;
            stall_flag_o = `StallEnable;
        end
    end

endmodule