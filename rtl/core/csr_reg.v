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

    // CSR direct outputs
    output wire[31:0]   mtvec_o             ,
    output wire[31:0]   mepc_o              ,
    output wire[31:0]   mcause_o            ,
    output wire[31:0]   mtval_o             ,
    output wire[31:0]   mstatus_o
);

    // ============================================================
    //  CSR Register Declarations
    // ============================================================
    reg[31:0]   mtvec                       ;
    reg[31:0]   mepc                        ;
    reg[31:0]   mcause                      ;
    reg[31:0]   mtval                       ;
    reg[31:0]   mstatus                     ;

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
        end else if (csr_w_en_i == `WriteEnable) begin
            case (csr_w_addr_i)
                `CSR_MTVEC  : mtvec   <= csr_w_data_i;
                `CSR_MEPC   : mepc    <= csr_w_data_i;
                `CSR_MCAUSE : mcause  <= csr_w_data_i;
                `CSR_MTVAL  : mtval   <= csr_w_data_i;
                `CSR_MSTATUS: mstatus <= csr_w_data_i;
                default     : begin
                end
            endcase
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
            default     : csr_r_data_o = `ZeroWord;
        endcase
    end

    assign mtvec_o   = mtvec;
    assign mepc_o    = mepc;
    assign mcause_o  = mcause;
    assign mtval_o   = mtval;
    assign mstatus_o = mstatus;

endmodule
