"""Compare BMP checked arithmetic, memory codecs and retained public failure state."""
import argparse
from collections import Counter
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import struct

from verify_jpeg_contracts_reference import implementation_hashes
from verify_tga_decode_reference import stdlib_hash, PINNED_STDLIB_SHA256
from verify_tiff_decode_reference import ProofLog, tree_hash, work_directory, PINNED_SOURCE_SHA256, checked_trap

EXPECTED_ROWS = 10684
EXPECTED_READ_ROWS = 654
EXPECTED_CONTROLS = 40
EXPECTED_TRAPS = 152
EXPECTED_SHA256 = '9b413f62c620cdc82ad314065a403fde50455c7eb04bde405c3c0953aff8e064'
EXPECTED_READ_SHA256 = '2d19b419f20e31609996f7887a5fd9258e4036c2d5fe2172a728a2d7da9c406d'
EXPECTED_STATE_SHA256 = '59aacb757a0572b8742e645599d049965f7df9d2c7715abd1e075bb371510d89'
BGR24, BGRA32, GRAY8 = 0x1308, 0x1408, 0x108
MAX = (1 << 64) - 1


def header(kind=108, width=1, height=1, bits=24, compression=None, magic=b'BM'):
    data = bytearray(kind)
    struct.pack_into('<IiiHH6I', data, 0, kind, width, height, 17, bits,
                     (3 if bits == 32 else 0) if compression is None else compression, 99, 11, 12, 13, 14)
    if kind >= 108:
        struct.pack_into('<4I', data, 40, 0x10203040, 0x50607080, 0x90abcdef, 0xdeadbeef)
        struct.pack_into('<I', data, 56, 0x73524742)
        struct.pack_into('<12I', data, 60, *range(1, 13))
    if kind == 124:
        struct.pack_into('<4I', data, 108, 8, 123, 456, 789)
    return struct.pack('<2sIII', magic, 1, 0x12345678, 9000) + data


def read_cases():
    cases = []
    for kind in (108, 124):
        for bits in (24, 32):
            for width in (0, 1, 2, 3, 8):
                for height in range(4):
                    for seed in range(3):
                        raw = bytes((i * 31 + seed * 61) & 255 for i in range(width * height * (bits // 8)))
                        data = header(kind, width, height, bits) + raw + b'\x11\x22'
                        for op in ('--read', '--read-image'):
                            cases.append((f'valid-{kind}-{bits}-{width}-{height}-{seed}-{op}', data, op))
            baseline = header(kind, 1, 2, bits) + bytes(range(2 * (bits // 8)))
            cuts = sorted({0, 1, 13, 14, 15, 17, 18, 53, 14 + kind - 1, 14 + kind,
                           14 + kind + bits // 8 - 1, 14 + kind + bits // 8, len(baseline) - 1})
            for length in cuts:
                for op in ('--read', '--read-image'):
                    cases.append((f'truncated-{kind}-{bits}-{length}-{op}', baseline[:length], op))
            for width, height in ((-1, -2), (-2, -1), (-3, 0), (0, -3), (-2147483648, 0), (0, -2147483647)):
                # Source may allocate unwritten pixels. Observe only public lengths/header/cursor.
                cases.append((f'negative-meta-{kind}-{bits}-{width}-{height}', header(kind, width, height, bits), '--read'))
            for name, data in (
                ('bad-magic', header(kind, 2147483647, 2, bits, magic=b'XY')),
                ('unsupported-bits', header(kind, 2147483647, 2, 16)),
                ('unsupported-method', header(kind, 2147483647, 2, bits, 3 if bits == 24 else 0)),
            ):
                for op in ('--read', '--read-image'):
                    cases.append((f'{name}-{kind}-{bits}-{op}', data, op))
    for size in (0, 1, 39, 41, 107, 109, 123, 125, 0xffffffff):
        data = struct.pack('<2sIIII', b'BM', 1, 2, 3, size)
        for op in ('--read', '--read-image'):
            cases.append((f'unsupported-size-{size}-{op}', data, op))
    for bits in (24, 32):
        for op in ('--read', '--read-image'):
            cases.append((f'windows31-{bits}-{op}', header(40, 2147483647, 2, bits), op))
    return cases


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path); parser.add_argument('zig', type=Path); parser.add_argument('v', type=Path)
    parser.add_argument('--target', default='aarch64-macos.14.0'); parser.add_argument('--v-prod', action='store_true')
    parser.add_argument('--workdir', type=Path); parser.add_argument('--timeout', type=int, default=180)
    args = parser.parse_args()
    if args.timeout <= 0: parser.error('--timeout must be positive')
    source = args.source.resolve() / 'src'; zig = args.zig.resolve(); v = args.v.resolve()
    if tree_hash(source) != PINNED_SOURCE_SHA256 or stdlib_hash(zig) != PINNED_STDLIB_SHA256:
        parser.error('Source or selected library differs from pins')
    repo = Path(__file__).resolve().parent.parent; probe = repo / 'zigimg/reference_probes/bmp_contracts'
    mode = 'ReleaseSafe' if args.v_prod else 'Debug'
    env = dict(os.environ, VEXE=str(v), V_C_ERROR_BUG_REPORT_DISABLED='1')
    with work_directory(args.workdir, 'witty-bmp-contracts-') as root:
        proof = ProofLog(root); shutil.copytree(source, root / 'src'); fixtures = {}
        for name in ('main.v', 'reference.zig'):
            shutil.copyfile(probe / name, root / name)
            fixtures[name] = hashlib.sha256((root / name).read_bytes()).hexdigest()
        versions = [proof.run([str(exe), 'version'], label, env=env).stdout.decode().strip()
                    for exe, label in ((zig, 'zig-version'), (v, 'v-version'))]
        if versions[0] != '0.15.2' or not re.match(r'^V 0\.5\.2(?: |$)', versions[1]):
            raise AssertionError('unexpected compiler versions')
        implementations = implementation_hashes(repo); runner_hash = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
        (root / 'provenance.json').write_text(json.dumps(dict(source_sha256=PINNED_SOURCE_SHA256, stdlib_sha256=PINNED_STDLIB_SHA256,
            versions=versions, target=args.target, zig_mode=mode, v_prod=args.v_prod, fixtures=fixtures,
            implementation_sha256=implementations, runner_sha256=runner_hash), indent=2) + '\n')
        zbase = [str(zig), 'build-exe', '-target', args.target, '-lc', '-O', mode, '--global-cache-dir', str(root / 'zig-global')]
        vbase = [str(v), '-enable-globals', *(['-prod'] if args.v_prod else []), '-path', f'{repo}|@vlib|@vmodules']
        print(f'Building BMP contracts: Source {mode}, V {"production" if args.v_prod else "ordinary"}', flush=True)
        proof.run(zbase + ['-femit-bin=' + str(root / 'native'), str(root / 'reference.zig')], 'build-source', timeout=args.timeout)
        proof.run(vbase + ['-o', str(root / 'translated'), str(root / 'main.v')], 'build-v', env=env, timeout=args.timeout)
        outputs = []
        for exe in ('native', 'translated'):
            result = proof.run([str(root / exe)], 'returning-' + exe, timeout=args.timeout)
            if result.stderr: raise AssertionError('unexpected returning stderr')
            outputs.append(result.stdout.splitlines())
        if len(outputs[0]) != len(outputs[1]): raise AssertionError(f'row counts differ: {[len(x) for x in outputs]}')
        for index, (native, translated) in enumerate(zip(*outputs)):
            if native != translated: raise AssertionError(f'{index}: Source={native!r}, V={translated!r}')
        if len(outputs[0]) != EXPECTED_ROWS: raise AssertionError(f'expected {EXPECTED_ROWS}, got {len(outputs[0])}')
        digest = hashlib.sha256(b'\n'.join(outputs[0])).hexdigest()
        if digest != EXPECTED_SHA256: raise AssertionError('returning golden changed')
        groups = Counter(row[:1].decode() for row in outputs[0]); reads = hashlib.sha256(); read_count = 0
        def returning(name, arguments, expected_prefix=None):
            results = []
            for exe in ('native', 'translated'):
                result = proof.run([str(root / exe), arguments[0], '-', *map(str, arguments[1:])], name + '-' + exe, timeout=args.timeout)
                if result.stderr or len(result.stdout.splitlines()) != 1: raise AssertionError('invalid returning control')
                results.append(result.stdout)
            if results[0] != results[1]: raise AssertionError(f'{name}: differing return {results}')
            if expected_prefix is not None and not results[0].startswith(expected_prefix): raise AssertionError('wrong control status')
            reads.update(name.encode() + b'\0' + results[0])
        for name, data, op in read_cases():
            file = root / (name + '.bmp'); file.write_bytes(data); returning(name, [op, file]); read_count += 1
        controls = 0
        for format in (BGR24, BGRA32):
            returning(f'max-width-zero-height-{format}', ['--image', 256, 2147483647, 0, format, 0], b'ok|'); controls += 1
            for width, height in ((-2147483648, 1), (-1, 2), (1, -2147483647), (-1, -2)):
                for kind in (108, 124):
                    returning(f'direct-negative-{kind}-{format}-{width}-{height}', ['--direct', 256, width, height, format, 0, kind], b'ok|'); controls += 1
            for kind in (108, 124):
                for cap in (0, 13, 14, kind + 13):
                    returning(f'write-first-{kind}-{format}-{cap}', ['--direct', cap, 0, -2147483648, format, 0, kind], b'WriteFailed|'); controls += 1
                returning(f'unsupported-before-height-{kind}-{format}', ['--direct', 256, 0, -2147483648, GRAY8, 0, kind], b'InvalidData|'); controls += 1
        returning('unsupported-before-size', ['--image', 256, MAX, 2, GRAY8, 0], b'InvalidData|0|'); controls += 1
        returning('windows31-before-height', ['--direct', 256, 0, -2147483648, BGR24, 0, 40], b'InvalidData|14|'); controls += 1
        read_digest = reads.hexdigest()
        if read_count != EXPECTED_READ_ROWS or controls != EXPECTED_CONTROLS: raise AssertionError('read/control counts changed')
        if read_digest != EXPECTED_READ_SHA256: raise AssertionError('read/control golden changed')
        print(f'{EXPECTED_ROWS} main rows and {read_count} decoder cases match; checking strict state', flush=True)
        states = hashlib.sha256(); traps = Counter()
        def trap(group, name, arguments, category):
            observed = []
            for exe in ('native', 'translated'):
                path = root / (name + '-' + exe + '.state')
                result = proof.run([str(root / exe), arguments[0], str(path), *map(str, arguments[1:])], name + '-' + exe, timeout=args.timeout, check=False)
                checked_trap(result, name + '/' + exe, category)
                if not path.exists(): raise AssertionError('missing panic observer')
                observed.append(path.read_bytes())
            if not observed[0] or observed[0] != observed[1]: raise AssertionError(f'{name}: states differ {observed}')
            states.update(name.encode() + b'\0' + observed[0] + b'\n'); traps[group] += 1
        for kind in (108, 124):
            for bits, format in ((24, BGR24), (32, BGRA32)):
                for width, height in ((46341, 46341), (2147483647, 2), (-2147483648, -1), (-2147483648, 2)):
                    name = f'read-product-{kind}-{bits}-{width}-{height}'
                    file = root / (name + '.bmp'); file.write_bytes(header(kind, width, height, bits))
                    trap('read-product', name, ['--read', file], 'integer overflow')
                for width, height in ((-1, 1), (1, -1), (-2147483648, 1), (1, -2147483647)):
                    name = f'read-count-{kind}-{bits}-{width}-{height}'
                    file = root / (name + '.bmp'); file.write_bytes(header(kind, width, height, bits))
                    trap('read-count', name, ['--read', file], 'integer does not fit in destination type')
                file = root / (f'read-height-{kind}-{bits}.bmp'); file.write_bytes(header(kind, 0, -2147483648, bits))
                trap('read-height', f'read-height-{kind}-{bits}', ['--read', file], 'integer overflow')
                for width, height in ((-1, -2), (-2, -1), (-3, 0), (0, -3), (-2147483648, 0), (0, -2147483647)):
                    name = f'image-read-cast-{kind}-{bits}-{width}-{height}'
                    file = root / (name + '.bmp'); file.write_bytes(header(kind, width, height, bits))
                    trap('read-image-cast', name, ['--read-image', file], 'integer does not fit in destination type')
                trap('direct-height', f'direct-height-{kind}-{format}', ['--direct', 256, 0, -2147483648, format, 0, kind], 'integer overflow')
                for width in (1073741824, -1073741825):
                    trap('direct-product', f'direct-product-{kind}-{format}-{width}', ['--direct', 256, width, 3, format, 0, kind], 'integer overflow')
                for width, height in ((1, 1), (2, 2), (3, 2), (4, 1), (1073741824, 2)):
                    for length in (0, 1, 3, 4):
                        if length >= width * height: continue
                        index = (height - 1) * width
                        if length > index: index = length
                        trap('direct-bounds', f'direct-bounds-{kind}-{format}-{width}-{height}-{length}',
                             ['--direct', 1024, width, height, format, length, kind], f'index out of bounds: index {index}, len {length}')
        for format, channels, header_size in ((BGR24, 3, 122), (BGRA32, 4, 138)):
            for name, width, height, category in (
                ('pixel-product', MAX, 2, 'integer overflow'),
                ('byte-product', MAX // channels + 1, 1, 'integer overflow'),
                ('header-sum', MAX // channels, 1, 'integer overflow'),
                ('file-cast', ((1 << 32) - 1 - header_size) // channels + 1, 1, 'integer does not fit in destination type'),
                ('width-cast', 1 << 31, 0, 'integer does not fit in destination type'),
                ('height-cast', 0, 1 << 31, 'integer does not fit in destination type'),
                ('wide-width-cast', 1 << 32, 0, 'integer does not fit in destination type'),
                ('max-width-cast', MAX, 0, 'integer does not fit in destination type'),
            ):
                trap('write-' + name, f'{name}-{format}', ['--image', 256, width, height, format, 4], category)
            width = ((1 << 32) - 1 - header_size) // channels
            trap('write-file-boundary', f'file-boundary-{format}', ['--image', 256, width, 1, format, 0], 'index out of bounds: index 0, len 0')
            trap('write-bounds', f'image-bounds-{format}', ['--image', 256, 4, 1, format, 3], 'index out of bounds: index 3, len 3')
        state_digest = states.hexdigest()
        if sum(traps.values()) != EXPECTED_TRAPS: raise AssertionError('trap count changed')
        if state_digest != EXPECTED_STATE_SHA256: raise AssertionError('failure-state golden changed')
        if (tree_hash(source) != PINNED_SOURCE_SHA256 or tree_hash(root / 'src') != PINNED_SOURCE_SHA256
                or stdlib_hash(zig) != PINNED_STDLIB_SHA256 or implementation_hashes(repo) != implementations
                or hashlib.sha256(Path(__file__).read_bytes()).hexdigest() != runner_hash): raise AssertionError('dependency, implementation or runner changed')
        for name, expected in fixtures.items():
            if any(hashlib.sha256((base / name).read_bytes()).hexdigest() != expected for base in (root, probe)): raise AssertionError('fixture changed')
        summary = dict(returning_records=EXPECTED_ROWS, groups=dict(groups), output_sha256=digest, decoder_records=read_count,
            return_controls=controls, read_control_sha256=read_digest, paired_traps=sum(traps.values()), failure_groups=dict(traps),
            state_sha256=state_digest, zig_mode=mode, v_prod=args.v_prod)
        (root / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n'); print(json.dumps(summary), flush=True)


if __name__ == '__main__': main()
