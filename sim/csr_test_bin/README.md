# CSR Test Binaries

This folder contains CSR and exception regression binaries.

It is intentionally separate from `sim/test_bin/` so normal RV32I/RV32M regression can stay stable while CSR and trap behavior is tested by its own runner.

## Layout

```text
sim/
  test_csr.py
  csr_test_bin/
    rv32csr-p-*.bin
```

## File Names

CSR instruction tests:

```text
rv32csr-p-csrrw.bin
rv32csr-p-csrrs.bin
rv32csr-p-csrrc.bin
rv32csr-p-csrrwi.bin
rv32csr-p-csrrsi.bin
rv32csr-p-csrrci.bin
rv32csr-p-mscratch.bin
```

Synchronous trap and return tests:

```text
rv32csr-p-mret.bin
rv32csr-p-ecall.bin
rv32csr-p-ebreak.bin
rv32csr-p-illegal_inst.bin
rv32csr-p-misaligned_load.bin
rv32csr-p-misaligned_store.bin
rv32csr-p-mtvec_align.bin
rv32csr-p-trap_flush.bin
```

CSR access validation tests:

```text
rv32csr-p-invalid_csr.bin
rv32csr-p-readonly_csr_write.bin
```

Interrupt tests:

```text
rv32csr-p-external_irq.bin
rv32csr-p-external_irq_masked.bin
rv32csr-p-external_irq_pending_latch.bin
```

## Pass/Fail Convention

CSR binaries follow the existing testbench convention:

```text
x26 = 1: test finished
x27 = 1: pass
x27 = 0: fail
x3      : fail case id
```

## Regression Policy

This folder is not scanned by `sim/test_all.py`.

CSR tests are run by:

```text
python sim/test_csr.py
```

That runner scans only this folder and should not affect normal RV32I/RV32M regression.

## Generated Files

The runners convert each source `.bin` into:

```text
sim/inst_data.txt
```

That file is generated simulation input and should not be committed.
