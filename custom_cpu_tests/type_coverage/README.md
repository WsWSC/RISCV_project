# Detailed Type Tests

This folder contains self-checking tests that cover every implemented instruction
type in this RV32IM core:

- `r_type`: RV32I register-register ALU operations, overflow wraparound, signed/unsigned compares, masked shift amounts, and `x0` write suppression.
- `i_type`: immediate ALU operations, 12-bit immediate edges, signed/unsigned compares, and shift-immediate edge amounts.
- `load_store_type`: `LB/LH/LW/LBU/LHU` plus `SB/SH/SW`, byte lanes, halfword lanes, sign/zero extension, and ignored misaligned load/store cases.
- `branch_type`: taken and not-taken `BEQ/BNE/BLT/BGE/BLTU/BGEU`, plus a backward branch loop.
- `u_j_type`: `LUI/AUIPC/JAL/JALR`, high-immediate wraparound, `JAL x0`, backward `JAL`, and `JALR` odd-target clearing.
- `m_type`: RV32M multiply/divide/remainder operations, signed/unsigned high-product variants, divide-by-zero, overflow, and small-dividend cases.

The current suite has 95 self-checking cases across the six groups.

Run all tests from the repository root:

```powershell
python custom_cpu_tests\type_coverage\run_type_tests.py
```

Run one group:

```powershell
python custom_cpu_tests\type_coverage\run_type_tests.py r_type
```

Useful debug options:

```powershell
python custom_cpu_tests\type_coverage\run_type_tests.py branch_type --trace --verbose
python custom_cpu_tests\type_coverage\run_type_tests.py load_store_type --dump
```

The script generates binaries under `custom_cpu_tests/type_coverage/generated_bin/` and then
uses the existing `sim/compile_and_sim.py` flow. It follows the original
testbench convention: `x26 = 1` means finished, `x27 = 1` means pass, and `x3`
holds the failing case number.
