# CSR Test Binaries

This folder is reserved for CSR and exception regression binaries.

It is intentionally separate from `sim/test_bin/` so normal RV32I/RV32M regression can stay stable while CSR and trap behavior is still being defined.

## Current Scope

This branch only establishes the folder and documentation.

Do not add executable CSR `.bin` files here until all of the following are true:

```text
- CSR RTL behavior is finalized enough to test.
- The testbench pass/fail convention is confirmed.
- The binary is known to run and report PASS/FAIL deterministically.
- The test is ready to be included in a CSR-specific regression flow.
```

## Planned File Names

CSR instruction tests:

```text
csr-p-csrrw.bin
csr-p-csrrs.bin
csr-p-csrrc.bin
csr-p-csrrwi.bin
csr-p-csrrsi.bin
csr-p-csrrci.bin
```

Synchronous trap and return tests:

```text
csr-p-mret.bin
csr-p-ecall.bin
csr-p-ebreak.bin
csr-p-illegal.bin
csr-p-misalign-load.bin
csr-p-misalign-store.bin
```

Future interrupt tests, only after interrupt behavior is stable:

```text
csr-p-external-irq.bin
csr-p-external-irq-masked.bin
csr-p-timer-irq.bin
```

## Pass/Fail Convention

CSR binaries should follow the existing testbench convention unless the testbench flow is intentionally changed later:

```text
x26 = 1: test finished
x27 = 1: pass
x27 = 0: fail
x3      : fail case id
```

## Regression Policy

This folder should not be scanned by `sim/test_all.py`.

When CSR tests are ready, add a separate CSR runner, for example:

```text
sim/test_csr.py
```

That runner should scan only this folder and should not affect normal RV32I/RV32M regression.

## Do Not Commit Yet

Until the CSR flow is stable, do not commit:

```text
- empty placeholder .bin files
- generated inst_data.txt files
- temporary VVP/VCD artifacts
- experimental CSR tests that do not have deterministic PASS/FAIL behavior
```
