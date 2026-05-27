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

endmodule
