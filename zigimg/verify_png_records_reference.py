"""Compare required PNG records, mutable fields, defaults, and live borrows."""
import argparse
import hashlib
import itertools
import json
import os
from pathlib import Path
import re
import shutil

from verify_png_header_reference import PINNED_SOURCE_SHA256
from verify_tiff_decode_reference import ProofLog, tree_hash, work_directory
from verify_simd_reference import ordinary_rejection

MEMORY_FILES = ("mem.zig", "debug.zig")
PINNED_MEMORY_SHA256 = "d8e33d24ad79f9e3cf7694a9914bcf8023d5125b15f1b51930fab0e91114e65e"
EXPECTED_ROWS = 10451
EXPECTED_SHA256 = "9cc70d9461b1b38135ca9ed12406d7016c9278e646074cf91277957908a24e03"
EXPECTED_SOURCE_BOX_SHA256 = "1469df14428bc421bcc4aff834e1f6a6cf634da1a3ab3a82c5b8f8e053ef753b"
EXPECTED_V_BOX_SHA256 = "d7f2fe6c87190cd8191c99c70372a837aba9f1320edd828762c815f08a7c52eb"
CONTRACTS = [
    ("HeaderData", "PngHeaderData", {
        "width": ("0", "0"), "height": ("0", "0"), "bit_depth": ("0", "0"),
        "color_type": (".grayscale", ".grayscale"), "compression_method": (".deflate", ".deflate"),
        "filter_method": (".adaptive", ".adaptive"), "interlace_method": (".none", ".none")}),
    ("Chunk", "PngChunk", {"id": ("0", "0"), "name": ('"IHDR"', "'IHDR'")}),
    ("ChunkHeader", "PngChunkHeader", {"length": ("0", "0"), "type": ("0", "0")}),
]


def corpus():
    rows = []
    for color, depth, width, height, method, field in itertools.product(
            (0, 2, 3, 4, 6), (0, 1, 8, 16, 255), (0, 1, 0x7fffffff, 0xffffffff),
            (0, 3, 0xffffffff), (0, 1, 255), range(8)):
        rows.append("|".join(map(str, ("H", width, height, depth, color, method, method, field % 2, field))))
    for name, position, value in itertools.product(("49484452", "74455874", "00ff00ff"), range(4), range(256)):
        rows.append(f"C|{name}|41424344|{value * 16843009}|{0xffffffff ^ value}|{position}|{value}")
    for length, tag, copied_length, copied_tag in itertools.product((0, 1, 0xffffffff), (0, 0x49484452, 0xffffffff),
                                                                  (0, 17, 0xffffffff), (0, 0x74455874, 0xffffffff)):
        rows.append(f"N|{length}|{tag}|{copied_length}|{copied_tag}")
    for interlaced, before, after in itertools.product(range(2), range(7), range(7)):
        rows.append(f"O|{interlaced}|{before}|{after}")
    return rows


def z_consumer(body, alias=""):
    return ('const std=@import("std");const types=@import("src/formats/png/types.zig");'
            'const PNG=@import("src/formats/png.zig").PNG;const f=@import("src/formats/png/filtering.zig");' + alias +
            'pub fn main() void {' + body + '}\n')


def v_consumer(body, alias=""):
    return "module main\nimport zigimg\n" + alias + "fn main(){\n" + body + "\n}\n"


def memory_hash(zig):
    digest = hashlib.sha256()
    for name in MEMORY_FILES:
        digest.update(name.encode() + b"\0")
        digest.update((zig.parent / "lib/std" / name).read_bytes())
    return digest.hexdigest()


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
    if args.timeout <= 0: parser.error("--timeout must be positive")
    mode = args.zig_mode or ("ReleaseSafe" if args.v_prod else "Debug")
    source = args.source.resolve() / "src"
    zig, v = args.zig.resolve(), args.v.resolve()
    if tree_hash(source) != PINNED_SOURCE_SHA256 or memory_hash(zig) != PINNED_MEMORY_SHA256:
        parser.error("Source or selected compiler library differs from the pins")
    repo = Path(__file__).resolve().parent.parent
    probe = repo / "zigimg/reference_probes/png_records"
    env = dict(os.environ, VEXE=str(v), V_C_ERROR_BUG_REPORT_DISABLED="1")
    rows = corpus()
    if EXPECTED_ROWS is not None and len(rows) != EXPECTED_ROWS:
        raise AssertionError("record corpus changed")
    with work_directory(args.workdir, "witty-png-records-") as root:
        proof = ProofLog(root)
        shutil.copytree(source, root / "src")
        fixtures = {}
        for name in ("reference.zig", "main.v"):
            shutil.copyfile(probe / name, root / name)
            fixtures[name] = hashlib.sha256((root / name).read_bytes()).hexdigest()
        if tree_hash(root / "src") != PINNED_SOURCE_SHA256:
            raise AssertionError("copied Source changed")
        versions = [proof.run([str(exe), "version"], label, env=env).stdout.decode().strip()
                    for exe, label in ((zig, "zig-version"), (v, "v-version"))]
        if versions[0] != "0.15.2" or not re.match(r"^V 0\.5\.2(?: |$)", versions[1]):
            raise AssertionError("unexpected compiler versions")
        provenance = {"source_sha256": PINNED_SOURCE_SHA256, "memory_sha256": PINNED_MEMORY_SHA256,
                      "versions": versions, "zig_mode": mode, "v_prod": args.v_prod, "target": args.target,
                      "fixtures": fixtures, "runner_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest()}
        (root / "provenance.json").write_text(json.dumps(provenance, indent=2) + "\n")
        zbase = [str(zig), "build-exe", "-target", args.target, "-lc", "-O", mode,
                 "--global-cache-dir", str(root / "zig-global")]
        vbase = [str(v), "-enable-globals", *(["-prod"] if args.v_prod else []), "-path", f"{repo}|@vlib|@vmodules"]
        print(f"Building PNG records: {mode}, V {'production' if args.v_prod else 'ordinary'}", flush=True)
        proof.run(zbase + ["-femit-bin=" + str(root / "native"), str(root / "reference.zig")], "build-source", timeout=args.timeout)
        proof.run(vbase + ["-o", str(root / "translated"), str(root / "main.v")], "build-v", env=env, timeout=args.timeout)
        path = root / "corpus.txt"
        path.write_text("\n".join(rows) + "\n")
        results = [proof.run([str(root / exe), str(path)], "returning-" + exe, timeout=args.timeout, check=False)
                   for exe in ("native", "translated")]
        if any(result.returncode or result.stderr for result in results):
            raise AssertionError([(r.returncode, r.stderr[:2000]) for r in results])
        outputs = [result.stdout.splitlines() for result in results]
        if any(len(output) != len(rows) for output in outputs): raise AssertionError("wrong record count")
        for case, native, translated in zip(rows, *outputs):
            if native != translated: raise AssertionError(f"{case}: Source={native!r}, V={translated!r}")
        digest = hashlib.sha256(b"\n".join(outputs[0])).hexdigest()
        if EXPECTED_SHA256 is not None and digest != EXPECTED_SHA256: raise AssertionError("output golden changed")

        # A boxed V sum-type payload has a distinct copy representation. Measure
        # this separately rather than count mismatching copies as equivalent.
        boxed = root / "boxed-copy.txt"
        boxed.write_text("\n".join(f"B|{a}|{b}" for a, b in itertools.product(range(5), repeat=2)) + "\n")
        box_hashes = []
        box_outputs = []
        for exe in ("native", "translated"):
            result = proof.run([str(root / exe), str(boxed)], "boxed-copy-" + exe, timeout=args.timeout)
            if result.stderr or len(result.stdout.splitlines()) != 25: raise AssertionError("boxed-copy observations invalid")
            box_outputs.append(result.stdout.splitlines())
            box_hashes.append(hashlib.sha256(b"\n".join(box_outputs[-1])).hexdigest())
        for actual, expected in zip(box_hashes, (EXPECTED_SOURCE_BOX_SHA256, EXPECTED_V_BOX_SHA256)):
            if expected is not None and actual != expected: raise AssertionError("boxed-copy golden changed")

        def pair(label, ztext, vtext, zmarker=None, vmarker=None):
            zpath, vpath = root / (label + ".zig"), root / (label + ".v")
            zpath.write_text(ztext); vpath.write_text(vtext)
            for language, command, marker in (
                ("Source", zbase + ["-fno-emit-bin", str(zpath)], zmarker),
                ("V", vbase + ["-check", str(vpath)], vmarker)):
                result = proof.run(command, label + "-" + language, env=env, timeout=args.timeout, check=False)
                diagnostic = result.stdout + result.stderr
                if marker is None:
                    if result.returncode or re.search(rb"(?:^|\n).*error:", diagnostic):
                        raise AssertionError(f"{label}/{language}: expected acceptance\n" + diagnostic.decode(errors="replace"))
                else:
                    ordinary_rejection(result, label + "/" + language)
                    if marker.encode() not in diagnostic:
                        raise AssertionError(f"{label}/{language}: missing diagnostic {marker!r}\n" + diagnostic.decode(errors="replace"))
        omissions = 0
        for kind, vkind, fields in CONTRACTS:
            for missing in fields:
                zfields = ",".join("." + name + "=" + values[0] for name, values in fields.items() if name != missing)
                vfields = ",".join(("chunk_type" if name == "type" else name) + ":" + values[1] for name, values in fields.items() if name != missing)
                zbody = "const x:types." + kind + "=.{" + zfields + "};_=x;"
                vbody = "x:=zigimg." + vkind + "{" + vfields + "}\n_=x"
                vmissing = "chunk_type" if missing == "type" else missing
                pair(f"missing-{kind}-{missing}", z_consumer(zbody), v_consumer(vbody),
                     "missing struct field: " + missing, "zigimg." + vkind + "." + vmissing)
                pair(f"alias-missing-{kind}-{missing}",
                     z_consumer(zbody.replace("types." + kind, "Alias"), "const Alias=types." + kind + ";"),
                     v_consumer(vbody.replace("zigimg." + vkind, "Alias"), "type Alias=zigimg." + vkind + "\n"),
                     "missing struct field: " + missing)
                omissions += 1
        pair("specified-payload", z_consumer("const x:f.FilterChoice=.specified;_=x;"),
             v_consumer("x:=zigimg.PngSpecified{}\n_=x"),
             "must initialize", "zigimg.PngSpecified.filter")
        pair("readonly-chunk", z_consumer('const x=types.Chunk.init("IHDR");x.id=1;'),
             v_consumer("x:=zigimg.PngChunk.init('IHDR')\nx.id=1"), "cannot assign to constant", "immutable")
        pair("readonly-options", z_consumer("const x:PNG.EncoderOptions=.{};x.interlaced=true;"),
             v_consumer("x:=zigimg.PngEncoderOptions{}\nx.interlaced=true"), "cannot assign to constant", "immutable")
        pair("readonly-name-receiver", z_consumer("const x:types.ChunkHeader=.{.length=0,.type=0};_=x.name();"),
             v_consumer("x:=zigimg.PngChunkHeader{length:0,chunk_type:0}\n_=x.name()"), "discards const qualifier", "immutable")
        pair("readonly-borrow", z_consumer("var x:types.ChunkHeader=.{.length=0,.type=0};const b=x.name();b[0]=1;"),
             v_consumer("mut x:=zigimg.PngChunkHeader{length:0,chunk_type:0}\nmut b:=x.name()\nb[0]=1"), "cannot assign to constant")
        pair("direct-short-name", z_consumer('const x:types.Chunk=.{.id=0,.name="x"};_=x;'),
             v_consumer("x:=zigimg.PngChunk{id:0,name:'x'}\n_=x"), "expected type '*const [4:0]u8'")
        if (tree_hash(source) != PINNED_SOURCE_SHA256 or tree_hash(root / "src") != PINNED_SOURCE_SHA256
                or memory_hash(zig) != PINNED_MEMORY_SHA256): raise AssertionError("dependency changed during proof")
        for name, expected in fixtures.items():
            if any(hashlib.sha256(p.read_bytes()).hexdigest() != expected for p in (root / name, probe / name)):
                raise AssertionError("fixture changed: " + name)
        if hashlib.sha256(Path(__file__).read_bytes()).hexdigest() != provenance["runner_sha256"]:
            raise AssertionError("runner changed during proof")
        summary = {"returning_records": len(rows), "sha256": digest, "paired_required_fields": omissions,
                   "paired_payload_rejections": 1, "paired_readonly_rejections": 3,
                   "alias_marker_adaptations": omissions, "source_only_type_rejections": 2,
                   "boxed_copy_records": 25, "boxed_copy_hashes": box_hashes,
                   "boxed_copy_divergences": sum(a != b for a, b in zip(*box_outputs)), "zig_mode": mode, "v_prod": args.v_prod}
        (root / "result.json").write_text(json.dumps(summary, indent=2) + "\n")
        print(json.dumps(summary), flush=True)


if __name__ == "__main__": main()
