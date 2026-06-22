# Simulation

This directory keeps the shared simulation helper and three grouped test flows.

## Prerequisites

Before running the simulation, make sure the following tools are installed:

- **Python 3**
- **Icarus Verilog** (`iverilog` / `vvp`)

Optional:

- **GTKWave** for waveform viewing
- **Questa / ModelSim** for waveform viewing and manual simulation debug

This workspace currently has:

```text
Questa Altera Starter FPGA Edition 2025.2
Intel FPGA Starter Edition ModelSim 2021.1
```

You can verify the installation using:

```powershell
python --version
iverilog -V
vvp -V
vsim -version
```

## Shared Files

`compile_and_sim.py` compiles RTL with Icarus Verilog, converts one `.bin` into `sim/inst_data.txt`, and runs `tb/tb.v`.

`inst_data.txt` and `out.vvp` are generated runtime files and should not be committed.

## Test Flows

| Folder | Purpose | Details |
|--------|---------|---------|
| `isa_test/` | Normal RV32I/RV32M instruction regression. | [isa_test/README.md](isa_test/README.md) |
| `csr_test/` | CSR, exception, trap, `mret`, and external interrupt regression. | [csr_test/README.md](csr_test/README.md) |
| `compliance_test/` | Imported ACT4/Sail golden signature comparison. | [compliance_test/README.md](compliance_test/README.md) |

Each test folder documents its own setup, required files, and run commands.

Run simulation commands sequentially. The runners share `sim/inst_data.txt` and
`sim/out.vvp`, so parallel runs can overwrite each other's generated files.

