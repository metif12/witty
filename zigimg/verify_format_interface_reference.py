"""Compare all pinned format callbacks, including mismatched encoder options."""
import argparse
import hashlib
import os
from pathlib import Path
import resource
import shutil
import subprocess
import tempfile

from verify_png_foundation_reference import PINNED_SOURCE_SHA256


def no_core():
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))


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
    probe = Path(__file__).resolve().parent / "reference_probes/format_interface"
    with tempfile.TemporaryDirectory(prefix="witty-format-interface-") as directory:
        root = Path(directory)
        shutil.copytree(source, root / "src")
        shutil.copyfile(probe / "reference.zig", root / "reference.zig")
        subprocess.run([str(args.zig.resolve()), "build-exe", "-target", args.target,
                        "-lc", f"-femit-bin={root / 'native'}", str(root / "reference.zig")], check=True)
        subprocess.run([str(args.v.resolve()), "-o", str(root / "translated"), str(probe / "main.v")],
                       env=dict(os.environ, VEXE=str(args.v.resolve()), V_C_ERROR_BUG_REPORT_DISABLED="1"), check=True)
        outputs = [subprocess.run([str(root / executable)], capture_output=True, check=True, timeout=60).stdout.splitlines()
                   for executable in ("native", "translated")]
        expected = 49344
        if any(len(output) != expected for output in outputs):
            raise AssertionError([expected] + [len(output) for output in outputs])
        for native, translated in zip(*outputs):
            if native != translated:
                raise AssertionError(f"native={native!r}, V={translated!r}")
        digest = hashlib.sha256(b"\n".join(outputs[0])).hexdigest()
        print(f"Format interfaces: {expected} returning cases, SHA256 {digest}")
        for boundary in ("png", "tga"):
            for executable in ("native", "translated"):
                result = subprocess.run([str(root / executable), boundary], capture_output=True, timeout=5, preexec_fn=no_core)
                lines = result.stderr.splitlines() + result.stdout.splitlines()
                if result.returncode == 0 or any(line.startswith(b"UNEXPECTED") for line in lines) or not any(
                    marker in result.stderr for marker in (b"panic:", b"Assertion failed")
                ):
                    raise AssertionError((boundary, executable, result.returncode, result.stdout, result.stderr))
        print("Format interfaces: PNG/TGA wrong-option traps matched")


if __name__ == "__main__":
    main()
