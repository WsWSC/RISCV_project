# Compliance Test Flow

This folder contains the Windows-side runner for ACT4/Sail golden signature checks.

The golden generator is intentionally kept outside this Git repository in WSL, because it depends on ACT4, Sail, and the RISC-V toolchain.

## Layout

```text
sim/compliance_test/
  runner.py
  README.md
  golden/       local Sail golden signatures and metadata, ignored
  .runtime/     local DUT binaries, data images, and current.sig, ignored
```

```text
~/risc-v/test-golden-generator/
  generate_golden.sh
  act4_config/
  env/
  scripts/
```

The WSL folder generates ACT4/Sail outputs and exports only the local files needed by this repo.

## What Is Committed

Commit these files:

```text
sim/compliance_test/runner.py
sim/compliance_test/README.md
sim/test_compliance_one.py
sim/test_compliance_all.py
```

Do not commit these local/generated files:

```text
sim/compliance_test/golden/
sim/compliance_test/.runtime/
sim/compliance_test/bin/
sim/compliance_test/asm/
sim/compliance_test/ref/
sim/compliance_test/act4_config/
sim/compliance_test/env/
sim/compliance_test/import_act4_outputs.py
sim/compliance_test/generate_golden.ps1
```

## Generate Golden And Runtime Files

Run this from WSL:

```bash
cd ~/risc-v/test-golden-generator
./generate_golden.sh
```

This runs ACT4/Sail for `I` and `M`, then exports:

```text
sim/compliance_test/golden/ref/*.sig
sim/compliance_test/golden/meta/*.json
sim/compliance_test/.runtime/bin/*.bin
sim/compliance_test/.runtime/data/*.data
```

Expected count for the current RV32IM setup:

```text
golden/ref/*.sig       47
golden/meta/*.json     47
.runtime/bin/*.bin     47
.runtime/data/*.data   47
```

## Run Compliance Tests

From the Windows repo root:

```powershell
python sim\test_compliance_one.py add
python sim\test_compliance_one.py beq
python sim\test_compliance_one.py sw
python sim\test_compliance_one.py div
```

Run all imported compliance tests:

```powershell
python sim\test_compliance_all.py
```

The full run is slow because ACT4 binaries are large.

## How The Check Works

The runner loads the DUT binary from:

```text
sim/compliance_test/.runtime/bin/
```

It loads data RAM init from:

```text
sim/compliance_test/.runtime/data/
```

It reads signature range, `tohost`, and golden path from:

```text
sim/compliance_test/golden/meta/
```

The testbench dumps the DUT signature to:

```text
sim/compliance_test/.runtime/out/current.sig
```

Then the runner compares:

```text
current.sig == golden/ref/<test>.sig
```

`tohost` only means the test reached done/fail. PASS requires the signature to match the Sail golden.

## If Runtime Files Are Missing

This message means `.runtime/bin` has not been exported yet:

```text
missing compliance runtime binary
run WSL golden/runtime generation first
```

Fix it by running:

```bash
cd ~/risc-v/test-golden-generator
./generate_golden.sh
```

## WSL Tool Locations

Current local setup:

```text
~/risc-v/test-golden-generator/
~/risc-v/riscv-arch-test/
~/risc-v/arch-test-compile/act4_work/
~/risc-v/tools/bin/sail_riscv_sim
```

These paths are local machine setup, not source files for this repository.
