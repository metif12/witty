"""Compare named PixelFormat methods and the defined packed-info carrier domain."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil

from verify_tiff_decode_reference import PINNED_SOURCE_SHA256, ProofLog, checked_trap, tree_hash, work_directory

WORDS = (0, 1, 2, 4, 8, 16, 0x101, 0x102, 0x104, 0x108, 0x110, 0x208, 0x210,
         0x303, 0x305, 0x3305, 0x308, 0x408, 0x1305, 0x1308, 0x1408, 0x310, 0x410, 0x2420)
PREFIX_ROWS = 1 + 1024 + 24
EXPECTED_ROWS = PREFIX_ROWS + 24 + 65536 * 3 + 32 * 3
EXPECTED_SHA256 = "9eeaca0cd04514798359ff079b7f9d7f80fd838a8b53bde663154f317a87d349"


def corpus():
    rows = [(f"named-{raw:x}", f"F|{raw}") for raw in WORDS]
    for padding in (0, 32768, 65535):
        for lower in range(65536):
            raw = padding << 16 | lower
            rows.append((f"packed-{raw:08x}", f"I|{raw}|{raw ^ 0xa5a5a5a5}"))
    for bit in range(32):
        for raw in ((1 << bit), 0xffffffff ^ (1 << bit), 0xffffffff):
            rows.append((f"bit-{bit}-{raw:08x}", f"I|{raw}|{raw ^ 0xffffffff}"))
    return rows


def reject(result, label, expression):
    diagnostic = (result.stdout + result.stderr).decode(errors="replace")
    if (result.returncode <= 0 or any(text in diagnostic.lower() for text in
            ("panic:", "compiler bug", "internal compiler error", "c error found", "segmentation fault"))
            or not re.search(r"^(?:[^\n]*:\d+:\d+: )?error: " + expression + r"$", diagnostic, re.M)):
        raise AssertionError(label + ": expected ordinary compiler diagnostic\n" + diagnostic)


def compiler_boundaries(proof, root, args, env, repo):
    fixtures = {
        "bits-width": ("const x:p.PixelFormatInfo=.{.bits_per_channel=256};_=x;", r"type 'u8' cannot represent integer value '256'"),
        "channel-width": ("const x:p.PixelFormatInfo=.{.channel_count=16};_=x;", r"type 'u4' cannot represent integer value '16'"),
        "variant-width": ("const x:p.PixelFormatInfo=.{.variant=@enumFromInt(16)};_=x;", r"int value '16' out of range of non-exhaustive enum 'src\.pixel_format\.PixelFormatVariant'"),
        "variant-byte-width": ("const x:p.PixelFormatInfo=.{.variant=@enumFromInt(255)};_=x;", r"int value '255' out of range of non-exhaustive enum 'src\.pixel_format\.PixelFormatVariant'"),
        "padding-width": ("const x:p.PixelFormatInfo=.{.padding=65536};_=x;", r"type 'u16' cannot represent integer value '65536'"),
        "runtime-value": ("const args=try std.process.argsAlloc(std.heap.page_allocator);const raw=try std.fmt.parseInt(u32,args[1],10);const x:p.PixelFormatInfo=@bitCast(raw);_=p.toPixelFormatValue(x);", r"unable to resolve comptime value"),
        "v-carrier-field": ("const x:p.PixelFormatInfo=.{.raw=0};_=x;", r"no field named 'raw' in struct .*PixelFormatInfo.*"),
    }
    for name, (body, expression) in fixtures.items():
        path = root / (name + ".zig")
        path.write_text('const std=@import("std");const p=@import("src/pixel_format.zig");pub fn main() !void {' + body + '}\n')
        result = proof.run([str(args.zig.resolve()), "build-exe", "-target", args.target, "-O", args.zig_mode,
                           "-lc", "--global-cache-dir", str(root / "zig-cache"), "-fno-emit-bin", str(path)],
                          "source-reject-" + name, check=False)
        reject(result, name, expression)
    # V has a numeric carrier field and projection methods in place of Source bit-fields.
    for field, value in (("bits_per_channel", "8"), ("channel_count", "3"),
                         ("variant", ".none"), ("padding", "1")):
        path = root / ("v-field-" + field + ".v")
        path.write_text('module main\nimport zigimg\nfn main(){x:=zigimg.PixelFormatInfo{' + field + ':' + value + '} _=x}\n')
        result = proof.run([str(args.v.resolve()), *(["-prod"] if args.v_prod else []), "-path",
                           f"{repo}|@vlib|@vmodules", "-check", str(path)],
                          "v-reject-field-" + field, env=env, check=False)
        reject(result, field, r"unknown field [`']" + field + r"[`'] in struct literal of type [`']zigimg.PixelFormatInfo[`']\.")
    path = root / "v-runtime-value.v"
    path.write_text('module main\nimport os\nimport zigimg\nfn main(){info:=zigimg.PixelFormatInfo{raw:os.args[1].u32()} println(zigimg.to_pixel_format_value(info))}\n')
    result = proof.run([str(args.v.resolve()), *(["-prod"] if args.v_prod else []), "-path",
                       f"{repo}|@vlib|@vmodules", "-check", str(path)], "v-runtime-value-acceptance", env=env)
    if re.search(rb"(?:^|\n).*error:", result.stdout + result.stderr):
        raise AssertionError("V runtime carrier acceptance had an error diagnostic")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("zig", type=Path)
    parser.add_argument("v", type=Path)
    parser.add_argument("--target", default="aarch64-macos.14.0")
    parser.add_argument("--v-prod", action="store_true")
    parser.add_argument("--zig-mode", choices=("Debug", "ReleaseSafe"))
    parser.add_argument("--workdir", type=Path)
    parser.add_argument("--timeout", type=int, default=180)
    args = parser.parse_args()
    args.zig_mode = args.zig_mode or ("ReleaseSafe" if args.v_prod else "Debug")
    if args.timeout <= 0:
        parser.error("--timeout must be positive")
    source = args.source.resolve() / "src"
    if tree_hash(source) != PINNED_SOURCE_SHA256:
        parser.error("src differs from unchanged pinned zigimg")
    repo = Path(__file__).resolve().parent.parent
    probe = repo / "zigimg/reference_probes/pixel_format"
    env = dict(os.environ, VEXE=str(args.v.resolve()), V_C_ERROR_BUG_REPORT_DISABLED="1")
    rows = corpus()
    if len(rows) + PREFIX_ROWS != EXPECTED_ROWS:
        raise AssertionError("record corpus count changed")
    with work_directory(args.workdir, "witty-pixel-format-") as root:
        proof = ProofLog(root)
        shutil.copytree(source, root / "src")
        if tree_hash(root / "src") != PINNED_SOURCE_SHA256:
            raise AssertionError("copied Source changed")
        fixtures = {}
        for name in ("reference.zig", "main.v"):
            shutil.copyfile(probe / name, root / name)
            fixtures[name] = hashlib.sha256((root / name).read_bytes()).hexdigest()
        versions = [proof.run([str(exe.resolve()), "version"], f"version-{name}", env=env).stdout.decode().strip()
                    for exe, name in ((args.zig, "zig"), (args.v, "v"))]
        if versions[0] != "0.15.2" or not re.match(r"^V 0\.5\.2(?: |$)", versions[1]):
            raise AssertionError("compiler versions differ from pinned compilers")
        provenance = {"source_revision": "d7b7ab0ba0899643831ef042bd73289510b39906", "source_sha256": PINNED_SOURCE_SHA256,
                      "versions": versions, "target": args.target, "zig_mode": args.zig_mode, "v_prod": args.v_prod,
                      "fixture_hashes": fixtures, "runner_hash": hashlib.sha256(Path(__file__).read_bytes()).hexdigest()}
        (root / "provenance.json").write_text(json.dumps(provenance, indent=2) + "\n")
        print(f"Building PixelFormat Source {args.zig_mode} and V {'production' if args.v_prod else 'ordinary'}", flush=True)
        proof.run([str(args.zig.resolve()), "build-exe", "-target", args.target, "-O", args.zig_mode,
                   "-lc", "--global-cache-dir", str(root / "zig-cache"), f"-femit-bin={root / 'native'}",
                   str(root / "reference.zig")], "build-source", timeout=args.timeout)
        proof.run([str(args.v.resolve()), *(["-prod"] if args.v_prod else []), "-path", f"{repo}|@vlib|@vmodules",
                   "-o", str(root / "translated"), str(root / "main.v")], "build-v", env=env, timeout=args.timeout)
        path = root / "corpus.txt"
        path.write_text("\n".join(row for _, row in rows) + "\n")
        print(f"Comparing {EXPECTED_ROWS} defined public-method/packed-record observations", flush=True)
        results = [proof.run([str(root / executable), str(path)], "returning-" + executable, timeout=args.timeout)
                   for executable in ("native", "translated")]
        outputs = [result.stdout.splitlines() for result in results]
        if any(result.stderr for result in results) or any(len(output) != EXPECTED_ROWS for output in outputs):
            raise AssertionError("unexpected diagnostic or record count")
        for index, (expected, actual) in enumerate(zip(*outputs)):
            if expected != actual:
                label = "defaults/constants/variants" if index < PREFIX_ROWS else rows[index - PREFIX_ROWS][0]
                raise AssertionError(f"{label}: Source={expected!r}, V={actual!r}")
        digest = hashlib.sha256(b"\n".join(outputs[0])).hexdigest()
        if EXPECTED_SHA256 and digest != EXPECTED_SHA256:
            raise AssertionError("returning golden changed: " + digest)
        print(f"PixelFormat: {EXPECTED_ROWS} records SHA256 {digest}", flush=True)
        for name in ("rgb332", "rgb565"):
            for executable in ("native", "translated"):
                label = "trap-" + name + "-" + executable
                result = proof.run([str(root / executable), "--trap", name], label, check=False)
                checked_trap(result, label, "reached unreachable code")
        compiler_boundaries(proof, root, args, env, repo)
        for value in (16, 255):
            observed = proof.run([str(root / "translated"), "--variant-wide", str(value)],
                                 "v-variant-wide-" + str(value))
            if observed.stderr or observed.stdout != f"{value}\n".encode():
                raise AssertionError("V numeric variant carrier width boundary changed")
        if tree_hash(source) != PINNED_SOURCE_SHA256 or tree_hash(root / "src") != PINNED_SOURCE_SHA256:
            raise AssertionError("Source changed during proof")
        for name, value in fixtures.items():
            if any(hashlib.sha256(path.read_bytes()).hexdigest() != value for path in (probe/name, root/name)):
                raise AssertionError("fixture changed during proof")
        if hashlib.sha256(Path(__file__).read_bytes()).hexdigest() != provenance["runner_hash"]:
            raise AssertionError("runner changed during proof")
        summary = {"returning_records": EXPECTED_ROWS, "output_sha256": digest, "paired_strict_traps":2,
                   "named_formats":24, "comptime_packing_controls":1024, "source_only_compile_boundaries":7, "v_wide_variant_observations":2,
                   "v_record_shape_rejections":4, "v_runtime_carrier_acceptances":1,
                   "zig_mode":args.zig_mode, "v_prod":args.v_prod}
        (root/"summary.json").write_text(json.dumps(summary,indent=2)+"\n")
        print(json.dumps(summary),flush=True)


if __name__ == "__main__":
    main()
