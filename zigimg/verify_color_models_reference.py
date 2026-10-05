"""Compare color models and predefined colors with unchanged locked zigimg.

Comparisons preserve all defined f32 output bits, including signed zeros.
NaN payloads are canonicalized by the probes; their presence is still compared.
"""
import argparse
import hashlib
import itertools
import os
from pathlib import Path
import random
import shutil
import struct
import subprocess
import tempfile

PINNED_SOURCE_SHA256 = "ca759a44a902143a60f42f0810dc90df7250c0f92804cf201353f0141650eb6b"


def bits(value):
    return struct.unpack("<I", struct.pack("<f", value))[0]


def corpus():
    cases = []

    def add(label, mode, values):
        cases.append((label, "|".join(map(str, [mode] + list(values)))))

    boundaries = [bits(value) for value in (-2, -1, -0.5, -0.0, 0, 0.00000011920928955078125,
                  0.1, 0.5, 0.9, 1, 1.5, 2)]
    boundaries += [1, 0x007fffff, 0x00800000, 0x33800000, 0x34000001, 0x3f7fffff,
                   0x3f800001, 0x7f7fffff, 0xff7fffff, 0x7f800000, 0xff800000, 0x7fc00000]
    for index, values in enumerate(itertools.product(boundaries, repeat=3)):
        add(f"rgb-boundary-{index}", 0, (*values, boundaries[index % len(boundaries)]))
    hues = [-720, -360, -60, -0.0, 0, 30, 60, 120, 180, 240, 300, 360, 720, 10000]
    for index, (hue, saturation, value) in enumerate(itertools.product(hues, boundaries[:19], boundaries[:19])):
        add(f"hue-boundary-{index}", 1, (bits(hue), saturation, value, bits(1)))
    rng = random.Random(0xd7b7ab0b)
    for index in range(4096):
        channels = [bits(rng.uniform(-2, 2)) for _ in range(4)]
        add(f"rgb-random-{index}", 0, channels)
        add(f"cmyk-random-{index}", 2, channels)
        add(f"hue-random-{index}", 1, (bits(rng.uniform(-1080, 1080)), *channels[1:]))
    add("predefined", 3, [0, 0, 0, 0])
    return cases


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("zig", type=Path)
    parser.add_argument("v", type=Path)
    parser.add_argument("--target", default="aarch64-macos.14.0")
    args = parser.parse_args()
    source = args.source.resolve() / "src"
    digest = hashlib.sha256()
    for path in sorted(source.rglob("*")):
        if path.is_file():
            digest.update(path.relative_to(source).as_posix().encode() + b"\0")
            digest.update(path.read_bytes())
    if digest.hexdigest() != PINNED_SOURCE_SHA256:
        parser.error("src differs from locked zigimg")
    probe = Path(__file__).resolve().parent / "reference_probes/color_models"
    cases = corpus()
    with tempfile.TemporaryDirectory(prefix="witty-color-models-") as directory:
        root = Path(directory)
        shutil.copytree(source, root / "src")
        shutil.copyfile(probe / "reference.zig", root / "reference.zig")
        corpus_path = root / "corpus.txt"
        corpus_path.write_text("\n".join(case[1] for case in cases) + "\n")
        subprocess.run([str(args.zig.resolve()), "build-exe", "-target", args.target, "-lc",
                        f"-femit-bin={root / 'native'}", str(root / "reference.zig")], check=True)
        subprocess.run([str(args.v.resolve()), "-o", str(root / "translated"), str(probe / "main.v")],
                       env=dict(os.environ, VEXE=str(args.v.resolve())), check=True)
        outputs = [subprocess.run([str(root / executable), str(corpus_path)], capture_output=True,
                                  check=True, timeout=60).stdout.splitlines()
                   for executable in ("native", "translated")]
        if any(len(output) != len(cases) for output in outputs):
            raise AssertionError([len(cases)] + [len(output) for output in outputs])
        for (label, data), expected, actual in zip(cases, *outputs):
            if expected != actual:
                raise AssertionError(f"{label} ({data}): native={expected!r}, V={actual!r}")
        result_hash = hashlib.sha256(b"\n".join(outputs[0])).hexdigest()
        print(f"Color models: {len(cases)} cases, SHA256 {result_hash}")


if __name__ == "__main__":
    main()
