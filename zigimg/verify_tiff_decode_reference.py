"""Compare TIFF pixels, failures, partial writes, and positions with locked source."""
import argparse
from contextlib import contextmanager
import hashlib
import json
import os
from pathlib import Path
import re
import resource
import shutil
import struct
import subprocess
import sys
import tempfile
import zlib

PINNED_SOURCE_SHA256 = "ca759a44a902143a60f42f0810dc90df7250c0f92804cf201353f0141650eb6b"
# The TIFF adapter also translates this exact compiler dependency.
PINNED_FLATE_SHA256 = "e8898fcced291d899efc9ebacf42762954ac5a1e088283cee0f1f261a498cab5"
FLATE_SOURCES = ["compress/flate.zig", "compress/flate/Decompress.zig",
                 "compress/flate/Token.zig", "compress/flate/HuffmanEncoder.zig",
                 "Io/Reader.zig", "Io/Writer.zig"]
EXPECTED_ROWS = 39707
EXPECTED_SHA256 = "22c929806d09ca615c320574abc8bb2be684f3d5596ba940f220164977fd6698"
BOUNDS = {
    **{name: ("integer overflow", "integer overflow") for name in
       ("sum_overflow", "sum_underflow", "ccitt_run", "pixel_overflow", "packbits_zero")},
    **{name: ("division by zero", "division by zero") for name in
       ("zero_rows", "empty_height")},
    "missing_counts": ("attempt to use null value", "missing TIFF strip byte counts"),
    "missing_offsets": ("attempt to use null value", "missing TIFF strip offsets"),
    **{name: ("index out of bounds", ("index out of bounds", "array.get: index out of range",
                                    "array.set: index out of range")) for name in
       ("short_counts", "short_offsets", "zero_pixels", "rgb_stride", "palette_bounds",
        "packbits_overrun")},
    "fixed_window": ("reached unreachable code", "reached unreachable code"),
    "ccitt_padding": ("integer does not fit in destination type", "integer does not fit in destination type"),
}


def tree_hash(source):
    digest = hashlib.sha256()
    for path in sorted(source.rglob("*")):
        if path.is_file():
            digest.update(path.relative_to(source).as_posix().encode() + b"\0")
            digest.update(path.read_bytes())
    return digest.hexdigest()


def no_core():
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))


@contextmanager
def work_directory(path, prefix):
    if path is None:
        with tempfile.TemporaryDirectory(prefix=prefix) as directory:
            yield Path(directory)
    else:
        root = path.resolve()
        if root.exists() and any(root.iterdir()):
            raise ValueError("--workdir must be absent or empty: " + str(root))
        root.mkdir(parents=True, exist_ok=True)
        yield root


class ProofLog:
    def __init__(self, root):
        self.root = root
        self.commands = []

    def run(self, argv, label, *, env=None, timeout=180, check=True):
        prefix = f"{len(self.commands):03d}-{label}"
        record = {"label": label, "argv": list(map(str, argv)), "cwd": os.getcwd(),
                  "timeout": timeout}
        if env:
            record["environment"] = {key: env[key] for key in
                                     ("VEXE", "V_C_ERROR_BUG_REPORT_DISABLED") if key in env}
        self.commands.append(record)
        try:
            result = subprocess.run(argv, capture_output=True, env=env, timeout=timeout,
                                    preexec_fn=no_core)
        except subprocess.TimeoutExpired as error:
            record["timed_out"] = True
            (self.root / f"{prefix}.stdout").write_bytes(error.stdout or b"")
            (self.root / f"{prefix}.stderr").write_bytes(error.stderr or b"")
            (self.root / "commands.json").write_text(json.dumps(self.commands, indent=2) + "\n")
            raise AssertionError(f"{label} timed out after {timeout}s") from error
        record["returncode"] = result.returncode
        (self.root / f"{prefix}.stdout").write_bytes(result.stdout)
        (self.root / f"{prefix}.stderr").write_bytes(result.stderr)
        (self.root / "commands.json").write_text(json.dumps(self.commands, indent=2) + "\n")
        if check and result.returncode:
            raise AssertionError(f"{label}: command failed ({result.returncode})\n"
                                 + (result.stdout + result.stderr).decode(errors="replace"))
        return result


def checked_trap(result, label, category):
    categories = (category,) if isinstance(category, str) else category
    messages = [match.group(1) for line in result.stderr.decode(errors="replace").splitlines()
                if (match := re.fullmatch(r"(?:thread \d+ |V )?panic:\s*(.*)", line.strip()))]
    if (result.returncode == 0 or result.stdout or b"UNEXPECTED" in result.stdout + result.stderr
            or not any(message.startswith(expected) for message in messages for expected in categories)):
        raise AssertionError(f"{label}: expected checked panic {categories}, got {result.returncode}\n"
                             + (result.stdout + result.stderr).decode(errors="replace"))


def pack_codes(codes, width=9):
    bits = "".join(f"{code:0{width}b}" for code in codes)
    bits += "0" * (-len(bits) % 8)
    return bytes(int(bits[index:index + 8], 2) for index in range(0, len(bits), 8))


def compressed(raw, kind):
    if kind == 1:
        return raw
    if kind == 2:
        assert len(raw) == 1
        return b"\x98"  # CCITT white run of eight pixels, followed by zero padding.
    if kind == 32773:
        return b"".join(bytes([len(raw[index:index + 128]) - 1]) + raw[index:index + 128]
                        for index in range(0, len(raw), 128))
    if kind == 5:
        # Each generated strip is below the first code-width change.
        assert len(raw) < 253
        return pack_codes([256, *raw, 257])
    return zlib.compress(raw)


def make_tiff(fmt, width, height, rows, kind, predictor, endian, version=42, photo=None):
    order = ">" if endian == "big" else "<"
    channels = [1, 1, 1, 3, 4][fmt]
    row_bytes = width // 8 if fmt == 0 else width * channels
    raw_strips = [bytes(((index * 37 + start * 19 + fmt * 13) & 255)
                        for index in range(min(rows, height - start) * row_bytes))
                  for start in range(0, height, rows)]
    payloads = [compressed(raw, kind) for raw in raw_strips]
    tags = {
        256: (4, [width]), 257: (4, [height]),
        258: (3, [1] if fmt == 0 else [8] * channels),
        259: (3, [kind]), 262: (3, [photo if photo is not None else 3 if fmt == 2 else 2 if fmt >= 3 else 1]),
        266: (3, [2]), 277: (3, [channels]), 278: (4, [rows]),
        273: (4, [0] * len(payloads)),
        279: (4, [len(payload) if kind == 32773 else 0 for payload in payloads]),
        284: (3, [2]), 317: (3, [predictor]),
    }
    if fmt == 4:
        tags[338] = (3, [2])
    if fmt == 2:
        tags[320] = (3, [((index * factor) & 255) * 256 for factor in (1, 7, 13) for index in range(256)])
    start = 8 + 2 + len(tags) * 12 + 4
    extra = bytearray()
    external = {}
    for key, (datatype, values) in sorted(tags.items()):
        if len(values) > 1:
            external[key] = start + len(extra)
            extra += struct.pack(order + ("H" if datatype == 3 else "I") * len(values), *values)
    pixels_start = start + len(extra)
    for index, payload in enumerate(payloads):
        tags[273][1][index] = pixels_start + sum(len(p) + 3 for p in payloads[:index])
    if 273 in external:
        at = external[273] - start
        extra[at:at + len(payloads) * 4] = struct.pack(order + "I" * len(payloads), *tags[273][1])
    data = bytearray((b"MM" if endian == "big" else b"II") + struct.pack(order + "HIH", version, 8, len(tags)))
    for key, (datatype, values) in sorted(tags.items()):
        data += struct.pack(order + "HHI", key, datatype, len(values))
        if len(values) > 1:
            data += struct.pack(order + "I", external[key])
        elif datatype == 3:
            data += struct.pack(order + "H", values[0]) + b"\x00\x00"
        else:
            data += struct.pack(order + "I", values[0])
    data += b"\x00" * 4 + extra
    for payload in payloads:
        data += payload + b"\x99\x88\x77"
    return bytes(data)


def corpus():
    cases = []

    def add(label, data, op=0, fmt=1, kind=1, photo=1, predictor=1,
            width=1, height=1, rows=1, dest=1, bits=(8,), offsets=(), counts=()):
        values = [op, fmt, kind, photo, predictor, width, height, rows, dest,
                  ",".join(map(str, bits)), ",".join(map(str, offsets)),
                  ",".join(map(str, counts)), data.hex()]
        cases.append((label, "|".join(map(str, values))))

    payloads = [b"", b"hello", bytes(range(256)), b"abababab" * 100,
                bytes((i * i + i * 19) & 255 for i in range(1200)),
                bytes((i // 113 + i // 17) & 255 for i in range(160000))]
    for index, raw in enumerate(payloads):
        for strategy in (zlib.Z_DEFAULT_STRATEGY, zlib.Z_FIXED, zlib.Z_HUFFMAN_ONLY):
            if strategy == zlib.Z_FIXED and len(raw) > 65536:
                continue  # This pinned path's fixed matches can trap at a window boundary.
            encoder = zlib.compressobj(6, zlib.DEFLATED, 15, 8, strategy)
            encoded = encoder.compress(raw) + encoder.flush()
            for trailing in (b"", bytes(range(9))):
                for capacity in sorted({0, max(0, len(raw) - 1), len(raw), len(raw) + 9}):
                    add(f"zlib-{index}-{strategy}-{len(trailing)}-{capacity}", encoded + trailing, dest=capacity)
            # Truncate all small inputs, and sample the large buffered cases.
            cuts = range(len(encoded) + 1) if len(encoded) < 1500 else sorted({0, 1, 2, 3, 4, 8, 17, len(encoded)//2, len(encoded)-5, len(encoded)-1})
            for cut in cuts:
                for capacity in (0, len(raw) + 9):
                    add(f"zlib-cut-{index}-{strategy}-{cut}-{capacity}", encoded[:cut], dest=capacity)
            if len(encoded) < 1500:
                for position in range(len(encoded)):
                    for bit in range(8):
                        mutated = bytearray(encoded)
                        mutated[position] ^= 1 << bit
                        add(f"zlib-bit-{index}-{strategy}-{position}-{bit}", mutated + bytes(range(9)), dest=len(raw) + 9)
    # Stored blocks exercise successful prefixes delivered before a bad footer,
    # empty blocks, and multi-window rebasing independently of Huffman coding.
    for size in (0, 1, 257, 65535, 65536, 140000):
        raw = bytes((i * 23) & 255 for i in range(size))
        encoded = zlib.compress(raw, 0)
        for capacity in sorted({0, max(0, size-1), size, size+3}):
            for cut in (len(encoded), len(encoded)-1, len(encoded)-4):
                add(f"stored-{size}-{capacity}-{cut}", encoded[:cut], dest=capacity)
    for codes in ([256, 65, 66, 257], [65, 258, 257], [256, 300, 257], [256, 65, 256, 66, 257]):
        data = pack_codes(codes)
        for cut in range(len(data)+1):
            for capacity in (0, 1, 2, 7):
                add(f"lzw-{codes}-{cut}-{capacity}", data[:cut], op=1, dest=capacity)
    # All-white eight-pixel CCITT row (10011), padded with zero bits.
    for data in (b"", b"\x98", b"\x98\x00", b"\x00\x00"):
        for photo in (0, 1, 2, 3, 65535):
            for capacity in (0, 1, 2):
                add(f"ccitt-{data.hex()}-{photo}-{capacity}", data, op=2, photo=photo, width=8, dest=capacity)
    for photo in (0, 1, 2, 3):
        for predictor in (1, 2):
            add(f"ccitt-strips-{photo}-{predictor}", b"\x00\x98\x98\x98", op=3, fmt=0,
                kind=2, photo=photo, predictor=predictor, width=8, height=3, dest=24,
                bits=(1,), offsets=(1, 2, 3), counts=(0, 0, 0))
    for endian in ("big", "little"):
        for photo in (0, 1):
            for height in (1, 3):
                data = make_tiff(0, 8, height, 1, 2, 1, endian, photo=photo)
                for op in (4, 5):
                    add(f"ccitt-read-{op}-{endian}-{photo}-{height}", data, op=op)
    for fmt in range(6):
        channels = [1, 1, 1, 3, 4, 1][fmt]
        bits = (1,) if fmt == 0 else (8,) * channels
        for width in ((7, 8, 17) if fmt == 0 else (1, 7)):
            for height in (1, 3, 5):
                for rows in (1, 2, 8):
                    row_bytes = width // 8 if fmt == 0 else width * channels
                    parts = [bytes((i * 37 + start * 19) & 255 for i in range(min(rows, height-start)*row_bytes))
                             for start in range(0, height, rows)]
                    for kind in (1, 5, 8, 32946, 32773, 6):
                        if row_bytes == 0 and kind == 32773:
                            continue
                        data = bytearray(b"\xaa")
                        offsets, counts = [], []
                        for part in parts:
                            payload = compressed(part, kind)
                            offsets.append(len(data))
                            counts.append(len(payload) if kind == 32773 else 0)
                            data += payload + b"\x99\x88\x77"
                        for predictor in (1, 2, 65535):
                            for photo in (0, 1, 3):
                                add(f"strips-{fmt}-{width}-{height}-{rows}-{kind}-{predictor}-{photo}", data,
                                    op=3, fmt=fmt, kind=kind, photo=photo, predictor=predictor,
                                    width=width, height=height, rows=rows, dest=width*height,
                                    bits=bits, offsets=offsets, counts=counts)
    # Defined clipping and ignored byte counts with smaller caller storage.
    for dest in (1, 5, 8):
        add(f"clip-{dest}", bytes(range(9)), op=3, width=8, dest=dest, offsets=(1,), counts=(0,), predictor=2)
    add("unsupported-row-size", b"\x00\x00", op=3, bits=(4,), offsets=(1,), counts=(1,))
    add("invalid-seek", b"\x00\x00", op=3, offsets=(2,), counts=(1,))
    add("later-invalid-seek", b"\x00\x7e", op=3, height=2, dest=2, offsets=(1, 2), counts=(1, 1))
    for fmt in range(5):
        for endian in ("big", "little"):
            for kind in (1, 5, 8, 32946, 32773):
                for rows in (1, 2, 8):
                    for predictor in (1, 2, 65535):
                        data = make_tiff(fmt, 8 if fmt == 0 else 3, 3, rows, kind, predictor, endian,
                                         version=(0, 43, 65535)[predictor % 3])
                        for op in (4, 5):
                            add(f"read-{op}-{fmt}-{endian}-{kind}-{rows}-{predictor}", data, op=op)
                        # Avoid successful short pixel reads (undefined source tails).
                        for cut in (0, 1, 2, 3, 4, 5, 7, 8, 9, 13):
                            add(f"header-cut-{fmt}-{endian}-{kind}-{rows}-{predictor}-{cut}", data[:cut], op=4)
    add("bad-magic", b"ZZ\x00\x00\x00\x00\x00\x00", op=4)
    return cases


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("zig", type=Path)
    parser.add_argument("v", type=Path)
    parser.add_argument("--target", default="aarch64-macos.14.0")
    parser.add_argument("--v-prod", action="store_true", help="compile V with -prod; defaults Zig to ReleaseSafe")
    parser.add_argument("--zig-mode", choices=("Debug", "ReleaseSafe"))
    parser.add_argument("--workdir", type=Path, help="retain sources, corpus, binaries, commands and diagnostics in an empty directory")
    parser.add_argument("--timeout", type=int, default=180, help="seconds allowed for each complete corpus run")
    parser.add_argument("--bounds-only", action="store_true", help="build and verify isolated failures without running the returning corpus")
    args = parser.parse_args()
    args.zig_mode = args.zig_mode or ("ReleaseSafe" if args.v_prod else "Debug")
    if args.timeout <= 0:
        parser.error("--timeout must be positive")
    source = args.source.resolve() / "src"
    if tree_hash(source) != PINNED_SOURCE_SHA256:
        parser.error("src differs from locked zigimg")
    standard_library = args.zig.resolve().parent / "lib/std"
    digest = hashlib.sha256()
    for name in FLATE_SOURCES:
        digest.update(name.encode() + b"\0")
        digest.update((standard_library / name).read_bytes())
    if digest.hexdigest() != PINNED_FLATE_SHA256:
        parser.error("DEFLATE/reader/writer sources differ from Zig 0.15.2")
    cases = [] if args.bounds_only else corpus()
    if not args.bounds_only and len(cases) != EXPECTED_ROWS:
        raise AssertionError(f"returning corpus changed: {len(cases)} != {EXPECTED_ROWS}")
    probe = Path(__file__).resolve().parent / "reference_probes/tiff_decode"
    with work_directory(args.workdir, "witty-tiff-decode-") as root:
        proof = ProofLog(root)
        shutil.copytree(source, root / "src")
        if tree_hash(root / "src") != PINNED_SOURCE_SHA256:
            raise AssertionError("copied source differs from pinned source")
        shutil.copyfile(probe / "reference.zig", root / "reference.zig")
        shutil.copyfile(probe / "main.v", root / "main.v")
        (root / "provenance.json").write_text(json.dumps({
            "source_sha256": PINNED_SOURCE_SHA256, "flate_sha256": PINNED_FLATE_SHA256,
            "source_revision": "d7b7ab0ba0899643831ef042bd73289510b39906",
            "zig_mode": args.zig_mode, "v_prod": args.v_prod, "target": args.target,
            "reference_fixture_sha256": hashlib.sha256((root / "reference.zig").read_bytes()).hexdigest(),
            "v_fixture_sha256": hashlib.sha256((root / "main.v").read_bytes()).hexdigest(),
        }, indent=2) + "\n")
        input_path = root / "corpus.txt"
        input_path.write_text("\n".join(case[1] for case in cases) + "\n")
        print(f"Building TIFF source {args.zig_mode} and V {'production' if args.v_prod else 'ordinary'}", flush=True)
        proof.run([str(args.zig.resolve()), "build-exe", "-target", args.target, "-lc", "-O", args.zig_mode,
                   f"-femit-bin={root / 'native'}", str(root / "reference.zig")], "build-source")
        env = dict(os.environ, VEXE=str(args.v.resolve()), V_C_ERROR_BUG_REPORT_DISABLED="1")
        repo = Path(__file__).resolve().parent.parent
        proof.run([str(args.v.resolve()), *(["-prod"] if args.v_prod else []), "-path",
                   f"{repo}|@vlib|@vmodules", "-o", str(root / "translated"), str(root / "main.v")],
                  "build-v", env=env)
        if not args.bounds_only:
            print(f"Comparing {len(cases)} returning TIFF cases", flush=True)
            outputs = [proof.run([str(root / executable), str(input_path)], f"corpus-{executable}",
                                 timeout=args.timeout).stdout.splitlines()
                       for executable in ("native", "translated")]
            if any(len(rows) != len(cases) for rows in outputs):
                raise AssertionError((len(cases), *map(len, outputs)))
            for (label, _), expected, actual in zip(cases, *outputs):
                if expected != actual:
                    raise AssertionError(f"{label}: native={expected!r}, V={actual!r}")
            digest = hashlib.sha256(b"\n".join(outputs[0])).hexdigest()
            if digest != EXPECTED_SHA256:
                raise AssertionError(f"historical output changed: {digest} != {EXPECTED_SHA256}")
            print(f"TIFF decoding: {len(cases)} cases, SHA256 {digest}", flush=True)
        encoder = zlib.compressobj(6, zlib.DEFLATED, 15, 8, zlib.Z_FIXED)
        fixed_path = root / "fixed.zlib"
        fixed_path.write_bytes(encoder.compress(b"A" * 70000) + encoder.flush())
        for boundary, categories in BOUNDS.items():
            for executable, category in zip(("native", "translated"), categories):
                label = f"trap-{executable}-{boundary}"
                result = proof.run([str(root / executable), "--bounds", boundary, str(fixed_path)],
                                   label, timeout=10, check=False)
                checked_trap(result, label, category)
        print(f"TIFF decoding: {len(BOUNDS)} strict checked trap pairs matched", flush=True)
        if tree_hash(source) != PINNED_SOURCE_SHA256 or tree_hash(root / "src") != PINNED_SOURCE_SHA256:
            raise AssertionError("source changed during the proof")
        (root / "result.json").write_text(json.dumps({"returning_cases": len(cases),
            "sha256": None if args.bounds_only else EXPECTED_SHA256,
            "strict_trap_pairs": len(BOUNDS), "zig_mode": args.zig_mode,
            "v_prod": args.v_prod}, indent=2) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
