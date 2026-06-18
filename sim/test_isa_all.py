import os
import subprocess
import sys
import argparse

from compile_and_sim import list_binfiles


def project_root():
    return os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))


def parse_args():
    parser = argparse.ArgumentParser(description='Run every .bin test under sim/test_bin.')
    parser.add_argument('--trace', action='store_true', help='Print per-cycle CPU trace for every test.')
    parser.add_argument('--dump', action='store_true', help='Dump tb.vcd. Usually useful only with one selected test.')
    parser.add_argument('--timeout-cycles', type=int, help='Override tb.v simulation timeout in cycles.')
    parser.add_argument('--verbose', action='store_true', help='Print simulator output for passing tests too.')
    return parser.parse_args()


def run_one(file_bin, args):
    cmd = [sys.executable, 'compile_and_sim.py', file_bin]
    if args.trace:
        cmd.append('--trace')
    if args.dump:
        cmd.append('--dump')
    if args.timeout_cycles is not None:
        cmd.extend(['--timeout-cycles', str(args.timeout_cycles)])

    return subprocess.run(
        cmd,
        cwd=os.path.join(project_root(), 'sim'),
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        timeout=30,
    )


def main():
    args = parse_args()

    # get project root directory
    rtl_dir = project_root()

    # get all .bin instruction files under sim/test_bin
    all_bin_files = sorted(list_binfiles(rtl_dir + r'/sim/test_bin/'))
    
    # run simulation one by one
    failures = []
    for file_bin in all_bin_files:
        try:
            result = run_one(file_bin, args)
            output = result.stdout
        except subprocess.TimeoutExpired as exc:
            output = str(exc)
            result = None

        index = file_bin.index('-p-')
        print_name = file_bin[index + 3:-4]

        passed = result is not None and result.returncode == 0 and output.find('pass') != -1 and output.lower().find('fail') == -1 and output.lower().find('timeout') == -1
        if passed:
            print('instruction:  [ ' + print_name.ljust(10, ' ') + ']    PASS')
        else: 
            print('instruction:  [ ' + print_name.ljust(10, ' ') + ']    !!!FAIL!!!')
            failures.append(print_name)

        if args.verbose or not passed:
            print(output.rstrip())

    if failures:
        print('failed tests: ' + ', '.join(failures))
        return 1

    print('all tests passed')
    return 0


if __name__ == '__main__':
    sys.exit(main())
