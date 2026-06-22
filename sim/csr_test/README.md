# CSR / Trap Regression Tests

This folder contains CSR, exception, trap, `mret`, and external interrupt regression tests.

## Layout

```text
sim/csr_test/
  test_all.py
  test_bin/
```

`test_bin/` contains raw CSR/trap test binaries:

```text
rv32csr-p-*.bin
```

## Required Files

The CSR runner expects:

```text
sim/csr_test/test_bin/*.bin
sim/compile_and_sim.py
tb/tb.v
rtl/
```

The `.bin` files are committed test inputs. Generated files stay under `sim/` and are ignored.

## Commands

Run all CSR/trap tests:

```powershell
python sim\csr_test\test_all.py
```

Debug all tests with verbose simulator output:

```powershell
python sim\csr_test\test_all.py --verbose
python sim\csr_test\test_all.py --trace
```

## Testbench Convention

CSR binaries use the existing testbench pass/fail convention:

```text
x26 = 1: test finished
x27 = 1: pass
x27 = 0: fail
x3      : fail case id
```

Some interrupt tests pass extra plusargs from `test_all.py`, for example `+external_irq_cycle`.

## Generated Files

The runner converts each selected `.bin` into:

```text
sim/inst_data.txt
```

`tb/tb.v` reads that file. Do not commit generated files such as `sim/inst_data.txt`, `sim/out.vvp`, waveform files, or Python cache files.
