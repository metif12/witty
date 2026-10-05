"""Compare magic numbers and enum-checked native-layout reads with locked zigimg."""
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
    probe = Path(__file__).resolve().parent / "reference_probes/utils"
    with tempfile.TemporaryDirectory(prefix="witty-utils-") as directory:
        root = Path(directory)
        shutil.copytree(source, root / "src")
        shutil.copyfile(probe / "reference.zig", root / "reference.zig")
        subprocess.run([str(args.zig.resolve()), "build-exe", "-target", args.target,
                        "-lc", f"-femit-bin={root / 'native'}", str(root / "reference.zig")], check=True)
        v_options = ["-prod"] if args.v_prod else []
        subprocess.run([str(args.v.resolve()), *v_options, "-o", str(root / "translated"), str(probe / "main.v")],
                       env=dict(os.environ, VEXE=str(args.v.resolve()), V_C_ERROR_BUG_REPORT_DISABLED="1"), check=True)
        outputs = [subprocess.run([str(root / executable)], capture_output=True, check=True, timeout=60).stdout.splitlines()
                   for executable in ("native", "translated")]
        expected = 20992
        if any(len(output) != expected for output in outputs):
            raise AssertionError([expected] + [len(output) for output in outputs])
        for native, translated in zip(*outputs):
            if native != translated:
                raise AssertionError(f"native={native!r}, V={translated!r}")
        digest = hashlib.sha256(b"\n".join(outputs[0])).hexdigest()
        print(f"Utilities: {expected} returning cases, SHA256 {digest}")
        outputs = [subprocess.run([str(root / executable), "aliases"], capture_output=True,
                                  check=True, timeout=60).stdout.splitlines()
                   for executable in ("native", "translated")]
        expected = 54528
        if any(len(output) != expected for output in outputs):
            raise AssertionError([expected] + [len(output) for output in outputs])
        for native, translated in zip(*outputs):
            if native != translated:
                raise AssertionError(f"alias native={native!r}, V={translated!r}")
        digest = hashlib.sha256(b"\n".join(outputs[0])).hexdigest()
        print(f"Utilities: {expected} alias cases, SHA256 {digest}")
        for boundary in ("native", "foreign"):
            for executable in ("native", "translated"):
                result = subprocess.run([str(root / executable), boundary], capture_output=True, timeout=5, preexec_fn=no_core)
                lines = result.stderr.splitlines() + result.stdout.splitlines()
                if result.returncode == 0 or any(line.startswith(b"UNEXPECTED") for line in lines) or not any(
                    marker in result.stderr for marker in (b"panic:", b"Assertion failed", b"slice:")
                ):
                    raise AssertionError((boundary, executable, result.returncode, result.stdout, result.stderr))
        print("Utilities: two checked shift traps matched")
        for name in ("native_writer", "foreign_writer"):
            shutil.copyfile(probe / f"{name}.zig", root / f"{name}.zig")
            result = subprocess.run([str(args.zig.resolve()), "build-exe", "-target", args.target,
                                     "-lc", f"-femit-bin={root / name}", str(root / f"{name}.zig")], capture_output=True)
            if result.returncode == 0 or b"has no member named 'StreamSource'" not in result.stderr:
                raise AssertionError((name, result.returncode, result.stderr))
        print("Utilities: two inherited struct writer compilation failures confirmed")
        fields = (
            ("words", "[2]u16", "[2]u16", "only supports byte arrays"),
            ("alias_words", "AliasWords", "AliasWords", "only supports byte arrays"),
            ("slice", "[]u8", "[]u8", "requires inline byte arrays"),
            ("alias_slice", "AliasBytes", "AliasBytes", "requires inline byte arrays"),
        )
        repository = Path(__file__).resolve().parent.parent
        for name, v_type, zig_type, diagnostic in fields:
            zig_fixture = root / f"unsupported_{name}.zig"
            zig_fixture.write_text('''const std = @import("std");
const utils = @import("src/utils.zig");
const AliasByte = u8;
const AliasBytes = []AliasByte;
const AliasWords = [2]u16;
const Header = struct { bytes: ''' + zig_type + ''' };
pub fn main() !void {
    const bytes = [_]u8{0} ** @sizeOf(Header);
    var reader = std.Io.Reader.fixed(&bytes);
    _ = try utils.takeStructForeign(&reader, Header);
}
''')
            result = subprocess.run([str(args.zig.resolve()), "build-exe", "-target", args.target,
                                     "-lc", f"-femit-bin={root / name}", str(zig_fixture)], capture_output=True)
            if result.returncode == 0 or b"in swapFieldBytes" not in result.stderr:
                raise AssertionError((name, "native", result.returncode, result.stderr))
            v_fixture = root / f"unsupported_{name}.v"
            v_fixture.write_text('''module main
import zigimg
type AliasByte = u8
type AliasBytes = []AliasByte
type AliasWords = [2]u16
struct Header { bytes ''' + v_type + ''' }
fn main() {
    mut reader := zigimg.ReadStream.init_memory([]u8{len: int(sizeof(Header))})
    _ := zigimg.take_struct_foreign[Header](mut reader) or { panic(err) }
}
''')
            result = subprocess.run([str(args.v.resolve()), "-check", "-path",
                                     f"{repository}|@vlib|@vmodules", str(v_fixture)],
                                    env=dict(os.environ, VEXE=str(args.v.resolve()),
                                             V_C_ERROR_BUG_REPORT_DISABLED="1"), capture_output=True)
            if result.returncode == 0 or diagnostic.encode() not in result.stderr + result.stdout:
                raise AssertionError((name, "translated", result.returncode, result.stdout, result.stderr))
        print("Utilities: four unsupported array-field compilation failures matched")


if __name__ == "__main__":
    main()
