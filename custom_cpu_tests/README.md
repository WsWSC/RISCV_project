# Custom CPU Tests

This folder contains the custom tests generated for this repository. It is kept
outside `sim/` so the original `sim/test_bin` test cases remain untouched.

## Layout

- `type_coverage/`: broad RV32I/RV32M instruction-type coverage.
- `hazard_forwarding/`: dependency, stall, and forwarding stress tests.
- `csr/`: CSR register, trap, mret, interrupt, and misaligned access tests.

## Run Everything

```powershell
python custom_cpu_tests\run_all.py
```

## Run Individual Suites

```powershell
python custom_cpu_tests\type_coverage\run_type_tests.py
python custom_cpu_tests\hazard_forwarding\run_hazard_forwarding_tests.py
python custom_cpu_tests\csr\run_csr_tests.py
```

The folder is ignored by Git via `.gitignore`.
