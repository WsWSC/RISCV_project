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
    input wire[4:0]     reg1_raddr_i,
    input wire[4:0]     reg2_raddr_i,

    // to id
    output reg[31:0]    reg1_rdata_o,
    output reg[31:0]    reg2_rdata_o,

    // from ex
    input wire[4:0]     reg_waddr_i,
    input wire[31:0]    reg_wdata_i,
    input               reg_wen_i
);

    reg[31:0] regs[0:31];
    integer i;              // initial for loop

    // id stage, read rs1 data
    always @(*) begin
        if(rst_n == 1'b0) begin
            reg1_rdata_o = `ZeroWord;
        end else if (reg1_raddr_i == `ZeroReg) begin
            reg1_rdata_o = `ZeroWord;
        end else if (reg_wen_i && (reg1_raddr_i == reg_waddr_i) && (reg_waddr_i != `ZeroReg) ) begin   // RAW hazard forwarding: forward EX write-back to ID read port (exclude x0)
            reg1_rdata_o = reg_wdata_i;
        end else begin
            reg1_rdata_o = regs[reg1_raddr_i];
        end
    end

    // id stage, read rs2 data
    always @(*) begin
        if(rst_n == 1'b0) begin
            reg2_rdata_o = `ZeroWord;
        end else if (reg2_raddr_i == `ZeroReg) begin
            reg2_rdata_o = `ZeroWord;
        end else if (reg_wen_i && (reg2_raddr_i == reg_waddr_i) && (reg_waddr_i != `ZeroReg) ) begin   // RAW hazard forwarding: forward EX write-back to ID read port (exclude x0)
            reg2_rdata_o = reg_wdata_i;
        end else begin
            reg2_rdata_o = regs[reg2_raddr_i];
        end
    end

    // ex stage, wirte reg 
    always @(posedge clk) begin
        if(rst_n == 1'b0) begin
            for (i = 1; i <= 31; i = i + 1) begin     // reg x0 is always 0, no need reset
                regs[i] <= `ZeroWord;
            end
        end else if(reg_wen_i && (reg_waddr_i != `ZeroReg) ) begin
            regs[reg_waddr_i] <= reg_wdata_i;
        end
    end

endmodule