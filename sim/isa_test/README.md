# ISA Regression Tests

This folder contains the normal RV32I/RV32M regression flow.

## Layout

```text
sim/isa_test/
  test_all.py
  test_one.py
  test_bin/
```

`test_bin/` contains raw instruction binaries:

```text
rv32ui-p-*.bin
rv32um-p-*.bin
```

## Required Files

The ISA runner expects:

```text
sim/isa_test/test_bin/*.bin
sim/compile_and_sim.py
tb/tb.v
rtl/
```

The `.bin` files are committed test inputs. Generated files stay under `sim/` and are ignored.

## Commands

Run all ISA tests:

```powershell
python sim\isa_test\test_all.py
```

Run one ISA test:

```powershell
python sim\isa_test\test_one.py addi
```

Debug one test:

```powershell
python sim\isa_test\test_one.py addi --trace
python sim\isa_test\test_one.py addi --dump
```

## Generated Files

The runner converts the selected `.bin` into:

```text
sim/inst_data.txt
```

`tb/tb.v` reads that file. Do not commit generated files such as `sim/inst_data.txt`, `sim/out.vvp`, waveform files, or Python cache files.
