# ISA Regression Tests

This folder contains the tracked RV32I/RV32M instruction regression flow.

## Layout

```text
sim/isa_test/
  test_all.py           # run all tests
  test_one.py           # run one test
  test_bin/             # committed test binaries
```

Test binaries:

```text
rv32ui-p-*.bin
rv32um-p-*.bin
```

Current tracked coverage is 47 binaries: RV32I base instruction tests plus
RV32M multiply/divide tests.

<br>

## Required Files

Required inputs:

```text
sim/isa_test/test_bin/*.bin
sim/compile_and_sim.py
tb/tb.v
rtl/
```

The `.bin` files are committed test inputs. Runtime outputs stay under `sim/`
and are ignored.

These legacy binaries use the original Harvard data address space. The ISA
runners compile the RTL with `TEST_ZERO_BASED_RAM_MAP`; new software should use the
default SoC map with Data RAM at `0x1000_0000`.

<br>

## Commands

Run commands from the repo root:

Run all tests:

```powershell
python sim\isa_test\test_all.py
```

Run one test:

```powershell
python sim\isa_test\test_one.py addi
```

The test name is matched against files under `sim/isa_test/test_bin/`. Use a
specific instruction name such as `addi`, `lw`, `mul`, or `remu`.

<br>

## Debug Options

| Option | Effect |
| --- | --- |
| `--trace` | Print per-cycle CPU trace from `tb.v`. |
| `--dump` | Generate `sim/tb.vcd` waveform. |
| `--verbose` | Print simulator output for passing tests. |
| `--timeout-cycles N` | Override the testbench timeout cycle count. |

```powershell
python sim\isa_test\test_one.py addi --trace
python sim\isa_test\test_one.py addi --dump
python sim\isa_test\test_all.py --verbose
python sim\isa_test\test_one.py addi --timeout-cycles 2000
```

<br>

## Testbench Convention

ISA binaries use the existing testbench pass/fail convention:

```text
x26 = 1 : test finished
x27 = 1 : pass
x27 = 0 : fail
x3      : fail case id
```

<br>

## Generated Files

The runner converts each selected `.bin` into:

```text
sim/inst_data.txt
```

`tb/tb.v` reads that file. Do not commit generated files such as
`sim/inst_data.txt`, `sim/out.vvp`, `sim/tb.vcd`, or Python cache files.
