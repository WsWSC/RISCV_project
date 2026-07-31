# Simulation

This directory keeps the shared Icarus Verilog simulation helper and the
tracked regression flows.

## Prerequisites

Before running the simulation, make sure the following tools are installed:

- **Python 3**
- **Icarus Verilog** (`iverilog` / `vvp`)

Optional:

- **GTKWave** for waveform viewing
- **Questa / ModelSim** for waveform viewing and manual simulation debug

You can verify the installation using:

```powershell
python --version
iverilog -V
vvp -V
vsim -version
```

<br>

## Shared Helper

`compile_and_sim.py` compiles the RTL with Icarus Verilog, converts one `.bin`
file into `sim/inst_data.txt`, and runs `tb/tb.v`.

It can also run one binary directly:

```powershell
python sim\compile_and_sim.py sim\isa_test\test_bin\rv32ui-p-addi.bin
python sim\compile_and_sim.py sim\isa_test\test_bin\rv32ui-p-addi.bin --trace
python sim\compile_and_sim.py sim\isa_test\test_bin\rv32ui-p-addi.bin --dump
```

`sim/inst_data.txt`, `sim/out.vvp`, and waveform files are generated runtime
files and should not be committed.

<br>

## Test Flows

| Folder | Purpose | Details |
|--------|---------|---------|
| `isa_test/` | RV32I/RV32M instruction regression. | [isa_test/README.md](isa_test/README.md) |
| `csr_test/` | CSR, exception, trap, `mret`, and external interrupt regression. | [csr_test/README.md](csr_test/README.md) |
| `compliance_test/` | ACT4/Sail golden signature comparison. | [compliance_test/README.md](compliance_test/README.md) |

Each test folder documents its own setup, required files, and run commands.

Run these flows sequentially. They share `sim/inst_data.txt`, `sim/out.vvp`,
and optional waveform output.
