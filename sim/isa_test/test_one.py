import os
import subprocess
import argparse

import sys

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from compile_and_sim import list_binfiles
from compile_and_sim import bin_to_mem
from compile_and_sim import sim


def project_root():
    return os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))


def parse_args():
    parser = argparse.ArgumentParser(description='Run one instruction test by name.')
    parser.add_argument('name', nargs='?', default='addi', help='Instruction test name, for example addi or mul.')
    parser.add_argument('--trace', action='store_true', help='Print per-cycle CPU trace from tb.v.')
    parser.add_argument('--dump', action='store_true', help='Dump tb.vcd for waveform debug.')
    parser.add_argument('--timeout-cycles', type=int, help='Override tb.v simulation timeout in cycles.')
    return parser.parse_args()


def main(name='addi', trace=False, dump=False, timeout_cycles=None):
    # get project root directory
    rtl_dir = project_root()

    all_bin_files = list_binfiles(rtl_dir + r'/sim/isa_test/test_bin/')
    test_binfile = None

    for file in all_bin_files:
        if file.find(name) != -1 and file.find('.bin') != -1:
            test_binfile = file

    if test_binfile is None:
        print('missing test binary for: ' + name)
        return 1

    # output filename
    out_mem = rtl_dir + r'/sim/inst_data.txt'
    
    # bin to mem
    bin_to_mem(test_binfile, out_mem)

    # run simulation
    vvp_args = []
    if trace:
        vvp_args.append('+trace')
    if dump:
        vvp_args.append('+dump')
    if timeout_cycles is not None:
        vvp_args.append('+timeout_cycles=' + str(timeout_cycles))

    return sim(vvp_args)

    # Optional: open waveform viewer
    # gtkwave_cmd = [r'gtkwave']
    # gtkwave_cmd.append(r'tb.vcd')
    # process = subprocess.Popen(gtkwave_cmd)


if __name__ == '__main__':
    args = parse_args()
    sys.exit(main(args.name, args.trace, args.dump, args.timeout_cycles))
