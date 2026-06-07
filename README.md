# 3-Stage RV32IM Pipeline RISC-V CPU


This project implements a modular **3-Stage Pipeline RV32IM RISC-V CPU (Verilog HDL)**,
with emphasis on micro-architecture clarity, pipeline control, machine-mode trap handling,
and automated verification.


## Table of Contents
- [Repository Layout](#repository-layout)
- [Architecture](#architecture)
  - [3-Stage Pipeline](#3-stage-pipeline)
  - [System Organization](#system-organization)
    - [Core Architecture](#core-architecture)
    - [SoC Structure](#soc-structure)
  - [Hazard Control](#hazard-control)
  - [CSR and Trap Control](#csr-and-trap-control)
- [Implementation Status](#implementation-status)
  - [Implemented](#implemented)
  - [Not Implemented](#not-implemented)
- [Prerequisites](#prerequisites)
- [Simulation & Verification](#simulation--verification)
  - [Test Commands](#test-commands)
  - [Test Result Summary](#test-result-summary)
- [Reference](#reference)





## Repository Layout
```text
rtl/
 ├─ core/                 # CPU pipeline, execution, CSR, and trap modules
 ├─ mem/                  # Instruction ROM and Data RAM
 ├─ soc/                  # SoC wrapper
 └─ utils/                # Shared definitions and utilities

sim/
 ├─ compile_and_sim.py    # Compile RTL and run one binary
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
The processor is implemented as a modular 3-stage pipeline core,
decoupled from SoC integration logic.

The EX stage also handles memory access, CSR execution, and register write-back.


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

The **Core** contains:

- Program counter and pipeline datapath
- IF/ID and ID/EX pipeline registers
- Instruction decoder
- Integer register file
- RV32I execution logic
- Multi-cycle RV32M execution units
- Hazard detection and forwarding logic
- Machine-mode CSR register file
- Trap and interrupt control logic
- Pipeline stall, flush, and redirect control

The Core is responsible for instruction execution, memory access,
trap handling, and register write-back.


#### SoC Structure
![SoC](img/Architecture_soc.png)

The **SoC layer** integrates:

- Core
- Instruction ROM
- Data RAM
- External interrupt input

It acts as a lightweight wrapper for simulation and testing.


### Hazard Control
The current pipeline includes:

- EX-to-ID register forwarding
- Load-use hazard detection
- Load-use pipeline bubble insertion
- Branch and jump pipeline flush
- Multi-cycle MUL/DIV pipeline stall

For a load-use dependency, the control logic holds the PC and IF/ID register,
then flushes ID/EX to insert one pipeline bubble.


### CSR and Trap Control
The Core includes a machine-mode CSR register file and trap controller.

Supported CSR instructions:

- CSRRW / CSRRS / CSRRC
- CSRRWI / CSRRSI / CSRRCI

Implemented CSRs:

- cycle / cycleh
- mstatus
- mie
- mtvec
- mscratch
- mepc
- mcause
- mtval
- mip

Supported trap and return behavior:

- ECALL
- EBREAK
- Illegal instruction
- Invalid CSR access
- Misaligned load
- Misaligned store
- MRET
- Machine external interrupt

Trap entry updates `mepc`, `mcause`, `mtval`, and `mstatus`,
then redirects execution to the aligned `mtvec` base address.




## Implementation Status


### Implemented
- 3-stage pipeline (IF / ID / EX)
- IF/ID and ID/EX pipeline registers
- Register File (2R1W)
- RV32I R / I / B / J / U-type instructions
- Byte / halfword / word Load and Store
- Branch and Jump redirect
- EX-to-ID data forwarding
- Load-use hazard detection and pipeline bubble
- RV32M extension (multi-cycle MUL / DIV / REM)
- Machine-mode CSR instructions
- Machine-mode CSR register file
- Synchronous exception handling
- MRET return flow
- Machine external interrupt
- Automated RV32I / RV32M regression
- Automated CSR / trap / interrupt regression





## Not Implemented
- FENCE / FENCE.I full architectural behavior
- Timer interrupt
- Software interrupt
- Vectored `mtvec` mode
- Multiple privilege levels
- Memory-mapped peripherals
- Standard bus interface
- Cache and branch prediction




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
The design is validated through automated instruction-level,
CSR, exception, and interrupt regression tests.


### Test Commands
Run all commands from the repository root.

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
python sim\test_one_inst.py addi --timeout-cycles 5000
python sim\test_csr.py --verbose
python sim\test_csr.py --trace
```


### Test Result Summary
| Category              | Coverage                                      | Status |
|-----------------------|-----------------------------------------------|--------|
| RV32I Arithmetic      | R-type and I-type instructions                | PASS   |
| Load / Store          | Byte, halfword, and word access               | PASS   |
| Branch / Jump         | B-type, JAL, and JALR                          | PASS   |
| LUI / AUIPC           | U-type instructions                           | PASS   |
| RV32M Extension       | Multiply, divide, and remainder               | PASS   |
| Hazard Control        | Forwarding and load-use dependency            | PASS   |
| CSR Instructions      | Register and immediate CSR operations         | PASS   |
| Synchronous Traps     | ECALL, EBREAK, illegal and misaligned access   | PASS   |
| Trap Return           | MRET                                          | PASS   |
| External Interrupt    | Enable, mask, and pending behavior             | PASS   |

The testbench uses the following pass/fail convention:

```text
x26 = 1    Test finished
x27 = 1    Pass
x27 = 0    Fail
x3         Failed test case ID
```

Generated simulation files such as `sim/inst_data.txt`, `sim/out.vvp`,
waveforms, and Python cache files are not part of the source code.




## Reference
[1] [SI-RISCV Project](https://github.com/SI-RISCV/e200_opensource)
