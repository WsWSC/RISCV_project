import os
import subprocess
import sys
import tempfile

sys.path.insert(0, os.path.dirname(__file__))

from test_uart_mmio import Program
from test_uart_mmio import addi
from test_uart_mmio import andi
from test_uart_mmio import compile_cmd
from test_uart_mmio import emit_nops
from test_uart_mmio import lui
from test_uart_mmio import lw
from test_uart_mmio import project_root
from test_uart_mmio import sw
from test_uart_mmio import write_inst_file


def putchar(program, value, index):
    wait_label = "wait_tx_{0}".format(index)

    program.label(wait_label)
    program.emit(lw(3, 4, 1))       # UART_STATUS
    emit_nops(program, 4)
    program.emit(andi(3, 3, 1))     # tx busy
    emit_nops(program, 4)
    program.branch(wait_label, "bne", 3, 0)

    program.emit(addi(4, 0, value))
    program.emit(sw(4, 12, 1))      # UART_TXDATA
    emit_nops(program, 2)


def wait_tx_idle(program, label):
    program.label(label)
    program.emit(lw(3, 4, 1))       # UART_STATUS
    emit_nops(program, 4)
    program.emit(andi(3, 3, 1))     # tx busy
    emit_nops(program, 4)
    program.branch(label, "bne", 3, 0)


def uart_tx_polling_program():
    program = Program()

    # x1 = 0x3000_0000 uart base
    program.emit(lui(1, 0x30000))

    # UART_BAUD = 1
    program.emit(addi(2, 0, 1))
    program.emit(sw(2, 8, 1))

    # UART_CTRL[0] = tx enable
    program.emit(sw(2, 0, 1))
    emit_nops(program, 4)

    for index, value in enumerate(b"OK\n"):
        putchar(program, value, index)

    wait_tx_idle(program, "wait_tx_done")

    program.label("pass")
    program.emit(addi(27, 0, 1))
    program.emit(addi(26, 0, 1))
    program.label("done")
    program.jal("done")

    return program.build()


def testbench_source(inst_path):
    inst_path = inst_path.replace("\\", "/")
    return r'''
`timescale 1ns/1ps
`include "defines.v"

module tb_uart_tx_polling;
    reg clk;
    reg rst_n;
    reg external_irq;
    reg uart_rx;
    wire uart_tx;

    integer cycle_count;
    integer char_count;
    reg [7:0] tx_chars [0:2];

    soc soc_inst(
        .clk            (clk),
        .rst_n          (rst_n),
        .external_irq_i (external_irq),
        .uart_rx_i      (uart_rx),
        .uart_tx_o      (uart_tx)
    );

    always #10 clk = ~clk;

    task sample_uart_char;
        integer i;
        reg [7:0] value;
        begin
            value = 8'h00;
            repeat (3) @(posedge clk);

            for (i = 0; i < 8; i = i + 1) begin
                value[i] = uart_tx;
                repeat (2) @(posedge clk);
            end

            if (char_count < 3) begin
                tx_chars[char_count] = value;
            end

            char_count = char_count + 1;
            $display("UART_TX_POLLING_CHAR: 0x%02h", value);
            repeat (2) @(posedge clk);
        end
    endtask

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        external_irq = 1'b0;
        uart_rx = 1'b1;
        cycle_count = 0;
        char_count = 0;
        tx_chars[0] = 8'h00;
        tx_chars[1] = 8'h00;
        tx_chars[2] = 8'h00;

        $readmemh("''' + inst_path + r'''", soc_inst.inst_rom_inst.rom_mem);

        repeat (3) @(posedge clk);
        rst_n = 1'b1;
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            cycle_count <= 0;
        end else begin
            cycle_count <= cycle_count + 1;

            if (cycle_count > 1500) begin
                $display("UART TX POLLING FAIL: timeout");
                $finish;
            end

            if (soc_inst.core_inst.regs_inst.regs[26] == 32'h1) begin
                if (soc_inst.core_inst.regs_inst.regs[27] == 32'h1 &&
                    char_count == 3 &&
                    tx_chars[0] == 8'h4f &&
                    tx_chars[1] == 8'h4b &&
                    tx_chars[2] == 8'h0a) begin
                    $display("UART TX POLLING PASS");
                end else begin
                    $display("UART TX POLLING FAIL: x27=%h chars=%0d data=%02h_%02h_%02h",
                             soc_inst.core_inst.regs_inst.regs[27],
                             char_count,
                             tx_chars[0],
                             tx_chars[1],
                             tx_chars[2]);
                end
                $finish;
            end
        end
    end

    always @(negedge uart_tx) begin
        if (rst_n) begin
            sample_uart_char();
        end
    end
endmodule
'''


def main():
    root = project_root()

    with tempfile.TemporaryDirectory() as tmpdir:
        inst_path = os.path.join(tmpdir, "uart_tx_polling_inst.txt")
        tb_path = os.path.join(tmpdir, "tb_uart_tx_polling.v")
        out_path = os.path.join(tmpdir, "uart_tx_polling.vvp")

        write_inst_file(uart_tx_polling_program(), inst_path)

        with open(tb_path, "w") as file_obj:
            file_obj.write(testbench_source(inst_path))

        compile_result = subprocess.run(
            compile_cmd(root, out_path, tb_path),
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
        if "UART TX POLLING PASS" not in sim_result.stdout:
            return 1
        if "FAIL" in sim_result.stdout:
            return 1
        return 0


if __name__ == "__main__":
    sys.exit(main())
