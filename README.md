# 3-Stage RV32IM Pipeline RISC-V CPU


This project implements a modular **3-Stage Pipeline RV32IM RISC-V CPU (Verilog HDL)**,
with automated verification for ISA, CSR, trap, and interrupt behavior.


## Table of Contents
- [Repository Layout](#repository-layout)
- [Architecture](#architecture)
  - [3-Stage Pipeline](#3-stage-pipeline)
  - [System Organization](#system-organization)
    - [Core Architecture](#core-architecture)
    - [SoC Structure](#soc-structure)
- [Implementation Status](#implementation-status)
  - [Implemented](#implemented)
  - [Not Implemented](#not-implemented)
- [Prerequisites](#prerequisites)
- [Simulation & Verification](#simulation--verification)
  - [Test Result Summary](#test-result-summary)
- [Reference](#reference)


## Repository Layout
```text
rtl/
 ├─ core/                 # Pipeline core, CSR, and trap modules
 ├─ mem/                  # Instruction ROM / Data RAM
 ├─ soc/                  # SoC wrapper
 └─ utils/                # Shared definitions & utilities

sim/
 ├─ compile_and_sim.py    # Compile and run simulation
 ├─ test_all.py           # RV32I / RV32M regression
 ├─ test_one_inst.py      # Single instruction test
 ├─ test_csr.py           # CSR / trap / interrupt regression
 ├─ test_bin/             # RV32I / RV32M test binaries
 └─ csr_test_bin/         # CSR / trap / interrupt test binaries

tb/
 └─ tb.v                  # Top-level testbench

img/
 └─ Architecture diagrams
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


### Implemented
- 3-stage RV32IM pipeline core
- IF/ID and ID/EX pipeline registers
- Load / store, branch / jump, and write-back logic
- EX-to-ID forwarding and load-use bubble
- Machine-mode CSR, trap, `mret`, and external interrupt support
- RV32I / RV32M and CSR / trap / interrupt regression tests


## Not Implemented
- Full privileged architecture
- Timer / software interrupt
- Vectored `mtvec`
- RIB (RISC-V Internal Bus)
- MMIO peripherals / standard bus
- Cache / branch prediction

## Prerequisites
Before running the simulation, make sure the following tools are installed:

- **Python 3**
- **Icarus Verilog** (`iverilog` / `vvp`)

Optional:

- **GTKWave** for waveform viewing

You can verify the installation using:

```powershell
python --version
iverilog -V
vvp -V
```

## Simulation & Verification
The design is validated through Python-driven Icarus Verilog regression tests.

```powershell
# Run all RV32I / RV32M instruction tests
python sim\test_all.py

# Run one instruction test
python sim\test_one_inst.py addi

# Run all CSR / trap / interrupt tests
python sim\test_csr.py
```

Debug options:

```powershell
python sim\test_one_inst.py addi --trace
python sim\test_one_inst.py addi --dump
python sim\test_csr.py --verbose
python sim\test_csr.py --trace
```


### Test Result Summary
| Category           | Coverage                            | Status |
|--------------------|-------------------------------------|--------|
| RV32I / RV32M      | Integer, load/store, branch, M-ext  | PASS   |
| Pipeline Hazards   | Forwarding and load-use bubble      | PASS   |
| CSR / Trap         | CSR ops, exceptions, `mret`         | PASS   |
| External Interrupt | Enable, mask, pending behavior      | PASS   |

Generated files such as `sim/inst_data.txt`, `sim/out.vvp`, waveform files,
and Python cache files are not part of the source code.

## Reference
[1] [SI-RISCV Project](https://github.com/SI-RISCV/e200_opensource)
