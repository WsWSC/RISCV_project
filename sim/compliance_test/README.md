# Compliance Test

## What This Flow Does

This folder runs ACT4/Sail golden signature checks for the DUT.

Golden files are generated in WSL, then copied back into this Windows repo.

This flow uses two external repos in WSL:

- [riscv/riscv-arch-test](https://github.com/riscv/riscv-arch-test)
- [WsWSC/3-stage-riscv-golden-generator](https://github.com/WsWSC/3-stage-riscv-golden-generator)

## Files And Roles

Windows repo:

```text
sim/compliance_test/
  runner.py             # repo file, shared compliance runner
  test_one.py           # repo file, run one compliance test
  test_all.py           # repo file, run all compliance tests
  golden_sig/           # generated, Sail golden signatures
  DUT_metadata/         # generated, per-test metadata
  DUT_runtime/          # generated, binaries/data/output
```

WSL:

```text
~/risc-v/
  riscv-arch-test/                  # official ACT4
  3-stage-riscv-golden-generator/   # golden generator
```

## Setup

Step 0. Install WSL from Windows PowerShell:

```powershell
wsl --install
```

After installation, open Ubuntu from Windows Terminal. The following steps create this WSL layout:

```text
~/risc-v/
  riscv-arch-test/                  # official ACT4
  3-stage-riscv-golden-generator/   # golden generator
```

Step 1. Install required tools in WSL.

The install location is flexible, but WSL must be able to find them:

```bash
which mise
which riscv64-unknown-elf-gcc
which sail_riscv_sim
```

If `sail_riscv_sim` is not in `PATH`, set `SAIL_RISCV_SIM` in `config.env`.

Step 2. Clone the official ACT4 repo in WSL:

```bash
mkdir -p ~/risc-v
cd ~/risc-v
git clone https://github.com/riscv/riscv-arch-test.git
```

Step 3. Clone the golden generator repo in WSL:

```bash
cd ~/risc-v
git clone https://github.com/WsWSC/3-stage-riscv-golden-generator.git
```

Step 4. Create the local generator setting file:

```bash
cd ~/risc-v/3-stage-riscv-golden-generator
cp config.env.example config.env
```

`config.env.example` is only a template. `generate_golden.sh` reads `config.env`.

Step 5. Edit `config.env` and set where golden files should be copied:

```bash
TARGET_REPO=/mnt/c/Users/<windows_user>/Documents/3-stage_RISC-V
```

Main settings in `config.env`:

| Setting | Meaning |
| --- | --- |
| `TARGET_REPO` | Windows repo path as seen from WSL |
| `ACT4_REPO` | Official `riscv-arch-test` path |
| `ACT4_WORK` | Build/cache folder |
| `EXTENSIONS` | ACT4 extensions to build, usually `I M` |

## Run Compliance Tests

Step 1. Generate golden files from WSL:

```bash
cd ~/risc-v/3-stage-riscv-golden-generator
./generate_golden.sh
```

Generated output in this Windows repo:

| Output | Purpose |
| --- | --- |
| `golden_sig/*.sig` | Sail golden signatures |
| `DUT_metadata/*.json` | Per-test metadata |
| `DUT_runtime/bin/*.bin` | DUT binaries |
| `DUT_runtime/data/*.data` | DUT data images |

Expected count: `47` files in each output group.

Step 2. Run compliance tests from Windows PowerShell at the repo root.

```powershell
cd C:\Users\<windows_user>\Documents\3-stage_RISC-V
```

Step 2.1. Run one compliance test:

```powershell
python sim\compliance_test\test_one.py add
python sim\compliance_test\test_one.py beq
```

Step 2.2. Run all compliance tests:

```powershell
python sim\compliance_test\test_all.py
```

Do not run multiple compliance commands in parallel. These scripts share `sim/inst_data.txt` and `sim/out.vvp`.

## Common Failures

| Message / Symptom | Fix |
| --- | --- |
| `missing compliance runtime binary` | Run the WSL golden generator. |
| `sail_riscv_sim` not found | Fix the generator repo `config.env` or WSL `PATH`. |
| `mise` not found | Install `mise` in WSL and reopen the shell. |
| Stale golden files | Regenerate golden files, then rerun the Windows test. |
