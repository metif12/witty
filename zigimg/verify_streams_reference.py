"""Compare stream/bitstream state and checked traps with unchanged locked zigimg.

The probes use only native integer/float scalars and their aliases. Zig's other
bit-castable scalar widths remain outside the translated bitstream type surface.
"""
import argparse
import hashlib
import os
from pathlib import Path
import random
import resource
import shutil
import struct
import subprocess
import tempfile

PINNED_SOURCE_SHA256 = "ca759a44a902143a60f42f0810dc90df7250c0f92804cf201353f0141650eb6b"


def disable_core_dumps():
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))


def corpus():
    cases = []

    def add(label, mode, endian=0, kind=0, capacity=0, data=b"", actions="a"):
        cases.append((label, f"{mode}|{endian}|{kind}|{capacity}|{data.hex()}|{actions}"))

    word_bits = struct.calcsize("P") * 8
    widths = [8, 16, 32, 64, 8, 16, 32, 64, 32, 64, word_bits, word_bits] * 2
    rng = random.Random(0xd7b7ab0b)
    for endian in range(2):
        for kind, width in enumerate(widths):
            for prefix in (0, 1, 7):
                for num in range(width + 1):
                    seed = rng.getrandbits(64)
                    data = seed.to_bytes(8, "big") * 4
                    add(f"read-{endian}-{kind}-{prefix}-{num}", 0, endian, kind,
                        data=data, actions=f"t{prefix},t{num},r{width},n{num},a,t{num},s0,r{num}")
                    add(f"write-{endian}-{kind}-{prefix}-{num}", 1, endian, kind, 32,
                        actions=f"w{prefix}:{seed},w{num}:{seed ^ 0x123456789abcdef0},f,w{width}:{seed},s0,w{num}:{seed},f,w0:{seed}")
            for capacity in range(10):
                for num in (0, 1, 7, 8, width):
                    seed = rng.getrandbits(64)
                    add(f"write-failure-{endian}-{kind}-{capacity}-{num}", 1, endian, kind, capacity,
                        actions=f"w1:1,w{num}:{seed},f,f,s0,f")
            for length in range(width // 8 + 1):
                data = bytes(rng.getrandbits(8) for _ in range(length))
                for operation in ("t", "r", "n"):
                    add(f"read-eof-{endian}-{kind}-{length}-{operation}", 0, endian, kind,
                        data=data, actions=f"{operation}{width + 8},a,t0,n1")
            # Big reads discard high bits on repeated byte shifts; the source
            # only checks the narrower little-endian shift-count conversion.
            if endian == 0:
                for num in (width + 1, width + 7, width * 2):
                    add(f"big-read-over-width-{kind}-{num}", 0, endian, kind,
                        data=b"\xab\xcd\xef\x12\x34\x56\x78\x90" * 4, actions=f"t{num},a,r{num}")
                for num in (width + 1, width + 7):
                    add(f"big-write-leading-zero-{kind}-{num}", 1, endian, kind, 32,
                        actions=f"w{num}:{rng.getrandbits(64)},f")
            else:
                for num in (width + 8, width + 16, width + 64):
                    add(f"little-write-over-width-{kind}-{num}", 1, endian, kind, 32,
                        actions=f"w{num}:{rng.getrandbits(64)},f")
    for endian in range(4):
        for value in range(256):
            for kind in (0, 4, 8, 9, 12, 16, 20, 21):
                width = widths[kind]
                seed = value * 0x0101010101010101
                add(f"byte-pattern-{endian}-{kind}-{value}", 0, endian, kind,
                    data=seed.to_bytes(8, "big") * 3, actions=f"t3,r{width},a,n{width}")
                add(f"byte-write-{endian}-{kind}-{value}", 1, endian, kind, 24,
                    actions=f"w3:{seed},w{width}:{seed},f")
        for kind in range(24):
            width = widths[kind]
            for value in (0, 1, 0x80000000, 0x7f800000, 0x7fc12345, 0xff800000,
                          0x8000000000000000, 0x7ff0000000000000, 0x7ff8123456789abc,
                          0xfff0000000000000, 0xffffffffffffffff):
                data = value.to_bytes(width // 8, "big") if value < 1 << width else (value & ((1 << width) - 1)).to_bytes(width // 8, "big")
                if endian % 2 == 1:
                    data = data[::-1]
                add(f"scalar-bits-{endian}-{kind}-{value}", 0, endian, kind,
                    data=data, actions=f"n{width},a,t{width}")
                add(f"scalar-bits-write-{endian}-{kind}-{value}", 1, endian, kind, 16,
                    actions=f"w{width}:{value},f")

    for length in (0, 1, 2, 7, 8, 9, 15, 16, 17, 31, 32, 33, 63, 64, 65):
        data = bytes((index * 37 + length) % 256 for index in range(length))
        add(f"memory-read-{length}", 2, data=data,
            actions=f"p0,b,p1,t1,y-1,t2,s0,h{length + 3},s0,l{length + 2},b,y-9223372036854775808,s{length},e")
        add(f"memory-delimiter-{length}", 2, data=data,
            actions="q255,d255,s0,q0,d0,s0,x0,x1,x100,e")
        for capacity in (1, 2, 7, 8, 9, 16, 31, 64):
            add(f"file-read-{length}-{capacity}", 3, capacity=capacity, data=data,
                actions=f"p0,b,p1,t1,y-1,t1,s0,h{length + 3},s0,l{length + 2},b,y-9223372036854775808,s{length},e")
            add(f"file-delimiter-{length}-{capacity}", 3, capacity=capacity, data=data,
                actions="q255,d255,s0,q0,d0,e")
            add(f"file-closed-{length}-{capacity}", 3, capacity=capacity, data=data,
                actions="p1,c,b,h3,l4,e")
        for capacity in (0, 1, 2, 8, 64):
            add(f"file-direct-read-{length}-{capacity}", 3, capacity=capacity, data=data,
                actions=f"h0,h{length + 3},l0,l2,e")
    for capacity in (1, 2, 3, 4, 7, 8, 16, 64):
        for new_length in range(9):
            prefix = b"01234567"[:new_length].hex()
            add(f"file-shrink-{capacity}-{new_length}", 3, capacity=capacity, data=b"01234567",
                actions=f"e,z{prefix},h{new_length},b,e,s{new_length},e")
            if capacity >= max(1, new_length):
                add(f"file-shrink-buffer-fill-{capacity}-{new_length}", 3, capacity=capacity, data=b"01234567",
                    actions=f"e,z{prefix},t{new_length},b,e,s{new_length},e")
        add(f"file-grow-{capacity}", 3, capacity=capacity, data=b"012",
            actions="e,z30313233343536373839,h11,e,s9,b,e")
    for capacity in range(17):
        for mode in (4, 5):
            for length in (0, 1, 2, 3, 7, 8, 9, 16, 17, 31, 32):
                data = bytes(rng.getrandbits(8) for _ in range(length))
                add(f"byte-writes-{mode}-{capacity}-{length}", mode, capacity=capacity,
                    actions=f"w{data.hex()},b255,f,s0,a01020304,f,s2,wabcd,f,s{capacity},b170,f")
            if mode == 5:
                add(f"file-write-closed-{capacity}", mode, capacity=capacity,
                    actions="a0102,c,b255,f,s0,a03040506,f")
    for endian in range(4):
        for kind, width in enumerate(widths):
            if kind % 12 in (8, 9):
                continue
            for raw in (0, 1, (1 << (width - 1)) - 1, 1 << (width - 1),
                        (1 << width) - 1, 0xfedcba9876543210):
                data = (raw & ((1 << width) - 1)).to_bytes(width // 8, "big")
                if endian % 2 == 1:
                    data = data[::-1]
                for capacity in sorted({0, 1, width // 8 - 1, width // 8, width // 8 + 1, 16}):
                    add(f"integer-helpers-{endian}-{kind}-{raw}-{capacity}", 7, endian, kind,
                        capacity, data, str(raw))
    for capacity in (0, 1, 2, 3, 4, 7, 8, 16):
        for index, actions in enumerate([
            "w010203,w010203,b255,f,s0,w04,f,s2,f",
            "a0102030405,b170,f,a060708,f,s0,a09,f",
            "a0102,c,b255,f,a03040506,f",
            "s5,w010203,f,w04,f,s0,w05,f",
        ]):
            add(f"pipe-write-{capacity}-{index}", 8, capacity=capacity, actions=actions)
    add("writer-last-representable-position", 5, capacity=2,
        actions="s18446744073709551614,b1")
    return cases


def traps():
    names = ["memory-seek-add-overflow", "little-byte-read-width", "little-final-read-width",
             "big-byte-write-width", "big-buffered-write-width", "reader-toss-past-end",
             "file-request-capacity", "file-zero-buffer-byte", "file-seek-add-overflow",
             "reader-big-count8-shift", "reader-little-mask9", "writer-count-underflow",
             "writer-little-count8-shift", "writer-flush-count-underflow",
             "file-physical-seek-add-overflow", "streaming-writer-closed-file-seek",
             "writer-position-add-overflow"]
    return [(name, f"6|0|{code}|0||a") for code, name in enumerate(names)]


def compile_boundaries():
    return [
        ("take-float", "_ = try input.reader().takeInt(f32, .big);",
         "_ = input.take_int[f32, zigimg.BigEndian](zigimg.BigEndian{}) or { panic(err) }"),
        ("write-float", "try output.writer().writeInt(f32, 1, .big);",
         "output.write_int[f32, zigimg.BigEndian](f32(1), zigimg.BigEndian{}) or { panic(err) }"),
        ("take-invalid-endian", "_ = try input.reader().takeInt(u16, struct {}{});",
         "_ = input.take_int[u16, InvalidEndian](InvalidEndian{}) or { panic(err) }"),
        ("write-invalid-endian", "try output.writer().writeInt(u16, 1, struct {}{});",
         "output.write_int[u16, InvalidEndian](u16(1), InvalidEndian{}) or { panic(err) }"),
    ]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("zig", type=Path)
    parser.add_argument("v", type=Path)
    parser.add_argument("--target", default="aarch64-macos.14.0")
    parser.add_argument("--v-prod", action="store_true")
    args = parser.parse_args()
    source = args.source.resolve() / "src"
    digest = hashlib.sha256()
    for path in sorted(source.rglob("*")):
        if path.is_file():
            digest.update(path.relative_to(source).as_posix().encode() + b"\0")
            digest.update(path.read_bytes())
    if digest.hexdigest() != PINNED_SOURCE_SHA256:
        parser.error("src differs from locked zigimg")
    probe = Path(__file__).resolve().parent / "reference_probes/streams"
    module_root = probe.parents[2]
    cases = corpus()
    env = dict(os.environ, VEXE=str(args.v.resolve()), V_C_ERROR_BUG_REPORT_DISABLED="1")
    with tempfile.TemporaryDirectory(prefix="witty-streams-") as directory:
        root = Path(directory)
        shutil.copytree(source, root / "src")
        shutil.copyfile(probe / "reference.zig", root / "reference.zig")
        corpus_path = root / "corpus.txt"
        corpus_path.write_text("\n".join(data for _, data in cases) + "\n")
        subprocess.run([str(args.zig.resolve()), "build-exe", "-target", args.target, "-lc",
                        f"-femit-bin={root / 'native'}", str(root / "reference.zig")], check=True)
        v_options = ["-prod"] if args.v_prod else []
        subprocess.run([str(args.v.resolve()), *v_options, "-o", str(root / "translated"),
                        str(probe / "main.v")], env=env, check=True)
        outputs = [subprocess.run([str(root / executable), str(corpus_path)], capture_output=True,
                                  check=True, timeout=60, preexec_fn=disable_core_dumps).stdout.splitlines()
                   for executable in ("native", "translated")]
        if any(len(output) != len(cases) for output in outputs):
            raise AssertionError([len(cases)] + [len(output) for output in outputs])
        for (label, data), expected, actual in zip(cases, *outputs):
            if expected != actual:
                raise AssertionError(f"{label} ({data}): {expected[:500]!r} != {actual[:500]!r}")
        for label, data in traps():
            corpus_path.write_text(data + "\n")
            for executable in ("native", "translated"):
                result = subprocess.run([str(root / executable), str(corpus_path)], capture_output=True,
                                        timeout=10, preexec_fn=disable_core_dumps)
                if result.returncode == 0 or b"UNEXPECTED" in result.stdout + result.stderr or not any(marker in result.stderr for marker in (b"panic:", b"Assertion failed")):
                    raise AssertionError(f"{label}: {executable} did not produce a checked trap: {result.returncode}, {result.stdout!r}, {result.stderr[:300]!r}")
        for label, native_statements, translated_statements in compile_boundaries():
            native_path = root / f"{label}.zig"
            native_path.write_text('const io = @import("src/io.zig");\npub fn main() !void { var data: [8]u8 = @splat(0); var input = io.ReadStream.initMemory(&data); var output = io.WriteStream.initMemory(&data); _ = &input; _ = &output; ' + native_statements + ' }\n')
            translated_path = root / f"{label}.v"
            translated_path.write_text('module main\nimport zigimg\nstruct InvalidEndian {}\nfn main() { mut data := []u8{len: 8}\nmut input := zigimg.ReadStream.init_memory(data)\nmut output := zigimg.WriteStream.init_memory(mut data)\n' + translated_statements + '\n}\n')
            commands = [
                [str(args.zig.resolve()), "build-exe", "-target", args.target, "-lc", f"-femit-bin={root / 'boundary'}", str(native_path)],
                [str(args.v.resolve()), *v_options, "-path", f"{module_root}|@vlib|@vmodules", "-o", str(root / "boundary"), str(translated_path)],
            ]
            for executable, command in zip(("native", "translated"), commands):
                result = subprocess.run(command, capture_output=True, env=env, timeout=60, preexec_fn=disable_core_dumps)
                diagnostics = result.stdout + result.stderr
                if result.returncode == 0 or result.returncode < 0 or b"error:" not in diagnostics or any(marker in diagnostics.lower() for marker in (b"segmentation fault", b"panic:", b"compiler bug", b"c error found")):
                    raise AssertionError(f"{label}: {executable} did not produce an ordinary compiler rejection: {result.returncode}, {diagnostics[:500]!r}")
        result_hash = hashlib.sha256(b"\n".join(outputs[0])).hexdigest()
        print(f"Streams: {len(cases)} returning cases, {len(traps())} isolated traps, {len(compile_boundaries())} compile boundaries; SHA256 {result_hash}")


if __name__ == "__main__":
    main()
