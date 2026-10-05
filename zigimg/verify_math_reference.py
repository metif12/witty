"""Compare all locked vector/matrix helper APIs with unchanged zigimg source.

The probes compare every non-NaN f32 bit and the occurrence of NaNs. Matrices
include singular and zero-pivot inputs; the native source supplies results.
"""
import argparse
import hashlib
import os
from pathlib import Path
import random
import shutil
import struct
import subprocess
import tempfile

from verify_color_models_reference import PINNED_SOURCE_SHA256, bits


def corpus():
    cases = []
    rng = random.Random(0xca759a44)
    boundaries = [bits(value) for value in (-2, -1, -0.0, 0, 0.5, 1, 2)]
    boundaries += [1, 0x007fffff, 0x00800000, 0x3f7fffff, 0x3f800001, 0x7f7fffff,
                   0xff7fffff, 0x7f800000, 0xff800000, 0x7fc00000]
    for dimension in (2, 3, 4):
        size = dimension * dimension

        def add(label, values):
            cases.append((f"{dimension}-{label}", "|".join(map(str, [dimension] + values))))

        identity = [bits(int(row == column)) for row in range(dimension) for column in range(dimension)]
        for index, value in enumerate(boundaries):
            add(f"uniform-{index}", [value] * (size * 2 + dimension + 2))
            add(f"diagonal-{index}", [value if row == column else bits(0)
                for row in range(dimension) for column in range(dimension)]
                + identity + [value] * dimension + [bits(0), bits(1)])
        for index in range(2048):
            values = [bits(rng.uniform(-4, 4)) for _ in range(size * 2 + dimension + 2)]
            add(f"random-{index}", values)
            values = [rng.choice(boundaries) for _ in range(size * 2 + dimension + 2)]
            add(f"boundary-{index}", values)
        for index in range(size):
            left = identity[:]
            left[index] = bits(0)
            add(f"zero-pivot-{index}", left + identity + [bits(1)] * dimension + [bits(0), bits(1)])
    return cases


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("zig", type=Path)
    parser.add_argument("v", type=Path)
    parser.add_argument("--target", default="aarch64-macos.14.0")
    parser.add_argument("--v-prod", action="store_true", help="use V production optimization")
    args = parser.parse_args()
    source = args.source.resolve() / "src"
    digest = hashlib.sha256()
    for path in sorted(source.rglob("*")):
        if path.is_file():
            digest.update(path.relative_to(source).as_posix().encode() + b"\0")
            digest.update(path.read_bytes())
    if digest.hexdigest() != PINNED_SOURCE_SHA256:
        parser.error("src differs from locked zigimg")
    probe = Path(__file__).resolve().parent / "reference_probes/math"
    cases = corpus()
    with tempfile.TemporaryDirectory(prefix="witty-image-math-") as directory:
        root = Path(directory)
        shutil.copytree(source, root / "src")
        shutil.copyfile(probe / "reference.zig", root / "reference.zig")
        corpus_path = root / "corpus.txt"
        corpus_path.write_text("\n".join(case[1] for case in cases) + "\n")
        subprocess.run([str(args.zig.resolve()), "build-exe", "-target", args.target, "-lc",
                        f"-femit-bin={root / 'native'}", str(root / "reference.zig")], check=True)
        v_options = ["-prod"] if args.v_prod else []
        subprocess.run([str(args.v.resolve()), *v_options, "-o", str(root / "translated"), str(probe / "main.v")],
                       env=dict(os.environ, VEXE=str(args.v.resolve()), V_C_ERROR_BUG_REPORT_DISABLED="1"), check=True)
        outputs = [subprocess.run([str(root / executable), str(corpus_path)], capture_output=True,
                                  check=True, timeout=60).stdout.splitlines()
                   for executable in ("native", "translated")]
        if any(len(output) != len(cases) for output in outputs):
            raise AssertionError([len(cases)] + [len(output) for output in outputs])
        for (label, data), expected, actual in zip(cases, *outputs):
            if expected != actual:
                raise AssertionError(f"{label} ({data}): native={expected!r}, V={actual!r}")
        result_hash = hashlib.sha256(b"\n".join(outputs[0])).hexdigest()
        print(f"Image math: {len(cases)} cases, SHA256 {result_hash}")


if __name__ == "__main__":
    main()
