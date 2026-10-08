"""Compare direct PNG chunk-writer record contracts against unchanged source."""
import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import shutil

from verify_png_header_reference import STDLIB_FILES, PINNED_STDLIB_SHA256
from verify_png_foundation_reference import PINNED_SOURCE_SHA256
from verify_simd_reference import ordinary_rejection
from verify_tiff_decode_reference import ProofLog, tree_hash, work_directory

REPO = Path(__file__).resolve().parent.parent
PROBE = REPO / 'zigimg/reference_probes/png_chunk_records'
EXPECTED_ROWS = 163
EXPECTED_SHA256 = '54fe144e5a027d6259fa65b01ae19169fd5470bf14f350593635306bd6dd9ec9'


def stdlib_hash(zig):
    digest = hashlib.sha256()
    for name in STDLIB_FILES:
        digest.update(name.encode() + b'\0')
        digest.update((zig.parent / 'lib/std' / name).read_bytes())
    return digest.hexdigest()


def positive_timeout(value):
    result = float(value)
    if not math.isfinite(result) or result <= 0:
        raise argparse.ArgumentTypeError('timeout must be finite and positive')
    return result


def expect_success(result, label):
    if result.returncode or result.stderr:
        raise AssertionError(f'{label}: expected normal return\n' +
                             (result.stdout + result.stderr).decode(errors='replace'))


def require_rejection(result, label, *markers):
    ordinary_rejection(result, label)
    diagnostic = (result.stdout + result.stderr).decode(errors='replace')
    if any(marker not in diagnostic for marker in markers):
        raise AssertionError(f'{label}: wrong ordinary rejection\n{diagnostic}')


def omission_consumers(root, native_prefix, v_prefix):
    v_body = []
    cases = []
    for alias in (False, True):
        for missing in ('writer', 'section', 'both'):
            label = ('alias' if alias else 'direct') + '-' + missing
            native_type = 'RecordAlias' if alias else 'cw.ChunkWriter(4, Adapter)'
            native_fields, v_fields = [], []
            if missing not in ('writer', 'both'):
                native_fields.append('.unbuffered_writer=.{.output=&output}')
                v_fields.append('unbuffered_writer: Adapter{ output: &output }')
            if missing not in ('section', 'both'):
                native_fields.append('.section_id="IDAT".*')
                v_fields.append('section_id: [u8(`I`), `D`, `A`, `T`]!')
            native = root / (label + '.zig')
            native.write_text(native_prefix + '\nconst RecordAlias=cw.ChunkWriter(4,Adapter);\n'
                              'pub fn main() void { var destination:[32]u8=undefined; '
                              'var output=Output{.stream=std.Io.Writer.fixed(&destination)}; _=&output; '
                              f'const record={native_type}{{' + ','.join(native_fields) + '}; _=record.end; }\n')
            cases.append((label, native, missing))
            v_type = 'RecordAlias' if alias else 'zigimg.PngChunkWriter[Bytes4, Adapter]'
            v_body += [f' record_{label.replace("-", "_")}:={v_type}{{' + ','.join(v_fields) + '}',
                       f' print_omission("{label}", record_{label.replace("-", "_")}.unbuffered_writer.output == unsafe {{ nil }}, '
                       f'record_{label.replace("-", "_")}.end, record_{label.replace("-", "_")}.section_id[..])']
    v_file = root / 'omissions.v'
    v_file.write_text(v_prefix + '\ntype Bytes4=[4]u8\ntype RecordAlias=zigimg.PngChunkWriter[Bytes4,Adapter]\n'
                      'fn print_omission(label string, missing bool, end usize, section []u8) {'
                      'println("D|${label}|${missing}|${end}|${section.hex()}") }\n'
                      'fn main(){mut destination:=[]u8{len:32};mut output:=Output{stream:zigimg.WriteStream.init_memory(mut destination)}\n' +
                      '\n'.join(v_body) + '\n}\n')
    return cases, v_file


def storage_consumers(root, native_prefix, v_prefix):
    values = {
        'word-array': ('const buffer=[_]u16{1,2,3,4};', 'mut buffer:=[u16(1),2,3,4]!'),
        'pointer-array': ('var byte:u8=1; const buffer=[_]*u8{&byte} ** 4;',
                          'mut byte:=u8(1); buffer:=[&byte,&byte,&byte,&byte]!'),
        'pointer-alias-array': ('var byte:u8=1; const Pointer=*u8; const buffer=[_]Pointer{&byte} ** 4;',
                                'mut byte:=u8(1); buffer:=[Pointer(&byte),Pointer(&byte),Pointer(&byte),Pointer(&byte)]!'),
        'scalar': ('const buffer:u8=1;', 'buffer:=u8(1)'),
        'array-pointer': ('var bytes=[_]u8{1,2,3,4}; const buffer=&bytes;',
                          'mut bytes:=[u8(1),2,3,4]!; buffer:=&bytes'),
    }
    cases = []
    for name, (native_value, v_value) in values.items():
        native = root / (name + '.zig')
        native.write_text(native_prefix + '\npub fn main() void {var destination:[32]u8=undefined; '
                          'var output=Output{.stream=std.Io.Writer.fixed(&destination)}; ' + native_value +
                          ' const writer=cw.ChunkWriter(4,Adapter){.unbuffered_writer=.{.output=&output},'
                          '.section_id="IDAT".*,.buf=buffer}; _=writer.end;}\n')
        translated = root / (name + '.v')
        translated.write_text(v_prefix + '\ntype Pointer=&u8\nfn main(){mut destination:=[]u8{len:32}; '
                              'mut output:=Output{stream:zigimg.WriteStream.init_memory(mut destination)}; ' + v_value +
                              '; writer:=zigimg.png_chunk_writer_with_buffer(buffer,Adapter{output:&output},'
                              '[u8(`I`),`D`,`A`,`T`]!);println(writer.end)}\n')
        cases.append((name, native, translated))
    return cases


def verify(args, root):
    source = args.source.resolve() / 'src'
    zig = args.zig.resolve()
    if tree_hash(source) != PINNED_SOURCE_SHA256 or stdlib_hash(zig) != PINNED_STDLIB_SHA256:
        raise AssertionError('source/compiler differs from pinned dependency')
    shutil.copytree(source, root / 'src')
    if tree_hash(root / 'src') != PINNED_SOURCE_SHA256:
        raise AssertionError('copied source differs before compilation')
    fixtures = {}
    for name in ('reference.zig', 'main.v'):
        shutil.copyfile(PROBE / name, root / name)
        fixtures[name] = hashlib.sha256((PROBE / name).read_bytes()).hexdigest()
        if hashlib.sha256((root / name).read_bytes()).hexdigest() != fixtures[name]:
            raise AssertionError('copied fixture differs before compilation: ' + name)
    mode = args.zig_mode or ('ReleaseSafe' if args.v_prod else 'Debug')
    v_source_hash = hashlib.sha256((REPO / 'zigimg/png_chunk_writer.v').read_bytes()).hexdigest()
    runner_hash = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
    provenance = {
        'source_sha256': PINNED_SOURCE_SHA256, 'stdlib_sha256': PINNED_STDLIB_SHA256,
        'zig_mode': mode, 'v_prod': args.v_prod, 'target': args.target, 'fixtures': fixtures,
        'v_source_sha256': v_source_hash,
        'runner_sha256': runner_hash,
    }
    (root / 'provenance.json').write_text(json.dumps(provenance, indent=2) + '\n')
    proof = ProofLog(root)
    def run(argv, label, **options):
        return proof.run(argv, label, timeout=args.timeout, **options)
    native_base = [str(zig), 'build-exe', '-target', args.target, '-lc', '-O', mode,
                   '--global-cache-dir', str(root / 'zig-global')]
    v_base = [str(args.v.resolve()), *(['-prod'] if args.v_prod else []),
              '-path', f'{REPO}|@vlib|@vmodules']
    env = dict(os.environ, VEXE=str(args.v.resolve()), V_C_ERROR_BUG_REPORT_DISABLED='1')
    versions = {}
    for label, argv, expected in (('zig', [str(zig), 'version'], '0.15.2'),
                                  ('v', [str(args.v.resolve()), 'version'], 'V 0.5.2')):
        result = run(argv, 'version-' + label, env=env)
        expect_success(result, label + ' version')
        versions[label] = result.stdout.decode().strip()
        if versions[label] != expected:
            raise AssertionError(label + ': unsupported compiler version ' + versions[label])
    provenance['versions'] = versions
    (root / 'provenance.json').write_text(json.dumps(provenance, indent=2) + '\n')
    run(native_base + ['-femit-bin=' + str(root / 'native'), str(root / 'reference.zig')], 'build-source')
    run(v_base + ['-o', str(root / 'translated'), str(root / 'main.v')], 'build-v', env=env)
    returning = []
    for executable in ('native', 'translated'):
        result = run([str(root / executable)], 'returning-' + executable)
        expect_success(result, executable)
        returning.append(result.stdout)
    if returning[0] != returning[1] or len(returning[0].splitlines()) != EXPECTED_ROWS:
        raise AssertionError('record state/copy/byte-storage comparison differs')
    digest = hashlib.sha256(returning[0]).hexdigest()
    if digest != EXPECTED_SHA256:
        raise AssertionError('frozen record output hash changed: ' + digest)
    native_prefix = (root / 'reference.zig').read_text().split('const ByteAlias')[0]
    v_prefix = (root / 'main.v').read_text().split('type ByteAlias')[0]
    omission_cases, omissions = omission_consumers(root, native_prefix, v_prefix)
    for label, native, missing in omission_cases:
        result = run(native_base + ['-fno-emit-bin', str(native)], 'source-omission-' + label, check=False)
        markers = ['missing struct field: ' + field for field in
                   ({'writer': ('unbuffered_writer',), 'section': ('section_id',),
                     'both': ('unbuffered_writer', 'section_id')}[missing])]
        require_rejection(result, label, *markers)
    # Generic required attributes are ignored by pinned V. Measure full builds,
    # not only -check, without observing any source-undefined buffer bytes.
    run(v_base + ['-o', str(root / 'omissions'), str(omissions)], 'build-v-omissions', env=env)
    accepted = run([str(root / 'omissions')], 'v-omission-defaults')
    expect_success(accepted, 'generic omission acceptance')
    expected = []
    for alias in ('direct', 'alias'):
        for missing in ('writer', 'section', 'both'):
            nil = 'true' if missing in ('writer', 'both') else 'false'
            section = '49444154' if missing == 'writer' else '00000000'
            expected.append(f'D|{alias}-{missing}|{nil}|0|{section}')
    if accepted.stdout != ('\n'.join(expected) + '\n').encode():
        raise AssertionError('unexpected V generic omission defaults')
    storage = storage_consumers(root, native_prefix, v_prefix)
    for name, native, translated in storage:
        result = run(native_base + ['-fno-emit-bin', str(native)], 'source-storage-' + name, check=False)
        require_rejection(result, name, "expected type '[4]u8'")
        result = run(v_base + ['-check', str(translated)], 'v-storage-' + name, env=env, check=False)
        require_rejection(result, name, 'PNG chunk storage requires a fixed byte array')
    # Source permits record-only W values with no writer methods: its method
    # bodies/Error alias are lazy. V eagerly checks specialized generic methods.
    scalar_source = root / 'writer-scalar.zig'
    scalar_source.write_text('const std=@import("std"); const cw=@import("src/formats/png/chunk_writer.zig"); '
                             'pub fn main() !void {const record=cw.ChunkWriter(4,u32){.unbuffered_writer=9,'
                             '.section_id="IDAT".*};var stdout=std.fs.File.stdout().writer(&.{});'
                             'try stdout.interface.print("W|{d}|{d}|{s}\\n",.{record.unbuffered_writer,record.end,record.section_id});}\n')
    run(native_base + ['-femit-bin=' + str(root / 'writer-scalar'), str(scalar_source)], 'build-source-writer-scalar')
    scalar = run([str(root / 'writer-scalar')], 'source-writer-scalar')
    expect_success(scalar, 'source record-only scalar W')
    if scalar.stdout != b'W|9|0|IDAT\n': raise AssertionError('source scalar W default')
    scalar_v = root / 'writer-scalar.v'
    scalar_v.write_text('module main\nimport zigimg\ntype Bytes4=[4]u8\nfn main(){'
                        'record:=zigimg.PngChunkWriter[Bytes4,u32]{unbuffered_writer:9,'
                        'section_id:[u8(`I`),`D`,`A`,`T`]!};println(record.end)}\n')
    result = run(v_base + ['-check', str(scalar_v)], 'v-writer-scalar', env=env, check=False)
    require_rejection(result, 'V eager W methods', 'unknown method or field:', 'u32.write_int')
    # Slice-of-byte-alias is not a fixed array. The zero-capacity V carrier is
    # []u8 (or an alias of that exact slice), not arbitrary dynamic byte arrays.
    dynamic_v = root / 'dynamic-byte-alias.v'
    dynamic_v.write_text(v_prefix + '\ntype Byte=u8\nfn main(){mut destination:=[]u8{len:32};'
                         'mut output:=Output{stream:zigimg.WriteStream.init_memory(mut destination)};'
                         'buffer:=[]Byte{};writer:=zigimg.png_chunk_writer_with_buffer(buffer,'
                         'Adapter{output:&output},[u8(`I`),`D`,`A`,`T`]!);println(writer.end)}\n')
    result = run(v_base + ['-check', str(dynamic_v)], 'v-dynamic-byte-alias', env=env, check=False)
    require_rejection(result, 'V dynamic aliased-byte storage', 'PNG chunk storage requires a fixed byte array')
    if (tree_hash(source) != PINNED_SOURCE_SHA256 or tree_hash(root / 'src') != PINNED_SOURCE_SHA256 or
            stdlib_hash(zig) != PINNED_STDLIB_SHA256 or
            hashlib.sha256((REPO / 'zigimg/png_chunk_writer.v').read_bytes()).hexdigest() != v_source_hash or
            hashlib.sha256(Path(__file__).read_bytes()).hexdigest() != runner_hash or
            any(hashlib.sha256((PROBE / name).read_bytes()).hexdigest() != hash_value or
                hashlib.sha256((root / name).read_bytes()).hexdigest() != hash_value
                for name, hash_value in fixtures.items())):
        raise AssertionError('source/fixture changed during proof')
    provenance['consumers'] = {path.name: hashlib.sha256(path.read_bytes()).hexdigest()
                               for path in sorted(root.iterdir()) if path.suffix in ('.v', '.zig')}
    (root / 'provenance.json').write_text(json.dumps(provenance, indent=2) + '\n')
    summary = {'returning': EXPECTED_ROWS, 'sha256': digest, 'required_field_source_rejections': 6,
               'v_generic_omission_acceptances': 6, 'storage_rejection_pairs': len(storage),
               'record_only_w_boundary': 1, 'dynamic_byte_alias_v_rejection': 1,
               'zig_mode': mode, 'v_prod': args.v_prod}
    (root / 'result.json').write_text(json.dumps(summary, indent=2) + '\n')
    print(f'PNG chunk records {mode}: {EXPECTED_ROWS} returning records SHA256 {digest}; '
          f'6 Source omission rejections / 6 V generic accepts; {len(storage)} storage rejection pairs; '
          '1 record-only W and 1 V dynamic-byte-alias boundary', flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('zig', type=Path)
    parser.add_argument('v', type=Path)
    parser.add_argument('--target', default='aarch64-macos.14.0')
    parser.add_argument('--v-prod', action='store_true')
    parser.add_argument('--zig-mode', choices=('Debug', 'ReleaseSafe'))
    parser.add_argument('--workdir', type=Path)
    parser.add_argument('--timeout', type=positive_timeout, default=180)
    args = parser.parse_args()
    with work_directory(args.workdir, 'witty-png-chunk-records-') as root: verify(args, root)


if __name__ == '__main__': main()
