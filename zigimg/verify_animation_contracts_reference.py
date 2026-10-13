"""Compare required animation frames, duration bits, copied records and borrowed arrays."""
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
from verify_tiff_decode_reference import ProofLog, tree_hash, work_directory, PINNED_SOURCE_SHA256
from verify_simd_reference import ordinary_rejection

FORMATS = (0, 1, 2, 4, 8, 16, 0x101, 0x102, 0x104, 0x108, 0x110, 0x208, 0x210,
           0x303, 0x305, 0x3305, 0x308, 0x408, 0x1305, 0x1308, 0x1408, 0x310, 0x410, 0x2420)
EXPECTED_RETURNS = 20992
EXPECTED_RETURN_SHA256 = '3898e0c8d02443126eebf2be9b483dad48af2686e9bf58dd7673e105df52960f'
EXPECTED_REPRESENTATION_SHA256 = 'e1bb37fc2732a1f753c59c9cdf48b1ef10c51f30307001a5cb5bb55e56feb623'


def corpus():
    rows = []
    words = (0, 0x80000000, 1, 0x3f000000, 0x7f800000, 0xff800000, 0x7fc12345, 0x7f812345)
    loops = (-2147483648, -1, 0, 1, 2147483647)
    for op, index, n, word, count in itertools.product(range(8), range(24), (0, 1, 3), words, range(4)):
        loop = loops[(op + index + n + count) % len(loops)]
        row = '|'.join(map(str, (op, FORMATS[index], n, word, count, loop, (index * 19 + count * 7) % 256)))
        rows.append((f'record-operation-{op}', f'record-{len(rows)}', row))
    for sign, exponent, mantissa in itertools.product(range(2), range(256), (0, 1, 0x3fffff, 0x7ffffe, 0x7fffff)):
        word = sign << 31 | exponent << 23 | mantissa
        rows.append(('duration-bit-domain', f'duration-{len(rows)}', f'0|0|0|{word}|0|-1|7'))
    return rows


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
        parser.error('Source or selected compiler library differs from pins')
    repo = Path(__file__).resolve().parent.parent
    probe = repo / 'zigimg/reference_probes/animation_contracts'
    mode = 'ReleaseSafe' if args.v_prod else 'Debug'
    env = dict(os.environ, VEXE=str(v), V_C_ERROR_BUG_REPORT_DISABLED='1')
    with work_directory(args.workdir, 'witty-animation-contracts-') as root:
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
            source_sha256=PINNED_SOURCE_SHA256, stdlib_sha256=PINNED_STDLIB_SHA256, versions=versions,
            target=args.target, zig_mode=mode, v_prod=args.v_prod, fixtures=fixtures,
            implementation_sha256=implementations, runner_sha256=runner_hash), indent=2) + '\n')
        zbase = [str(zig), 'build-exe', '-target', args.target, '-lc', '-O', mode,
                 '--global-cache-dir', str(root / 'zig-global')]
        vbase = [str(v), '-enable-globals', *(['-prod'] if args.v_prod else []), '-path', f'{repo}|@vlib|@vmodules']
        print(f'Building animation contracts: Source {mode}, V {"production" if args.v_prod else "ordinary"}', flush=True)
        proof.run(zbase + ['-femit-bin=' + str(root / 'native'), str(root / 'reference.zig')], 'build-source', timeout=args.timeout)
        proof.run(vbase + ['-o', str(root / 'translated'), str(root / 'main.v')], 'build-v', env=env, timeout=args.timeout)
        rows = corpus()
        inputs = {}
        file = root / 'corpus.txt'
        file.write_text('\n'.join(row for group, name, row in rows) + '\n')
        inputs[file.name] = hashlib.sha256(file.read_bytes()).hexdigest()
        outputs = []
        for exe in ('native', 'translated'):
            result = proof.run([str(root / exe), '--corpus', str(file)], 'corpus-' + exe, timeout=args.timeout)
            if result.stderr:
                raise AssertionError('unexpected corpus stderr')
            outputs.append(result.stdout.splitlines())
        if any(len(output) != len(rows) for output in outputs):
            raise AssertionError('corpus counts differ')
        returns = hashlib.sha256()
        groups = Counter()
        for (group, name, row), native, translated in zip(rows, *outputs):
            if native != translated:
                raise AssertionError(f'{name}: {native!r} != {translated!r}; input {row}')
            returns.update(name.encode() + b'\0' + native + b'\n')
            groups[group] += 1
        print(f'{len(rows)} records match; checking constructors and boxed-copy controls', flush=True)
        representations = hashlib.sha256()
        for bits in (1, 2, 4, 8, 16):
            records = []
            for exe in ('native', 'translated'):
                result = proof.run([str(root / exe), '--boxed', str(bits)], 'boxed-' + str(bits) + '-' + exe, timeout=args.timeout)
                if result.stderr:
                    raise AssertionError('unexpected representation stderr')
                records.append(result.stdout)
            if records != [f'1:{2 if bits == 1 else 3}:3:3\n'.encode(), b'1:1:3:3\n']:
                raise AssertionError(f'boxed-copy control changed: {bits}, {records}')
            representations.update(str(bits).encode() + b'\0' + records[0] + b'\0' + records[1])
        consumers = {}

        def pair(label, zbody, vbody, zmarker=None, vmarker=None):
            paths = [root / (label + '.zig'), root / (label + '.v')]
            paths[0].write_text('const std=@import("std");const I=@import("src/ImageUnmanaged.zig");const M=@import("src/Image.zig");pub fn main() void {' + zbody + '}\n')
            paths[1].write_text('module main\nimport zigimg as p\nfn main(){\n' + vbody + '\n}\n')
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
        pair('complete-frame', 'const x=I.AnimationFrame{.pixels=.invalid,.duration=0};_=x;',
             'x:=p.AnimationFrame{pixels:p.InvalidPixels{},duration:0}\n_=x')
        pair('managed-frame-alias', 'const x=M.AnimationFrame{.pixels=.invalid,.duration=0};_=x;',
             'x:=p.AnimationFrame{pixels:p.InvalidPixels{},duration:0}\n_=x')
        pair('default-records', 'const x=I.Animation{};const y=I{};const z=M.init(std.heap.page_allocator);_=x;_=y;_=z;',
             'x:=p.Animation{}\ny:=p.ImageUnmanaged{}\nz:=p.Image.init()\n_=x\n_=y\n_=z')
        pair('mutable-records', 'var x=I.AnimationFrame{.pixels=.invalid,.duration=0};x.duration=1;x.pixels=.invalid;var y=I.Animation{};y.loop_count=7;_=x.duration;_=x.pixels;_=y.loop_count;',
             'mut x:=p.AnimationFrame{pixels:p.InvalidPixels{},duration:0}\nx.duration=1\nx.pixels=p.InvalidPixels{}\nmut y:=p.Animation{}\ny.loop_count=7\n_=x\n_=y')
        for missing in ('pixels', 'duration'):
            zfield = '.duration=0' if missing == 'pixels' else '.pixels=.invalid'
            vfield = 'duration:0' if missing == 'pixels' else 'pixels:p.InvalidPixels{}'
            pair('missing-' + missing, 'const x=I.AnimationFrame{' + zfield + '};_=x;',
                 'x:=p.AnimationFrame{' + vfield + '}\n_=x',
                 'missing struct field: ' + missing, f'`zigimg.AnimationFrame.{missing}` must be initialized')
        for field, zvalue, vvalue in (('pixels', '.invalid', 'p.InvalidPixels{}'), ('duration', '1', '1')):
            pair('constant-' + field, f'const x=I.AnimationFrame{{.pixels=.invalid,.duration=0}};x.{field}={zvalue};',
                 f'x:=p.AnimationFrame{{pixels:p.InvalidPixels{{}},duration:0}}\nx.{field}={vvalue}',
                 'cannot assign to constant', 'is immutable')
        pair('constant-loop', 'const x=I.Animation{};x.loop_count=7;',
             'x:=p.Animation{}\nx.loop_count=7', 'cannot assign to constant', 'is immutable')
        (root / 'consumer_sha256.json').write_text(json.dumps(consumers, indent=2) + '\n')
        (root / 'input_sha256.json').write_text(json.dumps(inputs, indent=2) + '\n')
        for name, digest in {**inputs, **consumers}.items():
            if hashlib.sha256((root / name).read_bytes()).hexdigest() != digest:
                raise AssertionError('generated input/consumer changed')
        if (tree_hash(source) != PINNED_SOURCE_SHA256 or tree_hash(root / 'src') != PINNED_SOURCE_SHA256
                or stdlib_hash(zig) != PINNED_STDLIB_SHA256 or implementation_hashes(repo) != implementations
                or hashlib.sha256(Path(__file__).read_bytes()).hexdigest() != runner_hash):
            raise AssertionError('dependency, implementation or runner changed')
        for name, pin in fixtures.items():
            if any(hashlib.sha256(path.read_bytes()).hexdigest() != pin for path in (root / name, probe / name)):
                raise AssertionError('fixture changed')
        summary = dict(returning_records=len(rows), return_groups=dict(groups), return_sha256=returns.hexdigest(),
                       boxed_copy_differences=5, representation_sha256=representations.hexdigest(),
                       accepted_constructor_record_pairs=4, required_omission_pairs=2, constant_mutation_rejection_pairs=3)
        (root / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
        print(json.dumps(summary, indent=2), flush=True)
        if len(rows) != EXPECTED_RETURNS:
            raise AssertionError('animation count changed')
        if returns.hexdigest() != EXPECTED_RETURN_SHA256 or representations.hexdigest() != EXPECTED_REPRESENTATION_SHA256:
            raise AssertionError('locked animation golden changed')


if __name__ == '__main__':
    main()
