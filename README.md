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

| Item | Status | Completed Date / Note |
|------|--------|-----------------------|
| 3-stage RV32IM pipeline core | Done | - |
| IF/ID and ID/EX pipeline registers | Done | - |
| Load / store, branch / jump, and write-back logic | Done | - |
| EX-to-ID forwarding and load-use bubble | Done | - |
| Machine-mode CSR, trap, `mret`, and external interrupt support | Done | - |
| RV32I / RV32M and CSR / trap / interrupt regression tests | Done | - |
| Imported ACT4/Sail compliance runner for local golden signature checks | Done | Local golden signature checks |
| Full privileged architecture | | - |
| Timer / software interrupt | | - |
| Vectored `mtvec` | | - |
| RIB (RISC-V Internal Bus) | | - |
| MMIO peripherals / standard bus | | - |
| Cache / branch prediction | | - |

<br>

## Simulation & Verification
The design is validated through Python-driven Icarus Verilog regression tests.
See [sim/README.md](sim/README.md) for the ISA, CSR, and ACT4/Sail compliance
flows.


### Test Result Summary
| Category           | Coverage                            | Status |
|--------------------|-------------------------------------|--------|
| RV32I / RV32M      | Integer, load/store, branch, M-ext  | PASS   |
| Pipeline Hazards   | Forwarding and load-use bubble      | PASS   |
| CSR / Trap         | CSR ops, exceptions, `mret`         | PASS   |
| External Interrupt | Enable, mask, pending behavior      | PASS   |
| ACT4 / Sail Import | Local golden signature comparison   | Local  |

Generated files such as `sim/inst_data.txt`, `sim/out.vvp`, waveform files,
Python cache files, and compliance runtime/golden folders are not part of the
source code.

## Reference
[1] [SI-RISCV Project](https://github.com/SI-RISCV/e200_opensource)
