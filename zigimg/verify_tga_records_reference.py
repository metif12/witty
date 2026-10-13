"""Compare TGA public records and checked mutations with unchanged pinned Source."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil

from verify_jpeg_contracts_reference import implementation_hashes, stdlib_hash, PINNED_STDLIB_SHA256
from verify_tiff_decode_reference import ProofLog, tree_hash, work_directory, PINNED_SOURCE_SHA256, checked_trap
from verify_simd_reference import ordinary_rejection

EXPECTED_ROWS = 274453
EXPECTED_SHA256 = '1a09cac1be76dea9fab61a3a330b4f0c484f4f67e5bc08e1cfe0e2f1e719ad36'
EXPECTED_STATE_SHA256 = 'dc9cb7be7b9c8d24f9cbf71550f8deba334d670042f07ab523795fd328586880'


def decode_cases():
    def image(kind=1, first=0, length=1, depth=24, bits=8):
        data = bytearray(48)
        data[0] = 3
        data[2] = kind
        data[3:5] = first.to_bytes(2, 'little')
        data[5:7] = length.to_bytes(2, 'little')
        data[7] = depth
        data[16] = bits
        data[18:21] = b'ID!'
        return data
    cases = {}
    for bits in range(249, 256):
        cases[f'pixel-byte-{bits}'] = (image(kind=11, bits=bits), 'integer overflow', 'integer overflow')
    for first, length in ((65535, 1), (65534, 2)):
        cases[f'palette-sum-{first}-{length}'] = (image(first=first, length=length), 'integer overflow', 'integer overflow')
    for depth in (16, 24):
        cases[f'palette-index-{depth}'] = (image(first=1, depth=depth), 'index out of bounds',
                                         'index out of bounds' if depth == 24 else 'array.get: index out of range')
    eof = image(first=1)[:26]
    eof[0] = 8
    cases['palette-index-before-eof'] = (eof, 'index out of bounds', 'index out of bounds')
    cases['palette-capacity'] = (image(length=257), 'reached unreachable code', 'reached unreachable code')
    # RLE byte arithmetic precedes palette resizing and palette-end arithmetic.
    cases['byte-before-capacity'] = (image(kind=9, length=257, bits=255), 'integer overflow', 'integer overflow')
    cases['capacity-before-sum'] = (image(first=65535, length=257), 'reached unreachable code', 'reached unreachable code')
    return cases


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
    if args.timeout <= 0:
        parser.error('--timeout must be positive')
    source = args.source.resolve() / 'src'
    zig, v = args.zig.resolve(), args.v.resolve()
    if tree_hash(source) != PINNED_SOURCE_SHA256 or stdlib_hash(zig) != PINNED_STDLIB_SHA256:
        parser.error('Source or selected compiler library differs from the pins')
    mode = args.zig_mode or ('ReleaseSafe' if args.v_prod else 'Debug')
    repo = Path(__file__).resolve().parent.parent
    probe = repo / 'zigimg/reference_probes/tga_records'
    env = dict(os.environ, VEXE=str(v), V_C_ERROR_BUG_REPORT_DISABLED='1')
    with work_directory(args.workdir, 'witty-tga-records-') as root:
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
        vbase = [str(v), '-enable-globals', *(['-prod'] if args.v_prod else []),
                 '-path', f'{repo}|@vlib|@vmodules']
        print(f'Building TGA records: Source {mode}, V {"production" if args.v_prod else "ordinary"}', flush=True)
        proof.run(zbase + ['-femit-bin=' + str(root / 'native'), str(root / 'reference.zig')],
                  'build-source', timeout=args.timeout)
        proof.run(vbase + ['-o', str(root / 'translated'), str(root / 'main.v')],
                  'build-v', env=env, timeout=args.timeout)
        outputs = []
        for exe in ('native', 'translated'):
            r = proof.run([str(root / exe)], 'returning-' + exe, timeout=args.timeout)
            if r.stderr or len(r.stdout.splitlines()) != EXPECTED_ROWS:
                raise AssertionError(f'{exe}: invalid returning output; see raw proof files')
            outputs.append(r.stdout.splitlines())
        for index, (native, translated) in enumerate(zip(*outputs)):
            if native != translated:
                raise AssertionError(f'{index}: Source={native!r}, V={translated!r}')
        digest = hashlib.sha256(b'\n'.join(outputs[0])).hexdigest()
        if EXPECTED_SHA256 is not None and digest != EXPECTED_SHA256:
            raise AssertionError('returning golden changed')
        print(f'{EXPECTED_ROWS} returning rows match; checking failure state and compiler controls', flush=True)
        states = hashlib.sha256()

        def trap(name, arguments, zcategory, vcategory):
            observed = []
            for exe, category in (('native', zcategory), ('translated', vcategory)):
                path = root / (name + '-' + exe + '.state')
                r = proof.run([str(root / exe), arguments[0], str(path), *arguments[1:]],
                              name + '-' + exe, timeout=args.timeout, check=False)
                checked_trap(r, name + '/' + exe, category)
                if not path.exists():
                    raise AssertionError('missing panic observer')
                observed.append(path.read_bytes())
            if not observed[0] or observed[0] != observed[1]:
                raise AssertionError(f'{name}: differing states {observed}')
            states.update(name.encode() + b'\0' + observed[0] + b'\n')

        for field, values in (('pad1', (16, 17, 255)), ('attributes', (16, 17, 255)), ('pad', (4, 5, 255))):
            for value in values:
                trap(f'narrow-{field}-{value}', ['--narrow', field, str(value)],
                     'integer does not fit in destination type', 'integer does not fit in destination type')
        for name, (data, zcategory, vcategory) in decode_cases().items():
            path = root / (name + '.tga')
            path.write_bytes(data)
            trap(name, ['--decode', str(path)], zcategory, vcategory)
        state_digest = states.hexdigest()
        if EXPECTED_STATE_SHA256 is not None and state_digest != EXPECTED_STATE_SHA256:
            raise AssertionError('failure-state golden changed')

        def pair(label, zbody, vbody, zmarker=None, vmarker=None):
            zp, vp = root / (label + '.zig'), root / (label + '.v')
            zp.write_text('const p=@import("src/formats/tga.zig");pub fn main() void {' + zbody + '}\n')
            vp.write_text('module main\nimport zigimg as p\nfn main(){\n' + vbody + '\n}\n')
            for language, command, marker in (
                    ('Source', zbase + ['-fno-emit-bin', str(zp)], zmarker),
                    ('V', vbase + ['-check', str(vp)], vmarker)):
                r = proof.run(command, label + '-' + language, env=env, timeout=args.timeout, check=False)
                diagnostic = (r.stdout + r.stderr).decode(errors='replace')
                errors = [line for line in diagnostic.splitlines() if re.search(r'\berror:', line)]
                if marker is None:
                    if r.returncode or errors:
                        raise AssertionError(f'{label}/{language}: expected acceptance\n{diagnostic}')
                else:
                    ordinary_rejection(r, label + '/' + language)
                    if not any(marker in line for line in errors):
                        raise AssertionError(f'{label}/{language}: missing actual error {marker!r}\n{diagnostic}')

        immutable = 0
        for kind, field, setter, value in (
                ('TGAImageType', 'indexed', 'set_indexed', 'true'),
                ('TGAImageType', 'truecolor', 'set_truecolor', 'true'),
                ('TGAImageType', 'pad0', 'set_pad0', 'true'),
                ('TGAImageType', 'run_length', 'set_run_length', 'true'),
                ('TGAImageType', 'pad1', 'set_pad1', '1'),
                ('TGADescriptor', 'num_attributes_bit', 'set_num_attributes_bit', '1'),
                ('TGADescriptor', 'right_to_left', 'set_right_to_left', 'true'),
                ('TGADescriptor', 'top_to_bottom', 'set_top_to_bottom', 'true'),
                ('TGADescriptor', 'pad', 'set_pad', '1')):
            pair('immutable-' + kind + '-' + field, 'const x:p.' + kind + '=.{};x.' + field + '=' + value + ';',
                 'x:=p.' + kind + '{}\nx.' + setter + '(' + value + ')', 'cannot assign to constant', 'immutable')
            immutable += 1
        for field, value in (('rle_compressed', 'false'), ('top_to_bottom_image', 'false'), ('color_map_depth', '16')):
            pair('immutable-options-' + field, 'const x:p.TGA.EncoderOptions=.{};x.' + field + '=' + value + ';',
                 'x:=p.TgaEncoderOptions{}\nx.' + field + '=' + value, 'cannot assign to constant', 'immutable')
            immutable += 1
        for kind, field, setter, value in (('TGAImageType', 'pad1', 'set_pad1', '16'),
                                         ('TGADescriptor', 'num_attributes_bit', 'set_num_attributes_bit', '16'),
                                         ('TGADescriptor', 'pad', 'set_pad', '4')):
            pair('literal-' + field, 'var x:p.' + kind + '=.{};x.' + field + '=' + value + ';_=x;',
                 'mut x:=p.' + kind + '{}\nx.' + setter + '(' + value + ')', 'cannot represent integer value', None)
        pair('const-id-pointee',
             'var data=[_]u8{1,2,3};var x:p.TGA.EncoderOptions=.{.image_id=&data};x.image_id[0]=9;',
             'mut data:=[u8(1),2,3]\nmut x:=p.TgaEncoderOptions{image_id:data}\nx.image_id[0]=9',
             'cannot assign to constant', None)
        lengths = []
        for exe, expected in (('native', b'40,40,40,80\n'), ('translated', b'41,41,41,81\n')):
            r = proof.run([str(root / exe), '--lengths'], 'lengths-' + exe, timeout=args.timeout)
            if r.stderr or r.stdout != expected:
                raise AssertionError('sentinel length observation changed')
            lengths.append(r.stdout.decode().strip())
        if (tree_hash(source) != PINNED_SOURCE_SHA256 or tree_hash(root / 'src') != PINNED_SOURCE_SHA256
                or stdlib_hash(zig) != PINNED_STDLIB_SHA256 or implementation_hashes(repo) != implementations
                or hashlib.sha256(Path(__file__).read_bytes()).hexdigest() != runner_hash):
            raise AssertionError('dependency, implementation or runner changed')
        for name, expected in fixtures.items():
            if any(hashlib.sha256((p / name).read_bytes()).hexdigest() != expected for p in (root, probe)):
                raise AssertionError('fixture changed')
        summary = dict(returning_records=EXPECTED_ROWS, image_type_mutations=6144, descriptor_mutations=6144,
                       header_validation=262144, record_and_option_rows=21, output_sha256=digest,
                       paired_traps=9 + len(decode_cases()), state_sha256=state_digest,
                       immutable_rejections=immutable, narrow_literal_differences=3,
                       const_id_pointee_differences=1,
                       sentinel_lengths=lengths, zig_mode=mode, v_prod=args.v_prod)
        (root / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
        print(json.dumps(summary), flush=True)


if __name__ == '__main__':
    main()
