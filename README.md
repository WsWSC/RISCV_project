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
  - [Implemented](#implemented)
  - [Not Implemented](#not-implemented)
- [Prerequisites](#prerequisites)
- [Simulation & Verification](#simulation--verification)
  - [Compliance / ACT4 Flow](#compliance--act4-flow)
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
  test_isa_all.py       # RV32I / RV32M regression
  test_isa_one.py       # Single instruction test
  test_csr_all.py       # CSR / trap / interrupt regression
  test_compliance_all.py # Imported ACT4/Sail compliance regression
  test_compliance_one.py # Single imported compliance test
  compliance_test/      # Compliance runner and local generated data
  test_bin/             # RV32I / RV32M test binaries
  csr_test_bin/         # CSR / trap / interrupt test binaries

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


### Implemented
- 3-stage RV32IM pipeline core
- IF/ID and ID/EX pipeline registers
- Load / store, branch / jump, and write-back logic
- EX-to-ID forwarding and load-use bubble
- Machine-mode CSR, trap, `mret`, and external interrupt support
- RV32I / RV32M and CSR / trap / interrupt regression tests
- Imported ACT4/Sail compliance runner for local golden signature checks


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
python sim\test_isa_all.py

# Run one instruction test
python sim\test_isa_one.py addi

# Run all CSR / trap / interrupt tests
python sim\test_csr_all.py
```

Debug options:

```powershell
python sim\test_isa_one.py addi --trace
python sim\test_isa_one.py addi --dump
python sim\test_csr_all.py --verbose
python sim\test_csr_all.py --trace
```

### Compliance / ACT4 Flow
The ACT4/Sail compliance flow is split between this Windows repository and a WSL
generator environment. This is intentional: ACT4, Sail, and the RISC-V toolchain
are Linux-oriented, while this repo stays focused on RTL simulation and checked-in
source files.

Responsibility split:

```text
This Git repository:
  RTL, testbench, Python runners, and documentation
  sim/compliance_test/runner.py
  sim/test_compliance_one.py
  sim/test_compliance_all.py

Windows local generated data, ignored by Git:
  sim/compliance_test/golden/
  sim/compliance_test/.runtime/
  sim/compliance_test/bin/
  sim/compliance_test/asm/
  sim/compliance_test/ref/

WSL generator environment, outside this repo:
  ACT4 config
  Sail simulator
  RISC-V toolchain
  golden/runtime generation scripts
```

Generate or refresh compliance golden/runtime files from WSL:

```bash
cd ~/risc-v/test-golden-generator
./generate_golden.sh
```

Then run the imported compliance tests from the Windows repo root:

```powershell
python sim\test_compliance_one.py add
python sim\test_compliance_all.py
```

The Windows runner consumes local generated files from:

```text
sim/compliance_test/golden/meta/
sim/compliance_test/golden/ref/
sim/compliance_test/.runtime/bin/
sim/compliance_test/.runtime/data/
```

Do not commit these generated folders. If compliance tests fail because runtime
files are missing or stale, refresh them from WSL first, then rerun the Windows
test command.


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
