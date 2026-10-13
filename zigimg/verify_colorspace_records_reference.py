"""Compare required RGB colorspace records, copies and callback dispatch."""
import argparse
from collections import Counter
import hashlib
import itertools
import json
import os
from pathlib import Path
import random
import re
import shutil

from verify_jpeg_contracts_reference import implementation_hashes
from verify_tga_decode_reference import stdlib_hash, PINNED_STDLIB_SHA256
from verify_tiff_decode_reference import ProofLog, tree_hash, work_directory, PINNED_SOURCE_SHA256
from verify_matrix_contracts_reference import MATH_HASHES
from verify_simd_reference import ordinary_rejection

FIELDS = ('red', 'green', 'blue', 'white', 'rgba_to_xyza', 'xyza_to_rgba',
          'to_gamma', 'to_gamma_fast', 'to_linear', 'to_linear_fast')
V_FIELDS = FIELDS[:6] + tuple(name + '_fn' for name in FIELDS[6:])
EXPECTED_RETURNS = 7920
EXPECTED_SHA256 = {
    'ordinary': '20d49e2104dc25aa362ce0ffc8347fa7b074c17c154fe7c5f5531412f9eba1ad',
    'production': '20d49e2104dc25aa362ce0ffc8347fa7b074c17c154fe7c5f5531412f9eba1ad',
}


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def corpus():
    boundaries = (0, 0x80000000, 1, 0x80000001, 0x00800000, 0x3f800000,
                  0xbf800000, 0x7f7fffff, 0x7f800000, 0xff800000, 0x7fc01234, 0x7f800001)
    rows = []
    rng = random.Random(0xd7b7ab0b)
    for form, operation, field in itertools.product(range(3), range(6), range(10)):
        group = f'form-{form}-operation-{operation}'
        for seed, index in itertools.product((0, 7, 255), range(len(boundaries))):
            pixel = [boundaries[(index + i) % len(boundaries)] for i in range(4)]
            rows.append((group, f'{group}-field-{field}-seed-{seed}-pixel-{index}',
                         '|'.join(map(str, (form, operation, field, seed, *pixel)))))
        for index in range(8):
            pixel = [rng.getrandbits(32) for _ in range(4)]
            rows.append((group, f'{group}-field-{field}-random-{index}',
                         '|'.join(map(str, (form, operation, field, rng.randrange(256), *pixel)))))
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
    source, zig, v = args.source.resolve() / 'src', args.zig.resolve(), args.v.resolve()
    math_dir = zig.parent / 'lib/std/math'
    if (tree_hash(source) != PINNED_SOURCE_SHA256 or stdlib_hash(zig) != PINNED_STDLIB_SHA256
            or any(digest(math_dir / name) != expected for name, expected in MATH_HASHES.items())):
        parser.error('Source or library differs from pins')
    repo = Path(__file__).resolve().parent.parent
    probe = repo / 'zigimg/reference_probes/colorspace_records'
    mode = 'production' if args.v_prod else 'ordinary'
    native_mode = 'ReleaseSafe' if args.v_prod else 'Debug'
    with work_directory(args.workdir, 'witty-colorspace-records-') as root:
        proof = ProofLog(root)
        tmp = root / 'tmp'; tmp.mkdir()
        env = dict(os.environ, VEXE=str(v), V_C_ERROR_BUG_REPORT_DISABLED='1', TMPDIR=str(tmp), VTMP=str(tmp))
        sdk = Path(proof.run(['xcrun', '--show-sdk-path'], 'sdk-path').stdout.decode().strip())
        sdk_math = sdk / 'usr/include/math.h'; sdk_hash = digest(sdk_math)
        shutil.copytree(source, root / 'src')
        fixtures = {}
        for name in ('main.v', 'reference.zig'):
            shutil.copyfile(probe / name, root / name)
            fixtures[name] = digest(probe / name)
        versions = [proof.run([str(exe), 'version'], label, env=env).stdout.decode().strip()
                    for exe, label in ((zig, 'zig-version'), (v, 'v-version'))]
        if versions[0] != '0.15.2' or not re.match(r'^V 0\.5\.2(?: |$)', versions[1]):
            raise AssertionError('unexpected compiler versions')
        implementations, runner_hash = implementation_hashes(repo), digest(Path(__file__))
        (root / 'provenance.json').write_text(json.dumps(dict(source_sha256=PINNED_SOURCE_SHA256,
            stdlib_sha256=PINNED_STDLIB_SHA256, math_sha256=MATH_HASHES, versions=versions,
            target=args.target, zig_mode=native_mode, v_prod=args.v_prod, fixtures=fixtures,
            sdk_math=dict(path=str(sdk_math), sha256=sdk_hash),
            implementation_sha256=implementations, runner_sha256=runner_hash), indent=2) + '\n')
        zbase = [str(zig), 'build-exe', '-target', args.target, '-lc', '-O', native_mode,
                 '--global-cache-dir', str(root / 'zig-global'), '--cache-dir', str(root / 'zig-cache')]
        vbase = [str(v), '-enable-globals', *(['-prod'] if args.v_prod else []), '-path', f'{repo}|@vlib|@vmodules']
        print(f'Building colorspace records: Source {native_mode}, V {mode}', flush=True)
        proof.run(zbase + ['-femit-bin=' + str(root / 'native'), str(root / 'reference.zig')], 'build-source', timeout=args.timeout)
        proof.run(vbase + ['-o', str(root / 'translated'), str(root / 'main.v')], 'build-v', env=env, timeout=args.timeout)
        rows = corpus(); file = root / 'corpus.txt'
        file.write_text('\n'.join(row for group, name, row in rows) + '\n')
        inputs = {file.name: digest(file)}; outputs = []
        for exe in ('native', 'translated'):
            result = proof.run([str(root / exe), str(file)], 'corpus-' + exe, timeout=args.timeout, check=False)
            if result.returncode or result.stderr:
                raise AssertionError(f'corpus-{exe} failed; see retained stdout/stderr')
            outputs.append(result.stdout.splitlines())
        if any(len(output) != len(rows) for output in outputs):
            raise AssertionError('corpus counts differ')
        h, groups = hashlib.sha256(), Counter()
        for (group, name, row), native, translated in zip(rows, *outputs):
            if native != translated:
                raise AssertionError(f'{name}: record/callback output differs; input {row}')
            h.update(name.encode() + b'\0' + native + b'\n'); groups[group] += 1
        print(f'{len(rows)} colorspace records, SHA256 {h.hexdigest()}', flush=True)
        consumers = {}
        zvalues = ('.{}',) * 4 + ('m.float4x4.identity()',) * 2 + ('identity',) * 4
        vvalues = ('c.CIExyY{}',) * 4 + ('c.Float4x4.identity()',) * 2 + ('identity',) * 4
        zinit = 'c.RgbColorspace{' + ','.join('.' + name + '=' + value for name, value in zip(FIELDS, zvalues)) + '}'
        vinit = 'c.RgbColorspace{' + ','.join(name + ':' + value for name, value in zip(V_FIELDS, vvalues)) + '}'

        def pair(label, zbody, vbody, zmarker=None, vmarker=None):
            paths = [root / (label + '.zig'), root / (label + '.v')]
            paths[0].write_text('const c=@import("src/color.zig");const m=@import("src/math.zig");fn identity(x:f32) f32{return x;}pub fn main() void {' + zbody + '}\n')
            paths[1].write_text('module main\nimport zigimg as c\nfn identity(x f32) f32{return x}\nfn main(){\n' + vbody + '\n}\n')
            for path in paths:consumers[path.name] = digest(path)
            for language, command, marker in (
                    ('Source', zbase + ['-fno-emit-bin', str(paths[0])], zmarker),
                    ('V', vbase + ['-check', '-o', str(root / (label + '-checked')), str(paths[1])], vmarker)):
                result = proof.run(command, label + '-' + language, env=env, timeout=args.timeout, check=False)
                diagnostic = (result.stdout + result.stderr).decode(errors='replace')
                errors = [line for line in diagnostic.splitlines() if re.search(r'\berror:', line)]
                if marker is None:
                    if result.returncode or errors:raise AssertionError(f'{label}/{language}: expected acceptance; see retained diagnostics')
                else:
                    ordinary_rejection(result, label + '/' + language)
                    if not any(marker in line for line in errors):raise AssertionError(f'{label}/{language}: missing {marker!r}; see retained diagnostics')
        pair('explicit-record', 'const x=' + zinit + ';_=x.red.x;', 'x:=' + vinit + '\n_=x.red.x')
        pair('default-init-args', 'const x=c.RgbColorspace.init(.{});_=x.red.x;', 'x:=c.RgbColorspace.init(c.RgbColorspaceInitArgs{})\n_=x.red.x')
        pair('mutable-record', 'var x=' + zinit + ';x.red.x=1;x.to_gamma=identity;_=x.red.x;',
             'mut x:=' + vinit + '\nx.red.x=1\nx.to_gamma_fn=identity\n_=x.red.x')
        for index, (zfield, vfield) in enumerate(zip(FIELDS, V_FIELDS)):
            zm = 'c.RgbColorspace{' + ','.join('.' + name + '=' + value for name, value in zip(FIELDS, zvalues) if name != zfield) + '}'
            vm = 'c.RgbColorspace{' + ','.join(name + ':' + value for name, value in zip(V_FIELDS, vvalues) if name != vfield) + '}'
            pair('missing-' + zfield, 'const x=' + zm + ';_=x;', 'x:=' + vm + '\n_=x',
                 'missing struct field: ' + zfield, '.' + vfield + '` must be initialized')
            pair('immutable-' + zfield, 'const x=' + zinit + ';x.' + zfield + '=' + zvalues[index] + ';',
                 'x:=' + vinit + '\nx.' + vfield + '=' + vvalues[index], 'cannot assign to constant', 'immutable')
        (root / 'input_sha256.json').write_text(json.dumps(inputs, indent=2) + '\n')
        (root / 'consumer_sha256.json').write_text(json.dumps(consumers, indent=2) + '\n')
        for name, expected in {**inputs, **consumers}.items():
            if digest(root / name) != expected:raise AssertionError('input or consumer changed')
        if (tree_hash(source) != PINNED_SOURCE_SHA256 or tree_hash(root / 'src') != PINNED_SOURCE_SHA256
                or stdlib_hash(zig) != PINNED_STDLIB_SHA256
                or any(digest(math_dir / name) != expected for name, expected in MATH_HASHES.items())
                or digest(sdk_math) != sdk_hash or implementation_hashes(repo) != implementations
                or digest(Path(__file__)) != runner_hash):raise AssertionError('dependency, implementation or runner changed')
        for name, expected in fixtures.items():
            if any(digest(path) != expected for path in (root / name, probe / name)):raise AssertionError('fixture changed')
        summary = dict(returning_records=len(rows), return_groups=dict(groups), sha256=h.hexdigest(),
                       accepted_record_pairs=3, required_field_rejection_pairs=10, immutable_rejection_pairs=10)
        (root / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n'); print(json.dumps(summary, indent=2), flush=True)
        if len(rows) != EXPECTED_RETURNS or h.hexdigest() != EXPECTED_SHA256[mode]:raise AssertionError('locked colorspace record golden changed')


if __name__ == '__main__':main()
