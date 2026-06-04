////////////////////////////////////////////////////////////
//  RISC-V CPU Side Project
//  Author  : WsWSC
//  Created : 2026
//  License : Personal / Educational Use
////////////////////////////////////////////////////////////

`timescale 1ns/1ps
`include "defines.v"

module csr_reg_tb;

    reg         clk;
    reg         rst_n;
    reg [11:0]  csr_r_addr_i;
    wire[31:0]  csr_r_data_o;
    reg         csr_w_en_i;
    reg [11:0]  csr_w_addr_i;
    reg [31:0]  csr_w_data_i;
    reg         trap_w_en_i;
    reg [31:0]  trap_mepc_i;
    reg [31:0]  trap_mcause_i;
    reg [31:0]  trap_mtval_i;
    reg [31:0]  trap_mstatus_i;
    wire[31:0]  mtvec_o;
    wire[31:0]  mepc_o;
    wire[31:0]  mcause_o;
    wire[31:0]  mtval_o;
    wire[31:0]  mstatus_o;
    wire[31:0]  mie_o;
    wire[31:0]  mip_o;

    integer errors;

    always #5 clk = ~clk;

    csr_reg dut(
        .clk           (clk),
        .rst_n         (rst_n),
        .csr_r_addr_i  (csr_r_addr_i),
        .csr_r_data_o  (csr_r_data_o),
        .csr_w_en_i    (csr_w_en_i),
        .csr_w_addr_i  (csr_w_addr_i),
        .csr_w_data_i  (csr_w_data_i),
        .trap_w_en_i   (trap_w_en_i),
        .trap_mepc_i   (trap_mepc_i),
        .trap_mcause_i (trap_mcause_i),
        .trap_mtval_i  (trap_mtval_i),
        .trap_mstatus_i(trap_mstatus_i),
        .mtvec_o       (mtvec_o),
        .mepc_o        (mepc_o),
        .mcause_o      (mcause_o),
        .mtval_o       (mtval_o),
        .mstatus_o     (mstatus_o),
        .mie_o         (mie_o),
        .mip_o         (mip_o)
    );

    task check;
        input[31:0] actual;
        input[31:0] expected;
        begin
            if (actual !== expected) begin
                $display("FAIL actual=%h expected=%h", actual, expected);
                errors = errors + 1;
            end
        end
    endtask

    task write_csr;
        input[11:0] addr;
        input[31:0] data;
        begin
            @(negedge clk);
            csr_w_en_i   = `WriteEnable;
            csr_w_addr_i = addr;
            csr_w_data_i = data;
            @(negedge clk);
            csr_w_en_i   = `WriteDisable;
            csr_w_addr_i = 12'b0;
            csr_w_data_i = `ZeroWord;
        end
    endtask

    initial begin
        clk          = 1'b0;
        rst_n        = 1'b0;
        csr_r_addr_i = 12'b0;
        csr_w_en_i   = `WriteDisable;
        csr_w_addr_i = 12'b0;
        csr_w_data_i = `ZeroWord;
        trap_w_en_i   = `WriteDisable;
        trap_mepc_i   = `ZeroWord;
        trap_mcause_i = `ZeroWord;
        trap_mtval_i  = `ZeroWord;
        trap_mstatus_i = `ZeroWord;
        errors       = 0;

        repeat(2) @(negedge clk);
        rst_n = 1'b1;

        csr_r_addr_i = `CSR_MTVEC;
        #1 check(csr_r_data_o, `ZeroWord);
        check(mtvec_o, `ZeroWord);

        write_csr(`CSR_MTVEC, 32'h0000_0123);
        csr_r_addr_i = `CSR_MTVEC;
        #1 check(csr_r_data_o, 32'h0000_0123);
        check(mtvec_o, 32'h0000_0123);

        write_csr(`CSR_MEPC, 32'h0000_0040);
        csr_r_addr_i = `CSR_MEPC;
        #1 check(csr_r_data_o, 32'h0000_0040);
        check(mepc_o, 32'h0000_0040);

        write_csr(`CSR_MCAUSE, 32'h0000_000b);
        csr_r_addr_i = `CSR_MCAUSE;
        #1 check(csr_r_data_o, 32'h0000_000b);
        check(mcause_o, 32'h0000_000b);

        write_csr(`CSR_MTVAL, 32'hdead_beef);
        csr_r_addr_i = `CSR_MTVAL;
        #1 check(csr_r_data_o, 32'hdead_beef);
        check(mtval_o, 32'hdead_beef);

        write_csr(`CSR_MSTATUS, 32'h0000_0088);
        csr_r_addr_i = `CSR_MSTATUS;
        #1 check(csr_r_data_o, 32'h0000_0088);
        check(mstatus_o, 32'h0000_0088);

        write_csr(`CSR_MIE, 32'h0000_0800);
        csr_r_addr_i = `CSR_MIE;
        #1 check(csr_r_data_o, 32'h0000_0800);
        check(mie_o, 32'h0000_0800);

        write_csr(`CSR_MIP, 32'h0000_0800);
        csr_r_addr_i = `CSR_MIP;
        #1 check(csr_r_data_o, 32'h0000_0800);
        check(mip_o, 32'h0000_0800);

        csr_r_addr_i = 12'hfff;
        #1 check(csr_r_data_o, `ZeroWord);

        @(negedge clk);
        trap_w_en_i    = `WriteEnable;
        trap_mepc_i    = 32'h0000_0100;
        trap_mcause_i  = 32'h0000_000b;
        trap_mtval_i   = 32'h0000_0073;
        trap_mstatus_i = 32'h0000_0080;
        csr_w_en_i     = `WriteEnable;
        csr_w_addr_i   = `CSR_MEPC;
        csr_w_data_i   = 32'hffff_ffff;
        @(negedge clk);
        trap_w_en_i    = `WriteDisable;
        csr_w_en_i     = `WriteDisable;

        csr_r_addr_i = `CSR_MEPC;
        #1 check(csr_r_data_o, 32'h0000_0100);
        check(mepc_o, 32'h0000_0100);
        csr_r_addr_i = `CSR_MCAUSE;
        #1 check(csr_r_data_o, 32'h0000_000b);
        csr_r_addr_i = `CSR_MTVAL;
        #1 check(csr_r_data_o, 32'h0000_0073);
        csr_r_addr_i = `CSR_MSTATUS;
        #1 check(csr_r_data_o, 32'h0000_0080);

        if (errors == 0) begin
            $display("csr_reg_tb PASS");
            $finish;
        end else begin
            $display("csr_reg_tb FAIL errors=%0d", errors);
            $finish;
        end
    end

endmodule
