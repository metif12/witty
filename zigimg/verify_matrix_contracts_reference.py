"""Compare required matrix fields, inline copies and mutation with unchanged Source.

Retains inputs, compiler controls, outputs and before/after provenance. Arithmetic
and the two matrix consumers retain their historical result hashes separately.
"""
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
from verify_simd_reference import ordinary_rejection
import verify_math_reference as named_math
import verify_math_generic_reference as generic_math
import verify_color_science_reference as science
import verify_color_space_reference as colorspace
import verify_color_trig_results as color_results

MATH_HASHES = {'cbrt.zig': 'a4995a636473d996e6ffb75c8a2890ca24e9457110dbefe244c05b21440e24af', 'atan.zig': '14a8df19a689f837e78b9b22f3a375c69ec5cd4bb0443d37bc55be638701fe45', 'atan2.zig': 'ad6ac04bf60dbe2b88bb953080b0dcace55007dbce4eadccaa5a810baadcc76d', 'pow.zig': '5df36194e30a115dac017fbfff11eacc5ed7b44fe9e39404afe9c3bd30829591', 'frexp.zig': '2a9cf896243de2e7bf46513614eae704626b6a4898c54abc047df66759739080', 'ldexp.zig': '2c3c54f8e10fb9ebaae5443832bbc4ad3d87ff35a50e109b71c0d8844feaeeaa', 'modf.zig': '339b1dd9b92e0df04e9b0d57929f5390f032627dbd7af8699009322573439cdc'}

FORMS = (('named2', 2), ('named3', 3), ('named4', 4), ('generic1', 1),
         ('generic2', 2), ('generic3', 3), ('generic4', 4), ('generic5', 5), ('generic8', 8))
BOUNDARIES = (0, 0x80000000, 1, 0x80000001, 0x007fffff, 0x00800000,
              0x3f7fffff, 0x3f800000, 0x3f800001, 0xbf800000, 0x7f7fffff,
              0xff7fffff, 0x7f800000, 0xff800000, 0x7fc00000, 0x7fc01234,
              0xffc05678, 0x7f800001, 0xff800001, 0x40000000)
EXPECTED_RETURNS = 6208
EXPECTED_RETURN_SHA256 = '1e940bc5ea0d199b792cd64c703e955fc6aae99f6c37596f2398d72021358525'
OPTIMIZED_COLORS = {
    'color_science': (6961, '0f89855f7a8b779c3c40600a456fe34c9f88e8a006fb1702ce0d1906b7a939a8',
                      5, '0bee6436f84cce99c39d3ce12ea0d2796f72f90536a4632046943507ef73574c'),
    'color_space': (5792, 'f5cd4a24f8ea84428809ee7d55725c652f38d25add39f402276b1b62949fd5ba',
                   32, 'd8037c0389d0cac691c8e1efc9305e75dd348040e77cfefe3de30e3016f1e697'),
}
HISTORICAL = (
    ('math', named_math, 12419, '23be1b2c20e279a493dda64087e1916b58e6fdbc8bdcb76469c15b7231a4fb31'),
    ('math_generic', generic_math, 6467, 'f303b568d8901d722b61cb805d2ccd212e57c10a758d2b530f15ab4d710e9c0f'),
    ('color_science', science, 6961, 'd97550d49bb60cf224fc60999d3603d6199aa9c99702a7c79b8d7ca9f10e8566'),
    ('color_space', colorspace, 5792, '262e3417fd251373234d20d0b06d7fe53adc63028db4a708a71d99677cf9d6a0'),
)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def corpus():
    rows = []
    rng = random.Random(0xd7b7ab0b)
    for form, (label, n) in enumerate(FORMS):
        for row, column, index, mixed in itertools.product(range(n), range(n), range(len(BOUNDARIES)), (False, True)):
            values = [BOUNDARIES[(index + i) % len(BOUNDARIES)] if mixed else BOUNDARIES[index] for i in range(n * n)]
            name = f'{label}-{row}-{column}-{index}-{int(mixed)}'
            rows.append((label, name, '|'.join(map(str, (form, row, column, *values)))))
        for index in range(32):
            values = [rng.getrandbits(32) for _ in range(n * n)]
            rows.append((label, f'{label}-random-{index}', '|'.join(map(str, (form, rng.randrange(n), rng.randrange(n), *values)))))
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
    if tree_hash(source) != PINNED_SOURCE_SHA256 or stdlib_hash(zig) != PINNED_STDLIB_SHA256:
        parser.error('Source or library differs from pins')
    math_dir = zig.parent / 'lib/std/math'
    if any(digest(math_dir / name) != expected for name, expected in MATH_HASHES.items()):
        parser.error('Zig math library differs from pinned 0.15.2')
    repo = Path(__file__).resolve().parent.parent
    env = dict(os.environ, VEXE=str(v), V_C_ERROR_BUG_REPORT_DISABLED='1')
    mode = 'ReleaseSafe' if args.v_prod else 'Debug'
    with work_directory(args.workdir, 'witty-matrix-contracts-') as root:
        proof = ProofLog(root)
        temporary = root / 'tmp'
        temporary.mkdir()
        env.update(TMPDIR=str(temporary), VTMP=str(temporary))
        shutil.copytree(source, root / 'src')
        fixtures = {}
        for name in ('matrix_contracts', *(item[0] for item in HISTORICAL)):
            for file, extension in (('reference.zig', 'zig'), ('main.v', 'v')):
                original = repo / 'zigimg/reference_probes' / name / file
                destination = root / f'{name}.{extension}'
                shutil.copyfile(original, destination)
                fixtures[destination.name] = dict(original=str(original.relative_to(repo)), sha256=digest(original))
        versions = [proof.run([str(exe), 'version'], label, env=env).stdout.decode().strip()
                    for exe, label in ((zig, 'zig-version'), (v, 'v-version'))]
        if versions[0] != '0.15.2' or not re.match(r'^V 0\.5\.2(?: |$)', versions[1]):
            raise AssertionError('unexpected compiler versions')
        implementations, runner_hash = implementation_hashes(repo), digest(Path(__file__))
        generators = {str(Path(item[1].__file__).relative_to(repo)): digest(Path(item[1].__file__)) for item in HISTORICAL}
        generators[str(Path(color_results.__file__).relative_to(repo))] = digest(Path(color_results.__file__))
        (root / 'provenance.json').write_text(json.dumps(dict(
            source_sha256=PINNED_SOURCE_SHA256, stdlib_sha256=PINNED_STDLIB_SHA256, math_sha256=MATH_HASHES, versions=versions,
            target=args.target, zig_mode=mode, v_prod=args.v_prod, fixtures=fixtures, generators=generators,
            historical_source_modes={name: mode for name, *_ in HISTORICAL},
            implementation_sha256=implementations, runner_sha256=runner_hash), indent=2) + '\n')
        zbase = [str(zig), 'build-exe', '-target', args.target, '-lc', '-O', mode,
                 '--global-cache-dir', str(root / 'zig-global'), '--cache-dir', str(root / 'zig-cache')]
        vbase = [str(v), *(['-prod'] if args.v_prod else []), '-path', f'{repo}|@vlib|@vmodules']
        inputs, consumers = {}, {}

        def compare(label, cases, expected_count, expected_hash, named=False, source_mode=None):
            source_mode = source_mode or mode
            build = zbase.copy()
            build[build.index('-O') + 1] = source_mode
            print(f'Building {label}: Source {source_mode}, V {"production" if args.v_prod else "ordinary"}', flush=True)
            proof.run(build + ['-femit-bin=' + str(root / (label + '-native')), str(root / (label + '.zig'))], label + '-build-source', timeout=args.timeout)
            proof.run(vbase + ['-o', str(root / (label + '-translated')), str(root / (label + '.v'))], label + '-build-v', env=env, timeout=args.timeout)
            file = root / (label + '-corpus.txt')
            file.write_text('\n'.join(case[-1] for case in cases) + '\n')
            inputs[file.name] = digest(file)
            outputs = []
            for language in ('native', 'translated'):
                result = proof.run([str(root / (label + '-' + language)), str(file)], label + '-' + language, timeout=args.timeout, check=False)
                if result.returncode or result.stderr:
                    raise AssertionError(f'{label}/{language} failed; see retained stdout/stderr')
                outputs.append(result.stdout.splitlines())
            if any(len(output) != expected_count for output in outputs) or len(cases) != expected_count:
                raise AssertionError(f'{label}: count changed')
            if label in OPTIMIZED_COLORS:
                summary, differences = color_results.compare_color_records(label, cases, *outputs, args.v_prod)
                (root / (label + '-differences.json')).write_text(json.dumps(differences, indent=2) + '\n')
                print(f'{label}: {summary["matching_records"]} matching records, {len(differences)} retained differences', flush=True)
                return summary
            h = hashlib.sha256()
            for case, native, translated in zip(cases, *outputs):
                if native != translated:
                    raise AssertionError(f'{label}/{case[-2]}: output differs; input {case[-1]}')
                if named:
                    h.update(case[-2].encode() + b'\0' + native + b'\n')
            result_hash = h.hexdigest() if named else hashlib.sha256(b'\n'.join(outputs[0])).hexdigest()
            if result_hash != expected_hash:
                raise AssertionError(f'{label}: golden changed: {result_hash}')
            print(f'{label}: {expected_count} records, SHA256 {result_hash}', flush=True)
            return dict(returning_records=expected_count, sha256=result_hash)

        rows = corpus()
        result = compare('matrix_contracts', rows, EXPECTED_RETURNS, EXPECTED_RETURN_SHA256, named=True)
        groups = Counter(row[0] for row in rows)
        historical = {name: compare(name, module.corpus(), count, expected_hash)
                      for name, module, count, expected_hash in HISTORICAL}
        # Ordinary colors use their historical Debug oracle. Production now
        # uses ReleaseSafe. Cross-mode observations remain separate controls.
        optimized_colors = {}
        for label, module, count, _ in HISTORICAL:
            if label not in OPTIMIZED_COLORS:
                continue
            _, expected_hash, expected_differences, expected_difference_hash = OPTIMIZED_COLORS[label]
            if args.v_prod:
                expected_differences = color_results.COLOR_RESULTS[label, True][3]
                expected_difference_hash = color_results.COLOR_RESULTS[label, True][4]
            build = zbase.copy()
            build[build.index('-O') + 1] = 'ReleaseSafe'
            exe = label + '-optimized-native'
            proof.run(build + ['-femit-bin=' + str(root / exe), str(root / (label + '.zig'))],
                      label + '-optimized-build', timeout=args.timeout)
            optimized = proof.run([str(root / exe), str(root / (label + '-corpus.txt'))],
                                  label + '-optimized-run', timeout=args.timeout, check=False)
            baseline = proof.run([str(root / (label + '-translated')), str(root / (label + '-corpus.txt'))],
                                 label + '-baseline-run', timeout=args.timeout, check=False)
            if optimized.returncode or baseline.returncode or optimized.stderr or baseline.stderr:
                raise AssertionError('color optimization comparison failed; see retained outputs')
            native, translated = optimized.stdout.splitlines(), baseline.stdout.splitlines()
            if (len(native) != count or len(translated) != count
                    or hashlib.sha256(b'\n'.join(native)).hexdigest() != expected_hash
                    or hashlib.sha256(b'\n'.join(translated)).hexdigest() != historical[label]['v_sha256']):
                raise AssertionError('color optimization output changed')
            differences, difference_hash = [], hashlib.sha256()
            for (name, row), expected, actual in zip(module.corpus(), native, translated):
                if expected != actual:
                    difference_hash.update(name.encode() + b'\0' + expected + b'\0' + actual + b'\n')
                    differences.append(dict(name=name, input=row, source=expected.decode(), v=actual.decode(),
                                            columns=[i for i, (a, b) in enumerate(zip(expected.split(b','), actual.split(b','))) if a != b]))
            if len(differences) != expected_differences or difference_hash.hexdigest() != expected_difference_hash:
                raise AssertionError('color optimization differences changed')
            (root / (label + '-optimization-differences.json')).write_text(json.dumps(differences, indent=2) + '\n')
            symbols = {}
            for name in (exe, label + '-native', label + '-translated'):
                symbols[name] = proof.run(['nm', '-u', str(root / name)], 'symbols-' + name, timeout=args.timeout).stdout
            combined = b'___sincosf_stret'
            native_paired = combined in symbols[label + '-native']
            v_paired = combined in symbols[label + '-translated']
            if combined not in symbols[exe] or native_paired != args.v_prod or v_paired != args.v_prod:
                raise AssertionError('color sin/cos symbol selection changed')
            optimized_colors[label] = dict(source_sha256=expected_hash, differing_records=len(differences),
                                          difference_sha256=difference_hash.hexdigest())
            print(f'{label} optimized Source: {len(differences)} retained differences; combined sin/cos symbol confirmed', flush=True)
        for guard, message in {'rectangular': 'Matrix requires square fixed-array rows',
                               'short_array': 'Matrix.from_array requires N*N components',
                               'short_vector': 'Matrix.mul_vector requires N components'}.items():
            trapped = proof.run([str(root / 'math_generic-translated'), guard], guard, timeout=args.timeout, check=False)
            checked_trap(trapped, guard, message)
        controls = Counter()

        def pair(label, n, ztype, vtype, zbody, vbody, zmarker=None, vmarker=None):
            paths = [root / (label + '.zig'), root / (label + '.v')]
            paths[0].write_text('const math=@import("src/math.zig");const M=' + ztype + ';pub fn main() void {' + zbody + '}\n')
            paths[1].write_text('module main\nimport zigimg as p\ntype Rows=[' + str(n) + '][' + str(n) + ']f32\nfn main(){\n' + vbody.replace('TYPE', vtype) + '\n}\n')
            for path in paths:
                consumers[path.name] = digest(path)
            for language, command, marker in (
                    ('Source', zbase + ['-fno-emit-bin', str(paths[0])], zmarker),
                    ('V', vbase + ['-check', '-o', str(root / (label + '-checked')), str(paths[1])], vmarker)):
                accepted = proof.run(command, label + '-' + language, env=env, timeout=args.timeout, check=False)
                diagnostic = (accepted.stdout + accepted.stderr).decode(errors='replace')
                errors = [line for line in diagnostic.splitlines() if re.search(r'\berror:', line)]
                if marker is None:
                    if accepted.returncode or errors:
                        raise AssertionError(f'{label}/{language}: expected acceptance; see retained diagnostics')
                else:
                    ordinary_rejection(accepted, label + '/' + language)
                    if not any(marker in line for line in errors):
                        raise AssertionError(f'{label}/{language}: missing {marker!r}; see retained diagnostics')
        for label, n in FORMS:
            named = label.startswith('named')
            ztype = f'math.float{n}x{n}' if named else f'math.Matrix([{n}]@Vector({n},f32))'
            vtype = f'p.Float{n}x{n}' if named else 'p.Matrix[Rows]'
            zero = f'@as([{n}]@Vector({n},f32),@splat(@splat(0)))'
            zinit = f'M{{.matrix={zero}}}'
            vinit = 'TYPE{matrix:Rows{}}'
            pair(label + '-explicit', n, ztype, vtype,
                 f'var x={zinit};x.matrix[0][0]=1;_=x.matrix[0][0];',
                 f'mut x:={vinit}\nx.matrix[0][0]=1\n_=x.matrix[0][0]')
            controls['accepted_record_pairs'] += 1
            pair(label + '-omitted', n, ztype, vtype, 'const x=M{};_=x;', 'x:=TYPE{}\n_=x',
                 'missing struct field: matrix', 'must be initialized' if named else None)
            controls['required_field_rejection_pairs' if named else 'generic_required_field_adaptations'] += 1
            for assignment in ('cell', 'storage'):
                zassign = 'x.matrix[0][0]=1;' if assignment == 'cell' else f'x.matrix={zero};'
                vassign = 'x.matrix[0][0]=1' if assignment == 'cell' else 'x.matrix=Rows{}'
                pair(label + '-immutable-' + assignment, n, ztype, vtype,
                     f'const x={zinit};{zassign}', f'x:={vinit}\n{vassign}',
                     'cannot assign to constant', 'immutable')
                controls['immutable_rejection_pairs'] += 1
        (root / 'input_sha256.json').write_text(json.dumps(inputs, indent=2) + '\n')
        (root / 'consumer_sha256.json').write_text(json.dumps(consumers, indent=2) + '\n')
        for name, expected in {**inputs, **consumers}.items():
            if digest(root / name) != expected:
                raise AssertionError('input or consumer changed')
        if (tree_hash(source) != PINNED_SOURCE_SHA256 or tree_hash(root / 'src') != PINNED_SOURCE_SHA256
                or stdlib_hash(zig) != PINNED_STDLIB_SHA256
                or any(digest(math_dir / name) != expected for name, expected in MATH_HASHES.items())
                or implementation_hashes(repo) != implementations
                or digest(Path(__file__)) != runner_hash):
            raise AssertionError('dependency, implementation or runner changed')
        for name, expected in generators.items():
            if digest(repo / name) != expected:
                raise AssertionError('historical corpus generator changed')
        for name, pin in fixtures.items():
            if any(digest(path) != pin['sha256'] for path in (root / name, repo / pin['original'])):
                raise AssertionError('fixture changed')
        summary = dict(returning_records=result['returning_records'], return_sha256=result['sha256'],
                       return_groups=dict(groups), historical=historical, v_shape_guards=3,
                       optimized_color_controls=optimized_colors, **controls)
        (root / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
        print(json.dumps(summary, indent=2), flush=True)


if __name__ == '__main__':
    main()
