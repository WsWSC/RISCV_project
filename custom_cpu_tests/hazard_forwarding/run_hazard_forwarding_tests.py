import os
import struct
import subprocess
import sys


def project_root():
    return os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))


def sign_extend_check(value, bits, name):
    lo = -(1 << (bits - 1))
    hi = (1 << (bits - 1)) - 1
    if value < lo or value > hi:
        raise ValueError(f"{name} out of {bits}-bit signed range: {value}")
    return value & ((1 << bits) - 1)


def r_type(funct7, rs2, rs1, funct3, rd, opcode=0x33):
    return (
        ((funct7 & 0x7F) << 25)
        | ((rs2 & 0x1F) << 20)
        | ((rs1 & 0x1F) << 15)
        | ((funct3 & 0x7) << 12)
        | ((rd & 0x1F) << 7)
        | (opcode & 0x7F)
    )


def i_type(imm, rs1, funct3, rd, opcode):
    imm12 = sign_extend_check(imm, 12, "I-type immediate")
    return (
        (imm12 << 20)
        | ((rs1 & 0x1F) << 15)
        | ((funct3 & 0x7) << 12)
        | ((rd & 0x1F) << 7)
        | (opcode & 0x7F)
    )


def s_type(imm, rs2, rs1, funct3, opcode=0x23):
    imm12 = sign_extend_check(imm, 12, "S-type immediate")
    return (
        ((imm12 >> 5) << 25)
        | ((rs2 & 0x1F) << 20)
        | ((rs1 & 0x1F) << 15)
        | ((funct3 & 0x7) << 12)
        | ((imm12 & 0x1F) << 7)
        | (opcode & 0x7F)
    )


def b_type(offset, rs2, rs1, funct3, opcode=0x63):
    if offset % 2:
        raise ValueError(f"B-type offset must be 2-byte aligned: {offset}")
    imm = sign_extend_check(offset, 13, "B-type offset")
    return (
        (((imm >> 12) & 0x1) << 31)
        | (((imm >> 5) & 0x3F) << 25)
        | ((rs2 & 0x1F) << 20)
        | ((rs1 & 0x1F) << 15)
        | ((funct3 & 0x7) << 12)
        | (((imm >> 1) & 0xF) << 8)
        | (((imm >> 11) & 0x1) << 7)
        | (opcode & 0x7F)
    )


def j_type(offset, rd, opcode=0x6F):
    if offset % 2:
        raise ValueError(f"J-type offset must be 2-byte aligned: {offset}")
    imm = sign_extend_check(offset, 21, "J-type offset")
    return (
        (((imm >> 20) & 0x1) << 31)
        | (((imm >> 1) & 0x3FF) << 21)
        | (((imm >> 11) & 0x1) << 20)
        | (((imm >> 12) & 0xFF) << 12)
        | ((rd & 0x1F) << 7)
        | (opcode & 0x7F)
    )


class Program:
    def __init__(self):
        self.items = []
        self.labels = {}

    def label(self, name):
        self.labels[name] = 4 * len(self.items)

    def emit(self, op, *args):
        self.items.append((op, args))

    def resolve(self):
        words = []
        for pc, (op, args) in enumerate(self.items):
            addr = 4 * pc
            if op == "addi":
                rd, rs1, imm = args
                if isinstance(imm, str):
                    imm = self.labels[imm]
                words.append(i_type(imm, rs1, 0x0, rd, 0x13))
            elif op == "add":
                rd, rs1, rs2 = args
                words.append(r_type(0x00, rs2, rs1, 0x0, rd))
            elif op == "sub":
                rd, rs1, rs2 = args
                words.append(r_type(0x20, rs2, rs1, 0x0, rd))
            elif op == "sll":
                rd, rs1, rs2 = args
                words.append(r_type(0x00, rs2, rs1, 0x1, rd))
            elif op == "xor":
                rd, rs1, rs2 = args
                words.append(r_type(0x00, rs2, rs1, 0x4, rd))
            elif op == "or":
                rd, rs1, rs2 = args
                words.append(r_type(0x00, rs2, rs1, 0x6, rd))
            elif op == "and":
                rd, rs1, rs2 = args
                words.append(r_type(0x00, rs2, rs1, 0x7, rd))
            elif op == "mul":
                rd, rs1, rs2 = args
                words.append(r_type(0x01, rs2, rs1, 0x0, rd))
            elif op == "div":
                rd, rs1, rs2 = args
                words.append(r_type(0x01, rs2, rs1, 0x4, rd))
            elif op == "lw":
                rd, imm, rs1 = args
                words.append(i_type(imm, rs1, 0x2, rd, 0x03))
            elif op == "lb":
                rd, imm, rs1 = args
                words.append(i_type(imm, rs1, 0x0, rd, 0x03))
            elif op == "lbu":
                rd, imm, rs1 = args
                words.append(i_type(imm, rs1, 0x4, rd, 0x03))
            elif op == "sw":
                rs2, imm, rs1 = args
                words.append(s_type(imm, rs2, rs1, 0x2))
            elif op == "sb":
                rs2, imm, rs1 = args
                words.append(s_type(imm, rs2, rs1, 0x0))
            elif op == "beq":
                rs1, rs2, label = args
                words.append(b_type(self.labels[label] - addr, rs2, rs1, 0x0))
            elif op == "bne":
                rs1, rs2, label = args
                words.append(b_type(self.labels[label] - addr, rs2, rs1, 0x1))
            elif op == "jal":
                rd, label = args
                words.append(j_type(self.labels[label] - addr, rd))
            elif op == "jalr":
                rd, imm, rs1 = args
                words.append(i_type(imm, rs1, 0x0, rd, 0x67))
            else:
                raise ValueError(f"unknown op: {op}")
        return words


def build_hazard_program():
    p = Program()

    # 1. EX-to-ID forwarding into both R-type operands.
    p.emit("addi", 3, 0, 1)
    p.emit("addi", 1, 0, 7)
    p.emit("add", 2, 1, 1)
    p.emit("addi", 4, 0, 14)
    p.emit("bne", 2, 4, "fail")

    # 2. Back-to-back ALU dependency chain.
    p.emit("addi", 3, 0, 2)
    p.emit("addi", 5, 0, 1)
    p.emit("addi", 5, 5, 2)
    p.emit("addi", 5, 5, 3)
    p.emit("addi", 6, 0, 6)
    p.emit("bne", 5, 6, "fail")

    # 3. Store-data forwarding, load-use forwarding, then ALU consume.
    p.emit("addi", 3, 0, 3)
    p.emit("addi", 10, 0, 64)
    p.emit("addi", 11, 0, 42)
    p.emit("sw", 11, 0, 10)
    p.emit("lw", 12, 0, 10)
    p.emit("add", 13, 12, 11)
    p.emit("addi", 14, 0, 84)
    p.emit("bne", 13, 14, "fail")

    # 4. Store-base forwarding.
    p.emit("addi", 3, 0, 4)
    p.emit("addi", 15, 0, 80)
    p.emit("sw", 11, 0, 15)
    p.emit("lw", 16, 0, 15)
    p.emit("bne", 16, 11, "fail")

    # 5. Branch operand forwarding.
    p.emit("addi", 3, 0, 5)
    p.emit("addi", 17, 0, 5)
    p.emit("beq", 17, 0, "fail")
    p.emit("addi", 18, 0, 5)
    p.emit("beq", 18, 17, "branch_ok")
    p.emit("jal", 0, "fail")
    p.label("branch_ok")

    # 6. JALR base-address forwarding.
    p.emit("addi", 3, 0, 6)
    p.emit("addi", 19, 0, "jalr_target")
    p.emit("jalr", 0, 0, 19)
    p.emit("jal", 0, "fail")
    p.label("jalr_target")

    # 7. x0 must not be forwarded.
    p.emit("addi", 3, 0, 7)
    p.emit("addi", 0, 0, 99)
    p.emit("addi", 21, 0, 1)
    p.emit("addi", 22, 0, 1)
    p.emit("bne", 21, 22, "fail")

    # 8. Multi-cycle mul stall followed by immediate result consume.
    p.emit("addi", 3, 0, 8)
    p.emit("addi", 23, 0, 6)
    p.emit("addi", 24, 0, 7)
    p.emit("mul", 25, 23, 24)
    p.emit("add", 5, 25, 0)
    p.emit("addi", 6, 0, 42)
    p.emit("bne", 5, 6, "fail")

    # 9. Forwarding into I-type rs1 operand.
    p.emit("addi", 3, 0, 9)
    p.emit("addi", 1, 0, 12)
    p.emit("addi", 2, 1, -5)
    p.emit("addi", 4, 0, 7)
    p.emit("bne", 2, 4, "fail")

    # 10. Forwarding into rs2 as a shift amount.
    p.emit("addi", 3, 0, 10)
    p.emit("addi", 1, 0, 3)
    p.emit("addi", 2, 0, 2)
    p.emit("sll", 4, 1, 2)
    p.emit("addi", 5, 0, 12)
    p.emit("bne", 4, 5, "fail")

    # 11. Two-source forwarding from the same producer to both rs1 and rs2.
    p.emit("addi", 3, 0, 11)
    p.emit("addi", 1, 0, 9)
    p.emit("sub", 2, 1, 1)
    p.emit("bne", 2, 0, "fail")

    # 12. R-type logic operations consume freshly forwarded operands.
    p.emit("addi", 3, 0, 12)
    p.emit("addi", 1, 0, 10)
    p.emit("addi", 2, 0, 12)
    p.emit("and", 4, 1, 2)
    p.emit("addi", 5, 0, 8)
    p.emit("bne", 4, 5, "fail")
    p.emit("or", 6, 1, 2)
    p.emit("addi", 7, 0, 14)
    p.emit("bne", 6, 7, "fail")
    p.emit("xor", 8, 1, 2)
    p.emit("addi", 9, 0, 6)
    p.emit("bne", 8, 9, "fail")

    # 13. Branch not-taken path must use forwarded data correctly.
    p.emit("addi", 3, 0, 13)
    p.emit("addi", 1, 0, 1)
    p.emit("bne", 1, 1, "fail")
    p.emit("addi", 2, 0, 33)
    p.emit("addi", 4, 0, 33)
    p.emit("bne", 2, 4, "fail")

    # 14. JAL link register can be consumed immediately at the target.
    p.emit("addi", 3, 0, 14)
    p.emit("jal", 1, "jal_link_target")
    p.label("jal_return_addr")
    p.emit("jal", 0, "fail")
    p.emit("jal", 0, "fail")
    p.label("jal_link_target")
    p.emit("addi", 2, 1, 0)
    p.emit("addi", 4, 0, "jal_return_addr")
    p.emit("bne", 2, 4, "fail")

    # 15. Store byte data forwarding and unsigned byte load-use forwarding.
    p.emit("addi", 3, 0, 15)
    p.emit("addi", 10, 0, 96)
    p.emit("addi", 11, 0, 127)
    p.emit("sb", 11, 1, 10)
    p.emit("lbu", 12, 1, 10)
    p.emit("addi", 13, 12, 1)
    p.emit("addi", 14, 0, 128)
    p.emit("bne", 13, 14, "fail")

    # 16. Signed byte load result forwards into the next ALU instruction.
    p.emit("addi", 3, 0, 16)
    p.emit("addi", 11, 0, -1)
    p.emit("sb", 11, 2, 10)
    p.emit("lb", 12, 2, 10)
    p.emit("addi", 13, 12, 1)
    p.emit("bne", 13, 0, "fail")

    # 17. Multi-cycle div stall followed by immediate result consume.
    p.emit("addi", 3, 0, 17)
    p.emit("addi", 23, 0, 42)
    p.emit("addi", 24, 0, 7)
    p.emit("div", 25, 23, 24)
    p.emit("add", 5, 25, 0)
    p.emit("addi", 6, 0, 6)
    p.emit("bne", 5, 6, "fail")

    # 18. Load-use bubble immediately followed by mul multi-cycle stall.
    p.emit("addi", 3, 0, 18)
    p.emit("addi", 10, 0, 112)
    p.emit("addi", 11, 0, 6)
    p.emit("sw", 11, 0, 10)
    p.emit("lw", 23, 0, 10)
    p.emit("mul", 25, 23, 24)
    p.emit("addi", 6, 0, 42)
    p.emit("bne", 25, 6, "fail")

    # 19. Load-use bubble immediately followed by div multi-cycle stall.
    p.emit("addi", 3, 0, 19)
    p.emit("addi", 10, 0, 116)
    p.emit("addi", 11, 0, 42)
    p.emit("sw", 11, 0, 10)
    p.emit("lw", 23, 0, 10)
    p.emit("div", 25, 23, 24)
    p.emit("addi", 6, 0, 6)
    p.emit("bne", 25, 6, "fail")

    p.label("pass")
    p.emit("addi", 27, 0, 1)
    p.emit("addi", 26, 0, 1)
    p.emit("jal", 0, "pass")

    p.label("fail")
    p.emit("addi", 27, 0, 0)
    p.emit("addi", 26, 0, 1)
    p.emit("jal", 0, "fail")

    return p.resolve()


def write_bin(path, words):
    with open(path, "wb") as f:
        for word in words:
            f.write(struct.pack("<I", word))


def main():
    root = project_root()
    out_bin = os.path.join(os.path.dirname(__file__), "hazard_forwarding.bin")
    write_bin(out_bin, build_hazard_program())

    try:
        cmd = [
            sys.executable,
            "compile_and_sim.py",
            out_bin,
            "--timeout-cycles",
            "2000",
        ]
        result = subprocess.run(
            cmd,
            cwd=os.path.join(root, "sim"),
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
        )
        print(result.stdout, end="")
        return result.returncode
    finally:
        if os.path.exists(out_bin):
            os.remove(out_bin)


if __name__ == "__main__":
    sys.exit(main())
