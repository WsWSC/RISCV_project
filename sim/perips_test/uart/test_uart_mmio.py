import os
import subprocess
import sys
import tempfile


def project_root():
    return os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))


def encode_i(imm, rs1, funct3, rd, opcode):
    return ((imm & 0xfff) << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode


def encode_s(imm, rs2, rs1, funct3):
    imm &= 0xfff
    imm_11_5 = (imm >> 5) & 0x7f
    imm_4_0 = imm & 0x1f
    return (imm_11_5 << 25) | (rs2 << 20) | (rs1 << 15) | \
           (funct3 << 12) | (imm_4_0 << 7) | 0x23


def encode_b(imm, rs2, rs1, funct3):
    imm &= 0x1fff
    imm_12 = (imm >> 12) & 0x1
    imm_10_5 = (imm >> 5) & 0x3f
    imm_4_1 = (imm >> 1) & 0xf
    imm_11 = (imm >> 11) & 0x1
    return (imm_12 << 31) | (imm_10_5 << 25) | (rs2 << 20) | \
           (rs1 << 15) | (funct3 << 12) | (imm_4_1 << 8) | \
           (imm_11 << 7) | 0x63


def encode_jal(rd, imm):
    imm &= 0x1fffff
    imm_20 = (imm >> 20) & 0x1
    imm_10_1 = (imm >> 1) & 0x3ff
    imm_11 = (imm >> 11) & 0x1
    imm_19_12 = (imm >> 12) & 0xff
    return (imm_20 << 31) | (imm_10_1 << 21) | (imm_11 << 20) | \
           (imm_19_12 << 12) | (rd << 7) | 0x6f


def addi(rd, rs1, imm):
    return encode_i(imm, rs1, 0x0, rd, 0x13)


def andi(rd, rs1, imm):
    return encode_i(imm, rs1, 0x7, rd, 0x13)


def lw(rd, imm, rs1):
    return encode_i(imm, rs1, 0x2, rd, 0x03)


def sw(rs2, imm, rs1):
    return encode_s(imm, rs2, rs1, 0x2)


def lui(rd, imm20):
    return (imm20 << 12) | (rd << 7) | 0x37


def nop():
    return addi(0, 0, 0)


def emit_nops(program, count):
    for _ in range(count):
        program.emit(nop())


class Program:
    def __init__(self):
        self.items = []
        self.labels = {}

    def label(self, name):
        self.labels[name] = len(self.items) * 4

    def emit(self, word):
        self.items.append(word)

    def branch(self, name, op, rs1, rs2):
        self.items.append(("branch", name, op, rs1, rs2))

    def jal(self, name):
        self.items.append(("jal", name))

    def build(self):
        words = []
        for index, item in enumerate(self.items):
            pc = index * 4
            if isinstance(item, tuple) and item[0] == "branch":
                _, name, op, rs1, rs2 = item
                offset = self.labels[name] - pc
                funct3 = 0x0 if op == "beq" else 0x1
                words.append(encode_b(offset, rs2, rs1, funct3))
            elif isinstance(item, tuple) and item[0] == "jal":
                _, name = item
                offset = self.labels[name] - pc
                words.append(encode_jal(0, offset))
            else:
                words.append(item)
        return words


def check_eq(program, rd, rs):
    emit_nops(program, 4)
    program.branch("fail", "bne", rd, rs)


def check_zero(program, rd):
    emit_nops(program, 4)
    program.branch("fail", "bne", rd, 0)


def check_nonzero(program, rd):
    emit_nops(program, 4)
    program.branch("fail", "beq", rd, 0)


def wait_tx_idle(program, label):
    program.label(label)
    program.emit(lw(5, 4, 1))
    emit_nops(program, 4)
    program.emit(andi(5, 5, 1))
    emit_nops(program, 4)
    program.branch(label, "bne", 5, 0)


def uart_mmio_program():
    program = Program()

    # x1 = 0x3000_0000 uart base
    program.emit(lui(1, 0x30000))

    # UART_BAUD = 1, then read back.
    program.emit(addi(2, 0, 1))
    program.emit(sw(2, 8, 1))
    program.emit(lw(3, 8, 1))
    check_eq(program, 3, 2)

    # UART_CTRL[0] = tx enable, then read back.
    program.emit(sw(2, 0, 1))
    program.emit(lw(3, 0, 1))
    emit_nops(program, 4)
    program.emit(andi(3, 3, 1))
    check_eq(program, 3, 2)

    # UART_TXDATA = 'H'. TX busy should set.
    program.emit(addi(4, 0, 72))
    program.emit(sw(4, 12, 1))
    emit_nops(program, 2)
    program.emit(lw(5, 4, 1))
    emit_nops(program, 4)
    program.emit(andi(5, 5, 1))
    check_nonzero(program, 5)

    # Writing TXDATA while busy must not replace the active byte.
    program.emit(addi(4, 0, 88))
    program.emit(sw(4, 12, 1))

    emit_nops(program, 40)

    wait_tx_idle(program, "wait_h_done")

    # Send more bytes after idle.
    program.emit(addi(4, 0, 73))
    program.emit(sw(4, 12, 1))

    wait_tx_idle(program, "wait_i_done")

    program.emit(addi(4, 0, 33))
    program.emit(sw(4, 12, 1))

    wait_tx_idle(program, "wait_bang_done")

    # Out-of-range UART offset should read zero.
    program.emit(lw(6, 32, 1))
    check_zero(program, 6)

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


def write_inst_file(words, path):
    with open(path, "w") as file_obj:
        for word in words:
            file_obj.write("{:08x}\n".format(word))


def testbench_source(inst_path):
    inst_path = inst_path.replace("\\", "/")
    return r'''
`timescale 1ns/1ps
`include "defines.v"

module tb_uart_mmio;
    reg clk;
    reg rst_n;
    reg external_irq;
    reg uart_rx;
    wire uart_tx;

    integer cycle_count;
    integer char_count;
    integer errors;
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
            $display("UART_MMIO_TX_CHAR: 0x%02h", value);
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
        errors = 0;
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

            if (cycle_count > 1000) begin
                $display("UART MMIO FAIL: timeout");
                $finish;
            end

            if (soc_inst.core_inst.regs_inst.regs[26] == 32'h1) begin
                if (soc_inst.core_inst.regs_inst.regs[27] == 32'h1 &&
                    char_count == 3 &&
                    tx_chars[0] == 8'h48 &&
                    tx_chars[1] == 8'h49 &&
                    tx_chars[2] == 8'h21) begin
                    $display("UART MMIO PASS");
                end else begin
                    $display("UART MMIO FAIL: x27=%h chars=%0d data=%02h_%02h_%02h",
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


def compile_cmd(root, out_path, tb_path):
    return [
        "iverilog", "-g2012",
        "-o", out_path,
        "-I", os.path.join(root, "rtl"),
        "-I", os.path.join(root, "rtl", "utils"),
        "-I", os.path.join(root, "rtl", "core"),
        "-I", os.path.join(root, "rtl", "perips"),
        "-I", os.path.join(root, "rtl", "soc"),
        os.path.join(root, "rtl", "utils", "defines.v"),
        os.path.join(root, "rtl", "utils", "gen_dff.v"),
        os.path.join(root, "rtl", "core", "core.v"),
        os.path.join(root, "rtl", "core", "pc_reg.v"),
        os.path.join(root, "rtl", "core", "regs.v"),
        os.path.join(root, "rtl", "core", "if_id.v"),
        os.path.join(root, "rtl", "core", "id.v"),
        os.path.join(root, "rtl", "core", "id_ex.v"),
        os.path.join(root, "rtl", "core", "ex.v"),
        os.path.join(root, "rtl", "core", "mul.v"),
        os.path.join(root, "rtl", "core", "div.v"),
        os.path.join(root, "rtl", "core", "csr_reg.v"),
        os.path.join(root, "rtl", "core", "clint.v"),
        os.path.join(root, "rtl", "core", "ctrl.v"),
        os.path.join(root, "rtl", "core", "rib.v"),
        os.path.join(root, "rtl", "perips", "inst_rom.v"),
        os.path.join(root, "rtl", "perips", "data_ram.v"),
        os.path.join(root, "rtl", "perips", "timer.v"),
        os.path.join(root, "rtl", "perips", "uart.v"),
        os.path.join(root, "rtl", "soc", "soc.v"),
        tb_path,
    ]


def main():
    root = project_root()

    with tempfile.TemporaryDirectory() as tmpdir:
        inst_path = os.path.join(tmpdir, "uart_mmio_inst.txt")
        tb_path = os.path.join(tmpdir, "tb_uart_mmio.v")
        out_path = os.path.join(tmpdir, "uart_mmio.vvp")

        write_inst_file(uart_mmio_program(), inst_path)

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
        if "UART MMIO PASS" not in sim_result.stdout:
            return 1
        if "FAIL" in sim_result.stdout:
            return 1
        return 0


if __name__ == "__main__":
    sys.exit(main())
