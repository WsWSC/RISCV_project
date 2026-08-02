# CSR / Trap Regression Tests

This folder contains the tracked CSR/trap/interrupt regression flow.

## Layout

```text
sim/csr_test/
  test_all.py           # run all tests
  test_bin/             # committed test binaries
```

Test binaries:

```text
rv32csr-p-*.bin
```

Current tracked coverage is 33 binaries.

<br>

## Required Files

Required inputs:

```text
sim/csr_test/test_bin/*.bin
sim/compile_and_sim.py
tb/tb.v
rtl/
```

The `.bin` files are committed test inputs. Runtime outputs stay under `sim/`
and are ignored.

These legacy binaries use the original Harvard data address space. The CSR
runner compiles the RTL with `LEGACY_HARVARD_MAP`; new software should use the
default SoC map with Data RAM at `0x1000_0000`.

<br>

## Commands

Run commands from the repo root:

Run all tests:

```powershell
python sim\csr_test\test_all.py
```

<br>

## Debug Options

| Option | Effect |
| --- | --- |
| `--trace` | Print per-cycle CPU trace from `tb.v`. |
| `--dump` | Generate `sim/tb.vcd` waveform. |
| `--verbose` | Print simulator output for passing tests. |
| `--timeout-cycles N` | Override the testbench timeout cycle count. |

```powershell
python sim\csr_test\test_all.py --verbose
python sim\csr_test\test_all.py --trace
python sim\csr_test\test_all.py --dump
python sim\csr_test\test_all.py --timeout-cycles 2000
```

<br>

## Testbench Convention

CSR binaries use the existing testbench pass/fail convention:

```text
x26 = 1 : test finished
x27 = 1 : pass
x27 = 0 : fail
x3      : fail case id
```

External interrupt tests pass extra plusargs from `test_all.py`, for example
`+external_irq_cycle`.

<br>

## Generated Files

The runner converts each selected `.bin` into:

```text
sim/inst_data.txt
```

`tb/tb.v` reads that file. Do not commit generated files such as
`sim/inst_data.txt`, `sim/out.vvp`, `sim/tb.vcd`, or Python cache files.
