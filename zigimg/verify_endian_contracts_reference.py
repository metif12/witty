"""Compare bit-stream endian constraints and valid align/flush state with Source."""
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

EXPECTED_RETURNS = 71680
EXPECTED_SHA256 = '4151f02c6b6aca387075822982c0d3d48dac17eeeb1602a6c2014d07178ffb2c'
DIAGNOSTIC = 'Bit streams require BigEndian or LittleEndian'
VALID = ('p.LittleEndian', 'p.BigEndian', 'AliasLittle', 'AliasBig')
INVALID = ('Neither', 'AliasNeither', 'u8', 'bool', '&p.BigEndian', 'PointerAlias', 'ArrayMarker')
OPERATIONS = ('read_bits_no_eof', 'read_bits', 'read_bits_tuple', 'align_to_byte',
              'write_bits', 'flush_bits')


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def corpus():
    rows = []
    for order, raw, count in itertools.product(range(4), range(256), range(16)):
        rows.append(('align', f'align-{order}-{raw}-{count}', f'0|{order}|{raw}|{count}|0|1'))
    for order, raw, count, capacity, repeats in itertools.product(
            range(4), range(256), range(9), (0, 1, 2), (1, 2)):
        name = f'flush-{order}-{raw}-{count}-{capacity}-{repeats}'
        rows.append(('flush', name, f'1|{order}|{raw}|{count}|{capacity}|{repeats}'))
    return rows


def operation(marker, method):
    if method in OPERATIONS[:4]:
        record = f'mut bits:=p.BitReader[{marker}]{{reader:input.reader()}}\n'
        if method == 'align_to_byte':
            return record + 'bits.align_to_byte()'
        if method == 'read_bits':
            return record + f'mut count:=u16(777)\n_=bits.read_bits[{marker},u8](0,&count) or {{u8(0)}}'
        if method == 'read_bits_tuple':
            return record + f'x,y:=bits.read_bits_tuple[{marker},u8](0) or {{panic(err)}}\n_=x\n_=y'
        return record + f'_=bits.read_bits_no_eof[{marker},u8](0) or {{u8(0)}}'
    record = f'mut bits:=p.BitWriter[{marker}]{{writer:output.writer()}}\n'
    if method == 'flush_bits':
        return record + 'bits.flush_bits() or {}'
    return record + f'bits.write_bits[{marker},u8](u8(0),0) or {{}}'


def source_operation(endian, method):
    if method in OPERATIONS[:4]:
        body = f'var bits=p.BitReader({endian}){{.reader=input.reader()}};'
        calls = dict(read_bits_no_eof='_ = bits.readBitsNoEof(u8,0) catch 0;',
                     read_bits='var count:u16=777;_=bits.readBits(u8,0,&count) catch 0;',
                     read_bits_tuple='_ = bits.readBitsTuple(u8,0) catch unreachable;',
                     align_to_byte='bits.alignToByte();')
        return body + calls[method]
    body = f'var bits=p.BitWriter({endian}){{.writer=output.writer()}};'
    return body + ('bits.flushBits() catch {};' if method == 'flush_bits'
                   else 'bits.writeBits(@as(u8,0),0) catch {};')


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
    if args.timeout <= 0:
        parser.error('--timeout must be positive')
    source, zig, v = args.source.resolve() / 'src', args.zig.resolve(), args.v.resolve()
    if tree_hash(source) != PINNED_SOURCE_SHA256 or stdlib_hash(zig) != PINNED_STDLIB_SHA256:
        parser.error('Source or library differs from pins')
    repo = Path(__file__).resolve().parent.parent
    probe = repo / 'zigimg/reference_probes/endian_contracts'
    mode = 'ReleaseSafe' if args.v_prod else 'Debug'
    with work_directory(args.workdir, 'witty-endian-contracts-') as root:
        proof = ProofLog(root)
        tmp = root / 'tmp'; tmp.mkdir()
        env = dict(os.environ, VEXE=str(v), V_C_ERROR_BUG_REPORT_DISABLED='1', TMPDIR=str(tmp), VTMP=str(tmp))
        shutil.copytree(source, root / 'src')
        fixtures = {}
        for name in ('main.v', 'reference.zig'):
            shutil.copyfile(probe / name, root / name)
            fixtures[name] = digest(probe / name)
        versions = [proof.run([str(exe), 'version'], label, env=env).stdout.decode().strip()
                    for exe, label in ((zig, 'zig-version'), (v, 'v-version'))]
        if versions[0] != '0.15.2' or not re.match(r'^V 0\.5\.2(?: |$)', versions[1]):
            raise AssertionError('compiler version changed')
        implementation, runner_hash = implementation_hashes(repo), digest(Path(__file__))
        provenance = dict(source_sha256=PINNED_SOURCE_SHA256, stdlib_sha256=PINNED_STDLIB_SHA256,
                          versions=versions, target=args.target, zig_mode=mode, v_prod=args.v_prod,
                          fixtures=fixtures, implementation_sha256=implementation, runner_sha256=runner_hash)
        (root / 'provenance.json').write_text(json.dumps(provenance, indent=2) + '\n')
        zbase = [str(zig), 'build-exe', '-target', args.target, '-lc', '-O', mode,
                 '--global-cache-dir', str(root / 'zig-global'), '--cache-dir', str(root / 'zig-cache')]
        vbase = [str(v), '-enable-globals', *(['-prod'] if args.v_prod else []), '-path', f'{repo}|@vlib|@vmodules']
        print(f'Building endian contracts: Source {mode}, V production={args.v_prod}', flush=True)
        proof.run(zbase + ['-femit-bin=' + str(root / 'native'), str(root / 'reference.zig')], 'build-source', timeout=args.timeout)
        proof.run(vbase + ['-o', str(root / 'translated'), str(root / 'main.v')], 'build-v', env=env, timeout=args.timeout)
        rows = corpus(); path = root / 'corpus.txt'
        path.write_text('\n'.join(row for _, _, row in rows) + '\n')
        inputs = {path.name: digest(path)}
        outputs = []
        for exe in ('native', 'translated'):
            result = proof.run([str(root / exe), str(path)], 'corpus-' + exe, timeout=args.timeout, check=False)
            if result.returncode or result.stderr:
                raise AssertionError('corpus failed; see retained diagnostics')
            outputs.append(result.stdout.splitlines())
        if any(len(output) != len(rows) for output in outputs):
            raise AssertionError('corpus counts differ')
        h = hashlib.sha256()
        for (_, name, row), a, b in zip(rows, *outputs):
            if a != b:
                raise AssertionError(f'{name}: differing state; input {row}')
            h.update(name.encode() + b'\0' + a + b'\n')
        print(f'{len(rows)} returning records match, SHA256 {h.hexdigest()}', flush=True)
        consumers = {}
        prefix = ('const std=@import("std");const p=@import("src/io.zig");'
                  'pub fn main() void {var data:[2]u8=@splat(0);var input=p.ReadStream.initMemory(&data);'
                  'var output=p.WriteStream.initMemory(&data);_=&input;_=&output;')
        vprefix = ('module main\nimport zigimg as p\nstruct Neither{}\ntype AliasNeither=Neither\n'
                   'type AliasBig=p.BigEndian\ntype AliasLittle=p.LittleEndian\ntype NestedBig=AliasBig\n'
                   'type PointerAlias=&p.BigEndian\ntype ArrayMarker=[1]u8\nfn main(){\nmut data:=[]u8{len:2}\n'
                   'mut input:=p.ReadStream.init_memory(data)\nmut output:=p.WriteStream.init_memory(mut data)\n'
                   '_=&input\n_=&output\n')

        def pair(label, zbody, vbody, zmarker=None, vmarker=None):
            paths = (root / (label + '.zig'), root / (label + '.v'))
            paths[0].write_text(prefix + zbody + '}\n')
            paths[1].write_text(vprefix + vbody + '\n}\n')
            for path in paths:
                consumers[path.name] = digest(path)
            for language, command, marker in (
                    ('Source', zbase + ['-fno-emit-bin', str(paths[0])], zmarker),
                    ('V', vbase + ['-check', '-o', str(root / (label + '-checked')), str(paths[1])], vmarker)):
                result = proof.run(command, label + '-' + language, env=env, timeout=args.timeout, check=False)
                errors = [line for line in (result.stdout + result.stderr).decode(errors='replace').splitlines()
                          if re.search(r'\berror:', line)]
                if marker is None:
                    if result.returncode or errors:
                        raise AssertionError(label + '/' + language + ': expected acceptance; see diagnostics')
                else:
                    ordinary_rejection(result, label + '/' + language)
                    if not any(marker in line for line in errors):
                        raise AssertionError(label + '/' + language + ': expected diagnostic missing')

        for i, marker in enumerate(VALID):
            endian = '.little' if marker in ('p.LittleEndian', 'AliasLittle') else '.big'
            for method in OPERATIONS:
                pair(f'valid-{i}-{method}', source_operation(endian, method), operation(marker, method))
        for i, marker in enumerate(INVALID):
            for method in OPERATIONS:
                pair(f'invalid-{i}-{method}', source_operation('@as(u8,0)', method),
                     operation(marker, method), 'expected type', DIAGNOSTIC)
        for method in OPERATIONS:
            pair('nested-alias-' + method, source_operation('.big', method),
                 operation('NestedBig', method), None, DIAGNOSTIC)
        for name, field in (('Reader', 'reader'), ('Writer', 'writer')):
            pair('bare-invalid-' + name,
                 f'const bits=p.Bit{name}(@as(u8,0)){{.{field}=' + ('input' if name == 'Reader' else 'output') + f'.{field}()}};_=bits;',
                 f'bits:=p.Bit{name}[Neither]{{{field}:' + ('input' if name == 'Reader' else 'output') + f'.{field}()}}\n_=bits',
                 'expected type', DIAGNOSTIC)
        (root / 'input_sha256.json').write_text(json.dumps(inputs, indent=2) + '\n')
        (root / 'consumer_sha256.json').write_text(json.dumps(consumers, indent=2) + '\n')
        for name, expected in {**inputs, **consumers}.items():
            if digest(root / name) != expected:
                raise AssertionError('input or consumer changed')
        if (tree_hash(source) != PINNED_SOURCE_SHA256 or tree_hash(root / 'src') != PINNED_SOURCE_SHA256
                or stdlib_hash(zig) != PINNED_STDLIB_SHA256 or implementation_hashes(repo) != implementation
                or digest(Path(__file__)) != runner_hash):
            raise AssertionError('Source, dependency, implementation or runner changed')
        for name, expected in fixtures.items():
            if any(digest(path) != expected for path in (root / name, probe / name)):
                raise AssertionError('fixture changed')
        summary = dict(returning_records=len(rows), return_groups=dict(Counter(g for g, _, _ in rows)),
                       sha256=h.hexdigest(), accepted_operation_pairs=len(VALID) * len(OPERATIONS),
                       invalid_operation_pairs=len(INVALID) * len(OPERATIONS), bare_record_rejection_pairs=2, nested_alias_rejections=6)
        (root / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
        print(json.dumps(summary, indent=2), flush=True)
        if (len(rows) != EXPECTED_RETURNS or h.hexdigest() != EXPECTED_SHA256):
            raise AssertionError('locked endian golden changed')


if __name__ == '__main__':
    main()
