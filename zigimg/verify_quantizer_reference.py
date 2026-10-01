"""Run the locked private quantizer without changing its implementation."""
import argparse
import hashlib
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

PINNED_FILES = {
    "src/OctTreeQuantizer.zig": "5991bb475650bf8e20c7f72406de1d4c06670fc78f8fef1e210e9b322b5adf6a",
    "src/color.zig": "86370d212ed51f8654bfc455429c388db2376d456968cb9b07e89e8bffed092a",
    "src/math.zig": "acb177e4f6f7d563c6258112aef0ee18923d0173e31c44955458faeaa7d32dd8",
    "src/pixel_format.zig": "f9a27b5445def059ed17a9d524ba977a073a33263945187d23e420ec6b7b3664",
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path, help="locked zigimg package directory")
    parser.add_argument("zig", type=Path, help="Zig 0.15.2 executable")
    parser.add_argument("--target", default="aarch64-macos.14.0")
    parser.add_argument("--probe-output", type=Path, help="also build the checked-boundary probe")
    args = parser.parse_args()
    source = args.source.resolve()
    for name, digest in PINNED_FILES.items():
        if hashlib.sha256((source / name).read_bytes()).hexdigest() != digest:
            parser.error(f"{name} differs from locked zigimg d7b7ab0ba0899643831ef042bd73289510b39906")
    with tempfile.TemporaryDirectory(prefix="witty-quantizer-reference-") as directory:
        root = Path(directory)
        shutil.copytree(source / "src", root / "src")
        harness = Path(__file__).with_suffix(".zig")
        shutil.copyfile(harness, root / harness.name)
        result = subprocess.run([str(args.zig.resolve()), "run", "-target", args.target, "-lc", str(root / harness.name)], check=False)
        if result.returncode:
            return result.returncode
        if args.probe_output:
            probe = Path(__file__).parent / "reference_probes/quantizer_bounds/reference.zig"
            shutil.copyfile(probe, root / "probe.zig")
            result = subprocess.run([str(args.zig.resolve()), "build-exe", "-target", args.target, "-lc", f"-femit-bin={args.probe_output.resolve()}", str(root / "probe.zig")], check=False)
        return result.returncode


if __name__ == "__main__":
    sys.exit(main())
