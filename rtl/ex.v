////////////////////////////////////////////////////////////
//  RISC-V CPU Side Project
//  Author  : WsWSC
//  Created : 2026
//  License : Personal / Educational Use
////////////////////////////////////////////////////////////

`include "defines.v"

module ex(
    // from id_ex
    input wire[31:0]   inst_addr_i,
    input wire[31:0]   inst_i,
    input wire[31:0]   op1_i,
    input wire[31:0]   op2_i,
    input wire[4:0]    rd_addr_i,
    input wire         reg_wen_i,

    // to regs
    output reg[4:0]     rd_addr_o,
    output reg[31:0]    rd_data_o,
    output reg          rd_wen_o
);


    // R-type
    wire[6:0]   opcode;
    wire[4:0]   rd;
    wire[2:0]   funct3;
    wire[4:0]   rs1, rs2;
    wire[6:0]   funct7;
    // I-type
    wire[11:0]  imm;

    // R-type
    assign opcode   = inst_i[6:0];
    assign rd       = inst_i[11:7];
    assign funct3   = inst_i[14:12];
    assign rs1      = inst_i[19:15];
    assign rs2      = inst_i[24:20];
    assign funct7   = inst_i[31:25];
    // I-type
    assign imm      = inst_i[31:20];

    // Calculator
        // add
        wire [31:0] op1_add_op2_res;
        assign op1_add_op2_res = op1_i + op2_i;
        //sub
        wire [31:0] op1_sub_op2_res;
        assign op1_sub_op2_res = op1_i - op2_i;

    // opcode, identify R-type or I-type
    always @(*) begin
        case(opcode) 
            `INST_TYPE_I: begin
                case(funct3)
                    `INST_ADDI: begin      // I-type, addi
                        rd_addr_o = rd_addr_i;
                        rd_data_o = op1_add_op2_res;
                        rd_wen_o  = `WriteEnable;
                    end

                    /*`INST_SLTI : begin
                    end

                    `INST_SLTIU: begin
                    end

                    `INST_XORI : begin
                    end

                    `INST_ORI  : begin
                    end

                    `INST_ANDI : begin
                    end

                    `INST_SLLI : begin
                    end

                    `INST_SRI  : begin
                    end
                    */
                    default: begin
                        rd_addr_o = `ZeroReg;
                        rd_data_o = `ZeroWord;
                        rd_wen_o  = `WriteDisable;
                    end
                    
                endcase
            end

            `INST_TYPE_R_M: begin
                case(funct3)
                    `INST_ADD_SUB: begin
                        if(funct7 == 7'b000_0000) begin     // add
                            rd_addr_o = rd_addr_i;
                            rd_data_o = op1_add_op2_res;
                            rd_wen_o = `WriteEnable;
                        end else begin                      // sub
                            rd_addr_o = rd_addr_i;
                            rd_data_o = op1_sub_op2_res;
                            rd_wen_o  = `WriteEnable;
                        end
                        
                    end
                    
                endcase

            end
            default: begin
                    rd_addr_o = `ZeroReg;
                    rd_data_o = `ZeroWord;
                    rd_wen_o  = `WriteDisable;
            end
        endcase
    end


endmodule