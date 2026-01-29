import os
import subprocess

from compile_and_sim import compile
from compile_and_sim import list_binfiles
from compile_and_sim import sim
from compile_and_sim import bin_to_mem
import sys


def main(name='addi'):
    # get project root directory
    rtl_dir = os.path.abspath(os.path.join(os.getcwd(), ".."))

    all_bin_files = list_binfiles(rtl_dir + r'/sim/generated/')

    for file in all_bin_files:
        if file.find(name) != -1 and file.find('.bin') != -1:
            test_binfile = file

    # output filename
    out_mem = rtl_dir + r'/sim/generated/inst_data.txt'
    
    # bin to mem
    bin_to_mem(test_binfile, out_mem)

    # run simulation
    sim()

    # Optional: open waveform viewer
    # gtkwave_cmd = [r'gtkwave']
    # gtkwave_cmd.append(r'tb.vcd')
    # process = subprocess.Popen(gtkwave_cmd)


if __name__ == '__main__':
    sys.exit(main(sys.argv[1]))
