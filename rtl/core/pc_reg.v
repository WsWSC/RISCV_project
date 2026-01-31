////////////////////////////////////////////////////////////
//  RISC-V CPU Side Project
//  Author  : WsWSC
//  Created : 2026
//  License : Personal / Educational Use
////////////////////////////////////////////////////////////

module pc_reg(
    input  wire         clk ,
    input  wire         rst_n ,

    // from ctrl
    input  wire[31:0]   jump_addr_i,
    input  wire         jump_en_i,

    // to ifetch
    output reg[31:0]    pc_addr_o
);

    // rom addr + 4
    always @(posedge clk) begin
        if(rst_n == 1'b0)
            pc_addr_o <= 32'b0;
        else if(jump_en_i)
            pc_addr_o <= jump_addr_i;
        else
            pc_addr_o <= pc_addr_o + 3'd4;
    end

endmodule