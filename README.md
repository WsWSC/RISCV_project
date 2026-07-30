# 3-Stage RV32IM Pipeline RISC-V CPU

This project implements a modular **3-Stage Pipeline RV32IM RISC-V CPU
(Verilog HDL)**, with automated verification for ISA, CSR, trap, interrupt, and
imported compliance behavior.


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
  core/                 # Pipeline core, CSR, CLINT, RIB, and pipeline control
  perips/               # inst_rom, data_ram, timer, uart
  soc/                  # SoC wrapper
  utils/                # Shared definitions and utility registers

sim/
  compile_and_sim.py    # Compile and run simulation
  isa_test/             # RV32I / RV32M regression runners and binaries
  csr_test/             # CSR / trap / interrupt regression runner and binaries
  compliance_test/      # Compliance runner and local generated data

tb/
  tb.v                  # Top-level testbench

img/
  Arichtecture-core.drawio.png
  Arichtecture.drawio
```

## Architecture
The processor is a modular 3-stage pipeline core with a small simulation SoC.


### 3-Stage Pipeline
```text
IF -> ID -> EX
```

| Stage | Description |
|-------|-------------|
| IF | Instruction Fetch |
| ID | Instruction Decode / Register Read |
| EX | Execute / Memory / CSR / Write Back |


### System Organization
![Core Architecture](img/Arichtecture-core.drawio.png)

The SoC view shows the current 3-stage pipeline system in one diagram. The Core
contains PC generation, IF/ID and ID/EX pipeline registers, decode, register
file, execute / memory / CSR / write-back logic, multi-cycle MUL / DIV units,
CLINT trap/interrupt handling, and pipeline control.

At the SoC level, the Core connects to `rib` as two active masters:
instruction fetch and load/store memory access. The RIB then routes requests to
`inst_rom`, `data_ram`, `timer`, and `uart`. Data memory access has priority
over instruction fetch, so the RIB can stall IF and inject a fetch bubble while
load/store traffic is using the bus.

Current SoC external signals:

| Signal | Direction | Description |
|--------|-----------|-------------|
| `external_irq_i` | Input | Machine external interrupt source |
| `uart_rx_i` | Input | UART RX pin |
| `uart_tx_o` | Output | UART TX pin |

Current RIB MMIO map:

| Address | Register | Access | Description |
|---------|----------|--------|-------------|
| `0x2000_0000` | `TIMER_CTRL` | RW | `[0] enable`, `[1] clear count` |
| `0x2000_0004` | `TIMER_COUNT` | RW | Current timer counter |
| `0x2000_0008` | `TIMER_COMPARE` | RW | Compare threshold |
| `0x2000_000c` | `TIMER_STATUS` | RO | `[0] count >= compare` |
| `0x3000_0000` | `UART_CTRL` | RW | `[0] TX enable`, `[1] RX enable` |
| `0x3000_0004` | `UART_STATUS` | RW/RO | `[0] TX busy`, `[1] RX done / clear` |
| `0x3000_0008` | `UART_BAUD` | RW | UART baud divider |
| `0x3000_000c` | `UART_TXDATA` | WO | TX byte write |
| `0x3000_0010` | `UART_RXDATA` | RO | RX byte read |

## Implementation Status

| Item | Status | Completed On | Note |
|------|--------|--------------|------|
| 3-stage pipeline structure | Done | 2026-01-21 | IF / ID / EX architecture organization |
| RV32I base instructions | Done | 2026-02-04 | Integer, branch/jump, load/store, write-back |
| RV32M extension | Done | 2026-02-10 | RV32M instruction decode / execute support |
| RV32M multi-cycle MUL | Done | 2026-03-03 | `MUL`, `MULH`, `MULHSU`, `MULHU` |
| RV32M multi-cycle DIV | Done | 2026-05-19 | `DIV`, `DIVU`, `REM`, `REMU` |
| Forwarding, load-use bubble | Done | 2026-05-19 | - |
| Machine CSR, trap, `mret`, MEI | Done | 2026-06-18 | - |
| CSR regression | Done | 2026-06-22 | - |
| Architecture compliance tests | Done | 2026-06-22 | ACT4 tests compared against Sail golden signatures |
| RIB grant / MMIO decode | Done | 2026-07-24 | MEM has priority over IF, zero-wait read path kept |
| Timer MMIO | Done | 2026-07-23 | Zero-wait RIB slave at `0x2000_0000` |
| Timer interrupt | Done | 2026-07-24 | Timer MTIP / MTIE through CSR and CLINT |
| UART TX/RX peripheral | Done | 2026-07-28 | TX/RX FSM and register map |
| UART RIB slave | Done | 2026-07-29 | MMIO slave at `0x3000_0000` |
| Privileged architecture | Partial | - | Machine-mode subset only |
| RIB | Ongoing | - | Reserved slots remain for GPIO/SPI/debug expansion |

### Future Work

| Item | Status | Note |
|------|--------|------|
| Vectored `mtvec` | Not Implemented | Optional trap mode |
| GPIO/SPI MMIO | Not Implemented | Future RIB peripherals |
| UART interrupt / FIFO | Not Implemented | Future UART extensions |

<br>

## Simulation & Verification
The design is validated through Python-driven Icarus Verilog regression tests.
See [sim/README.md](sim/README.md) for the ISA, CSR, and ACT4/Sail compliance
flows.


### Test Result Summary
| Category | Coverage | Status | Note |
|----------|----------|--------|------|
| ISA regression | RV32I/RV32M, load/store, branch/jump | Pass | `fence_i` is a known gap |
| Hazard handling | Forwarding, load-use bubble | Pass | - |
| CSR/trap regression | CSR ops, exceptions, `mret` | Pass | - |
| Interrupt handling | External interrupt and timer interrupt | Pass | MEI + MTI machine-mode subset |
| ACT4/Sail compliance | Golden signature comparison | Pass | Local golden files |

Generated files such as `sim/inst_data.txt`, `sim/out.vvp`, waveform files,
Python cache files, and compliance runtime/golden folders are not part of the
source code.

## Reference
[1] [SI-RISCV Project](https://github.com/SI-RISCV/e200_opensource)
