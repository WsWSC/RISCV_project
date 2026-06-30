# 3-Stage RV32IM Pipeline RISC-V CPU


This project implements a modular **3-Stage Pipeline RV32IM RISC-V CPU (Verilog HDL)**,
with automated verification for ISA, CSR, trap, interrupt, and imported compliance behavior.


## Table of Contents
- [Repository Layout](#repository-layout)
- [Architecture](#architecture)
  - [3-Stage Pipeline](#3-stage-pipeline)
  - [System Organization](#system-organization)
- [Implementation Status](#implementation-status)
  - [Future Work](#future-work)
- [Simulation & Verification](#simulation--verification)
  - [Test Result Summary](#test-result-summary)
- [Reference](#reference)


## Repository Layout
```text
rtl/
  core/                 # Pipeline core, CSR, and trap modules
  mem/                  # Instruction ROM / Data RAM
  soc/                  # SoC wrapper
  utils/                # Shared definitions & utilities

sim/
  compile_and_sim.py    # Compile and run simulation
  isa_test/             # RV32I / RV32M regression runners and binaries
  csr_test/             # CSR / trap / interrupt regression runner and binaries
  compliance_test/      # Compliance runner and local generated data

tb/
  tb.v                  # Top-level testbench

img/
  Architecture diagrams
```

## Architecture
The processor is a modular 3-stage pipeline core with a small simulation SoC.


### 3-Stage Pipeline
```text
IF -> ID -> EX
```

| Stage | Description                         |
|-------|-------------------------------------|
| IF    | Instruction Fetch                   |
| ID    | Instruction Decode / Register Read  |
| EX    | Execute / Memory / CSR / Write Back |


### System Organization
![SoC Architecture](img/Architecture_soc.png)

The SoC view shows the full 3-stage pipeline system in one diagram. The Core
contains PC generation, IF/ID and ID/EX pipeline registers, decode, register
file, execute / memory / CSR / write-back logic, multi-cycle MUL / DIV units,
trap handling, and pipeline control.

At the SoC level, the Core is integrated with Instruction ROM, Data RAM, and
the RIB (RISC-V Internal Bus). The current RTL uses direct instruction fetch
from `inst_rom` and routes data memory access through `rib` to `data_ram`;
the dotted peripheral blocks in the diagram represent planned RIB expansion
targets.

## Implementation Status

| Item | Status | Completed On | Note |
|------|--------|--------------|------|
| 3-stage pipeline structure | ✅ Done | 2026-01-21 | IF / ID / EX architecture organization |
| RV32I base instructions | ✅ Done | 2026-02-04 | Integer, branch/jump, load/store, write-back |
| RV32M extension | ✅ Done | 2026-02-10 | Single-cycle M extension baseline |
| RV32M multi-cycle MUL | ✅ Done | 2026-03-03 | `MUL`, `MULH`, `MULHSU`, `MULHU` |
| RV32M multi-cycle DIV | ✅ Done | 2026-05-19 | `DIV`, `DIVU`, `REM`, `REMU` |
| Forwarding, load-use bubble | ✅ Done | 2026-05-19 | - |
| Machine CSR, trap, `mret`, MEI | ✅ Done | 2026-06-18 | - |
| CSR regression | ✅ Done | 2026-06-22 | - |
| Architecture compliance tests | ✅ Done | 2026-06-22 | ACT4 tests compared against Sail golden signatures |
| Privileged architecture | ⚠️ Partial | - | Machine-mode subset only |
| RIB | 🔄 Ongoing | - | RISC-V Internal Bus |

### Future Work

| Item | Status | Note |
|------|--------|------|
| Timer/software interrupt | ⛔ Not Implemented | Future CLINT extension |
| Vectored `mtvec` | ⛔ Not Implemented | Optional trap mode |
| MMIO/standard bus | ⛔ Not Implemented | After RIB |

<br>

## Simulation & Verification
The design is validated through Python-driven Icarus Verilog regression tests.
See [sim/README.md](sim/README.md) for the ISA, CSR, and ACT4/Sail compliance
flows.


### Test Result Summary
| Category | Coverage | Status | Note |
|----------|----------|--------|------|
| ISA regression | RV32I/RV32M, load/store, branch/jump | ✅ | - |
| Hazard handling | Forwarding, load-use bubble | ✅ | - |
| CSR/trap regression | CSR ops, exceptions, `mret` | ✅ | - |
| Interrupt handling | External interrupt enable/mask/pending | ✅ | - |
| ACT4/Sail compliance | Golden signature comparison | ✅ | Local golden files |

Generated files such as `sim/inst_data.txt`, `sim/out.vvp`, waveform files,
Python cache files, and compliance runtime/golden folders are not part of the
source code.

## Reference
[1] [SI-RISCV Project](https://github.com/SI-RISCV/e200_opensource)
