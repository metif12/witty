"""Compare GIF packed mutation, required records and production failure state."""
import argparse
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
from verify_simd_reference import ordinary_rejection

EXPECTED_ROWS = 14875
EXPECTED_SHA256 = 'c440937a2fdf13c1e0d4842500aad5820a32d1e23d8680a32cfdbb12e712ffbe'
EXPECTED_STATE_SHA256 = 'fff55be0cc9007627f8ec87bfea8aa6a12260f7a581ad909294dde3f1fda72c7'
FLAGS = [
    ('HeaderFlags', 'GifHeaderFlags', 'global_color_table_size', '1'),
    ('HeaderFlags', 'GifHeaderFlags', 'sorted', 'true'),
    ('HeaderFlags', 'GifHeaderFlags', 'color_resolution', '1'),
    ('HeaderFlags', 'GifHeaderFlags', 'use_global_color_table', 'true'),
    ('ImageDescriptorFlags', 'GifImageDescriptorFlags', 'local_color_table_size', '1'),
    ('ImageDescriptorFlags', 'GifImageDescriptorFlags', 'reserved', '1'),
    ('ImageDescriptorFlags', 'GifImageDescriptorFlags', 'sort', 'true'),
    ('ImageDescriptorFlags', 'GifImageDescriptorFlags', 'is_interlaced', 'true'),
    ('ImageDescriptorFlags', 'GifImageDescriptorFlags', 'has_local_color_table', 'true'),
    ('GraphicControlExtensionFlags', 'GifGraphicControlExtensionFlags', 'has_transparent_color', 'true'),
    ('GraphicControlExtensionFlags', 'GifGraphicControlExtensionFlags', 'user_input', 'true'),
    ('GraphicControlExtensionFlags', 'GifGraphicControlExtensionFlags', 'disposal_method', '.none'),
    ('GraphicControlExtensionFlags', 'GifGraphicControlExtensionFlags', 'reserved', '1'),
]
CONTRACTS = [
    ('CommentExtension', 'GifCommentExtension', {'comment': ('&.{}', '[]u8{}')}),
    ('ApplicationExtension', 'GifApplicationExtension', {
        'application_identifier': ('@splat(0)', '[8]u8{}'),
        'authentification_code': ('@splat(0)', '[3]u8{}'), 'data': ('&.{}', '[]u8{}')}),
]


def decode_cases():
    header = b'GIF89a' + struct.pack('<HHBBB', 1, 1, 128, 0, 0) + bytes((1, 2, 3, 4, 5, 6))
    cases = {
        'plain-text-overflow': ('--decode', header + b'\x21\x01\x00\xff' + b'A' * 255 + b'\x00\x3b',
                                'integer overflow', 'integer overflow'),
        'graphic-toss': ('--decode', header + b'\x21\xf9\x04\x00\x00\x00',
                         'reached unreachable code', 'reached unreachable code'),
        'short-loop': ('--loop', b'', 'index out of bounds', 'index out of bounds'),
    }
    for bits, size in ((1, 0), (2, 1), (4, 3)):
        colors = bytes(i & 255 for i in range((1 << bits) * 3))
        header = b'GIF89a' + struct.pack('<HHBBB', 1, 1, 128 | size, 0, 0) + colors
        for index in (1 << bits, (1 << bits) + 1, 255):
            control = bytes((0x21, 0xf9, 4, 9, 0, 0, index, 0))
            image = b'\x2c' + struct.pack('<HHHHB', 0, 0, 1, 1, 0) + b'\x02\x02\x4c\x01\x00\x3b'
            cases[f'background-{bits}-{index}'] = ('--decode', header + control + image,
                                                   'integer does not fit in destination type',
                                                   'integer does not fit in destination type')
    return cases


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
    if args.timeout <= 0: parser.error('--timeout must be positive')
    source = args.source.resolve() / 'src'
    zig, v = args.zig.resolve(), args.v.resolve()
    if tree_hash(source) != PINNED_SOURCE_SHA256 or stdlib_hash(zig) != PINNED_STDLIB_SHA256:
        parser.error('Source or selected compiler library differs from the pins')
    mode = 'ReleaseSafe' if args.v_prod else 'Debug'
    repo = Path(__file__).resolve().parent.parent
    probe = repo / 'zigimg/reference_probes/gif_records'
    env = dict(os.environ, VEXE=str(v), V_C_ERROR_BUG_REPORT_DISABLED='1')
    with work_directory(args.workdir, 'witty-gif-records-') as root:
        proof = ProofLog(root)
        shutil.copytree(source, root / 'src')
        fixtures = {}
        for name in ('main.v', 'reference.zig'):
            shutil.copyfile(probe / name, root / name)
            fixtures[name] = hashlib.sha256((root / name).read_bytes()).hexdigest()
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
        zbase = [str(zig), 'build-exe', '-target', args.target, '-lc', '-O', mode,
                 '--global-cache-dir', str(root / 'zig-global')]
        vbase = [str(v), '-enable-globals', *(['-prod'] if args.v_prod else []), '-path', f'{repo}|@vlib|@vmodules']
        print(f'Building GIF records: Source {mode}, V {"production" if args.v_prod else "ordinary"}', flush=True)
        proof.run(zbase + ['-femit-bin=' + str(root / 'native'), str(root / 'reference.zig')], 'build-source', timeout=args.timeout)
        proof.run(vbase + ['-o', str(root / 'translated'), str(root / 'main.v')], 'build-v', env=env, timeout=args.timeout)
        outputs = []
        for exe in ('native', 'translated'):
            r = proof.run([str(root / exe)], 'returning-' + exe, timeout=args.timeout)
            if r.stderr or len(r.stdout.splitlines()) != EXPECTED_ROWS: raise AssertionError('invalid returning output')
            outputs.append(r.stdout.splitlines())
        for index, (native, translated) in enumerate(zip(*outputs)):
            if native != translated: raise AssertionError(f'{index}: Source={native!r}, V={translated!r}')
        digest = hashlib.sha256(b'\n'.join(outputs[0])).hexdigest()
        if EXPECTED_SHA256 is not None and digest != EXPECTED_SHA256: raise AssertionError('returning golden changed')
        print(f'{EXPECTED_ROWS} returning rows match; checking failure state and constructors', flush=True)
        states = hashlib.sha256()

        def trap(name, arguments, zcategory, vcategory):
            observed = []
            for exe, category in (('native', zcategory), ('translated', vcategory)):
                path = root / (name + '-' + exe + '.state')
                r = proof.run([str(root / exe), arguments[0], str(path), *arguments[1:]],
                              name + '-' + exe, timeout=args.timeout, check=False)
                checked_trap(r, name + '/' + exe, category)
                if not path.exists(): raise AssertionError('missing panic observer')
                observed.append(path.read_bytes())
            if not observed[0] or observed[0] != observed[1]: raise AssertionError(f'{name}: differing states {observed}')
            states.update(name.encode() + b'\0' + observed[0] + b'\n')

        for field in ('header_size', 'resolution', 'local_size', 'descriptor_reserved', 'disposal', 'control_reserved'):
            limit = 4 if field == 'descriptor_reserved' else 8
            for value in (limit, limit + 1, 255):
                trap(f'narrow-{field}-{value}', ['--narrow', field, str(value)],
                     'integer does not fit in destination type', 'integer does not fit in destination type')
        for name, (flag, data, zcategory, vcategory) in decode_cases().items():
            trap(name, [flag, data.hex()], zcategory, vcategory)
        for position, count in ((0, 5), (1, 4), (3, 33)):
            trap(f'toss-end-{position}-{count}', ['--toss', str(position), str(count)],
                 'reached unreachable code', 'reached unreachable code')
        for position in (1, 3):
            trap(f'toss-overflow-{position}', ['--toss', str(position), str(0xffffffffffffffff)],
                 'integer overflow', 'integer overflow')
        state_digest = states.hexdigest()
        if EXPECTED_STATE_SHA256 is not None and state_digest != EXPECTED_STATE_SHA256: raise AssertionError('failure-state golden changed')

        def pair(label, zbody, vbody, zmarker=None, vmarker=None):
            zp, vp = root / (label + '.zig'), root / (label + '.v')
            zp.write_text('const std=@import("std");const p=@import("src/formats/gif.zig");const a=std.heap.page_allocator;pub fn main() !void {' + zbody + '}\n')
            vp.write_text('module main\nimport zigimg as p\nfn main(){\n' + vbody + '\n}\n')
            for language, command, marker in (
                    ('Source', zbase + ['-fno-emit-bin', str(zp)], zmarker),
                    ('V', vbase + ['-check', str(vp)], vmarker)):
                r = proof.run(command, label + '-' + language, env=env, timeout=args.timeout, check=False)
                diagnostic = (r.stdout + r.stderr).decode(errors='replace')
                errors = [line for line in diagnostic.splitlines() if re.search(r'\berror:', line)]
                if marker is None:
                    if r.returncode or errors: raise AssertionError(f'{label}/{language}: expected acceptance\n{diagnostic}')
                else:
                    ordinary_rejection(r, label + '/' + language)
                    if not any(marker in line for line in errors): raise AssertionError(f'{label}/{language}: missing actual error {marker!r}\n{diagnostic}')

        for zk, vk, field, value in FLAGS:
            pair('immutable-' + zk + '-' + field, 'const x:p.' + zk + '=.{};x.' + field + '=' + value + ';',
                 'x:=p.' + vk + '{}\nx.set_' + field + '(' + value + ')', 'cannot assign to constant', 'immutable')
        omissions = 0
        for zk, vk, fields in CONTRACTS:
            for missing in (None, *fields):
                zfields = ','.join('.' + name + '=' + val[0] for name, val in fields.items() if name != missing)
                vfields = ','.join(name + ':' + val[1] for name, val in fields.items() if name != missing)
                label = ('complete-' if missing is None else 'missing-') + zk + ('-' + missing if missing else '')
                pair(label, 'const x:p.' + zk + '=.{' + zfields + '};_=x;', 'x:=p.' + vk + '{' + vfields + '}\n_=x',
                     None if missing is None else 'missing struct field: ' + missing,
                     None if missing is None else 'zigimg.' + vk + '.' + missing)
                omissions += missing is not None
        for zk, vk, field, _ in FLAGS:
            if field in ('global_color_table_size', 'color_resolution', 'local_color_table_size', 'reserved'):
                limit = '4' if zk == 'ImageDescriptorFlags' and field == 'reserved' else '8'
                pair('literal-' + zk + '-' + field, 'var x:p.' + zk + '=.{};x.' + field + '=' + limit + ';_=x;',
                     'mut x:=p.' + vk + '{}\nx.set_' + field + '(' + limit + ')', 'cannot represent integer value', None)
        pair('const-comment-pointee', 'var data=[_]u8{1};const x:p.CommentExtension=.{.comment=&data};x.comment[0]=2;',
             'mut data:=[u8(1)]\nx:=p.GifCommentExtension{comment:data}\nx.comment[0]=2', None, 'immutable')
        pair('cleanup-comment', 'const x:p.CommentExtension=.{.comment=try a.alloc(u8,0)};x.deinit(a);',
             'x:=p.GifCommentExtension{comment:[]u8{}}\nx.deinit()')
        pair('cleanup-application', 'const x:p.ApplicationExtension=.{.application_identifier=@splat(0),.authentification_code=@splat(0),.data=try a.alloc(u8,0)};x.deinit(a);',
             'x:=p.GifApplicationExtension{application_identifier:[8]u8{},authentification_code:[3]u8{},data:[]u8{}}\nx.deinit()')
        wide_states = []
        for exe, category, expected in (('native', 'reached unreachable code', b'18446744073709551615'),
                                        ('translated', 'reached unreachable code', b'0')):
            path = root / ('wide-toss-' + exe + '.state')
            r = proof.run([str(root / exe), '--toss', str(path), '0', '18446744073709551615'],
                          'wide-toss-' + exe, timeout=args.timeout, check=False)
            checked_trap(r, 'wide-toss/' + exe, category)
            if not path.exists() or path.read_bytes() != expected: raise AssertionError('wide cursor difference changed')
            wide_states.append(path.read_text())
        if (tree_hash(source) != PINNED_SOURCE_SHA256 or tree_hash(root / 'src') != PINNED_SOURCE_SHA256
                or stdlib_hash(zig) != PINNED_STDLIB_SHA256 or implementation_hashes(repo) != implementations
                or hashlib.sha256(Path(__file__).read_bytes()).hexdigest() != runner_hash):
            raise AssertionError('dependency, implementation or runner changed')
        for name, expected in fixtures.items():
            if any(hashlib.sha256((p / name).read_bytes()).hexdigest() != expected for p in (root, probe)): raise AssertionError('fixture changed')
        summary = dict(returning_records=EXPECTED_ROWS, header_mutations=5120, descriptor_mutations=4608,
                       control_mutations=5120, record_rows=27, output_sha256=digest,
                       paired_traps=23 + len(decode_cases()), state_sha256=state_digest,
                       immutable_rejections=len(FLAGS), required_omissions=omissions,
                       narrow_literal_differences=5, const_slice_pointee_differences=1,
                       wide_toss_cursor_difference=wide_states,
                       zig_mode=mode, v_prod=args.v_prod)
        (root / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
        print(json.dumps(summary), flush=True)


if __name__ == '__main__':
    main()
