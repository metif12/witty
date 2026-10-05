"""Compare Window-based widgets with the unchanged local vaxis source tree.

Includes all five alignments, Scrollbar drawing, ScrollView input/restriction,
bounding-box predicates, clipped content writes, retained cells/styles, isolated
checked-arithmetic traps, and the source's noncompiling readCell boundary.
"""
import argparse
import hashlib
import itertools
import os
from pathlib import Path
import random
import shutil
import subprocess
import tempfile

PINNED_VAXIS_SOURCE_SHA256 = "bc71386c999b4ba88faf0096c55f8b7af2bdb0c02cdb98ab9bf9455633c514ed"
MAXIMUM = (1 << 64) - 1


def corpus():
    cases = []
    rng = random.Random(0xbc71386c)

    def add(mode, *values):
        cases.append("|".join(map(str, (mode,) + values)))

    dimensions = (0, 1, 2, 3, 4, 5, 7, 8, 15, 16, 255, 65535)
    for width, height, cols, rows in itertools.product(dimensions, repeat=4):
        add("A", width, height, 0, 0, 0, 0, cols, rows)
    for _ in range(512):
        add("A", rng.randrange(33), rng.randrange(33), rng.randrange(-8, 9),
            rng.randrange(-8, 9), rng.randrange(-8, 1), rng.randrange(-8, 1),
            rng.randrange(33), rng.randrange(33))
    positions = (0, 1, 2, 31, 32, 33, MAXIMUM - 32, MAXIMUM - 1, MAXIMUM)
    for x, y, code, mods in itertools.product(positions, positions, range(9), (0, 1, 2, 4, 64, 128, 193)):
        add("I", x, y, code, mods)
    limits = (0, 1, 31, 32, MAXIMUM - 32, MAXIMUM - 1, MAXIMUM)
    for values in itertools.product(limits, repeat=4):
        add("R", *values)
    for width, height, enabled, x, y in itertools.product((0, 1, 2, 31, 65535), (0, 1, 2, 31, 65535), (0, 1), positions, positions):
        col = rng.choice((x, MAXIMUM, 0))
        row = rng.choice((y, MAXIMUM, 0))
        add("G", width, height, enabled, x, y, col, row)
    for width, height, total, visible in itertools.product((0, 1, 2, 5, 8), (0, 1, 2, 5, 8), (0, 1, 2, 3, 8, 17), (0, 1, 2, 5, 8, 17)):
        for top in (0, max(total - 1, 0), total + 1):
            add("B", width, height, 0, 0, width, height, rng.randrange(5), rng.randrange(4), rng.randrange(4), top, total, visible)
    for _ in range(2048):
        add("B", rng.randrange(13), rng.randrange(9), rng.randrange(-3, 5), rng.randrange(-3, 5),
            rng.randrange(17), rng.randrange(13), rng.randrange(5), rng.randrange(4), rng.randrange(4),
            rng.randrange(129), rng.randrange(129), rng.randrange(65))
    for _ in range(4096):
        sw, sh = rng.randrange(13), rng.randrange(9)
        ox, oy = rng.randrange(-3, 5), rng.randrange(-3, 5)
        width = min(rng.randrange(17), max(sw - ox, 0))
        height = min(rng.randrange(13), max(sh - oy, 0))
        enabled = rng.randrange(2)
        x, y = rng.choice((rng.randrange(65), MAXIMUM)), rng.randrange(65)
        cols = rng.choice((rng.randrange(65), MAXIMUM))
        rows = rng.randrange(65) if enabled else rng.choice((rng.randrange(65), MAXIMUM))
        initial_x, initial_y = x, y
        code, mods = rng.randrange(9), rng.choice((0, 1, 2, 4, 64, 128, 193))
        plain = mods & ~192
        step = 32 if plain == 1 else 1
        if code in (0, 1) and plain in (0, 1):
            x = min(x + step, MAXIMUM) if code == 0 else max(x - step, 0)
        elif plain == 0:
            if code in (2, 4): y = max(y - (1 if code == 2 else 32), 0)
            elif code in (3, 5): y = min(y + (1 if code == 3 else 32), MAXIMUM)
            elif code == 6: y = MAXIMUM
            elif code == 7: y = 0
        bounded_x = min(x, max(min(cols + enabled, MAXIMUM) - width, 0))
        bounded_y = min(y, max(rows - height, 0))
        end_x = max(min(bounded_x + width, MAXIMUM) - enabled, 0)
        end_y = min(bounded_y + height, MAXIMUM)
        col = rng.choice((bounded_x, max(end_x - 1, 0), end_x, 0))
        row = rng.choice((bounded_y, max(end_y - 1, 0), end_y, 0))
        add("C", sw, sh, ox, oy, width, height, initial_x, initial_y, cols, rows, enabled,
            rng.randrange(5), rng.randrange(4), code, mods, col, row)
    for width in (0, 1, 5):
        add("C", width, 1, 0, 0, width, 1, MAXIMUM, 0, MAXIMUM, MAXIMUM, 1, 0, 1, 8, 0, MAXIMUM, 0)
    return cases


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("zig", type=Path)
    parser.add_argument("v", type=Path)
    parser.add_argument("--target", default="aarch64-macos.14.0")
    parser.add_argument("--v-prod", action="store_true")
    parser.add_argument("--v-path", help=argparse.SUPPRESS)
    args = parser.parse_args()
    source = args.source.resolve() / "src"
    digest = hashlib.sha256()
    for path in sorted(source.rglob("*")):
        if path.is_file():
            digest.update(path.relative_to(source).as_posix().encode() + b"\0")
            digest.update(path.read_bytes())
    if digest.hexdigest() != PINNED_VAXIS_SOURCE_SHA256:
        parser.error("src differs from the recorded local vaxis source")
    probe = Path(__file__).resolve().parent / "reference_probes/widgets"
    cases = corpus()
    with tempfile.TemporaryDirectory(prefix="witty-vaxis-widgets-") as directory:
        root = Path(directory)
        shutil.copytree(source, root / "src")
        shutil.copyfile(probe / "reference.zig", root / "reference.zig")
        zig = str(args.zig.resolve())
        native = [zig, "build-exe", "-target", args.target, "-lc", "--dep", "vaxis",
                  f"-Mroot={root / 'reference.zig'}", f"-Mvaxis={root / 'src/main.zig'}", f"-femit-bin={root / 'native'}"]
        subprocess.run(native, check=True)
        options = ["-prod"] if args.v_prod else []
        if args.v_path:
            options += ["-path", args.v_path]
        translated = [str(args.v.resolve()), *options, "-o", str(root / "translated"), str(probe / "main.v")]
        environment = dict(os.environ, VEXE=str(args.v.resolve()), V_C_ERROR_BUG_REPORT_DISABLED="1")
        subprocess.run(translated, env=environment, check=True)
        corpus_path = root / "corpus.txt"
        corpus_path.write_text("\n".join(cases) + "\n")
        outputs = [subprocess.run([str(root / executable), str(corpus_path)], capture_output=True,
                                  check=True, timeout=60).stdout.splitlines()
                   for executable in ("native", "translated")]
        if any(len(output) != len(cases) for output in outputs):
            raise AssertionError([len(cases)] + [len(output) for output in outputs])
        for index, (data, expected, actual) in enumerate(zip(cases, *outputs)):
            if expected != actual:
                raise AssertionError(f"row {index} ({data}): native={expected!r}, V={actual!r}")
        for mode, message in {"overflow_view": "integer overflow", "overflow_top": "integer overflow", "row_cast": "integer does not fit in destination type"}.items():
            for executable in ("native", "translated"):
                result = subprocess.run([str(root / executable), mode], capture_output=True, timeout=10)
                if result.returncode == 0 or message.encode() not in result.stderr + result.stdout:
                    raise AssertionError(f"{mode}: {executable} did not retain the checked trap")
        shutil.copyfile(probe / "read_unsupported.zig", root / "read_unsupported.zig")
        rejection = subprocess.run([zig, "build-exe", "-target", args.target, "-lc", "--dep", "vaxis",
            f"-Mroot={root / 'read_unsupported.zig'}", f"-Mvaxis={root / 'src/main.zig'}", f"-femit-bin={root / 'rejection'}"], capture_output=True)
        if rejection.returncode == 0 or b"expected type '?Cell', found 'void'" not in rejection.stderr:
            raise AssertionError("source ScrollView.readCell no longer rejects compilation")
        rejection = subprocess.run([str(args.v.resolve()), *options, "-o", str(root / "rejection_v"),
            str(probe / "read_unsupported.v")], env=environment, capture_output=True)
        if rejection.returncode == 0 or b"read_cell" not in rejection.stderr:
            raise AssertionError("V exposes the inherited noncompiling readCell boundary")
        result_hash = hashlib.sha256(b"\n".join(outputs[0])).hexdigest()
        print(f"Window widgets: {len(cases)} cases, 3 traps, 1 compile boundary, SHA256 {result_hash}")


if __name__ == "__main__":
    main()
