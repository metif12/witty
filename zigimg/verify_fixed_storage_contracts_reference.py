"""Compare inline fixed-buffer copies, borrowed views and exact resize failure state."""
import argparse
from collections import Counter
import hashlib
import itertools
import json
import os
from pathlib import Path
import re
import shutil

from verify_jpeg_contracts_reference import implementation_hashes
from verify_tga_decode_reference import stdlib_hash, PINNED_STDLIB_SHA256
from verify_tiff_decode_reference import ProofLog, tree_hash, work_directory, PINNED_SOURCE_SHA256, checked_trap
from verify_simd_reference import ordinary_rejection

CAPACITIES = (0, 1, 7, 8, 256, 513, 8, 256)
EXPECTED_RETURNS = 11508
EXPECTED_TRAPS = 1320
EXPECTED_RETURN_SHA256 = 'ca784ad0d6cf34998a7b78d16c63893daa7b6511fe6c8fb526973e2af64deb8d'
EXPECTED_STATE_SHA256 = '8cf452e2aa375778bb4f19266e1fcb02ff2e65ce1c554f0700a518322d1c5fb4'
HISTORICAL_SHA256 = 'ba652143ec8ea584ce4522ed61dc6605986e90185c524ce8b13281b40b642c0b'


def corpus():
    rows, traps = [], []
    for kind, form, op, mode, seed in itertools.product(range(3), range(8), range(7), range(4), (7, 251)):
        capacity = CAPACITIES[form]
        maximum = (0, capacity, 4, 3)[mode]
        old_lengths = sorted({0, min(1, maximum), maximum, max(0, maximum - 1)})
        sizes = sorted({0, min(1, capacity), capacity // 2, capacity, capacity + 1, (1 << 64) - 1}) if op in (0, 1, 2, 5, 6) else (0,)
        for old, size in itertools.product(old_lengths, sizes):
            message = f'index out of bounds: index {size}, len {capacity}' if op in (0, 1, 2, 5, 6) and size > capacity else None
            row = '|'.join(map(str, (kind, form, op, mode, old, size, seed)))
            group = f'operation-{op}'
            if message and (seed != 7 or op == 2 or old not in (0, maximum)):
                continue
            target = traps if message else rows
            target.append((group, f'{"trap" if message else "record"}-{len(target)}', row, message))
    return rows, traps


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('zig', type=Path)
    parser.add_argument('v', type=Path)
    parser.add_argument('--target', default='aarch64-macos.14.0')
    parser.add_argument('--v-prod', action='store_true')
    parser.add_argument('--workdir', type=Path)
    parser.add_argument('--timeout', type=int, default=180)
    args = parser.parse_args()
    if args.timeout <= 0:
        parser.error('--timeout must be positive')
    source = args.source.resolve() / 'src'
    zig, v = args.zig.resolve(), args.v.resolve()
    if tree_hash(source) != PINNED_SOURCE_SHA256 or stdlib_hash(zig) != PINNED_STDLIB_SHA256:
        parser.error('Source or library differs from pins')
    repo = Path(__file__).resolve().parent.parent
    probe = repo / 'zigimg/reference_probes/fixed_storage_contracts'
    historical = repo / 'zigimg/reference_probes/fixed_storage'
    mode = 'ReleaseSafe' if args.v_prod else 'Debug'
    env = dict(os.environ, VEXE=str(v), V_C_ERROR_BUG_REPORT_DISABLED='1')
    with work_directory(args.workdir, 'witty-fixed-storage-contracts-') as root:
        proof = ProofLog(root)
        shutil.copytree(source, root / 'src')
        fixtures = {}
        for original, name in ((probe / 'main.v', 'main.v'), (probe / 'reference.zig', 'reference.zig'),
                               (historical / 'main.v', 'historical-main.v'),
                               (historical / 'reference.zig', 'historical-reference.zig')):
            shutil.copyfile(original, root / name)
            fixtures[name] = dict(original=str(original.relative_to(repo)), sha256=hashlib.sha256(original.read_bytes()).hexdigest())
        versions = [proof.run([str(exe), 'version'], label, env=env).stdout.decode().strip()
                    for exe, label in ((zig, 'zig-version'), (v, 'v-version'))]
        if versions[0] != '0.15.2' or not re.match(r'^V 0\.5\.2(?: |$)', versions[1]):
            raise AssertionError('unexpected compiler versions')
        implementations = implementation_hashes(repo)
        runner_hash = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
        (root / 'provenance.json').write_text(json.dumps(dict(
            source_sha256=PINNED_SOURCE_SHA256, stdlib_sha256=PINNED_STDLIB_SHA256, versions=versions,
            target=args.target, zig_mode=mode, v_prod=args.v_prod, fixtures=fixtures,
            implementation_sha256=implementations, runner_sha256=runner_hash), indent=2) + '\n')
        zbase = [str(zig), 'build-exe', '-target', args.target, '-lc', '-O', mode,
                 '--global-cache-dir', str(root / 'zig-global')]
        vbase = [str(v), '-enable-globals', *(['-prod'] if args.v_prod else []), '-path', f'{repo}|@vlib|@vmodules']
        print(f'Building fixed-storage contracts: Source {mode}, V {"production" if args.v_prod else "ordinary"}', flush=True)
        proof.run(zbase + ['-femit-bin=' + str(root / 'native'), str(root / 'reference.zig')], 'build-source', timeout=args.timeout)
        proof.run(vbase + ['-o', str(root / 'translated'), str(root / 'main.v')], 'build-v', env=env, timeout=args.timeout)
        rows, traps = corpus()
        inputs = {}
        file = root / 'corpus.txt'
        file.write_text('\n'.join(row for group, name, row, message in rows) + '\n')
        inputs[file.name] = hashlib.sha256(file.read_bytes()).hexdigest()
        outputs = []
        for exe in ('native', 'translated'):
            result = proof.run([str(root / exe), '--corpus', str(file)], 'corpus-' + exe, timeout=args.timeout, check=False)
            if result.returncode:
                raise AssertionError(f'corpus-{exe} failed {result.returncode}; see retained stdout/stderr')
            if result.stderr:
                raise AssertionError('unexpected corpus stderr')
            outputs.append(result.stdout.splitlines())
        if any(len(output) != len(rows) for output in outputs):
            raise AssertionError('corpus counts differ')
        returns, states = hashlib.sha256(), hashlib.sha256()
        return_groups, trap_groups, categories = Counter(), Counter(), Counter()
        for (group, name, row, message), native, translated in zip(rows, *outputs):
            if native != translated:
                raise AssertionError(f'{name}: {native!r} != {translated!r}; input {row}')
            returns.update(name.encode() + b'\0' + native + b'\n')
            return_groups[group] += 1
        print(f'{len(rows)} fixed-buffer records match; checking {len(traps)} exact failures', flush=True)
        for group, name, row, message in traps:
            file = root / (name + '.txt')
            file.write_text(row)
            inputs[file.name] = hashlib.sha256(file.read_bytes()).hexdigest()
            records = []
            for exe in ('native', 'translated'):
                path = root / (name + '-' + exe + '.state')
                result = proof.run([str(root / exe), '--trap', str(path), row], name + '-' + exe,
                                   timeout=args.timeout, check=False)
                checked_trap(result, name + '/' + exe, message)
                messages = [m.group(1) for line in result.stderr.decode().splitlines()
                            if (m := re.fullmatch(r'(?:thread \d+ |V )?panic:\s*(.*)', line.strip()))]
                if messages != [message] or not path.exists():
                    raise AssertionError('exact panic or state missing')
                records.append(path.read_bytes())
            if not records[0] or records[0] != records[1]:
                raise AssertionError(f'{name}: differing state {records}; input {row}')
            states.update(name.encode() + b'\0' + message.encode() + b'\0' + records[0] + b'\n')
            trap_groups[group] += 1
            categories[message] += 1
        (root / 'input_sha256.json').write_text(json.dumps(inputs, indent=2) + '\n')
        consumers = {}

        def pair(label, zbody, vbody, zmarker=None, vmarker=None):
            paths = [root / (label + '.zig'), root / (label + '.v')]
            paths[0].write_text('const fixed=@import("src/utils.zig").FixedStorage;pub fn main() void {' + zbody + '}\n')
            paths[1].write_text('module main\nimport zigimg as p\ntype BadBytes=[2]u8\nfn main(){\n' + vbody + '\n}\n')
            for path in paths:
                consumers[path.name] = hashlib.sha256(path.read_bytes()).hexdigest()
            for language, command, marker in (
                    ('Source', zbase + ['-fno-emit-bin', str(paths[0])], zmarker),
                    ('V', vbase + ['-check', '-o', str(root / (label + '-checked')), str(paths[1])], vmarker)):
                result = proof.run(command, label + '-' + language, env=env, timeout=args.timeout, check=False)
                diagnostic = (result.stdout + result.stderr).decode(errors='replace')
                errors = [line for line in diagnostic.splitlines() if re.search(r'\berror:', line)]
                if marker is None:
                    if result.returncode or errors:
                        raise AssertionError(f'{label}/{language}: expected acceptance\n{diagnostic}')
                else:
                    ordinary_rejection(result, label + '/' + language)
                    if not any(marker in line for line in errors):
                        raise AssertionError(f'{label}/{language}: missing {marker!r}\n{diagnostic}')
        pair('default-record', 'const x=fixed(u8,8){};_=x;',
             'x:=p.FixedStorage8[u8]{}\n_=x')
        pair('initialized-record', 'const x=fixed(u8,8){.storage=.{0} ** 8};_=x.data.len;',
             'x:=p.FixedStorage8[u8]{storage:[8]u8{}}\n_=x.data.len')
        pair('mutable-record', 'var x=fixed(u8,8){.storage=.{0} ** 8};x.resize(3);x.data[0]=7;_=x.data.len;',
             'mut x:=p.FixedStorage8[u8]{}\nx.resize(3)\nx.data[0]=7\n_=x.data.len')
        pair('constant-resize', 'const x=fixed(u8,8){.storage=.{0} ** 8};x.resize(3);',
             'x:=p.FixedStorage8[u8]{}\nx.resize(3)', 'expected type', 'immutable')
        pair('constant-inline', 'const x=fixed(u8,8){.storage=.{0} ** 8};x.storage[0]=7;',
             'x:=p.FixedStorage8[u8]{}\nx.storage[0]=7', 'cannot assign to constant', 'immutable')
        pair('constant-borrowed-pointee', 'var data=[_]u8{1,2};const x=fixed(u8,8){.data=&data};x.data[0]=7;_=data[0];',
             'mut data:=[u8(1),2]\nx:=p.FixedStorage8[u8]{data:data}\nx.data[0]=7', None, 'immutable')
        pair('mismatched-array-element', 'const bytes=[_]u8{1,2};const x=fixed(u16,2){.storage=bytes};_=x;',
             'mut x:=p.FixedStorage[u16,BadBytes]{}\nx.resize(0)', 'expected type', 'FixedStorage requires an inline array of its element type')
        (root / 'consumer_sha256.json').write_text(json.dumps(consumers, indent=2) + '\n')
        # Unchanged historical writer matrix, now executed in both compiler modes.
        proof.run(zbase + ['-femit-bin=' + str(root / 'historical-native'), str(root / 'historical-reference.zig')], 'historical-build-source', timeout=args.timeout)
        proof.run(vbase + ['-o', str(root / 'historical-translated'), str(root / 'historical-main.v')], 'historical-build-v', env=env, timeout=args.timeout)
        old = [proof.run([str(root / exe)], 'historical-' + exe, timeout=args.timeout).stdout.splitlines()
               for exe in ('historical-native', 'historical-translated')]
        if old[0] != old[1] or len(old[0]) != 2373 or hashlib.sha256(b'\n'.join(old[0])).hexdigest() != HISTORICAL_SHA256:
            raise AssertionError('historical fixed-storage matrix changed')
        for name, digest in {**inputs, **consumers}.items():
            if hashlib.sha256((root / name).read_bytes()).hexdigest() != digest:
                raise AssertionError('generated input/consumer changed')
        if (tree_hash(source) != PINNED_SOURCE_SHA256 or tree_hash(root / 'src') != PINNED_SOURCE_SHA256
                or stdlib_hash(zig) != PINNED_STDLIB_SHA256 or implementation_hashes(repo) != implementations
                or hashlib.sha256(Path(__file__).read_bytes()).hexdigest() != runner_hash):
            raise AssertionError('dependency, implementation or runner changed')
        for name, pin in fixtures.items():
            if any(hashlib.sha256(path.read_bytes()).hexdigest() != pin['sha256'] for path in (root / name, repo / pin['original'])):
                raise AssertionError('fixture changed')
        summary = dict(returning_records=len(rows), return_groups=dict(return_groups), return_sha256=returns.hexdigest(),
                       paired_traps=len(traps), failure_groups=dict(trap_groups), panic_categories=dict(categories),
                       state_sha256=states.hexdigest(), accepted_record_pairs=3, rejection_pairs=3,
                       constant_pointee_adaptations=1, historical_returning_records=2373,
                       historical_sha256=HISTORICAL_SHA256)
        (root / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
        print(json.dumps(summary, indent=2), flush=True)
        if len(rows) != EXPECTED_RETURNS or len(traps) != EXPECTED_TRAPS:
            raise AssertionError('fixed-storage counts changed')
        if returns.hexdigest() != EXPECTED_RETURN_SHA256 or states.hexdigest() != EXPECTED_STATE_SHA256:
            raise AssertionError('locked fixed-storage golden changed')


if __name__ == '__main__':
    main()
