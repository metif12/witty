"""Compare public color constructors/getters with unchanged locked zigimg.

Defined float output bits are compared exactly; NaN payloads are canonicalized.
The matrix keeps the source's unsupported mixed-width arrays and HTML boundaries,
including unsupported float/integer instantiations and checked packed-channel traps.
"""
import argparse
import hashlib
import itertools
import os
from pathlib import Path
import random
import resource
import shutil
import struct
import subprocess
import tempfile

PINNED_SOURCE_SHA256 = "ca759a44a902143a60f42f0810dc90df7250c0f92804cf201353f0141650eb6b"


def float_bits(value):
    return struct.unpack("<I", struct.pack("<f", value))[0]


def double_bits(value):
    return struct.unpack("<Q", struct.pack("<d", value))[0]


def disable_core_dumps():
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))


def corpus():
    cases = []

    def add(label, mode, values):
        cases.append((label, "|".join(map(str, [mode, *values]))))

    boundaries = [float_bits(value) for value in (-2, -1, -0.5, -0.0, 0, 0.1, 0.5, 0.9, 1, 1.5, 2)]
    boundaries += [1, 0x007fffff, 0x00800000, 0x33800000, 0x34000001, 0x3f7fffff,
                   0x3f800001, 0x7f7fffff, 0xff7fffff, 0x7f800000, 0xff800000, 0x7fc00000]
    doubles = [double_bits(value) for value in (-2, -1, -0.5, -0.0, 0, 0.1, 0.5, 0.9, 1, 1.5, 2)]
    doubles += [1, 0x000fffffffffffff, 0x0010000000000000, 0x3fefffffffffffff,
                0x3ff0000000000001, 0x7fefffffffffffff, 0xffefffffffffffff,
                0x7ff0000000000000, 0xfff0000000000000, 0x7ff8000000000000]
    for index, values in enumerate(itertools.product(boundaries, repeat=3)):
        add(f"float-boundary-{index}", 1, (*values, boundaries[index % len(boundaries)]))
    for value in range(256):
        seed = (value * 0x0101010101010101) ^ 0x123456789abcdef0
        add(f"packed-byte-{value}", 0, [seed, 0, 0, 0])
        add(f"constructors-byte-{value}", 6, [seed, 0, 0, 0])
        add(f"custom-dispatch-byte-{value}", 9, [seed, 0, 0, 0])
        add(f"packed-alias-byte-{value}", 10, [seed, 0, 0, 0])
        add(f"scale-byte-{value}", 4, [seed, boundaries[value % len(boundaries)], doubles[value % len(doubles)], 0])
    for kind, limit in enumerate([2, 4, 16, 256, 65536, 256, 65536]):
        values = range(limit) if limit <= 256 else [0, 1, 127, 128, 255, 256, 32767, 32768, 65534, 65535]
        for value in values:
            for alpha in ([0, 1, limit // 2, limit - 1] if kind in (5, 6) else [0]):
                add(f"gray-{kind}-{value}-{alpha}", 2, [kind, value, alpha, 0])
    for value, alpha in itertools.product(boundaries, repeat=2):
        add(f"gray-float-{value}-{alpha}", 2, [8, value, alpha, 0])
        add(f"gray-float-no-alpha-{value}-{alpha}", 2, [7, value, alpha, 0])
    rng = random.Random(0xd7b7ab0b)
    for index in range(1024):
        value = rng.getrandbits(64)
        add(f"packed-random-{index}", 0, [value, 0, 0, 0])
        add(f"constructors-random-{index}", 6, [value, 0, 0, 0])
        add(f"custom-dispatch-random-{index}", 9, [value, 0, 0, 0])
        add(f"packed-alias-random-{index}", 10, [value, 0, 0, 0])
        add(f"scale-random-{index}", 4, [value, rng.getrandbits(32), rng.getrandbits(64), 0])
        add(f"float-random-{index}", 1, [rng.getrandbits(32) for _ in range(4)])
        add(f"mixed-random-{index}", 8, [rng.getrandbits(8), rng.getrandbits(16), rng.getrandbits(64), rng.getrandbits(32)])
        for source in range(11):
            add(f"color-{source}-{index}", 3, [source, value, 0, 0])
    html = ['', '#', '123', '#12', '#12345', '#1234567', '#123456789', '#xyz', '#12G456', '#1234567z']
    html += ['#' + ''.join(digits) for digits in itertools.product('0fAa', repeat=3)]
    html += ['#' + ''.join(digits) for digits in itertools.product('0fAa', repeat=4)]
    html += ['#123456', '#aBcDeF', '#12345678', '#aBcDeF12']
    for index, (single, double) in enumerate(itertools.product(boundaries, doubles)):
        add(f"mixed-boundary-{index}", 8, [index % 256, (index * 257) % 65536, double, single])
    for index in range(256):
        html.append('#' + ''.join(rng.choice('0123456789abcdefABCDEFz- ') for _ in range(rng.choice([3, 4, 6, 8]))))
    for index, text in enumerate(html):
        add(f"html-{index}", 5, [text])
    return cases


def traps():
    cases = []
    for kind, value in [(3, 32), (4, 4), (5, 32), (6, 4)]:
        cases.append((f"packed-channel-range-{kind}", f"7|{kind}|{value}|0|0"))
    return cases


def compile_boundaries():
    return [
        ("missing-target-factory", "(color.Rgb24{}).to.color(struct {})", "_ = zigimg.Rgb24{}.to_color[NotColor]()"),
        ("missing-input-fields", "color.Rgb24.from.color(struct {}{})", "_ = zigimg.Rgb24.from_color(NotColor{})"),
        ("generic-float4-u32", "color.ScaleValue(u32)(@as(f32, 0.5))", "arr := [f32(0.5), 0, 0, 1]!\n_ = zigimg.color_from_float4[WideColor](arr)"),
        ("generic-color-u32", "color.ScaleValue(u32)(@as(f32, 0.5))", "_ = zigimg.color_from_color[WideColor, zigimg.Colorf32](zigimg.Colorf32{})"),
        ("generic-grayscale-u32", "color.ScaleValue(u32)(@as(f32, 0.5))", "_ = zigimg.color_from_grayscale[WideColor, zigimg.Grayscalef32](zigimg.Grayscalef32{})"),
        ("generic-premultiply-u32", "color.ScaleValue(u32)(@as(f32, 0.5))", "_ = zigimg.color_premultiplied_alpha(WideAlphaColor{})"),
        ("missing-target-fields", "(color.Rgb24{}).to.color(struct {})", "_ = zigimg.color_from_color[NotColor, zigimg.Rgb24](zigimg.Rgb24{})"),
        ("float32-usize-scale", "color.ScaleValue(usize)(@as(f32, 0.5))", "_ = zigimg.scale_value[usize, f32](f32(0.5))"),
        ("float64-usize-scale", "color.ScaleValue(usize)(@as(f64, 0.5))", "_ = zigimg.scale_value[usize, f64](f64(0.5))"),
        ("aliased-float32-u32-scale", "color.ScaleValue(u32)(@as(f32, 0.5))", "_ = zigimg.scale_value[AliasU32, AliasF32](AliasF32(0.5))"),
        ("float32-u32-scale", "color.ScaleValue(u32)(@as(f32, 0.5))", "_ = zigimg.scale_value[u32, f32](f32(0.5))"),
        ("float32-u64-scale", "color.ScaleValue(u64)(@as(f32, 0.5))", "_ = zigimg.scale_value[u64, f32](f32(0.5))"),
        ("float64-u64-scale", "color.ScaleValue(u64)(@as(f64, 0.5))", "_ = zigimg.scale_value[u64, f64](f64(0.5))"),
        ("rgb332-array", "color.Rgb332.from.array(.{0, 0, 0, 0})", "arr := [u8(0), 0, 0, 0]!\n_ = zigimg.color_from_array[zigimg.Rgb332, u8](arr)"),
        ("rgb565-array", "color.Rgb565.from.array(.{0, 0, 0, 0})", "arr := [u8(0), 0, 0, 0]!\n_ = zigimg.color_from_array[zigimg.Rgb565, u8](arr)"),
        ("rgb332-to-array", "(color.Rgb332{}).to.array()", "_ = zigimg.Rgb332{}.to_array()"),
        ("rgb565-to-array", "(color.Rgb565{}).to.array()", "_ = zigimg.Rgb565{}.to_array()"),
        ("rgb48-html", 'color.Rgb48.from.htmlHex("#123456")', "_ = zigimg.color_from_html_hex[zigimg.Rgb48]('#123456') or { panic(err) }"),
        ("float-html", 'color.Colorf32.from.htmlHex("#123456")', "_ = zigimg.color_from_html_hex[zigimg.Colorf32]('#123456') or { panic(err) }"),
        ("signed-input-scale", "color.ScaleValue(u8)(@as(i8, 1))", "_ = zigimg.scale_value[u8, i8](i8(1))"),
        ("signed-output-scale", "color.ScaleValue(i8)(@as(u8, 1))", "_ = zigimg.scale_value[i8, u8](u8(1))"),
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
    probe = Path(__file__).resolve().parent / "reference_probes/color_methods"
    module_root = probe.parents[2]
    cases = corpus()
    env = dict(os.environ, VEXE=str(args.v.resolve()), V_C_ERROR_BUG_REPORT_DISABLED="1")
    with tempfile.TemporaryDirectory(prefix="witty-color-methods-") as directory:
        root = Path(directory)
        shutil.copytree(source, root / "src")
        shutil.copyfile(probe / "reference.zig", root / "reference.zig")
        corpus_path = root / "corpus.txt"
        corpus_path.write_text("\n".join(case[1] for case in cases) + "\n")
        zig_command = [str(args.zig.resolve()), "build-exe", "-target", args.target, "-lc"]
        subprocess.run([*zig_command, f"-femit-bin={root / 'native'}", str(root / "reference.zig")], check=True)
        v_options = ["-prod"] if args.v_prod else []
        subprocess.run([str(args.v.resolve()), *v_options, "-o", str(root / "translated"), str(probe / "main.v")], env=env, check=True)
        outputs = [subprocess.run([str(root / executable), str(corpus_path)], capture_output=True,
                                  check=True, timeout=60).stdout.splitlines()
                   for executable in ("native", "translated")]
        if any(len(output) != len(cases) for output in outputs):
            raise AssertionError([len(cases)] + [len(output) for output in outputs])
        for (label, data), expected, actual in zip(cases, *outputs):
            if expected != actual:
                left, right = expected.split(b','), actual.split(b',')
                mismatches = [(index, e, a) for index, (e, a) in enumerate(zip(left, right)) if e != a]
                raise AssertionError(f"{label} ({data}): {mismatches[:8]}, lengths {len(left)}/{len(right)}")
        for label, case in traps():
            corpus_path.write_text(case + "\n")
            for executable in ("native", "translated"):
                result = subprocess.run([str(root / executable), str(corpus_path)], capture_output=True, timeout=10, preexec_fn=disable_core_dumps)
                if result.returncode == 0 or not any(marker in result.stderr for marker in (b"panic:", b"Assertion failed")):
                    raise AssertionError(f"{label}: {executable} did not produce a checked trap: {result.returncode}, {result.stdout!r}, {result.stderr[:300]!r}")
        for label, native_expression, translated_statements in compile_boundaries():
            native_path = root / f"{label}.zig"
            native_path.write_text('const color = @import("src/color.zig");\npub fn main() void { _ = ' + native_expression + '; }\n')
            translated_path = root / f"{label}.v"
            translated_path.write_text('module main\nimport zigimg\nstruct NotColor {}\ntype AliasU32 = u32\ntype AliasF32 = f32\nstruct WideColor {\npub mut:\n r u32\n g u32\n b u32\n}\nstruct WideAlphaColor {\npub mut:\n r u32\n g u32\n b u32\n a u8\n}\nfn main() {\n' + translated_statements + '\n}\n')
            commands = [
                [*zig_command, f"-femit-bin={root / 'boundary'}", str(native_path)],
                [str(args.v.resolve()), "-path", f"{module_root}|@vlib|@vmodules", "-o", str(root / "boundary"), str(translated_path)],
            ]
            for executable, command in zip(("native", "translated"), commands):
                result = subprocess.run(command, capture_output=True, env=env, timeout=60, preexec_fn=disable_core_dumps)
                diagnostics = result.stdout + result.stderr
                if result.returncode == 0 or b"error:" not in diagnostics or result.returncode < 0 or any(marker in diagnostics.lower() for marker in (b"segmentation fault", b"panic:", b"compiler bug", b"c error found")):
                    raise AssertionError(f"{label}: {executable} did not produce an ordinary compiler rejection: {result.returncode}, {diagnostics[:500]!r}")
        result_hash = hashlib.sha256(b"\n".join(outputs[0])).hexdigest()
        print(f"Color methods: {len(cases)} returning cases, {len(traps())} isolated traps, {len(compile_boundaries())} compile boundaries; SHA256 {result_hash}")


if __name__ == "__main__":
    main()
