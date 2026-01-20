////////////////////////////////////////////////////////////
//  RISC-V CPU Side Project
//  Author  : WsWSC
//  Created : 2026
//  License : Personal / Educational Use
////////////////////////////////////////////////////////////

module pc_reg(
    input   wire        clk,
    input   wire        rst_n,

    output  reg[31:0]   pc_o
);

    // rom addr + 4
    always @(posedge clk) begin
        if(rst_n == 1'b0)
            pc_o <= 32'b0;
        else
            pc_o <= pc_o + 3'd4;
    end

endmodule