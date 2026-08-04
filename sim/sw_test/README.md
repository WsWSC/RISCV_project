# Software Simulation Tests

This folder is the Windows CPU-repo side of the bare-metal software test flow.
It does not own the software source code. Source, linker scripts, startup code,
ELF files, and generated binaries stay in the WSL repository:

```text
/home/wswsc/risc-v/3-Stage-RISC-V-Bare-Metal-Test
```

`sim/sw_test` only runs a WSL-built `.bin` through the RTL simulation and checks
the DUT result.

<br>

## Role

Input:

```text
WSL 03_BIN/*.bin
```

Output:

```text
PASS / FAIL / timeout
```

The runner should:

1. Receive a `.bin` path from the WSL bare-metal test repo.
2. Reuse `sim/compile_and_sim.py` to generate `sim/inst_data.txt`.
3. Run `tb/tb.v` with the default SoC memory map.
4. Check the existing software result protocol:

```text
x26 = 0  program running
x26 = 1  program finished
x27 = 0  FAIL
x27 = 1  PASS
```

5. For UART tests, also check decoded UART TX bytes.

<br>

## Memory Map

SW tests use the default SoC memory map:

```text
0x0000_0000 -> inst_rom
0x1000_0000 -> data_ram
0x2000_0000 -> timer
0x3000_0000 -> uart
```

Do not compile these tests with `TEST_ZERO_BASED_RAM_MAP`. That define is only
for prebuilt ISA, CSR, and compliance regression binaries.

<br>

## Planned Files

```text
sim/sw_test/
  README.md
  run_one.py
  test_all.py
```

`run_one.py` should accept an external binary path:

```powershell
python sim\sw_test\run_one.py \\wsl.localhost\Ubuntu\home\wswsc\risc-v\3-Stage-RISC-V-Bare-Metal-Test\03_BIN\uart_tx_polling.bin
```

No `test_bin/` folder is planned here. The WSL repo remains the owner of the
generated `.bin` files.

<br>

## First Target

First DUT-level SW test:

```text
uart_tx_polling.bin
```

Expected behavior:

```text
1. CPU boots from inst_rom at 0x0000_0000.
2. Program writes UART CTRL / BAUD / TXDATA through MMIO.
3. Program sets x27 = 1 and returns to startup.
4. Startup sets x26 = 1 and loops.
5. Testbench reports PASS only if x26/x27 pass and UART TX decodes "OK\n".
```

<br>

## Implementation Order

Recommended order:

```text
1. Add run_one.py that runs any external .bin using default SoC map.
2. Add UART TX decode support in tb.v behind a plusarg.
3. Add expected UART output argument, for example +uart_expect=OK.
4. Run WSL uart_tx_polling.bin from Windows sim/sw_test.
5. Only after the assembly smoke test passes, move to C runtime and C UART print.
```
