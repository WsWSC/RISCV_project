import os
import subprocess
import sys

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from compile_and_sim import compile
from compile_and_sim import project_root
from compile_and_sim import sim_dir
from test_timer_mmio import Program
from test_timer_mmio import addi
from test_timer_mmio import andi
from test_timer_mmio import lui
from test_timer_mmio import sw


CSR_MSTATUS = 0x300
CSR_MIE = 0x304
CSR_MTVEC = 0x305
CSR_MCAUSE = 0x342
CSR_MIP = 0x344


def encode_csr(csr, rs1, funct3, rd):
    return (csr << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | 0x73


def csrw(csr, rs1):
    return encode_csr(csr, rs1, 0x1, 0)


def csrrs(rd, csr, rs1):
    return encode_csr(csr, rs1, 0x2, rd)


def csrs(csr, rs1):
    return csrrs(0, csr, rs1)


def csrr(rd, csr):
    return csrrs(rd, csr, 0)


def timer_interrupt_program():
    program = Program()

    # x1 = 0x2000_0000 timer base
    program.emit(lui(1, 0x20000))

    # mtvec = 0x80
    program.emit(addi(2, 0, 0x80))
    program.emit(csrw(CSR_MTVEC, 2))

    # TIMER_COMPARE = 5, TIMER_COUNT = 0, TIMER_CTRL[0] = enable
    program.emit(addi(2, 0, 5))
    program.emit(sw(2, 8, 1))
    program.emit(addi(2, 0, 0))
    program.emit(sw(2, 4, 1))
    program.emit(addi(2, 0, 1))
    program.emit(sw(2, 0, 1))

    # enable MTIE and global MIE
    program.emit(addi(2, 0, 0x80))
    program.emit(csrs(CSR_MIE, 2))
    program.emit(addi(2, 0, 0x8))
    program.emit(csrs(CSR_MSTATUS, 2))

    program.label("wait_irq")
    program.jal("wait_irq")

    while len(program.items) * 4 < 0x80:
        program.emit(addi(0, 0, 0))

    program.label("handler")
    program.emit(csrr(3, CSR_MCAUSE))
    program.emit(lui(4, 0x80000))
    program.emit(addi(4, 4, 7))
    program.branch("fail", "bne", 3, 4)

    # disable timer, then wait for level MTIP to clear
    program.emit(addi(2, 0, 0))
    program.emit(sw(2, 0, 1))
    program.emit(addi(0, 0, 0))
    program.emit(addi(0, 0, 0))
    program.emit(csrr(5, CSR_MIP))
    program.emit(andi(5, 5, 0x80))
    program.branch("fail", "bne", 5, 0)

    program.label("pass")
    program.emit(addi(26, 0, 1))
    program.emit(addi(27, 0, 1))
    program.label("done")
    program.jal("done")

    program.label("fail")
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
    write_inst_data(timer_interrupt_program())

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
