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

    // I-type
    wire[31:0]  op1_i_slt_op2_i   = ($signed(op1_i)  < $signed(op2_i)) ? 32'd1 : 32'd0;     // INST_SLTI  & INST_SLT
    wire[31:0]  op1_i_sltu_op2_i  = (op1_i < op2_i)                    ? 32'd1 : 32'd0;     // INST_SLTIU & INST_SLTU 
    wire[31:0]  op1_i_xor_op2_i   = (op1_i ^ op2_i);                                        // INST_XORI  & INST_XOR
    wire[31:0]  op1_i_or_op2_i    = (op1_i | op2_i);                                        // INST_ORI   & INST_OR
    wire[31:0]  op1_i_and_op2_i   = (op1_i & op2_i);                                        // INST_ANDI  & INST_AND
    wire[31:0]  op1_i_sll_op2_i   = (op1_i << op2_i[4:0]);                                  // INST_SLLI  & INST_SLL
    wire[31:0]  op1_i_srl_op2_i   = (op1_i >> op2_i[4:0]);                                  // INST_SRLI  & INST_SRL
    wire[31:0]  op1_i_sra_op2_i   = ($signed(op1_i) >>> op2_i[4:0]);                        // INST_SRAI  & INST_SRA

    // R-type
    wire[31:0]  op1_i_add_op2_i   = (op1_i + op2_i);                                        // INST_ADD_SUB add
    wire[31:0]  op1_i_sub_op2_i   = (op1_i - op2_i);                                        // INST_ADD_SUB sub

    // B-type   
    wire[31:0]  jump_imm          = {{19{inst_i[31]}}, inst_i[31], inst_i[7], inst_i[30:25], inst_i[11:8], 1'b0};  
    wire[31:0]  jump_pc_imm       = inst_addr_i + jump_imm ;                                // branch addr. = pc + imm  
    wire        op1_i_equal_op2_i = ( op1_i == op2_i );                                     // for INST_BEQ & INST_BNE, 1 = equal, 0 = not equal  
   

    // ============================================================
    //  Ex-stage logic
    // ============================================================
    
    always @(*) begin
        // defaults
        rd_addr_o   = `ZeroReg      ;
        rd_data_o   = `ZeroWord     ;
        rd_wen_o    = `WriteDisable ;

        jump_addr_o = `ZeroAddr     ;
        jump_en_o   = `JumpDisable  ;
        hold_flag_o = `HoldDisable  ;

        case(opcode) 
            // I-type
            `INST_TYPE_I: begin
                case(funct3)
                    `INST_ADDI: begin      
                        rd_addr_o = rd_addr_i       ;
                        rd_data_o = op1_i_add_op2_i ;
                        rd_wen_o  = `WriteEnable    ;
                    end

                    `INST_SLTI : begin
                        rd_addr_o = rd_addr_i       ;
                        rd_data_o = op1_i_slt_op2_i ;
                        rd_wen_o  = `WriteEnable    ;
                    end

                    `INST_SLTIU: begin
                        rd_addr_o = rd_addr_i        ;
                        rd_data_o = op1_i_sltu_op2_i ;
                        rd_wen_o  = `WriteEnable     ;
                    end

                    `INST_XORI : begin
                        rd_addr_o = rd_addr_i       ;
                        rd_data_o = op1_i_xor_op2_i ;
                        rd_wen_o  = `WriteEnable    ;
                    end

                    `INST_ORI  : begin
                        rd_addr_o = rd_addr_i      ;
                        rd_data_o = op1_i_or_op2_i ;
                        rd_wen_o  = `WriteEnable   ;
                    end

                    `INST_ANDI : begin
                        rd_addr_o = rd_addr_i       ;
                        rd_data_o = op1_i_and_op2_i ;
                        rd_wen_o  = `WriteEnable    ;
                    end

                    `INST_SLLI : begin
                        rd_addr_o = rd_addr_i       ;
                        rd_data_o = op1_i_sll_op2_i ;
                        rd_wen_o  = `WriteEnable    ;
                    end

                    `INST_SRI  : begin
                        if (funct7 == 7'b000_0000) begin            // INST_SRLI
                            rd_addr_o = rd_addr_i        ;
                            rd_data_o = op1_i_srl_op2_i ;
                            rd_wen_o  = `WriteEnable     ;
                        end else if (funct7 == 7'b010_0000) begin   // INST_SRAI
                            rd_addr_o = rd_addr_i        ;
                            rd_data_o = op1_i_sra_op2_i ;
                            rd_wen_o  = `WriteEnable     ;    
                        end else begin                              // illegal input, funct7 error 
                            rd_addr_o = `ZeroReg      ;
                            rd_data_o = `ZeroWord     ;
                            rd_wen_o  = `WriteDisable ;
                        end
                    end
                    
                    default: begin
                        rd_addr_o = `ZeroReg      ;
                        rd_data_o = `ZeroWord     ;
                        rd_wen_o  = `WriteDisable ;
                    end
                    
                endcase
            end

            // R-type
            `INST_TYPE_R_M: begin
                case(funct3)
                    `INST_ADD_SUB: begin
                        if (funct7 == 7'b000_0000) begin                // add
                            rd_addr_o   = rd_addr_i       ;
                            rd_data_o   = op1_i_add_op2_i ;
                            rd_wen_o    = `WriteEnable    ;
                        end else if (funct7 == 7'b010_0000) begin       // sub
                            rd_addr_o   = rd_addr_i       ;
                            rd_data_o   = op1_i_sub_op2_i ;
                            rd_wen_o    = `WriteEnable    ;
                        end else begin
                            rd_addr_o   = `ZeroReg      ;
                            rd_data_o   = `ZeroWord     ;
                            rd_wen_o    = `WriteDisable ;
                        end  
                    end

                    `INST_SLL: begin
                        rd_addr_o = rd_addr_i       ;
                        rd_data_o = op1_i_sll_op2_i ;
                        rd_wen_o  = `WriteEnable    ;
                    end

                    `INST_SLT: begin
                        rd_addr_o = rd_addr_i       ;
                        rd_data_o = op1_i_slt_op2_i ;
                        rd_wen_o  = `WriteEnable    ;
                    end

                    `INST_SLTU: begin
                        rd_addr_o = rd_addr_i        ;
                        rd_data_o = op1_i_sltu_op2_i ;
                        rd_wen_o  = `WriteEnable     ;
                    end

                    `INST_XOR: begin
                        rd_addr_o = rd_addr_i       ;
                        rd_data_o = op1_i_xor_op2_i ;
                        rd_wen_o  = `WriteEnable    ;
                    end

                    `INST_SR: begin
                        if (funct7 == 7'b000_0000) begin            // INST_SRL
                            rd_addr_o = rd_addr_i        ;
                            rd_data_o = op1_i_srl_op2_i ;
                            rd_wen_o  = `WriteEnable     ;
                        end else if (funct7 == 7'b010_0000) begin   // INST_SRA
                            rd_addr_o = rd_addr_i        ;
                            rd_data_o = op1_i_sra_op2_i ;
                            rd_wen_o  = `WriteEnable     ;    
                        end else begin                              // illegal input, funct7 error 
                            rd_addr_o = `ZeroReg      ;
                            rd_data_o = `ZeroWord     ;
                            rd_wen_o  = `WriteDisable ;
                        end
                    end

                    `INST_OR: begin
                        rd_addr_o = rd_addr_i      ;
                        rd_data_o = op1_i_or_op2_i ;
                        rd_wen_o  = `WriteEnable   ;
                    end

                    `INST_AND: begin
                        rd_addr_o = rd_addr_i       ;
                        rd_data_o = op1_i_and_op2_i ;
                        rd_wen_o  = `WriteEnable    ;
                    end

                    default: begin
                        rd_addr_o   = `ZeroReg      ;
                        rd_data_o   = `ZeroWord     ;
                        rd_wen_o    = `WriteDisable ;				
					end
                endcase
            end

            // B-type
            `INST_TYPE_B: begin
                case(funct3)
                    `INST_BEQ: begin
                        jump_addr_o = jump_pc_imm  ;
                        jump_en_o   = op1_i_equal_op2_i    ;
                        hold_flag_o = `HoldDisable ;
                    end

                    `INST_BNE: begin
                        jump_addr_o = jump_pc_imm  ;
                        jump_en_o   = ~op1_i_equal_op2_i   ;
                        hold_flag_o = `HoldDisable ;
                    end

                    default: begin
                        jump_addr_o = `ZeroAddr    ;
                        jump_en_o   = `JumpDisable ;
                        hold_flag_o = `HoldDisable ;
                    end

                
                endcase
            end

            // J-type
            `INST_JAL: begin
                rd_addr_o   = rd_addr_i           ;
                rd_data_o   = inst_addr_i + 32'h4 ;
                rd_wen_o    = `WriteEnable        ;

                jump_addr_o = inst_addr_i + op1_i ;
                jump_en_o   = `JumpEnable         ;
                hold_flag_o = `HoldDisable        ;
            end

            `INST_LUI: begin
                rd_addr_o   = rd_addr_i    ;
                rd_data_o   = op1_i        ;
                rd_wen_o    = `WriteEnable ;

                jump_addr_o = `ZeroAddr     ;
                jump_en_o   = `JumpDisable  ;
                hold_flag_o = `HoldDisable  ;
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