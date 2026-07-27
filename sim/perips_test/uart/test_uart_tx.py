import os
import subprocess
import sys
import tempfile


def project_root():
    return os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))


def testbench_source():
    return r'''
`timescale 1ns/1ps

module tb_uart_tx;
    reg         clk;
    reg         rst_n;
    reg         w_en;
    reg  [3:0]  w_sel;
    reg  [31:0] w_addr;
    reg  [31:0] w_data;
    reg  [31:0] r_addr;
    wire [31:0] r_data;
    wire        tx_pin;

    integer errors;

    uart dut (
        .clk        (clk),
        .rst_n      (rst_n),
        .w_en_i     (w_en),
        .w_sel_i    (w_sel),
        .w_addr_i   (w_addr),
        .w_data_i   (w_data),
        .r_addr_i   (r_addr),
        .r_data_o   (r_data),
        .tx_pin_o   (tx_pin),
        .rx_pin_i   (1'b1)
    );

    always #5 clk = ~clk;

    task check;
        input condition;
        input [8*80-1:0] message;
        begin
            if (!condition) begin
                $display("FAIL: %0s", message);
                errors = errors + 1;
            end
        end
    endtask

    task uart_write;
        input [31:0] addr;
        input [31:0] data;
        input [3:0]  sel;
        begin
            @(negedge clk);
            w_en  = 1'b1;
            w_sel = sel;
            w_addr = addr;
            w_data = data;
            @(negedge clk);
            w_en  = 1'b0;
            w_sel = 4'b0;
            w_addr = 32'b0;
            w_data = 32'b0;
        end
    endtask

    task wait_bit_time;
        begin
            repeat (2) @(posedge clk);
            #1;
        end
    endtask

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        w_en = 1'b0;
        w_sel = 4'b0;
        w_addr = 32'b0;
        w_data = 32'b0;
        r_addr = 32'b0;
        errors = 0;

        repeat (3) @(posedge clk);
        rst_n = 1'b1;
        @(posedge clk);
        #1;

        check(tx_pin == 1'b1, "tx pin should idle high after reset");

        r_addr = 32'h0000_0008;
        #1;
        check(r_data == 32'h0000_01b8, "default baud should be 0x1b8");

        uart_write(32'h0000_0008, 32'h0000_0001, 4'b1111);
        uart_write(32'h0000_0000, 32'h0000_0001, 4'b1111);
        uart_write(32'h0000_000c, 32'h0000_00a5, 4'b0001);

        r_addr = 32'h0000_0004;
        #1;
        check(r_data[0] == 1'b1, "tx busy should set after txdata write");

        @(posedge clk);
        #1;
        check(tx_pin == 1'b0, "start bit should be low");

        wait_bit_time();
        check(tx_pin == 1'b1, "data bit 0 should be 1");
        wait_bit_time();
        check(tx_pin == 1'b0, "data bit 1 should be 0");
        wait_bit_time();
        check(tx_pin == 1'b1, "data bit 2 should be 1");
        wait_bit_time();
        check(tx_pin == 1'b0, "data bit 3 should be 0");
        wait_bit_time();
        check(tx_pin == 1'b0, "data bit 4 should be 0");
        wait_bit_time();
        check(tx_pin == 1'b1, "data bit 5 should be 1");
        wait_bit_time();
        check(tx_pin == 1'b0, "data bit 6 should be 0");
        wait_bit_time();
        check(tx_pin == 1'b1, "data bit 7 should be 1");
        wait_bit_time();
        check(tx_pin == 1'b1, "stop bit should be high");

        wait_bit_time();
        @(posedge clk);
        #1;
        r_addr = 32'h0000_0004;
        #1;
        check(r_data[0] == 1'b0, "tx busy should clear after stop bit");

        uart_write(32'h0000_000c, 32'h0000_0055, 4'b0010);
        repeat (4) @(posedge clk);
        r_addr = 32'h0000_0004;
        #1;
        check(r_data[0] == 1'b0, "txdata should ignore non-low-byte write");

        if (errors == 0) begin
            $display("UART TX PASS");
        end else begin
            $display("UART TX FAIL: %0d errors", errors);
        end

        $finish;
    end
endmodule
'''


def main():
    root = project_root()

    with tempfile.TemporaryDirectory() as tmpdir:
        tb_path = os.path.join(tmpdir, "tb_uart_tx.v")
        out_path = os.path.join(tmpdir, "uart_tx.vvp")

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
            os.path.join(root, "rtl", "perips"),
            os.path.join(root, "rtl", "utils", "defines.v"),
            os.path.join(root, "rtl", "perips", "uart.v"),
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
        if "UART TX PASS" not in sim_result.stdout:
            return 1
        if "FAIL" in sim_result.stdout:
            return 1
        return 0


if __name__ == "__main__":
    sys.exit(main())
