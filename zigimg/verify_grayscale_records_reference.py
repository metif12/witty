"""Compare grayscale construction, copies and checked narrow carriers."""
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
from verify_tiff_decode_reference import ProofLog, tree_hash, work_directory, PINNED_SOURCE_SHA256, checked_trap
from verify_matrix_contracts_reference import MATH_HASHES
from verify_simd_reference import ordinary_rejection

TYPES = (
    ('Grayscale1', 1, False), ('Grayscale2', 2, False), ('Grayscale4', 4, False),
    ('Grayscale8', 8, False), ('Grayscale16', 16, False),
    ('Grayscale8Alpha', 8, True), ('Grayscale16Alpha', 16, True),
    ('Grayscalef32', 32, False), ('Grayscalef32Alpha', 32, True),
)
FLOAT_BOUNDARIES = (0, 0x80000000, 1, 0x80000001, 0x007fffff, 0x00800000,
                    0x3f7fffff, 0x3f800000, 0x3f800001, 0xbf800000, 0x7f7fffff,
                    0xff7fffff, 0x7f800000, 0xff800000, 0x7fc00000, 0x7fc01234,
                    0xffc05678, 0x7f800001, 0xff800001, 0x40000000)
EXPECTED_RETURNS = 10232
EXPECTED_SHA256 = {
    'ordinary': 'dc6b5c8e04f277b0bd37a373851c553d46686d67092d95af8f7667b30d96b272',
    'production': 'dc6b5c8e04f277b0bd37a373851c553d46686d67092d95af8f7667b30d96b272',
}


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def corpus():
    rows = []
    rng = random.Random(0xd7b7ab0b)
    for kind, (name, width, alpha) in enumerate(TYPES):
        limit = (1 << width) - 1
        boundaries = FLOAT_BOUNDARIES if width == 32 else tuple(sorted({
            0, 1, limit, limit - 1, limit // 2, limit // 2 + 1,
            *[value for value in (2, 3, 7, 8, 15, 16, 127, 128, 255, 256, 32767, 32768)
              if value <= limit]}))
        for form, operation, field in itertools.product(range(2) if alpha else (0,), range(4), range(2) if alpha else (0,)):
            group = f'{name}-form-{form}-operation-{operation}'
            for index, value in enumerate(boundaries):
                original = (value, boundaries[(index + 3) % len(boundaries)])
                replacement = boundaries[(index + 7) % len(boundaries)]
                rows.append((group, f'{group}-field-{field}-boundary-{index}',
                             '|'.join(map(str, (kind, form, operation, field, *original, replacement)))))
            for index in range(128):
                values = [rng.getrandbits(width) for _ in range(3)]
                rows.append((group, f'{group}-field-{field}-random-{index}',
                             '|'.join(map(str, (kind, form, operation, field, *values)))))
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
    probe = repo / 'zigimg/reference_probes/grayscale_records'
    mode = 'production' if args.v_prod else 'ordinary'
    native_mode = 'ReleaseSafe' if args.v_prod else 'Debug'
    with work_directory(args.workdir, 'witty-grayscale-records-') as root:
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
        vbase = [str(v), *(['-prod'] if args.v_prod else []), '-path', f'{repo}|@vlib|@vmodules']
        print(f'Building grayscale records: Source {native_mode}, V {mode}', flush=True)
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
                raise AssertionError(f'{name}: record/conversion output differs; input {row}')
            h.update(name.encode() + b'\0' + native + b'\n'); groups[group] += 1
        print(f'{len(rows)} grayscale records, SHA256 {h.hexdigest()}', flush=True)
        consumers = {}

        def pair(label, zbody, vbody, zmarker=None, vmarker=None):
            paths = [root / (label + '.zig'), root / (label + '.v')]
            paths[0].write_text('const c=@import("src/color.zig");pub fn main() void {' + zbody + '}\n')
            paths[1].write_text('module main\nimport zigimg as c\nfn main(){\n' + vbody + '\n}\n')
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
        for index, (name, width, alpha) in enumerate(TYPES):
            zinit = 'c.' + name + '{.value=0}'
            vinit = 'c.' + name + '{value:0}'
            fields = ('value', 'alpha') if alpha else ('value',)
            pair(name+'-accepted', 'var x='+zinit+';'+''.join('x.'+field+'=1;' for field in fields)+'_=x.value;',
                 'mut x:='+vinit+'\n'+'\n'.join('x.'+field+'=1' for field in fields)+'\n_=x.value')
            pair(name+'-missing-value', 'const x=c.'+name+'{};_=x;', 'x:=c.'+name+'{}\n_=x',
                 'missing struct field: value', '.value` must be initialized')
            for field in fields:
                pair(name+'-immutable-'+field, 'const x='+zinit+';x.'+field+'=1;',
                     'x:='+vinit+'\nx.'+field+'=1', 'cannot assign to constant', 'immutable')
            if index < 3:
                raw = 1 << width
                pair(name+'-wider-carrier', 'const x=c.'+name+'{.value='+str(raw)+'};_=x.value;',
                     'x:=c.'+name+'{value:'+str(raw)+'}\n_=x.value', 'cannot represent integer value')
        for kind, (_, width, _) in enumerate(TYPES[:3]):
            for raw in (1 << width, 255):
                for exe in ('native', 'translated'):
                    result = proof.run([str(root/exe), 'trap', str(kind), str(raw)],
                                       f'width-{width}-value-{raw}-'+exe, check=False, timeout=args.timeout)
                    checked_trap(result, f'{exe}/width-{width}/value-{raw}', 'integer does not fit in destination type')
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
                       accepted_record_pairs=9, required_field_rejection_pairs=9, immutable_rejection_pairs=12,
                       wider_carrier_adaptations=3, checked_width_trap_pairs=6)
        (root / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n'); print(json.dumps(summary, indent=2), flush=True)
        if len(rows) != EXPECTED_RETURNS or h.hexdigest() != EXPECTED_SHA256[mode]:raise AssertionError('locked grayscale record golden changed')


if __name__ == '__main__':main()
