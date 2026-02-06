import os
import subprocess
import sys


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
    root_dir = os.path.abspath(os.path.join(os.getcwd(), ".."))

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
    iverilog_cmd.append(root_dir + '/rtl/core/ctrl.v')

    # memory
    iverilog_cmd.append(root_dir + '/rtl/mem/ram_array.v')
    iverilog_cmd.append(root_dir + '/rtl/mem/dual_ram.v')
    iverilog_cmd.append(root_dir + '/rtl/mem/inst_mem.v')
    iverilog_cmd.append(root_dir + '/rtl/mem/data_mem.v')

    # SoC top
    iverilog_cmd.append(root_dir + '/rtl/soc/soc.v')

    # compile
    process = subprocess.Popen(iverilog_cmd)
    process.wait(timeout=10)


def sim():
    # 1. compile RTL files
    compile()
    # 2. run simulation
    vvp_cmd = [r'vvp']
    vvp_cmd.append(r'out.vvp')
    process = subprocess.Popen(vvp_cmd)
    try:
        process.wait(timeout=10)
    except subprocess.TimeoutExpired:
        print('!!!Fail, vvp exec timeout!!!')


def run(test_binfile):
    # get project root directory
    rtl_dir = os.path.abspath(os.path.join(os.getcwd(), ".."))
    # output filename
    out_mem = rtl_dir + r'/sim/test_bin/inst_data.txt'
    # bin to mem
    bin_to_mem(test_binfile, out_mem)
    # run simulation
    sim()


if __name__ == '__main__':
    sys.exit(run(sys.argv[1]))
