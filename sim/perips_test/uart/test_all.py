import os
import subprocess
import sys


def test_dir():
    return os.path.dirname(__file__)


def run_test(script_name):
    script_path = os.path.join(test_dir(), script_name)
    result = subprocess.run(
        [sys.executable, script_path],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    )

    print(result.stdout.rstrip())

    if result.returncode == 0:
        print("uart test:    [ {0:<24} ]    PASS".format(script_name))
    else:
        print("uart test:    [ {0:<24} ]    !!!FAIL!!!".format(script_name))

    return result.returncode


def main():
    tests = [
        "test_uart_tx.py",
        "test_uart_rx.py",
        "test_uart_mmio.py",
        "test_uart_tx_polling.py",
        "test_uart_rx_polling.py",
    ]

    failures = []
    for test in tests:
        if run_test(test) != 0:
            failures.append(test)

    if failures:
        print("failed UART tests: " + ", ".join(failures))
        return 1

    print("all UART tests passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
