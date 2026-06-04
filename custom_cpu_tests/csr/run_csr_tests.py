import os
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT_DIR = Path(__file__).resolve().parents[2]
SIM_DIR = ROOT_DIR / "sim"
sys.path.insert(0, str(SIM_DIR))

from compile_and_sim import bin_to_mem


OPCODE_SYSTEM = 0x73
OPCODE_OP_IMM = 0x13
OPCODE_OP = 0x33
OPCODE_LOAD = 0x03
OPCODE_STORE = 0x23
OPCODE_JAL = 0x6F
INST_MRET = 0x30200073

FUNCT3_ADDI = 0
FUNCT3_LW = 2
FUNCT3_SW = 2
FUNCT3_SLTIU = 3
FUNCT3_AND = 7
FUNCT3_OR = 6
FUNCT3_CSRRW = 1
FUNCT3_CSRRS = 2
FUNCT3_CSRRC = 3

CSR_MTVEC = 0x305
CSR_MSTATUS = 0x300
CSR_MIE = 0x304
CSR_MEPC = 0x341
CSR_MCAUSE = 0x342
CSR_MTVAL = 0x343


def encode_i(imm, rs1, funct3, rd, opcode):
    return ((imm & 0xFFF) << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode


def encode_r(funct7, rs2, rs1, funct3, rd, opcode):
    return (funct7 << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode


def encode_s(imm, rs2, rs1, funct3, opcode):
    return (
        (((imm >> 5) & 0x7F) << 25)
        | (rs2 << 20)
        | (rs1 << 15)
        | (funct3 << 12)
        | ((imm & 0x1F) << 7)
        | opcode
    )


def encode_csr(csr, rs1, funct3, rd):
    return (csr << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | OPCODE_SYSTEM


def addi(rd, rs1, imm):
    return encode_i(imm, rs1, FUNCT3_ADDI, rd, OPCODE_OP_IMM)


def lui(rd, imm20):
    return ((imm20 & 0xFFFFF) << 12) | (rd << 7) | 0x37


def lw(rd, rs1, imm):
    return encode_i(imm, rs1, FUNCT3_LW, rd, OPCODE_LOAD)


def sw(rs2, rs1, imm):
    return encode_s(imm, rs2, rs1, FUNCT3_SW, OPCODE_STORE)


def sltiu(rd, rs1, imm):
    return encode_i(imm, rs1, FUNCT3_SLTIU, rd, OPCODE_OP_IMM)


def sub(rd, rs1, rs2):
    return encode_r(0x20, rs2, rs1, 0, rd, OPCODE_OP)


def and_(rd, rs1, rs2):
    return encode_r(0x00, rs2, rs1, FUNCT3_AND, rd, OPCODE_OP)


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
    out_mem = os.path.join(ROOT_DIR, "sim", "test_bin", "inst_data.txt")
    with open(out_mem, "w", encoding="utf-8") as f:
        for inst in insts:
            f.write(f"{inst:08x}\n")


def run_core_case(name, insts, vvp_args=None):
    root = str(ROOT_DIR)
    with tempfile.NamedTemporaryFile(delete=False, suffix=".bin") as tmp:
        tmp_path = tmp.name
        for inst in insts:
            tmp.write(inst.to_bytes(4, byteorder="little"))

    out_mem = os.path.join(root, "sim", "test_bin", "inst_data.txt")
    bin_to_mem(tmp_path, out_mem)
    os.unlink(tmp_path)

    args = ["+timeout_cycles=1000"]
    if vvp_args:
        args.extend(vvp_args)

    cmd = [
        sys.executable,
        "-c",
        "import sys, compile_and_sim; sys.exit(compile_and_sim.sim(sys.argv[1:]))",
    ]
    cmd.extend(args)
    result = subprocess.run(
        cmd,
        cwd=str(SIM_DIR),
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        timeout=30,
    )
    output = result.stdout
    passed = result.returncode == 0 and "pass" in output and "fail" not in output.lower() and "timeout" not in output.lower()

    if not passed:
        print(f"{name}: FAIL")
        print(output.rstrip())
        return 1

    print(f"{name}: PASS")
    return 0


def run_csr_reg_tb():
    root = str(ROOT_DIR)
    out_vvp = Path(__file__).with_name("csr_reg_tb.vvp")
    cmd = [
        "iverilog",
        "-g2012",
        "-I",
        os.path.join(root, "rtl", "utils"),
        "-I",
        os.path.join(root, "rtl", "core"),
        "-o",
        str(out_vvp),
        os.path.join(root, "rtl", "utils", "defines.v"),
        os.path.join(root, "rtl", "core", "csr_reg.v"),
        os.path.join(root, "custom_cpu_tests", "csr", "csr_reg_tb.v"),
    ]

    proc = subprocess.run(cmd, cwd=str(ROOT_DIR), text=True)
    if proc.returncode != 0:
        return proc.returncode

    proc = subprocess.run(["vvp", str(out_vvp)], cwd=str(ROOT_DIR), text=True)
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

    ecall_trap = [
        addi(3, 0, 4),
        addi(5, 0, 0x20),
        encode_csr(CSR_MTVEC, 5, FUNCT3_CSRRW, 0),
        addi(5, 0, 0x08),
        encode_csr(CSR_MSTATUS, 5, FUNCT3_CSRRW, 0),
        0x00000073,
        jal_zero(),
        jal_zero(),
        encode_csr(CSR_MEPC, 0, FUNCT3_CSRRS, 7),
        addi(5, 0, 0x14),
        sub(8, 7, 5),
        sltiu(27, 8, 1),
        encode_csr(CSR_MCAUSE, 0, FUNCT3_CSRRS, 7),
        addi(5, 0, 11),
        sub(8, 7, 5),
        sltiu(8, 8, 1),
        and_(27, 27, 8),
        encode_csr(CSR_MSTATUS, 0, FUNCT3_CSRRS, 7),
        addi(5, 0, 0x80),
        sub(8, 7, 5),
        sltiu(8, 8, 1),
        and_(27, 27, 8),
        addi(26, 0, 1),
        jal_zero(),
    ]

    mret_return = [
        addi(3, 0, 5),
        addi(5, 0, 0x44),
        encode_csr(CSR_MTVEC, 5, FUNCT3_CSRRW, 0),
        addi(5, 0, 0x08),
        encode_csr(CSR_MSTATUS, 5, FUNCT3_CSRRW, 0),
        0x00000073,
        addi(10, 0, 0x55),
        encode_csr(CSR_MSTATUS, 0, FUNCT3_CSRRS, 7),
        addi(5, 0, 0x88),
        sub(8, 7, 5),
        sltiu(27, 8, 1),
        addi(5, 0, 0x55),
        sub(8, 10, 5),
        sltiu(8, 8, 1),
        and_(27, 27, 8),
        addi(26, 0, 1),
        jal_zero(),
        addi(5, 0, 0x18),
        encode_csr(CSR_MEPC, 5, FUNCT3_CSRRW, 0),
        INST_MRET,
    ]

    external_irq = [
        addi(3, 0, 6),
        addi(5, 0, 0x3c),
        encode_csr(CSR_MTVEC, 5, FUNCT3_CSRRW, 0),
        addi(5, 0, 0x08),
        encode_csr(CSR_MSTATUS, 5, FUNCT3_CSRRW, 0),
        lui(5, 0x1),
        addi(5, 5, 0x800),
        encode_csr(CSR_MIE, 5, FUNCT3_CSRRW, 0),
        jal_zero(),
        jal_zero(),
        jal_zero(),
        jal_zero(),
        jal_zero(),
        jal_zero(),
        jal_zero(),
        encode_csr(CSR_MCAUSE, 0, FUNCT3_CSRRS, 7),
        lui(5, 0x80000),
        addi(5, 5, 11),
        sub(8, 7, 5),
        sltiu(27, 8, 1),
        encode_csr(CSR_MSTATUS, 0, FUNCT3_CSRRS, 7),
        addi(5, 0, 0x80),
        sub(8, 7, 5),
        sltiu(8, 8, 1),
        and_(27, 27, 8),
        addi(26, 0, 1),
        jal_zero(),
    ]

    external_irq_masked = [
        addi(3, 0, 7),
        addi(5, 0, 0x40),
        encode_csr(CSR_MTVEC, 5, FUNCT3_CSRRW, 0),
        addi(5, 0, 0x08),
        encode_csr(CSR_MSTATUS, 5, FUNCT3_CSRRW, 0),
        addi(0, 0, 0),
        addi(0, 0, 0),
        addi(0, 0, 0),
        addi(0, 0, 0),
        addi(0, 0, 0),
        addi(0, 0, 0),
        addi(0, 0, 0),
        addi(0, 0, 0),
        addi(27, 0, 1),
        addi(26, 0, 1),
        jal_zero(),
        addi(27, 0, 0),
        addi(26, 0, 1),
        jal_zero(),
    ]

    misaligned_load_trap = [
        addi(3, 0, 8),
        addi(5, 0, 0x20),
        encode_csr(CSR_MTVEC, 5, FUNCT3_CSRRW, 0),
        addi(6, 0, 1),
        lw(9, 6, 0),
        jal_zero(),
        jal_zero(),
        jal_zero(),
        encode_csr(CSR_MEPC, 0, FUNCT3_CSRRS, 7),
        addi(5, 0, 0x10),
        sub(8, 7, 5),
        sltiu(27, 8, 1),
        encode_csr(CSR_MCAUSE, 0, FUNCT3_CSRRS, 7),
        addi(5, 0, 4),
        sub(8, 7, 5),
        sltiu(8, 8, 1),
        and_(27, 27, 8),
        encode_csr(CSR_MTVAL, 0, FUNCT3_CSRRS, 7),
        addi(5, 0, 1),
        sub(8, 7, 5),
        sltiu(8, 8, 1),
        and_(27, 27, 8),
        addi(26, 0, 1),
        jal_zero(),
    ]

    misaligned_store_trap = [
        addi(3, 0, 9),
        addi(5, 0, 0x20),
        encode_csr(CSR_MTVEC, 5, FUNCT3_CSRRW, 0),
        addi(6, 0, 2),
        addi(7, 0, 0x55),
        sw(7, 6, 0),
        jal_zero(),
        jal_zero(),
        encode_csr(CSR_MEPC, 0, FUNCT3_CSRRS, 7),
        addi(5, 0, 0x14),
        sub(8, 7, 5),
        sltiu(27, 8, 1),
        encode_csr(CSR_MCAUSE, 0, FUNCT3_CSRRS, 7),
        addi(5, 0, 6),
        sub(8, 7, 5),
        sltiu(8, 8, 1),
        and_(27, 27, 8),
        encode_csr(CSR_MTVAL, 0, FUNCT3_CSRRS, 7),
        addi(5, 0, 2),
        sub(8, 7, 5),
        sltiu(8, 8, 1),
        and_(27, 27, 8),
        addi(26, 0, 1),
        jal_zero(),
    ]

    illegal_inst_trap = [
        addi(3, 0, 10),
        addi(5, 0, 0x20),
        encode_csr(CSR_MTVEC, 5, FUNCT3_CSRRW, 0),
        0x00000000,
        jal_zero(),
        jal_zero(),
        jal_zero(),
        jal_zero(),
        encode_csr(CSR_MEPC, 0, FUNCT3_CSRRS, 7),
        addi(5, 0, 0x0c),
        sub(8, 7, 5),
        sltiu(27, 8, 1),
        encode_csr(CSR_MCAUSE, 0, FUNCT3_CSRRS, 7),
        addi(5, 0, 2),
        sub(8, 7, 5),
        sltiu(8, 8, 1),
        and_(27, 27, 8),
        encode_csr(CSR_MTVAL, 0, FUNCT3_CSRRS, 7),
        sub(8, 7, 0),
        sltiu(8, 8, 1),
        and_(27, 27, 8),
        addi(26, 0, 1),
        jal_zero(),
    ]

    mtvec_align_trap = [
        addi(3, 0, 11),
        addi(5, 0, 0x22),
        encode_csr(CSR_MTVEC, 5, FUNCT3_CSRRW, 0),
        0x00000073,
        jal_zero(),
        jal_zero(),
        jal_zero(),
        jal_zero(),
        encode_csr(CSR_MEPC, 0, FUNCT3_CSRRS, 7),
        addi(5, 0, 0x0c),
        sub(8, 7, 5),
        sltiu(27, 8, 1),
        encode_csr(CSR_MCAUSE, 0, FUNCT3_CSRRS, 7),
        addi(5, 0, 11),
        sub(8, 7, 5),
        sltiu(8, 8, 1),
        and_(27, 27, 8),
        addi(26, 0, 1),
        jal_zero(),
    ]

    failures += run_core_case("csr_core_csrrw", csrrw_readback)
    failures += run_core_case("csr_core_csrrs", csrrs_readback)
    failures += run_core_case("csr_core_csrrc", csrrc_readback)
    failures += run_core_case("csr_core_ecall_trap", ecall_trap)
    failures += run_core_case("csr_core_mret_return", mret_return)
    failures += run_core_case("csr_core_external_irq", external_irq, ["+external_irq_cycle=12"])
    failures += run_core_case("csr_core_external_irq_masked", external_irq_masked, ["+external_irq_cycle=12"])
    failures += run_core_case("csr_core_misaligned_load_trap", misaligned_load_trap)
    failures += run_core_case("csr_core_misaligned_store_trap", misaligned_store_trap)
    failures += run_core_case("csr_core_illegal_inst_trap", illegal_inst_trap)
    failures += run_core_case("csr_core_mtvec_align_trap", mtvec_align_trap)

    if failures:
        print("CSR tests failed")
        return 1

    print("CSR tests passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
