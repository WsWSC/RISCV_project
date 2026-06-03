import os
import subprocess
import sys

from compile_and_sim import project_root
from compile_and_sim import sim


OPCODE_SYSTEM = 0x73
OPCODE_OP_IMM = 0x13
OPCODE_OP = 0x33
OPCODE_JAL = 0x6F

FUNCT3_ADDI = 0
FUNCT3_SLTIU = 3
FUNCT3_OR = 6
FUNCT3_CSRRW = 1
FUNCT3_CSRRS = 2
FUNCT3_CSRRC = 3

CSR_MTVEC = 0x305


def encode_i(imm, rs1, funct3, rd, opcode):
    return ((imm & 0xFFF) << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode


def encode_r(funct7, rs2, rs1, funct3, rd, opcode):
    return (funct7 << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode


def encode_csr(csr, rs1, funct3, rd):
    return (csr << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | OPCODE_SYSTEM


def addi(rd, rs1, imm):
    return encode_i(imm, rs1, FUNCT3_ADDI, rd, OPCODE_OP_IMM)


def sltiu(rd, rs1, imm):
    return encode_i(imm, rs1, FUNCT3_SLTIU, rd, OPCODE_OP_IMM)


def sub(rd, rs1, rs2):
    return encode_r(0x20, rs2, rs1, 0, rd, OPCODE_OP)


def jal_zero():
    return OPCODE_JAL


def pass_if_x7_equals(expected, test_no):
    return [
        addi(3, 0, test_no),
        addi(5, 0, expected),
        sub(8, 7, 5),
        sltiu(27, 8, 1),
        addi(26, 0, 1),
        jal_zero(),
    ]


def write_inst_data(insts):
    out_mem = os.path.join(project_root(), "sim", "test_bin", "inst_data.txt")
    with open(out_mem, "w", encoding="utf-8") as f:
        for inst in insts:
            f.write(f"{inst:08x}\n")


def run_core_case(name, insts):
    write_inst_data(insts)
    rc = sim(["+timeout_cycles=1000"])
    if rc != 0:
        print(f"{name}: FAIL")
        return 1

    print(f"{name}: PASS")
    return 0


def run_csr_reg_tb():
    root = project_root()
    cmd = [
        "iverilog",
        "-g2012",
        "-I",
        os.path.join(root, "rtl", "utils"),
        "-I",
        os.path.join(root, "rtl", "core"),
        "-o",
        "csr_reg_tb.vvp",
        os.path.join(root, "rtl", "utils", "defines.v"),
        os.path.join(root, "rtl", "core", "csr_reg.v"),
        os.path.join(root, "tb", "csr_reg_tb.v"),
    ]

    proc = subprocess.run(cmd, cwd=os.path.dirname(__file__), text=True)
    if proc.returncode != 0:
        return proc.returncode

    proc = subprocess.run(["vvp", "csr_reg_tb.vvp"], cwd=os.path.dirname(__file__), text=True)
    return proc.returncode


def main():
    failures = 0

    failures += run_csr_reg_tb()

    csrrw_readback = [
        addi(5, 0, 0x123),
        encode_csr(CSR_MTVEC, 5, FUNCT3_CSRRW, 6),
        encode_csr(CSR_MTVEC, 0, FUNCT3_CSRRS, 7),
    ] + pass_if_x7_equals(0x123, 1)

    csrrs_readback = [
        addi(5, 0, 0x10),
        encode_csr(CSR_MTVEC, 5, FUNCT3_CSRRW, 0),
        addi(6, 0, 0x03),
        encode_csr(CSR_MTVEC, 6, FUNCT3_CSRRS, 0),
        encode_csr(CSR_MTVEC, 0, FUNCT3_CSRRS, 7),
    ] + pass_if_x7_equals(0x13, 2)

    csrrc_readback = [
        addi(5, 0, 0x13),
        encode_csr(CSR_MTVEC, 5, FUNCT3_CSRRW, 0),
        addi(6, 0, 0x02),
        encode_csr(CSR_MTVEC, 6, FUNCT3_CSRRC, 0),
        encode_csr(CSR_MTVEC, 0, FUNCT3_CSRRS, 7),
    ] + pass_if_x7_equals(0x11, 3)

    failures += run_core_case("csr_core_csrrw", csrrw_readback)
    failures += run_core_case("csr_core_csrrs", csrrs_readback)
    failures += run_core_case("csr_core_csrrc", csrrc_readback)

    if failures:
        print("CSR tests failed")
        return 1

    print("CSR tests passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
