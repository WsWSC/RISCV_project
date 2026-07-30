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


def receive_byte(program, wait_label, store_offset):
    # Poll UART_STATUS[1] until rx done.
    program.label(wait_label)
    program.emit(lw(3, 4, 1))
    emit_nops(program, 4)
    program.emit(andi(3, 3, 2))
    emit_nops(program, 4)
    program.branch(wait_label, "beq", 3, 0)

    # Read UART_RXDATA and store it to data_ram.
    program.emit(lw(4, 16, 1))
    emit_nops(program, 4)
    program.emit(sw(4, store_offset, 0))

    # Clear UART_STATUS[1].
    program.emit(addi(2, 0, 2))
    program.emit(sw(2, 4, 1))
    program.emit(lw(5, 4, 1))
    emit_nops(program, 4)
    program.emit(andi(5, 5, 2))
    emit_nops(program, 4)
    program.branch("fail", "bne", 5, 0)


def uart_rx_polling_program():
    program = Program()

    # x1 = 0x3000_0000 uart base
    program.emit(lui(1, 0x30000))

    # UART_BAUD = 1
    program.emit(addi(2, 0, 1))
    program.emit(sw(2, 8, 1))

    # UART_CTRL[1] = rx enable
    program.emit(addi(2, 0, 2))
    program.emit(sw(2, 0, 1))
    emit_nops(program, 4)

    receive_byte(program, "wait_rx_first", 256)
    receive_byte(program, "wait_rx_second", 260)
    receive_byte(program, "wait_rx_third", 264)
    receive_byte(program, "wait_rx_fourth", 268)

    program.label("pass")
    program.emit(addi(27, 0, 1))
    program.emit(addi(26, 0, 1))
    program.label("done")
    program.jal("done")

    program.label("fail")
    program.emit(addi(27, 0, 0))
    program.emit(addi(26, 0, 1))
    program.jal("done")

    return program.build()


def testbench_source(inst_path):
    inst_path = inst_path.replace("\\", "/")
    return r'''
`timescale 1ns/1ps
`include "defines.v"

module tb_uart_rx_polling;
    reg clk;
    reg rst_n;
    reg external_irq;
    reg uart_rx;
    wire uart_tx;

    integer cycle_count;

    soc soc_inst(
        .clk            (clk),
        .rst_n          (rst_n),
        .external_irq_i (external_irq),
        .uart_rx_i      (uart_rx),
        .uart_tx_o      (uart_tx)
    );

    always #10 clk = ~clk;

    task drive_uart_bit;
        input value;
        begin
            uart_rx = value;
            repeat (2) @(posedge clk);
        end
    endtask

    task drive_uart_byte;
        input [7:0] value;
        integer i;
        begin
            drive_uart_bit(1'b0);
            for (i = 0; i < 8; i = i + 1) begin
                drive_uart_bit(value[i]);
            end
            drive_uart_bit(1'b1);
        end
    endtask

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        external_irq = 1'b0;
        uart_rx = 1'b1;
        cycle_count = 0;

        $readmemh("''' + inst_path + r'''", soc_inst.inst_rom_inst.rom_mem);

        repeat (3) @(posedge clk);
        rst_n = 1'b1;

        repeat (60) @(posedge clk);
        drive_uart_byte(8'h5a);
        repeat (80) @(posedge clk);
        drive_uart_byte(8'ha5);
        repeat (80) @(posedge clk);
        drive_uart_byte(8'h3c);
        repeat (80) @(posedge clk);
        drive_uart_byte(8'hc3);
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            cycle_count <= 0;
        end else begin
            cycle_count <= cycle_count + 1;

            if (cycle_count > 1500) begin
                $display("UART RX POLLING FAIL: timeout");
                $finish;
            end

            if (soc_inst.core_inst.regs_inst.regs[26] == 32'h1) begin
                if (soc_inst.core_inst.regs_inst.regs[27] == 32'h1 &&
                    soc_inst.data_ram_inst.ram[64] == 32'h0000_005a &&
                    soc_inst.data_ram_inst.ram[65] == 32'h0000_00a5 &&
                    soc_inst.data_ram_inst.ram[66] == 32'h0000_003c &&
                    soc_inst.data_ram_inst.ram[67] == 32'h0000_00c3) begin
                    $display("UART RX POLLING PASS");
                end else begin
                    $display("UART RX POLLING FAIL: x27=%h ram100=%h ram104=%h ram108=%h ram10c=%h",
                             soc_inst.core_inst.regs_inst.regs[27],
                             soc_inst.data_ram_inst.ram[64],
                             soc_inst.data_ram_inst.ram[65],
                             soc_inst.data_ram_inst.ram[66],
                             soc_inst.data_ram_inst.ram[67]);
                end
                $finish;
            end
        end
    end
endmodule
'''


def main():
    root = project_root()

    with tempfile.TemporaryDirectory() as tmpdir:
        inst_path = os.path.join(tmpdir, "uart_rx_polling_inst.txt")
        tb_path = os.path.join(tmpdir, "tb_uart_rx_polling.v")
        out_path = os.path.join(tmpdir, "uart_rx_polling.vvp")

        write_inst_file(uart_rx_polling_program(), inst_path)

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
        if "UART RX POLLING PASS" not in sim_result.stdout:
            return 1
        if "FAIL" in sim_result.stdout:
            return 1
        return 0


if __name__ == "__main__":
    sys.exit(main())
