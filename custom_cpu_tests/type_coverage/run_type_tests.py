#!/usr/bin/env python3
"""
Detailed RV32I/RV32M instruction-type regression tests.

This script generates small self-checking binaries without using an external
assembler, then runs them through the repository's existing tb.v pass/fail
convention:

    x26 = 1  -> test finished
    x27 = 1  -> pass
    x27 = 0  -> fail, with x3 holding the failing case id
"""

from __future__ import annotations

import argparse
import os
import pathlib
import subprocess
import sys
from dataclasses import dataclass


THIS_DIR = pathlib.Path(__file__).resolve().parent
ROOT_DIR = THIS_DIR.parents[1]
SIM_DIR = ROOT_DIR / "sim"
GEN_DIR = THIS_DIR / "generated_bin"

sys.path.insert(0, str(SIM_DIR))
import compile_and_sim  # noqa: E402


NOP = 0x00000013


def u32(value: int) -> int:
    return value & 0xFFFFFFFF


def s32(value: int) -> int:
    value &= 0xFFFFFFFF
    return value - 0x100000000 if value & 0x80000000 else value


def fits_simm12(value: int) -> bool:
    return -2048 <= value <= 2047


def require_range(name: str, value: int, bits: int, signed: bool = False) -> None:
    if signed:
        lo = -(1 << (bits - 1))
        hi = (1 << (bits - 1)) - 1
    else:
        lo = 0
        hi = (1 << bits) - 1
    if not (lo <= value <= hi):
        raise ValueError(f"{name}={value} does not fit {bits} bits")


def enc_r(funct7: int, rs2: int, rs1: int, funct3: int, rd: int, opcode: int = 0x33) -> int:
    return (
        ((funct7 & 0x7F) << 25)
        | ((rs2 & 0x1F) << 20)
        | ((rs1 & 0x1F) << 15)
        | ((funct3 & 0x7) << 12)
        | ((rd & 0x1F) << 7)
        | (opcode & 0x7F)
    )


def enc_i(imm: int, rs1: int, funct3: int, rd: int, opcode: int = 0x13) -> int:
    require_range("i_imm", imm, 12, signed=True)
    return (
        ((imm & 0xFFF) << 20)
        | ((rs1 & 0x1F) << 15)
        | ((funct3 & 0x7) << 12)
        | ((rd & 0x1F) << 7)
        | (opcode & 0x7F)
    )


def enc_s(imm: int, rs2: int, rs1: int, funct3: int) -> int:
    require_range("s_imm", imm, 12, signed=True)
    imm &= 0xFFF
    return (
        ((imm >> 5) << 25)
        | ((rs2 & 0x1F) << 20)
        | ((rs1 & 0x1F) << 15)
        | ((funct3 & 0x7) << 12)
        | ((imm & 0x1F) << 7)
        | 0x23
    )


def enc_b(imm: int, rs2: int, rs1: int, funct3: int) -> int:
    require_range("b_imm", imm, 13, signed=True)
    if imm % 2:
        raise ValueError("branch offset must be 2-byte aligned")
    imm &= 0x1FFF
    return (
        (((imm >> 12) & 0x1) << 31)
        | (((imm >> 5) & 0x3F) << 25)
        | ((rs2 & 0x1F) << 20)
        | ((rs1 & 0x1F) << 15)
        | ((funct3 & 0x7) << 12)
        | (((imm >> 1) & 0xF) << 8)
        | (((imm >> 11) & 0x1) << 7)
        | 0x63
    )


def enc_u(imm20: int, rd: int, opcode: int) -> int:
    require_range("u_imm20", imm20, 20)
    return ((imm20 & 0xFFFFF) << 12) | ((rd & 0x1F) << 7) | (opcode & 0x7F)


def enc_j(imm: int, rd: int) -> int:
    require_range("j_imm", imm, 21, signed=True)
    if imm % 2:
        raise ValueError("jal offset must be 2-byte aligned")
    imm &= 0x1FFFFF
    return (
        (((imm >> 20) & 0x1) << 31)
        | (((imm >> 1) & 0x3FF) << 21)
        | (((imm >> 11) & 0x1) << 20)
        | (((imm >> 12) & 0xFF) << 12)
        | ((rd & 0x1F) << 7)
        | 0x6F
    )


@dataclass
class Fixup:
    index: int
    label: str
    kind: str
    rs1: int = 0
    rs2: int = 0
    funct3: int = 0
    rd: int = 0


class Program:
    def __init__(self) -> None:
        self.words: list[int] = []
        self.labels: dict[str, int] = {}
        self.fixups: list[Fixup] = []
        self.case_id = 0

    @property
    def pc(self) -> int:
        return 4 * len(self.words)

    def emit(self, word: int) -> None:
        self.words.append(word & 0xFFFFFFFF)

    def label(self, name: str) -> None:
        if name in self.labels:
            raise ValueError(f"duplicate label: {name}")
        self.labels[name] = self.pc

    def nops(self, count: int = 3) -> None:
        for _ in range(count):
            self.emit(NOP)

    def li(self, rd: int, value: int) -> None:
        value = u32(value)
        signed_value = s32(value)
        if fits_simm12(signed_value):
            self.addi(rd, 0, signed_value)
            return

        upper = (value + 0x800) >> 12
        lower = s32(value - (upper << 12))
        self.lui(rd, upper & 0xFFFFF)
        if lower:
            self.nops()
            self.addi(rd, rd, lower)

    def finish_pass(self) -> None:
        self.li(27, 1)
        self.nops()
        self.li(26, 1)
        self.label("pass_halt")
        self.jal(0, "pass_halt")

    def finish_fail(self) -> None:
        self.label("fail")
        self.li(27, 0)
        self.nops()
        self.li(26, 1)
        self.label("fail_halt")
        self.jal(0, "fail_halt")

    def set_case(self, text: str) -> int:
        self.case_id += 1
        self.li(3, self.case_id)
        print(f"  case {self.case_id:02d}: {text}")
        return self.case_id

    def check_reg(self, rd: int, expected: int, text: str) -> None:
        self.set_case(text)
        self.li(6, expected)
        self.nops()
        self.bne(rd, 6, "fail")
        self.nops()

    def addi(self, rd: int, rs1: int, imm: int) -> None:
        self.emit(enc_i(imm, rs1, 0x0, rd))

    def slti(self, rd: int, rs1: int, imm: int) -> None:
        self.emit(enc_i(imm, rs1, 0x2, rd))

    def sltiu(self, rd: int, rs1: int, imm: int) -> None:
        self.emit(enc_i(imm, rs1, 0x3, rd))

    def xori(self, rd: int, rs1: int, imm: int) -> None:
        self.emit(enc_i(imm, rs1, 0x4, rd))

    def ori(self, rd: int, rs1: int, imm: int) -> None:
        self.emit(enc_i(imm, rs1, 0x6, rd))

    def andi(self, rd: int, rs1: int, imm: int) -> None:
        self.emit(enc_i(imm, rs1, 0x7, rd))

    def slli(self, rd: int, rs1: int, shamt: int) -> None:
        self.emit(enc_i(shamt, rs1, 0x1, rd))

    def srli(self, rd: int, rs1: int, shamt: int) -> None:
        self.emit(enc_i(shamt, rs1, 0x5, rd))

    def srai(self, rd: int, rs1: int, shamt: int) -> None:
        self.emit(enc_i(0x400 | shamt, rs1, 0x5, rd))

    def lb(self, rd: int, rs1: int, imm: int) -> None:
        self.emit(enc_i(imm, rs1, 0x0, rd, opcode=0x03))

    def lh(self, rd: int, rs1: int, imm: int) -> None:
        self.emit(enc_i(imm, rs1, 0x1, rd, opcode=0x03))

    def lw(self, rd: int, rs1: int, imm: int) -> None:
        self.emit(enc_i(imm, rs1, 0x2, rd, opcode=0x03))

    def lbu(self, rd: int, rs1: int, imm: int) -> None:
        self.emit(enc_i(imm, rs1, 0x4, rd, opcode=0x03))

    def lhu(self, rd: int, rs1: int, imm: int) -> None:
        self.emit(enc_i(imm, rs1, 0x5, rd, opcode=0x03))

    def jalr(self, rd: int, rs1: int, imm: int) -> None:
        self.emit(enc_i(imm, rs1, 0x0, rd, opcode=0x67))

    def sb(self, rs2: int, rs1: int, imm: int) -> None:
        self.emit(enc_s(imm, rs2, rs1, 0x0))

    def sh(self, rs2: int, rs1: int, imm: int) -> None:
        self.emit(enc_s(imm, rs2, rs1, 0x1))

    def sw(self, rs2: int, rs1: int, imm: int) -> None:
        self.emit(enc_s(imm, rs2, rs1, 0x2))

    def r(self, rd: int, rs1: int, rs2: int, funct3: int, funct7: int = 0) -> None:
        self.emit(enc_r(funct7, rs2, rs1, funct3, rd))

    def add(self, rd: int, rs1: int, rs2: int) -> None:
        self.r(rd, rs1, rs2, 0x0, 0x00)

    def sub(self, rd: int, rs1: int, rs2: int) -> None:
        self.r(rd, rs1, rs2, 0x0, 0x20)

    def sll(self, rd: int, rs1: int, rs2: int) -> None:
        self.r(rd, rs1, rs2, 0x1)

    def slt(self, rd: int, rs1: int, rs2: int) -> None:
        self.r(rd, rs1, rs2, 0x2)

    def sltu(self, rd: int, rs1: int, rs2: int) -> None:
        self.r(rd, rs1, rs2, 0x3)

    def xor(self, rd: int, rs1: int, rs2: int) -> None:
        self.r(rd, rs1, rs2, 0x4)

    def srl(self, rd: int, rs1: int, rs2: int) -> None:
        self.r(rd, rs1, rs2, 0x5)

    def sra(self, rd: int, rs1: int, rs2: int) -> None:
        self.r(rd, rs1, rs2, 0x5, 0x20)

    def or_(self, rd: int, rs1: int, rs2: int) -> None:
        self.r(rd, rs1, rs2, 0x6)

    def and_(self, rd: int, rs1: int, rs2: int) -> None:
        self.r(rd, rs1, rs2, 0x7)

    def mulop(self, rd: int, rs1: int, rs2: int, funct3: int) -> None:
        self.r(rd, rs1, rs2, funct3, 0x01)

    def lui(self, rd: int, imm20: int) -> None:
        self.emit(enc_u(imm20, rd, 0x37))

    def auipc(self, rd: int, imm20: int) -> int:
        pc = self.pc
        self.emit(enc_u(imm20, rd, 0x17))
        return pc

    def branch(self, rs1: int, rs2: int, label: str, funct3: int) -> None:
        self.fixups.append(Fixup(len(self.words), label, "b", rs1=rs1, rs2=rs2, funct3=funct3))
        self.emit(NOP)

    def beq(self, rs1: int, rs2: int, label: str) -> None:
        self.branch(rs1, rs2, label, 0x0)

    def bne(self, rs1: int, rs2: int, label: str) -> None:
        self.branch(rs1, rs2, label, 0x1)

    def blt(self, rs1: int, rs2: int, label: str) -> None:
        self.branch(rs1, rs2, label, 0x4)

    def bge(self, rs1: int, rs2: int, label: str) -> None:
        self.branch(rs1, rs2, label, 0x5)

    def bltu(self, rs1: int, rs2: int, label: str) -> None:
        self.branch(rs1, rs2, label, 0x6)

    def bgeu(self, rs1: int, rs2: int, label: str) -> None:
        self.branch(rs1, rs2, label, 0x7)

    def jal(self, rd: int, label: str) -> None:
        self.fixups.append(Fixup(len(self.words), label, "j", rd=rd))
        self.emit(NOP)

    def resolve(self) -> list[int]:
        words = self.words[:]
        for fixup in self.fixups:
            if fixup.label not in self.labels:
                raise ValueError(f"undefined label: {fixup.label}")
            here = fixup.index * 4
            target = self.labels[fixup.label]
            offset = target - here
            if fixup.kind == "b":
                words[fixup.index] = enc_b(offset, fixup.rs2, fixup.rs1, fixup.funct3)
            elif fixup.kind == "j":
                words[fixup.index] = enc_j(offset, fixup.rd)
            else:
                raise ValueError(f"unknown fixup kind: {fixup.kind}")
        return words


def build_r_type() -> Program:
    p = Program()
    p.li(1, 13)
    p.li(2, 7)
    p.nops()
    p.add(5, 1, 2)
    p.nops()
    p.check_reg(5, 20, "R ADD positive operands")
    p.li(1, 0x7FFFFFFF)
    p.li(2, 1)
    p.nops()
    p.add(5, 1, 2)
    p.nops()
    p.check_reg(5, 0x80000000, "R ADD wraps on signed overflow")
    p.li(1, 0x80000000)
    p.li(2, 1)
    p.nops()
    p.sub(5, 1, 2)
    p.nops()
    p.check_reg(5, 0x7FFFFFFF, "R SUB wraps on signed overflow")
    p.li(1, 13)
    p.li(2, 7)
    p.nops()
    p.sub(5, 1, 2)
    p.nops()
    p.check_reg(5, 6, "R SUB positive operands")
    p.li(1, 0x80000001)
    p.li(2, 4)
    p.nops()
    p.sll(5, 1, 2)
    p.nops()
    p.check_reg(5, 0x00000010, "R SLL uses low five bits of rs2")
    p.srl(5, 1, 2)
    p.nops()
    p.check_reg(5, 0x08000000, "R SRL zero-fills")
    p.sra(5, 1, 2)
    p.nops()
    p.check_reg(5, 0xF8000000, "R SRA sign-fills")
    p.li(1, 1)
    p.li(2, 0x0000003F)
    p.nops()
    p.sll(5, 1, 2)
    p.nops()
    p.check_reg(5, 0x80000000, "R SLL masks rs2 to shamt[4:0]")
    p.li(1, 0x80000000)
    p.nops()
    p.sra(5, 1, 2)
    p.nops()
    p.check_reg(5, 0xFFFFFFFF, "R SRA with masked shamt 31")
    p.li(1, 0xFFFFFFFF)
    p.li(2, 1)
    p.nops()
    p.slt(5, 1, 2)
    p.nops()
    p.check_reg(5, 1, "R SLT signed negative less than positive")
    p.sltu(5, 1, 2)
    p.nops()
    p.check_reg(5, 0, "R SLTU unsigned comparison")
    p.slt(5, 2, 1)
    p.nops()
    p.check_reg(5, 0, "R SLT positive not less than negative")
    p.sltu(5, 2, 1)
    p.nops()
    p.check_reg(5, 1, "R SLTU one less than unsigned max")
    p.li(1, 0x55AA00FF)
    p.li(2, 0x0F0FF0F0)
    p.nops()
    p.xor(5, 1, 2)
    p.nops()
    p.check_reg(5, 0x5AA5F00F, "R XOR bit pattern")
    p.or_(5, 1, 2)
    p.nops()
    p.check_reg(5, 0x5FAFF0FF, "R OR bit pattern")
    p.and_(5, 1, 2)
    p.nops()
    p.check_reg(5, 0x050A00F0, "R AND bit pattern")
    p.addi(0, 0, 99)
    p.nops()
    p.addi(5, 0, 0)
    p.nops()
    p.check_reg(5, 0, "x0 remains hard-wired to zero")
    p.finish_pass()
    p.finish_fail()
    return p


def build_i_type() -> Program:
    p = Program()
    p.li(1, 0x00000F00)
    p.nops()
    p.addi(5, 1, -16)
    p.nops()
    p.check_reg(5, 0x00000EF0, "I ADDI sign-extends negative immediate")
    p.addi(5, 1, 2047)
    p.nops()
    p.check_reg(5, 0x000016FF, "I ADDI max positive immediate")
    p.addi(5, 1, -2048)
    p.nops()
    p.check_reg(5, 0x00000700, "I ADDI min negative immediate")
    p.li(1, 0xFFFFFFFF)
    p.nops()
    p.slti(5, 1, 1)
    p.nops()
    p.check_reg(5, 1, "I SLTI signed compare")
    p.sltiu(5, 1, 1)
    p.nops()
    p.check_reg(5, 0, "I SLTIU unsigned compare")
    p.slti(5, 1, -1)
    p.nops()
    p.check_reg(5, 0, "I SLTI equal signed values is false")
    p.li(1, 0)
    p.nops()
    p.sltiu(5, 1, -1)
    p.nops()
    p.check_reg(5, 1, "I SLTIU compares sign-extended immediate as unsigned")
    p.li(1, 0x12345678)
    p.nops()
    p.xori(5, 1, -1)
    p.nops()
    p.check_reg(5, 0xEDCBA987, "I XORI sign-extended all-ones immediate")
    p.ori(5, 1, 0x0F0)
    p.nops()
    p.check_reg(5, 0x123456F8, "I ORI immediate mask")
    p.andi(5, 1, 0x0F0)
    p.nops()
    p.check_reg(5, 0x00000070, "I ANDI immediate mask")
    p.slli(5, 1, 4)
    p.nops()
    p.check_reg(5, 0x23456780, "I SLLI shamt")
    p.slli(5, 1, 0)
    p.nops()
    p.check_reg(5, 0x12345678, "I SLLI shamt 0 leaves value")
    p.slli(5, 1, 31)
    p.nops()
    p.check_reg(5, 0, "I SLLI shamt 31 low-bit behavior")
    p.li(1, 0x80000000)
    p.nops()
    p.srli(5, 1, 4)
    p.nops()
    p.check_reg(5, 0x08000000, "I SRLI zero-fill")
    p.srai(5, 1, 4)
    p.nops()
    p.check_reg(5, 0xF8000000, "I SRAI sign-fill")
    p.srli(5, 1, 31)
    p.nops()
    p.check_reg(5, 1, "I SRLI shamt 31 extracts sign bit as data")
    p.srai(5, 1, 31)
    p.nops()
    p.check_reg(5, 0xFFFFFFFF, "I SRAI shamt 31 all sign bits")
    p.finish_pass()
    p.finish_fail()
    return p


def build_load_store_type() -> Program:
    p = Program()
    p.li(1, 0)
    p.li(2, 0xA1B2C3D4)
    p.nops()
    p.sw(2, 1, 0)
    p.nops(5)
    p.lw(5, 1, 0)
    p.nops()
    p.check_reg(5, 0xA1B2C3D4, "S/L SW then LW full word")
    p.lb(5, 1, 0)
    p.nops()
    p.check_reg(5, 0xFFFFFFD4, "L LB sign-extends byte 0")
    p.lb(5, 1, 1)
    p.nops()
    p.check_reg(5, 0xFFFFFFC3, "L LB sign-extends byte 1")
    p.lb(5, 1, 3)
    p.nops()
    p.check_reg(5, 0xFFFFFFA1, "L LB sign-extends byte 3")
    p.lbu(5, 1, 0)
    p.nops()
    p.check_reg(5, 0x000000D4, "L LBU zero-extends byte 0")
    p.lbu(5, 1, 3)
    p.nops()
    p.check_reg(5, 0x000000A1, "L LBU zero-extends byte 3")
    p.lh(5, 1, 0)
    p.nops()
    p.check_reg(5, 0xFFFFC3D4, "L LH sign-extends low halfword")
    p.lhu(5, 1, 2)
    p.nops()
    p.check_reg(5, 0x0000A1B2, "L LHU zero-extends high halfword")
    p.li(2, 0x0000007E)
    p.nops()
    p.sb(2, 1, 0)
    p.nops(5)
    p.lw(5, 1, 0)
    p.nops()
    p.check_reg(5, 0xA1B2C37E, "S SB writes byte lane 0")
    p.sb(2, 1, 1)
    p.nops(5)
    p.lw(5, 1, 0)
    p.nops()
    p.check_reg(5, 0xA1B27E7E, "S SB writes byte lane 1")
    p.sb(2, 1, 2)
    p.nops(5)
    p.lw(5, 1, 0)
    p.nops()
    p.check_reg(5, 0xA17E7E7E, "S SB writes byte lane 2")
    p.sb(2, 1, 3)
    p.nops(5)
    p.lw(5, 1, 0)
    p.nops()
    p.check_reg(5, 0x7E7E7E7E, "S SB writes byte lane 3")
    p.li(2, 0x00001234)
    p.nops()
    p.sh(2, 1, 0)
    p.nops(5)
    p.lw(5, 1, 0)
    p.nops()
    p.check_reg(5, 0x7E7E1234, "S SH writes aligned low halfword")
    p.sh(2, 1, 2)
    p.nops(5)
    p.lw(5, 1, 0)
    p.nops()
    p.check_reg(5, 0x12341234, "S SH writes aligned high halfword")
    p.finish_pass()
    p.finish_fail()
    return p


def build_branch_type() -> Program:
    p = Program()

    def must_take(name: str, emit_branch) -> None:
        p.set_case(name)
        emit_branch(f"taken_{p.case_id}")
        p.nops()
        p.jal(0, "fail")
        p.label(f"taken_{p.case_id}")
        p.nops()

    def must_not_take(name: str, emit_branch) -> None:
        p.set_case(name)
        emit_branch("fail")
        p.nops()

    p.li(1, 5)
    p.li(2, 5)
    p.nops()
    must_take("B BEQ taken on equal", lambda label: p.beq(1, 2, label))
    must_not_take("B BNE not taken on equal", lambda label: p.bne(1, 2, label))
    p.li(2, 6)
    p.nops()
    must_not_take("B BEQ not taken on not equal", lambda label: p.beq(1, 2, label))
    must_take("B BNE taken on not equal", lambda label: p.bne(1, 2, label))
    p.li(1, 0xFFFFFFFF)
    p.li(2, 1)
    p.nops()
    must_take("B BLT signed negative < positive", lambda label: p.blt(1, 2, label))
    must_not_take("B BGE signed negative !>= positive", lambda label: p.bge(1, 2, label))
    must_take("B BGE signed positive >= negative", lambda label: p.bge(2, 1, label))
    must_not_take("B BLTU unsigned max !< one", lambda label: p.bltu(1, 2, label))
    must_take("B BLTU unsigned one < max", lambda label: p.bltu(2, 1, label))
    must_take("B BGEU unsigned max >= one", lambda label: p.bgeu(1, 2, label))
    must_not_take("B BGEU unsigned one !>= max", lambda label: p.bgeu(2, 1, label))
    p.set_case("B backward BNE loop reaches zero")
    p.li(4, 3)
    p.nops()
    p.label("countdown_loop")
    p.addi(4, 4, -1)
    p.nops()
    p.bne(4, 0, "countdown_loop")
    p.nops()
    p.li(6, 0)
    p.nops()
    p.bne(4, 6, "fail")
    p.nops()
    p.finish_pass()
    p.finish_fail()
    return p


def build_u_j_type() -> Program:
    p = Program()
    p.lui(5, 0xABCDE)
    p.nops()
    p.check_reg(5, 0xABCDE000, "U LUI places immediate in upper bits")
    p.lui(5, 0)
    p.nops()
    p.check_reg(5, 0, "U LUI zero immediate")
    p.lui(5, 0xFFFFF)
    p.nops()
    p.check_reg(5, 0xFFFFF000, "U LUI all upper immediate bits")
    auipc_pc = p.auipc(5, 0x00012)
    p.nops()
    p.check_reg(5, auipc_pc + 0x00012000, "U AUIPC adds upper immediate to current PC")
    auipc_pc = p.auipc(5, 0xFFFFF)
    p.nops()
    p.check_reg(5, u32(auipc_pc + 0xFFFFF000), "U AUIPC wraps with high immediate")
    p.set_case("J JAL jumps and writes PC+4 link")
    jal_pc = p.pc
    p.jal(5, "after_jal")
    p.nops()
    p.jal(0, "fail")
    p.label("after_jal")
    p.nops()
    p.li(6, jal_pc + 4)
    p.nops()
    p.bne(5, 6, "fail")
    p.nops()
    p.set_case("J JAL x0 does not clobber a register")
    p.li(5, 0xCAFEBABE)
    p.nops()
    p.jal(0, "after_jal_x0")
    p.nops()
    p.jal(0, "fail")
    p.label("after_jal_x0")
    p.nops()
    p.li(6, 0xCAFEBABE)
    p.nops()
    p.bne(5, 6, "fail")
    p.nops()
    p.set_case("J backward JAL reaches an earlier target once")
    p.li(4, 0)
    p.nops()
    p.jal(0, "after_backward_target")
    p.label("backward_target")
    p.addi(4, 4, 1)
    p.nops()
    p.jal(0, "done_backward_jal")
    p.label("after_backward_target")
    p.jal(0, "backward_target")
    p.label("done_backward_jal")
    p.nops()
    p.li(6, 1)
    p.nops()
    p.bne(4, 6, "fail")
    p.nops()
    p.set_case("I/J JALR clears target bit 0 and writes PC+4 link")
    target_label = "after_jalr"
    p.li(1, 0)
    p.nops()
    p.li(1, 0)
    patch_index = len(p.words) - 1
    p.nops()
    jalr_pc = p.pc
    p.jalr(5, 1, 0)
    p.nops()
    p.jal(0, "fail")
    p.label(target_label)
    target_pc = p.labels[target_label]
    p.words[patch_index] = enc_i(target_pc | 1, 0, 0x0, 1)
    p.li(6, jalr_pc + 4)
    p.nops()
    p.bne(5, 6, "fail")
    p.nops()
    p.set_case("I/J JALR adds immediate before clearing target bit 0")
    p.li(1, 0)
    p.nops()
    p.li(1, 0)
    patch_index = len(p.words) - 1
    p.nops()
    jalr_pc = p.pc
    p.jalr(5, 1, 4)
    p.nops()
    p.jal(0, "fail")
    p.label("after_jalr_imm")
    target_pc = p.labels["after_jalr_imm"]
    p.words[patch_index] = enc_i((target_pc - 3) & 0xFFF, 0, 0x0, 1)
    p.li(6, jalr_pc + 4)
    p.nops()
    p.bne(5, 6, "fail")
    p.nops()
    p.finish_pass()
    p.finish_fail()
    return p


def build_m_type() -> Program:
    p = Program()
    p.li(1, 7)
    p.li(2, 6)
    p.nops()
    p.mulop(5, 1, 2, 0x0)
    p.nops(8)
    p.check_reg(5, 42, "M MUL low word")
    p.li(1, -7)
    p.li(2, 6)
    p.nops()
    p.mulop(5, 1, 2, 0x0)
    p.nops(8)
    p.check_reg(5, u32(-42), "M MUL signed low word negative product")
    p.li(1, 0xFFFFFFFF)
    p.li(2, 2)
    p.nops()
    p.mulop(5, 1, 2, 0x1)
    p.nops(8)
    p.check_reg(5, 0xFFFFFFFF, "M MULH signed high word")
    p.mulop(5, 1, 2, 0x2)
    p.nops(8)
    p.check_reg(5, 0xFFFFFFFF, "M MULHSU signed by unsigned high word")
    p.mulop(5, 1, 2, 0x3)
    p.nops(8)
    p.check_reg(5, 0x00000001, "M MULHU unsigned high word")
    p.li(1, 0x80000000)
    p.li(2, 2)
    p.nops()
    p.mulop(5, 1, 2, 0x1)
    p.nops(8)
    p.check_reg(5, 0xFFFFFFFF, "M MULH int-min times two high word")
    p.mulop(5, 1, 2, 0x3)
    p.nops(8)
    p.check_reg(5, 0x00000001, "M MULHU high bit operand high word")
    p.li(1, -21)
    p.li(2, 4)
    p.nops()
    p.mulop(5, 1, 2, 0x4)
    p.nops(40)
    p.check_reg(5, u32(-5), "M DIV signed truncates toward zero")
    p.mulop(5, 1, 2, 0x6)
    p.nops(40)
    p.check_reg(5, u32(-1), "M REM signed keeps dividend sign")
    p.li(1, -21)
    p.li(2, -4)
    p.nops()
    p.mulop(5, 1, 2, 0x4)
    p.nops(40)
    p.check_reg(5, 5, "M DIV signed negative by negative")
    p.mulop(5, 1, 2, 0x6)
    p.nops(40)
    p.check_reg(5, u32(-1), "M REM signed overflow-style sign rule")
    p.li(1, 21)
    p.li(2, 4)
    p.nops()
    p.mulop(5, 1, 2, 0x5)
    p.nops(40)
    p.check_reg(5, 5, "M DIVU unsigned quotient")
    p.mulop(5, 1, 2, 0x7)
    p.nops(40)
    p.check_reg(5, 1, "M REMU unsigned remainder")
    p.li(1, 3)
    p.li(2, 7)
    p.nops()
    p.mulop(5, 1, 2, 0x5)
    p.nops(40)
    p.check_reg(5, 0, "M DIVU dividend smaller than divisor")
    p.mulop(5, 1, 2, 0x7)
    p.nops(40)
    p.check_reg(5, 3, "M REMU dividend smaller than divisor")
    p.li(1, 0x80000000)
    p.li(2, 0xFFFFFFFF)
    p.nops()
    p.mulop(5, 1, 2, 0x4)
    p.nops(40)
    p.check_reg(5, 0x80000000, "M DIV signed overflow special case")
    p.mulop(5, 1, 2, 0x6)
    p.nops(40)
    p.check_reg(5, 0, "M REM signed overflow special case")
    p.li(1, 0x12345678)
    p.li(2, 0)
    p.nops()
    p.mulop(5, 1, 2, 0x4)
    p.nops(40)
    p.check_reg(5, 0xFFFFFFFF, "M DIV signed divide-by-zero quotient")
    p.mulop(5, 1, 2, 0x6)
    p.nops(40)
    p.check_reg(5, 0x12345678, "M REM signed divide-by-zero remainder")
    p.mulop(5, 1, 2, 0x5)
    p.nops(40)
    p.check_reg(5, 0xFFFFFFFF, "M DIVU divide-by-zero quotient")
    p.mulop(5, 1, 2, 0x7)
    p.nops(40)
    p.check_reg(5, 0x12345678, "M REMU divide-by-zero remainder")
    p.finish_pass()
    p.finish_fail()
    return p


TESTS = {
    "r_type": build_r_type,
    "i_type": build_i_type,
    "load_store_type": build_load_store_type,
    "branch_type": build_branch_type,
    "u_j_type": build_u_j_type,
    "m_type": build_m_type,
}


def write_bin(path: pathlib.Path, words: list[int]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("wb") as f:
        for word in words:
            f.write(int(word).to_bytes(4, byteorder="little", signed=False))


def run_one(name: str, trace: bool, dump: bool, timeout_cycles: int, verbose: bool) -> bool:
    print(f"\n=== build {name} ===")
    program = TESTS[name]()
    words = program.resolve()
    bin_path = GEN_DIR / f"{name}.bin"
    write_bin(bin_path, words)
    print(f"  wrote {bin_path.relative_to(ROOT_DIR)} ({len(words)} instructions)")

    cmd = [
        sys.executable,
        str(SIM_DIR / "compile_and_sim.py"),
        str(bin_path),
        "--timeout-cycles",
        str(timeout_cycles),
    ]
    if trace:
        cmd.append("--trace")
    if dump:
        cmd.append("--dump")

    result = subprocess.run(
        cmd,
        cwd=SIM_DIR,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        timeout=60,
    )
    output = result.stdout
    passed = (
        result.returncode == 0
        and "pass" in output.lower()
        and "fail" not in output.lower()
        and "timeout" not in output.lower()
    )
    print(f"=== result {name}: {'PASS' if passed else 'FAIL'} ===")
    if verbose or not passed:
        print(output.rstrip())
    return passed


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate and run detailed type-level CPU tests.")
    parser.add_argument(
        "tests",
        nargs="*",
        choices=sorted(TESTS),
        help="Optional subset to run. Default: all tests.",
    )
    parser.add_argument("--trace", action="store_true", help="Pass +trace to tb.v.")
    parser.add_argument("--dump", action="store_true", help="Pass +dump to tb.v.")
    parser.add_argument("--timeout-cycles", type=int, default=200000)
    parser.add_argument("--verbose", action="store_true", help="Print simulator output for passing tests too.")
    return parser.parse_args()


def main() -> int:
    os.chdir(SIM_DIR)
    args = parse_args()
    names = args.tests or list(TESTS)
    print("Running detailed instruction-type tests:")
    for name in names:
        print(f"  - {name}")

    failures = []
    for name in names:
        if not run_one(name, args.trace, args.dump, args.timeout_cycles, args.verbose):
            failures.append(name)

    print("\n=== summary ===")
    if failures:
        print("failed: " + ", ".join(failures))
        return 1
    print("all detailed type tests passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
