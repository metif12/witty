"""Compare PNG diagnostic output, stream positions, and suppressed write errors."""
import argparse
import hashlib
import os
import json
from pathlib import Path
import re
import shutil
import zlib

from verify_tiff_decode_reference import ProofLog, checked_trap, tree_hash, work_directory

from verify_png_foundation_reference import PINNED_SOURCE_SHA256, PINNED_FLATE_SHA256, FLATE_SOURCES

FORMAT_SOURCES = ["fmt.zig", "fmt/float.zig"]
PINNED_FORMAT_SHA256 = "9ad2e71bc2e950a01e29eec9d20a6e9674097602774399a5451839a23c4b278b"
EXPECTED_ROWS = 51223
EXPECTED_CHECKED_ROWS = 1041
EXPECTED_CHECKED_SHA256 = "05946f5a7cbbcdc928e51c71edb9d4d6ee25c208ef21611cd4562bf6c91bcff8"
EXPECTED_CONSTRUCTOR_SHA256 = "4915f0abe0141219e84b1fdf33fbe144f55ef9379143743f5a5cee6176b08a1a"
EXPECTED_STATE_SHA256 = "529d510c5be49ae7fa2e42b35e70ec2c0786cc88e77e1d87c57c79f7e470445a"
EXPECTED_SHA256 = "87adba8bfd33b6f94e620ef6b277496fe1303c0fc80ca07a261f22fae0af7d4a"
BOUNDS = {
    **{name: ("integer overflow", "integer overflow") for name in
       ("count_overflow", "size_overflow", "both_overflow")},
    **{name: ("invalid enum value", "invalid enum value") for name in
       ("compression_tag", "filter_tag", "color_tag", "interlace_tag")},
    **{name: ("attempt to use null value", "attempt to use null value") for name in
       ("text_null", "ztxt_null", "itxt_language", "itxt_translation")},
    **{name: ("index out of bounds", ("index out of bounds", "array.get: index out of range"))
       for name in ("ztxt_method", "itxt_flags", "itxt_one_yes")},
    **{name: ("start index 2 is larger than end index 1", "start index 2 is larger than end index 1")
       for name in ("itxt_one_no", "itxt_one_unknown")},
}


def corpus():
    cases = []

    def add(label, name, length, data, color=0, depth=8, capacities=(0, 1, 6, 16, 33, 64, 120, 512), count=0, size=0, operation=0):
        chunk_id = int.from_bytes(name.encode(), "big")
        for capacity in capacities:
            cases.append((f"{label}-cap{capacity}", "|".join(map(str, [chunk_id, length, color, depth, capacity, data.hex(), count, size, operation]))))

    for name in ("gAMA", "sBIT", "cHRM", "pHYs", "tRNS", "bKGD", "tIME", "iCCP", "sRGB", "abCd"):
        for length in (0, 1, 2, 3, 4, 5, 6, 7, 9, 20, 21, 32, 1024, 1025):
            data = bytes((i * 37) & 255 for i in range(length)) + b"\x12\x34\x56\x78\x99"
            for color in (0, 3):
                for cut in sorted({0, 1, max(0, length-1), length, length+4, length+5}):
                    add(f"{name}-{length}-{color}-cut{cut}", name, length, data[:cut], color)
    for color in (0, 2, 3, 4, 6):
        for depth in (1, 2, 4, 8, 16, 255):
            add(f"header-{color}-{depth}", "IHDR", 13, b"", color, depth, capacities=range(240))
    for size in (0, 1, 20, 1023, 1024, 1025, 1048575, 1048576, 4294967295, 4294967296, 2**53-1, 2**53, 2**63, 2**64-1):
        add(f"iend-{size}", "IEND", 0, b"", capacities=range(210), count=1234, size=size)
    sizes = {max(0, 2**bit + delta) for bit in range(64) for delta in (-1, 0, 1)}
    seed = 0x0123456789abcdef
    for magnitude in range(7):
        mask = (1 << min(64, 10*(magnitude+1))) - 1
        for _ in range(2048):
            seed = (seed * 6364136223846793005 + 1442695040888963407) & (2**64-1)
            sizes.add(seed & mask)
    for size in sorted(sizes):
        add(f"byte-size-{size}", "IEND", 0, b"", capacities=(256,), count=1234, size=size)
    for length in (0, 1, 1024, 4294967295):
        add(f"idat-{length}", "IDAT", length, b"", count=1234, size=2**53)
    for length in (0, 1, 4, 256):
        add(f"palette-{length}", "PLTE", length, b"", capacities=range(35), operation=1)
    # Known critical chunks are notifications and unknown critical chunks print nothing.
    for name in ("PLTE", "ABCD"):
        add(f"critical-{name}", name, 3000, b"", count=17, size=123456)
    for name, data in (
        ("tEXt", b"key\0text\xff\0tail"),
        ("tEXt", b"key\0" + b"x" * 1100),
        ("iTXt", b"key\0\x00\x00en\0translation\0text"),
        ("iTXt", b"key\0\x01\x00en\0translation\0raw compressed flag"),
        ("iTXt", b"key\0\x01\x08\0\0text"),
        ("iTXt", b"\0\x02\x00\0\0" + b"x" * 1100),
        ("zTXt", b"key\0\x08unrecognized method"),
        ("zTXt", b"key\0\x08" + b"x"*200),
    ):
        for cut in sorted({0, 1, len(data)-1, len(data), len(data)+4, len(data)+5}):
            add(f"{name}-text{len(data)}-cut{cut}", name, len(data), (data+b"\0"*5)[:cut], capacities=range(260))
    for size in (0, 5, 1023, 1024, 1025, 3073, 160000):
        raw = bytes((i//7 + i*19) & 255 for i in range(size))
        for level, strategy in ((0, zlib.Z_DEFAULT_STRATEGY), (6, zlib.Z_DEFAULT_STRATEGY), (6, zlib.Z_FIXED)):
            if size > 65536 and strategy == zlib.Z_FIXED:
                continue  # The pinned fixed-match window boundary is a checked trap.
            encoder = zlib.compressobj(level, zlib.DEFLATED, 15, 8, strategy)
            compressed = encoder.compress(raw) + encoder.flush()
            data = b"key\0\0" + compressed
            capacities = (0, 39, 90, 120, 1024, 4096)
            for cut in sorted({0, 1, 5, 7, 80, len(data)-4, len(data)-1, len(data), len(data)+4, len(data)+5}):
                cut = min(cut, len(data)+5)
                add(f"ztxt-{size}-{level}-{strategy}-cut{cut}", "zTXt", len(data), (data+b"\0"*5)[:cut], capacities=capacities)
            if len(compressed) < 120:
                for position in range(len(compressed)):
                    for bit in range(8):
                        mutated = bytearray(data+b"\0"*5)
                        mutated[position+5] ^= 1 << bit
                        add(f"ztxt-bit-{size}-{level}-{strategy}-{position}-{bit}", "zTXt", len(data), mutated, capacities=(90, 512))
    return cases


def checked_corpus():
    cases = []
    def add(label, name, length, data, capacities, color=0, count=0, size=0, compression=0, filtering=0, interlace=1):
        for capacity in capacities:
            fields = [int.from_bytes(name.encode(), "big"), length, color, 8, capacity,
                      data.hex(), count, size, 0, compression, filtering, interlace]
            cases.append((f"{label}-cap{capacity}", "|".join(map(str, fields))))
    dimensions = b"Dimensions: 17x3\nBit Depth: 8\n"
    color = b"Color Type: grayscale\n"
    compression = b"Compression Method: deflate\n"
    filtering = b"Filter Method: adaptive\n"
    # Invalid enum tagName arguments are evaluated only after preceding prints succeed.
    for tag in (1, 255):
        add(f"suppressed-color-{tag}", "IHDR", 13, b"", range(len(dimensions)), color=tag)
        add(f"suppressed-compression-{tag}", "IHDR", 13, b"", range(len(dimensions+color)), compression=tag)
        add(f"suppressed-filter-{tag}", "IHDR", 13, b"", range(len(dimensions+color+compression)), filtering=tag)
    for tag in (2, 255):
        add(f"suppressed-interlace-{tag}", "IHDR", 13, b"", range(len(dimensions+color+compression+filtering)), interlace=tag)
    for name, data, prefix in (
        ("tEXt", b"abc", b"tEXt Length 3B:\n"),
        ("zTXt", b"abc", b"zTXt Length 3B:\n"),
        ("zTXt", b"key\0", b"zTXt Length 4B:\n               Keyword: key\n"),
        ("iTXt", b"key\0", b"iTXt Length 4B:\n               Keyword: key\n"),
        ("iTXt", b"key\0\1", b"iTXt Length 5B:\n               Keyword: key\n"),
        ("iTXt", b"key\0\0", b"iTXt Length 5B:\n               Keyword: key\n            Compressed: No\n"),
        ("iTXt", b"key\0\2", b"iTXt Length 5B:\n               Keyword: key\n            Compressed: No\n"),
        ("iTXt", b"key\0\0\0x", b"iTXt Length 7B:\n               Keyword: key\n            Compressed: No\n"),
        ("iTXt", b"key\0\0\0\0x", b"iTXt Length 8B:\n               Keyword: key\n            Compressed: No\n          Language Tag: \n"),
    ):
        add(f"suppressed-fields-{name}-{data.hex()}", name, len(data), data,
            range(len(prefix)))
    for length in (0, 1, 0xffffffff):
        for count in (0, 0xfffffffe):
            for size in (0, (1 << 64)-1-length):
                add(f"idat-limit-{length}-{count}-{size}", "IDAT", length, b"", (0, 1, 256), count=count, size=size)
    return cases


def ordinary_rejection(result, label, expression):
    diagnostic = (result.stdout + result.stderr).decode(errors="replace")
    if (result.returncode <= 0 or any(word in diagnostic.lower() for word in
            ("panic:", "compiler bug", "internal compiler error", "c error found", "segmentation fault"))
            or not re.search(r"^(?:[^\n]*:\d+:\d+: )?" + expression + r"$", diagnostic, re.M)):
        raise AssertionError(f"{label}: expected ordinary compiler rejection\n{diagnostic}")


def constructor_boundaries(proof, root, args, env, repo):
    fixtures = {
        "required_writer": ('const x: Info = .{}; _ = x;', 'x := zigimg.PngInfoProcessor{}\n _ = x',
                            r"error: missing struct field: writer", r"error: reference field `zigimg.PngInfoProcessor.writer` must be initialized"),
        "nil_writer": ('const x = Info.init(null); _ = x;', 'x := zigimg.PngInfoProcessor.init(unsafe { nil })\n _ = x',
                       r"error: expected type \'.*Writer\', found \'@TypeOf\(null\)\'", None),
        "readonly_writer": ('const w = std.Io.Writer.fixed(&.{}); const x = Info.init(&w); _ = x;',
                            'w := zigimg.WriteStream.init_memory(mut bytes)\n x := zigimg.PngInfoProcessor.init(&w)\n _ = x',
                            r"error: expected type \'.*Writer\', found \'\*const .*Writer\'", None),
    }
    for label, (zig_body, v_body, zig_error, v_error) in fixtures.items():
        z = root / (label + ".zig")
        v = root / (label + ".v")
        z.write_text('const std = @import("std"); const Info = @import("src/formats/png/InfoProcessor.zig"); pub fn main() void { ' + zig_body + ' }\n')
        v.write_text('module main\nimport zigimg\nfn main() {\n mut bytes := []u8{}\n _ = bytes\n' + v_body + '\n}\n')
        result = proof.run([str(args.zig.resolve()), "build-exe", "--global-cache-dir", str(root / "zig-global-cache"), "-target", args.target, "-O", args.zig_mode,
                            "-lc", "-fno-emit-bin", str(z)], "ctor-source-" + label, check=False)
        ordinary_rejection(result, label + " Source", zig_error)
        result = proof.run([str(args.v.resolve()), *(["-prod"] if args.v_prod else []), "-path",
                            f"{repo}|@vlib|@vmodules", "-check", str(v)], "ctor-v-" + label, env=env, check=False)
        if v_error:
            ordinary_rejection(result, label + " V", v_error)
        elif result.returncode or re.search(rb"(?:^|\n).*error:", result.stdout + result.stderr):
            raise AssertionError(f"{label}: expected measured V-only constructor acceptance")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("zig", type=Path)
    parser.add_argument("v", type=Path)
    parser.add_argument("--target", default="aarch64-macos.14.0")
    parser.add_argument("--v-prod", action="store_true", help="compile V with -prod; defaults Zig to ReleaseSafe")
    parser.add_argument("--zig-mode", choices=("Debug", "ReleaseSafe"))
    parser.add_argument("--workdir", type=Path, help="retain proof artifacts in an absent or empty directory")
    parser.add_argument("--timeout", type=int, default=180)
    parser.add_argument("--bounds-only", action="store_true")
    args = parser.parse_args()
    args.zig_mode = args.zig_mode or ("ReleaseSafe" if args.v_prod else "Debug")
    if args.timeout <= 0:
        parser.error("--timeout must be positive")
    source = args.source.resolve() / "src"
    if tree_hash(source) != PINNED_SOURCE_SHA256:
        parser.error("src differs from locked zigimg")
    for names, expected, label in ((FLATE_SOURCES, PINNED_FLATE_SHA256, "DEFLATE/reader/writer"),
                                  (FORMAT_SOURCES, PINNED_FORMAT_SHA256, "format/float")):
        digest = hashlib.sha256()
        for name in names:
            digest.update(name.encode() + b"\0")
            digest.update((args.zig.resolve().parent / "lib/std" / name).read_bytes())
        if digest.hexdigest() != expected:
            parser.error(label + " sources differ from Zig 0.15.2")
    cases = [] if args.bounds_only else corpus()
    extra = [] if args.bounds_only else checked_corpus()
    if not args.bounds_only and (len(cases) != EXPECTED_ROWS or len(extra) != EXPECTED_CHECKED_ROWS):
        raise AssertionError("historical returning corpus changed")
    probe = Path(__file__).resolve().parent / "reference_probes/png_info"
    repo = Path(__file__).resolve().parent.parent
    env = dict(os.environ, VEXE=str(args.v.resolve()), V_C_ERROR_BUG_REPORT_DISABLED="1")
    with work_directory(args.workdir, "witty-png-info-") as root:
        proof = ProofLog(root)
        shutil.copytree(source, root / "src")
        if tree_hash(root / "src") != PINNED_SOURCE_SHA256:
            raise AssertionError("copied source changed")
        for name in ("reference.zig", "main.v"):
            shutil.copyfile(probe / name, root / name)
        provenance = {"source_sha256": PINNED_SOURCE_SHA256, "flate_sha256": PINNED_FLATE_SHA256,
                      "formatter_sha256": PINNED_FORMAT_SHA256, "zig_mode": args.zig_mode,
                      "v_prod": args.v_prod, "target": args.target,
                      "fixtures": {name: hashlib.sha256((root/name).read_bytes()).hexdigest()
                                   for name in ("reference.zig", "main.v")}}
        (root / "provenance.json").write_text(json.dumps(provenance, indent=2) + "\n")
        print(f"Building PNG info Source {args.zig_mode} and V {'production' if args.v_prod else 'ordinary'}", flush=True)
        proof.run([str(args.zig.resolve()), "build-exe", "--global-cache-dir", str(root / "zig-global-cache"), "-target", args.target, "-O", args.zig_mode, "-lc",
                   f"-femit-bin={root / 'native'}", str(root / "reference.zig")], "build-source")
        proof.run([str(args.v.resolve()), "-enable-globals", *(["-prod"] if args.v_prod else []), "-path",
                   f"{repo}|@vlib|@vmodules", "-o", str(root / "translated"), str(root / "main.v")], "build-v", env=env)
        hashes = {}
        for label, rows, expected in (("historical", cases, EXPECTED_SHA256), ("checked", extra, EXPECTED_CHECKED_SHA256)):
            if args.bounds_only: continue
            path = root / (label + "-corpus.txt")
            path.write_text("\n".join(row[1] for row in rows) + "\n")
            print(f"Comparing {len(rows)} {label} returning cases", flush=True)
            results = [proof.run([str(root / executable), str(path)], label + "-" + executable, timeout=args.timeout)
                       for executable in ("native", "translated")]
            outputs = [result.stdout.splitlines() for result in results]
            if any(result.stderr for result in results) or any(len(output) != len(rows) for output in outputs):
                raise AssertionError(f"{label}: unexpected diagnostics or row count")
            for (name, _), wanted, actual in zip(rows, *outputs):
                if wanted != actual:
                    raise AssertionError(f"{name}: Source={wanted!r}, V={actual!r}")
            digest = hashlib.sha256(b"\n".join(outputs[0])).hexdigest()
            if expected and digest != expected:
                raise AssertionError(f"{label}: historical hash changed: {digest}")
            hashes[label] = digest
            print(f"PNG info {label}: {len(rows)} records SHA256 {digest}", flush=True)
        outputs = [proof.run([str(root / executable), "--contracts"], "contracts-" + executable).stdout
                   for executable in ("native", "translated")]
        if outputs[0] != outputs[1] or len(outputs[0].splitlines()) != 1:
            raise AssertionError(f"supported constructors/copy/borrow differ: {outputs}")
        hashes["constructors"] = hashlib.sha256(outputs[0].rstrip(b"\n")).hexdigest()
        if hashes["constructors"] != EXPECTED_CONSTRUCTOR_SHA256:
            raise AssertionError("supported constructor/copy/borrow output changed")
        constructor_boundaries(proof, root, args, env, repo)
        states = []
        for boundary, categories in BOUNDS.items():
            observations = []
            for executable, category in zip(("native", "translated"), categories):
                path = root / (executable + "-" + boundary + ".state")
                label = f"trap-{executable}-{boundary}"
                result = proof.run([str(root / executable), "--bounds", boundary, str(path)], label, timeout=10, check=False)
                checked_trap(result, label, category)
                state = path.read_bytes()
                if not re.fullmatch(rb"\d+\|\d+\|\d+\|\d+\|[0-9a-f]{16}", state):
                    raise AssertionError(label + ": missing or invalid panic state")
                observations.append(state)
            if observations[0] != observations[1]:
                raise AssertionError(f"{boundary}: retained state differs: {observations}")
            states.append(boundary.encode() + b"|" + observations[0])
        hashes["panic_states"] = hashlib.sha256(b"\n".join(states)).hexdigest()
        if hashes["panic_states"] != EXPECTED_STATE_SHA256:
            raise AssertionError("retained panic state changed")
        if tree_hash(source) != PINNED_SOURCE_SHA256 or tree_hash(root / "src") != PINNED_SOURCE_SHA256:
            raise AssertionError("source changed during proof")
        result = {"historical_records": len(cases), "checked_returning_records": len(extra), "hashes": hashes,
                  "strict_trap_pairs": len(BOUNDS), "panic_states": len(states),
                  "complete_constructors": 2, "required_omission_pairs": 1,
                  "source_only_constructor_rejections": 2, "zig_mode": args.zig_mode, "v_prod": args.v_prod}
        (root / "result.json").write_text(json.dumps(result, indent=2) + "\n")
        print(f"PNG info: {len(BOUNDS)} strict traps and matching panic states; constructors/defaults/copy/borrow checked", flush=True)
        print(json.dumps(hashes, sort_keys=True), flush=True)


if __name__ == "__main__":
    main()
