"""Compare complete PNG reads with unchanged locked zigimg and Zig 0.15.2.

Python constructs inputs only. Native decoding defines every expected result,
including error positions, palette/processor state and information output.
"""
import argparse
import hashlib
import os
from pathlib import Path
import shutil
import struct
import zlib
import json
import re
import sys

from verify_tiff_decode_reference import ProofLog, tree_hash, work_directory

from verify_png_foundation_reference import PINNED_SOURCE_SHA256, PINNED_FLATE_SHA256, FLATE_SOURCES
from verify_png_info_reference import FORMAT_SOURCES, PINNED_FORMAT_SHA256

MAGIC = b"\x89PNG\r\n\x1a\n"
FORMATS = [(0, d) for d in (1, 2, 4, 8, 16)] + [(3, d) for d in (1, 2, 4, 8)] + [(c, d) for c in (2, 4, 6) for d in (8, 16)]
PASSES = [(0, 0, 8, 8), (4, 0, 8, 8), (0, 4, 4, 8), (2, 0, 4, 4), (0, 2, 2, 4), (1, 0, 2, 2), (0, 1, 1, 2)]
EXPECTED_ROWS = 60760
EXPECTED_SHA256 = "96ee46b18345684842d8ae9cd64290f7c5e9b86228458a83386a602bbd646e9c"
EXPECTED_PROCESSOR_ROWS = 64395
EXPECTED_PROCESSOR_SHA256 = "09ac13edac49df9819661dccd6625541d1e4590d0e3935e4738bf01bb447d6af"
EXPECTED_TRAPS = 26
EXPECTED_STATE_SHA256 = "f2c3d51b1acd37f3f435e2ac9399ae936ce897ff59a34426164bebba2ac8be35"
PIXEL_FORMATS = [0, 1, 2, 4, 8, 16, 0x101, 0x102, 0x104, 0x108, 0x110, 0x208, 0x210,
                 0x303, 0x305, 0x3305, 0x308, 0x408, 0x1305, 0x1308, 0x1408, 0x310, 0x410, 0x2420]
INDEXED = [0, 1, 2, 4, 8, 16]
ALPHA_DEST = [0x208, 0x210, 0x408, 0x1408, 0x410]


def chunk(name, payload=b"", *, length=None, crc=None):
    return struct.pack(">I", len(payload) if length is None else length) + name + payload + struct.pack(">I", zlib.crc32(name + payload) if crc is None else crc)


def header(width, height, color, depth, interlace=0, compression=0, filtering=0):
    return chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, depth, color, compression, filtering, interlace))


def paeth(a, b, c):
    p = a + b - c
    distances = [abs(p-a), abs(p-b), abs(p-c)]
    return (a, b, c)[distances.index(min(distances))]


def scanlines(width, height, color, depth, interlace, filter_, seed=0):
    channels = {0: 1, 3: 1, 2: 3, 4: 2, 6: 4}[color]
    stride = (depth+7)//8 * channels
    output = bytearray()
    for sx, sy, dx, dy in PASSES if interlace else [(0, 0, 1, 1)]:
        if sx >= width or sy >= height:
            continue
        previous = b""
        for y in range(sy, height, dy):
            samples = [(x*37 + y*19 + c*43 + seed*7) & ((1 << depth)-1)
                       for x in range(sx, width, dx) for c in range(channels)]
            if depth < 8:
                row = bytearray((len(samples)*depth+7)//8)
                for i, value in enumerate(samples):
                    row[i*depth//8] |= value << (8-depth-(i*depth)%8)
            elif depth == 8:
                row = bytes(samples)
            else:
                row = b"".join(struct.pack(">H", value) for value in samples)
            output.append(filter_)
            for i, value in enumerate(row):
                a = row[i-stride] if i >= stride else 0
                b = previous[i] if previous else 0
                c = previous[i-stride] if previous and i >= stride else 0
                predictor = (0, a, b, (a+b)//2, paeth(a, b, c))[filter_]
                output.append((value-predictor) & 255)
            previous = row
    return bytes(output)


def compress(raw, kind=1):
    encoder = zlib.compressobj(0 if kind == 0 else 6, zlib.DEFLATED, 15, 8,
                              zlib.Z_FIXED if kind == 2 else zlib.Z_DEFAULT_STRATEGY)
    return encoder.compress(raw) + encoder.flush()


def palette(depth):
    return chunk(b"PLTE", bytes(value for i in range(1 << depth) for value in (i, i*7 & 255, i*13 & 255)))


def transparency(color, depth, seed=0):
    if color == 3:
        payload = bytes((i*71) & 255 for i in range(min(3, 1 << depth)))
    elif color == 0:
        payload = struct.pack(">H", seed*7 & ((1 << depth)-1))
    elif color == 2:
        payload = b"".join(struct.pack(">H", c*43+seed*7) for c in range(3))
    else:
        payload = b"\x00\xff"  # Source skips tRNS for formats already carrying alpha.
    return chunk(b"tRNS", payload)


def image(width=3, height=3, color=0, depth=8, interlace=0, filter_=0, seed=0, kind=1, split=None, trns=True):
    encoded = compress(scanlines(width, height, color, depth, interlace, filter_, seed), kind)
    split = len(encoded)//2 if split is None else split
    return (MAGIC + header(width, height, color, depth, interlace)
            + (palette(depth) if color == 3 else b"")
            + (transparency(color, depth, seed) if trns else b"")
            + chunk(b"IDAT", encoded[:split]) + chunk(b"IDAT", encoded[split:]) + chunk(b"IEND"))


def corpus():
    cases = []

    def add(label, data, modes=range(8)):
        for mode in modes:
            cases.append((f"{label}-mode{mode}", f"{mode}|{data.hex()}"))

    for color, depth in FORMATS:
        for width, height in ((1, 1), (3, 3), (8, 9), (17, 2)):
            for interlace in (0, 1):
                for filter_ in range(5):
                    for kind in range(3):
                        for seed in (0, 1):
                            label = f"matrix-{color}-{depth}-{width}-{height}-{interlace}-{filter_}-{kind}-{seed}"
                            add(label, image(width, height, color, depth, interlace, filter_, seed, kind))
    for color, depth in FORMATS:
        base = image(color=color, depth=depth)
        for cut in range(len(base)+1):
            add(f"truncate-{color}-{depth}-{cut}", base[:cut])
        encoded = compress(scanlines(3, 3, color, depth, 0, 0))
        prefix = MAGIC + header(3, 3, color, depth) + (palette(depth) if color == 3 else b"")
        for split in range(len(encoded)+1):
            add(f"split-{color}-{depth}-{split}", image(color=color, depth=depth, split=split))
        add(f"byte-idats-{color}-{depth}", prefix + b"".join(chunk(b"IDAT", bytes([byte])) for byte in encoded) + chunk(b"IEND"))
        for length in (0, 1, 2, 3, 6, 8):
            add(f"trns-length-{color}-{depth}-{length}", prefix + chunk(b"tRNS", bytes(length)) + chunk(b"IDAT", encoded) + chunk(b"IEND"))
        repeat_modes = (0, 2, 4, 6) if depth == 16 and color in (0, 2) else range(8)
        add(f"repeat-trns-{color}-{depth}", prefix + transparency(color, depth, 1) + transparency(color, depth, 0) + chunk(b"IDAT", encoded) + chunk(b"IEND"), repeat_modes)
        add(f"post-trns-{color}-{depth}", prefix + chunk(b"IDAT", encoded) + transparency(color, depth) + chunk(b"IEND"))
        add(f"bad-trns-crc-{color}-{depth}", prefix + chunk(b"tRNS", transparency(color, depth)[8:-4], crc=0) + chunk(b"IDAT", encoded) + chunk(b"IEND"))
    encoded = compress(scanlines(3, 3, 2, 8, 0, 0))
    prefix = MAGIC + header(3, 3, 2, 8)
    data = chunk(b"IDAT", encoded)
    end = chunk(b"IEND")
    for label, body in (
        ("no-idat", end), ("repeat-ihdr", header(3, 3, 2, 8)+data+end),
        ("repeat-plte", palette(1)+palette(1)+data+end),
        ("empty-plte", chunk(b"PLTE")+palette(1)+data+end),
        ("bad-plte-crc", chunk(b"PLTE", bytes(6), crc=0)+data+end),
        ("post-plte", data+palette(1)+end),
        ("post-repeat-plte", palette(1)+data+palette(1)+end),
        ("bad-idat-crc", chunk(b"IDAT", encoded, crc=0)+end),
        ("no-next-header", data), ("no-iend-crc", data+end[:8]),
        ("nonconsecutive-idat", data+chunk(b"abCd", b"abc")+chunk(b"IDAT", b"x")+end),
        ("empty-initial-idat", chunk(b"IDAT")+data+end),
        ("empty-final-idat", data+chunk(b"IDAT")+end),
        ("empty-middle-idat", chunk(b"IDAT", encoded[:3])+chunk(b"IDAT")+chunk(b"IDAT", encoded[3:])+end),
        ("iend-ignore-crc", data+chunk(b"IEND", crc=0)),
        ("iend-ignore-length", data+chunk(b"IEND", length=99)),
        ("unknown-ancillary", chunk(b"abCd", b"abc")+data+end),
        ("unknown-critical", chunk(b"ABCD", b"abc")+data+end),
        ("critical-header-body", chunk(b"ABCD", struct.pack(">I", 0)+b"IEND")+data+end),
        ("text", chunk(b"tEXt", b"key\0hello")+data+end),
        ("compressed-text", chunk(b"zTXt", b"key\0\0"+compress(b"hello"))+data+end),
        ("international-text", chunk(b"iTXt", b"key\0\1\0en\0title\0raw bytes")+data+end),
    ):
        add(label, prefix+body)
    for length in (1, 2, 4, 769):
        add(f"invalid-plte-{length}", prefix+chunk(b"PLTE", bytes(length))+data+end)
    for color in (0, 4):
        add(f"forbidden-plte-{color}", MAGIC+header(3, 3, color, 8)+palette(1)+data+end)
    add("indexed-no-plte", MAGIC+header(3, 3, 3, 8)+data+end)
    add("indexed-empty-plte", MAGIC+header(3, 3, 3, 8)+chunk(b"PLTE")+data+end)
    for compression, filtering in ((1, 0), (0, 1), (17, 255), (255, 17)):
        add(f"open-methods-{compression}-{filtering}", MAGIC+header(3, 3, 2, 8, compression=compression, filtering=filtering)+data+end, modes=(0, 1, 2, 3, 5, 6, 7))
    for position in (0, 1, len(encoded)-4, len(encoded)-1):
        modified = bytearray(encoded)
        modified[position] ^= 0x80
        add(f"zlib-header-trailer-{position}", prefix+chunk(b"IDAT", modified)+end)
    raw = scanlines(3, 3, 2, 8, 0, 0)
    for cut in range(len(raw)):
        add(f"short-inflated-{cut}", prefix+chunk(b"IDAT", compress(raw[:cut]))+end)
    add("invalid-filter", prefix+chunk(b"IDAT", compress(b"\5"+raw[1:]))+end)
    for color, depth in FORMATS:
        for interlace in (0, 1):
            add(f"callback-order-{color}-{depth}-{interlace}", image(color=color, depth=depth, interlace=interlace), range(8, 14))
    # Exercise IDAT rebase/read-ahead and the 64-KiB output window, plus the
    # source's >=128-KiB temporary-row allocation branch. Avoid its inherited
    # fixed-match-at-window-boundary trap (already isolated by the TIFF runner).
    for width, height, color, depth, interlace in ((4097, 17, 0, 8, 0), (512, 129, 2, 8, 1), (17001, 1, 6, 16, 0), (8193, 9, 0, 8, 1)):
        raw = scanlines(width, height, color, depth, interlace, 4)
        for kind in (0, 1):
            encoded = compress(raw, kind)
            prefix = MAGIC+header(width, height, color, depth, interlace)
            for split in sorted({1, min(4095, len(encoded)-1), min(4096, len(encoded)-1), min(4097, len(encoded)-1), len(encoded)//2}):
                add(f"large-{width}-{height}-{color}-{depth}-{interlace}-{kind}-{split}", prefix+chunk(b"IDAT", encoded[:split])+chunk(b"IDAT", encoded[split:])+end)
    # Repeat returning branches through File.Reader, whose buffering and seek
    # workaround can change source positions and results relative to memory.
    file_cases = [(label, line) for label, line in cases if label.endswith("-mode0") and
                  (label.startswith(("truncate-0-8-", "split-2-16-", "byte-idats-", "large-")) or
                   label in ("post-plte-mode0", "unknown-ancillary-mode0", "bad-idat-crc-mode0", "empty-initial-idat-mode0"))]
    file_cases += [(label, line) for label, line in cases if label.startswith("matrix-") and label.endswith("-0-0-mode5")]
    file_cases += [(label, line) for label, line in cases if label.startswith("callback-order-")]
    for transport in range(1, 6):
        for label, line in file_cases:
            mode, hex_data = line.split("|")
            cases.append((f"file{transport}-{label}", f"{transport*100+int(mode)}|{hex_data}"))
    return cases


def bounds():
    prefix = MAGIC+header(3, 3, 2, 8)
    raw = scanlines(3, 3, 2, 8, 0, 0)
    data = chunk(b"IDAT", compress(raw))
    end = chunk(b"IEND")
    return [
        ("pixel-count-overflow", 0, MAGIC+header(0x7fffffff, 3, 0, 8)+data+end),
        ("extra-inflated-data", 0, prefix+chunk(b"IDAT", compress(raw+b"x"))+end),
        ("adam7-byte-y-overflow", 0, image(width=1, height=249, interlace=1, trns=False)),
        ("ancillary-skip-overflow", 0, prefix+struct.pack(">I", 0xffffffff)+b"abCd"+data+end),
        ("post-plte-skip-overflow", 0, prefix+data+struct.pack(">I", 0xffffffff)+b"PLTE"+end),
        ("trns-palette-bounds", 1, MAGIC+header(3, 3, 3, 8)+chunk(b"PLTE", bytes(3))+chunk(b"tRNS", bytes(2))+data+end),
        ("spread16-short-source", 14, image(width=1, height=1, color=2, depth=16, interlace=1, trns=False)),
        ("spread16-short-destination", 15, image(width=1, height=1, color=0, depth=16, trns=False)),
    ] + [(f"repeat-trns-stride-{color}", 1, MAGIC+header(3, 3, color, 16)+transparency(color, 16, 1)+transparency(color, 16, 0)+data+end) for color in (0, 2)]


def checked_trap(result, label, category):
    lines = (result.stdout + result.stderr).decode(errors="replace").splitlines()
    unexpected = any(re.match(r"^(?:UNEXPECTED\b|(?:thread \d+ |V )?panic:\s*UNEXPECTED\b)", line.strip())
                     for line in lines)
    messages = [match.group(1) for line in result.stderr.decode(errors="replace").splitlines()
                if (match := re.fullmatch(r"(?:thread \d+ |V )?panic:\s*(.*)", line.strip()))]
    if (result.returncode == 0 or result.stdout or unexpected or not messages
            or not messages[0].startswith(category)):
        raise AssertionError(f"{label}: expected checked panic {category}, got {result.returncode}\n"
                             + (result.stdout + result.stderr).decode(errors="replace"))


def processor_cases():
    cases = []
    def add(label, *values):
        cases.append((label, "|".join(map(str, values))))
    for op in (0, 1):  # Concrete and public erased-callback entry points.
        for arm in range(4):
            for src in PIXEL_FORMATS:
                for dest in ALPHA_DEST + [0, 0x308]:
                    for length in range(17):
                        bypass = arm == 0 or src in INDEXED or dest not in ALPHA_DEST
                        if not bypass:
                            if arm == 1:
                                if src not in [0x101, 0x102, 0x104, 0x108, 0x110] or (src == 0x110 and length % 2):
                                    continue
                            elif arm == 2:
                                if src not in [0x308, 0x310] or length % (4 if src == 0x308 else 8):
                                    continue
                                if src == 0x308 and dest in [0x208, 0x210] and length >= 4:
                                    continue  # Inherited zero-increment loop, checked separately.
                            else:
                                continue  # Non-indexed index_alpha reaches Source unreachable.
                        for seed in (0, 7):
                            add(f"trns-row-{op}-{arm}-{src}-{dest}-{length}-{seed}", op, src, dest, arm, length, seed, 0)
    for src in PIXEL_FORMATS:
        for dest in ALPHA_DEST + [0, 0x308]:
            for size in (0, 1, 4, 257):
                if src == 0 and size and dest in [0x408, 0x1408, 0x410]:
                    continue  # Source switch traps even with an empty destination.
                for length in range(20):
                    for adapter in (0, 1):
                        seed = min(size - 1, 65535) if size else 0
                        add(f"plte-row-{src}-{dest}-{size}-{length}-{adapter}", 2, src, dest, size, length, seed, adapter)
    for arm in range(4):
        for length in range(5):
            for size in range(5):
                if arm == 3 and length > size:
                    continue
                for adapter in (0, 1):
                    add(f"trns-palette-{arm}-{length}-{size}-{adapter}", 3, arm, length, size, 0, 0, adapter)
    for color, depth in FORMATS:
        for fmt in (0, 0x108, 0x110, 0x308, 0x310, 0x408):
            for length in (0, 1, 2, 3, 4, 6, 7, 16):
                for processed in (0, 1):
                    for available in (0, 1, 4, 8, 16, 64):
                        add(f"trns-chunk-{color}-{depth}-{fmt}-{length}-{processed}-{available}", 4, color, depth, fmt, length, processed, available)
    for fmt in PIXEL_FORMATS:
        for processed in (0, 1):
            add(f"plte-chunk-{fmt}-{processed}", 5, 3, 8, fmt, 0xffffffff, processed, 64)
    for method in range(3):
        add(f"empty-adapter-{method}", 6, method, 0, 0, 0, 0, 0)
    return cases


PROCESSOR_TRAPS = {
    "processed-trns-skip-overflow": ("4|0|8|264|4294967295|1|64", "integer overflow"),
    "gray16-short-byte-row": ("0|272|528|1|3|7|0", "exact division produced remainder"),
    "rgb24-short-byte-row": ("1|776|1032|2|3|7|0", "exact division produced remainder"),
    "rgb48-short-byte-row": ("0|784|1040|2|7|7|0", "exact division produced remainder"),
    "gray-invalid-source": ("0|776|1032|1|0|7|0", "reached unreachable code"),
    "rgb-invalid-source": ("1|264|1032|2|0|7|0", "reached unreachable code"),
    "indexed-alpha-nonindexed-row": ("0|264|1032|3|0|7|0", "reached unreachable code"),
    "trns-palette-prefix": ("3|3|2|1|0|0|0", "index out of bounds"),
    "trns-adapter-palette-prefix": ("3|3|2|1|0|0|1", "index out of bounds"),
    "plte-byte-index-bounds": ("2|8|1032|1|4|1|0", "index out of bounds"),
    "plte-u16-index-bounds": ("2|16|1032|1|4|256|1", "index out of bounds"),
    "plte-row-prefix": ("2|8|1032|1|8|0|2", "index out of bounds"),
    "plte-invalid-empty-row": ("2|0|1032|1|0|0|0", "reached unreachable code"),
    "zero-width-header": ("7|0|1|0|0|0|0", "division by zero"),
    "zero-height-header": ("7|1|0|0|0|0|0", "division by zero"),
    "zero-size-header": ("7|0|0|0|0|0|0", "division by zero"),
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("zig", type=Path)
    parser.add_argument("v", type=Path)
    parser.add_argument("--target", default="aarch64-macos.14.0")
    parser.add_argument("--v-prod", action="store_true", help="compile V with -prod; defaults Zig to ReleaseSafe")
    parser.add_argument("--zig-mode", choices=("Debug", "ReleaseSafe"))
    parser.add_argument("--workdir", type=Path, help="retain source, fixtures, inputs, binaries, exact commands and diagnostics in an empty directory")
    parser.add_argument("--zig-cache", type=Path, help="optional reusable task-specific global Zig cache")
    parser.add_argument("--bounds-only", action="store_true", help="verify isolated failures and inherited loop without returning corpora")
    parser.add_argument("--timeout", type=int, default=180,
                        help="seconds allowed for each complete corpus run (default: 180)")
    args = parser.parse_args()
    args.zig_mode = args.zig_mode or ("ReleaseSafe" if args.v_prod else "Debug")
    if args.timeout <= 0:
        parser.error("--timeout must be positive")
    source = args.source.resolve() / "src"
    if tree_hash(source) != PINNED_SOURCE_SHA256:
        parser.error("src differs from locked zigimg")
    std = args.zig.resolve().parent / "lib/std"
    dependencies = ((FLATE_SOURCES, PINNED_FLATE_SHA256),
                    (FORMAT_SOURCES, PINNED_FORMAT_SHA256),
                    (["mem.zig", "debug.zig"], "d8e33d24ad79f9e3cf7694a9914bcf8023d5125b15f1b51930fab0e91114e65e"))
    def std_hash(names):
        digest = hashlib.sha256()
        for name in names:
            digest.update(name.encode() + b"\0")
            digest.update((std / name).read_bytes())
        return digest.hexdigest()
    for names, expected in dependencies:
        if std_hash(names) != expected:
            parser.error("reader/decompressor/formatter/memory/debug sources differ from Zig 0.15.2")
    cases = [] if args.bounds_only else corpus()
    extra = [] if args.bounds_only else processor_cases()
    if not args.bounds_only and len(cases) != EXPECTED_ROWS:
        raise AssertionError(f"returning corpus changed: {len(cases)} != {EXPECTED_ROWS}")
    if not args.bounds_only and len(extra) != EXPECTED_PROCESSOR_ROWS:
        raise AssertionError(f"processor corpus changed: {len(extra)} != {EXPECTED_PROCESSOR_ROWS}")
    probe = Path(__file__).resolve().parent / "reference_probes/png_decode"
    repo = Path(__file__).resolve().parent.parent
    with work_directory(args.workdir, "witty-png-decode-") as root:
        proof = ProofLog(root)
        shutil.copytree(source, root / "src")
        if tree_hash(root / "src") != PINNED_SOURCE_SHA256:
            raise AssertionError("copied source differs from pinned source")
        fixtures = ("reference.zig", "main.v", "processors.zig", "processors.v")
        for name in fixtures:
            shutil.copyfile(probe / name, root / name)
        metadata = {"source_sha256": PINNED_SOURCE_SHA256,
                    "source_revision": "d7b7ab0ba0899643831ef042bd73289510b39906",
                    "runner_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
                    "zig_mode": args.zig_mode, "v_prod": args.v_prod, "target": args.target,
                    "fixture_sha256": {name: hashlib.sha256((root / name).read_bytes()).hexdigest() for name in fixtures},
                    "std_sha256": {",".join(names): expected for names, expected in dependencies},
                    "implementation_sha256": {name: hashlib.sha256((repo / "zigimg" / name).read_bytes()).hexdigest()
                                             for name in ("png_reader.v", "png_processors.v")}}
        (root / "provenance.json").write_text(json.dumps(metadata, indent=2) + "\n")
        input_path = root / "corpus.txt"
        input_path.write_text("\n".join(case[1] for case in cases) + "\n")
        processor_path = root / "processors.txt"
        processor_path.write_text("\n".join(case[1] for case in extra) + "\n")
        cache = args.zig_cache.resolve() if args.zig_cache else root / "zig-cache"
        print(f"Building PNG source {args.zig_mode} and V {'production' if args.v_prod else 'ordinary'}", flush=True)
        env = dict(os.environ, VEXE=str(args.v.resolve()), V_C_ERROR_BUG_REPORT_DISABLED="1")
        for fixture, executable in (("reference.zig", "native"), ("processors.zig", "processors-native")):
            proof.run([str(args.zig.resolve()), "build-exe", "--global-cache-dir", str(cache),
                       "-target", args.target, "-lc", "-O", args.zig_mode,
                       f"-femit-bin={root / executable}", str(root / fixture)], "build-" + executable)
        for fixture, executable in (("main.v", "translated"), ("processors.v", "processors-v")):
            proof.run([str(args.v.resolve()), "-enable-globals", *(["-prod"] if args.v_prod else []),
                       "-path", f"{repo}|@vlib|@vmodules", "-o", str(root / executable), str(root / fixture)],
                      "build-" + executable, env=env)
        hashes = []
        if not args.bounds_only:
            for rows, path, executables, label in ((cases, input_path, ("native", "translated"), "decode"),
                                                   (extra, processor_path, ("processors-native", "processors-v"), "processors")):
                print(f"Comparing {len(rows)} returning PNG {label} cases", flush=True)
                outputs = [proof.run([str(root / executable), str(path)], "corpus-" + executable,
                                     timeout=args.timeout).stdout.splitlines() for executable in executables]
                if any(len(output) != len(rows) for output in outputs):
                    raise AssertionError((len(rows), *map(len, outputs)))
                for (case_label, _), expected, actual in zip(rows, *outputs):
                    if expected != actual:
                        raise AssertionError(f"{case_label}: native={expected!r}, V={actual!r}")
                digest = hashlib.sha256(b"\n".join(outputs[0])).hexdigest()
                hashes.append(digest)
                if label == "decode" and digest != EXPECTED_SHA256:
                    raise AssertionError(f"historical output changed: {digest} != {EXPECTED_SHA256}")
                if label == "processors" and digest != EXPECTED_PROCESSOR_SHA256:
                    raise AssertionError(f"processor output changed: {digest} != {EXPECTED_PROCESSOR_SHA256}")
                print(f"PNG {label}: {len(rows)} cases, SHA256 {digest}", flush=True)
        states = []
        def compare_trap(label, line, category, path, executables):
            path.write_text(line + "\n")
            pair = []
            for executable in executables:
                state_path = root / f"state-{label}-{executable}.txt"
                result = proof.run([str(root / executable), str(path), str(state_path)],
                                   f"trap-{executable}-{label}", timeout=10, check=False)
                checked_trap(result, f"{label}, {executable}", category)
                state = state_path.read_bytes()
                if len(state) != 17 or not all(byte in b"0123456789abcdef" for byte in state[:16]) or state[-1:] != b"\n":
                    raise AssertionError(f"invalid/missing state observation: {label}, {executable}: {state!r}")
                pair.append(state)
            if pair[0] != pair[1]:
                raise AssertionError(f"{label}: native state={pair[0]!r}, V state={pair[1]!r}")
            states.append(label.encode() + b"|" + pair[0].rstrip(b"\n"))
            print(f"{label}: strict panic and initialized retained state match", flush=True)
        for label, mode, data in bounds():
            category = ("exact division produced remainder" if label.startswith("spread16-") else
                        "index out of bounds" if label == "trns-palette-bounds" else
                        "reached unreachable code" if label.startswith("repeat-trns") or label == "extra-inflated-data" else
                        "integer overflow")
            compare_trap(label, f"{mode}|{data.hex()}", category, input_path, ("native", "translated"))
        for label, (line, category) in PROCESSOR_TRAPS.items():
            compare_trap(label, line, category, processor_path, ("processors-native", "processors-v"))
        # This four-byte case cannot legitimately take one second to return.
        # A timeout establishes the inherited zero-increment loop separately
        # from checked failures; output or diagnostics invalidate that claim.
        processor_path.write_text("0|776|520|2|4|7|0\n")
        for executable in ("processors-native", "processors-v"):
            try:
                proof.run([str(root / executable), str(processor_path)], "loop-" + executable, timeout=1)
            except AssertionError:
                if not proof.commands[-1].get("timed_out"):
                    raise
                prefix = f"{len(proof.commands)-1:03d}-loop-{executable}"
                if (root / f"{prefix}.stdout").read_bytes() or (root / f"{prefix}.stderr").read_bytes():
                    raise AssertionError(f"{executable}: inherited loop emitted unexpected output")
            else:
                raise AssertionError(f"{executable}: inherited zero-increment loop returned")
        if tree_hash(source) != PINNED_SOURCE_SHA256 or tree_hash(root / "src") != PINNED_SOURCE_SHA256:
            raise AssertionError("source changed during the proof")
        for names, expected in dependencies:
            if std_hash(names) != expected:
                raise AssertionError("compiler dependency changed during the proof")
        for name, expected in metadata["fixture_sha256"].items():
            if hashlib.sha256((root / name).read_bytes()).hexdigest() != expected or hashlib.sha256((probe / name).read_bytes()).hexdigest() != expected:
                raise AssertionError("fixture changed during the proof: " + name)
        for name, expected in metadata["implementation_sha256"].items():
            if hashlib.sha256((repo / "zigimg" / name).read_bytes()).hexdigest() != expected:
                raise AssertionError("owned implementation changed during the proof: " + name)
        if hashlib.sha256(Path(__file__).read_bytes()).hexdigest() != metadata["runner_sha256"]:
            raise AssertionError("runner changed during the proof")
        state_digest = hashlib.sha256(b"\n".join(states)).hexdigest()
        if len(states) != EXPECTED_TRAPS or state_digest != EXPECTED_STATE_SHA256:
            raise AssertionError(f"panic states changed: {len(states)}, {state_digest}")
        result = {"returning_cases": len(cases), "sha256": hashes[0] if hashes else None,
                  "processor_cases": len(extra), "processor_sha256": hashes[1] if hashes else None,
                  "strict_trap_pairs": len(bounds()) + len(PROCESSOR_TRAPS), "panic_state_pairs": len(states),
                  "state_sha256": state_digest, "inherited_loop_pairs": 1,
                  "zig_mode": args.zig_mode, "v_prod": args.v_prod}
        (root / "result.json").write_text(json.dumps(result, indent=2) + "\n")
        print(f"PNG decoding: {result['strict_trap_pairs']} strict checked traps and retained states, "
              f"one inherited loop; state SHA256 {state_digest}", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
