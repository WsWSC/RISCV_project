# 3-Stage RV32IM Pipeline RISC-V CPU


This project implements a modular **3-Stage Pipeline RV32IM RISC-V CPU (Verilog HDL)**,
with automated verification for ISA, CSR, trap, interrupt, and imported compliance behavior.


## Table of Contents
- [Repository Layout](#repository-layout)
- [Architecture](#architecture)
  - [3-Stage Pipeline](#3-stage-pipeline)
  - [System Organization](#system-organization)
    - [Core Architecture](#core-architecture)
    - [SoC Structure](#soc-structure)
- [Implementation Status](#implementation-status)
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
The processor is organized into two major layers:

- **Core**
- **SoC**


#### Core Architecture
![Core](img/Architecture_core.png)

The **Core** contains the pipeline datapath, register file, ALU, load/store logic,
multi-cycle RV32M units, forwarding / hazard control, CSR registers, and trap control.


#### SoC Structure
![SoC](img/Architecture_soc.png)

The **SoC layer** integrates the Core, Instruction ROM, Data RAM, and external interrupt input.

## Implementation Status

| Item | Status | Note |
|------|--------|------|
| RV32IM 3-stage pipeline | ✅ | - |
| IF/ID, ID/EX registers | ✅ | - |
| Load/store, branch/jump, write-back | ✅ | - |
| Forwarding, load-use bubble | ✅ | - |
| Machine CSR, trap, `mret`, MEI | ✅ | - |
| RV32I/RV32M, CSR regression | ✅ | - |
| ACT4/Sail compliance | ✅ | Local golden checks |
| Privileged architecture | | - |
| Timer/software interrupt | | - |
| Vectored `mtvec` | | - |
| RIB | | RISC-V Internal Bus |
| MMIO/standard bus | | - |
| Cache/branch prediction | | - |

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
