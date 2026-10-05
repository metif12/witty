"""Compare RGB colorspaces, gamma transfers, and borrowed/copy slices.

Every non-NaN f32 bit and the occurrence of NaNs are compared with the
unchanged source. Includes all presets, Bradford white-point adaptation,
all scalar wrappers and sixteen slice APIs, gamma factories and white points.
"""
import argparse
import itertools
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
    boundaries = [bits(value) for value in (-2, -1, -0.0, 0, 0.00000011920928955078125,
                  0.0031308, 0.004, 0.018, 0.0181, 0.031248, 0.04045, 0.5, 1, 2, 100, 512)]
    boundaries += [1, 0x007fffff, 0x00800000, 0x3f7fffff, 0x3f800001, 0x7f7fffff,
                   0xff7fffff, 0x7f800000, 0xff800000, 0x7fc00000]
    for source, target in itertools.product(range(12), repeat=2):
        for index, value in enumerate(boundaries):
            row = [source, target, value, boundaries[(index + 3) % len(boundaries)],
                   boundaries[(index + 7) % len(boundaries)], boundaries[(index + 11) % len(boundaries)]]
            cases.append((f"preset-{source}-to-{target}-boundary-{index}", "|".join(map(str, row))))
    rng = random.Random(0xd7b7ab0b)
    for index in range(2048):
        row = [rng.randrange(12), rng.randrange(12), *[bits(rng.uniform(-2, 2)) for _ in range(4)]]
        cases.append((f"random-{index}", "|".join(map(str, row))))
    return cases


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("zig", type=Path)
    parser.add_argument("v", type=Path)
    parser.add_argument("--target", default="aarch64-macos.14.0")
    parser.add_argument("--v-prod", action="store_true", help="also use V's production optimizer")
    args = parser.parse_args()
    source = args.source.resolve() / "src"
    digest = hashlib.sha256()
    for path in sorted(source.rglob("*")):
        if path.is_file():
            digest.update(path.relative_to(source).as_posix().encode() + b"\0")
            digest.update(path.read_bytes())
    if digest.hexdigest() != PINNED_SOURCE_SHA256:
        parser.error("src differs from locked zigimg")
    std_math = args.zig.resolve().parent / "lib/std/math"
    for name, expected in {'cbrt.zig': 'a4995a636473d996e6ffb75c8a2890ca24e9457110dbefe244c05b21440e24af', 'atan.zig': '14a8df19a689f837e78b9b22f3a375c69ec5cd4bb0443d37bc55be638701fe45', 'atan2.zig': 'ad6ac04bf60dbe2b88bb953080b0dcace55007dbce4eadccaa5a810baadcc76d', 'pow.zig': '5df36194e30a115dac017fbfff11eacc5ed7b44fe9e39404afe9c3bd30829591', 'frexp.zig': '2a9cf896243de2e7bf46513614eae704626b6a4898c54abc047df66759739080', 'ldexp.zig': '2c3c54f8e10fb9ebaae5443832bbc4ad3d87ff35a50e109b71c0d8844feaeeaa', 'modf.zig': '339b1dd9b92e0df04e9b0d57929f5390f032627dbd7af8699009322573439cdc'}.items():
        if hashlib.sha256((std_math / name).read_bytes()).hexdigest() != expected:
            parser.error(f"Zig std.math/{name} differs from pinned 0.15.2")
    probe = Path(__file__).resolve().parent / "reference_probes/color_space"
    cases = corpus()
    with tempfile.TemporaryDirectory(prefix="witty-color-space-") as directory:
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
        print(f"RGB colorspaces: {len(cases)} cases, SHA256 {result_hash}")


if __name__ == "__main__":
    main()
