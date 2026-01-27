////////////////////////////////////////////////////////////
//  RISC-V CPU Side Project
//  Author  : WsWSC
//  Created : 2026
//  License : Personal / Educational Use
////////////////////////////////////////////////////////////

`include "defines.v"

module id(
    // from if_id
    input wire[31:0]    inst_addr_i ,       // return from "if_id"
    input wire[31:0]    inst_i      ,       // return from "if_id"

    // to regs
    output reg[4:0]     rs1_addr_o  ,       // send to "regs", it's reg addr. output
    output reg[4:0]     rs2_addr_o  ,       // send to "regs", it's reg addr. output

    // from regs    
    input wire[31:0]    rs1_data_i  ,       // return from "regs", it's actual data input
    input wire[31:0]    rs2_data_i  ,       // return from "regs", it's actual data input

    // to id_ex
    output reg[31:0]    inst_addr_o ,
    output reg[31:0]    inst_o      ,
    output reg[31:0]    op1_o       ,       // send to "id_ex" DFF, = rs1_data_o
    output reg[31:0]    op2_o       ,       // send to "id_ex" DFF, = rs2_data_o
    output reg[4:0]     rd_addr_o   ,       // send to "id_ex" DFF, rd register addr.
    output reg          reg_wen_o           // send to "id_ex" DFF, reg_wen_o = reg write enable 
);

    // R-type
    wire[6:0]   opcode;
    wire[4:0]   rd;
    wire[2:0]   funct3;
    wire[4:0]   rs1, rs2;
    wire[6:0]   funct7;
    // I-type
    wire[11:0]  imm;
    wire[4:0]   shamt;

    // R-type
    assign opcode   = inst_i[6:0];
    assign rd       = inst_i[11:7];
    assign funct3   = inst_i[14:12];
    assign rs1      = inst_i[19:15];
    assign rs2      = inst_i[24:20];
    assign funct7   = inst_i[31:25];
    // I-type
    assign imm      = inst_i[31:20];
    assign shamt    = inst_i[24:20];


    // ============================================================
    //  Id-stage logic
    // ============================================================
    always @(*) begin
        // send instr. to next stage
        inst_o = inst_i;
        inst_addr_o = inst_addr_i;

        // defaults
        rs1_addr_o  = `ZeroReg      ;
        rs2_addr_o  = `ZeroReg      ;

        op1_o       = `ZeroWord     ;
        op2_o       = `ZeroWord     ;
        rd_addr_o   = `ZeroReg      ;
        reg_wen_o   = `WriteDisable ;

        case(opcode) 
            // I-type
            `INST_TYPE_I: begin
                case(funct3)
                    `INST_ADDI, `INST_SLTI, `INST_SLTIU, `INST_XORI, `INST_ORI, `INST_ANDI: begin 
                        rs1_addr_o  = rs1                   ;
                        rs2_addr_o  = `ZeroReg              ;

                        op1_o       = rs1_data_i            ;
                        op2_o       = {{20{imm[11]}},imm}   ;
                        rd_addr_o   = rd                    ;   
                        reg_wen_o   = `WriteEnable          ;
                    end

                    `INST_SLLI, `INST_SRI: begin
                        rs1_addr_o  = rs1            ;
                        rs2_addr_o  = `ZeroReg       ;

                        op1_o       = rs1_data_i     ;
                        op2_o       = {27'b0, shamt} ;
                        rd_addr_o   = rd             ;   
                        reg_wen_o   = `WriteEnable   ;
                    end
                    
                    default: begin
                        rs1_addr_o  = `ZeroReg      ;
                        rs2_addr_o  = `ZeroReg      ;

                        op1_o       = `ZeroWord     ;
                        op2_o       = `ZeroWord     ;
                        rd_addr_o   = `ZeroReg      ;
                        reg_wen_o   = `WriteDisable ;
                    end
                    
                endcase
            end

            // R-type
            `INST_TYPE_R_M: begin
                case(funct3)
                    `INST_ADD_SUB, `INST_SLT, `INST_SLTU, `INST_XOR, `INST_OR, `INST_AND: begin
                        rs1_addr_o  = rs1;
                        rs2_addr_o  = rs2;

                        op1_o       = rs1_data_i;
                        op2_o       = rs2_data_i;
                        rd_addr_o   = rd;
                        reg_wen_o   = `WriteEnable;
                    end

                    `INST_SLL, `INST_SR: begin
                        rs1_addr_o  = rs1;
                        rs2_addr_o  = rs2;

                        op1_o       = rs1_data_i;
                        op2_o       = {27'b0, rs2_data_i[4:0]};
                        rd_addr_o   = rd;
                        reg_wen_o   = `WriteEnable;
                    end

                    default: begin
                        rs1_addr_o  = `ZeroReg      ;
                        rs2_addr_o  = `ZeroReg      ;

                        op1_o       = `ZeroWord     ;
                        op2_o       = `ZeroWord     ;
                        rd_addr_o   = `ZeroReg      ;
                        reg_wen_o   = `WriteDisable ;
                    end
                endcase
            end

            // B-type
            `INST_TYPE_B: begin
                case(funct3)
                    /*`INST_BLT: begin
                        rs1_addr_o  = rs1           ;
                        rs2_addr_o  = rs2           ;

                        op1_o       = rs1_data_i    ;
                        op2_o       = rs2_data_i    ;
                        rd_addr_o   = rd            ;   
                        reg_wen_o   = `WriteDisable ;
                    end*/

                    `INST_BEQ, `INST_BNE: begin
                        rs1_addr_o  = rs1           ;
                        rs2_addr_o  = rs2           ;

                        op1_o       = rs1_data_i    ;
                        op2_o       = rs2_data_i    ;
                        rd_addr_o   = `ZeroReg      ;   
                        reg_wen_o   = `WriteDisable ;
                    end

                    default: begin
                        rs1_addr_o  = `ZeroReg      ;
                        rs2_addr_o  = `ZeroReg      ;

                        op1_o       = `ZeroWord     ;
                        op2_o       = `ZeroWord     ;
                        rd_addr_o   = `ZeroReg      ;
                        reg_wen_o   = `WriteDisable ;
                    end

                
                endcase
            end

            // J-type
            `INST_JAL: begin
                rs1_addr_o  = `ZeroReg                                                           ;
                rs2_addr_o  = `ZeroReg                                                           ;

                op1_o       = {{12{inst_i[31]}}, inst_i[19:12], inst_i[20], inst_i[30:21], 1'b0} ;
                op2_o       = `ZeroWord                                                          ;
                rd_addr_o   = rd                                                                 ; 
                reg_wen_o   = `WriteEnable                                                       ;
            end   

            `INST_LUI: begin
                rs1_addr_o  = `ZeroReg               ;
                rs2_addr_o  = `ZeroReg               ;

                op1_o       = {inst_i[31:12], 12'b0} ;
                op2_o       = `ZeroWord              ;
                rd_addr_o   = rd                     ;
                reg_wen_o   = `WriteEnable           ;                                                    
            end   

            default: begin
                rs1_addr_o  = `ZeroReg      ;
                rs2_addr_o  = `ZeroReg      ;

                op1_o       = `ZeroWord     ;
                op2_o       = `ZeroWord     ;
                rd_addr_o   = `ZeroReg      ;
                reg_wen_o   = `WriteDisable ;
            end
        endcase
    end


endmodule