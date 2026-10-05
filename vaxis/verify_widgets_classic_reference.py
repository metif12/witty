"""Compare runnable classic View/LineNumbers/TextView/CodeView APIs unchanged."""
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

PROBE = Path(__file__).resolve().parent / "reference_probes/widgets_classic"
sys.path.insert(0, str(PROBE))
from source_build import VAXIS_SHA256, UUCODE_PACKAGE, module, prepare_uucode, tree_hash

def corpus():
    rng = random.Random(203052316)
    cases = []

    def add(*v):
        cases.append('|'.join(map(str, v)))
    for (v, n) in itertools.product((0, 1, 9, 10, 99, 100, 999, 1000, 99999999, 100000000, (1 << 64) - 1), range(20)):
        add('H', v, n)
    for _ in range(2048):
        (vw, vh, sw, sh) = [rng.randrange(13) for _ in range(4)]
        ox = rng.randrange(sw + 1)
        oy = rng.randrange(sh + 1)
        ww = rng.randrange(sw - ox + 1)
        wh = rng.randrange(sh - oy + 1)
        add('D', vw, vh, sw, sh, ox, oy, ww, wh, rng.randrange(17), rng.randrange(17))
    # Early returns precede invalid destination coordinate arithmetic.
    for vals in ((0, 1, 0, 0), (1, 0, 0, 0), (2, 3, 2, 0), (2, 3, 0, 3)):
        (vw, vh, x, y) = vals
        add('D', vw, vh, 2, 2, -1, -1, 2, 2, x, y)
    for _ in range(2048):
        (vw, vh, sw, sh) = [rng.randrange(1, 13) for _ in range(4)]
        ox = rng.randrange(sw + 1)
        oy = rng.randrange(sh + 1)
        ww = rng.randrange(sw - ox + 1)
        wh = rng.randrange(sh - oy + 1)
        add('R', vw, vh, sw, sh, ox, oy, ww, wh, rng.choice((0, 1, 12, 65535)), rng.choice((0, 1, 12, 65535)), rng.randrange(2), rng.randrange(17), rng.randrange(2), rng.randrange(17))
    for dims in ((0, 0), (1, 1), (2, 2), (8, 3)):
        (w, h) = dims
        for (method, cluster, wrap, commit, col, row) in itertools.product(range(3), range(12), range(3), range(2), (0, 1, 5), (0, 1, 3)):
            add('P', w, h, 1, 1, 0, 0, 1, 1, method, cluster, wrap, commit, col, row)
    for _ in range(2048):
        (sw, sh) = (rng.randrange(13), rng.randrange(9))
        (ox, oy) = (rng.randrange(-2, 3), rng.randrange(-2, 3))
        (ww, wh) = (rng.randrange(13), rng.randrange(9))
        scroll = rng.choice((0, 1, 9, 99, 99999998, 99999999))
        num = scroll + rng.randrange(1, 65)
        highlight = rng.choice((0, scroll + 1, scroll + 2))
        actualwidth = min(ww, max(sw - ox, 0))
        digits = len(str(highlight)) if highlight < 100000000 else 0
        if highlight and highlight - 1 >= scroll and (highlight - 1 < scroll + min(wh, max(sh - oy, 0))) and (actualwidth < digits + 1):
            highlight = 0
        add('N', sw, sh, ox, oy, ww, wh, num, scroll, highlight, rng.randrange(4), rng.randrange(4))
    for _ in range(4096):
        items = [str(rng.randrange(12)) for _ in range(rng.randrange(1, 33))]
        (sw, sh) = (rng.randrange(13), rng.randrange(9))
        (ox, oy) = (rng.randrange(-2, 3), rng.randrange(-2, 3))
        (ww, wh) = (rng.randrange(13), rng.randrange(9))
        add('T', ','.join(items), sw, sh, ox, oy, ww, wh, rng.randrange(3), rng.choice((0, 1, 8, 64, (1 << 64) - 1)), rng.randrange(65), rng.randrange(2), rng.randrange(9), rng.choice((0, 1, 2, 4, 64, 128, 193)))
    for (code, mods) in itertools.product(range(9), (0, 1, 2, 4, 64, 128, 193)):
        add('I', code, mods)
    for scroll in ((1 << 64) - 3, (1 << 64) - 2):
        for highlight in (0, scroll + 1):
            add('N', 6, 3, 0, 0, 6, 3, (1 << 64) - 1, scroll, highlight, 1, 2)
    return cases

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("zig", type=Path)
    parser.add_argument("v", type=Path)
    parser.add_argument("--uucode", type=Path, default=Path.home() / ".cache/zig/p" / UUCODE_PACKAGE)
    parser.add_argument("--target", default="aarch64-macos.14.0")
    parser.add_argument("--v-prod", action="store_true")
    parser.add_argument("--v-path", help=argparse.SUPPRESS)
    args = parser.parse_args()
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
    source = args.source.resolve() / "src"
    if tree_hash(source) != VAXIS_SHA256:
        parser.error("vaxis src differs from the recorded local source")
    cases = corpus()
    with tempfile.TemporaryDirectory(prefix="witty-vaxis-classic-") as directory:
        root = Path(directory)
        shutil.copytree(source, root / "src")
        graph = prepare_uucode(args.zig.resolve(), root, args.uucode.resolve(), args.target)
        zig = str(args.zig.resolve())
        def native(path, output):
            return [zig, "build-exe", "-target", args.target, "-lc",
                *module("root", path, ["vaxis"]),
                *module("vaxis", root / "src/main.zig", ["uucode"]), *graph, output]
        subprocess.run(native(PROBE / "reference.zig", f"-femit-bin={root / 'native'}"), check=True)
        options = ["-prod"] if args.v_prod else []
        if args.v_path:
            options += ["-path", args.v_path]
        environment = dict(os.environ, VEXE=str(args.v.resolve()), V_C_ERROR_BUG_REPORT_DISABLED="1")
        subprocess.run([str(args.v.resolve()), *options, "-o", str(root / "translated"),
            str(PROBE / "main.v")], env=environment, check=True)
        corpus_path = root / "corpus.txt"
        corpus_path.write_text("\n".join(cases) + "\n")
        outputs = [subprocess.run([str(root / executable), str(corpus_path)], capture_output=True,
            check=True, timeout=60).stdout.splitlines() for executable in ("native", "translated")]
        if any(len(output) != len(cases) for output in outputs):
            raise AssertionError([len(cases)] + [len(output) for output in outputs])
        for index, (data, expected, actual) in enumerate(zip(cases, *outputs)):
            if expected != actual:
                raise AssertionError(f"row {index} ({data}): native={expected!r}, V={actual!r}")
        traps = dict.fromkeys(("trap_src", "trap_dst", "trap_zero", "trap_lines", "trap_highlight", "trap_scroll", "trap_style"), "integer overflow")
        traps.update(trap_negx="integer does not fit in destination type", trap_negy="integer does not fit in destination type",
            trap_bounds="index out of bounds", trap_grapheme="index out of bounds", trap_style_index="index out of bounds", trap_glyph="integer does not fit in destination type", trap_overlap="memcpy arguments alias", trap_same="memcpy arguments alias", trap_slice="memcpy arguments alias",
            trap_digit="attempt to unwrap error: Overflow")
        for mode, message in traps.items():
            for executable in ("native", "translated"):
                result = subprocess.run([str(root / executable), mode], capture_output=True, timeout=10)
                if result.returncode == 0 or b"UNEXPECTED" in result.stderr + result.stdout or message.encode() not in result.stderr + result.stdout:
                    raise AssertionError(f"{mode}: {executable} did not retain the checked trap")
        boundaries = {"append": ("error union payload", "append"), "update": ("error union payload", "update"),
            "write": ("error union payload", "write"), "code": ("expected type '?u16', found 'usize'", "draw")}
        def ordinary_rejection(result, message, extra=b""):
            diagnostics = result.stderr + result.stdout
            forbidden = (b"panic:", b"compiler bug", b"segmentation fault", b"segfault", b"C error found", b"UNEXPECTED")
            return (result.returncode > 0 and b"error:" in diagnostics
                and message in diagnostics and (not extra or extra in diagnostics)
                and not any(word in diagnostics.lower() for word in (b"panic:", b"compiler bug", b"segmentation fault", b"segfault"))
                and not any(word in diagnostics for word in forbidden[4:]))
        for mode, (zig_message, v_message) in boundaries.items():
            rejection = subprocess.run(native(PROBE / f"{mode}_unsupported.zig", "-fno-emit-bin"), capture_output=True)
            if not ordinary_rejection(rejection, zig_message.encode()):
                raise AssertionError(f"source {mode} did not ordinarily reject compilation: {rejection.stderr.decode()}")
            rejection = subprocess.run([str(args.v.resolve()), *options, "-o", str(root / "rejection_v"),
                str(PROBE / f"{mode}_unsupported.v")], env=environment, capture_output=True)
            if not ordinary_rejection(rejection, v_message.encode(), b"unknown method or field"):
                raise AssertionError(f"V {mode} did not ordinarily reject the unavailable method: {rejection.stderr.decode()}")
        print(f"Classic widgets: {len(cases)} cases, {len(traps)} traps, {len(boundaries)} compile boundaries, SHA256 "
            + hashlib.sha256(b"\n".join(outputs[0])).hexdigest())


if __name__ == "__main__":
    main()
