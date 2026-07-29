import os
import subprocess
import sys
import tempfile


def project_root():
    return os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))


def testbench_source():
    return r'''
`timescale 1ns/1ps
`include "defines.v"

module tb_rib_uart_route;
    reg         clk;
    reg         rst_n;

    reg  [31:0] m0_if_r_addr;
    wire [31:0] m0_if_r_data;
    wire        m0_if_stall;

    reg         m1_mem_r_en;
    reg  [31:0] m1_mem_r_addr;
    wire [31:0] m1_mem_r_data;

    reg         m1_mem_w_en;
    reg  [3:0]  m1_mem_w_sel;
    reg  [31:0] m1_mem_w_addr;
    reg  [31:0] m1_mem_w_data;

    wire        s1_ram_w_en;
    wire [3:0]  s1_ram_w_sel;
    wire [31:0] s1_ram_w_addr;
    wire [31:0] s1_ram_w_data;
    wire [31:0] s1_ram_r_addr;
    reg  [31:0] s1_ram_r_data;

    wire        s2_timer_w_en;
    wire [3:0]  s2_timer_w_sel;
    wire [31:0] s2_timer_w_addr;
    wire [31:0] s2_timer_w_data;
    wire [31:0] s2_timer_r_addr;
    reg  [31:0] s2_timer_r_data;

    wire        s3_uart_w_en;
    wire [3:0]  s3_uart_w_sel;
    wire [31:0] s3_uart_w_addr;
    wire [31:0] s3_uart_w_data;
    wire [31:0] s3_uart_r_addr;
    reg  [31:0] s3_uart_r_data;

    wire [31:0] s0_rom_r_addr;
    reg  [31:0] s0_rom_r_data;

    integer errors;

    rib dut (
        .clk                (clk),
        .rst_n              (rst_n),

        .m0_if_r_addr_i     (m0_if_r_addr),
        .m0_if_r_data_o     (m0_if_r_data),
        .m0_if_stall_o      (m0_if_stall),

        .m1_mem_r_en_i      (m1_mem_r_en),
        .m1_mem_r_addr_i    (m1_mem_r_addr),
        .m1_mem_r_data_o    (m1_mem_r_data),

        .m1_mem_w_en_i      (m1_mem_w_en),
        .m1_mem_w_sel_i     (m1_mem_w_sel),
        .m1_mem_w_addr_i    (m1_mem_w_addr),
        .m1_mem_w_data_i    (m1_mem_w_data),

        .s1_ram_w_en_o      (s1_ram_w_en),
        .s1_ram_w_sel_o     (s1_ram_w_sel),
        .s1_ram_w_addr_o    (s1_ram_w_addr),
        .s1_ram_w_data_o    (s1_ram_w_data),
        .s1_ram_r_addr_o    (s1_ram_r_addr),
        .s1_ram_r_data_i    (s1_ram_r_data),

        .s2_timer_w_en_o    (s2_timer_w_en),
        .s2_timer_w_sel_o   (s2_timer_w_sel),
        .s2_timer_w_addr_o  (s2_timer_w_addr),
        .s2_timer_w_data_o  (s2_timer_w_data),
        .s2_timer_r_addr_o  (s2_timer_r_addr),
        .s2_timer_r_data_i  (s2_timer_r_data),

        .s3_uart_w_en_o     (s3_uart_w_en),
        .s3_uart_w_sel_o    (s3_uart_w_sel),
        .s3_uart_w_addr_o   (s3_uart_w_addr),
        .s3_uart_w_data_o   (s3_uart_w_data),
        .s3_uart_r_addr_o   (s3_uart_r_addr),
        .s3_uart_r_data_i   (s3_uart_r_data),

        .s0_rom_r_addr_o    (s0_rom_r_addr),
        .s0_rom_r_data_i    (s0_rom_r_data)
    );

    always #5 clk = ~clk;

    task check;
        input condition;
        input [8*100-1:0] message;
        begin
            if (!condition) begin
                $display("FAIL: %0s", message);
                errors = errors + 1;
            end
        end
    endtask

    task clear_mem_req;
        begin
            m1_mem_r_en   = `ReadDisable;
            m1_mem_r_addr = `ZeroAddr;
            m1_mem_w_en   = `WriteDisable;
            m1_mem_w_sel  = 4'b0;
            m1_mem_w_addr = `ZeroAddr;
            m1_mem_w_data = `ZeroWord;
        end
    endtask

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        m0_if_r_addr = 32'h0000_0040;
        s0_rom_r_data = 32'h1234_5678;
        s1_ram_r_data = 32'haaaa_0001;
        s2_timer_r_data = 32'hbbbb_0002;
        s3_uart_r_data = 32'hcccc_0003;
        clear_mem_req();
        errors = 0;

        repeat (2) @(posedge clk);
        rst_n = 1'b1;
        #1;

        check(m0_if_stall == `StallDisable, "IF should run when MEM has no request");
        check(s0_rom_r_addr == 32'h0000_0040, "IF should route to inst_rom");
        check(m0_if_r_data == 32'h1234_5678, "IF data should come from inst_rom");

        m1_mem_w_en   = `WriteEnable;
        m1_mem_w_sel  = 4'b1111;
        m1_mem_w_addr = 32'h3000_000c;
        m1_mem_w_data = 32'h0000_0048;
        #1;

        check(m0_if_stall == `StallEnable, "IF should stall while MEM owns RIB");
        check(s3_uart_w_en == `WriteEnable, "UART write enable should assert");
        check(s3_uart_w_sel == 4'b1111, "UART write select should route");
        check(s3_uart_w_addr == 32'h3000_000c, "UART write address should route");
        check(s3_uart_w_data == 32'h0000_0048, "UART write data should route");
        check(s1_ram_w_en == `WriteDisable, "RAM should not receive UART write");
        check(s2_timer_w_en == `WriteDisable, "timer should not receive UART write");

        clear_mem_req();
        m1_mem_r_en   = `ReadEnable;
        m1_mem_r_addr = 32'h3000_0010;
        #1;

        check(s3_uart_r_addr == 32'h3000_0010, "UART read address should route");
        check(m1_mem_r_data == 32'hcccc_0003, "MEM read data should come from UART");
        check(s1_ram_r_addr == `ZeroAddr, "RAM read address should stay zero");
        check(s2_timer_r_addr == `ZeroAddr, "timer read address should stay zero");

        clear_mem_req();
        m1_mem_r_en   = `ReadEnable;
        m1_mem_r_addr = 32'h6000_0000;
        #1;

        check(m1_mem_r_data == `ZeroWord, "out-of-range read should return zero");
        check(s3_uart_r_addr == `ZeroAddr, "UART should ignore out-of-range read");

        if (errors == 0) begin
            $display("RIB UART ROUTE PASS");
        end else begin
            $display("RIB UART ROUTE FAIL: %0d errors", errors);
        end

        $finish;
    end
endmodule
'''


def main():
    root = project_root()

    with tempfile.TemporaryDirectory() as tmpdir:
        tb_path = os.path.join(tmpdir, "tb_rib_uart_route.v")
        out_path = os.path.join(tmpdir, "rib_uart_route.vvp")

        with open(tb_path, "w") as file_obj:
            file_obj.write(testbench_source())

        compile_cmd = [
            "iverilog",
            "-g2012",
            "-o",
            out_path,
            "-I",
            os.path.join(root, "rtl"),
            "-I",
            os.path.join(root, "rtl", "utils"),
            "-I",
            os.path.join(root, "rtl", "core"),
            os.path.join(root, "rtl", "utils", "defines.v"),
            os.path.join(root, "rtl", "core", "rib.v"),
            tb_path,
        ]

        compile_result = subprocess.run(
            compile_cmd,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            timeout=30,
        )
        if compile_result.returncode != 0:
            print(compile_result.stdout.rstrip())
            return compile_result.returncode

        sim_result = subprocess.run(
            ["vvp", out_path],
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            timeout=30,
        )

        print(sim_result.stdout.rstrip())

        if sim_result.returncode != 0:
            return sim_result.returncode
        if "RIB UART ROUTE PASS" not in sim_result.stdout:
            return 1
        if "FAIL" in sim_result.stdout:
            return 1
        return 0


if __name__ == "__main__":
    sys.exit(main())
