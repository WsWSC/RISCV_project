////////////////////////////////////////////////////////////
//  RISC-V CPU Side Project
//  Author  : WsWSC
//  Created : 2026
//  License : Personal / Educational Use
////////////////////////////////////////////////////////////

`include "defines.v"

module ex(
    // from id_ex
    input  wire[31:0]   inst_addr_i         ,
    input  wire[31:0]   inst_i              ,  
    input  wire[31:0]   op1_i               ,
    input  wire[31:0]   op2_i               ,
    input  wire[4:0]    rd_addr_i           ,
    input  wire         reg_w_en_i          ,
    input  wire[31:0]   base_addr_i         , 
    input  wire[31:0]   addr_offset_i       ,

    // from data_mem read
    input  wire [31:0]  data_mem_rd_data_i  ,
 
    // to regs
    output reg[4:0]     rd_addr_o           ,
    output reg[31:0]    rd_data_o           ,
    output reg          rd_w_en_o           ,
        
    // to ctrl
    output reg[31:0]    jump_addr_o         ,
    output reg          jump_en_o           ,
    output reg          hold_flag_o         ,


    // to data_mem write
    output reg	 	    data_mem_w_en_o	    ,
	output reg[3:0]     data_mem_w_sel_o    ,
	output reg[31:0]    data_mem_w_addr_o   ,
	output reg[31:0]    data_mem_w_data_o   	
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
    //  ALU
    // ============================================================

    // I-type
    wire[31:0]  op1_i_slt_op2_i   = ($signed(op1_i) < $signed(op2_i)) ? 32'd1 : 32'd0;      // INST_SLTI  & INST_SLT
    wire[31:0]  op1_i_sltu_op2_i  = (op1_i < op2_i)                   ? 32'd1 : 32'd0;      // INST_SLTIU & INST_SLTU 
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
    wire        op1_i_eq_op2_i    = (op1_i == op2_i);                                       // INST_BEQ 
    wire        op1_i_ne_op2_i    = (op1_i != op2_i);                                       // INST_BNE
    wire        op1_i_lt_op2_i    = ($signed(op1_i) <  $signed(op2_i));                     // INST_BLT,  1 = op1_i <  op2_i, 0 = op1_i >= op2_i
    wire        op1_i_ge_op2_i    = ($signed(op1_i) >= $signed(op2_i));                     // INST_BGE,  1 = op1_i >= op2_i, 0 = op1_i <  op2_i
    wire        op1_i_ltu_op2_i   = (op1_i < op2_i );                                       // INST_BLTU, 1 = op1_i <  op2_i, 0 = op1_i >= op2_i
    wire        op1_i_geu_op2_i   = (op1_i >= op2_i);                                       // INST_BGEU, 1 = op1_i >= op2_i, 0 = op1_i <  op2_i
    wire[31:0]  base_addr_add_addr_offset   = (base_addr_i + addr_offset_i);                // branch addr. = pc + imm

    // load/store index
    wire[1:0]   load_index  = base_addr_add_addr_offset[1:0];
    wire[1:0]   store_index = base_addr_add_addr_offset[1:0];
   

    // ============================================================
    //  Ex-stage logic
    // ============================================================
    
    always @(*) begin
        // defaults
        rd_addr_o   = `ZeroReg      ;
        rd_data_o   = `ZeroWord     ;
        rd_w_en_o   = `WriteDisable ;

        jump_addr_o = `ZeroAddr     ;
        jump_en_o   = `JumpDisable  ;
        hold_flag_o = `HoldDisable  ;

        data_mem_w_en_o	  = `WriteDisalbe;
        data_mem_w_sel_o  = 4'b0;
        data_mem_w_addr_o = `ZeroAddr;
        data_mem_w_data_o = `ZeroWord;

        case(opcode) 
            // I-type
            `INST_TYPE_I: begin
                case(funct3)
                    `INST_ADDI: begin      
                        rd_addr_o   = rd_addr_i           ;
                        rd_data_o   = op1_i_add_op2_i     ;
                        rd_w_en_o   = `WriteEnable        ;
                    end

                    `INST_SLTI : begin
                        rd_addr_o   = rd_addr_i           ;
                        rd_data_o   = op1_i_slt_op2_i     ;
                        rd_w_en_o   = `WriteEnable        ;
                    end

                    `INST_SLTIU: begin
                        rd_addr_o   = rd_addr_i           ;
                        rd_data_o   = op1_i_sltu_op2_i    ;
                        rd_w_en_o   = `WriteEnable        ;
                    end

                    `INST_XORI : begin
                        rd_addr_o   = rd_addr_i           ;
                        rd_data_o   = op1_i_xor_op2_i     ;
                        rd_w_en_o   = `WriteEnable        ;
                    end

                    `INST_ORI  : begin
                        rd_addr_o   = rd_addr_i           ;
                        rd_data_o   = op1_i_or_op2_i      ;
                        rd_w_en_o   = `WriteEnable        ;
                    end

                    `INST_ANDI : begin
                        rd_addr_o   = rd_addr_i           ;
                        rd_data_o   = op1_i_and_op2_i     ;
                        rd_w_en_o   = `WriteEnable        ;
                    end

                    `INST_SLLI : begin
                        rd_addr_o   = rd_addr_i           ;
                        rd_data_o   = op1_i_sll_op2_i     ;
                        rd_w_en_o   = `WriteEnable        ;
                    end

                    `INST_SRI  : begin
                        if (funct7 == 7'b000_0000) begin            // INST_SRLI
                            rd_addr_o   = rd_addr_i       ;
                            rd_data_o   = op1_i_srl_op2_i ;
                            rd_w_en_o   = `WriteEnable    ;
                        end else if (funct7 == 7'b010_0000) begin   // INST_SRAI
                            rd_addr_o   = rd_addr_i       ;
                            rd_data_o   = op1_i_sra_op2_i ;
                            rd_w_en_o   = `WriteEnable    ;    
                        end else begin                              // illegal input, funct7 error 
                            rd_addr_o   = `ZeroReg        ;
                            rd_data_o   = `ZeroWord       ;
                            rd_w_en_o   = `WriteDisable   ;
                        end
                    end
                    
                    default: begin
                        rd_addr_o   = `ZeroReg            ;
                        rd_data_o   = `ZeroWord           ;
                        rd_w_en_o   = `WriteDisable       ;
                    end
                    
                endcase
            end

            // R-type
            `INST_TYPE_R_M: begin
                case(funct3)
                    `INST_ADD_SUB: begin
                        if (funct7 == 7'b000_0000) begin            // add
                            rd_addr_o   = rd_addr_i       ;
                            rd_data_o   = op1_i_add_op2_i ;
                            rd_w_en_o   = `WriteEnable    ;
                        end else if (funct7 == 7'b010_0000) begin   // sub
                            rd_addr_o   = rd_addr_i       ;
                            rd_data_o   = op1_i_sub_op2_i ;
                            rd_w_en_o   = `WriteEnable    ;
                        end else begin
                            rd_addr_o   = `ZeroReg        ;
                            rd_data_o   = `ZeroWord       ;
                            rd_w_en_o   = `WriteDisable   ;
                        end  
                    end

                    `INST_SLL: begin
                        rd_addr_o   = rd_addr_i           ;
                        rd_data_o   = op1_i_sll_op2_i     ;
                        rd_w_en_o   = `WriteEnable        ;
                    end

                    `INST_SLT: begin
                        rd_addr_o   = rd_addr_i           ;
                        rd_data_o   = op1_i_slt_op2_i     ;
                        rd_w_en_o   = `WriteEnable        ;
                    end

                    `INST_SLTU: begin
                        rd_addr_o   = rd_addr_i           ;
                        rd_data_o   = op1_i_sltu_op2_i    ;
                        rd_w_en_o   = `WriteEnable        ;
                    end

                    `INST_XOR: begin
                        rd_addr_o   = rd_addr_i           ;
                        rd_data_o   = op1_i_xor_op2_i     ;
                        rd_w_en_o   = `WriteEnable        ;
                    end

                    `INST_SR: begin
                        if (funct7 == 7'b000_0000) begin            // INST_SRL
                            rd_addr_o   = rd_addr_i       ;
                            rd_data_o   = op1_i_srl_op2_i ;
                            rd_w_en_o   = `WriteEnable    ;
                        end else if (funct7 == 7'b010_0000) begin   // INST_SRA
                            rd_addr_o   = rd_addr_i       ;
                            rd_data_o   = op1_i_sra_op2_i ;
                            rd_w_en_o   = `WriteEnable    ;    
                        end else begin                              // illegal input, funct7 error 
                            rd_addr_o   = `ZeroReg        ;
                            rd_data_o   = `ZeroWord       ;
                            rd_w_en_o   = `WriteDisable   ;
                        end
                    end

                    `INST_OR: begin
                        rd_addr_o   = rd_addr_i           ;
                        rd_data_o   = op1_i_or_op2_i      ;
                        rd_w_en_o   = `WriteEnable        ;
                    end

                    `INST_AND: begin
                        rd_addr_o   = rd_addr_i           ;
                        rd_data_o   = op1_i_and_op2_i     ;
                        rd_w_en_o   = `WriteEnable        ;
                    end

                    default: begin
                        rd_addr_o   = `ZeroReg          ;
                        rd_data_o   = `ZeroWord         ;
                        rd_w_en_o   = `WriteDisable     ;				
					end

                endcase
            end

            // B-type
            `INST_TYPE_B: begin
                case(funct3)
                    `INST_BEQ: begin
                        jump_addr_o = base_addr_add_addr_offset ;
                        jump_en_o   = op1_i_eq_op2_i            ;
                        hold_flag_o = `HoldDisable              ;
                    end

                    `INST_BNE: begin
                        jump_addr_o = base_addr_add_addr_offset ;
                        jump_en_o   = op1_i_ne_op2_i            ;
                        hold_flag_o = `HoldDisable              ;
                    end

                    `INST_BLT: begin
                        jump_addr_o = base_addr_add_addr_offset ;
                        jump_en_o   = op1_i_lt_op2_i            ;
                        hold_flag_o = `HoldDisable              ;
                    end

                    `INST_BGE: begin
                        jump_addr_o = base_addr_add_addr_offset ;
                        jump_en_o   = op1_i_ge_op2_i            ;
                        hold_flag_o = `HoldDisable              ;
                    end

                    `INST_BLTU: begin
                        jump_addr_o = base_addr_add_addr_offset ;
                        jump_en_o   = op1_i_ltu_op2_i           ;
                        hold_flag_o = `HoldDisable              ;
                    end

                    `INST_BGEU: begin
                        jump_addr_o = base_addr_add_addr_offset ;
                        jump_en_o   = op1_i_geu_op2_i           ;
                        hold_flag_o = `HoldDisable              ;
                    end

                    default: begin
                        jump_addr_o = `ZeroAddr     ;
                        jump_en_o   = `JumpDisable  ;
                        hold_flag_o = `HoldDisable  ;
                    end

                endcase
            end

            // L-type
            `INST_TYPE_L: begin
                case (funct3)
                    `INST_LB: begin
                        rd_addr_o = rd_addr_i       ;
                        rd_w_en_o = `WriteEnable    ;

                        case (load_index)
                            2'b00   : rd_data_o = {{24{data_mem_rd_data_i[7 ]} }, data_mem_rd_data_i[7 :0 ] };
                            2'b01   : rd_data_o = {{24{data_mem_rd_data_i[15]} }, data_mem_rd_data_i[15:8 ] };
                            2'b10   : rd_data_o = {{24{data_mem_rd_data_i[23]} }, data_mem_rd_data_i[23:16] };
                            2'b11   : rd_data_o = {{24{data_mem_rd_data_i[31]} }, data_mem_rd_data_i[31:24] };
                            default : rd_data_o = `ZeroWord;
                        endcase
                    end 
                    
                    `INST_LH: begin
                        rd_addr_o = rd_addr_i       ;
                        rd_w_en_o = `WriteEnable    ;

                        if (load_index[0] == 1'b1) begin        // misaligned halfword address check (..01 or ..11)
                            rd_w_en_o = `WriteDisable;
                            rd_data_o = `ZeroWord;
                        end else begin
                            case (load_index[1])
                                1'b0    : rd_data_o = {{16{data_mem_rd_data_i[15]}}, data_mem_rd_data_i[15:0]};   // low half
                                1'b1    : rd_data_o = {{16{data_mem_rd_data_i[31]}}, data_mem_rd_data_i[31:16]};  // high half
                                default : rd_data_o = `ZeroWord;
                            endcase
                        end
                    end

                    `INST_LW: begin
						rd_addr_o = rd_addr_i;
                        rd_data_o = data_mem_rd_data_i;
						rd_w_en_o = `WriteEnable;
                    end 
                    
                    `INST_LBU: begin
                        rd_addr_o = rd_addr_i;
                        rd_w_en_o = `WriteEnable;

                        case (load_index)
                            2'b00   : rd_data_o = {24'b0, data_mem_rd_data_i[7 :0 ]};
                            2'b01   : rd_data_o = {24'b0, data_mem_rd_data_i[15:8 ]};
                            2'b10   : rd_data_o = {24'b0, data_mem_rd_data_i[23:16]};
                            2'b11   : rd_data_o = {24'b0, data_mem_rd_data_i[31:24]};
                            default : rd_data_o = `ZeroWord;
                        endcase
                    end
                    
                    `INST_LHU: begin
                        rd_addr_o = rd_addr_i;
                        rd_w_en_o = `WriteEnable;

                        if (load_index[0] == 1'b1) begin        // misaligned halfword address check (..01 or ..11)
                            rd_w_en_o = `WriteDisable;  
                            rd_data_o = `ZeroWord;
                        end else begin
                            case (load_index[1])
                                1'b0: rd_data_o = {16'b0, data_mem_rd_data_i[15:0 ]};
                                1'b1: rd_data_o = {16'b0, data_mem_rd_data_i[31:16]};
                            endcase
                        end
                    end

                    default: begin
                        rd_addr_o   = `ZeroReg      ;
                        rd_data_o   = `ZeroWord     ;
                        rd_w_en_o   = `WriteDisable ;
                    end

                endcase
            end

            // S-tpye
            `INST_TYPE_S: begin
                case (funct3)
                    `INST_SB: begin
                        
                    end

                    `INST_SH: begin
                        
                    end 
                    
                    `INST_SW: begin

                    end

                    default: begin

                    end

                endcase
            end
            

            // J-type jump
            `INST_JAL: begin
                rd_addr_o   = rd_addr_i           ;
                rd_data_o   = inst_addr_i + 32'h4 ;
                rd_w_en_o   = `WriteEnable        ;

                jump_addr_o = op1_i_add_op2_i     ;
                jump_en_o   = `JumpEnable         ;
                hold_flag_o = `HoldDisable        ;
            end

            // I-type jump
            `INST_JALR: begin
                rd_addr_o   = rd_addr_i                         ;
                rd_data_o   = inst_addr_i + 32'h4               ;
                rd_w_en_o   = `WriteEnable                      ;

                jump_addr_o = (op1_i_add_op2_i) & 32'hFFFF_FFFE ;       // JALR sets the least-significant bit of the target address to zero
                jump_en_o   = `JumpEnable                       ;
                hold_flag_o = `HoldDisable                      ;
            end

            // U-type
            `INST_LUI: begin
                rd_addr_o   = rd_addr_i     ;
                rd_data_o   = op1_i         ;
                rd_w_en_o   = `WriteEnable  ;

                jump_addr_o = `ZeroAddr     ;
                jump_en_o   = `JumpDisable  ;
                hold_flag_o = `HoldDisable  ;
            end

            `INST_AUIPC: begin
                rd_addr_o   = rd_addr_i         ;
                rd_data_o   = op1_i_add_op2_i   ;
                rd_w_en_o   = `WriteEnable      ;

                jump_addr_o = `ZeroAddr         ;
                jump_en_o   = `JumpDisable      ;
                hold_flag_o = `HoldDisable      ;
            end

            default: begin
                rd_addr_o   = `ZeroReg      ;
                rd_data_o   = `ZeroWord     ;
                rd_w_en_o   = `WriteDisable ;

                jump_addr_o = `ZeroAddr     ;
                jump_en_o   = `JumpDisable  ;
                hold_flag_o = `HoldDisable  ;
            end

        endcase
    end


endmodule