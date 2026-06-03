////////////////////////////////////////////////////////////
//  RISC-V CPU Side Project
//  Author  : WsWSC
//  Created : 2026
//  License : Personal / Educational Use
////////////////////////////////////////////////////////////

`include "defines.v"

module ctrl(
    // from ex
    input  wire         flush_req_i         ,
    input  wire         stall_req_i         ,
    input  wire[31:0]   jump_addr_i         ,
    input  wire         jump_en_i           ,

    // from clint
    input  wire         trap_jump_en_i      ,
    input  wire[31:0]   trap_jump_addr_i    ,

    // from hazard detect
    input  wire         hazard_stall_req_i  ,

    // aggregate debug / trace flags
    output reg          flush_flag_o        ,       // flush or bubble
    output reg          stall_flag_o        ,       // any pipeline hold

    // to pc_reg
    output reg          pc_stall_flag_o     ,

    // to if_id
    output reg          if_id_flush_flag_o  ,
    output reg          if_id_stall_flag_o  ,

    // to id_ex
    output reg          id_ex_flush_flag_o  ,
    output reg          id_ex_stall_flag_o  ,

    // to pc_reg
    output reg[31:0]    jump_addr_o         ,
    output reg          jump_en_o       
);

    // ============================================================
    //  Main logic
    // ============================================================
    // Priority:
    //   1. trap request: save trap CSRs and jump to mtvec
    //   2. jump/flush request: discard younger instructions
    //   3. multi-cycle stall: hold PC, IF/ID, and ID/EX
    //   4. load-use hazard: hold PC and IF/ID, inject NOP into ID/EX
    //   5. normal: pipeline advances
    always @(*) begin
        // default
        flush_flag_o       = `FlushDisable ;
        stall_flag_o       = `StallDisable ;
        pc_stall_flag_o    = `StallDisable ;
        if_id_flush_flag_o = `FlushDisable ;
        if_id_stall_flag_o = `StallDisable ;
        id_ex_flush_flag_o = `FlushDisable ;
        id_ex_stall_flag_o = `StallDisable ;
        jump_addr_o        = jump_addr_i   ;
        jump_en_o          = jump_en_i     ;

        if (trap_jump_en_i) begin               // trap
            if_id_flush_flag_o = `FlushEnable;
            id_ex_flush_flag_o = `FlushEnable;
            jump_addr_o        = trap_jump_addr_i;
            jump_en_o          = `JumpEnable;
        end else if (jump_en_i || flush_req_i) begin     // jump
            if_id_flush_flag_o = `FlushEnable;
            id_ex_flush_flag_o = `FlushEnable;
        end else if (stall_req_i) begin         // stall
            pc_stall_flag_o    = `StallEnable;
            if_id_stall_flag_o = `StallEnable;
            id_ex_stall_flag_o = `StallEnable;
        end else if (hazard_stall_req_i) begin  // load-use bubble
            pc_stall_flag_o    = `StallEnable;
            if_id_stall_flag_o = `StallEnable;
            id_ex_flush_flag_o = `FlushEnable;
        end

        flush_flag_o = if_id_flush_flag_o || id_ex_flush_flag_o;
        stall_flag_o = pc_stall_flag_o || if_id_stall_flag_o || id_ex_stall_flag_o;
    end

endmodule
