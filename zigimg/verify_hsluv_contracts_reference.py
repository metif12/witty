"""Compare HSLuv required fields, copies and ray evaluation with unchanged Source."""
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
from verify_color_models_reference import bits

BOUNDARIES = (0, 0x80000000, 1, 0x80000001, 0x007fffff, 0x00800000,
              0x3f7fffff, 0x3f800000, 0x3f800001, 0xbf800000, 0x7f7fffff,
              0xff7fffff, 0x7f800000, 0xff800000, 0x7fc00000, 0x7fc01234,
              0xffc05678, 0x7f800001, 0xff800001, 0x40000000)
EXPECTED_RETURNS = 9424
EXPECTED_SHA256 = {
    'ordinary': 'f07e05a03320b8b6fe232813a45686fd2b21d4ebb7767a812900c0bd11436762',
    'production': 'e26a6d77e9297e5e9e3224fda48e876eba468443deea92806b181bda37f766af',
}


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def corpus():
    profiles = [
        [bits(int(row == column)) for row in range(4) for column in range(4)],
        [bits(value) for value in (-1.7, .4, -2.3, 0, .1, 1.2, .7, 0, .5, -.9, 2.2, 0, 0, 0, 0, 1)],
        [0] * 16,
        [bits(value) for value in (1, 0, 1, 0, 0, 0, 0, 0, -1, 0, -1, 0, 0, 0, 0, 1)],
    ]
    tiny = bits(1e-8)
    lightness = (bits(-1), bits(-1e-8), 0x80000000, 0, tiny - 1, tiny, tiny + 1,
                 bits(.5), 0x3f7fffff, 0x3f800000, 0x3f800001, 0x7f800000, 0x7fc01234)
    rows = []
    rng = random.Random(0xd7b7ab0b)
    for profile, matrix in enumerate(profiles):
        for kind in (0, 1):
            n = 3 + kind
            group = f'{"alpha" if kind else "plain"}-matrix-{profile}'
            for field, index, mixed in itertools.product(range(n), range(len(BOUNDARIES)), (False, True)):
                values = [BOUNDARIES[(index + i) % len(BOUNDARIES)] if mixed else BOUNDARIES[index] for i in range(4)]
                rows.append((group, f'{group}-{field}-{index}-{int(mixed)}', '|'.join(map(str, (kind, field, *values, *matrix)))))
            for field, index, level in itertools.product(range(n), range(len(BOUNDARIES)), range(len(lightness))):
                values = (BOUNDARIES[index], bits(.5), lightness[level], 0x80000000)
                rows.append((group, f'{group}-lightness-{field}-{index}-{level}', '|'.join(map(str, (kind, field, *values, *matrix)))))
            for index in range(128):
                values = [rng.getrandbits(32) for _ in range(4)]
                rows.append((group, f'{group}-random-{index}', '|'.join(map(str, (kind, rng.randrange(n), *values, *matrix)))))
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
    probe = repo / 'zigimg/reference_probes/hsluv_contracts'
    mode = 'production' if args.v_prod else 'ordinary'
    native_mode = 'ReleaseSafe' if args.v_prod else 'Debug'
    with work_directory(args.workdir, 'witty-hsluv-contracts-') as root:
        proof = ProofLog(root)
        tmp = root / 'tmp'
        tmp.mkdir()
        env = dict(os.environ, VEXE=str(v), V_C_ERROR_BUG_REPORT_DISABLED='1', TMPDIR=str(tmp), VTMP=str(tmp))
        sdk = Path(proof.run(['xcrun', '--show-sdk-path'], 'sdk-path').stdout.decode().strip())
        sdk_math = sdk / 'usr/include/math.h'
        sdk_hash = digest(sdk_math)
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
        vbase = [str(v), *(['-prod'] if args.v_prod else []), '-path', f'{repo}|@vlib|@vmodules']
        print(f'Building HSLuv: Source {native_mode}, V {mode}', flush=True)
        proof.run(zbase + ['-femit-bin=' + str(root / 'native'), str(root / 'reference.zig')], 'build-source', timeout=args.timeout)
        proof.run(vbase + ['-o', str(root / 'translated'), str(root / 'main.v')], 'build-v', env=env, timeout=args.timeout)
        rows = corpus()
        file = root / 'corpus.txt'
        file.write_text('\n'.join(row for group, name, row in rows) + '\n')
        inputs = {file.name: digest(file)}
        outputs = []
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
                columns = [i for i, (a, b) in enumerate(zip(native.split(b','), translated.split(b','))) if a != b]
                raise AssertionError(f'{name}: output differs at {columns}; input {row}')
            h.update(name.encode() + b'\0' + native + b'\n')
            groups[group] += 1
        print(f'{len(rows)} HSLuv records, SHA256 {h.hexdigest()}', flush=True)
        consumers = {}

        def pair(label, zbody, vbody, zmarker=None, vmarker=None):
            paths = [root / (label + '.zig'), root / (label + '.v')]
            paths[0].write_text('const c=@import("src/color.zig");pub fn main() void {' + zbody + '}\n')
            paths[1].write_text('module main\nimport zigimg as c\nfn main(){\n' + vbody + '\n}\n')
            for path in paths:
                consumers[path.name] = digest(path)
            for language, command, marker in (
                    ('Source', zbase + ['-fno-emit-bin', str(paths[0])], zmarker),
                    ('V', vbase + ['-check', '-o', str(root / (label + '-checked')), str(paths[1])], vmarker)):
                result = proof.run(command, label + '-' + language, env=env, timeout=args.timeout, check=False)
                diagnostic = (result.stdout + result.stderr).decode(errors='replace')
                errors = [line for line in diagnostic.splitlines() if re.search(r'\berror:', line)]
                if marker is None:
                    if result.returncode or errors:
                        raise AssertionError(f'{label}/{language}: expected acceptance; see retained diagnostics')
                else:
                    ordinary_rejection(result, label + '/' + language)
                    if not any(marker in line for line in errors):
                        raise AssertionError(f'{label}/{language}: missing {marker!r}; see retained diagnostics')
        for name, fields in (('HSLuv', ('h', 's', 'l')), ('HSLuvAlpha', ('h', 's', 'l', 'alpha'))):
            zinit = 'c.' + name + '{' + ','.join('.' + field + '=0' for field in fields) + '}'
            vinit = 'c.' + name + '{' + ','.join(field + ':0' for field in fields) + '}'
            pair(name + '-explicit', 'var x=' + zinit + ';' + ''.join('x.' + field + '=1;' for field in fields) + '_=x.h;',
                 'mut x:=' + vinit + '\n' + '\n'.join('x.' + field + '=1' for field in fields) + '\n_=x.h')
            for field in fields:
                zmissing = 'c.' + name + '{' + ','.join('.' + item + '=0' for item in fields if item != field) + '}'
                vmissing = 'c.' + name + '{' + ','.join(item + ':0' for item in fields if item != field) + '}'
                pair(name + '-missing-' + field, 'const x=' + zmissing + ';_=x;', 'x:=' + vmissing + '\n_=x',
                     'missing struct field: ' + field, '.' + field + '` must be initialized')
                pair(name + '-immutable-' + field, 'const x=' + zinit + ';x.' + field + '=1;', 'x:=' + vinit + '\nx.' + field + '=1',
                     'cannot assign to constant', 'immutable')
        pair('float4-bridge', 'const x=c.HSLuvAlpha.fromFloat4(.{1,2,3,4});_=c.HSLuvAlpha.toFloat4(x);',
             'x:=c.HSLuvAlpha.from_float4(c.Float4([f32(1),2,3,4]!))\n_=c.HSLuvAlpha.to_float4(x)')
        pair('factory-return-typo', 'const x:c.HSLuvAlpha=c.HSLuvAlpha.fromFloat4(.{1,2,3,4});_=x;',
             'x:=c.HSLuvAlpha(c.HSLuvAlpha.from_float4(c.Float4([f32(1),2,3,4]!)))\n_=x', 'expected type', 'cannot convert struct')
        pair('float4-argument-typo', 'const x=c.HSLuvAlpha{.h=1,.s=2,.l=3,.alpha=4};_=c.HSLuvAlpha.toFloat4(x);',
             'x:=c.HSLuvAlpha{h:1,s:2,l:3,alpha:4}\n_=c.HSLuvAlpha.to_float4(x)', 'expected type', 'cannot use')
        (root / 'input_sha256.json').write_text(json.dumps(inputs, indent=2) + '\n')
        (root / 'consumer_sha256.json').write_text(json.dumps(consumers, indent=2) + '\n')
        for name, expected in {**inputs, **consumers}.items():
            if digest(root / name) != expected:
                raise AssertionError('input or consumer changed')
        if (tree_hash(source) != PINNED_SOURCE_SHA256 or tree_hash(root / 'src') != PINNED_SOURCE_SHA256
                or stdlib_hash(zig) != PINNED_STDLIB_SHA256
                or any(digest(math_dir / name) != expected for name, expected in MATH_HASHES.items())
                or digest(sdk_math) != sdk_hash
                or implementation_hashes(repo) != implementations or digest(Path(__file__)) != runner_hash):
            raise AssertionError('dependency, implementation or runner changed')
        for name, expected in fixtures.items():
            if any(digest(path) != expected for path in (root / name, probe / name)):
                raise AssertionError('fixture changed')
        summary = dict(returning_records=len(rows), return_groups=dict(groups), sha256=h.hexdigest(),
                       accepted_record_pairs=3, required_field_rejection_pairs=7,
                       immutable_rejection_pairs=7, preserved_typo_rejection_pairs=2)
        (root / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
        print(json.dumps(summary, indent=2), flush=True)
        if len(rows) != EXPECTED_RETURNS or h.hexdigest() != EXPECTED_SHA256[mode]:
            raise AssertionError('locked HSLuv golden changed')


if __name__ == '__main__':
    main()
