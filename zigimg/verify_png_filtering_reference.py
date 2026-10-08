"""Compare public PNG filtering, preserving its historical golden and checked failures."""
import argparse
import hashlib
import itertools
import json
import os
from pathlib import Path
import re
import shutil

from verify_png_foundation_reference import PINNED_SOURCE_SHA256, PINNED_FLATE_SHA256, FLATE_SOURCES
from verify_tiff_decode_reference import ProofLog, tree_hash, work_directory

REPO = Path(__file__).resolve().parent.parent
PROBE = REPO / 'zigimg/reference_probes/png_filtering'
EXPECTED_ROWS = 43389
EXPECTED_SHA256 = 'ba128302912d022c765fd89f37431e3961ffbe5b5c35cd6c9d140862401a9c7d'
PINNED_HELPERS_SHA256 = 'd8e33d24ad79f9e3cf7694a9914bcf8023d5125b15f1b51930fab0e91114e65e'
FORMATS = [(1, 3), (2, 3), (4, 3), (8, 3), (1, 0), (2, 0), (4, 0), (8, 0),
           (16, 0), (8, 4), (16, 4), (8, 2), (16, 2), (8, 6), (16, 6)]
CHANNELS = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}
TRAPS = {
    'short_pixels': 'index out of bounds',
    'channels8': 'source and destination arguments have non-equal lengths',
    'channels16': ('index out of bounds', ('array.get: index out of range', 'index out of bounds')),
    'odd16': 'exact division produced remainder',
    'try_all': 'Unimplemented',
    'rgb332': 'reached unreachable code',
    'rgb565': 'reached unreachable code',
    'pixel_bits': 'integer overflow',
    'line_product': 'integer overflow',
    'line_round': 'integer overflow',
}


def strict_panic(result, label, category, trace=()):
    categories = (category,) if isinstance(category, str) else category
    diagnostic = (result.stdout + result.stderr).decode(errors='replace')
    headers = [match.group(1) for line in diagnostic.splitlines()
               if (match := re.fullmatch(r'(?:thread \d+ |V )panic:\s*(.*)', line))]
    observed = tuple(line for line in result.stderr.decode(errors='replace').splitlines()
                     if line.startswith('TRACE '))
    if (result.returncode == 0 or result.stdout or
            any(line.startswith('UNEXPECTED') for line in diagnostic.splitlines()) or
            not any(header.startswith(expected) for header in headers for expected in categories) or
            observed != trace):
        raise AssertionError(f'{label}: expected {categories}, trace {trace}: {result.returncode}\n{diagnostic}')


def stdlib_hash(zig):
    digest = hashlib.sha256()
    for name in FLATE_SOURCES:
        digest.update(name.encode() + b'\0')
        digest.update((zig.parent / 'lib/std' / name).read_bytes())
    return digest.hexdigest()


def checked_helpers_hash(zig):
    digest = hashlib.sha256()
    for name in ('mem.zig', 'debug.zig'):
        digest.update(name.encode() + b'\0')
        digest.update((zig.parent / 'lib/std' / name).read_bytes())
    return digest.hexdigest()


def corpus():
    rows = []
    def add(slot, width, height, depth, color, seed, choice, capacity, count=None):
        rows.append('|'.join(map(str, (slot, width, height, width * height if count is None else count,
                                      depth, color, seed, choice, capacity))))
    for slot, (depth, color) in enumerate(FORMATS):
        for width, height, seed in itertools.product((1, 3, 9, 17), (0, 1, 3), range(8)):
            length = (((width * depth * CHANNELS[color] + 7) // 8) + 1) * height
            for choice, capacity in itertools.product(range(6), (0, 1, max(0, length - 1), length, length + 5)):
                add(slot, width, height, depth, color, seed, choice, capacity)
    assert len(rows) == 43200
    for slot, (depth, color) in enumerate(FORMATS):
        for choice in range(6):
            add(slot, 0, 3, depth, color, 0, choice, 8)
        add(slot, 17, 0, depth, color, 0, 6, 8)
    for width, height, choice, capacity in itertools.product((1, 2, 9), (1, 3), range(6), (0, 64)):
        add(15, width, height, 16, 3, 3, choice, capacity)
    for choice in range(6):
        add(8, 2, 1, 8, 0, 3, choice, 8)  # Source copies only one native u16.
        add(16, 1, 3, 0, 0, 0, choice, 8, count=0)  # Empty invalid-format rows.
    return rows


def golden(rows):
    value = 14695981039346656037
    for row in rows:
        failed, position, raw = row.decode().split('|')
        for part in [int(failed), int(position), *bytes.fromhex(raw)]:
            value = ((value ^ part) * 1099511628211) & ((1 << 64) - 1)
    return value


def verify(args, root):
    source = args.source.resolve() / 'src'
    zig = args.zig.resolve()
    if (tree_hash(source) != PINNED_SOURCE_SHA256 or stdlib_hash(zig) != PINNED_FLATE_SHA256 or
            checked_helpers_hash(zig) != PINNED_HELPERS_SHA256):
        raise AssertionError('dependency differs from pinned source/compiler')
    shutil.copytree(source, root / 'src')
    fixtures = {}
    for name in ('reference.zig', 'main.v'):
        shutil.copyfile(PROBE / name, root / name)
        fixtures[name] = hashlib.sha256((PROBE / name).read_bytes()).hexdigest()
    mode = args.zig_mode or ('ReleaseSafe' if args.v_prod else 'Debug')
    (root / 'provenance.json').write_text(json.dumps({
        'source_sha256': PINNED_SOURCE_SHA256, 'stdlib_sha256': PINNED_FLATE_SHA256,
        'checked_helpers_sha256': PINNED_HELPERS_SHA256,
        'zig_mode': mode, 'v_prod': args.v_prod, 'target': args.target, 'fixtures': fixtures,
    }, indent=2) + '\n')
    proof = ProofLog(root)
    proof.run([str(zig), 'build-exe', '-target', args.target, '-lc', '-O', mode,
               '--global-cache-dir', str(root / 'zig-global'),
               '-femit-bin=' + str(root / 'native'), str(root / 'reference.zig')], 'build-source')
    proof.run([str(args.v.resolve()), *(['-prod'] if args.v_prod else []), '-path',
               f'{REPO}|@vlib|@vmodules', '-o', str(root / 'translated'), str(root / 'main.v')],
              'build-v', env=dict(os.environ, VEXE=str(args.v.resolve()), V_C_ERROR_BUG_REPORT_DISABLED='1'))
    cases = corpus()
    if len(cases) != EXPECTED_ROWS: raise AssertionError('expanded corpus changed')
    path = root / 'corpus.txt'
    path.write_text('\n'.join(cases) + '\n')
    outputs = []
    for executable in ('native', 'translated'):
        result = proof.run([str(root / executable), str(path)], 'returning-' + executable, timeout=args.timeout)
        if result.stderr: raise AssertionError(f'{executable}: returning stderr')
        outputs.append(result.stdout.splitlines())
    if any(len(rows) != len(cases) for rows in outputs): raise AssertionError('returning row count')
    for case, native, translated in zip(cases, *outputs):
        if native != translated: raise AssertionError(f'{case}: {native!r} != {translated!r}')
    previous = golden(outputs[0][:43200])
    if previous != 0x809cede448778a71: raise AssertionError(f'historical golden changed: {previous:x}')
    for name, category in TRAPS.items():
        native_category, v_category = category if isinstance(category, tuple) else (category, category)
        for executable, expected in (('native', native_category), ('translated', v_category)):
            label = f'trap-{executable}-{name}'
            result = proof.run([str(root / executable), 'trap:' + name], label, check=False, timeout=15)
            strict_panic(result, label, expected)
    if (tree_hash(source) != PINNED_SOURCE_SHA256 or tree_hash(root / 'src') != PINNED_SOURCE_SHA256 or
            stdlib_hash(zig) != PINNED_FLATE_SHA256 or
            checked_helpers_hash(zig) != PINNED_HELPERS_SHA256 or
            any(hashlib.sha256((PROBE / name).read_bytes()).hexdigest() != digest for name, digest in fixtures.items())):
        raise AssertionError('dependency/fixture changed during comparison')
    digest = hashlib.sha256(b'\n'.join(outputs[0])).hexdigest()
    if digest != EXPECTED_SHA256: raise AssertionError('expanded output hash changed: ' + digest)
    summary = {'returning': len(cases), 'legacy_returning': 43200, 'legacy_fnv64': f'{previous:016x}',
               'sha256': digest, 'strict_trap_pairs': len(TRAPS), 'zig_mode': mode, 'v_prod': args.v_prod}
    (root / 'result.json').write_text(json.dumps(summary, indent=2) + '\n')
    print(f'PNG filtering {mode}: {len(cases)} returning records, historical golden {previous:016x}, '
          f'{len(TRAPS)} strict trap pairs, SHA256 {digest}', flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('zig', type=Path)
    parser.add_argument('v', type=Path)
    parser.add_argument('--target', default='aarch64-macos.14.0')
    parser.add_argument('--v-prod', action='store_true')
    parser.add_argument('--zig-mode', choices=('Debug', 'ReleaseSafe'))
    parser.add_argument('--workdir', type=Path)
    parser.add_argument('--timeout', type=float, default=180)
    args = parser.parse_args()
    with work_directory(args.workdir, 'witty-png-filter-') as root: verify(args, root)


if __name__ == '__main__': main()
