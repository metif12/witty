"""Compare public TIFF record constructors and defined copy/borrow behavior."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil

from verify_tiff_decode_reference import PINNED_SOURCE_SHA256, ProofLog, tree_hash, work_directory
from verify_tiff_metadata_bounds_reference import PINNED_STDLIB_SHA256, STDLIB_SOURCES

CONTRACTS = [
    ("Header", "TiffHeader", ["version", "idf_offset"]),
    ("PackedTag", "TiffPackedTag", ["tag_id", "data_type", "data_count", "data_offset"]),
    ("TagField", "TiffTagField", ["data_type", "data_count", "data_offset"]),
    ("IFD", "TiffIFD", ["tags_map", "read_stream"]),
]
EXPECTED_ROWS = 343
EXPECTED_SHA256 = "e58e21e70207affb3ec52c115ad2cd73af652ce6f14d81ae0385e9f8bf4dea26"


def rejection(result, marker):
    diagnostic = result.stdout + result.stderr
    return (result.returncode > 0 and b"error:" in diagnostic and marker.encode() in diagnostic
            and not any(text in diagnostic.lower() for text in
                        (b"panic:", b"compiler bug", b"segmentation fault", b"c error found")))


def literal(kind, fields, missing, translated=False):
    selected = [field for field in fields if field != missing]
    values = {field: "0" for field in fields}
    if kind == "IFD":
        values.update(tags_map="zigimg.TiffTagMap{}" if translated else
                      "std.AutoHashMap(types.TagId,types.TagField).init(std.heap.page_allocator)",
                      read_stream="&stream")
    entries = [field + ":" + values[field] if translated else "." + field + "=" + values[field]
               for field in selected]
    if kind == "IFD" and not translated:
        entries.insert(0, ".allocator=std.heap.page_allocator")
    return "{" + ",".join(entries) + "}"


def source_consumer(body, alias=""):
    return ("const std=@import(\"std\");const types=@import(\"src/formats/tiff/types.zig\");"
            "const io=@import(\"src/io.zig\");" + alias +
            "pub fn main() void {var stream=io.ReadStream.initMemory(&.{});_=&stream;" + body + "}\n")


def v_consumer(body, alias=""):
    return ("module main\nimport zigimg\n" + alias +
            "fn main(){mut stream:=zigimg.ReadStream.init_memory([]u8{}) _=&stream " + body + "}\n")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path, help="locked zigimg package directory")
    parser.add_argument("zig", type=Path, help="Zig 0.15.2 executable")
    parser.add_argument("v", type=Path, help="pinned V executable")
    parser.add_argument("--target", default="aarch64-macos.14.0")
    parser.add_argument("--v-prod", action="store_true")
    parser.add_argument("--zig-mode", choices=("Debug", "ReleaseSafe"))
    parser.add_argument("--workdir", type=Path, help="retain proof artifacts in an absent or empty directory")
    args = parser.parse_args()
    mode = args.zig_mode or ("ReleaseSafe" if args.v_prod else "Debug")
    source = args.source.resolve() / "src"
    if tree_hash(source) != PINNED_SOURCE_SHA256:
        parser.error("src differs from locked zigimg d7b7ab0ba0899643831ef042bd73289510b39906")
    stdlib = args.zig.resolve().parent / "lib/std"
    stdlib_digest = hashlib.sha256()
    for name in STDLIB_SOURCES:
        stdlib_digest.update(name.encode() + b"\0")
        stdlib_digest.update((stdlib / name).read_bytes())
    if stdlib_digest.hexdigest() != PINNED_STDLIB_SHA256:
        parser.error("HashMap and integer-power sources differ from Zig 0.15.2")
    probe = Path(__file__).resolve().parent / "reference_probes/tiff_records"
    repo = Path(__file__).resolve().parent.parent
    environment = dict(os.environ, VEXE=str(args.v.resolve()), V_C_ERROR_BUG_REPORT_DISABLED="1")
    with work_directory(args.workdir, "witty-tiff-records-") as root:
        proof = ProofLog(root)
        shutil.copytree(source, root / "src")
        if tree_hash(root / "src") != PINNED_SOURCE_SHA256:
            raise AssertionError("copied source differs from pinned source")
        for name in ("reference.zig", "main.v"):
            shutil.copyfile(probe / name, root / name)

        def commands(zpath, vpath, emit=False):
            return (
                [str(args.zig.resolve()), "build-exe", "-target", args.target, "-lc", "-O", mode,
                 f"-femit-bin={root / 'native'}" if emit else "-fno-emit-bin", str(zpath)],
                [str(args.v.resolve()), *(["-prod"] if args.v_prod else []), "-path",
                 f"{repo}|@vlib|@vmodules", *(["-o", str(root / "translated")] if emit else ["-check"]),
                 str(vpath)],
            )

        versions = [proof.run([str(exe.resolve()), "version"], f"version-{name}").stdout.decode().strip()
                    for exe, name in ((args.zig, "zig"), (args.v, "v"))]
        if versions[0] != "0.15.2" or not versions[1].startswith("V 0.5.2"):
            raise AssertionError("compiler version differs from pinned versions: " + repr(versions))
        (root / "provenance.json").write_text(json.dumps({
            "source_revision": "d7b7ab0ba0899643831ef042bd73289510b39906",
            "source_sha256": PINNED_SOURCE_SHA256, "stdlib_sha256": PINNED_STDLIB_SHA256,
            "compiler_versions": versions,
            "zig_mode": mode, "v_prod": args.v_prod, "target": args.target,
            "fixture_sha256": {name: hashlib.sha256((root / name).read_bytes()).hexdigest()
                               for name in ("reference.zig", "main.v")},
        }, indent=2) + "\n")
        print(f"Building six public TIFF record constructors/copy consumers ({mode}, V {'production' if args.v_prod else 'ordinary'})", flush=True)
        for name, command in zip(("source", "v"), commands(root / "reference.zig", root / "main.v", True)):
            proof.run(command, "build-" + name, env=environment)
        results = [proof.run([str(root / name)], "returning-" + name) for name in ("native", "translated")]
        if any(result.stderr for result in results) or results[0].stdout != results[1].stdout:
            raise AssertionError("defined record/copy consumers differ; inspect retained returning logs")
        rows = results[0].stdout.splitlines()
        digest = hashlib.sha256(b"\n".join(rows)).hexdigest()
        if len(rows) != EXPECTED_ROWS or digest != EXPECTED_SHA256:
            raise AssertionError(f"record corpus changed: {len(rows)} rows SHA256 {digest}")
        print(f"TIFF records: {len(rows)} returning records, SHA256 {digest}", flush=True)

        def pair(label, ztext, vtext, zmarker=None, vmarker=None):
            zpath, vpath = root / (label + ".zig"), root / (label + ".v")
            zpath.write_text(ztext)
            vpath.write_text(vtext)
            for language, command, marker in zip(("source", "v"), commands(zpath, vpath), (zmarker, vmarker)):
                result = proof.run(command, label + "-" + language, env=environment, check=False)
                if (result.returncode != 0 if marker is None else not rejection(result, marker)):
                    raise AssertionError(label + ": " + language + " ordinary compiler contract mismatch: "
                                         + (result.stdout + result.stderr).decode(errors="replace"))

        omissions = 0
        alias_adaptations = 0
        for kind, vkind, fields in CONTRACTS:
            print("Checking required fields and aliases of " + kind, flush=True)
            for missing in fields:
                original = literal(kind, fields, missing)
                translated = literal(kind, fields, missing, True)
                pair("missing-" + kind + "-" + missing,
                     source_consumer("const value:types." + kind + "=." + original + ";_=value;"),
                     v_consumer("value:=zigimg." + vkind + translated + " println(sizeof(value))"),
                     "missing struct field: " + missing, "zigimg." + vkind + "." + missing)
                omissions += 1
                # Zig type aliases retain the requirement; pinned V aliases ignore it.
                pair("alias-missing-" + kind + "-" + missing,
                     source_consumer("const value:Alias=." + original + ";_=value;", "const Alias=types." + kind + ";"),
                     v_consumer("value:=Alias" + translated + " println(sizeof(value))", "type Alias=zigimg." + vkind + "\n"),
                     "missing struct field: " + missing)
                alias_adaptations += 1

        zifd = ".{.allocator=std.heap.page_allocator,.tags_map=std.AutoHashMap(types.TagId,types.TagField).init(std.heap.page_allocator),.read_stream="
        vifd = "zigimg.TiffIFD{tags_map:zigimg.TiffTagMap{},read_stream:"
        pair("nil-stream", source_consumer("const value:types.IFD=" + zifd + "@ptrFromInt(0)};_=value;"),
             v_consumer("value:=" + vifd + "unsafe{nil}} println(sizeof(value))"), "pointer type '*src.io.ReadStream' does not allow address zero")
        pair("readonly-stream",
             source_consumer("const readonly=io.ReadStream.initMemory(&.{});const value:types.IFD=" + zifd + "&readonly};_=value;"),
             v_consumer("readonly:=zigimg.ReadStream.init_memory([]u8{}) value:=" + vifd + "&readonly} println(sizeof(value))"),
             "discards const qualifier")
        pair("allocator-omission",
             source_consumer("const value:types.IFD=.{.tags_map=std.AutoHashMap(types.TagId,types.TagField).init(std.heap.page_allocator),.read_stream=&stream};_=value;"),
             v_consumer("value:=" + vifd + "&stream} println(sizeof(value))"), "missing struct field: allocator")
        pair("readonly-header",
             source_consumer("const value=types.Header{.version=1,.idf_offset=2};value.version=3;"),
             v_consumer("value:=zigimg.TiffHeader{version:1,idf_offset:2} value.version=3"),
             "cannot assign to constant", "immutable")
        if tree_hash(source) != PINNED_SOURCE_SHA256 or tree_hash(root / "src") != PINNED_SOURCE_SHA256:
            raise AssertionError("source changed during proof")
        summary = {"returning_records": len(rows), "sha256": digest, "complete_constructors": 6,
                   "paired_required_omissions": omissions, "paired_readonly_rejections": 1,
                   "alias_required_marker_adaptations": alias_adaptations,
                   "nil_readonly_allocator_adaptations": 3, "zig_mode": mode, "v_prod": args.v_prod}
        (root / "result.json").write_text(json.dumps(summary, indent=2) + "\n")
        print("TIFF constructor contracts: " + json.dumps(summary), flush=True)


if __name__ == "__main__":
    main()
