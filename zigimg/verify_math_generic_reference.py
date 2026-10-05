"""Compare generic fixed-array matrices with unchanged locked math.zig.

Includes dimensions 1, 2, 3, 4, 5 and 8, existing concrete matrix types,
and a custom named array alias. Non-NaN bits and NaN occurrence are compared.
V shape guards are checked separately, including in production mode.
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
    for dimension in (1, 2, 3, 4, 5, 8):
        size = dimension * dimension

        def add(label, values):
            cases.append((f"{dimension}-{label}", "|".join(map(str, [dimension] + values))))

        identity = [bits(int(row == column)) for row in range(dimension) for column in range(dimension)]
        for index, value in enumerate(boundaries):
            add(f"uniform-{index}", [value] * (size * 2 + dimension))
            add(f"diagonal-{index}", [value if row == column else bits(0)
                for row in range(dimension) for column in range(dimension)]
                + identity + [value] * dimension)
        for index in range(512):
            values = [bits(rng.uniform(-4, 4)) for _ in range(size * 2 + dimension)]
            add(f"random-{index}", values)
            values = [rng.choice(boundaries) for _ in range(size * 2 + dimension)]
            add(f"boundary-{index}", values)
        for index in range(size):
            left = identity[:]
            left[index] = bits(0)
            add(f"zero-pivot-{index}", left + identity + [bits(1)] * dimension)
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
    probe = Path(__file__).resolve().parent / "reference_probes/math_generic"
    cases = corpus()
    with tempfile.TemporaryDirectory(prefix="witty-generic-matrix-") as directory:
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
        for mode, message in {
            "rectangular": "Matrix requires square fixed-array rows",
            "short_array": "Matrix.from_array requires N*N components",
            "short_vector": "Matrix.mul_vector requires N components",
        }.items():
            result = subprocess.run([str(root / "translated"), mode], capture_output=True, timeout=10)
            if result.returncode == 0 or message.encode() not in result.stderr + result.stdout:
                raise AssertionError(f"{mode}: shape guard was not retained")
        result_hash = hashlib.sha256(b"\n".join(outputs[0])).hexdigest()
        print(f"Generic matrices: {len(cases)} cases, 3 shape guards, SHA256 {result_hash}")


if __name__ == "__main__":
    main()
