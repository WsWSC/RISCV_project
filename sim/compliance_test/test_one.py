import os
import subprocess
import sys


def sim_dir():
    return os.path.dirname(__file__)


def main():
    cmd = [sys.executable, "runner.py", "--one"]
    cmd.extend(sys.argv[1:])

    result = subprocess.run(cmd, cwd=sim_dir())
    return result.returncode


if __name__ == "__main__":
    sys.exit(main())
