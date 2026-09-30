"""Run the locked package's private compression modules without editing it."""

import argparse
import hashlib
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

PINNED_FILES = {
    "src/io.zig": "cd79888d89932cff1dc30492f842c71a3aacd62b8d2b1713d0df4d5ef70c7035",
    "src/compressions/lzw.zig": "280dcb682c031e7c955261c1d2410540c2adcbb99b48329a2125d97480ab395c",
    "src/compressions/packbits.zig": "6072dd53b3268255a6ee1f22b7e48f96b1451c2ee835fb441a856dc76e7c2500",
    "src/compressions/ccitt.zig": "cc92242a9f208ced9e7ad0de4e0bf6c80fb82022efb7703e8479db1f1b6e9a39",
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path, help="locked zigimg package directory")
    parser.add_argument("zig", type=Path, help="Zig 0.15.2 executable")
    parser.add_argument("--target", default="aarch64-macos.14.0")
    args = parser.parse_args()
    source = args.source.resolve()
    for name, digest in PINNED_FILES.items():
        if hashlib.sha256((source / name).read_bytes()).hexdigest() != digest:
            parser.error(f"{name} differs from locked zigimg d7b7ab0ba0899643831ef042bd73289510b39906")
    with tempfile.TemporaryDirectory(prefix="witty-compressions-reference-") as directory:
        root = Path(directory)
        shutil.copytree(source / "src", root / "src")
        harness = Path(__file__).with_suffix(".zig")
        shutil.copyfile(harness, root / harness.name)
        result = subprocess.run(
            [str(args.zig.resolve()), "run", "-target", args.target, "-lc", str(root / harness.name)],
            check=False,
        )
        return result.returncode


if __name__ == "__main__":
    sys.exit(main())
