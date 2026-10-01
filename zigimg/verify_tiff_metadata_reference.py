"""Verify the locked TIFF metadata implementation without modifying its source."""
import argparse
import hashlib
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

PINNED_SOURCE_SHA256 = "ca759a44a902143a60f42f0810dc90df7250c0f92804cf201353f0141650eb6b"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path, help="locked zigimg package directory")
    parser.add_argument("zig", type=Path, help="Zig 0.15.2 executable")
    parser.add_argument("--target", default="aarch64-macos.14.0")
    parser.add_argument("--probe-output", type=Path, help="also build the checked-boundary probe")
    args = parser.parse_args()
    source = args.source.resolve() / "src"
    digest = hashlib.sha256()
    for path in sorted(source.rglob("*")):
        if path.is_file():
            digest.update(path.relative_to(source).as_posix().encode() + b"\0")
            digest.update(path.read_bytes())
    if digest.hexdigest() != PINNED_SOURCE_SHA256:
        parser.error("src differs from locked zigimg d7b7ab0ba0899643831ef042bd73289510b39906")
    with tempfile.TemporaryDirectory(prefix="witty-tiff-metadata-reference-") as directory:
        root = Path(directory)
        shutil.copytree(source, root / "src")
        harness = Path(__file__).with_suffix(".zig")
        shutil.copyfile(harness, root / harness.name)
        result = subprocess.run([str(args.zig.resolve()), "run", "-target", args.target, "-lc", str(root / harness.name)], check=False)
        if result.returncode:
            return result.returncode
        if args.probe_output:
            probe = Path(__file__).parent / "reference_probes/tiff_metadata_bounds/reference.zig"
            shutil.copyfile(probe, root / "probe.zig")
            result = subprocess.run([str(args.zig.resolve()), "build-exe", "-target", args.target, "-lc", f"-femit-bin={args.probe_output.resolve()}", str(root / "probe.zig")], check=False)
        return result.returncode


if __name__ == "__main__":
    sys.exit(main())
