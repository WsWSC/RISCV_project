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
    // RAW Hazard / Forwarding
    // ============================================================
    // This core is a 3-stage pipeline: IF -> ID -> EX.
    //
    // A producer instruction writes its result in EX, while the next
    // consumer instruction reads rs1/rs2 in ID during the same cycle.
    // When ID.rs == EX.rd, forward the EX write-back data directly to
    // the ID read port instead of returning the old register value.
    //
    // x0 is never forwarded because it is architecturally fixed at zero.
    wire forward_rs1_from_ex = reg_w_en_i &&
                               (reg_w_addr_i != `ZeroReg) &&
                               (reg1_r_addr_i == reg_w_addr_i);

    wire forward_rs2_from_ex = reg_w_en_i &&
                               (reg_w_addr_i != `ZeroReg) &&
                               (reg2_r_addr_i == reg_w_addr_i);


    // ============================================================
    //  Main logic
    // ============================================================
    // id stage, read rs1 data
    always @(*) begin
        if (!rst_n) begin
            reg1_r_data_o = `ZeroWord;
        end else if (reg1_r_addr_i == `ZeroReg) begin
            reg1_r_data_o = `ZeroWord;
        end else if (forward_rs1_from_ex) begin
            reg1_r_data_o = reg_w_data_i;
        end else begin
            reg1_r_data_o = regs[reg1_r_addr_i];
        end
    end

    // id stage, read rs2 data
    always @(*) begin
        if (!rst_n) begin
            reg2_r_data_o = `ZeroWord;
        end else if (reg2_r_addr_i == `ZeroReg) begin
            reg2_r_data_o = `ZeroWord;
        end else if (forward_rs2_from_ex) begin
            reg2_r_data_o = reg_w_data_i;
        end else begin
            reg2_r_data_o = regs[reg2_r_addr_i];
        end
    end

    // ex stage, wirte reg 
    always @(posedge clk) begin
        if (!rst_n) begin
            for (i = 1; i <= 31; i = i + 1) begin     // reg x0 is always 0, no need reset
                regs[i] <= `ZeroWord;
            end
        end else if(reg_w_en_i && (reg_w_addr_i != `ZeroReg) ) begin
            regs[reg_w_addr_i] <= reg_w_data_i;
        end
    end

endmodule
