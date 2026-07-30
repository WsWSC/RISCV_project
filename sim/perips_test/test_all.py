import os
import subprocess
import sys


def test_dir():
    return os.path.dirname(__file__)


def run_test(label, script_path):
    result = subprocess.run(
        [sys.executable, script_path],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    )

    if result.returncode == 0:
        print("perips test:  [ {0:<24} ]    PASS".format(label))
    else:
        print("perips test:  [ {0:<24} ]    !!!FAIL!!!".format(label))
        print(result.stdout.rstrip())

    return result.returncode


def main():
    root = test_dir()
    tests = [
        ("timer", os.path.join(root, "timer", "test_all.py")),
        ("rib", os.path.join(root, "rib", "test_rib_uart_route.py")),
        ("uart", os.path.join(root, "uart", "test_all.py")),
    ]

    failures = []
    for label, script_path in tests:
        if run_test(label, script_path) != 0:
            failures.append(label)

    if failures:
        print("failed peripheral groups: " + ", ".join(failures))
        return 1

    print("all peripheral tests passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
