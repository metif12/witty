"""Compare public indexed factories, capacities, shared storage and checked resizes."""
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

TYPES = (('bool', 'bool', 1), ('u8', 'u8', 8), ('u16', 'u16', 16),
         ('i8', 'i8', 8), ('i16', 'i16', 16), ('ByteAlias', 'u8', 8),
         ('WordAlias', 'u16', 16), ('SignedAlias', 'i16', 16))
EXPECTED_RETURNS = 2384
EXPECTED_SHA256 = 'c0b156d0c049b331e851d03790c796d6e7f10fbb5dcc4ca699928c6ebac6a554'
EXPECTED_STATE_SHA256 = 'de4f2c99de990d467f02db399ebdc050189e8b85575dcbd0cc59dcb3040a53fd'
EXPECTED_EXTRA_SHA256 = {'named': '4a67a087d6b5e2ec7e312a38aefd65b6287ce60bb8f0a54f2203cf1449078a23',
                         'capacity': '72a7ca516e7bc799f0039c91009dd3ae67373edc4140184f92c0375631438c69'}
OBSERVER_HASHES = {'source': 'a28d24aaad78f6448af3f6f89d9a552aa7c2b14ad73b8c0fe5742d6f97acd358',
                   'v': '1a129adb553506de3977f381d895531bbf993e8f55d2a5b94eabb41c3f724384'}

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def corpus():
    rows = []
    for kind, (name, _, bits) in enumerate(TYPES):
        cap = 1 << bits
        for count, size, new, seed in itertools.product((0, 1, 7, 31),
                sorted({0, 1, cap // 2, cap - 1, cap}), sorted({0, 1, cap // 2, cap}), (0, 1, 127, 65535)):
            label = f'{name}-count-{count}-size-{size}-new-{new}-seed-{seed}'
            rows.append((name, label, '|'.join(map(str, (kind, count, size, new, seed)))))
    return rows

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('zig', type=Path)
    parser.add_argument('v', type=Path)
    parser.add_argument('--target', default='aarch64-macos.14.0')
    parser.add_argument('--v-prod', action='store_true')
    parser.add_argument('--workdir', type=Path)
    parser.add_argument('--timeout', type=int, default=300)
    args = parser.parse_args()
    if args.timeout <= 0: parser.error('--timeout must be positive')
    source, zig, v = args.source.resolve() / 'src', args.zig.resolve(), args.v.resolve()
    observers = {'source': zig.parent / 'lib/std/hash/fnv.zig', 'v': v.parent / 'vlib/hash/fnv1a/fnv1a.v'}
    if (tree_hash(source) != PINNED_SOURCE_SHA256 or stdlib_hash(zig) != PINNED_STDLIB_SHA256
            or any(digest(path) != OBSERVER_HASHES[name] for name, path in observers.items())):
        parser.error('Source or library differs from pins')
    repo = Path(__file__).resolve().parent.parent
    probe = repo / 'zigimg/reference_probes/indexed_generic'
    mode = 'ReleaseSafe' if args.v_prod else 'Debug'
    with work_directory(args.workdir, 'witty-indexed-generic-') as root:
        proof = ProofLog(root)
        tmp = root / 'tmp'; tmp.mkdir()
        env = dict(os.environ, VEXE=str(v), V_C_ERROR_BUG_REPORT_DISABLED='1', TMPDIR=str(tmp), VTMP=str(tmp))
        shutil.copytree(source, root / 'src')
        fixtures = {}
        for name in ('main.v', 'reference.zig'):
            shutil.copyfile(probe / name, root / name); fixtures[name] = digest(probe / name)
        versions = [proof.run([str(exe), 'version'], label, env=env).stdout.decode().strip()
                    for exe, label in ((zig, 'zig-version'), (v, 'v-version'))]
        if versions[0] != '0.15.2' or not re.match(r'^V 0\.5\.2(?: |$)', versions[1]): raise AssertionError('compiler version changed')
        implementations, runner_hash = implementation_hashes(repo), digest(Path(__file__))
        (root / 'provenance.json').write_text(json.dumps(dict(source_sha256=PINNED_SOURCE_SHA256,
            stdlib_sha256=PINNED_STDLIB_SHA256, observer_sha256=OBSERVER_HASHES, versions=versions,
            target=args.target, zig_mode=mode, v_prod=args.v_prod, fixtures=fixtures,
            implementation_sha256=implementations, runner_sha256=runner_hash), indent=2) + '\n')
        zbase = [str(zig), 'build-exe', '-target', args.target, '-lc', '-O', mode,
                 '--global-cache-dir', str(root / 'zig-global'), '--cache-dir', str(root / 'zig-cache')]
        vbase = [str(v), '-enable-globals', *(['-prod'] if args.v_prod else []), '-path', f'{repo}|@vlib|@vmodules']
        print(f'Building indexed factories: Source {mode}, V production={args.v_prod}', flush=True)
        proof.run(zbase + ['-femit-bin=' + str(root / 'native'), str(root / 'reference.zig')], 'build-source', timeout=args.timeout)
        proof.run(vbase + ['-o', str(root / 'translated'), str(root / 'main.v')], 'build-v', env=env, timeout=args.timeout)
        rows = corpus(); file = root / 'corpus.txt'
        file.write_text('\n'.join(row for _, _, row in rows) + '\n')
        inputs = {file.name: digest(file)}; consumers = {}; outputs = []
        for exe in ('native', 'translated'):
            result = proof.run([str(root / exe), str(file)], 'corpus-' + exe, timeout=args.timeout, check=False)
            if result.returncode or result.stderr: raise AssertionError('corpus failed; see retained diagnostics')
            outputs.append(result.stdout.splitlines())
        if any(len(output) != len(rows) for output in outputs): raise AssertionError('corpus counts differ')
        h = hashlib.sha256()
        for (_, name, row), a, b in zip(rows, *outputs):
            if a != b: raise AssertionError(f'{name}: initialized indexed state differs; input {row}')
            h.update(name.encode() + b'\0' + a + b'\n')
        extra = {}
        for label, count in (('named', 5), ('capacity', 3)):
            records = [proof.run([str(root / exe), label], label + '-' + exe, timeout=args.timeout).stdout for exe in ('native', 'translated')]
            if records[0] != records[1] or len(records[0].splitlines()) != count: raise AssertionError(label + ' differs')
            extra[label] = hashlib.sha256(records[0]).hexdigest()
        states = hashlib.sha256(); traps = 0
        for kind, (name, _, bits) in enumerate(TYPES):
            for operation, size in itertools.product((0, 1), ((1 << bits) + 1, (1 << 64) - 1)):
                label = f'{name}-trap-{operation}-{size}'; records = []
                for exe in ('native', 'translated'):
                    state = root / (label + '-' + exe + '.state')
                    result = proof.run([str(root / exe), 'trap', str(state), str(kind), str(operation), str(size)], label + '-' + exe, timeout=args.timeout, check=False)
                    checked_trap(result, label + '/' + exe, 'reached unreachable code')
                    messages = [m.group(1) for line in result.stderr.decode().splitlines()
                                if (m := re.fullmatch(r'(?:thread \d+ |V )?panic:\s*(.*)', line.strip()))]
                    if messages != ['reached unreachable code'] or not state.exists(): raise AssertionError('panic/state missing')
                    records.append(state.read_bytes())
                if not records[0] or records[0] != records[1]: raise AssertionError(label + ': retained state differs')
                states.update(label.encode() + b'\0' + records[0] + b'\n'); traps += 1
        def pair(label, zbody, vbody, zmarker=None, vmarker=None):
            paths = [root / (label + '.zig'), root / (label + '.v')]
            paths[0].write_text('const std=@import("std");const p=@import("src/color.zig");const a=std.heap.page_allocator;const ByteAlias=u8;const WordAlias=u16;const SignedAlias=i16;pub fn main() !void {' + zbody + '}\n')
            paths[1].write_text('module main\nimport zigimg as p\ntype ByteAlias=u8\ntype WordAlias=u16\ntype SignedAlias=i16\nfn main(){\n' + vbody + '\n}\n')
            for path in paths: consumers[path.name] = digest(path)
            for language, command, marker in (
                    ('Source', zbase + ['-fno-emit-bin', str(paths[0])], zmarker),
                    ('V', vbase + ['-check', '-o', str(root / (label + '-checked')), str(paths[1])], vmarker)):
                result = proof.run(command, label + '-' + language, env=env, timeout=args.timeout, check=False)
                errors = [line for line in (result.stdout + result.stderr).decode(errors='replace').splitlines() if re.search(r'\berror:', line)]
                if marker is None:
                    if result.returncode or errors: raise AssertionError(label + '/' + language + ': expected acceptance; see diagnostics')
                else:
                    ordinary_rejection(result, label + '/' + language)
                    if not any(marker in line for line in errors): raise AssertionError(label + '/' + language + ': expected diagnostic missing')
        for name, ztype, bits in TYPES:
            ztype = name
            vtype = name
            pair(name + '-constructors', 'var x=try p.IndexedStorage(' + ztype + ').init(a,0);x.resizePalette(1);x.deinit(a);',
                 'mut x:=p.IndexedStorage.init[' + vtype + '](0)\np.IndexedStorage.resize_palette[' + vtype + '](mut x,1)\nx.deinit()')
            for missing in ('palette', 'indices'):
                pair(name + '-missing-' + missing,
                     'const x:p.IndexedStorage(' + ztype + ')=.{' + ('.indices=&.{}' if missing == 'palette' else '.palette=&.{}') + '};_=x;',
                     'x:=p.IndexedStorage[' + vtype + ']{' + ('indices:[]' + vtype + '{}' if missing == 'palette' else 'palette:[]p.Rgba32{}') + '}\n_=x', 'missing struct field: ' + missing)
            pair(name + '-immutable-resize', 'const x=try p.IndexedStorage(' + ztype + ').init(a,0);x.resizePalette(0);',
                 'x:=p.IndexedStorage.init[' + vtype + '](0)\np.IndexedStorage.resize_palette[' + vtype + '](mut x,0)', 'expected type', 'immutable')
        for ztype, vtype in (('u64', 'u64'), ('i64', 'i64'), ('f64', 'f64')):
            pair(vtype + '-direct', 'const x:p.IndexedStorage(' + ztype + ')=.{.palette=&.{},.indices=&.{}};_=x;',
                 'x:=p.IndexedStorage[' + vtype + ']{palette:[]p.Rgba32{},indices:[]' + vtype + '{}}\nx.deinit()')
            pair(vtype + '-capacity', 'const x:usize=p.IndexedStorage(' + ztype + ').PaletteSize;_=x;',
                 '_=p.IndexedStorage.palette_size[' + vtype + ']()', 'cannot represent integer value', 'outside the represented scalar types')
        for bits, typ in ((8,'u8'),(16,'u16')):
            pair('named-identity-'+str(bits), 'const x=try p.IndexedStorage('+typ+').init(a,0);const y:p.IndexedStorage'+str(bits)+'=x;_=y;',
                 'accept:=fn(x p.IndexedStorage'+str(bits)+'){_=x}\naccept(p.IndexedStorage.init['+typ+'](0))', None, 'cannot use')
        for kind in ('u32','int','f32','count'):
            result = proof.run([str(root / 'translated'),'guard',kind], 'v-array-guard-'+kind,timeout=args.timeout,check=False)
            checked_trap(result,'v-array-guard-'+kind,'indexed storage exceeds V array length')
        (root / 'input_sha256.json').write_text(json.dumps(inputs, indent=2) + '\n')
        (root / 'consumer_sha256.json').write_text(json.dumps(consumers, indent=2) + '\n')
        for name, expected in {**inputs, **consumers}.items():
            if digest(root / name) != expected: raise AssertionError('input/consumer changed')
        if (tree_hash(source) != PINNED_SOURCE_SHA256 or tree_hash(root / 'src') != PINNED_SOURCE_SHA256
                or stdlib_hash(zig) != PINNED_STDLIB_SHA256 or implementation_hashes(repo) != implementations
                or digest(Path(__file__)) != runner_hash
                or any(digest(path) != OBSERVER_HASHES[name] for name, path in observers.items())):
            raise AssertionError('dependency, implementation or runner changed')
        for name, expected in fixtures.items():
            if any(digest(path) != expected for path in (root / name, probe / name)): raise AssertionError('fixture changed')
        summary = dict(returning_records=len(rows), groups=dict(Counter(group for group, _, _ in rows)), sha256=h.hexdigest(),
            named_records=5, capacity_records=3, extra_sha256=extra, paired_traps=traps, state_sha256=states.hexdigest(),
            accepted_constructor_pairs=8, generic_required_field_adaptations=16, immutable_resize_pairs=8,
            wide_direct_constructor_pairs=3, unrepresentable_capacity_pairs=3, named_identity_adaptations=2,
            v_array_length_guards=4, zig_mode=mode, v_prod=args.v_prod)
        (root / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n'); print(json.dumps(summary, indent=2), flush=True)
        if len(rows) != EXPECTED_RETURNS or traps != 32: raise AssertionError('counts changed')
        if h.hexdigest() != EXPECTED_SHA256 or states.hexdigest() != EXPECTED_STATE_SHA256 or extra != EXPECTED_EXTRA_SHA256:
            raise AssertionError('locked golden changed')

if __name__ == '__main__': main()
