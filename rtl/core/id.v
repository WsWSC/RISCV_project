////////////////////////////////////////////////////////////
//  RISC-V CPU Side Project
//  Author  : WsWSC
//  Created : 2026
//  License : Personal / Educational Use
////////////////////////////////////////////////////////////

`include "defines.v"

module id(
    // from if_id
    input wire[31:0]    inst_addr_i         ,       // return from "if_id"
    input wire[31:0]    inst_i              ,       // return from "if_id"

    // from regs            
    input wire[31:0]    rs1_data_i          ,       // return from "regs", it's actual data input
    input wire[31:0]    rs2_data_i          ,       // return from "regs", it's actual data input
    
    // to regs      
    output reg[4:0]     rs1_addr_o          ,       // send to "regs", it's reg addr. output
    output reg[4:0]     rs2_addr_o          ,       // send to "regs", it's reg addr. output

    // to id_ex     
    output reg[31:0]    inst_addr_o         ,       
    output reg[31:0]    inst_o              ,       
    output reg[31:0]    op1_o               ,       // send to "id_ex" DFF, = rs1_data_o
    output reg[31:0]    op2_o               ,       // send to "id_ex" DFF, = rs2_data_o
    output reg[4:0]     rd_addr_o           ,       // send to "id_ex" DFF, rd register addr.
    output reg          reg_w_en_o          ,       // send to "id_ex" DFF, reg_w_en_o = reg write enable 
    output reg[31:0]    base_addr_o         ,       // b/l/s type used
    output reg[31:0]    addr_offset_o       ,
    output reg[11:0]    csr_addr_o          ,
    output reg          csr_w_en_o          ,
    output reg[2:0]     csr_op_o            ,
    output reg          trap_en_o           ,
    output reg[31:0]    trap_cause_o        ,
    output reg[31:0]    trap_tval_o         ,
    output reg          mret_en_o
);

    // ============================================================
    //  Internal Signals
    // ============================================================
    // R-type
    wire[6:0]   opcode  = inst_i[6:0];
    wire[4:0]   rd      = inst_i[11:7];
    wire[2:0]   funct3  = inst_i[14:12];
    wire[4:0]   rs1     = inst_i[19:15];
    wire[4:0]   rs2     = inst_i[24:20];
    wire[6:0]   funct7  = inst_i[31:25];
    wire[11:0]  csr_addr = inst_i[31:20];

    wire        csr_inst = (opcode == `INST_CSR) &&
                           ((funct3 == `INST_CSRRW)  ||
                            (funct3 == `INST_CSRRS)  ||
                            (funct3 == `INST_CSRRC)  ||
                            (funct3 == `INST_CSRRWI) ||
                            (funct3 == `INST_CSRRSI) ||
                            (funct3 == `INST_CSRRCI));

    wire        csr_write_req = (funct3 == `INST_CSRRW)  ||
                                (funct3 == `INST_CSRRWI) ||
                                (((funct3 == `INST_CSRRS)  ||
                                  (funct3 == `INST_CSRRC)  ||
                                  (funct3 == `INST_CSRRSI) ||
                                  (funct3 == `INST_CSRRCI)) && (rs1 != `ZeroReg));

    wire        csr_read_only = (csr_addr == `CSR_CYCLE) ||
                                (csr_addr == `CSR_CYCLEH);

    wire        csr_valid = (csr_addr == `CSR_CYCLE)    ||
                            (csr_addr == `CSR_CYCLEH)   ||
                            (csr_addr == `CSR_MSTATUS)  ||
                            (csr_addr == `CSR_MIE)      ||
                            (csr_addr == `CSR_MTVEC)    ||
                            (csr_addr == `CSR_MSCRATCH) ||
                            (csr_addr == `CSR_MEPC)     ||
                            (csr_addr == `CSR_MCAUSE)   ||
                            (csr_addr == `CSR_MTVAL)    ||
                            (csr_addr == `CSR_MIP);

    wire        csr_illegal = csr_inst && ((!csr_valid) ||
                                           (csr_write_req && csr_read_only));

    reg          illegal_inst;

    // ============================================================
    //  Main logic
    // ============================================================
    always @(*) begin
        // send instr. to next stage
        inst_o = inst_i;
        inst_addr_o = inst_addr_i;

        // defaults
        rs1_addr_o        = `ZeroReg      ;
        rs2_addr_o        = `ZeroReg      ;

        op1_o             = `ZeroWord     ;
        op2_o             = `ZeroWord     ;
        rd_addr_o         = `ZeroReg      ;
        reg_w_en_o        = `WriteDisable ;
        base_addr_o       = `ZeroAddr     ;
        addr_offset_o     = `ZeroWord     ;
        csr_addr_o        = 12'b0         ;
        csr_w_en_o        = `WriteDisable ;
        csr_op_o          = 3'b0          ;
        trap_en_o         = `WriteDisable ;
        trap_cause_o      = `ZeroWord     ;
        trap_tval_o       = `ZeroWord     ;
        mret_en_o         = `WriteDisable ;
        illegal_inst      = 1'b0          ;

        case(opcode) 
            // I-type
            `INST_TYPE_I: begin
                case(funct3)
                    `INST_ADDI, `INST_SLTI, `INST_SLTIU, `INST_XORI, `INST_ORI, `INST_ANDI: begin 
                        rs1_addr_o = rs1                       ;
                        rs2_addr_o = `ZeroReg                  ;

                        op1_o      = rs1_data_i                ;
                        op2_o      = {{20{inst_i[31]}}, inst_i[31:20]}  ;
                        rd_addr_o  = rd                        ;   
                        reg_w_en_o = `WriteEnable              ;
                    end

                    `INST_SLLI, `INST_SRI: begin
                        if ((funct3 == `INST_SLLI && funct7 == 7'b000_0000) ||
                            (funct3 == `INST_SRI  && (funct7 == 7'b000_0000 || funct7 == 7'b010_0000))) begin
                            rs1_addr_o = rs1            ;
                            rs2_addr_o = `ZeroReg       ;

                            op1_o      = rs1_data_i     ;
                            op2_o      = {27'b0, inst_i[24:20]} ;
                            rd_addr_o  = rd             ;
                            reg_w_en_o = `WriteEnable   ;
                        end else begin
                            illegal_inst = 1'b1;
                        end
                    end
                    
                    default: begin
                        illegal_inst = 1'b1;
                    end
                    
                endcase
            end

            // R-type
            `INST_TYPE_R_M: begin
                if (funct7 == `FUNCT7_TYPE_M) begin     // M-type
                    case(funct3)
                        `INST_MUL, `INST_MULH, `INST_MULHSU, `INST_MULHU, `INST_DIV, `INST_DIVU, `INST_REM, `INST_REMU: begin
                            rs1_addr_o = rs1;
                            rs2_addr_o = rs2;

                            op1_o      = rs1_data_i;
                            op2_o      = rs2_data_i;
                            rd_addr_o  = rd;
                            reg_w_en_o = `WriteEnable;
                        end

                        default: begin
                            illegal_inst = 1'b1;
                        end

                    endcase

                end else begin                          // R-type
                    case(funct3)
                        `INST_ADD_SUB, `INST_SLT, `INST_SLTU, `INST_XOR, `INST_OR, `INST_AND: begin
                            if ((funct3 == `INST_ADD_SUB && (funct7 == 7'b000_0000 || funct7 == 7'b010_0000)) ||
                                (funct3 != `INST_ADD_SUB && funct7 == 7'b000_0000)) begin
                                rs1_addr_o = rs1;
                                rs2_addr_o = rs2;

                                op1_o      = rs1_data_i;
                                op2_o      = rs2_data_i;
                                rd_addr_o  = rd;
                                reg_w_en_o = `WriteEnable;
                            end else begin
                                illegal_inst = 1'b1;
                            end
                        end

                        `INST_SLL, `INST_SR: begin
                            if ((funct3 == `INST_SLL && funct7 == 7'b000_0000) ||
                                (funct3 == `INST_SR  && (funct7 == 7'b000_0000 || funct7 == 7'b010_0000))) begin
                                rs1_addr_o = rs1;
                                rs2_addr_o = rs2;

                                op1_o      = rs1_data_i;
                                op2_o      = {27'b0, rs2_data_i[4:0]};
                                rd_addr_o  = rd;
                                reg_w_en_o = `WriteEnable;
                            end else begin
                                illegal_inst = 1'b1;
                            end
                        end

                        default: begin
                            illegal_inst = 1'b1;
                        end

                    endcase
                end

            end

            // B-type
            `INST_TYPE_B: begin
                case(funct3)
                    `INST_BEQ, `INST_BNE, `INST_BLT, `INST_BGE, `INST_BLTU, `INST_BGEU: begin
                        rs1_addr_o    = rs1                       ;
                        rs2_addr_o    = rs2                       ;

                        op1_o         = rs1_data_i                ;
                        op2_o         = rs2_data_i                ;
                        rd_addr_o     = `ZeroReg                  ;   
                        reg_w_en_o    = `WriteDisable             ;
                        base_addr_o   = inst_addr_i               ;
                        addr_offset_o = {{19{inst_i[31]}}, inst_i[31], inst_i[7], inst_i[30:25], inst_i[11:8], 1'b0} ;
                    end

                    default: begin
                        illegal_inst = 1'b1;
                    end

                endcase
            end

            // L-type
            `INST_TYPE_L: begin
                case (funct3)
                    `INST_LB, `INST_LH, `INST_LW, `INST_LBU, `INST_LHU: begin
                        rs1_addr_o    = rs1          ;
                        rs2_addr_o    = `ZeroReg     ;

                        op1_o         = `ZeroWord    ;
                        op2_o         = `ZeroWord    ;
                        rd_addr_o     = rd           ;   
                        reg_w_en_o    = `WriteEnable ;
                        base_addr_o   = rs1_data_i   ;
                        addr_offset_o = {{20{inst_i[31]}}, inst_i[31:20]} ;

                    end

                    default: begin
                        illegal_inst = 1'b1;

                    end

                endcase
            end

            // S-tpye
            `INST_TYPE_S: begin
                case (funct3)
                    `INST_SB, `INST_SH, `INST_SW: begin
                        rs1_addr_o          = rs1                       ;
                        rs2_addr_o          = rs2                       ;

                        op1_o               = `ZeroWord                 ;
                        op2_o               = rs2_data_i                ;
                        rd_addr_o           = `ZeroReg                  ;   
                        reg_w_en_o          = `WriteDisable             ;
                        base_addr_o         = rs1_data_i                ;
                        addr_offset_o       = {{20{inst_i[31]}}, inst_i[31:25], inst_i[11:7]}  ;

                    end

                    default: begin
                        illegal_inst = 1'b1;

                    end

                endcase
            end
            
            // J-type jump
            `INST_JAL: begin
                rs1_addr_o      = `ZeroReg                  ;
                rs2_addr_o      = `ZeroReg                  ;

                op1_o           = `ZeroWord                 ;
                op2_o           = `ZeroWord                 ;
                rd_addr_o       = rd                        ; 
                reg_w_en_o      = `WriteEnable              ;
                base_addr_o     = inst_addr_i               ;
                addr_offset_o   = {{11{inst_i[31]}}, inst_i[31], inst_i[19:12], inst_i[20], inst_i[30:21], 1'b0}  ;
            end  

            // I-type jump
            `INST_JALR: begin
                if (funct3 == 3'b000) begin
                    rs1_addr_o      = rs1                       ;
                    rs2_addr_o      = `ZeroReg                  ;

                    op1_o           = `ZeroWord                 ;
                    op2_o           = `ZeroWord                 ;
                    rd_addr_o       = rd                        ;
                    reg_w_en_o      = `WriteEnable              ;
                    base_addr_o     = rs1_data_i                ;
                    addr_offset_o   = {{20{inst_i[31]}}, inst_i[31:20]}  ;
                end else begin
                    illegal_inst = 1'b1;
                end
            end   

            // U-type
            `INST_LUI: begin
                rs1_addr_o  = `ZeroReg               ;
                rs2_addr_o  = `ZeroReg               ;

                op1_o       = {inst_i[31:12], 12'b0} ;
                op2_o       = `ZeroWord              ;
                rd_addr_o   = rd                     ;
                reg_w_en_o  = `WriteEnable           ;                                                    
            end   

            `INST_AUIPC: begin
                rs1_addr_o  = `ZeroReg               ;
                rs2_addr_o  = `ZeroReg               ;

                op1_o       = inst_addr_i            ;
                op2_o       = {inst_i[31:12], 12'b0} ;
                rd_addr_o   = rd                     ;
                reg_w_en_o  = `WriteEnable           ;                                                    
            end   

            `INST_FENCE: begin
            end

            `INST_CSR: begin
                case(funct3)
                    3'b000: begin
                        if (inst_i == `INST_ECALL) begin
                            trap_en_o    = `WriteEnable;
                            trap_cause_o = `TRAP_CAUSE_ECALL_M;
                            trap_tval_o  = `ZeroWord;
                        end else if (inst_i == `INST_EBREAK) begin
                            trap_en_o    = `WriteEnable;
                            trap_cause_o = `TRAP_CAUSE_BREAKPOINT;
                            trap_tval_o  = inst_i;
                        end else if (inst_i == `INST_MRET) begin
                            mret_en_o = `WriteEnable;
                        end else begin
                            illegal_inst = 1'b1;
                        end
                    end

                    `INST_CSRRW, `INST_CSRRS, `INST_CSRRC: begin
                        if (csr_illegal) begin
                            illegal_inst = 1'b1;
                        end else begin
                            rs1_addr_o = rs1;
                            rs2_addr_o = `ZeroReg;

                            op1_o      = rs1_data_i;
                            op2_o      = `ZeroWord;
                            rd_addr_o  = rd;
                            reg_w_en_o = `WriteEnable;
                            csr_addr_o = csr_addr;
                            csr_op_o   = funct3;

                            if ((funct3 == `INST_CSRRW) || (rs1 != `ZeroReg))
                                csr_w_en_o = `WriteEnable;
                        end
                    end

                    `INST_CSRRWI, `INST_CSRRSI, `INST_CSRRCI: begin
                        if (csr_illegal) begin
                            illegal_inst = 1'b1;
                        end else begin
                            rs1_addr_o = `ZeroReg;
                            rs2_addr_o = `ZeroReg;

                            op1_o      = {27'b0, rs1};
                            op2_o      = `ZeroWord;
                            rd_addr_o  = rd;
                            reg_w_en_o = `WriteEnable;
                            csr_addr_o = csr_addr;
                            csr_op_o   = funct3;

                            if ((funct3 == `INST_CSRRWI) || (rs1 != `ZeroReg))
                                csr_w_en_o = `WriteEnable;
                        end
                    end

                    default: begin
                        illegal_inst = 1'b1;
                    end
                endcase
            end

            default: begin
                illegal_inst = 1'b1;
            end

        endcase

        if (illegal_inst) begin
            rs1_addr_o    = `ZeroReg      ;
            rs2_addr_o    = `ZeroReg      ;
            op1_o         = `ZeroWord     ;
            op2_o         = `ZeroWord     ;
            rd_addr_o     = `ZeroReg      ;
            reg_w_en_o    = `WriteDisable ;
            base_addr_o   = `ZeroAddr     ;
            addr_offset_o = `ZeroWord     ;
            csr_addr_o    = 12'b0         ;
            csr_w_en_o    = `WriteDisable ;
            csr_op_o      = 3'b0          ;
            trap_en_o     = `WriteEnable  ;
            trap_cause_o  = `TRAP_CAUSE_ILLEGAL_INST;
            trap_tval_o   = inst_i        ;
            mret_en_o     = `WriteDisable ;
        end
    end


endmodule
