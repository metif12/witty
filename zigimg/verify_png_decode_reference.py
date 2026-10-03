"""Compare complete PNG reads with unchanged locked zigimg and Zig 0.15.2.

Python constructs inputs only. Native decoding defines every expected result,
including error positions, palette/processor state and information output.
"""
import argparse
import hashlib
import os
from pathlib import Path
import resource
import shutil
import struct
import subprocess
import tempfile
import zlib

from verify_png_foundation_reference import PINNED_SOURCE_SHA256, PINNED_FLATE_SHA256, FLATE_SOURCES
from verify_png_info_reference import FORMAT_SOURCES, PINNED_FORMAT_SHA256

MAGIC = b"\x89PNG\r\n\x1a\n"
FORMATS = [(0, d) for d in (1, 2, 4, 8, 16)] + [(3, d) for d in (1, 2, 4, 8)] + [(c, d) for c in (2, 4, 6) for d in (8, 16)]
PASSES = [(0, 0, 8, 8), (4, 0, 8, 8), (0, 4, 4, 8), (2, 0, 4, 4), (0, 2, 2, 4), (1, 0, 2, 2), (0, 1, 1, 2)]


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
    ] + [(f"repeat-trns-stride-{color}", 1, MAGIC+header(3, 3, color, 16)+transparency(color, 16, 1)+transparency(color, 16, 0)+data+end) for color in (0, 2)]


def no_core():
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("zig", type=Path)
    parser.add_argument("v", type=Path)
    parser.add_argument("--target", default="aarch64-macos.14.0")
    args = parser.parse_args()
    source = args.source.resolve()/"src"
    digest = hashlib.sha256()
    for path in sorted(source.rglob("*")):
        if path.is_file():
            digest.update(path.relative_to(source).as_posix().encode()+b"\0")
            digest.update(path.read_bytes())
    if digest.hexdigest() != PINNED_SOURCE_SHA256:
        parser.error("src differs from locked zigimg")
    for names, expected in ((FLATE_SOURCES, PINNED_FLATE_SHA256), (FORMAT_SOURCES, PINNED_FORMAT_SHA256)):
        digest = hashlib.sha256()
        for name in names:
            digest.update(name.encode()+b"\0")
            digest.update((args.zig.resolve().parent/"lib/std"/name).read_bytes())
        if digest.hexdigest() != expected:
            parser.error("reader/decompressor/formatter sources differ from Zig 0.15.2")
    cases = corpus()
    probe = Path(__file__).resolve().parent/"reference_probes/png_decode"
    with tempfile.TemporaryDirectory(prefix="witty-png-decode-") as directory:
        root = Path(directory)
        shutil.copytree(source, root/"src")
        shutil.copyfile(probe/"reference.zig", root/"reference.zig")
        corpus_path = root/"corpus.txt"
        corpus_path.write_text("\n".join(case[1] for case in cases)+"\n")
        subprocess.run([str(args.zig.resolve()), "build-exe", "-target", args.target, "-lc", f"-femit-bin={root/'native'}", str(root/"reference.zig")], check=True)
        subprocess.run([str(args.v.resolve()), "-o", str(root/"translated"), str(probe/"main.v")], env=dict(os.environ, VEXE=str(args.v.resolve())), check=True)
        outputs = []
        for executable in ("native", "translated"):
            result = subprocess.run([str(root/executable), str(corpus_path)], capture_output=True, timeout=180, preexec_fn=no_core)
            if result.returncode:
                count = len(result.stdout.splitlines())
                label = cases[min(count, len(cases)-1)][0]
                raise AssertionError(f"{executable} stopped at {label}: {result.returncode}: {result.stderr.decode(errors='replace')}")
            outputs.append(result.stdout.splitlines())
        native, translated = outputs
        if len(native) != len(cases) or len(translated) != len(cases):
            raise AssertionError((len(cases), len(native), len(translated)))
        for (label, _), expected, actual in zip(cases, native, translated):
            if expected != actual:
                raise AssertionError(f"{label}: native={expected!r}, V={actual!r}")
        output_digest = hashlib.sha256(b"\n".join(native)).hexdigest()
        print(f"PNG decoding: {len(cases)} cases, SHA256 {output_digest}")
        for label, mode, data in bounds():
            corpus_path.write_text(f"{mode}|{data.hex()}\n")
            for executable in ("native", "translated"):
                result = subprocess.run([str(root/executable), str(corpus_path)], capture_output=True, timeout=5, preexec_fn=no_core)
                first_line = result.stderr.splitlines()[0] if result.stderr else b""
                if result.returncode == 0 or b"UNEXPECTED" in first_line or not any(marker in result.stderr for marker in (b"panic:", b"Assertion failed", b"array.get:", b"slice:")):
                    raise AssertionError(f"{label}, {executable}: {result.returncode}: {result.stdout!r}: {result.stderr!r}")
        print(f"PNG decoding: {len(bounds())} checked traps matched")


if __name__ == "__main__":
    main()
