////////////////////////////////////////////////////////////
//  RISC-V CPU Side Project
//  Author  : WsWSC
//  Created : 2026
//  License : Personal / Educational Use
////////////////////////////////////////////////////////////

`include "defines.v"

module regs(
    input wire clk,
    input wire rst_n,

    // from id
    input wire[4:0]     reg1_r_addr_i,
    input wire[4:0]     reg2_r_addr_i,

    // to id
    output reg[31:0]    reg1_r_data_o,
    output reg[31:0]    reg2_r_data_o,

    // from ex
    input wire[4:0]     reg_w_addr_i,
    input wire[31:0]    reg_w_data_i,
    input               reg_w_en_i
);

    // ============================================================
    //  Wire Declarations
    // ============================================================
    reg[31:0] regs[0:31];
    integer i;              // initial for loop


    // ============================================================
    //  Main logic
    // ============================================================
    // id stage, read rs1 data
    always @(*) begin
        if(rst_n == 1'b0) begin
            reg1_r_data_o = `ZeroWord;
        end else if (reg1_r_addr_i == `ZeroReg) begin
            reg1_r_data_o = `ZeroWord;
        end else if (reg_w_en_i && (reg1_r_addr_i == reg_w_addr_i) && (reg_w_addr_i != `ZeroReg) ) begin   // RAW hazard forwarding: forward EX write-back to ID read port (exclude x0)
            reg1_r_data_o = reg_w_data_i;
        end else begin
            reg1_r_data_o = regs[reg1_r_addr_i];
        end
    end

    // id stage, read rs2 data
    always @(*) begin
        if(rst_n == 1'b0) begin
            reg2_r_data_o = `ZeroWord;
        end else if (reg2_r_addr_i == `ZeroReg) begin
            reg2_r_data_o = `ZeroWord;
        end else if (reg_w_en_i && (reg2_r_addr_i == reg_w_addr_i) && (reg_w_addr_i != `ZeroReg) ) begin   // RAW hazard forwarding: forward EX write-back to ID read port (exclude x0)
            reg2_r_data_o = reg_w_data_i;
        end else begin
            reg2_r_data_o = regs[reg2_r_addr_i];
        end
    end

    // ex stage, wirte reg 
    always @(posedge clk) begin
        if(rst_n == 1'b0) begin
            for (i = 1; i <= 31; i = i + 1) begin     // reg x0 is always 0, no need reset
                regs[i] <= `ZeroWord;
            end
        end else if(reg_w_en_i && (reg_w_addr_i != `ZeroReg) ) begin
            regs[reg_w_addr_i] <= reg_w_data_i;
        end
    end

endmodule