#!/usr/bin/env python3
"""Run all custom CPU test suites without touching sim/test_bin content."""

from __future__ import annotations

import pathlib
import subprocess
import sys


ROOT_DIR = pathlib.Path(__file__).resolve().parents[1]
SUITES = [
    ("type_coverage", ROOT_DIR / "custom_cpu_tests" / "type_coverage" / "run_type_tests.py"),
    (
        "hazard_forwarding",
        ROOT_DIR / "custom_cpu_tests" / "hazard_forwarding" / "run_hazard_forwarding_tests.py",
    ),
    ("csr", ROOT_DIR / "custom_cpu_tests" / "csr" / "run_csr_tests.py"),
]


def main() -> int:
    failures: list[str] = []

    for name, script in SUITES:
        print(f"\n===== {name} =====", flush=True)
        result = subprocess.run(
            [sys.executable, str(script)],
            cwd=ROOT_DIR,
            text=True,
        )
        if result.returncode != 0:
            failures.append(name)

    print("\n===== custom test summary =====", flush=True)
    if failures:
        print("failed: " + ", ".join(failures))
        return 1

    print("all custom CPU tests passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
