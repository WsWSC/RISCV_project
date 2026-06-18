# Normal ISA Test Binaries

This folder contains normal RV32I and RV32M regression binaries.

These tests are intentionally separate from CSR / trap / interrupt tests, which live under:

```text
sim/csr_test_bin/
```

## File Naming

Current naming follows the RISC-V ISA test style:

```text
rv32ui-p-*.bin
rv32um-p-*.bin
```

Meaning:

```text
rv32ui: RV32 user integer tests
rv32um: RV32 multiply/divide extension tests
-p-   : bare-metal processor test naming convention
*.bin : raw little-endian instruction binary
```

## Runners

Run every normal ISA test:

```powershell
python sim\test_isa_all.py
```

Run one normal ISA test:

```powershell
python sim\test_isa_one.py addi
```

## Generated Files

The runner converts each selected `.bin` into:

```text
sim/inst_data.txt
```

The testbench reads that generated file. Do not commit generated files such as:

```text
inst_data.txt
*.dump
*.txt
*.verilog
```

