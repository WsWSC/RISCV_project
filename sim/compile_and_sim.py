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
    # get project root directory
    rtl_dir = os.path.abspath(os.path.join(os.getcwd(), ".."))

    # build iverilog command 
    iverilog_cmd = ['iverilog']

    # output compiled simulation file
    iverilog_cmd += ['-o', r'out.vvp']

    # RTL headers (e.g., defines.v)
    iverilog_cmd += ['-I', rtl_dir + r'/rtl']
    iverilog_cmd += ['-I', rtl_dir + r'/utils'] 
    iverilog_cmd.append(rtl_dir + r'/rtl/defines.v')
    # testbench 
    iverilog_cmd.append(rtl_dir + r'/tb/tb.v')

    # core RTL 
    iverilog_cmd.append(rtl_dir + r'/rtl/core.v')
    iverilog_cmd.append(rtl_dir + r'/rtl/pc_reg.v')
    iverilog_cmd.append(rtl_dir + r'/rtl/regs.v')

    iverilog_cmd.append(rtl_dir + r'/rtl/ifetch.v')
    iverilog_cmd.append(rtl_dir + r'/rtl/if_id.v')
    iverilog_cmd.append(rtl_dir + r'/rtl/id.v')
    iverilog_cmd.append(rtl_dir + r'/rtl/id_ex.v')
    iverilog_cmd.append(rtl_dir + r'/rtl/ex.v')

    iverilog_cmd.append(rtl_dir + r'/rtl/ctrl.v')
    # iverilog_cmd.append(rtl_dir + r'/rtl/ram.v')
    iverilog_cmd.append(rtl_dir + r'/rtl/rom.v')

    # common utility modules
    iverilog_cmd.append(rtl_dir + r'/utils/dff_set.v')
    # iverilog_cmd.append(rtl_dir + r'/utils/dual_ram.v')

    # top-level SoC module
    iverilog_cmd.append(rtl_dir + r'/rtl/soc.v')

    # compile RTL and testbench
    process = subprocess.Popen(iverilog_cmd)
    process.wait(timeout=5)


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
    out_mem = rtl_dir + r'/sim/generated/inst_data.txt'
    # bin to mem
    bin_to_mem(test_binfile, out_mem)
    # run simulation
    sim()


if __name__ == '__main__':
    sys.exit(run(sys.argv[1]))
