////////////////////////////////////////////////////////////
//  RISC-V CPU Side Project
//  Author  : WsWSC
//  Created : 2026
//  License : Personal / Educational Use
////////////////////////////////////////////////////////////

module pc_reg(
    input  wire         clk                 ,
    input  wire         rst_n               ,

    // from ctrl
    input  wire         stall_flag_i        ,           // hold
    input  wire [31:0]  jump_addr_i         ,
    input  wire         jump_en_i           ,

    // to inst_mem
    output reg  [31:0]  pc_addr_o           
);

    // ============================================================
    //  Main logic
    // ============================================================
    always @(posedge clk) begin
        if (!rst_n)
            pc_addr_o <= 32'b0;
        else if (jump_en_i)
            pc_addr_o <= jump_addr_i;                   // jump
        else if (stall_flag_i)          
            pc_addr_o <= pc_addr_o;                     // hold
        else
            pc_addr_o <= pc_addr_o + 32'd4;  
    end

endmodule
