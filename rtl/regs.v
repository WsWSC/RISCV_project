//////////////////////////////////////////////////
// risc v side project                          //
//                                              //
// create by WsWSC                              //
//////////////////////////////////////////////////

module regs(
    input wire clk,
    input wire rst,

    // from id
    input wire[4:0]     reg1_raddr_i,
    input wire[4:0]     reg2_raddr_i,

    // to id
    output reg[31:0]    reg1_rdata_o,
    output reg[31:0]    reg2_rdata_o,

    // from ex
    input wire[4:0]     reg_waddr_i,
    input wire[31:0]    reg_wdata_i,
    input               reg_wen
);

    reg[31:0] regs[0:31];
    integer i;              // initial for loop

    // id stage, read rs1 data
    always @(*) begin
        if(rst == 1'b0) 
            reg1_rdata_o = `ZeroWord;
        else if (reg1_raddr_i == `ZeroReg)
            reg1_rdata_o = `ZeroWord;
        else if (reg_wen && (reg1_raddr_i == reg_waddr_i) )    // hazard detection & forwarding
            reg1_rdata_o = reg_wdata_i;
        else 
            reg1_rdata_o = regs[reg1_raddr_i];
    end

    // id stage, read rs2 data
    always @(*) begin
        if(rst == 1'b0) 
            reg2_rdata_o = `ZeroWord;
        else if (reg2_raddr_i == `ZeroReg)
            reg2_rdata_o = `ZeroWord;
        else if (reg_wen && (reg2_raddr_i == reg_waddr_i) )    // hazard detection & forwarding
            reg2_rdata_o = reg_wdata_i;
        else 
            reg2_rdata_o = regs[reg2_raddr_i];
    end

    // ex stage, wirte reg 
    always @(posedge clk) begin
        if(rst == 1'b0) begin
            for (i = 1; i <= 31; i = i + 1) begin     // reg x0 is always 0, no need reset
                regs[i] <= `ZeroWord;
            end
        end else if(reg_wen && (reg_waddr_i != `ZeroReg) )
            regs[reg_waddr_i] <= reg_wdata_i;
    end

endmodule