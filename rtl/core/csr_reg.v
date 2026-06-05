////////////////////////////////////////////////////////////
//  RISC-V CPU Side Project
//  Author  : WsWSC
//  Created : 2026
//  License : Personal / Educational Use
////////////////////////////////////////////////////////////

`include "defines.v"

module csr_reg(
    input  wire         clk                 ,
    input  wire         rst_n               ,

    // CSR read port
    input  wire[11:0]   csr_r_addr_i        ,
    output reg [31:0]   csr_r_data_o        ,

    // CSR write port
    input  wire         csr_w_en_i          ,
    input  wire[11:0]   csr_w_addr_i        ,
    input  wire[31:0]   csr_w_data_i        ,

    // trap write port
    input  wire         trap_w_en_i         ,
    input  wire[31:0]   trap_mepc_i         ,
    input  wire[31:0]   trap_mcause_i       ,
    input  wire[31:0]   trap_mtval_i        ,
    input  wire[31:0]   trap_mstatus_i      ,

    // interrupt pending set
    input  wire         external_irq_i       ,

    // CSR direct outputs
    output wire[31:0]   mtvec_o             ,
    output wire[31:0]   mepc_o              ,
    output wire[31:0]   mcause_o            ,
    output wire[31:0]   mtval_o             ,
    output wire[31:0]   mstatus_o           ,
    output wire[31:0]   mie_o               ,
    output wire[31:0]   mip_o
);

    // ============================================================
    //  CSR Register Declarations
    // ============================================================
    reg[31:0]   mtvec                       ;
    reg[31:0]   mepc                        ;
    reg[31:0]   mcause                      ;
    reg[31:0]   mtval                       ;
    reg[31:0]   mstatus                     ;
    reg[31:0]   mie                         ;
    reg[31:0]   mip                         ;

    // ============================================================
    //  CSR Write
    // ============================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mtvec   <= `ZeroWord;
            mepc    <= `ZeroWord;
            mcause  <= `ZeroWord;
            mtval   <= `ZeroWord;
            mstatus <= `ZeroWord;
            mie     <= `ZeroWord;
            mip     <= `ZeroWord;
        end else begin
            if (trap_w_en_i == `WriteEnable) begin
                mepc    <= trap_mepc_i;
                mcause  <= trap_mcause_i;
                mtval   <= trap_mtval_i;
                mstatus <= trap_mstatus_i & `CSR_MSTATUS_MASK;
            end else if (csr_w_en_i == `WriteEnable) begin
                case (csr_w_addr_i)
                    `CSR_MTVEC  : mtvec   <= csr_w_data_i;
                    `CSR_MEPC   : mepc    <= csr_w_data_i;
                    `CSR_MCAUSE : mcause  <= csr_w_data_i;
                    `CSR_MTVAL  : mtval   <= csr_w_data_i;
                    `CSR_MSTATUS: mstatus <= csr_w_data_i & `CSR_MSTATUS_MASK;
                    `CSR_MIE    : mie     <= csr_w_data_i & `CSR_MIE_MEIE;
                    `CSR_MIP    : begin
                        if (external_irq_i == `WriteEnable)
                            mip <= (csr_w_data_i & `CSR_MIP_MEIP) | `CSR_MIP_MEIP;
                        else
                            mip <= csr_w_data_i & `CSR_MIP_MEIP;
                    end
                    default     : begin
                    end
                endcase
            end

            if ((external_irq_i == `WriteEnable) &&
                !((csr_w_en_i == `WriteEnable) && (csr_w_addr_i == `CSR_MIP))) begin
                mip <= mip | `CSR_MIP_MEIP;
            end
        end
    end

    // ============================================================
    //  CSR Read
    // ============================================================
    always @(*) begin
        case (csr_r_addr_i)
            `CSR_MTVEC  : csr_r_data_o = mtvec;
            `CSR_MEPC   : csr_r_data_o = mepc;
            `CSR_MCAUSE : csr_r_data_o = mcause;
            `CSR_MTVAL  : csr_r_data_o = mtval;
            `CSR_MSTATUS: csr_r_data_o = mstatus;
            `CSR_MIE    : csr_r_data_o = mie;
            `CSR_MIP    : csr_r_data_o = mip;
            default     : csr_r_data_o = `ZeroWord;
        endcase
    end

    assign mtvec_o   = mtvec;
    assign mepc_o    = mepc;
    assign mcause_o  = mcause;
    assign mtval_o   = mtval;
    assign mstatus_o = mstatus;
    assign mie_o     = mie;
    assign mip_o     = mip;

endmodule
