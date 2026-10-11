"""Compare JPEG public record construction and mutation with unchanged Source."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil

from verify_jpeg_contracts_reference import stdlib_hash, PINNED_STDLIB_SHA256, implementation_hashes
from verify_tiff_decode_reference import ProofLog, tree_hash, work_directory, PINNED_SOURCE_SHA256
from verify_simd_reference import ordinary_rejection

EXPECTED_ROWS = 17747
EXPECTED_SHA256 = '924be5dd9166431cce22672eead65ce550a96e1d48fc570078d35f145ca2323d'
EXPECTED_BOXED_SHA256 = ('7ddf49db31a6257661b6d7046a12f24466f517b43e4846a896cb176e5d485936',
                         '22607c4ce6f4ad8ac93484824f0ecb3c5004ea4f0957dc823c05bfe570aebbca')

CONTRACTS = [
    ('Component', 'C', 'JpegComponent', {
        'id': ('0', '0'), 'horizontal_sampling_factor': ('0', '0'),
        'vertical_sampling_factor': ('0', '0'), 'quantization_table_id': ('0', '0')}, {}),
    ('FrameHeader', 'F', 'JpegFrameHeader', {
        'sample_precision': ('0', '0'), 'height': ('0', '0'), 'width': ('0', '0'),
        'components': ('&.{}', '[]p.JpegComponent{}')}, {'allocator': 'a'}),
    ('QuantizationHeader', 'Q.Header', 'JpegQuantizationHeader', {
        'table_precision': ('0', '0'), 'table_destination': ('0', '0'),
        'table': ('.{.q8=@splat(0)}', 'p.JpegQuantization8{values:[64]u8{}}')}, {}),
    ('JfifHeader', 'J', 'JpegJfifHeader', {
        'jfif_revision': ('0', '0'), 'density_unit': ('.pixels', '.pixels'),
        'x_density': ('0', '0'), 'y_density': ('0', '0')}, {}),
    ('HuffmanTable', 'H.Table', 'JpegHuffmanTable', {
        'code_counts': ('@splat(0)', '[16]u8{}'), 'code_map': ('.init(a)', 'map[u32]u8{}'),
        'fast_table': ('@splat(255)', '[512]u8{init:255}'),
        'fast_size': ('@splat(0)', '[512]u8{}'), 'table_class': ('0', '0')}, {'allocator': 'a'}),
]


def z_consumer(body):
    return ('const std=@import("std");const F=@import("src/formats/jpeg/FrameHeader.zig");'
            'const C=@typeInfo(@FieldType(F,"components")).pointer.child;'
            'const J=@import("src/formats/jpeg/JFIFHeader.zig");'
            'const Q=@import("src/formats/jpeg/quantization.zig");'
            'const H=@import("src/formats/jpeg/huffman.zig");'
            'const a=std.heap.page_allocator;pub fn main() !void {' + body + '}\n')


def v_consumer(body):
    return 'module main\nimport zigimg as p\nfn main(){\n' + body + '\n}\n'


def record(zkind, vkind, fields, fixed, missing=None, mutable=False):
    zfields = ','.join(['.' + name + '=' + values[0] for name, values in fields.items() if name != missing]
                      + ['.' + name + '=' + value for name, value in fixed.items()])
    vfields = ','.join(name + ':' + values[1] for name, values in fields.items() if name != missing)
    return (('var' if mutable else 'const') + ' x:' + zkind + '=.{' + zfields + '};',
            ('mut ' if mutable else '') + 'x:=p.' + vkind + '{' + vfields + '}\n')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('zig', type=Path)
    parser.add_argument('v', type=Path)
    parser.add_argument('--target', default='aarch64-macos.14.0')
    parser.add_argument('--v-prod', action='store_true')
    parser.add_argument('--zig-mode', choices=('Debug', 'ReleaseSafe'))
    parser.add_argument('--workdir', type=Path)
    parser.add_argument('--timeout', type=int, default=180)
    args = parser.parse_args()
    if args.timeout <= 0: parser.error('--timeout must be positive')
    source = args.source.resolve() / 'src'
    zig, v = args.zig.resolve(), args.v.resolve()
    if tree_hash(source) != PINNED_SOURCE_SHA256 or stdlib_hash(zig) != PINNED_STDLIB_SHA256:
        parser.error('Source or compiler library differs from the pins')
    mode = args.zig_mode or ('ReleaseSafe' if args.v_prod else 'Debug')
    repo = Path(__file__).resolve().parent.parent
    probe = repo / 'zigimg/reference_probes/jpeg_records'
    env = dict(os.environ, VEXE=str(v), V_C_ERROR_BUG_REPORT_DISABLED='1')
    with work_directory(args.workdir, 'witty-jpeg-records-') as root:
        proof = ProofLog(root)
        shutil.copytree(source, root / 'src')
        fixtures = {}
        for name in ('reference.zig', 'main.v'):
            shutil.copyfile(probe / name, root / name)
            fixtures[name] = hashlib.sha256((root / name).read_bytes()).hexdigest()
        versions = [proof.run([str(exe), 'version'], label, env=env).stdout.decode().strip()
                    for exe, label in ((zig, 'zig-version'), (v, 'v-version'))]
        if versions[0] != '0.15.2' or not re.match(r'^V 0\.5\.2(?: |$)', versions[1]):
            raise AssertionError('unexpected compiler versions')
        implementations = implementation_hashes(repo)
        runner_hash = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
        provenance = dict(source_sha256=PINNED_SOURCE_SHA256, stdlib_sha256=PINNED_STDLIB_SHA256,
                          versions=versions, zig_mode=mode, v_prod=args.v_prod, target=args.target,
                          fixtures=fixtures, v_implementation_sha256=implementations,
                          runner_sha256=runner_hash)
        (root / 'provenance.json').write_text(json.dumps(provenance, indent=2) + '\n')
        zbase = [str(zig), 'build-exe', '-target', args.target, '-lc', '-O', mode,
                 '--global-cache-dir', str(root / 'zig-global')]
        vbase = [str(v), *(['-prod'] if args.v_prod else []), '-path', f'{repo}|@vlib|@vmodules']
        print(f'Building JPEG records: Source {mode}, V {"production" if args.v_prod else "ordinary"}', flush=True)
        proof.run(zbase + ['-femit-bin=' + str(root / 'native'), str(root / 'reference.zig')],
                  'build-source', timeout=args.timeout)
        proof.run(vbase + ['-o', str(root / 'translated'), str(root / 'main.v')],
                  'build-v', env=env, timeout=args.timeout)
        results = [proof.run([str(root / exe)], 'returning-' + exe, timeout=args.timeout)
                   for exe in ('native', 'translated')]
        outputs = [r.stdout.splitlines() for r in results]
        if any(r.stderr for r in results) or any(len(out) != EXPECTED_ROWS for out in outputs):
            raise AssertionError('invalid returning output: ' + repr([(len(out), r.stderr) for r, out in zip(results, outputs)]))
        for index, (native, translated) in enumerate(zip(*outputs)):
            if native != translated: raise AssertionError(f'record {index}: Source={native!r}, V={translated!r}')
        digest = hashlib.sha256(b'\n'.join(outputs[0])).hexdigest()
        if EXPECTED_SHA256 is not None and digest != EXPECTED_SHA256: raise AssertionError('returning golden changed')
        boxed, boxed_hashes = [], []
        for exe, expected in zip(('native', 'translated'), EXPECTED_BOXED_SHA256):
            result = proof.run([str(root / exe), '--boxed'], 'boxed-' + exe, timeout=args.timeout)
            if result.stderr or len(result.stdout.splitlines()) != 18: raise AssertionError('invalid boxed output')
            boxed.append(result.stdout.splitlines())
            boxed_hashes.append(hashlib.sha256(b'\n'.join(boxed[-1])).hexdigest())
            if expected is not None and boxed_hashes[-1] != expected: raise AssertionError('boxed golden changed')

        def pair(label, zbody, vbody, zmarker=None, vmarker=None):
            paths = root / (label + '.zig'), root / (label + '.v')
            paths[0].write_text(z_consumer(zbody)); paths[1].write_text(v_consumer(vbody))
            for language, command, marker in (
                    ('Source', zbase + ['-fno-emit-bin', str(paths[0])], zmarker),
                    ('V', vbase + ['-check', str(paths[1])], vmarker)):
                result = proof.run(command, label + '-' + language, env=env, timeout=args.timeout, check=False)
                diagnostic = (result.stdout + result.stderr).decode(errors='replace')
                errors = [line for line in diagnostic.splitlines() if re.search(r'\berror:', line)]
                if marker is None:
                    if result.returncode or errors: raise AssertionError(f'{label}/{language}: expected acceptance\n{diagnostic}')
                else:
                    ordinary_rejection(result, label + '/' + language)
                    if not any(marker in line for line in errors):
                        raise AssertionError(f'{label}/{language}: missing actual error {marker!r}\n{diagnostic}')

        omissions = 0
        print('Checking required constructors and immutable bindings', flush=True)
        for label, zkind, vkind, fields, fixed in CONTRACTS:
            zbody, vbody = record(zkind, vkind, fields, fixed)
            pair('complete-' + label, zbody + '_=x;', vbody + '_=x')
            for missing in fields:
                zbody, vbody = record(zkind, vkind, fields, fixed, missing)
                pair('missing-' + label + '-' + missing, zbody + '_=x;', vbody + '_=x',
                     'missing struct field: ' + missing, 'zigimg.' + vkind + '.' + missing)
                omissions += 1
            field = next(iter(fields))
            value = fields[field]
            zbody, vbody = record(zkind, vkind, fields, fixed)
            pair('readonly-' + label, zbody + 'x.' + field + '=' + value[0] + ';',
                 vbody + 'x.' + field + '=' + value[1], 'cannot assign to constant', 'immutable')
        for tag, vkind, vtype in (('q8', 'JpegQuantization8', 'u8'), ('q16', 'JpegQuantization16', 'u16')):
            pair('complete-' + tag, 'const x:Q.Table=.{.' + tag + '=@splat(0)};_=x;',
                 'x:=p.' + vkind + '{values:[64]' + vtype + '{}}\n_=x')
            pair('missing-' + tag, 'const x:Q.Table=.' + tag + ';_=x;',
                 'x:=p.' + vkind + '{}\n_=x', 'must initialize', 'zigimg.' + vkind + '.values')
            pair('readonly-' + tag, 'const x:Q.Table=.{.' + tag + '=@splat(0)};x.' + tag + '[0]=1;',
                 'x:=p.' + vkind + '{values:[64]' + vtype + '{}}\nx.values[0]=1',
                 'cannot assign to constant', 'immutable')
            omissions += 1
        pair('empty-table', 'const x:Q.Table=.{};_=x;', 'x:=p.JpegQuantizationTable{}\n_=x',
             'union initializer must initialize one field', 'zigimg.JpegQuantization8.values')
        pair('two-arms', 'const x:Q.Table=.{.q8=@splat(0),.q16=@splat(0)};_=x;',
             'x:=p.JpegQuantization8{values:[64]u8{},q16:[64]u16{}}\n_=x',
             'cannot initialize multiple union fields', 'unknown field')
        # Source accepts mutating through a const slice descriptor. V const
        # bindings reject the operation; keep that language adaptation separate.
        fields, fixed = CONTRACTS[1][3:]
        zbody, vbody = record('F', 'JpegFrameHeader', fields, fixed)
        zbody = ('var components=[_]C{.{.id=0,.horizontal_sampling_factor=0,.vertical_sampling_factor=0,.quantization_table_id=0}};'
                 + zbody.replace('.components=&.{}', '.components=&components'))
        vbody = ('mut components:=[p.JpegComponent{id:0,horizontal_sampling_factor:0,vertical_sampling_factor:0,quantization_table_id:0}]\n'
                 + vbody.replace('components:[]p.JpegComponent{}', 'components:components'))
        pair('const-slice-pointee', zbody + 'x.components[0].id=1;',
             vbody + 'x.components[0].id=1', None, 'immutable')
        # deinit controls use valid owned/empty storage and inspect no freed memory.
        zbody, vbody = record('F', 'JpegFrameHeader', fields, fixed, mutable=True)
        pair('cleanup-header', zbody + 'x.deinit();', vbody + 'x.deinit()')
        fields, fixed = CONTRACTS[4][3:]
        zbody, vbody = record('H.Table', 'JpegHuffmanTable', fields, fixed, mutable=True)
        pair('cleanup-huffman', zbody + 'x.deinit();', vbody + 'x.deinit()')
        for index, field, value, marker in (
                (0, 'horizontal_sampling_factor', '16', "type 'u4' cannot represent integer value '16'"),
                (0, 'vertical_sampling_factor', '16', "type 'u4' cannot represent integer value '16'"),
                (2, 'table_precision', '16', "type 'u4' cannot represent integer value '16'"),
                (2, 'table_destination', '16', "type 'u4' cannot represent integer value '16'"),
                (4, 'fast_size', '@splat(32)', "type 'u5' cannot represent integer value '32'")):
            label, zkind, vkind, fields, fixed = CONTRACTS[index]
            fields = dict(fields)
            fields[field] = (value, '[512]u8{init:32}' if field == 'fast_size' else value)
            zbody, vbody = record(zkind, vkind, fields, fixed)
            pair('wide-' + label + '-' + field, zbody + '_=x;', vbody + '_=x', marker)
        if (tree_hash(source) != PINNED_SOURCE_SHA256 or tree_hash(root / 'src') != PINNED_SOURCE_SHA256
                or stdlib_hash(zig) != PINNED_STDLIB_SHA256): raise AssertionError('dependency changed')
        for name, expected in fixtures.items():
            if any(hashlib.sha256((p / name).read_bytes()).hexdigest() != expected for p in (probe, root)):
                raise AssertionError('fixture changed: ' + name)
        if (implementation_hashes(repo) != implementations or
                hashlib.sha256(Path(__file__).read_bytes()).hexdigest() != runner_hash):
            raise AssertionError('runner or V implementation changed')
        summary = dict(returning_records=EXPECTED_ROWS, output_sha256=digest,
                       complete_constructor_pairs=7, required_field_pairs=omissions,
                       readonly_rejection_pairs=7, tag_constructor_rejection_pairs=2,
                       const_slice_adaptations=1, cleanup_compile_controls=2,
                       wider_carrier_adaptations=5,
                       boxed_copy_records=18, boxed_copy_divergences=sum(a != b for a, b in zip(*boxed)),
                       boxed_copy_hashes=boxed_hashes, zig_mode=mode, v_prod=args.v_prod)
        (root / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
        print(json.dumps(summary), flush=True)


if __name__ == '__main__': main()
