import argparse
import json
import os
import subprocess
import sys

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from compile_and_sim import bin_to_mem, list_binfiles


def project_root():
    return os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))


def sim_dir():
    return os.path.join(project_root(), "sim")


def compliance_dir():
    return os.path.join(project_root(), "sim", "compliance_test")


def parse_args():
    parser = argparse.ArgumentParser(description="Run compliance tests under sim/compliance_test/DUT_runtime/bin.")
    parser.add_argument("name", nargs="?", help="Compliance test name, for example rv32i-I-add-00.")
    parser.add_argument("--one", action="store_true", help="Require the name to resolve to exactly one test.")
    parser.add_argument("--trace", action="store_true", help="Print per-cycle CPU trace for every test.")
    parser.add_argument("--dump", action="store_true", help="Dump tb.vcd. Usually useful only with one selected test.")
    parser.add_argument("--timeout-cycles", type=int, default=1000, help="Override tb.v simulation timeout in cycles.")
    parser.add_argument("--verbose", action="store_true", help="Print simulator output for passing tests too.")
    parser.add_argument("--data-mem", "--data-ram-init", dest="data_mem", help="Optional data RAM init image for compliance mode.")
    parser.add_argument("--signature-start", help="Signature start byte address, for example 00001200.")
    parser.add_argument("--signature-end", help="Signature end byte address, for example 00001854.")
    parser.add_argument("--tohost-addr", help="Optional tohost byte address for official compliance halt.")
    parser.add_argument("--reference", help="Optional reference signature file to compare against.")
    parser.add_argument("--smoke", action="store_true", help="Allow running without a golden reference signature.")
    return parser.parse_args()


def test_name(file_bin):
    return os.path.splitext(os.path.basename(file_bin))[0]


def short_test_name(name):
    parts = name.split("-")
    if len(parts) >= 3:
        return parts[2]
    return name


def select_binfiles(bin_dir, name):
    all_bin_files = sorted(list_binfiles(bin_dir))
    if name is None:
        return all_bin_files

    exact = []
    short = []
    partial = []
    for file_bin in all_bin_files:
        current_name = test_name(file_bin)
        current_short_name = short_test_name(current_name)

        if current_name == name:
            exact.append(file_bin)
        elif current_short_name == name:
            short.append(file_bin)
        elif name in current_name:
            partial.append(file_bin)

    if exact:
        return exact

    if short:
        return short

    return partial


def signature_mode(args):
    return args.signature_start is not None and args.signature_end is not None


def metadata_path(name):
    dut_metadata_path = os.path.join(compliance_dir(), "DUT_metadata", name + ".json")
    if os.path.exists(dut_metadata_path):
        return dut_metadata_path

    return os.path.join(compliance_dir(), ".runtime", "meta", name + ".json")


def load_metadata(name):
    path = metadata_path(name)
    if not os.path.exists(path):
        return {}

    with open(path, "r", encoding="utf-8-sig") as metadata_file:
        return json.load(metadata_file)


def default_reference_path(name):
    return os.path.join(compliance_dir(), "golden_sig", name + ".sig")


def resolve_test_args(file_bin, args):
    resolved = argparse.Namespace(**vars(args))
    name = test_name(file_bin)
    metadata = load_metadata(name)

    if resolved.data_mem is None and "data_ram_init" in metadata:
        resolved.data_mem = os.path.join(project_root(), metadata["data_ram_init"])

    if resolved.data_mem is None and "data" in metadata:
        resolved.data_mem = os.path.join(project_root(), metadata["data"])

    if resolved.signature_start is None and "signature_start" in metadata:
        resolved.signature_start = metadata["signature_start"]

    if resolved.signature_end is None and "signature_end" in metadata:
        resolved.signature_end = metadata["signature_end"]

    if resolved.tohost_addr is None and "tohost_addr" in metadata:
        resolved.tohost_addr = metadata["tohost_addr"]

    if resolved.reference is None and "reference" in metadata:
        resolved.reference = os.path.join(project_root(), metadata["reference"])

    if resolved.reference is None:
        reference_path = default_reference_path(name)
        if os.path.exists(reference_path):
            resolved.reference = reference_path

    if "timeout_cycles" in metadata and resolved.timeout_cycles == 1000:
        resolved.timeout_cycles = metadata["timeout_cycles"]

    return resolved


def normalize_signature(path):
    lines = []
    with open(path, "r") as sig_file:
        for line in sig_file:
            text = line.strip().lower()
            if text:
                lines.append(text)
    return lines


def compare_signature(actual_path, reference_path):
    actual = normalize_signature(actual_path)
    reference = normalize_signature(reference_path)

    if actual == reference:
        return True, ""

    limit = min(len(actual), len(reference))
    for index in range(limit):
        if actual[index] != reference[index]:
            return False, "signature mismatch at word " + str(index)

    return False, "signature length mismatch: actual=" + str(len(actual)) + " reference=" + str(len(reference))


def run_one(file_bin, args):
    args = resolve_test_args(file_bin, args)
    out_mem = os.path.join(project_root(), "sim", "inst_data.txt")
    bin_to_mem(file_bin, out_mem)

    out_dir = os.path.join(compliance_dir(), "DUT_runtime", "out")
    os.makedirs(out_dir, exist_ok=True)
    current_sig = os.path.join(out_dir, "current.sig")
    if os.path.exists(current_sig):
        os.remove(current_sig)

    vvp_args = ["+timeout_cycles=" + str(args.timeout_cycles)]
    if signature_mode(args):
        vvp_args.append("+compliance")
        vvp_args.append("+signature_start=" + args.signature_start)
        vvp_args.append("+signature_end=" + args.signature_end)

    if args.tohost_addr:
        vvp_args.append("+tohost_addr=" + args.tohost_addr)

    if args.data_mem:
        vvp_args.append("+compliance_data")
        vvp_args.append("+compliance_data_file=" + os.path.abspath(args.data_mem).replace("\\", "/"))

    if args.trace:
        vvp_args.append("+trace")
    if args.dump:
        vvp_args.append("+dump")

    cmd = [
        sys.executable,
        "-c",
        "import sys, compile_and_sim; sys.exit(compile_and_sim.sim(sys.argv[1:], iverilog_defines=['COMPLIANCE_MEM'], vvp_timeout=300, compile_timeout=120))",
    ]
    cmd.extend(vvp_args)

    result = subprocess.run(
        cmd,
        cwd=os.path.join(project_root(), "sim"),
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        timeout=360,
    )
    return result, args


def classify_result(result, output, args):
    if result is None or result.returncode != 0:
        return "FAIL", "simulator failed"

    if not signature_mode(args):
        passed = (
            output.find("pass") != -1
            and output.lower().find("fail") == -1
            and output.lower().find("timeout") == -1
        )
        if passed:
            return "DONE", "legacy x26/x27 marker reached end without golden compare"
        return "FAIL", "x26/x27 pass marker failed"

    if output.lower().find("timeout") != -1:
        return "FAIL", "simulation timeout"

    if output.lower().find("compliance tohost fail") != -1:
        return "FAIL", "tohost reported fail"

    if args.tohost_addr and output.lower().find("compliance tohost done") == -1:
        return "FAIL", "missing tohost done"

    actual_sig = os.path.join(compliance_dir(), "DUT_runtime", "out", "current.sig")
    if not os.path.exists(actual_sig):
        return "FAIL", "missing signature dump"

    if args.reference:
        if not os.path.exists(args.reference):
            return "FAIL", "missing reference signature: " + args.reference
        matched, detail = compare_signature(actual_sig, args.reference)
        if matched:
            return "PASS", "golden signature matched"
        return "FAIL", detail

    if args.smoke:
        return "DONE", "signature dumped without golden compare"

    return "FAIL", "missing reference signature"


def main():
    args = parse_args()
    bin_dir = os.path.join(compliance_dir(), "DUT_runtime", "bin")
    all_bin_files = select_binfiles(bin_dir, args.name)

    if not all_bin_files:
        if args.name is None:
            print("missing compliance DUT runtime binaries under sim/compliance_test/DUT_runtime/bin")
        else:
            print("missing compliance DUT runtime binary for: " + args.name)
        print("run WSL golden/DUT runtime generation first")
        return 1

    if args.one and len(all_bin_files) != 1:
        print("ambiguous compliance test name: " + str(args.name))
        print("matched tests:")
        for file_bin in all_bin_files:
            print("  " + test_name(file_bin))
        return 1

    failures = []
    for file_bin in all_bin_files:
        name = test_name(file_bin)
        try:
            result, resolved_args = run_one(file_bin, args)
            output = result.stdout
        except subprocess.TimeoutExpired as exc:
            output = str(exc)
            result = None
            resolved_args = args

        status, detail = classify_result(result, output, resolved_args)
        if status == "PASS":
            print("compliance:   [ " + name.ljust(28, " ") + "]    PASS")
        elif status == "DONE":
            print("compliance:   [ " + name.ljust(28, " ") + "]    DONE")
            if detail:
                print(detail)
        else:
            print("compliance:   [ " + name.ljust(28, " ") + "]    !!!FAIL!!!")
            if detail:
                print(detail)
            failures.append(name)

        if args.verbose or status == "FAIL":
            print(output.rstrip())

    if failures:
        print("failed compliance tests: " + ", ".join(failures))
        return 1

    if args.smoke:
        print("all compliance tests completed")
    else:
        print("all compliance tests passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
