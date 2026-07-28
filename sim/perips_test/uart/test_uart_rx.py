import os
import subprocess
import sys
import tempfile


def project_root():
    return os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))


def testbench_source():
    return r'''
`timescale 1ns/1ps

module tb_uart_rx;
    reg         clk;
    reg         rst_n;
    reg         w_en;
    reg  [3:0]  w_sel;
    reg  [31:0] w_addr;
    reg  [31:0] w_data;
    reg  [31:0] r_addr;
    reg         rx_pin;
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
        .rx_pin_i   (rx_pin)
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

    task drive_bit;
        input value;
        begin
            rx_pin = value;
            repeat (2) @(posedge clk);
        end
    endtask

    task drive_byte;
        input [7:0] value;
        integer i;
        begin
            drive_bit(1'b0);
            for (i = 0; i < 8; i = i + 1) begin
                drive_bit(value[i]);
            end
            drive_bit(1'b1);
            repeat (4) @(posedge clk);
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
        rx_pin = 1'b1;
        errors = 0;

        repeat (3) @(posedge clk);
        rst_n = 1'b1;
        @(posedge clk);

        uart_write(32'h0000_0008, 32'h0000_0001, 4'b1111);
        uart_write(32'h0000_0000, 32'h0000_0002, 4'b1111);

        drive_byte(8'h5a);

        r_addr = 32'h0000_0004;
        #1;
        check(r_data[1] == 1'b1, "rx done should set after receive");

        r_addr = 32'h0000_0010;
        #1;
        check(r_data[7:0] == 8'h5a, "rx data should match received byte");

        uart_write(32'h0000_0004, 32'h0000_0002, 4'b1111);
        r_addr = 32'h0000_0004;
        #1;
        check(r_data[1] == 1'b0, "rx done should clear by status write");

        drive_byte(8'ha5);

        r_addr = 32'h0000_0010;
        #1;
        check(r_data[7:0] == 8'ha5, "rx data should update after clear");

        if (errors == 0) begin
            $display("UART RX PASS");
        end else begin
            $display("UART RX FAIL: %0d errors", errors);
        end

        $finish;
    end
endmodule
'''


def main():
    root = project_root()

    with tempfile.TemporaryDirectory() as tmpdir:
        tb_path = os.path.join(tmpdir, "tb_uart_rx.v")
        out_path = os.path.join(tmpdir, "uart_rx.vvp")

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
        if "UART RX PASS" not in sim_result.stdout:
            return 1
        if "FAIL" in sim_result.stdout:
            return 1
        return 0


if __name__ == "__main__":
    sys.exit(main())
