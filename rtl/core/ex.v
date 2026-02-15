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

    // to regs  
    output reg[4:0]     rd_addr_o           ,
    output reg[31:0]    rd_data_o           ,
    output reg          rd_w_en_o           ,

    // from mul
    input wire          mul_busy_i          ,
    input wire          mul_ready_i         ,
    input wire[63:0]    mul_result64_i      ,
    input wire[4:0]     mul_rd_waddr_i      ,
    input wire[2:0]     mul_funct3_i        ,

    // to mul
    output reg          mul_start_o         ,
    output reg[2:0]     mul_funct3_o        ,
    output reg[31:0]    mul_op1_o           ,
    output reg[31:0]    mul_op2_o           ,
    output reg[4:0]     mul_reg_waddr_o     ,

    // to ctrl  
    output reg[31:0]    jump_addr_o         ,
    output reg          jump_en_o           ,
    output reg          flush_req_o         ,       // NOP
    output reg          stall_req_o         ,       // stall

    // from data_mem read
    input  wire[31:0]   data_mem_r_data_i   ,

    // to data_mem write
    output reg	 	    data_mem_w_en_o	    ,
	output reg[3:0]     data_mem_w_sel_o    ,
	output reg[31:0]    data_mem_w_addr_o   ,
	output reg[31:0]    data_mem_w_data_o   	
);

    // R-type
    wire[6:0]  opcode   = inst_i[6:0];
    wire[4:0]  rd       = inst_i[11:7];
    wire[2:0]  funct3   = inst_i[14:12];
    wire[4:0]  rs1      = inst_i[19:15];
    wire[4:0]  rs2      = inst_i[24:20];
    wire[6:0]  funct7   = inst_i[31:25];
    // I-type
    wire[11:0] imm      = inst_i[31:20];


    // ============================================================
    //  ALU
    // ============================================================
    // signed / unsigned op1_i
    wire signed [31:0] op1_i_s = op1_i;
    wire        [31:0] op1_i_u = op1_i;
    // signed / unsigned op2_i
    wire signed [31:0] op2_i_s = op2_i;
    wire        [31:0] op2_i_u = op2_i;

    // I-type
    wire[31:0]  op1_i_slt_op2_i    = (op1_i_s < op2_i_s) ? 32'd1 : 32'd0;           // INST_SLTI  & INST_SLT
    wire[31:0]  op1_i_sltu_op2_i   = (op1_i < op2_i)     ? 32'd1 : 32'd0;           // INST_SLTIU & INST_SLTU 
    wire[31:0]  op1_i_xor_op2_i    = (op1_i ^ op2_i);                               // INST_XORI  & INST_XOR
    wire[31:0]  op1_i_or_op2_i     = (op1_i | op2_i);                               // INST_ORI   & INST_OR
    wire[31:0]  op1_i_and_op2_i    = (op1_i & op2_i);                               // INST_ANDI  & INST_AND
    wire[31:0]  op1_i_sll_op2_i    = (op1_i << op2_i[4:0]);                         // INST_SLLI  & INST_SLL
    wire[31:0]  op1_i_srl_op2_i    = (op1_i >> op2_i[4:0]);                         // INST_SRLI  & INST_SRL
    wire[31:0]  op1_i_sra_op2_i    = (op1_i_s >>> op2_i[4:0]);                      // INST_SRAI  & INST_SRA
 
    // R-type 
    wire[31:0]  op1_i_add_op2_i    = (op1_i + op2_i);                               // INST_ADD_SUB add
    wire[31:0]  op1_i_sub_op2_i    = (op1_i - op2_i);                               // INST_ADD_SUB sub
 
    // M-type 
    wire[63:0]  op1_i_mul_op2_i    = (op1_i_s * op2_i_s);                           // INST_MUL & INST_MULH
    wire[63:0]  op1_i_mulhsu_op2_i = (op1_i_s * $signed({1'b0, op2_i}));            // INST_MULHSU (make op2 32bit unsigned -> 33bit signed)
    wire[63:0]  op1_i_mulhu_op2_i  = (op1_i * op2_i);                               // INST_MULHU
    wire[63:0]  op1_i_div_op2_i    = (op1_i_s / op2_i_s);                           // INST_DIV
    wire[63:0]  op1_i_divu_op2_i   = (op1_i / op2_i);                               // INST_DIVU
    wire[31:0]  op1_i_rem_op2_i    = (op1_i_s % op2_i_s);                           // INST_REM
    wire[31:0]  op1_i_remu_op2_i   = (op1_i % op2_i);                               // INST_REMU
 
    // B-type    
    wire        op1_i_eq_op2_i     = (op1_i == op2_i);                              // INST_BEQ 
    wire        op1_i_ne_op2_i     = (op1_i != op2_i);                              // INST_BNE
    wire        op1_i_lt_op2_i     = (op1_i_s <  op2_i_s);                          // INST_BLT,  1 = op1_i <  op2_i, 0 = op1_i >= op2_i
    wire        op1_i_ge_op2_i     = (op1_i_s >= op2_i_s);                          // INST_BGE,  1 = op1_i >= op2_i, 0 = op1_i <  op2_i
    wire        op1_i_ltu_op2_i    = (op1_i < op2_i );                              // INST_BLTU, 1 = op1_i <  op2_i, 0 = op1_i >= op2_i
    wire        op1_i_geu_op2_i    = (op1_i >= op2_i);                              // INST_BGEU, 1 = op1_i >= op2_i, 0 = op1_i <  op2_i
    wire[31:0]  base_addr_add_addr_offset = (base_addr_i + addr_offset_i);          // branch addr. = pc + imm

    // load/store index
    wire[1:0]   load_index  = base_addr_add_addr_offset[1:0];
    wire[1:0]   store_index = base_addr_add_addr_offset[1:0];
/*    
    // mul determined
    wire is_mul_inst = (opcode == `INST_TYPE_R_M) && (funct7 == 7'b0000001) &&
        (   (funct3 == `INST_MUL)    ||
            (funct3 == `INST_MULH)   ||
            (funct3 == `INST_MULHSU) ||
            (funct3 == `INST_MULHU)     );

    assign mul_start_o    = is_mul_inst || mul_busy_i;
    assign mul_funct3_o   = funct3;
    assign mul_op1_o      = op1_i;
    assign mul_op2_o      = op2_i;
    assign mul_rd_waddr_o = rd_addr_i;

    assign stall_req_o    = (is_mul_inst && !mul_ready_i) || mul_busy_i;
 */


    // ============================================================
    //  Ex-stage logic
    // ============================================================
    
    always @(*) begin
        // defaults
        rd_addr_o   = `ZeroReg      ;
        rd_data_o   = `ZeroWord     ;
        rd_w_en_o   = `WriteDisable ;

        // default mul outputs
        mul_start_o      = 1'b0;
        mul_funct3_o     = 3'd0;
        mul_op1_o        = 32'd0;
        mul_op2_o        = 32'd0;
        mul_reg_waddr_o  = 5'd0;

        jump_addr_o = `ZeroAddr     ;
        jump_en_o   = `JumpDisable  ;
        flush_req_o = `FlushDisable ;
        stall_req_o = `StallDisable ;

        data_mem_w_en_o	  = `WriteDisable ;
        data_mem_w_sel_o  = 4'b0          ;
        data_mem_w_addr_o = `ZeroAddr     ;
        data_mem_w_data_o = `ZeroWord     ;

        case(opcode) 
            // I-type
            `INST_TYPE_I: begin
                case(funct3)
                    `INST_ADDI: begin      
                        rd_addr_o   = rd_addr_i       ;
                        rd_data_o   = op1_i_add_op2_i ;
                        rd_w_en_o   = `WriteEnable    ;
                    end

                    `INST_SLTI : begin
                        rd_addr_o   = rd_addr_i       ;
                        rd_data_o   = op1_i_slt_op2_i ;
                        rd_w_en_o   = `WriteEnable    ;
                    end

                    `INST_SLTIU: begin
                        rd_addr_o   = rd_addr_i        ;
                        rd_data_o   = op1_i_sltu_op2_i ;
                        rd_w_en_o   = `WriteEnable     ;
                    end

                    `INST_XORI : begin
                        rd_addr_o   = rd_addr_i       ;
                        rd_data_o   = op1_i_xor_op2_i ;
                        rd_w_en_o   = `WriteEnable    ;
                    end

                    `INST_ORI  : begin
                        rd_addr_o   = rd_addr_i      ;
                        rd_data_o   = op1_i_or_op2_i ;
                        rd_w_en_o   = `WriteEnable   ;
                    end

                    `INST_ANDI : begin
                        rd_addr_o   = rd_addr_i       ;
                        rd_data_o   = op1_i_and_op2_i ;
                        rd_w_en_o   = `WriteEnable    ;
                    end

                    `INST_SLLI : begin
                        rd_addr_o   = rd_addr_i       ;
                        rd_data_o   = op1_i_sll_op2_i ;
                        rd_w_en_o   = `WriteEnable    ;
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
                        end else begin                                // illegal input, funct7 error 
                            rd_addr_o   = `ZeroReg        ;
                            rd_data_o   = `ZeroWord       ;
                            rd_w_en_o   = `WriteDisable   ;
                        end
                    end
                    
                    default: begin
                        rd_addr_o   = `ZeroReg      ;
                        rd_data_o   = `ZeroWord     ;
                        rd_w_en_o   = `WriteDisable ;
                    end
                    
                endcase
            end

            // R/M-type
            `INST_TYPE_R_M: begin

                
                if (funct7 == `FUNCT7_TYPE_M) begin     // M-type
                    case (funct3)
                        `INST_MUL, `INST_MULH, `INST_MULHSU, `INST_MULHU: begin
                            // start mul.v
                            mul_start_o     = 1'b1      ;
                            mul_funct3_o    = funct3    ;
                            mul_op1_o       = op1_i     ;
                            mul_op2_o       = op2_i     ;
                            mul_reg_waddr_o = rd_addr_i ;

                            // stall pipeline
                            stall_req_o = (!mul_ready_i) || mul_busy_i;

                            // ready & write back
                            if (mul_ready_i) begin              
                                rd_w_en_o = `WriteEnable;
                                rd_addr_o = mul_rd_waddr_i;

                                if (mul_funct3_i == `INST_MUL)
                                    rd_data_o = mul_result64_i[31:0];
                                else
                                    rd_data_o = mul_result64_i[63:32];
                            end
                        end
/*                     
                        `INST_MUL: begin
                            rd_addr_o = rd_addr_i             ;
                            rd_data_o = op1_i_mul_op2_i[31:0] ;
                            rd_w_en_o = `WriteEnable          ;
                        end

                        `INST_MULH: begin
                            rd_addr_o = rd_addr_i              ;
                            rd_data_o = op1_i_mul_op2_i[63:32] ;
                            rd_w_en_o = `WriteEnable           ;
                        end

                        `INST_MULHSU: begin
                            rd_addr_o = rd_addr_i                 ;
                            rd_data_o = op1_i_mulhsu_op2_i[63:32] ;
                            rd_w_en_o = `WriteEnable              ;
                        end

                        `INST_MULHU: begin
                            rd_addr_o = rd_addr_i                ;
                            rd_data_o = op1_i_mulhu_op2_i[63:32] ;
                            rd_w_en_o = `WriteEnable             ;
                        end
 */
                        `INST_DIV: begin
                            rd_addr_o = rd_addr_i       ;
                            rd_data_o = op1_i_div_op2_i ;
                            rd_w_en_o = `WriteEnable    ;
                        end

                        `INST_DIVU: begin
                            rd_addr_o = rd_addr_i        ;
                            rd_data_o = op1_i_divu_op2_i ;
                            rd_w_en_o = `WriteEnable     ;
                        end

                        `INST_REM: begin
                            rd_addr_o = rd_addr_i    ;
                            rd_w_en_o = `WriteEnable ;

                            if (op2_i == 0)                                             
                                rd_data_o = op1_i;
                            else if (op1_i == 32'h80000000 && op2_i == 32'hFFFFFFFF)        // overflow detection
                                rd_data_o = 0;
                            else                                                        
                                rd_data_o = op1_i_rem_op2_i;
                        end

                        `INST_REMU: begin
                            rd_addr_o = rd_addr_i    ;
                            rd_w_en_o = `WriteEnable ;

                            if (op2_i == 32'b0)
                                rd_data_o = op1_i;
                            else
                                rd_data_o = op1_i_remu_op2_i;
                        end

                        default: begin
                            rd_addr_o   = `ZeroReg      ;
                            rd_data_o   = `ZeroWord     ;
                            rd_w_en_o   = `WriteDisable ;     
                        end
                    endcase 
                end else begin                          // R-type
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
                            rd_addr_o   = rd_addr_i       ;
                            rd_data_o   = op1_i_sll_op2_i ;
                            rd_w_en_o   = `WriteEnable    ;
                        end

                        `INST_SLT: begin
                            rd_addr_o   = rd_addr_i       ;
                            rd_data_o   = op1_i_slt_op2_i ;
                            rd_w_en_o   = `WriteEnable    ;
                        end

                        `INST_SLTU: begin
                            rd_addr_o   = rd_addr_i        ;
                            rd_data_o   = op1_i_sltu_op2_i ;
                            rd_w_en_o   = `WriteEnable     ;
                        end

                        `INST_XOR: begin
                            rd_addr_o   = rd_addr_i       ;
                            rd_data_o   = op1_i_xor_op2_i ;
                            rd_w_en_o   = `WriteEnable    ;
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
                            rd_addr_o   = rd_addr_i      ;
                            rd_data_o   = op1_i_or_op2_i ;
                            rd_w_en_o   = `WriteEnable   ;
                        end

                        `INST_AND: begin
                            rd_addr_o   = rd_addr_i       ;
                            rd_data_o   = op1_i_and_op2_i ;
                            rd_w_en_o   = `WriteEnable    ;
                        end

                        default: begin
                            rd_addr_o   = `ZeroReg      ;
                            rd_data_o   = `ZeroWord     ;
                            rd_w_en_o   = `WriteDisable ;				
                        end

                    endcase
                end
            end

            // B-type
            `INST_TYPE_B: begin
                case(funct3)
                    `INST_BEQ: begin
                        jump_addr_o  = base_addr_add_addr_offset ;
                        jump_en_o    = op1_i_eq_op2_i            ;
                    end

                    `INST_BNE: begin
                        jump_addr_o  = base_addr_add_addr_offset ;
                        jump_en_o    = op1_i_ne_op2_i            ;
                    end

                    `INST_BLT: begin
                        jump_addr_o  = base_addr_add_addr_offset ;
                        jump_en_o    = op1_i_lt_op2_i            ;
                    end

                    `INST_BGE: begin
                        jump_addr_o  = base_addr_add_addr_offset ;
                        jump_en_o    = op1_i_ge_op2_i            ;
                    end

                    `INST_BLTU: begin
                        jump_addr_o  = base_addr_add_addr_offset ;
                        jump_en_o    = op1_i_ltu_op2_i           ;
                    end

                    `INST_BGEU: begin
                        jump_addr_o  = base_addr_add_addr_offset ;
                        jump_en_o    = op1_i_geu_op2_i           ;
                    end

                    default: begin
                        jump_addr_o  = `ZeroAddr    ;
                        jump_en_o    = `JumpDisable ;
                    end

                endcase
            end

            // L-type
            `INST_TYPE_L: begin
                case (funct3)
                    `INST_LB: begin
                        rd_addr_o = rd_addr_i    ;
                        rd_w_en_o = `WriteEnable ;

                        case (load_index)
                            2'b00   : rd_data_o = { {24{data_mem_r_data_i[ 7]} }, data_mem_r_data_i[ 7: 0] } ;
                            2'b01   : rd_data_o = { {24{data_mem_r_data_i[15]} }, data_mem_r_data_i[15: 8] } ;
                            2'b10   : rd_data_o = { {24{data_mem_r_data_i[23]} }, data_mem_r_data_i[23:16] } ;
                            2'b11   : rd_data_o = { {24{data_mem_r_data_i[31]} }, data_mem_r_data_i[31:24] } ;
                            default : rd_data_o = `ZeroWord;
                        endcase
                    end 
                    
                    `INST_LH: begin
                        rd_addr_o = rd_addr_i    ;
                        rd_w_en_o = `WriteEnable ;

                        if (load_index[0] == 1'b1) begin        // misaligned halfword address check (..01 or ..11)
                            rd_w_en_o = `WriteDisable ;
                            rd_data_o = `ZeroWord     ;
                        end else begin
                            case (load_index[1])
                                1'b0    : rd_data_o = { {16{data_mem_r_data_i[15]}}, data_mem_r_data_i[15: 0] } ;     // low half
                                1'b1    : rd_data_o = { {16{data_mem_r_data_i[31]}}, data_mem_r_data_i[31:16] } ;     // high half
                                default : rd_data_o = `ZeroWord;
                            endcase
                        end
                    end

                    `INST_LW: begin
                        rd_addr_o = rd_addr_i;

                        if (load_index != 2'b00) begin          // misaligned word address check (..01 or .. 10 or ..11)
                            rd_data_o = `ZeroWord         ;
                            rd_w_en_o = `WriteDisable     ;   
                        end else begin
                            rd_data_o = data_mem_r_data_i ;
                            rd_w_en_o = `WriteEnable      ;
                        end
                    end

                    
                    `INST_LBU: begin
                        rd_addr_o = rd_addr_i;
                        rd_w_en_o = `WriteEnable;

                        case (load_index)
                            2'b00   : rd_data_o = {24'b0, data_mem_r_data_i[ 7: 0]} ;
                            2'b01   : rd_data_o = {24'b0, data_mem_r_data_i[15: 8]} ;
                            2'b10   : rd_data_o = {24'b0, data_mem_r_data_i[23:16]} ;
                            2'b11   : rd_data_o = {24'b0, data_mem_r_data_i[31:24]} ;
                            default : rd_data_o = `ZeroWord                         ;
                        endcase
                    end
                    
                    `INST_LHU: begin
                        rd_addr_o = rd_addr_i    ;
                        rd_w_en_o = `WriteEnable ;

                        if (load_index[0] == 1'b1) begin        // misaligned halfword address check (..01 or ..11)
                            rd_w_en_o = `WriteDisable ;  
                            rd_data_o = `ZeroWord     ;
                        end else begin
                            case (load_index[1])
                                1'b0: rd_data_o = {16'b0, data_mem_r_data_i[15: 0]} ;
                                1'b1: rd_data_o = {16'b0, data_mem_r_data_i[31:16]} ;
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
                        data_mem_w_en_o             = `WriteEnable              ;
                        data_mem_w_addr_o           = base_addr_add_addr_offset ;

                        case (store_index)
                            2'b00: begin
                                data_mem_w_sel_o    = 4'b0001                   ;       // byte 0
                                data_mem_w_data_o   = {24'b0, op2_i[7:0]}       ;
                            end
                            2'b01: begin
                                data_mem_w_sel_o    = 4'b0010                   ;       // byte 1
                                data_mem_w_data_o   = {16'b0, op2_i[7:0], 8'b0} ;
                            end
                            2'b10: begin
                                data_mem_w_sel_o    = 4'b0100                   ;       // byte 2
                                data_mem_w_data_o   = {8'b0, op2_i[7:0], 16'b0} ;
                            end
                            2'b11: begin
                                data_mem_w_sel_o    = 4'b1000                   ;       // byte 3
                                data_mem_w_data_o   = {op2_i[7:0], 24'b0}       ;
                            end

                            default: begin
                                data_mem_w_sel_o    = 4'b0000                   ;
                                data_mem_w_data_o   = `ZeroWord                 ;
                            end
                        endcase
                    end

                    `INST_SH: begin
                        data_mem_w_en_o    = `WriteEnable;
                        data_mem_w_addr_o  = base_addr_add_addr_offset;

                        if (store_index[0] == 1'b1) begin           // misaligned halfword address check (..01 or ..11)
                            data_mem_w_en_o   = `WriteDisable ;
                            data_mem_w_sel_o  = 4'b0000       ;
                            data_mem_w_data_o = `ZeroWord     ;
                        end else begin
                            case (store_index[1])
                                1'b0: begin                         // ..00 : write low halfword -> byte0 & byte1
                                    data_mem_w_sel_o  = 4'b0011;
                                    data_mem_w_data_o = {16'b0, op2_i[15:0]};
                                end

                                1'b1: begin                         // ..10 : write high halfword -> byte2 & byte3
                                    data_mem_w_sel_o  = 4'b1100;
                                    data_mem_w_data_o = {op2_i[15:0], 16'b0};
                                end
                            endcase
                        end
                    end

                    
                    `INST_SW: begin
                        data_mem_w_addr_o = base_addr_add_addr_offset;

                        if (store_index != 2'b00) begin         // misaligned halfword address check 
                            data_mem_w_en_o   = `WriteDisable ;
                            data_mem_w_sel_o  = 4'b0000       ;
                            data_mem_w_data_o = `ZeroWord     ;
                        end else begin
                            data_mem_w_en_o   = `WriteEnable ;
                            data_mem_w_sel_o  = 4'b1111      ;
                            data_mem_w_data_o = op2_i        ;
                        end
                    end

                    default: begin
                        data_mem_w_en_o	    = `WriteDisable ;
                        data_mem_w_sel_o    = 4'b0          ;
                        data_mem_w_addr_o   = `ZeroAddr     ;
                        data_mem_w_data_o   = `ZeroWord     ;
                    end

                endcase
            end
            
            // J-type jump
            `INST_JAL: begin
                rd_addr_o    = rd_addr_i                 ;
                rd_data_o    = inst_addr_i + 32'h4       ;
                rd_w_en_o    = `WriteEnable              ;
 
                jump_addr_o  = base_addr_add_addr_offset ;
                jump_en_o    = `JumpEnable               ;
            end

            // I-type jump
            `INST_JALR: begin
                rd_addr_o    = rd_addr_i           ;
                rd_data_o    = inst_addr_i + 32'h4 ;
                rd_w_en_o    = `WriteEnable        ;
 
                jump_addr_o  = (base_addr_add_addr_offset) & 32'hFFFF_FFFE ;       // JALR sets the least-significant bit of the target address to zero
                jump_en_o    = `JumpEnable                       ;
            end

            // U-type
            `INST_LUI: begin
                rd_addr_o    = rd_addr_i    ;
                rd_data_o    = op1_i        ;
                rd_w_en_o    = `WriteEnable ;
 
                jump_addr_o  = `ZeroAddr    ;
                jump_en_o    = `JumpDisable ;
            end

            `INST_AUIPC: begin
                rd_addr_o    = rd_addr_i       ;
                rd_data_o    = op1_i_add_op2_i ;
                rd_w_en_o    = `WriteEnable    ;
 
                jump_addr_o  = `ZeroAddr       ;
                jump_en_o    = `JumpDisable    ;
            end

            default: begin
                rd_addr_o    = `ZeroReg      ;
                rd_data_o    = `ZeroWord     ;
                rd_w_en_o    = `WriteDisable ;
 
                jump_addr_o  = `ZeroAddr     ;
                jump_en_o    = `JumpDisable  ;
            end

        endcase
    end


endmodule