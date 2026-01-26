////////////////////////////////////////////////////////////
//  RISC-V CPU Side Project
//  Author  : WsWSC
//  Created : 2026
//  License : Personal / Educational Use
////////////////////////////////////////////////////////////

`include "defines.v"

module ex(
    // from id_ex
    input  wire[31:0]   inst_addr_i ,
    input  wire[31:0]   inst_i      ,  
    input  wire[31:0]   op1_i       ,
    input  wire[31:0]   op2_i       ,
    input  wire[4:0]    rd_addr_i   ,
    input  wire         reg_wen_i   ,
 
    // to regs
    output reg[4:0]     rd_addr_o   ,
    output reg[31:0]    rd_data_o   ,
    output reg          rd_wen_o    ,
        
    // to ctrl
    output reg[31:0]    jump_addr_o ,
    output reg          jump_en_o   ,
    output reg          hold_flag_o    
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


    // ============================================================
    //  Calculators
    // ============================================================
    // add
    wire [31:0] op1_add_op2_res;
    assign op1_add_op2_res = op1_i + op2_i;
    // sub
    wire [31:0] op1_sub_op2_res;
    assign op1_sub_op2_res = op1_i - op2_i;

    // branch
    wire [31:0] jump_imm;
    assign jump_imm = {{19{inst_i[31]}}, inst_i[31], inst_i[7], inst_i[30:25], inst_i[11:8], 1'b0};
    // branch addr. = pc + imm
    wire [31:0] jump_pc_imm;
    assign jump_pc_imm = inst_addr_i + jump_imm ;

    // for INST_BEQ & INST_BNE, 1 = equal, 0 = not equal
    wire branch_eq = (op1_i == op2_i);
    



    // opcode, identify instruction type
    always @(*) begin
        // defaults
        rd_addr_o   = `ZeroReg      ;
        rd_data_o   = `ZeroWord     ;
        rd_wen_o    = `WriteDisable ;

        jump_addr_o = `ZeroAddr     ;
        jump_en_o   = `JumpDisable  ;
        hold_flag_o = `HoldDisable  ;

        case(opcode) 
            `INST_TYPE_I: begin
                case(funct3)
                    `INST_ADDI: begin      // I-type, addi
                        rd_addr_o = rd_addr_i       ;
                        rd_data_o = op1_add_op2_res ;
                        rd_wen_o  = `WriteEnable    ;
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
                        rd_addr_o = `ZeroReg      ;
                        rd_data_o = `ZeroWord     ;
                        rd_wen_o  = `WriteDisable ;
                    end
                    
                endcase
            end

            `INST_TYPE_R_M: begin
                case(funct3)
                    `INST_ADD_SUB: begin
                        if(funct7 == 7'b000_0000) begin     // add
                            rd_addr_o = rd_addr_i       ;
                            rd_data_o = op1_add_op2_res ;
                            rd_wen_o  = `WriteEnable    ;
                        end else begin                      // sub
                            rd_addr_o = rd_addr_i       ;
                            rd_data_o = op1_sub_op2_res ;
                            rd_wen_o  = `WriteEnable    ;
                        end
                        
                    end

                    default: begin
                        rd_addr_o   = `ZeroReg      ;
                        rd_data_o   = `ZeroWord     ;
                        rd_wen_o    = `WriteDisable ;				
					end
                endcase

            end

            `INST_TYPE_B: begin
                case(funct3)
                    `INST_BEQ: begin
                        jump_addr_o = jump_pc_imm  ;
                        jump_en_o   = branch_eq    ;
                        hold_flag_o = `HoldDisable ;
                    end

                    `INST_BNE: begin
                        jump_addr_o = jump_pc_imm  ;
                        jump_en_o   = ~branch_eq   ;
                        hold_flag_o = `HoldDisable ;
                    end

                    default: begin
                        jump_addr_o = `ZeroAddr    ;
                        jump_en_o   = `JumpDisable ;
                        hold_flag_o = `HoldDisable ;
                    end

                
                endcase
            end

            `INST_JAL: begin
                rd_addr_o   = rd_addr_i           ;
                rd_data_o   = inst_addr_i + 32'h4 ;
                rd_wen_o    = `WriteEnable        ;

                jump_addr_o = inst_addr_i + op1_i ;
                jump_en_o   = `JumpEnable         ;
                hold_flag_o = `HoldDisable        ;
            end

            default: begin
                rd_addr_o   = `ZeroReg      ;
                rd_data_o   = `ZeroWord     ;
                rd_wen_o    = `WriteDisable ;
                
                jump_addr_o = `ZeroAddr     ;
                jump_en_o   = `JumpDisable  ;
                hold_flag_o = `HoldDisable  ;
            end

        endcase
    end


endmodule