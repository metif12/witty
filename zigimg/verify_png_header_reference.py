"""Compare public PNG header helpers, borrowed names, and buffered loading."""
import argparse
import hashlib
import itertools
import json
import os
from pathlib import Path
import re
import shutil
import struct
import zlib

from verify_tiff_decode_reference import ProofLog, tree_hash, work_directory

PINNED_SOURCE_SHA256 = "ca759a44a902143a60f42f0810dc90df7250c0f92804cf201353f0141650eb6b"
STDLIB_FILES = ["Io/Reader.zig", "Io/Writer.zig", "hash/crc.zig", "hash/crc/impl.zig", "debug.zig", "mem.zig"]
PINNED_STDLIB_SHA256 = "8f15ac8ae0cb2cdabf972d66be18fda272d2a2fecee4673107bbfa1b2c949fa9"
EXPECTED_ROWS = 59241
EXPECTED_SHA256 = "4c45f77f60ecc57f4c0a02c7c666d514eb3112b49bc35bd5d0cba65f2073db0d"
EXPECTED_STATE_SHA256 = "64d5b333aa2818162757b169e3a17bc82bdcd5fbeaab6291577b4981b4875797"
TRAPS = {
    **{name: "integer overflow" for name in
       ("pixel_rgb", "pixel_rgba", "pixel_alpha", "line_pixel_first", "line_mul", "line_add")},
    **{name: "reached unreachable code" for name in
       ("format_gray", "format_rgb", "format_index", "format_alpha", "format_rgba")},
}


def corpus():
    rows = []
    def add(label, *fields):
        rows.append((label, "|".join(map(str, fields))))
    for color, channels in ((0, 1), (2, 3), (3, 1), (4, 2), (6, 4)):
        for depth in range(255 // channels + 1):
            bits = channels * depth
            limit = (0xffffffff - 7) // bits if bits else 0xffffffff
            widths = {0, 1, 3, limit, max(0, limit - 1)}
            widths.update(w for w in (0x7fffffff, 0xffffffff) if w <= limit)
            for width, height, methods in itertools.product(sorted(widths), (0, 1, 0x7fffffff, 0xffffffff),
                                                           ((0, 0, 0), (1, 255, 1), (255, 1, 0))):
                add(f"helpers-{color}-{depth}-{width}-{height}-{methods}", "H", width, height, depth, color, *methods)
    for fmt in (0, 1, 2, 4, 8, 16, 0x101, 0x102, 0x104, 0x108, 0x110, 0x208,
                0x210, 0x303, 0x305, 0x3305, 0x308, 0x408, 0x1305, 0x1308,
                0x1408, 0x310, 0x410, 0x2420):
        add(f"format-{fmt}", "F", fmt)
    for name in (b"IHDR", b"tEXt", b"\0\xff\0\xff", b"ABCD"):
        for position, value in itertools.product(range(4), range(256)):
            add(f"borrow-{name.hex()}-{position}-{value}", "C", name.hex(), position, value,
                (0, 1, 0xffffffff)[value % 3])

    buffers = (0, 13, 16, 17, 31, 33, 64)
    def load(label, data):
        for capacity in buffers:
            add(f"load-{label}-buffer{capacity}", "L", capacity, data.hex())
    def png(width=17, height=3, depth=8, color=0, compression=0, filtering=0, interlace=0,
            name=b"IHDR", length=13, crc_delta=0):
        data = struct.pack(">IIBBBBB", width, height, depth, color, compression, filtering, interlace)
        return b"\x89PNG\r\n\x1a\n" + struct.pack(">I", length) + name + data + struct.pack(">I", zlib.crc32(name + data) ^ crc_delta)
    base = png()
    for cut in range(len(base) + 1):
        load(f"truncated-{cut}", base[:cut])
    for position, bit in itertools.product(range(len(base)), range(8)):
        mutated = bytearray(base)
        mutated[position] ^= 1 << bit
        load(f"bit-{position}-{bit}", mutated)
    for color in range(256):
        load(f"raw-color-{color}", png(color=color))
    for value in range(256):
        load(f"raw-interlace-{value}", png(interlace=value))
    for compression, filtering in itertools.product((0, 1, 127, 255), repeat=2):
        for tail in (b"", b"\xa5" * 64, bytes(range(64))):
            load(f"open-methods-{compression}-{filtering}-{tail.hex()}", png(compression=compression, filtering=filtering) + tail)
    for color in (0, 2, 3, 4, 6):
        for depth in (0, 1, 2, 4, 8, 16, 17, 63, 255):
            for dimension in (0, 1, 0x7fffffff, 0x80000000, 0xffffffff):
                load(f"dimensions-{color}-{depth}-{dimension}", png(width=dimension, height=dimension, color=color, depth=depth))
    for length in (0, 1, 12, 14, 0xffffffff):
        load(f"chunk-length-{length}", png(length=length))
    for name in (b"IDAT", b"ihdr", b"\0\0\0\0"):
        load(f"chunk-name-{name.hex()}", png(name=name))
    return rows


def checked_trap(result, label, category):
    diagnostic = result.stderr.decode(errors="replace")
    headers = [m.group(1) for line in diagnostic.splitlines()
               if (m := re.fullmatch(r"(?:thread \d+ |V )?panic:\s*(.*)", line))]
    unexpected = any(line.lstrip().startswith("UNEXPECTED") for line in diagnostic.splitlines())
    if (result.returncode == 0 or result.stdout or unexpected or
            not any(message == category for message in headers)):
        raise AssertionError(f"{label}: expected checked panic {category!r}, got {result.returncode}\n{diagnostic}")


def chunk_boundaries(proof, root, args, env, repo):
    for length in (0, 3, 5):
        source = root / f"chunk-length-{length}.zig"
        source.write_text('const Chunk = @import("src/formats/png/types.zig").Chunk; '
                          'pub fn main() void { const c = Chunk.init("' + "a" * length + '"); _ = c; }\n')
        result = proof.run([str(args.zig.resolve()), "build-exe", "-target", args.target, "-O", args.zig_mode,
                            "-lc", "--global-cache-dir", str(root / "zig-cache"), "-fno-emit-bin", str(source)], f"source-chunk-length-{length}", check=False)
        diagnostic = (result.stdout + result.stderr).decode(errors="replace")
        if (result.returncode <= 0 or not re.search(r"error: expected type '\*const \[4:0\]u8'", diagnostic)
                or any(word in diagnostic.lower() for word in ("panic:", "compiler bug", "segmentation fault"))):
            raise AssertionError(f"chunk length {length}: expected ordinary Source compiler rejection\n{diagnostic}")
        result = proof.run([str(root / "translated"), "--chunk-length", str(length)],
                           f"v-chunk-length-{length}", check=False)
        checked_trap(result, f"V chunk length {length}", "PNG chunk name must contain four bytes")


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
        parser.error("src differs from pinned zigimg")
    digest = hashlib.sha256()
    for name in STDLIB_FILES:
        digest.update(name.encode() + b"\0")
        digest.update((args.zig.resolve().parent / "lib/std" / name).read_bytes())
    if digest.hexdigest() != PINNED_STDLIB_SHA256:
        parser.error("selected compiler library differs from Zig 0.15.2")
    repo = Path(__file__).resolve().parent.parent
    probe = repo / "zigimg/reference_probes/png_header"
    env = dict(os.environ, VEXE=str(args.v.resolve()), V_C_ERROR_BUG_REPORT_DISABLED="1")
    rows = corpus()
    if len(rows) != EXPECTED_ROWS:
        raise AssertionError("returning corpus count changed")
    with work_directory(args.workdir, "witty-png-header-") as root:
        proof = ProofLog(root)
        shutil.copytree(source, root / "src")
        fixtures = {}
        for name in ("reference.zig", "main.v"):
            shutil.copyfile(probe / name, root / name)
            fixtures[name] = hashlib.sha256((root / name).read_bytes()).hexdigest()
        if tree_hash(root / "src") != PINNED_SOURCE_SHA256:
            raise AssertionError("copied Source changed")
        zig_version = proof.run([str(args.zig.resolve()), "version"], "zig-version").stdout.decode().strip()
        v_version = proof.run([str(args.v.resolve()), "version"], "v-version", env=env).stdout.decode().strip()
        if zig_version != "0.15.2" or not re.match(r"^V 0\.5\.2(?: |$)", v_version):
            raise AssertionError("unexpected compiler version")
        provenance = {"source_sha256": PINNED_SOURCE_SHA256, "stdlib_sha256": PINNED_STDLIB_SHA256,
                      "zig_version": zig_version, "v_version": v_version, "target": args.target,
                      "zig_mode": args.zig_mode, "v_prod": args.v_prod, "fixtures": fixtures,
                      "runner_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest()}
        (root / "provenance.json").write_text(json.dumps(provenance, indent=2) + "\n")
        print(f"Building PNG headers: Source {args.zig_mode}, V {'production' if args.v_prod else 'ordinary'}", flush=True)
        proof.run([str(args.zig.resolve()), "build-exe", "-target", args.target, "-O", args.zig_mode, "-lc",
                   "--global-cache-dir", str(root / "zig-cache"),
                   f"-femit-bin={root / 'native'}", str(root / "reference.zig")], "build-source", timeout=args.timeout)
        proof.run([str(args.v.resolve()), "-enable-globals", *(["-prod"] if args.v_prod else []), "-path",
                   f"{repo}|@vlib|@vmodules", "-o", str(root / "translated"), str(root / "main.v")],
                  "build-v", env=env, timeout=args.timeout)
        path = root / "corpus.txt"
        path.write_text("\n".join(row for _, row in rows) + "\n")
        print(f"Comparing {len(rows)} returning records", flush=True)
        results = [proof.run([str(root / executable), str(path)], executable, timeout=args.timeout, check=False)
                   for executable in ("native", "translated")]
        outputs = [result.stdout.splitlines() for result in results]
        if any(result.returncode or result.stderr for result in results) or any(len(out) != len(rows) for out in outputs):
            raise AssertionError("unexpected diagnostics or record count: " + repr([
                (r.returncode, len(r.stdout.splitlines()), r.stderr[:2000]) for r in results]))
        for (label, _), native, translated in zip(rows, *outputs):
            if native != translated:
                raise AssertionError(f"{label}: Source={native!r}, V={translated!r}")
        output_hash = hashlib.sha256(b"\n".join(outputs[0])).hexdigest()
        if output_hash != EXPECTED_SHA256:
            raise AssertionError("returning output golden changed")
        states = hashlib.sha256()
        for label, category in TRAPS.items():
            observed = []
            for executable in ("native", "translated"):
                state = root / f"{label}-{executable}.state"
                result = proof.run([str(root / executable), "--trap", label, str(state)],
                                   f"{label}-{executable}", timeout=args.timeout, check=False)
                checked_trap(result, f"{executable}/{label}", category)
                if not state.exists():
                    raise AssertionError(f"{executable}/{label}: panic observer did not run")
                observed.append(state.read_bytes())
            if observed[0] != observed[1] or not re.fullmatch(rb"\d+(?:,\d+){6}", observed[0]):
                raise AssertionError(f"{label}: panic-state mismatch {observed}")
            states.update(label.encode() + b"\0" + observed[0] + b"\n")
        state_hash = states.hexdigest()
        if state_hash != EXPECTED_STATE_SHA256:
            raise AssertionError("trap-state golden changed")
        chunk_boundaries(proof, root, args, env, repo)
        if tree_hash(source) != PINNED_SOURCE_SHA256 or tree_hash(root / "src") != PINNED_SOURCE_SHA256:
            raise AssertionError("Source changed during proof")
        if any(hashlib.sha256((probe / name).read_bytes()).hexdigest() != value or
               hashlib.sha256((root / name).read_bytes()).hexdigest() != value for name, value in fixtures.items()):
            raise AssertionError("probe changed during proof")
        if hashlib.sha256(Path(__file__).read_bytes()).hexdigest() != provenance["runner_sha256"]:
            raise AssertionError("runner changed during proof")
        summary = {"returning_records": len(rows), "output_sha256": output_hash, "paired_traps": len(TRAPS),
                   "state_sha256": state_hash, "source_length_rejections": 3, "v_length_guards": 3}
        (root / "summary.json").write_text(json.dumps(summary, indent=2) + "\n")
        print(json.dumps(summary), flush=True)


if __name__ == "__main__":
    main()
