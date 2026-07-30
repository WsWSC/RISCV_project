import os
import subprocess
import sys

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..")))

from compile_and_sim import compile
from compile_and_sim import project_root
from compile_and_sim import sim_dir


def encode_i(imm, rs1, funct3, rd, opcode):
    return ((imm & 0xfff) << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode


def encode_s(imm, rs2, rs1, funct3):
    imm &= 0xfff
    imm_11_5 = (imm >> 5) & 0x7f
    imm_4_0 = imm & 0x1f
    return (imm_11_5 << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (imm_4_0 << 7) | 0x23


def encode_b(imm, rs2, rs1, funct3):
    imm &= 0x1fff
    imm_12 = (imm >> 12) & 0x1
    imm_10_5 = (imm >> 5) & 0x3f
    imm_4_1 = (imm >> 1) & 0xf
    imm_11 = (imm >> 11) & 0x1
    return (imm_12 << 31) | (imm_10_5 << 25) | (rs2 << 20) | (rs1 << 15) | \
           (funct3 << 12) | (imm_4_1 << 8) | (imm_11 << 7) | 0x63


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


def timer_mmio_program():
    program = Program()

    # x1 = 0x2000_0000 timer base
    program.emit(lui(1, 0x20000))

    # TIMER_COMPARE = 5
    program.emit(addi(2, 0, 5))
    program.emit(sw(2, 8, 1))
    program.emit(lw(3, 8, 1))
    program.branch("fail", "bne", 3, 2)

    # TIMER_COUNT = 0
    program.emit(addi(2, 0, 0))
    program.emit(sw(2, 4, 1))

    # TIMER_CTRL[0] = enable
    program.emit(addi(2, 0, 1))
    program.emit(sw(2, 0, 1))

    for _ in range(8):
        program.emit(addi(0, 0, 0))

    # TIMER_STATUS[0] should be 1 after count >= compare
    program.emit(lw(4, 12, 1))
    program.emit(andi(4, 4, 1))
    program.branch("fail", "beq", 4, 0)

    # TIMER_CTRL[1] clears count and disables timer
    program.emit(addi(2, 0, 2))
    program.emit(sw(2, 0, 1))
    program.emit(lw(5, 4, 1))
    program.branch("fail", "bne", 5, 0)

    program.label("pass")
    program.emit(addi(26, 0, 1))
    program.emit(addi(27, 0, 1))
    program.label("done")
    program.jal("done")

    program.label("fail")
    program.emit(addi(3, 0, 1))
    program.emit(addi(26, 0, 1))
    program.emit(addi(27, 0, 0))
    program.jal("done")

    return program.build()


def write_inst_data(words):
    path = os.path.join(project_root(), "sim", "inst_data.txt")
    with open(path, "w") as file_obj:
        for word in words:
            file_obj.write("{:08x}\n".format(word))


def main():
    write_inst_data(timer_mmio_program())

    compile_rc = compile()
    if compile_rc != 0:
        return compile_rc

    result = subprocess.run(
        ["vvp", "out.vvp"],
        cwd=sim_dir(),
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        timeout=10,
    )

    print(result.stdout.rstrip())

    if result.returncode != 0:
        return result.returncode
    if "pass" not in result.stdout:
        return 1
    if "fail" in result.stdout.lower() or "timeout" in result.stdout.lower():
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
