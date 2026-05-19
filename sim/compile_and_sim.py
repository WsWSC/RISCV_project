import os
import subprocess
import sys
import argparse


def project_root():
    return os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))


def sim_dir():
    return os.path.dirname(__file__)


def list_binfiles(path):
    files = []
    list_dir = os.walk(path)
    for maindir, subdir, all_file in list_dir:
        for filename in all_file:
            apath = os.path.join(maindir, filename)
            if apath.endswith('.bin'):
                files.append(apath)

    return files


def bin_to_mem(infile, outfile):
    binfile = open(infile, 'rb')
    binfile_content = binfile.read(os.path.getsize(infile))
    datafile = open(outfile, 'w')

    index = 0
    b0 = 0
    b1 = 0
    b2 = 0
    b3 = 0

    for b in binfile_content:
        if index == 0:
            b0 = b
            index = index + 1
        elif index == 1:
            b1 = b
            index = index + 1
        elif index == 2:
            b2 = b
            index = index + 1
        elif index == 3:
            b3 = b
            index = 0
            array = []
            array.append(b3)
            array.append(b2)
            array.append(b1)
            array.append(b0)
            datafile.write(bytearray(array).hex() + '\n')

    binfile.close()
    datafile.close()
 

def compile():
    # project root = RISCV_PROJECT
    root_dir = project_root()

    iverilog_cmd = ['iverilog', '-g2012']

    # output
    iverilog_cmd += ['-o', 'out.vvp']

    # include paths
    iverilog_cmd += ['-I', root_dir + '/rtl']
    iverilog_cmd += ['-I', root_dir + '/rtl/utils']
    iverilog_cmd += ['-I', root_dir + '/rtl/core']
    iverilog_cmd += ['-I', root_dir + '/rtl/mem']
    iverilog_cmd += ['-I', root_dir + '/rtl/soc']

    # testbench
    iverilog_cmd.append(root_dir + '/tb/tb.v')

    # utils
    iverilog_cmd.append(root_dir + '/rtl/utils/defines.v')
    iverilog_cmd.append(root_dir + '/rtl/utils/dff_set.v')

    # core
    iverilog_cmd.append(root_dir + '/rtl/core/core.v')
    iverilog_cmd.append(root_dir + '/rtl/core/pc_reg.v')
    iverilog_cmd.append(root_dir + '/rtl/core/regs.v')

    iverilog_cmd.append(root_dir + '/rtl/core/if_id.v')
    iverilog_cmd.append(root_dir + '/rtl/core/id.v')
    iverilog_cmd.append(root_dir + '/rtl/core/id_ex.v')
    iverilog_cmd.append(root_dir + '/rtl/core/ex.v')
    iverilog_cmd.append(root_dir + '/rtl/core/mul.v')
    iverilog_cmd.append(root_dir + '/rtl/core/div.v')
    iverilog_cmd.append(root_dir + '/rtl/core/ctrl.v')

    # memory
    iverilog_cmd.append(root_dir + '/rtl/mem/inst_rom.v')
    iverilog_cmd.append(root_dir + '/rtl/mem/data_ram.v')

    # SoC top
    iverilog_cmd.append(root_dir + '/rtl/soc/soc.v')

    # compile
    process = subprocess.Popen(iverilog_cmd, cwd=sim_dir())
    process.wait(timeout=10)
    return process.returncode


def sim(vvp_args=None):
    # 1. compile RTL files
    compile_rc = compile()
    if compile_rc != 0:
        return compile_rc
    
    # 2. run simulation
    vvp_cmd = [r'vvp']
    vvp_cmd.append(r'out.vvp')
    if vvp_args:
        vvp_cmd.extend(vvp_args)

    process = subprocess.Popen(vvp_cmd, cwd=sim_dir())
    try:
        process.wait(timeout=10)
    except subprocess.TimeoutExpired:
        print('!!!Fail, vvp exec timeout!!!')
        process.kill()
        return 1

    return process.returncode


def run(test_binfile, trace=False, dump=False, timeout_cycles=None):
    # get project root directory
    rtl_dir = project_root()

    # output filename
    out_mem = rtl_dir + r'/sim/test_bin/inst_data.txt'

    # bin to mem
    bin_to_mem(test_binfile, out_mem)

    vvp_args = []
    if trace:
        vvp_args.append('+trace')
    if dump:
        vvp_args.append('+dump')
    if timeout_cycles is not None:
        vvp_args.append('+timeout_cycles=' + str(timeout_cycles))

    # run simulation
    return sim(vvp_args)


def parse_args():
    parser = argparse.ArgumentParser(description='Compile and run one RISC-V binary.')
    parser.add_argument('test_binfile')
    parser.add_argument('--trace', action='store_true', help='Print per-cycle CPU trace from tb.v.')
    parser.add_argument('--dump', action='store_true', help='Dump tb.vcd for waveform debug.')
    parser.add_argument('--timeout-cycles', type=int, help='Override tb.v simulation timeout in cycles.')
    return parser.parse_args()


if __name__ == '__main__':
    args = parse_args()
    sys.exit(run(args.test_binfile, args.trace, args.dump, args.timeout_cycles))
