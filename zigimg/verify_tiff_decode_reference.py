"""Compare TIFF pixels, failures, partial writes, and positions with locked source."""
import argparse
import hashlib
import os
from pathlib import Path
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
    args = parser.parse_args()
    source = args.source.resolve() / "src"
    digest = hashlib.sha256()
    for path in sorted(source.rglob("*")):
        if path.is_file():
            digest.update(path.relative_to(source).as_posix().encode() + b"\0")
            digest.update(path.read_bytes())
    if digest.hexdigest() != PINNED_SOURCE_SHA256:
        parser.error("src differs from locked zigimg")
    standard_library = args.zig.resolve().parent / "lib/std"
    digest = hashlib.sha256()
    for name in FLATE_SOURCES:
        digest.update(name.encode() + b"\0")
        digest.update((standard_library / name).read_bytes())
    if digest.hexdigest() != PINNED_FLATE_SHA256:
        parser.error("DEFLATE/reader/writer sources differ from Zig 0.15.2")
    cases = corpus()
    probe = Path(__file__).parent / "reference_probes/tiff_decode"
    with tempfile.TemporaryDirectory(prefix="witty-tiff-decode-") as directory:
        root = Path(directory)
        shutil.copytree(source, root / "src")
        shutil.copyfile(probe / "reference.zig", root / "reference.zig")
        input_path = root / "corpus.txt"
        input_path.write_text("\n".join(case[1] for case in cases) + "\n")
        subprocess.run([str(args.zig.resolve()), "build-exe", "-target", args.target, "-lc", f"-femit-bin={root / 'native'}", str(root / "reference.zig")], check=True)
        env = dict(os.environ, VEXE=str(args.v.resolve()))
        subprocess.run([str(args.v.resolve()), "-o", str(root / "translated"), str(probe / "main.v")], env=env, check=True)
        native = subprocess.run([str(root / "native"), str(input_path)], capture_output=True, text=True, check=True).stdout.splitlines()
        translated = subprocess.run([str(root / "translated"), str(input_path)], capture_output=True, text=True, check=True).stdout.splitlines()
        if len(native) != len(cases) or len(translated) != len(cases):
            raise AssertionError((len(cases), len(native), len(translated)))
        for (label, _), expected, actual in zip(cases, native, translated):
            if expected != actual:
                raise AssertionError(f"{label}: native={expected}, V={actual}")
        print(f"TIFF decoding: {len(cases)} cases, SHA256 {hashlib.sha256(chr(10).join(native).encode()).hexdigest()}")
        encoder = zlib.compressobj(6, zlib.DEFLATED, 15, 8, zlib.Z_FIXED)
        fixed_path = root / "fixed.zlib"
        fixed_path.write_bytes(encoder.compress(b"A" * 70000) + encoder.flush())
        boundaries = ["sum_overflow", "sum_underflow", "zero_rows", "empty_height",
                      "missing_counts", "missing_offsets", "short_counts", "short_offsets",
                      "zero_pixels", "rgb_stride", "palette_bounds", "packbits_overrun",
                      "ccitt_run", "fixed_window", "pixel_overflow"]
        def no_core():
            resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
        for boundary in boundaries:
            for executable in ("native", "translated"):
                result = subprocess.run([str(root / executable), "--bounds", boundary, str(fixed_path)],
                                        capture_output=True, text=True, timeout=10, preexec_fn=no_core)
                first_line = result.stderr.splitlines()[0] if result.stderr else ""
                if not result.returncode or "UNEXPECTED" in first_line or not any(marker in result.stderr for marker in ("panic", "Assertion failed", "array.get")):
                    raise AssertionError(f"{boundary}, {executable}: {result.returncode}: {result.stderr}")
        print(f"TIFF decoding: {len(boundaries)} checked traps matched")
    return 0


if __name__ == "__main__":
    sys.exit(main())
