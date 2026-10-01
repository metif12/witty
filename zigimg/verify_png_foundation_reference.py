"""Run PNG header/filter/processor checks against unchanged locked zigimg."""
import argparse
import hashlib
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

PINNED_SOURCE_SHA256 = "ca759a44a902143a60f42f0810dc90df7250c0f92804cf201353f0141650eb6b"
PINNED_FLATE_SHA256 = "e8898fcced291d899efc9ebacf42762954ac5a1e088283cee0f1f261a498cab5"
FLATE_SOURCES = ["compress/flate.zig", "compress/flate/Decompress.zig",
                 "compress/flate/Token.zig", "compress/flate/HuffmanEncoder.zig",
                 "Io/Reader.zig", "Io/Writer.zig"]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("zig", type=Path)
    parser.add_argument("--v", type=Path, help="also build and compare checked-trap/loop probes")
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
    digest = hashlib.sha256()
    for name in FLATE_SOURCES:
        digest.update(name.encode() + b"\0")
        digest.update((args.zig.resolve().parent / "lib/std" / name).read_bytes())
    if digest.hexdigest() != PINNED_FLATE_SHA256:
        parser.error("DEFLATE/reader/writer sources differ from Zig 0.15.2")
    with tempfile.TemporaryDirectory(prefix="witty-png-foundation-") as directory:
        root = Path(directory)
        shutil.copytree(source, root / "src")
        harness = Path(__file__).with_suffix(".zig")
        shutil.copyfile(harness, root / harness.name)
        subprocess.run([str(args.zig.resolve()), "run", "-target", args.target, "-lc", str(root / harness.name)], check=True)
        if args.v:
            probe = Path(__file__).parent / "reference_probes/png_foundation_bounds"
            shutil.copyfile(probe / "reference.zig", root / "reference.zig")
            subprocess.run([str(args.zig.resolve()), "build-exe", "-target", args.target, "-lc", f"-femit-bin={root / 'native'}", str(root / "reference.zig")], check=True)
            subprocess.run([str(args.v.resolve()), "-o", str(root / "translated"), str(probe / "main.v")], env=dict(os.environ, VEXE=str(args.v.resolve())), check=True)
            subprocess.run([sys.executable, str(probe / "verify.py"), str(root / "translated"), str(root / "native")], check=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
