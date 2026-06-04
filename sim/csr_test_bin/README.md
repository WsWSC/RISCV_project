# CSR Test Binaries

This folder is reserved for CSR and exception regression binaries.

Planned binary naming:

```text
csr-p-csrrw.bin
csr-p-csrrs.bin
csr-p-csrrc.bin
csr-p-csrrwi.bin
csr-p-csrrsi.bin
csr-p-csrrci.bin
csr-p-mret.bin
csr-p-ecall.bin
csr-p-ebreak.bin
csr-p-illegal.bin
csr-p-misalign-load.bin
csr-p-misalign-store.bin
```

Current policy:

```text
- Do not include this folder in normal RV32I/RV32M regression yet.
- Do not add placeholder .bin files until the CSR RTL and testbench flow are finalized.
- Only commit CSR .bin files after each test has a clear pass/fail convention.
```

Expected pass/fail convention will follow the existing testbench style:

```text
x26 = 1: test finished
x27 = 1: pass
x27 = 0: fail
x3      : fail case id
```

