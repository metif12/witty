"""Run the locked private quantizer without changing its implementation."""
import argparse
import hashlib
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

from verify_png_foundation_reference import PINNED_SOURCE_SHA256

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
    parser.add_argument("v", type=Path, nargs="?", help="also compare V aliases and checked boundaries")
    parser.add_argument("--target", default="aarch64-macos.14.0")
    parser.add_argument("--v-prod", action="store_true", help="use V production optimization")
    parser.add_argument("--zig-mode", choices=("Debug", "ReleaseSafe"), default="Debug")
    parser.add_argument("--probe-output", type=Path, help="also build the checked-boundary probe")
    args = parser.parse_args()
    source = args.source.resolve()
    digest = hashlib.sha256()
    for path in sorted((source / "src").rglob("*")):
        if path.is_file():
            digest.update(path.relative_to(source / "src").as_posix().encode() + b"\0")
            digest.update(path.read_bytes())
    if digest.hexdigest() != PINNED_SOURCE_SHA256:
        parser.error("src differs from locked zigimg d7b7ab0ba0899643831ef042bd73289510b39906")
    for name, digest in PINNED_FILES.items():
        if hashlib.sha256((source / name).read_bytes()).hexdigest() != digest:
            parser.error(f"{name} differs from locked zigimg d7b7ab0ba0899643831ef042bd73289510b39906")
    with tempfile.TemporaryDirectory(prefix="witty-quantizer-reference-") as directory:
        root = Path(directory)
        shutil.copytree(source / "src", root / "src")
        harness = Path(__file__).with_suffix(".zig")
        shutil.copyfile(harness, root / harness.name)
        zig_flags = ["-target", args.target, "-O", args.zig_mode, "-lc"]
        result = subprocess.run([str(args.zig.resolve()), "run", *zig_flags, str(root / harness.name)], check=False)
        if result.returncode:
            return result.returncode
        if args.probe_output or args.v:
            probe = Path(__file__).parent / "reference_probes/quantizer_bounds/reference.zig"
            shutil.copyfile(probe, root / "probe.zig")
            native_bounds = args.probe_output.resolve() if args.probe_output else root / "native-bounds"
            result = subprocess.run([str(args.zig.resolve()), "build-exe", *zig_flags, f"-femit-bin={native_bounds}", str(root / "probe.zig")], check=False)
            if result.returncode:
                return result.returncode
        if args.v:
            v = str(args.v.resolve())
            v_flags = ["-prod"] if args.v_prod else []
            env = dict(os.environ, VEXE=v, V_C_ERROR_BUG_REPORT_DISABLED="1",
                WITTY_QUANTIZER_TREE_OUTPUT=str(root / "tree-hash"),
                WITTY_QUANTIZER_NORMALIZATION_OUTPUT=str(root / "normalization-hash"))

            def checked(command, **kwargs):
                result = subprocess.run(command, capture_output=True, **kwargs)
                if result.returncode:
                    sys.stderr.buffer.write(result.stdout + result.stderr)
                    result.check_returncode()
                return result

            probe_root = Path(__file__).resolve().parent / "reference_probes"
            checked([v, *v_flags, str(Path(__file__).with_name("oct_tree_quantizer_test.v").resolve())], env=env)
            assert (root / "tree-hash").read_text() == "2160,fb25faff7d5b5837"
            assert (root / "normalization-hash").read_text() == "336128,2e3cf0cdc340afc4"
            print("V baseline hashes: fb25faff7d5b5837 / 2e3cf0cdc340afc4")
            checked([v, *v_flags, "-o", str(root / "translated-bounds"), str(probe_root / "quantizer_bounds/main.v")], env=env)
            subprocess.run([sys.executable, str(probe_root / "quantizer_bounds/verify.py"),
                str(root / "translated-bounds"), str(native_bounds)], check=True)
            shutil.copyfile(probe_root / "quantizer_aliases/reference.zig", root / "aliases.zig")
            checked([str(args.zig.resolve()), "build-exe", *zig_flags,
                f"-femit-bin={root / 'native-aliases'}", str(root / "aliases.zig")])
            checked([v, *v_flags, "-o", str(root / "translated-aliases"),
                str(probe_root / "quantizer_aliases/main.v")], env=env)
            outputs = [checked([str(root / name)], timeout=60).stdout.splitlines()
                for name in ("native-aliases", "translated-aliases")]
            if any(len(rows) != 2816 for rows in outputs):
                raise AssertionError([len(rows) for rows in outputs])
            for native, translated in zip(*outputs):
                if native != translated:
                    raise AssertionError((native, translated))
            digest = hashlib.sha256(b"\n".join(outputs[0])).hexdigest()
            print(f"Quantizer aliases: 2816 returning records, SHA256 {digest}")
        return result.returncode


if __name__ == "__main__":
    sys.exit(main())
