import argparse
import os
import subprocess
import sys

from compile_and_sim import bin_to_mem, list_binfiles, sim


CSR_VVP_ARGS = {
    "external_irq": ["+external_irq_cycle=12"],
    "external_irq_masked": ["+external_irq_cycle=12"],
    "external_irq_pending_latch": ["+external_irq_cycle=5"],
}

EXPECTED_FAIL = set()


def project_root():
    return os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))


def parse_args():
    parser = argparse.ArgumentParser(description="Run every .bin test under sim/csr_test_bin.")
    parser.add_argument("--trace", action="store_true", help="Print per-cycle CPU trace for every test.")
    parser.add_argument("--dump", action="store_true", help="Dump tb.vcd. Usually useful only with one selected test.")
    parser.add_argument("--timeout-cycles", type=int, default=1000, help="Override tb.v simulation timeout in cycles.")
    parser.add_argument("--verbose", action="store_true", help="Print simulator output for passing tests too.")
    return parser.parse_args()


def test_name(file_bin):
    base = os.path.basename(file_bin)
    if "-p-" in base:
        return base[base.index("-p-") + 3:-4]
    return os.path.splitext(base)[0]


def run_one(file_bin, args):
    out_mem = os.path.join(project_root(), "sim", "inst_data.txt")
    bin_to_mem(file_bin, out_mem)

    name = test_name(file_bin)
    vvp_args = ["+timeout_cycles=" + str(args.timeout_cycles)]
    vvp_args.extend(CSR_VVP_ARGS.get(name, []))
    if args.trace:
        vvp_args.append("+trace")
    if args.dump:
        vvp_args.append("+dump")

    cmd = [
        sys.executable,
        "-c",
        "import sys, compile_and_sim; sys.exit(compile_and_sim.sim(sys.argv[1:]))",
    ]
    cmd.extend(vvp_args)

    return subprocess.run(
        cmd,
        cwd=os.path.join(project_root(), "sim"),
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        timeout=30,
    )


def passed_result(result, output):
    return (
        result is not None
        and result.returncode == 0
        and output.find("pass") != -1
        and output.lower().find("fail") == -1
        and output.lower().find("timeout") == -1
    )


def main():
    args = parse_args()
    bin_dir = os.path.join(project_root(), "sim", "csr_test_bin")
    all_bin_files = sorted(list_binfiles(bin_dir))

    failures = []
    for file_bin in all_bin_files:
        name = test_name(file_bin)
        try:
            result = run_one(file_bin, args)
            output = result.stdout
        except subprocess.TimeoutExpired as exc:
            output = str(exc)
            result = None

        passed = passed_result(result, output)
        expected_fail = name in EXPECTED_FAIL

        if expected_fail and not passed:
            print("csr test:     [ " + name.ljust(28, " ") + "]    XFAIL")
        elif expected_fail and passed:
            print("csr test:     [ " + name.ljust(28, " ") + "]    XPASS")
            failures.append(name)
        elif passed:
            print("csr test:     [ " + name.ljust(28, " ") + "]    PASS")
        else:
            print("csr test:     [ " + name.ljust(28, " ") + "]    !!!FAIL!!!")
            failures.append(name)

        if args.verbose or (not passed and not expected_fail) or (expected_fail and passed):
            print(output.rstrip())

    if failures:
        print("failed CSR tests: " + ", ".join(failures))
        return 1

    print("all CSR tests passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
