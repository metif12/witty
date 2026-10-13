"""Compare cylindrical RGB consumers with unchanged pinned Source in both modes."""
import argparse
from collections import Counter
import hashlib
import itertools
import json
import math
import os
from pathlib import Path
import random
import re
import shutil

from verify_jpeg_contracts_reference import implementation_hashes
from verify_tga_decode_reference import stdlib_hash, PINNED_STDLIB_SHA256
from verify_tiff_decode_reference import ProofLog, tree_hash, work_directory, PINNED_SOURCE_SHA256
from verify_matrix_contracts_reference import MATH_HASHES
from verify_color_models_reference import bits

EXPECTED_RETURNS = 50832
EXPECTED_SHA256 = {
    'ordinary': '28d84845b25575f8818f23627bc011f621bb44fd3c0cb8af508eca9a15f8fe71',
    'production': '3d1e90958a919819ccf65ddc2d0d2abbdb460d34892411d61c2b13e375ce4173',
}


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def corpus():
    levels = [bits(x) for x in (-2, -1, -0.0, 0, 1e-8, .001, .5, 1, 2, 100)]
    levels += [1, 0x7f7fffff, 0x7f800000, 0xff800000, 0x7fc01234]
    angles = [bits(x) for x in (-2 * math.pi, -math.pi, -.5, -0.0, 0, .5,
                               math.pi, 2 * math.pi, 1e-8, 1e8)]
    angles += [1, 0x7f7fffff, 0x7f800000, 0xff800000, 0x7fc01234]
    alphas = (0, 0x80000000, bits(.25), bits(1), bits(2), 0x7fc05678)
    rows = []
    rng = random.Random(0xd7b7ab0b)
    for space, kind, alpha, clamp in itertools.product(range(12), range(3), range(2), range(2)):
        group = f'space-{space}-kind-{kind}-alpha-{alpha}-clamp-{clamp}'
        prefix = (space, kind, alpha, clamp)
        for level, angle in itertools.product(range(len(levels)), range(len(angles))):
            values = (levels[level], levels[(level + angle + 7) % len(levels)],
                      angles[angle], alphas[(level + angle) % len(alphas)])
            rows.append((group, f'{group}-boundary-{level}-{angle}', '|'.join(map(str, (*prefix, *values)))))
        for index in range(128):
            values = [bits(rng.uniform(-4, 4)) for _ in range(4)] if index % 2 == 0 else [rng.getrandbits(32) for _ in range(4)]
            rows.append((group, f'{group}-random-{index}', '|'.join(map(str, (*prefix, *values)))))
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
    probe = repo / 'zigimg/reference_probes/cylindrical_colorspace'
    mode = 'production' if args.v_prod else 'ordinary'
    native_mode = 'ReleaseSafe' if args.v_prod else 'Debug'
    with work_directory(args.workdir, 'witty-cylindrical-colorspace-') as root:
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
        print(f'Building cylindrical colorspaces: Source {native_mode}, V {mode}', flush=True)
        proof.run([str(zig), 'build-exe', '-target', args.target, '-lc', '-O', native_mode,
                   '--global-cache-dir', str(root / 'zig-global'), '--cache-dir', str(root / 'zig-cache'),
                   '-femit-bin=' + str(root / 'native'), str(root / 'reference.zig')], 'build-source', timeout=args.timeout)
        proof.run([str(v), *(['-prod'] if args.v_prod else []), '-path', f'{repo}|@vlib|@vmodules',
                   '-o', str(root / 'translated'), str(root / 'main.v')], 'build-v', env=env, timeout=args.timeout)
        rows = corpus()
        file = root / 'corpus.txt'
        file.write_text('\n'.join(row for group, name, row in rows) + '\n')
        input_hash = digest(file)
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
        (root / 'input_sha256.json').write_text(json.dumps({file.name: input_hash}, indent=2) + '\n')
        if (tree_hash(source) != PINNED_SOURCE_SHA256 or tree_hash(root / 'src') != PINNED_SOURCE_SHA256
                or stdlib_hash(zig) != PINNED_STDLIB_SHA256
                or any(digest(math_dir / name) != expected for name, expected in MATH_HASHES.items())
                or digest(sdk_math) != sdk_hash or digest(file) != input_hash
                or implementation_hashes(repo) != implementations or digest(Path(__file__)) != runner_hash):
            raise AssertionError('dependency, input, implementation or runner changed')
        for name, expected in fixtures.items():
            if any(digest(path) != expected for path in (root / name, probe / name)):
                raise AssertionError('fixture changed')
        summary = dict(returning_records=len(rows), return_groups=dict(groups), sha256=h.hexdigest())
        (root / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
        print(f'{len(rows)} cylindrical colorspace records, SHA256 {h.hexdigest()}', flush=True)
        if len(rows) != EXPECTED_RETURNS or h.hexdigest() != EXPECTED_SHA256[mode]:
            raise AssertionError('locked cylindrical colorspace golden changed')


if __name__ == '__main__':
    main()
