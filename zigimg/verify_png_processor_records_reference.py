"""Compare public PNG processor record contracts against unchanged pinned Source."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil

from verify_png_header_reference import PINNED_SOURCE_SHA256
from verify_png_records_reference import memory_hash, PINNED_MEMORY_SHA256
from verify_tiff_decode_reference import ProofLog, tree_hash, work_directory
from verify_simd_reference import ordinary_rejection

EXPECTED_ROWS = 199
EXPECTED_SHA256 = '75975f75febf19e8a3a7085652494075707bef6323eba6455002c39998da2c32'
EXPECTED_SOURCE_BOX_SHA256 = '1ed0619962c4a745aa5c91bf340171ab52b454383daed56cf4c71ca11e407498'
EXPECTED_V_BOX_SHA256 = 'e396b5a8aec0e3d4362120be0d7127180cb55f1eb939a398a1916565c04ec456'

HEADER_Z = '.{.width=0,.height=0,.bit_depth=0,.color_type=.grayscale,.compression_method=.deflate,.filter_method=.adaptive,.interlace_method=.none}'
HEADER_V = 'zigimg.PngHeaderData{width:0,height:0,bit_depth:0,color_type:.grayscale,compression_method:.deflate,filter_method:.adaptive,interlace_method:.none}'
VT_Z = '.{.chunk_processor=null,.palette_processor=null,.data_row_processor=null}'
VT_V = 'zigimg.PngReaderProcessorVTable{chunk_processor:none,palette_processor:none,data_row_processor:none}'
CONTRACTS = [
    ('ChunkProcessData', 'r.ChunkProcessData', 'zigimg.PngChunkProcessData', {
        'read_stream': ('&stream', '&stream'), 'chunk_id': ('0', '0'), 'chunk_length': ('0', '0'),
        'current_format': ('.invalid', '.invalid'), 'header': ('&header', '&header')}, {'temp_allocator': 'allocator'}),
    ('PaletteProcessData', 'r.PaletteProcessData', 'zigimg.PngPaletteProcessData', {'palette': ('&.{}', '[]zigimg.Rgba32{}')}, {'temp_allocator': 'allocator'}),
    ('RowProcessData', 'r.RowProcessData', 'zigimg.PngRowProcessData', {
        'dest_row': ('&.{}', '[]u8{}'), 'src_format': ('.invalid', '.invalid'),
        'dest_format': ('.invalid', '.invalid'), 'header': ('&header', '&header')}, {'temp_allocator': 'allocator'}),
    ('ReaderProcessor', 'r.ReaderProcessor', 'zigimg.PngReaderProcessor', {
        'id': ('0', '0'), 'context': ('&context', 'unsafe{voidptr(&context)}'), 'vtable': ('&table', '&table')}, {}),
    ('VTable', 'VTable', 'zigimg.PngReaderProcessorVTable', {
        'chunk_processor': ('null', 'none'), 'palette_processor': ('null', 'none'), 'data_row_processor': ('null', 'none')}, {}),
    ('Custom1', 'r.CustomReaderOptions1(r.TrnsProcessor)', 'zigimg.PngCustomReaderOptions1[zigimg.PngTrnsProcessor]', {'processor': ('.{}', 'zigimg.PngTrnsProcessor{}')}, {}),
    ('Custom2', 'r.CustomReaderOptions2(r.TrnsProcessor,r.PlteProcessor)', 'zigimg.PngCustomReaderOptions2[zigimg.PngTrnsProcessor,zigimg.PngPlteProcessor]', {
        'processor1': ('.{}', 'zigimg.PngTrnsProcessor{}'), 'processor2': ('.{}', 'zigimg.PngPlteProcessor{}')}, {}),
]
PAYLOADS = [('gray', 'PngTrnsGray', 'value', '7', '7'),
            ('rgb', 'PngTrnsRGB', 'color', '.{.r=1,.g=2,.b=3}', 'zigimg.Rgb48{r:1,g:2,b:3}'),
            ('index_alpha', 'PngTrnsIndexAlpha', 'data', '&.{}', '[]u8{}')]


def z_consumer(body):
    return ('const std=@import("std");const r=@import("src/formats/png/reader.zig");'
            'const png=@import("src/formats/png/types.zig");const io=@import("src/io.zig");'
            'const allocator=std.heap.page_allocator;'
            'const VTable=@typeInfo(@FieldType(r.ReaderProcessor,"vtable")).pointer.child;'
            'const TrnsData=@FieldType(r.TrnsProcessor,"trns_data");'
            'pub fn main() void {var stream=io.ReadStream.initMemory(&.{});'
            'var header:png.HeaderData=' + HEADER_Z + ';var context:u8=0;var table:VTable=' + VT_Z + ';'
            '_=&stream;_=&header;_=&context;_=&table;' + body + '}\n')


def v_consumer(body):
    return ('module main\nimport zigimg\nfn main(){\n'
            'mut stream:=zigimg.ReadStream.init_memory([]u8{})\nmut header:=' + HEADER_V + '\n'
            'mut context:=u8(0)\nmut table:=' + VT_V + '\n_=stream\n_=header\n_=context\n_=table\n' + body + '\n}\n')


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
    source, zig, v = args.source.resolve() / 'src', args.zig.resolve(), args.v.resolve()
    if tree_hash(source) != PINNED_SOURCE_SHA256 or memory_hash(zig) != PINNED_MEMORY_SHA256:
        parser.error('Source or compiler library differs from the pins')
    mode = args.zig_mode or ('ReleaseSafe' if args.v_prod else 'Debug')
    repo = Path(__file__).resolve().parent.parent
    probe = repo / 'zigimg/reference_probes/png_processor_records'
    env = dict(os.environ, VEXE=str(v), V_C_ERROR_BUG_REPORT_DISABLED='1')
    with work_directory(args.workdir, 'witty-png-processor-records-') as root:
        proof = ProofLog(root)
        shutil.copytree(source, root / 'src')
        fixtures = {}
        for name in ('reference.zig', 'main.v', 'boxed.zig', 'boxed.v'):
            shutil.copyfile(probe / name, root / name)
            fixtures[name] = hashlib.sha256((root / name).read_bytes()).hexdigest()
        if tree_hash(root / 'src') != PINNED_SOURCE_SHA256: raise AssertionError('copied Source changed')
        versions = [proof.run([str(exe), 'version'], label, env=env).stdout.decode().strip()
                    for exe, label in ((zig, 'zig-version'), (v, 'v-version'))]
        if versions[0] != '0.15.2' or not re.match(r'^V 0\.5\.2(?: |$)', versions[1]):
            raise AssertionError('unexpected compiler versions')
        implementation = repo / 'zigimg/png_processors.v'
        provenance = {'source_sha256': PINNED_SOURCE_SHA256, 'memory_sha256': PINNED_MEMORY_SHA256,
                      'versions': versions, 'zig_mode': mode, 'v_prod': args.v_prod, 'target': args.target,
                      'fixtures': fixtures, 'implementation_sha256': hashlib.sha256(implementation.read_bytes()).hexdigest(),
                      'runner_sha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest()}
        (root / 'provenance.json').write_text(json.dumps(provenance, indent=2) + '\n')
        zbase = [str(zig), 'build-exe', '-target', args.target, '-lc', '-O', mode,
                 '--global-cache-dir', str(root / 'zig-global')]
        vbase = [str(v), '-enable-globals', *(['-prod'] if args.v_prod else []), '-path', f'{repo}|@vlib|@vmodules']
        print(f'Building PNG processor records: {mode}, V {"production" if args.v_prod else "ordinary"}', flush=True)
        for fixture, exe in (('reference', 'native'), ('boxed', 'native-boxed')):
            proof.run(zbase + ['-femit-bin=' + str(root / exe), str(root / (fixture + '.zig'))], 'build-' + exe, timeout=args.timeout)
        for fixture, exe in (('main', 'translated'), ('boxed', 'translated-boxed')):
            proof.run(vbase + ['-o', str(root / exe), str(root / (fixture + '.v'))], 'build-' + exe, env=env, timeout=args.timeout)
        outputs = []
        for exe in ('native', 'translated'):
            result = proof.run([str(root / exe)], 'returning-' + exe, timeout=args.timeout)
            if result.stderr or len(result.stdout.splitlines()) != EXPECTED_ROWS: raise AssertionError('invalid returning output')
            outputs.append(result.stdout.splitlines())
        for index, (native, translated) in enumerate(zip(*outputs)):
            if native != translated: raise AssertionError(f'record {index}: Source={native!r}, V={translated!r}')
        digest = hashlib.sha256(b'\n'.join(outputs[0])).hexdigest()
        if EXPECTED_SHA256 is not None and digest != EXPECTED_SHA256: raise AssertionError('returning golden changed')
        boxed, boxed_hashes = [], []
        for exe, expected in zip(('native-boxed', 'translated-boxed'), (EXPECTED_SOURCE_BOX_SHA256, EXPECTED_V_BOX_SHA256)):
            result = proof.run([str(root / exe)], 'boxed-' + exe, timeout=args.timeout)
            if result.stderr or len(result.stdout.splitlines()) != 12: raise AssertionError('invalid boxed observations')
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

        def record(kind, vkind, fields, fixed, missing=None):
            zfields = ','.join(['.' + name + '=' + value[0] for name, value in fields.items() if name != missing]
                               + ['.' + name + '=' + value for name, value in fixed.items()])
            vfields = ','.join(name + ':' + value[1] for name, value in fields.items() if name != missing)
            return 'const x:' + kind + '=.{' + zfields + '};_=x;', 'x:=' + vkind + '{' + vfields + '}\n_=x'

        omissions = generic_adaptations = 0
        print('Checking complete constructors and required field omissions', flush=True)
        for label, kind, vkind, fields, fixed in CONTRACTS:
            pair('complete-' + label, *record(kind, vkind, fields, fixed))
            for missing in fields:
                generic = label in ('Custom1', 'Custom2')
                pair('missing-' + label + '-' + missing, *record(kind, vkind, fields, fixed, missing),
                     'missing struct field: ' + missing, None if generic else vkind + '.' + missing)
                if generic: generic_adaptations += 1
                else: omissions += 1
        for tag, vkind, field, zvalue, vvalue in PAYLOADS:
            pair('complete-' + tag, 'const x:TrnsData=.{.' + tag + '=' + zvalue + '};_=x;',
                 'x:=zigimg.' + vkind + '{' + field + ':' + vvalue + '}\n_=x')
            pair('missing-' + tag, 'const x:TrnsData=.' + tag + ';_=x;', 'x:=zigimg.' + vkind + '{}\n_=x',
                 'must initialize', 'zigimg.' + vkind + '.' + field)
            omissions += 1
        for label, zkind, vkind in (('ReaderOptions', 'r.ReaderOptions', 'PngReaderOptions'),
                                  ('TrnsProcessor', 'r.TrnsProcessor', 'PngTrnsProcessor'),
                                  ('PlteProcessor', 'r.PlteProcessor', 'PngPlteProcessor')):
            pair('default-' + label, 'const x:' + zkind + '=.{};_=x;', 'x:=zigimg.' + vkind + '{}\n_=x')
        pair('complete-default-alias', 'const x:r.DefaultOptions=.{.processor=.{}};_=x;',
             'x:=zigimg.PngDefaultOptions{processor:zigimg.PngTrnsProcessor{}}\n_=x')
        pair('missing-default-alias', 'const x:r.DefaultOptions=.{};_=x;',
             'x:=zigimg.PngDefaultOptions{}\n_=x', 'missing struct field: processor')
        pair('readonly-processor', 'const x:r.ReaderProcessor=.{.id=0,.context=&context,.vtable=&table};x.id=1;',
             'x:=zigimg.PngReaderProcessor{id:0,context:unsafe{voidptr(&context)},vtable:&table}\nx.id=1',
             'cannot assign to constant', 'immutable')
        pair('readonly-vtable', 'const x:VTable=' + VT_Z + ';x.chunk_processor=null;',
             'x:=' + VT_V + '\nx.chunk_processor=none', 'cannot assign to constant', 'immutable')
        pair('const-vtable-pointee', 'const x:r.ReaderProcessor=.{.id=0,.context=&context,.vtable=&table};x.vtable.chunk_processor=null;',
             'mut x:=zigimg.PngReaderProcessor{id:0,context:unsafe{voidptr(&context)},vtable:&table}\nx.vtable.chunk_processor=none',
             'cannot assign to constant')
        pair('const-header-pointee', 'const x:r.RowProcessData=.{.dest_row=&.{},.src_format=.invalid,.dest_format=.invalid,.header=&header,.temp_allocator=allocator};x.header.width=1;',
             'mut x:=zigimg.PngRowProcessData{dest_row:[]u8{},src_format:.invalid,dest_format:.invalid,header:&header}\nx.header.width=1',
             'cannot assign to constant')
        if (tree_hash(source) != PINNED_SOURCE_SHA256 or tree_hash(root / 'src') != PINNED_SOURCE_SHA256
                or memory_hash(zig) != PINNED_MEMORY_SHA256): raise AssertionError('dependency changed')
        for name, expected in fixtures.items():
            if any(hashlib.sha256(p.read_bytes()).hexdigest() != expected for p in (root / name, probe / name)):
                raise AssertionError('fixture changed: ' + name)
        if (hashlib.sha256(Path(__file__).read_bytes()).hexdigest() != provenance['runner_sha256']
                or hashlib.sha256(implementation.read_bytes()).hexdigest() != provenance['implementation_sha256']):
            raise AssertionError('runner or implementation changed')
        summary = {'returning_records': EXPECTED_ROWS, 'sha256': digest, 'complete_constructor_pairs': 14,
                   'required_field_pairs': omissions, 'generic_marker_adaptations': generic_adaptations,
                   'readonly_rejection_pairs': 2, 'default_alias_adaptations': 1,
                   'const_pointee_adaptations': 2, 'boxed_copy_records': 12,
                   'boxed_copy_divergences': sum(a != b for a, b in zip(*boxed)), 'boxed_copy_hashes': boxed_hashes,
                   'zig_mode': mode, 'v_prod': args.v_prod}
        (root / 'result.json').write_text(json.dumps(summary, indent=2) + '\n')
        print(json.dumps(summary), flush=True)


if __name__ == '__main__': main()
