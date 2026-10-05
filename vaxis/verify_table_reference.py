"""Compare the unchanged Table width/context/data/renderer APIs and boundaries."""
import argparse
import hashlib
import itertools
import os
from pathlib import Path
import random
import resource
import shutil
import subprocess
import sys
import tempfile

PROBE = Path(__file__).resolve().parent / "reference_probes/table"
sys.path.insert(0, str(PROBE.parent / "widgets_classic"))
from source_build import VAXIS_SHA256, UUCODE_PACKAGE, module, prepare_uucode, tree_hash


def corpus():
    cases = ["C"] + [f"D|{kind}" for kind in range(6)] + [f"N|{i}" for i in range(11)]
    for kind in range(4):
        widths = (1, 2, 3, 5, 14, 15, 16, 255, 65535) if kind == 0 else (0, 14)
        args = (0, 1, 2, 31, 32767, 65535) if kind in (1, 2) else (0,)
        lengths = (0, 1, 2, 15, 255, 65535) if kind == 1 else (0,)
        for width, count, col, arg, length in itertools.product(
                widths, (0, 1, 2, 3, 5, 16, 257), (0, 1, 5, 257, 65535), args, lengths):
            if kind == 0 and not count:
                continue
            if kind == 1 and col < count and (arg > 32767 or length + arg * 2 > 65535):
                continue
            cases.append(f"W|{kind}|{width}|{count}|{col}|{arg}|{length}")
    rng = random.Random(6060514)
    for _ in range(4096):
        width, height, rows = rng.randrange(33), rng.randrange(10), rng.randrange(9)
        row = rng.randrange(13) if rows else 0
        start, col, active, old_offset, callback = rng.randrange(13), rng.randrange(9), rng.randrange(2), rng.randrange(5), rng.randrange(3)
        style = rng.randrange(4)
        if not width and style == 0:
            style = 2
        by_index = rng.randrange(2)
        custom = 1 if by_index else rng.randrange(2)
        values = (width, height, rows, row, start, col, active, old_offset, callback,
            style, rng.choice((0, 1, 2, 5, 9)), rng.randrange(2), rng.randrange(2),
            rng.randrange(2), by_index, custom, rng.randrange(4), rng.randrange(4), rng.randrange(4))
        cases.append("R|" + "|".join(map(str, values)))
    # Callback mutates the live context after budgeting. No selected-row lookup
    # means start+row remains usize, even when it no longer fits u16.
    cases.append("R|16|8|3|0|0|0|0|0|3|2|3|0|0|0|0|0|0|0|0")
    cases.append("R|32|8|3|0|0|0|0|0|4|2|12|0|0|0|0|0|0|0|0")
    return cases


def ordinary_rejection(result, message):
    text = result.stdout + result.stderr
    return (result.returncode > 0 and b"error:" in text and message.encode() in text
        and not any(word in text.lower() for word in (b"panic:", b"compiler bug", b"segmentation fault", b"segfault"))
        and b"C error found" not in text and b"UNEXPECTED" not in text)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("zig", type=Path)
    parser.add_argument("v", type=Path)
    parser.add_argument("--uucode", type=Path, default=Path.home() / ".cache/zig/p" / UUCODE_PACKAGE)
    parser.add_argument("--target", default="aarch64-macos.14.0")
    parser.add_argument("--v-prod", action="store_true")
    parser.add_argument("--zig-mode", choices=("Debug", "ReleaseSafe"), default="Debug")
    parser.add_argument("--keep", type=Path, help=argparse.SUPPRESS)
    args = parser.parse_args()
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
    source = args.source.resolve() / "src"
    if tree_hash(source) != VAXIS_SHA256:
        parser.error("vaxis src differs from the recorded local source")
    cases = corpus()
    with tempfile.TemporaryDirectory(prefix="witty-vaxis-table-") as directory:
        root = Path(directory)
        shutil.copytree(source, root / "src")
        graph = prepare_uucode(args.zig.resolve(), root, args.uucode.resolve(), args.target)
        def native(path, output):
            return [str(args.zig.resolve()), "build-exe", "-target", args.target, "-lc", "-O", args.zig_mode,
                *module("root", path, ["vaxis"]), *module("vaxis", root / "src/main.zig", ["uucode"]), *graph, output]
        subprocess.run(native(PROBE / "reference.zig", f"-femit-bin={root / 'native'}"), check=True)
        options = ["-prod"] if args.v_prod else []
        environment = dict(os.environ, VEXE=str(args.v.resolve()), V_C_ERROR_BUG_REPORT_DISABLED="1")
        subprocess.run([str(args.v.resolve()), *options, "-o", str(root / "translated"), str(PROBE / "main.v")], env=environment, check=True)
        corpus_path = root / "corpus.txt"
        corpus_path.write_text("\n".join(cases) + "\n")
        outputs = []
        for executable in ("native", "translated"):
            result = subprocess.run([str(root / executable), str(corpus_path)], capture_output=True, timeout=120)
            if result.returncode:
                raise AssertionError(f"{executable} corpus failed: {result.stderr.decode(errors='replace')}")
            outputs.append(result.stdout.splitlines())
        if any(len(output) != len(cases) for output in outputs):
            raise AssertionError([len(cases)] + [len(output) for output in outputs])
        for index, (data, expected, actual) in enumerate(zip(cases, *outputs)):
            if expected != actual:
                raise AssertionError(f"row {index} ({data}): native={expected!r}, V={actual!r}")
        traps = {
            "width_zero": ("integer overflow", "integer overflow"),
            "heads_zero": ("division by zero", "division by zero"),
            "heads_cast": ("integer does not fit in destination type", "integer does not fit in destination type"),
            "header_cast": ("integer does not fit in destination type", "integer does not fit in destination type"),
            "padding": ("integer overflow", "integer overflow"),
            "header_add": ("integer overflow", "integer overflow"),
            "width_list": ("index out of bounds", "Table width index out of bounds"),
            "empty_headers": ("integer overflow", "integer overflow"),
            "empty_rows": ("integer overflow", "integer overflow"),
            "start_add": ("integer overflow", "integer overflow"),
            "active_add": ("integer overflow", "integer overflow"),
            "col_add": ("integer overflow", "integer overflow"),
            "align_list": ("index out of bounds", "Table alignment index out of bounds"),
            "selected_cast": ("integer does not fit in destination type", "integer does not fit in destination type"),
        }
        for mode, messages in traps.items():
            for executable, message in zip(("native", "translated"), messages):
                result = subprocess.run([str(root / executable), mode], capture_output=True, timeout=10)
                diagnostics = result.stderr + result.stdout
                if result.returncode == 0 or b"UNEXPECTED" in diagnostics or message.encode() not in diagnostics:
                    raise AssertionError(f"{mode}: {executable} did not retain the checked trap: {diagnostics.decode(errors='replace')}")
        boundaries = {
            "slice": ("no field named 'Slice'", "obsolete Pointer.Size.Slice"),
            "required": ("missing struct field: selected_bg", "must be initialized"),
            "strings": ("expected type '[]const u8'", "string-slice field"),
            "optional_strings": ("expected type '[]const u8'", "string-slice field"),
        }
        for mode, messages in boundaries.items():
            result = subprocess.run(native(PROBE / f"{mode}_unsupported.zig", "-fno-emit-bin"), capture_output=True)
            if not ordinary_rejection(result, messages[0]):
                raise AssertionError(f"source {mode} did not ordinarily reject compilation: {(result.stdout + result.stderr).decode(errors='replace')}")
            result = subprocess.run([str(args.v.resolve()), *options, "-o", str(root / "rejection_v"), str(PROBE / f"{mode}_unsupported.v")], env=environment, capture_output=True)
            if not ordinary_rejection(result, messages[1]):
                raise AssertionError(f"V {mode} did not ordinarily reject compilation: {(result.stdout + result.stderr).decode(errors='replace')}")
        if args.keep:
            shutil.copytree(root, args.keep, dirs_exist_ok=True)
        print(f"Table: {len(cases)} returning cases, {len(traps)} traps, {len(boundaries)} compile boundaries, SHA256 "
            + hashlib.sha256(b"\n".join(outputs[0])).hexdigest())


if __name__ == "__main__":
    main()
