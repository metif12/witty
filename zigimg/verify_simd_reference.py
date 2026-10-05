"""Compare the pinned SIMD lane helpers and image arithmetic guards."""
import argparse
import hashlib
import math
import os
from pathlib import Path
import random
import re
import resource
import shutil
import struct
import subprocess
import tempfile

from verify_png_foundation_reference import PINNED_SOURCE_SHA256

TYPES = {'u8': (1, False), 'i8': (1, True), 'u16': (2, False),
         'i16': (2, True), 'u32': (4, False), 'i32': (4, True),
         'u64': (8, False), 'i64': (8, True), 'usize': (8, False),
         'isize': (8, True), 'f32': (4, None), 'f64': (8, None)}
LANES = (1, 2, 4, 8, 16)
TRAPS = {name: 'index out of bounds' for name in
         ('load_short', 'bytes_short', 'store_short', 'int_source_short',
          'float_source_short', 'mask_negative', 'mask_high')}
TRAPS['bytes_remainder'] = 'exact division produced remainder'
TRAPS.update({name: 'integer part of floating point value out of bounds' for name in
              ('negative_unsigned', 'positive_unsigned', 'negative_signed',
               'positive_signed', 'infinity', 'negative_infinity')})
TRAPS.update({name: 'integer overflow' for name in
              ('box_x_add', 'box_y_add', 'box_x_sub', 'box_y_sub',
               'managed_create', 'unmanaged_create', 'managed_crop', 'unmanaged_crop')})
COMPILER_FAILURES = ('segmentation fault', 'segfault', 'bus error',
                     'illegal instruction', 'panic:', 'assertion failed',
                     'internal compiler error', 'compiler bug', 'please report this bug',
                     'c compilation failed', 'c compilation error', 'c error found',
                     'c compiler error', 'c backend failure', 'failed in the c backend',
                     'linker command failed', 'undefined reference')


def corpus():
    rng = random.Random(0xd7b7ab0b)
    rows = []
    for name, (width, signed) in TYPES.items():
        bits = width * 8
        patterns = [0, 1, (1 << bits) - 1, 1 << (bits - 1),
                    (1 << (bits - 1)) - 1, (1 << bits) - 2]
        if signed is None:
            patterns += ([0x3f800000, 0x80000000, 0x7f800000, 0xff800000,
                          0x7fc00000, 0x7f800001, 0xffc00000] if width == 4 else
                         [0x3ff0000000000000, 0x8000000000000000,
                          0x7ff0000000000000, 0xfff0000000000000,
                          0x7ff8000000000000, 0x7ff0000000000001,
                          0xfff8000000000000])
        for _ in range(24):
            patterns.append(rng.getrandbits(bits))
        for lanes in LANES:
            for index, pattern in enumerate(patterns):
                values = [pattern] * lanes if index < 6 else [pattern] + [rng.getrandbits(bits) for _ in range(lanes - 1)]
                source = b''.join(value.to_bytes(width, 'little') for value in values).hex()
                destination = bytes([0xa5]) * ((lanes + 2) * width)
                for length in range(lanes + 1):
                    rows += [f'L|{name}|{lanes}|{length}|{source}',
                             f'B|{name}|{lanes}|{length}|{source}',
                             f'S|{name}|{lanes}|{length}|{source}|{destination.hex()}']
                if signed is not None:
                    for target in ('f32', 'f64'):
                        rows.append(f'I|{target}|{lanes}|{name}|{source}')
    for target, (width, signed) in TYPES.items():
        if signed is None:
            continue
        lower = -(1 << (width * 8 - 1)) if signed else 0
        upper = 1 << (width * 8 - int(signed))
        for source in ('f32', 'f64'):
            fmt = '<f' if source == 'f32' else '<d'
            candidates = [0.0, -0.0, -0.9, 0.9, 1.9, float(lower),
                          float(lower) - 0.9, float(lower) + 0.9,
                          float(upper) - 1, float(upper) - 0.1]
            if source == 'f32':
                candidates += [struct.unpack('<f', struct.pack('<I',
                    struct.unpack('<I', struct.pack('<f', float(upper)))[0] - 1))[0]]
            else:
                candidates += [math.nextafter(float(upper), 0.0)]
            candidates += [rng.uniform(float(lower), float(upper)) for _ in range(32)]
            raw = []
            for value in candidates:
                packed = struct.pack(fmt, value)
                rounded = struct.unpack(fmt, packed)[0]
                if math.isfinite(rounded) and lower <= math.trunc(rounded) < upper:
                    raw.append(packed)
            raw += ([struct.pack('<I', value) for value in (0x7fc00000, 0x7f800001, 0xffc00000)]
                    if source == 'f32' else [struct.pack('<Q', value) for value in
                                           (0x7ff8000000000000, 0x7ff0000000000001, 0xfff8000000000000)])
            for lanes in LANES:
                for value in raw:
                    rows.append(f'F|{target}|{lanes}|{source}|{(value * lanes).hex()}')
    for _ in range(1024):
        value = b''.join(rng.getrandbits(32).to_bytes(4, 'little') for _ in range(8))
        mask = b''.join(rng.randrange(8).to_bytes(4, 'little') for _ in range(8))
        rows.append('P|' + value.hex() + '|' + mask.hex())
    # Actual V scalar aliases paired with unchanged Zig type aliases; these
    # additionally exercise the source's fixed-array form of load/store.
    for name in ('u16', 'i32', 'usize', 'f32', 'f64'):
        width, signed = TYPES[name]
        for index in range(32):
            source = rng.randbytes(width * 4).hex()
            destination = (b'\xa5' * (width * 6)).hex()
            for length in (0, 1, 2, 4):
                rows += [f'AL|{name}|4|{length}|{source}',
                         f'AB|{name}|4|{length}|{source}',
                         f'AS|{name}|4|{length}|{source}|{destination}']
            if signed is not None:
                for target in ('f32', 'f64'):
                    rows.append(f'AI|{target}|4|{name}|{source}')
    for target in ('u16', 'i32', 'usize'):
        for source in ('f32', 'f64'):
            raw = [struct.pack('<f' if source == 'f32' else '<d', value)
                   for value in (-0.9, 0.0, 1.9, 23.9, 255.9)]
            raw += ([struct.pack('<I', value) for value in (0x7fc00000, 0x7f800001)]
                    if source == 'f32' else [struct.pack('<Q', value) for value in
                                           (0x7ff8000000000000, 0x7ff0000000000001)])
            for value in raw:
                rows.append(f'AF|{target}|4|{source}|{(value * 4).hex()}')
    for width in (0, 1, 8, 31):
        for height in (0, 1, 9):
            for x in range(width + 1):
                for y in (0, height):
                    for box_width, box_height in ((0, 0), (1, 1), (width + 1, height + 1)):
                        rows.append(f'C|{width}|{height}|{x}|{y}|{box_width}|{box_height}')
    maximum = (1 << 64) - 1
    for mode in ('managed', 'unmanaged'):
        for width, height in ((maximum, 0), (0, maximum), (maximum, 1), (1, maximum), (0, 0)):
            rows.append(f'Z|{mode}|{width}|{height}')
    rows.append('H|' + struct.pack('<6H', 1, 2, 3, 4, 5, 6).hex())
    # Source anytype accepts pointers to arrays, native vectors, and many-item
    # scalar pointers. V uses fixed-array pointers for both lane containers.
    pointer_rows = [row for row in rows if row.startswith(('I|', 'F|')) and row.split('|')[2] == '4']
    rows += [kind + row for row in pointer_rows for kind in ('Q', 'V', 'M')]
    for destination, source in (('u16','u8'), ('i16','u8'), ('u32','u16'), ('i32','u16'),
                                ('u64','u32'), ('i64','u32'), ('i16','i8'), ('i32','i16'),
                                ('i64','i32'), ('f64','f32')):
        width = TYPES[source][0]
        for _ in range(12):
            data = rng.randbytes(width * 4).hex()
            rows += [f'WL|{destination}|4|{source}|{data}',
                     f'WS|{destination}|4|{source}|{data}']
    rows += ['A' + row for row in rows if row.startswith(('WL|', 'WS|'))]
    rows += [kind + row for row in pointer_rows for kind in ('N', 'X')]
    for _ in range(32):
        for length in (0, 1, 2, 4):
            flags = bytes(rng.getrandbits(1) for _ in range(4))
            items = b''.join(struct.pack('<HI', rng.getrandbits(16), rng.getrandbits(32)) for _ in range(4))
            rows += [f'OB|{length}|{flags.hex()}', f'OS|{length}|{items.hex()}']
    return rows


def diagnostic(result):
    return '\n'.join(stream.decode(errors='replace') for stream in (result.stdout, result.stderr))


def unexpected(text):
    return any(line.lstrip().startswith('UNEXPECTED') for line in text.splitlines())


def checked_trap(result, label, category):
    text = diagnostic(result)
    messages = [match.group(1) for line in text.splitlines()
                if (match := re.match(r'^(?:thread \d+ |V )?panic:\s*(.*)$', line.strip()))]
    if result.returncode == 0 or unexpected(text) or not any(message.startswith(category) for message in messages):
        raise AssertionError(f'{label} expected {category}: {result.returncode}\n{text}')


def ordinary_rejection(result, label):
    text = diagnostic(result)
    if (result.returncode <= 0 or 'error:' not in text or unexpected(text)
            or any(marker in text.lower() for marker in COMPILER_FAILURES)):
        raise AssertionError(f'{label} expected ordinary rejection: {result.returncode}\n{text}')


def run(command, **kwargs):
    result = subprocess.run(command, capture_output=True, **kwargs)
    if result.returncode:
        raise AssertionError(f'command failed: {command}\n{diagnostic(result)}')
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('zig', type=Path)
    parser.add_argument('v', type=Path)
    parser.add_argument('--v-prod', action='store_true')
    parser.add_argument('--zig-mode', choices=['Debug', 'ReleaseSafe'])
    parser.add_argument('--v-root', type=Path, help=argparse.SUPPRESS)
    parser.add_argument('--keep', type=Path, help=argparse.SUPPRESS)
    args = parser.parse_args()
    args.zig_mode = args.zig_mode or ('ReleaseSafe' if args.v_prod else 'Debug')
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
    source = args.source.resolve() / 'src'
    digest = hashlib.sha256()
    for path in sorted(source.rglob('*')):
        if path.is_file():
            digest.update(path.relative_to(source).as_posix().encode() + b'\0')
            digest.update(path.read_bytes())
    if digest.hexdigest() != PINNED_SOURCE_SHA256:
        parser.error('src differs from pinned zigimg')
    repo = Path(__file__).resolve().parent.parent
    probe = repo / 'zigimg/reference_probes/simd'
    environment = dict(os.environ, VEXE=str(args.v.resolve()), V_C_ERROR_BUG_REPORT_DISABLED='1')
    with tempfile.TemporaryDirectory(prefix='witty-simd-') as directory:
        root = Path(directory)
        shutil.copytree(source, root / 'src')
        shutil.copyfile(probe / 'reference.zig', root / 'reference.zig')
        zargs = [str(args.zig.resolve()), 'build-exe', '-target', 'aarch64-macos.14.0', '-lc', '-O', args.zig_mode]
        vargs = [str(args.v.resolve()), *(['-prod'] if args.v_prod else []), '-path',
                 f'{(args.v_root or repo).resolve()}|{repo}|@vlib|@vmodules']
        run([*zargs, f'-femit-bin={root / "native"}', str(root / 'reference.zig')])
        run([*vargs, '-o', str(root / 'translated'), str(probe / 'main.v')], env=environment)
        rows = corpus()
        path = root / 'corpus.txt'
        path.write_text('\n'.join(rows) + '\n')
        outputs = [run([str(root / executable), str(path)], timeout=180).stdout.splitlines()
                   for executable in ('native', 'translated')]
        if any(len(output) != len(rows) for output in outputs):
            raise AssertionError([len(rows)] + [len(output) for output in outputs])
        for index, (expected, actual) in enumerate(zip(*outputs)):
            if expected != actual:
                raise AssertionError(f'row {index}: {rows[index]}\nsource={expected!r}\nV={actual!r}')
        for name, category in TRAPS.items():
            for executable in ('native', 'translated'):
                result = subprocess.run([str(root / executable), 'trap:' + name], capture_output=True, timeout=15)
                checked_trap(result, executable + ' ' + name, category)
        for fixture in sorted((probe / 'contracts').glob('*.zig')):
            shutil.copyfile(fixture, root / fixture.name)
            ordinary_rejection(subprocess.run([*zargs, '-fno-emit-bin', str(root / fixture.name)], capture_output=True), fixture.name)
            ordinary_rejection(subprocess.run([*vargs, '-check', str(fixture.with_suffix('.v'))], capture_output=True, env=environment), fixture.with_suffix('.v').name)
        shutil.copyfile(probe / 'store_prefix.zig', root / 'store_prefix.zig')
        run([*zargs, f'-femit-bin={root / "native_prefix"}', str(root / 'store_prefix.zig')])
        run([*vargs, '-o', str(root / 'translated_prefix'), str(probe / 'store_prefix.v')], env=environment)
        for executable in ('native_prefix', 'translated_prefix'):
            result = subprocess.run([str(root / executable)], capture_output=True, timeout=15)
            checked_trap(result, executable, 'index out of bounds')
            if result.stdout != b'TRACE:0001,0002,0009,0009\n':
                raise AssertionError(f'{executable} store prefix differs: {result.stdout!r}')
        # Source's excessive comptime length rejects; V's length adapter is
        # deliberately runtime-checked. Zero-length source arrays have no V type.
        for name in ('length_excess', 'zero_array'):
            shutil.copyfile(probe / (name + '.zig'), root / (name + '.zig'))
        ordinary_rejection(subprocess.run([*zargs, '-fno-emit-bin', str(root / 'length_excess.zig')], capture_output=True), 'source excessive comptime length')
        result = subprocess.run([str(root / 'translated'), 'trap:length_excess'], capture_output=True, timeout=15)
        checked_trap(result, 'V excessive runtime length', 'index out of bounds')
        run([*zargs, f'-femit-bin={root / "zero_array"}', str(root / 'zero_array.zig')])
        run([str(root / 'zero_array')])
        ordinary_rejection(subprocess.run([*vargs, '-check', str(probe / 'zero_array.v')], capture_output=True, env=environment), 'V zero-length lane array')
        # Native vectors and source arrays differ for overlapping stores;
        # the V fixed-array carrier follows the array form (the H record).
        shutil.copyfile(probe / 'store_alias.zig', root / 'store_alias.zig')
        run([*zargs, f'-femit-bin={root / "store_alias"}', str(root / 'store_alias.zig')])
        for mode, expected in (('a', b'1,1,1,1,1,6,\n'),
                               ('l', b'1,1,1,1,1,6,\n'),
                               ('v', b'1,1,2,3,4,6,\n'),
                               ('w', b'1,1,2,3,4,6,\n')):
            if run([str(root / 'store_alias'), mode]).stdout != expected:
                raise AssertionError('source array/vector overlap boundary changed: ' + mode)
        # Pinned V's nominal alias constructor for pointers to fixed arrays
        # emits an uninitialized-pointer memcpy. Inspect generated C, avoiding
        # execution of that undefined construction. Returning pointer records
        # use typed pointer-bit views to exercise valid aliased pointer values.
        shutil.copyfile(probe / 'pointer_alias_constructor.zig', root / 'pointer_alias_constructor.zig')
        run([*zargs, f'-femit-bin={root / "pointer_alias_constructor"}', str(root / 'pointer_alias_constructor.zig')])
        run([str(root / 'pointer_alias_constructor')])
        constructor_c = root / 'pointer_alias_constructor.c'
        run([*vargs, '-o', str(constructor_c), str(probe / 'pointer_alias_constructor.v')], env=environment)
        generated = constructor_c.read_text()
        if (not re.search(r'^\s*(?:main__Pointer|main__Words\*) aliased_pointer;\s*$', generated, re.MULTILINE)
                or not re.search(r'\bmemcpy\(aliased_pointer,\s*&words,\s*sizeof\(main__Pointer\)\)', generated)):
            raise AssertionError('pinned V pointer-alias constructor boundary changed')
        digest = hashlib.sha256(b'\n'.join(outputs[0]) + b'\n').hexdigest()
        print(f'{len(rows)} returning records, {len(TRAPS)} strict trap pairs, '
              f'{len(list((probe / "contracts").glob("*.zig")))} ordinary compile pairs, '
              f'one panic-visible store prefix pair and four measured language/representation/compiler boundaries; sha256={digest}')
        if args.keep:
            if args.keep.exists():
                shutil.rmtree(args.keep)
            shutil.copytree(root, args.keep)


if __name__ == '__main__':
    main()
