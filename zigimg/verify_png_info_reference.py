"""Compare PNG diagnostic output, stream positions, and suppressed write errors."""
import argparse
import hashlib
import os
from pathlib import Path
import resource
import shutil
import subprocess
import tempfile
import zlib

from verify_png_foundation_reference import PINNED_SOURCE_SHA256, PINNED_FLATE_SHA256, FLATE_SOURCES

FORMAT_SOURCES = ["fmt.zig", "fmt/float.zig"]
PINNED_FORMAT_SHA256 = "9ad2e71bc2e950a01e29eec9d20a6e9674097602774399a5451839a23c4b278b"


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


def no_core():
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))


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
    digest = hashlib.sha256()
    for name in FLATE_SOURCES:
        digest.update(name.encode() + b"\0")
        digest.update((args.zig.resolve().parent / "lib/std" / name).read_bytes())
    if digest.hexdigest() != PINNED_FLATE_SHA256:
        parser.error("DEFLATE/reader/writer sources differ from Zig 0.15.2")
    digest = hashlib.sha256()
    for name in FORMAT_SOURCES:
        digest.update(name.encode() + b"\0")
        digest.update((args.zig.resolve().parent / "lib/std" / name).read_bytes())
    if digest.hexdigest() != PINNED_FORMAT_SHA256:
        parser.error("formatter sources differ from Zig 0.15.2")
    cases = corpus()
    probe = Path(__file__).parent / "reference_probes/png_info"
    with tempfile.TemporaryDirectory(prefix="witty-png-info-") as directory:
        root = Path(directory)
        shutil.copytree(source, root / "src")
        shutil.copyfile(probe / "reference.zig", root / "reference.zig")
        corpus_path = root / "corpus.txt"
        corpus_path.write_text("\n".join(case[1] for case in cases) + "\n")
        subprocess.run([str(args.zig.resolve()), "build-exe", "-target", args.target, "-lc", f"-femit-bin={root / 'native'}", str(root / "reference.zig")], check=True)
        subprocess.run([str(args.v.resolve()), "-o", str(root / "translated"), str(probe / "main.v")], env=dict(os.environ, VEXE=str(args.v.resolve())), check=True)
        native = subprocess.run([str(root / "native"), str(corpus_path)], capture_output=True, text=True, check=True).stdout.splitlines()
        translated = subprocess.run([str(root / "translated"), str(corpus_path)], capture_output=True, text=True, check=True).stdout.splitlines()
        if len(native) != len(cases) or len(translated) != len(cases):
            raise AssertionError((len(cases), len(native), len(translated)))
        for (label, _), expected, actual in zip(cases, native, translated):
            if expected != actual:
                raise AssertionError(f"{label}: native={expected}, V={actual}")
        print(f"PNG info: {len(cases)} cases, SHA256 {hashlib.sha256(chr(10).join(native).encode()).hexdigest()}")
        bounds = ("count_overflow", "size_overflow", "compression_tag", "filter_tag", "color_tag", "interlace_tag", "text_null", "ztxt_null", "ztxt_method", "itxt_flags", "itxt_language", "itxt_translation")
        for boundary in bounds:
            for executable in ("native", "translated"):
                result = subprocess.run([str(root / executable), "--bounds", boundary], capture_output=True, timeout=5, preexec_fn=no_core)
                first_line = result.stderr.splitlines()[0] if result.stderr else b""
                if not result.returncode or b"UNEXPECTED" in first_line or not any(marker in result.stderr for marker in (b"panic:", b"Assertion failed", b"array.get:")):
                    raise AssertionError(f"{boundary}, {executable}: {result.returncode}: {result.stderr!r}")
        print(f"PNG info: {len(bounds)} checked traps matched")


if __name__ == "__main__":
    main()
