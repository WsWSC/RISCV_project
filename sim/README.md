# Simulation Layout

This directory keeps simulation runners, generated simulation input, and binary test inputs.

## Files

```text
compile_and_sim.py
```

Compiles the RTL with Icarus Verilog, converts one `.bin` file into `sim/inst_data.txt`, and runs `tb/tb.v`.

```text
test_isa_all.py
```

Runs all normal RV32I/RV32M `.bin` tests under `sim/test_bin/`.

```text
test_isa_one.py
```

Runs one normal RV32I/RV32M test from `sim/test_bin/`.

```text
test_csr_all.py
```

Runs all CSR / exception / interrupt `.bin` tests under `sim/csr_test_bin/`.

```text
inst_data.txt
```

Generated memory image consumed by `tb/tb.v`. This file is produced from the selected `.bin` before each simulation and should not be committed.

## Test Input Folders

```text
test_bin/
```

Normal RV32I/RV32M regression binaries. These are run by `test_isa_all.py` and `test_isa_one.py`.

```text
csr_test_bin/
```

CSR, trap, and interrupt regression binaries. These are run only by `test_csr_all.py`.

## Regression Commands

```powershell
python sim\test_isa_all.py
python sim\test_isa_one.py addi
python sim\test_csr_all.py
```

