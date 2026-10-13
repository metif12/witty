"""Compare JPEG retained tables, frames, pixels and retry state with Source."""
import argparse
from collections import Counter
import hashlib
import itertools
import json
import os
from pathlib import Path
import re
import shutil
import struct

from verify_jpeg_contracts_reference import (
    baseline, frame_header, implementation_hashes, PINNED_STDLIB_SHA256,
    segment, stdlib_hash,
)
from verify_png_header_reference import checked_trap
from verify_tiff_decode_reference import (
    PINNED_SOURCE_SHA256, ProofLog, tree_hash, work_directory,
)

EXPECTED_ROWS = 6138
EXPECTED_SHA256 = '846e18ebd6cccfb3d5d01147a2b2bede3041669033b573d02cec62de14fb3b76'
EXPECTED_STATE_SHA256 = '5c752672755ff2581f89c69aa911b00cd30cb1eabfc8d532ebd1242f54c08060'
SOI = b'\xff\xd8'
EOI = b'\xff\xd9'


def quant(slot=0, precision=0, value=1, size=None):
    payload = (bytes((precision * 16 + slot,))
               + (bytes((i * 37 + value) & 255 for i in range(64)) if precision == 0
                  else b''.join(struct.pack('>H', (i * 257 + value) & 65535) for i in range(64))))
    return segment(0xffdb, payload, size)


def huffman(slot=0, cls=0, symbol=7, size=None):
    return segment(0xffc4, bytes((cls * 16 + slot, 1)) + b'\0' * 15 + bytes((symbol,)), size)


def row(*stages, frame=1, components=1, width=8, height=8, seed=0,
        qmode=1, qvalue=1, pixels=2, pixel_count=None, restart=0, tables=255,
        reset=0, buffer=0):
    if pixel_count is None:
        pixel_count = width * height
    return '|'.join(map(str, (','.join(data.hex() for data in stages), frame, components,
                              width, height, seed, qmode, qvalue, pixels, pixel_count,
                              restart, tables, reset, buffer)))


def corpus():
    groups = []
    def add(group, *stages, buffers=(0, 16, 31), **kwargs):
        for buffer in buffers:
            groups.append((group, row(*stages, buffer=buffer, **kwargs)))
    for components, (width, height), seed, value, tables in itertools.product(
            (1, 3), ((0, 0), (1, 1), (8, 8), (9, 9), (17, 9)), (0, 8, 64), (0, 1, 7, 255), (0, 255)):
        add('stored-success', SOI + EOI, components=components, width=width, height=height,
            seed=seed, qvalue=value, pixels=2 if components == 1 else 3, tables=tables)
    failures = (b'', b'\0', b'\0\0', SOI, SOI + b'\xff', SOI + b'\xff\xc1',
                SOI + b'\xff\xc0', SOI + b'\xff\xcc', SOI + b'\xff\xdc',
                SOI + b'\xff\xda\0\x08\0', SOI + quant()[:-1], SOI + huffman()[:-1],
                SOI + segment(0xffdb, b'\x20'), SOI + segment(0xffc4, b'\x20'))
    for data, qmode, kind, tables in itertools.product(failures, (0, 1, 2), range(4), (0, 255)):
        add('recoverable-state', data, qmode=qmode, pixels=kind, tables=tables, restart=17)
    for qmode, kind, components in itertools.product((0, 2), range(4), (1, 3)):
        if qmode == 2:
            # Empty storage avoids Source's inactive-q8 access.
            if kind == (2 if components == 1 else 3):
                add('empty-q16', SOI + EOI, qmode=qmode, pixels=kind, components=components,
                    width=0, height=0)
        else:
            add('missing-quantization', SOI + EOI, qmode=0, pixels=kind, components=components)
    for slot, value in itertools.product(range(4), (0, 1, 255)):
        data = SOI + quant(slot, value=value) + b'\xff\xcc'
        add('quantization-install', data, seed=8)
        for cut in range(len(quant(slot, value=value)) + 1):
            add('quantization-truncation', (SOI + quant(slot, value=value))[:2 + cut],
                seed=8, buffers=(0, 16))
    for slot, value in itertools.product(range(4), (0, 1, 65535)):
        data = quant(slot, precision=1, value=value)
        for cut in (0, 1, 2, 3, 4, 5, 64, 65, 127, 128, 129, 130, 131, 132, 133):
            add('quantization16-install', SOI + data[:cut], seed=8)
    for slot, cls, symbol in itertools.product(range(4), range(2), (0, 1, 42, 255)):
        data = huffman(slot, cls, symbol)
        for cut in range(len(data) + 1):
            add('huffman-install-truncation', SOI + data[:cut], seed=8, buffers=(0, 16))
    for kind, slot in itertools.product(range(4), range(4)):
        if kind < 2:
            marker = 0xffdb
            first = quant(slot, precision=kind, value=7)[4:]
            second = quant((slot + 1) % 4, precision=kind, value=13)[4:]
        else:
            marker = 0xffc4
            first = huffman(slot, kind - 2, 7)[4:]
            second = huffman((slot + 1) % 4, kind - 2, 13)[4:]
        for cut in (0, 1, len(second) // 2, len(second) - 1, len(second)):
            add('multi-table-partial-install',
                SOI + segment(marker, first + second[:cut], 2 + len(first) + len(second)),
                buffers=(0, 16))
    for restart, trailer in itertools.product((0, 1, 17, 65535), (EOI, b'', b'\xff\xcc')):
        add('restart-retention', SOI + segment(0xffdd, struct.pack('>H', restart)) + trailer,
            seed=8, restart=9)
    for marker, size, available in itertools.product((0xffe0, 0xffef, 0xfffe), (2, 3, 16, 65535), (0, 1, 8)):
        payload = bytearray(available)
        remaining = available - (size - 2)
        if remaining >= 2:
            payload[size - 2:size] = EOI
        add('skip-position', SOI + segment(marker, payload, size), seed=8)
    for first, second, reset, components in itertools.product(
            (SOI + EOI, SOI + b'\xff\xcc', SOI + quant(1, value=7) + b'\xff\xcc',
             SOI + huffman(1, 1, 7) + b'\xff\xcc', SOI + segment(0xffdd, b'\0\x11') + b'\xff\xcc'),
            (SOI + b'\xff\xc0', SOI + b'\xff\xc1', SOI + b'\xff\xcc'), (0, 1), (1, 3)):
        stages = (first, second, SOI + EOI) if reset else (first, second)
        add('read-retry', *stages, components=components, seed=8, reset=reset,
            pixels=2 if components == 1 else 3)
    for kind, qmode, data in itertools.product(range(4), (0, 1),
            (SOI + EOI, SOI + b'\xff\xc1', SOI + b'\xff\xcc',
             SOI + b'\xff\xc0' + frame_header(), SOI + quant(0) + EOI,
             baseline(width=1, height=1), baseline(width=8, height=8))):
        add('fresh-record', data, frame=0, pixels=kind, qmode=qmode)
    return groups


def traps():
    cases = {}
    def add(name, data, category, **kwargs):
        for buffer in (0, 16):
            cases[f'{name}-{buffer}'] = (row(data, buffer=buffer, **kwargs), category)
    for components, (width, height), seed in itertools.product((1, 3), ((0, 0), (8, 8), (9, 9)), (0, 64)):
        add(f'null-pixels-{components}-{width}-{height}-{seed}', SOI + EOI,
            'attempt to use null value', components=components, width=width, height=height,
            seed=seed, pixels=0)
    add('gray-wrong-arm', SOI + EOI, "access of union field 'grayscale8' while field 'invalid' is active", pixels=1)
    add('rgb-wrong-arm', SOI + EOI, "access of union field 'rgb24' while field 'grayscale8' is active", components=3)
    add('gray-short', SOI + EOI, 'index out of bounds: index 1, len 1', pixel_count=1, seed=64)
    add('rgb-short', SOI + EOI, 'index out of bounds: index 1, len 1', components=3, pixels=3, pixel_count=1, seed=64)
    add('component-count', SOI + EOI, 'reached unreachable code', components=2, pixels=1)
    add('null-before-component-count', SOI + EOI, 'attempt to use null value', components=2, pixels=0)
    add('q16-before-null', SOI + EOI, "access of union field 'q8' while field 'q16' is active", qmode=2, pixels=0)
    add('quant-overflow-before-null', SOI + EOI, 'integer overflow', seed=2147483647, qvalue=2, pixels=0)
    add('idct-overflow-before-null', SOI + EOI, 'integer overflow', seed=2147483647, pixels=0)
    add('unknown-marker', SOI + b'\xff\x00', 'invalid enum value', seed=64)
    add('unknown-after-skip', SOI + segment(0xffe0, b'\0\0', 2), 'invalid enum value', seed=64)
    add('q8-underflow-before-install', SOI + quant(1, value=7, size=66), 'integer overflow')
    add('q16-underflow-before-install', SOI + quant(1, precision=1, value=7, size=130), 'integer overflow')
    add('huffman-underflow-after-install', SOI + huffman(1, 1, 7, size=19), 'integer overflow')
    add('huffman-bounds-after-read', SOI + huffman(4, 0, 7), 'index out of bounds: index 4, len 4')
    for size in (0, 3, 5):
        add(f'restart-length-{size}', SOI + segment(0xffdd, b'\0\x11', size),
            'integer overflow' if size < 4 else 'reached unreachable code', restart=9)
    return cases


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('zig', type=Path)
    parser.add_argument('v', type=Path)
    parser.add_argument('--workdir', type=Path)
    parser.add_argument('--target', default='aarch64-macos.14.0')
    parser.add_argument('--v-prod', action='store_true')
    parser.add_argument('--timeout', type=int, default=180)
    args = parser.parse_args()
    if args.timeout <= 0:
        parser.error('--timeout must be positive')
    source, zig, v = args.source.resolve() / 'src', args.zig.resolve(), args.v.resolve()
    if tree_hash(source) != PINNED_SOURCE_SHA256 or stdlib_hash(zig) != PINNED_STDLIB_SHA256:
        parser.error('Source or compiler library differs from pins')
    repo = Path(__file__).resolve().parent.parent
    probe = repo / 'zigimg/reference_probes/jpeg_state'
    env = dict(os.environ, VEXE=str(v), V_C_ERROR_BUG_REPORT_DISABLED='1')
    mode = 'ReleaseSafe' if args.v_prod else 'Debug'
    with work_directory(args.workdir, 'witty-jpeg-state-') as root:
        proof = ProofLog(root)
        shutil.copytree(source, root / 'src')
        fixtures = {}
        for name in ('main.v', 'reference.zig'):
            shutil.copyfile(probe / name, root / name)
            fixtures[name] = hashlib.sha256((probe / name).read_bytes()).hexdigest()
        versions = [proof.run([str(exe), 'version'], label, env=env).stdout.decode().strip()
                    for exe, label in ((zig, 'zig-version'), (v, 'v-version'))]
        if versions[0] != '0.15.2' or not re.match(r'^V 0\.5\.2(?: |$)', versions[1]):
            raise AssertionError('unexpected compiler versions')
        implementations = implementation_hashes(repo)
        runner_hash = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
        (root / 'provenance.json').write_text(json.dumps(dict(
            source_sha256=PINNED_SOURCE_SHA256, stdlib_sha256=PINNED_STDLIB_SHA256,
            versions=versions, target=args.target, zig_mode=mode, v_prod=args.v_prod,
            fixtures=fixtures, implementation_sha256=implementations, runner_sha256=runner_hash), indent=2) + '\n')
        print(f'Building JPEG state: Source {mode}, V {"production" if args.v_prod else "ordinary"}', flush=True)
        proof.run([str(zig), 'build-exe', '-target', args.target, '-lc', '-O', mode,
                   '--global-cache-dir', str(root / 'zig-global'), '-femit-bin=' + str(root / 'native'),
                   str(root / 'reference.zig')], 'build-source', timeout=args.timeout)
        proof.run([str(v), '-enable-globals', *(['-prod'] if args.v_prod else []), '-path',
                   f'{repo}|@vlib|@vmodules', '-o', str(root / 'translated'), str(root / 'main.v')],
                  'build-v', env=env, timeout=args.timeout)
        groups = corpus()
        rows = [data for _, data in groups]
        (root / 'corpus.txt').write_text('\n'.join(rows) + '\n')
        outputs = []
        for exe in ('native', 'translated'):
            r = proof.run([str(root / exe), str(root / 'corpus.txt')], exe,
                          timeout=args.timeout, check=False)
            if r.returncode or r.stderr or len(r.stdout.splitlines()) != len(rows):
                raise AssertionError(f'{exe}: invalid returning output ({r.returncode}, '
                                     f'{len(r.stdout.splitlines())} lines); see raw proof files')
            outputs.append(r.stdout.splitlines())
        for index, (native, translated) in enumerate(zip(*outputs)):
            if native != translated:
                raise AssertionError(f'{index}/{rows[index]}: Source={native!r}, V={translated!r}')
        digest = hashlib.sha256(b'\n'.join(outputs[0])).hexdigest()
        if EXPECTED_ROWS is not None and len(rows) != EXPECTED_ROWS:
            raise AssertionError('corpus changed')
        if EXPECTED_SHA256 is not None and digest != EXPECTED_SHA256:
            raise AssertionError('returning golden changed')
        print(f'{len(rows)} returning rows match; checking retained panic state', flush=True)
        states = hashlib.sha256()
        for name, (data, category) in traps().items():
            observed = []
            for exe in ('native', 'translated'):
                path = root / (name + '-' + exe + '.state')
                r = proof.run([str(root / exe), '--trap', str(path), data], name + '-' + exe,
                              timeout=args.timeout, check=False)
                checked_trap(r, name + '/' + exe, category)
                if not path.exists():
                    raise AssertionError('missing observer')
                observed.append(path.read_bytes())
            if observed[0] != observed[1]:
                raise AssertionError(f'{name}: differing states {observed}')
            states.update(name.encode() + b'\0' + observed[0] + b'\n')
        state_digest = states.hexdigest()
        if EXPECTED_STATE_SHA256 is not None and state_digest != EXPECTED_STATE_SHA256:
            raise AssertionError('failure-state golden changed')
        if (tree_hash(source) != PINNED_SOURCE_SHA256 or tree_hash(root / 'src') != PINNED_SOURCE_SHA256
                or stdlib_hash(zig) != PINNED_STDLIB_SHA256):
            raise AssertionError('dependency changed')
        if (implementation_hashes(repo) != implementations
                or hashlib.sha256(Path(__file__).read_bytes()).hexdigest() != runner_hash):
            raise AssertionError('implementation or runner changed')
        for name, expected in fixtures.items():
            if any(hashlib.sha256((p / name).read_bytes()).hexdigest() != expected for p in (root, probe)):
                raise AssertionError('fixture changed')
        summary = dict(returning_records=len(rows), returning_groups=dict(Counter(group for group, _ in groups)),
                       read_attempts=sum(len(line.split('|')[0].split(',')) for line in rows),
                       output_sha256=digest, paired_traps=len(traps()), state_sha256=state_digest,
                       zig_mode=mode, v_prod=args.v_prod)
        (root / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
        print(json.dumps(summary), flush=True)


if __name__ == '__main__':
    main()
