"""Compare JPEG headers, entropy state, borrowed tables and strict decoder traps."""
import argparse
import hashlib
import itertools
import json
import os
from pathlib import Path
import re
import shutil
import struct

from verify_tiff_decode_reference import ProofLog, tree_hash, work_directory, PINNED_SOURCE_SHA256
from verify_png_header_reference import checked_trap
from verify_simd_reference import ordinary_rejection

# This comparison uses the compiler's reader, writer and table-map implementation.
STDLIB_FILES = ("debug.zig", "mem.zig", "Io/Reader.zig", "Io/Writer.zig", "array_hash_map.zig", "fs/File.zig")
PINNED_STDLIB_SHA256 = "e286bbf410a68a14bcdb8e25fbe5c35b7a9c5779a76c928deb04df25329e0990"
EXPECTED_ROWS = 15805
EXPECTED_SHA256 = "c351ba2c35413cc9ff5951a77206a0b6aa3ed55f9a495d6c4f94505e5caa7ae4"
EXPECTED_STATE_SHA256 = "d7ddad1f92a7f409a59c64e289a68f9084f8590666d99563990a07640d9c402e"


def stdlib_hash(zig):
    h = hashlib.sha256()
    for name in STDLIB_FILES:
        h.update(name.encode() + b"\0")
        h.update((zig.parent / "lib/std" / name).read_bytes())
    return h.hexdigest()


def implementation_hashes(repo):
    return {p.relative_to(repo).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in sorted((repo / "zigimg").iterdir())
            if p.is_file() and (p.suffix == ".h" or (p.suffix == ".v" and not p.name.endswith("_test.v")))}


def frame_header(count=1, width=8, height=8, precision=8, sampling=0x11, table=0, size=None):
    return struct.pack(">HBHHB", size if size is not None else 8 + 3 * count,
                       precision, height, width, count) + bytes((1, sampling, table)) * count


def jfif(density=0, thumbnail=(0, 0), marker=0xffdb, revision=0x102):
    return (b"\xff\xd8\xff\xe0\x00\x10JFIF\0" + struct.pack(">HBHHBBH", revision,
            density, 72, 96, *thumbnail, marker))


def segment(marker, data, size=None):
    return struct.pack(">HH", marker, len(data) + 2 if size is None else size) + data


def baseline(width=8, height=8, quant=1, dc=0, magnitude=0, progressive=False, approximation=0):
    q = segment(0xffdb, b"\0" + bytes([quant]) * 64)
    f = struct.pack(">H", 0xffc2 if progressive else 0xffc0) + frame_header(width=width, height=height)
    dc_table = segment(0xffc4, b"\0\x01" + b"\0" * 15 + bytes([magnitude]))
    ac_table = segment(0xffc4, b"\x10\x01" + b"\0" * 16)
    s = segment(0xffda, bytes([1, 1, 0, 0, 0 if progressive else 63, approximation]))
    # Every source-observed coefficient is initialized in the baseline case.
    blocks = ((width + 7) // 8) * ((height + 7) // 8)
    bits = ("0" + f"{dc:0{magnitude}b}" if magnitude else "0") + ("" if progressive else "0")
    raw_bits = bits * blocks
    raw_bits += "0" * (-len(raw_bits) % 8)
    entropy = bytes(int(raw_bits[i:i + 8], 2) for i in range(0, len(raw_bits), 8)).replace(b"\xff", b"\xff\0")
    return b"\xff\xd8" + q + f + dc_table + ac_table + s + entropy + b"\xff\xd9"


def corpus(repo):
    rows = []

    def add(label, op, data, *args, buffers=(0, 16, 31, 4096)):
        for capacity in buffers:
            rows.append((f"{label}/buffer{capacity}", "|".join(map(str, (op, capacity, data.hex(), *args)))))

    for count, dimension, precision, sampling, table in itertools.product(
            (0, 1, 2, 3, 4), (0, 1, 8, 65535), (0, 8, 12, 255),
            (0, 0x11, 0x14, 0x41, 0x44, 0x15, 0xf1), (0, 3, 4, 255)):
        add(f"frame-{count}-{dimension}-{precision}-{sampling}-{table}", "F",
            frame_header(count, dimension, dimension, precision, sampling, table), buffers=(0, 16))
    for count in (1, 3):
        data = frame_header(count)
        for cut in range(len(data) + 1):
            add(f"frame-trunc-{count}-{cut}", "F", data[:cut])
    for density, thumbnail, marker, revision in itertools.product(range(3),
            ((0, 0), (1, 0), (0, 1), (255, 255)), (0xffe0, 0xffef, 0xffdb, 0), (0, 0x102, 65535)):
        add(f"jfif-{density}-{thumbnail}-{marker}-{revision}", "J", jfif(density, thumbnail, marker, revision))
    data = jfif()
    for cut in range(len(data) + 1):
        # Positional File.Reader.discardAll loops on the missing NUL byte.
        add(f"jfif-trunc-{cut}", "J", data[:cut], buffers=(0,) if cut == 10 else (0, 16, 31, 4096))
    for offset, value in ((2, 0), (6, 0), (10, 255)):
        data = bytearray(jfif())
        data[offset] = value
        add(f"jfif-byte-{offset}", "J", bytes(data))
    for precision in range(4):
        data = bytes((i * 37 + 13) & 255 for i in range(128))
        for cut in range(129):
            add(f"quant-{precision}-{cut}", "Q", data[:cut], precision, buffers=(0, 16))
    for cls, length, symbol in itertools.product(range(4), range(16), (0, 1, 254, 255)):
        data = bytes(int(i == length) for i in range(16)) + bytes([symbol])
        add(f"table-{cls}-{length}-{symbol}", "T", data, cls, buffers=(0, 16))
        if cls <= 1:
            for cut in (0, 8, 15, 16):
                add(f"table-trunc-{cls}-{length}-{symbol}-{cut}", "T", data[:cut], cls, buffers=(0,))
    # Oversubscribed tables stop at the source's all-ones-code error.
    for length in range(8):
        counts = bytearray(16)
        counts[length] = min(255, 1 << (length + 1))
        add(f"table-oversubscribed-{length}", "T", bytes(counts) + bytes(range(255)), 0)
    payloads = (b"", b"\0", b"\xa5\x5a\xff\0\x12", bytes(range(12)),
                b"\xff\xff\0\x37\x42", b"\xff\xd0\x12\x34", b"\xff\xd9", b"\xff\xe0", b"\xff")
    for data, count, bit_buffer in itertools.product(payloads, (0, 1, 8, 9, 16, 23, 24, 31), (0, 0xa5a5a5a5)):
        for size in (0, 1, 7, 8, 9, 16, 17, 31):
            for op in ("p", "r", "m"):
                add(f"reader-{data.hex()}-{count}-{bit_buffer}-{op}{size}", "R", data,
                    bit_buffer, count, f"{op}{size},z0", buffers=(0, 16))
        for size in (0, 8, 16, 24):
            add(f"reader-fill-{data.hex()}-{count}-{bit_buffer}-{size}", "R", data,
                bit_buffer, count, f"f{size},p0,z0", buffers=(0,))
        for size in (0, 1, 8, 16):
            if size <= count:
                add(f"reader-consume-{data.hex()}-{count}-{bit_buffer}-{size}", "R", data,
                    bit_buffer, count, f"c{size},z0", buffers=(0,))
    for data in (b"", b"\xff\xd9", b"\xff", b"\xff\xe0"):
        add(f"missing-table-short-{data.hex()}", "R", data, 0, 0, "h0", buffers=(0, 16))
    for before, after in itertools.product((0, 1, 42, 254), (0, 1, 77, 254, 255)):
        add(f"borrow-{before}-{after}", "B", b"\0\0", 0, 16, "h0,h0,z0", before, after)
    for width, height, quant in itertools.product((1, 8, 9, 16, 17, 32), (1, 8, 9, 17), (0, 1, 255)):
        add(f"baseline-{width}-{height}-{quant}", "D", baseline(width, height, quant))
    for width, height in ((0, 0), (8, 0), (0, 8)):
        # No active sample means the source never accesses the q8 union field.
        data = (b"\xff\xd8" + segment(0xffdb, b"\x10" + b"\0\x01" * 64) +
                b"\xff\xc0" + frame_header(width=width, height=height) + b"\xff\xd9")
        add(f"empty-q16-{width}-{height}", "D", data)
    for name in ("grayscale-baseline.jpg", "rgb-baseline.jpg", "rgb-progressive-restart.jpg"):
        data = (repo / "zigimg/testdata/jpeg" / name).read_bytes()
        add(f"historical-{name}", "D", data, buffers=(0, 4096))
        for cut in (0, 1, 2, 4, 8, 16, 64, 128):
            add(f"historical-trunc-{name}-{cut}", "D", data[:cut], buffers=(0, 4096))
    for marker in (0xffc1, 0xffc3, 0xffcc, 0xffd0, 0xffd9, 0xffdc, 0xfff0):
        add(f"marker-{marker}", "D", struct.pack(">HH", 0xffd8, marker))
    for marker in (0xffe0, 0xffef, 0xfffe, 0xffdb, 0xffc4, 0xffdd):
        data = b"\xff\xd8" + segment(marker, b"", 4 if marker == 0xffdd else 2) + b"\xff\xd9"
        add(f"empty-segment-{marker}", "D", data)
    # Length validation is intentionally late, after component/table reads.
    for marker, payload in ((0xffdb, b"\xf0"), (0xffc4, b"\xf0")):
        add(f"invalid-table-before-short-length-{marker}", "D", b"\xff\xd8" + segment(marker, payload, 3))
    return rows


def traps():
    result = {}
    def add(name, op, data, category, value=0): result[name] = (op, data, value, category)
    add("marker", "D", b"\xff\xd8\xff\x00", "invalid enum value")
    for marker, kind in ((0xffdb, "quant"), (0xffc4, "huffman"), (0xffe0, "application"), (0xfffe, "comment")):
        for size in (0, 1):
            add(f"{kind}-length-{size}", "D", b"\xff\xd8" + segment(marker, b"", size), "integer overflow")
    for precision in (0, 1):
        data = bytes([precision << 4]) + b"\x01" * (64 if precision == 0 else 128)
        add(f"quant-payload-{precision}", "D", b"\xff\xd8" + segment(0xffdb, data, len(data) + 1), "integer overflow")
    add("huffman-payload", "D", b"\xff\xd8" + segment(0xffc4, b"\0\x01" + b"\0" * 16, 18), "integer overflow")
    add("huffman-destination", "D", b"\xff\xd8" + segment(0xffc4, b"\x04\x01" + b"\0" * 16), "index out of bounds: index 4, len 4")
    for size in (0, 3, 5):
        add(f"restart-length-{size}", "D", b"\xff\xd8" + segment(0xffdd, b"\0\x01", size),
            "integer overflow" if size < 4 else "reached unreachable code")
    add("frame-length", "F", frame_header(size=10), "reached unreachable code")
    add("jfif-density", "J", jfif(density=3), "invalid enum value")
    add("fill_overflow", "R", b"\xa5", "integer overflow")
    add("fill_shift", "R", b"\xa5", "integer overflow")
    add("consume", "R", b"", "reached unreachable code")
    add("consume17", "R", b"", "reached unreachable code")
    add("missing_table", "R", b"\0\0", "attempt to use null value")
    add("argument-u5", "R", b"", "integer does not fit in destination type", 32)
    # Header/scan failures occur before any undefined coefficient reads.
    data = baseline()
    at = data.index(b"\xff\xda")
    short_scan = bytearray(data)
    short_scan[at + 3] = 7
    add("scan-length", "D", bytes(short_scan), "reached unreachable code")
    bad_selector = bytearray(data)
    bad_selector[at + 6] = 0x40
    add("scan-selector", "D", bytes(bad_selector), "index out of bounds: index 4, len 4")
    missing_ac = data.replace(segment(0xffc4, b"\x10\x01" + b"\0" * 16), b"")
    add("scan-missing-ac", "D", missing_ac, "attempt to use null value")
    q16 = data.replace(segment(0xffdb, b"\0" + b"\x01" * 64), segment(0xffdb, b"\x10" + b"\0\x01" * 64))
    add("quant-union", "D", q16, "access of union field 'q8' while field 'q16' is active")
    # A baseline block with a defined DC coefficient overflows in IDCT.
    add("idct-overflow", "D", baseline(quant=255, magnitude=11, dc=2047), "integer overflow")
    add("dequantize-overflow", "D", baseline(quant=255, magnitude=11, dc=2047, progressive=True, approximation=15), "integer overflow")
    return result


def header_compiler_boundary(proof, root, zig, mode, args):
    path = root / "quantization-header.zig"
    path.write_text('const std=@import("std");const Q=@import("src/formats/jpeg/quantization.zig");'
                    'pub fn main() !void {const bytes:[67]u8=@splat(0);var r=std.Io.Reader.fixed(&bytes);'
                    '_=try Q.Header.read(&r);}\n')
    r = proof.run([str(zig), "build-exe", "-target", args.target, "-O", mode, "-lc",
                   "--global-cache-dir", str(root / "zig-cache"), "-fno-emit-bin", str(path)],
                  "source-quantization-header", timeout=args.timeout, check=False)
    ordinary_rejection(r, "source quantization header")
    if b"error: expected type 'u4', found 'u8'" not in r.stderr:
        raise AssertionError(f"unexpected quantization header rejection: {r.stderr!r}")
    control = root / "quantization-header-controls.txt"
    control.write_text("X|0|" + (b"\0" * 67).hex() + "\nX|0|" + (b"\0\0\x13" + b"\0" * 128).hex() + "\n")
    r = proof.run([str(root / "translated"), str(control)], "v-quantization-header-controls", timeout=args.timeout)
    expected = ("0|0,0|0|" + "0," * 64 + "|67\n1|1,3|1|" + "0," * 64 + "|131\n").encode()
    if r.stdout != expected or r.stderr: raise AssertionError(f"V quantization header controls changed: {r.stdout!r}")


def discard_loops(proof, root):
    for capacity in (16, 31, 4096):
        path = root / f"jfif-discard-loop-{capacity}.txt"
        path.write_text(f"J|{capacity}|{jfif()[:10].hex()}\n")
        for executable in ("native", "translated"):
            label = f"jfif-discard-loop-{capacity}-{executable}"
            try:
                proof.run([str(root / executable), str(path)], label, timeout=0.5, check=False)
            except AssertionError:
                if not proof.commands[-1].get("timed_out"): raise
                prefix = f"{len(proof.commands) - 1:03d}-{label}"
                if any((root / f"{prefix}.{ext}").read_bytes() for ext in ("stdout", "stderr")):
                    raise AssertionError(f"{label}: unexpected output before loop timeout")
            else: raise AssertionError(f"{label}: source loop returned")


def reader_constructors(proof, root, zig, v, mode, args, env, repo):
    for missing in (False, True):
        z = root / f"reader-constructor-{int(missing)}.zig"
        z.write_text('const io=@import("src/io.zig");const H=@import("src/formats/jpeg/huffman.zig");'
                     'pub fn main() void {var s=io.ReadStream.initMemory(&.{});const r:H.Reader=.{.reader=s.reader()' +
                     ('' if missing else ',.stream=&s') + '};_=r;}\n')
        p = root / f"reader-constructor-{int(missing)}.v"
        p.write_text("module main\nimport zigimg\nfn main(){\nmut s:=zigimg.ReadStream.init_memory([]u8{})\n"
                     "r:=zigimg.JpegHuffmanReader{" + ('' if missing else 'stream:&s') + "}\n"
                     "if r.bit_buffer!=0 || r.bit_count!=0 || r.table!=none {panic('incorrect defaults')}\n}\n")
        commands = ([str(zig), "build-exe", "-target", args.target, "-O", mode, "-lc",
                     "--global-cache-dir", str(root / "zig-cache"), f"-femit-bin={z.with_suffix('')}", str(z)],
                    [str(v), *(["-prod"] if args.v_prod else []), "-path", f"{repo}|@vlib|@vmodules",
                     "-o", str(p.with_suffix('.bin')), str(p)])
        for language, command in zip(("Source", "V"), commands):
            r = proof.run(command, f"reader-constructor-{int(missing)}-{language}", timeout=args.timeout,
                          env=env if language == "V" else None, check=False)
            if missing:
                ordinary_rejection(r, f"missing reader stream/{language}")
                marker = b"missing struct field: stream" if language == "Source" else b"zigimg.JpegHuffmanReader.stream"
                if marker not in r.stdout + r.stderr: raise AssertionError("unexpected reader omission diagnostic")
            elif r.returncode:
                raise AssertionError(f"complete reader/{language}: {r.stdout!r} {r.stderr!r}")
            else:
                executable = z.with_suffix('') if language == "Source" else p.with_suffix('.bin')
                result = proof.run([str(executable)], f"reader-constructor-complete-{language}", timeout=args.timeout)
                if result.stdout or result.stderr: raise AssertionError("unexpected reader constructor output")


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
    if tree_hash(source) != PINNED_SOURCE_SHA256 or stdlib_hash(zig) != PINNED_STDLIB_SHA256:
        parser.error("Source or selected compiler library differs from pinned tree")
    repo = Path(__file__).resolve().parent.parent
    probe = repo / "zigimg/reference_probes/jpeg_contracts"
    env = dict(os.environ, VEXE=str(v), V_C_ERROR_BUG_REPORT_DISABLED="1")
    rows = corpus(repo)
    if len(rows) != EXPECTED_ROWS: raise AssertionError(f"returning corpus changed: {len(rows)}")
    with work_directory(args.workdir, "witty-jpeg-contracts-") as root:
        proof = ProofLog(root)
        shutil.copytree(source, root / "src")
        fixtures = {}
        for name in ("reference.zig", "main.v"):
            shutil.copyfile(probe / name, root / name)
            fixtures[name] = hashlib.sha256((root / name).read_bytes()).hexdigest()
        versions = [proof.run([str(zig), "version"], "zig-version").stdout.decode().strip(),
                    proof.run([str(v), "version"], "v-version", env=env).stdout.decode().strip()]
        if versions[0] != "0.15.2" or not re.match(r"^V 0\.5\.2(?: |$)", versions[1]):
            raise AssertionError("unexpected compiler version")
        runner_hash = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
        implementations = implementation_hashes(repo)
        fixture_hashes = {p.name: hashlib.sha256(p.read_bytes()).hexdigest()
                          for p in (repo / "zigimg/testdata/jpeg").glob("*.jpg")}
        provenance = dict(source_sha256=PINNED_SOURCE_SHA256, stdlib_sha256=PINNED_STDLIB_SHA256,
                          zig_version=versions[0], v_version=versions[1], target=args.target,
                          zig_mode=mode, v_prod=args.v_prod, fixtures=fixtures,
                          jpeg_fixtures=fixture_hashes, runner_sha256=runner_hash,
                          v_implementation_sha256=implementations)
        (root / "provenance.json").write_text(json.dumps(provenance, indent=2) + "\n")
        print(f"Building JPEG contracts: Source {mode}, V {'production' if args.v_prod else 'ordinary'}", flush=True)
        proof.run([str(zig), "build-exe", "-target", args.target, "-O", mode, "-lc",
                   "--global-cache-dir", str(root / "zig-cache"), f"-femit-bin={root / 'native'}",
                   str(root / "reference.zig")], "build-source", timeout=args.timeout)
        proof.run([str(v), "-enable-globals", *(["-prod"] if args.v_prod else []), "-path",
                   f"{repo}|@vlib|@vmodules", "-o", str(root / "translated"), str(root / "main.v")],
                  "build-v", env=env, timeout=args.timeout)
        path = root / "corpus.txt"
        path.write_text("\n".join(row for _, row in rows) + "\n")
        print(f"Comparing {len(rows)} returning records", flush=True)
        results = [proof.run([str(root / executable), str(path)], executable, timeout=args.timeout, check=False)
                   for executable in ("native", "translated")]
        outputs = [r.stdout.splitlines() for r in results]
        if any(r.returncode or r.stderr for r in results) or any(len(out) != len(rows) for out in outputs):
            raise AssertionError("unexpected output: " + repr([(r.returncode, len(r.stdout.splitlines()), r.stderr[:3000]) for r in results]))
        for (label, _), native, translated in zip(rows, *outputs):
            if native != translated: raise AssertionError(f"{label}: Source={native!r}, V={translated!r}")
        output_hash = hashlib.sha256(b"\n".join(outputs[0])).hexdigest()
        if output_hash != EXPECTED_SHA256: raise AssertionError(f"returning golden changed: {output_hash}")
        states = hashlib.sha256()
        for name, (op, data, value, category) in traps().items():
            observed = []
            for executable in ("native", "translated"):
                state = root / f"{name}-{executable}.state"
                r = proof.run([str(root / executable), "--trap", name, str(state), op, data.hex(), str(value)],
                              f"{name}-{executable}", timeout=args.timeout, check=False)
                checked_trap(r, f"{executable}/{name}", category)
                if not state.exists(): raise AssertionError(f"{name}: observer did not run")
                observed.append(state.read_bytes())
            if observed[0] != observed[1] or not re.fullmatch(rb"\d+(?:,\d+){0,2}", observed[0]):
                raise AssertionError(f"{name}: retained state differs {observed}")
            states.update(name.encode() + b"\0" + observed[0] + b"\n")
        state_hash = states.hexdigest()
        if state_hash != EXPECTED_STATE_SHA256: raise AssertionError(f"trap-state golden changed: {state_hash}")
        header_compiler_boundary(proof, root, zig, mode, args)
        discard_loops(proof, root)
        reader_constructors(proof, root, zig, v, mode, args, env, repo)
        if tree_hash(source) != PINNED_SOURCE_SHA256 or tree_hash(root / "src") != PINNED_SOURCE_SHA256:
            raise AssertionError("Source changed during proof")
        if stdlib_hash(zig) != PINNED_STDLIB_SHA256 or hashlib.sha256(Path(__file__).read_bytes()).hexdigest() != runner_hash:
            raise AssertionError("compiler library or runner changed during proof")
        if implementation_hashes(repo) != implementations:
            raise AssertionError("V image implementation changed during proof")
        for name, expected in fixtures.items():
            if any(hashlib.sha256((p / name).read_bytes()).hexdigest() != expected for p in (probe, root)):
                raise AssertionError("probe changed during proof")
        for name, expected in fixture_hashes.items():
            if hashlib.sha256((repo / "zigimg/testdata/jpeg" / name).read_bytes()).hexdigest() != expected:
                raise AssertionError("JPEG input changed during proof")
        summary = dict(returning_records=len(rows), output_sha256=output_hash, paired_traps=len(traps()), state_sha256=state_hash,
                       source_header_compile_rejections=1, v_header_controls=2, paired_discard_loops=3,
                       paired_reader_constructor_rejections=1, paired_reader_constructor_controls=1)
        (root / "summary.json").write_text(json.dumps(summary, indent=2) + "\n")
        print(json.dumps(summary), flush=True)


if __name__ == "__main__": main()
