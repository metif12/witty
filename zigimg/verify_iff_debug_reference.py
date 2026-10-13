"""Compare public IFF debug payloads, logger classification and caller immutability."""
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

EXPECTED_RETURNS = 142912
EXPECTED_SHA256 = '893786350ccb1081f99146384847741efd45b9f7a0e180a417c153ddea79591a'
FORMAT_FILES = {
    'fmt.zig': '667eac6285e472b5516ebebf8a6e69959a171be4fb97cac1e56419ffec20d500',
    'log.zig': 'a501bbda527d502fcc1cd0595a20c2487076c7e83c7636d6910ec2935ce8d59e',
    'std.zig': 'b78c7a6dec7a3ea3381bae30533309bd8de71994422c3f87fc9760e378c7e427',
    'Io/Writer.zig': 'f541f60754a1c4835381217e5072ce0eb311393efc38eb180c0adb740dd50543',
}
LOG_FILES = ('log.v', 'default.v', 'logger_interface.v', 'common.v', 'default.c.v')


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def corpus():
    rows = []
    counts = Counter()
    def add(group, values):
        name = f'{group}-{counts[group]}'; counts[group] += 1
        rows.append((group, name, '|'.join(map(str, values))))
    for mask, compression, byte in itertools.product(range(4), range(3), range(256)):
        add('bmhd-byte-domain', (0, 1, byte * 257, (255 - byte) * 257, byte - 128,
            127 - byte, byte, mask, compression, byte ^ 255, byte * 251, byte, byte ^ 85,
            byte * 239, byte * 233))
    for compression, byte in itertools.product(range(5), range(256)):
        add('dgbl-byte-domain', (1, 1, byte * 257, (255 - byte) * 257, compression, byte, byte ^ 85))
    for value in range(65536):
        add('bmhd-signed-domain', (0, 1, value, value ^ 65535, value - 32768,
            32767 - value, value & 255, value % 4, (value // 4) % 3, value >> 8,
            (value * 17) & 65535, (value * 31) & 255, (value * 37) & 255,
            (value * 41) & 65535, (value * 43) & 65535))
    bounds = (0, 1, 127, 128, 255, 32767, 32768, 65535)
    for mask, compression, value, repeats in itertools.product(range(4), range(3), bounds, range(4)):
        add('bmhd-boundaries-repeat', (0, repeats, value, value, -32768, 32767, value & 255,
            mask, compression, value & 255, value, value & 255, value & 255, value, value))
    for compression, value, repeats in itertools.product(range(5), bounds, range(4)):
        add('dgbl-boundaries-repeat', (1, repeats, value, value, compression, value & 255, value & 255))
    rng = random.Random(20261013)
    for _ in range(512):
        add('bmhd-seeded', (0, 2, rng.randrange(65536), rng.randrange(65536),
            rng.randrange(-32768, 32768), rng.randrange(-32768, 32768), rng.randrange(256),
            rng.randrange(4), rng.randrange(3), rng.randrange(256), rng.randrange(65536),
            rng.randrange(256), rng.randrange(256), rng.randrange(65536), rng.randrange(65536)))
        add('dgbl-seeded', (1, 2, rng.randrange(65536), rng.randrange(65536),
            rng.randrange(5), rng.randrange(256), rng.randrange(256)))
    return rows


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('source', 'zig', 'v'):
        parser.add_argument(name, type=Path)
    parser.add_argument('--target', default='aarch64-macos.14.0')
    parser.add_argument('--v-prod', action='store_true')
    parser.add_argument('--workdir', type=Path)
    parser.add_argument('--timeout', type=int, default=600)
    args = parser.parse_args()
    if args.timeout <= 0:
        parser.error('--timeout must be positive')
    source, zig, v = args.source.resolve() / 'src', args.zig.resolve(), args.v.resolve()
    if tree_hash(source) != PINNED_SOURCE_SHA256 or stdlib_hash(zig) != PINNED_STDLIB_SHA256:
        parser.error('Source or library differs from pins')
    for name, expected in FORMAT_FILES.items():
        if digest(zig.parent / 'lib/std' / name) != expected:
            parser.error('formatter/logging library differs from pins: ' + name)
    repo = Path(__file__).resolve().parent.parent
    probe = repo / 'zigimg/reference_probes/iff_debug'
    mode = 'ReleaseSafe' if args.v_prod else 'Debug'
    with work_directory(args.workdir, 'witty-iff-debug-') as root:
        proof = ProofLog(root)
        tmp = root / 'tmp'; tmp.mkdir()
        env = dict(os.environ, VEXE=str(v), V_C_ERROR_BUG_REPORT_DISABLED='1', TMPDIR=str(tmp), VTMP=str(tmp))
        shutil.copytree(source, root / 'src')
        fixtures = {}
        for name in ('main.v', 'reference.zig'):
            shutil.copyfile(probe / name, root / name); fixtures[name] = digest(probe / name)
        versions = [proof.run([str(exe), 'version'], label, env=env).stdout.decode().strip()
                    for exe, label in ((zig, 'zig-version'), (v, 'v-version'))]
        if versions[0] != '0.15.2' or not re.match(r'^V 0\.5\.2(?: |$)', versions[1]):
            raise AssertionError('compiler version changed')
        implementations, runner_hash = implementation_hashes(repo), digest(Path(__file__))
        helpers = {name: digest(repo / 'zigimg' / name) for name in
                   ('verify_jpeg_contracts_reference.py', 'verify_tga_decode_reference.py',
                    'verify_tiff_decode_reference.py')}
        v_log = {name: digest(v.parent / 'vlib/log' / name) for name in LOG_FILES}
        provenance = dict(source_sha256=PINNED_SOURCE_SHA256, stdlib_sha256=PINNED_STDLIB_SHA256,
            formatter_sha256=FORMAT_FILES, v_log_sha256=v_log, versions=versions, target=args.target,
            zig_mode=mode, v_prod=args.v_prod, fixtures=fixtures, implementation_sha256=implementations,
            runner_sha256=runner_hash, helper_sha256=helpers)
        (root / 'provenance.json').write_text(json.dumps(provenance, indent=2) + '\n')
        zbase = [str(zig), 'build-exe', '-target', args.target, '-lc', '-O', mode,
                 '--global-cache-dir', str(root / 'zig-global'), '--cache-dir', str(root / 'zig-cache')]
        vbase = [str(v), '-enable-globals', *(['-prod'] if args.v_prod else []), '-path', f'{repo}|@vlib|@vmodules']
        print(f'Building IFF debug: Source {mode}, V production={args.v_prod}', flush=True)
        inputs = {}
        for enabled in (0, 1):
            settings = root / f'settings-{enabled}.zig'
            settings.write_text(f'pub const enabled = {str(bool(enabled)).lower()};\n')
            inputs[settings.name] = digest(settings)
            proof.run(zbase + ['-femit-bin=' + str(root / f'native-{enabled}'), '--dep', 'settings',
                '-Mroot=' + str(root / 'reference.zig'), '-Msettings=' + str(settings)],
                f'build-source-{enabled}', env=env, timeout=args.timeout)
        proof.run(vbase + ['-o', str(root / 'translated'), str(root / 'main.v')],
                  'build-v', env=env, timeout=args.timeout)
        rows = corpus(); path = root / 'corpus.txt'
        path.write_text('\n'.join(row for _, _, row in rows) + '\n'); inputs[path.name] = digest(path)
        h = hashlib.sha256(); groups = Counter()
        for enabled in (0, 1):
            outputs = []
            for language, command in (
                    ('Source', [str(root / f'native-{enabled}'), str(path)]),
                    ('V', [str(root / 'translated'), str(path), str(enabled)])):
                result = proof.run(command, f'corpus-{enabled}-{language}', env=env, timeout=args.timeout)
                if result.stderr:
                    raise AssertionError('unexpected corpus diagnostics')
                outputs.append(result.stdout.splitlines())
            if any(len(output) != len(rows) for output in outputs):
                raise AssertionError('corpus counts differ')
            for (group, name, row), a, b in zip(rows, *outputs):
                if a != b:
                    raise AssertionError(f'{enabled}/{name}: differing output\n{row}\n{a!r}\n{b!r}')
                fields = a.split(b'|')
                if len(fields) != 4 or fields[2] != fields[3]:
                    raise AssertionError('caller mutated or malformed observation')
                h.update(str(enabled).encode() + b'\0' + name.encode() + b'\0' + a + b'\n')
                groups[('enabled-' if enabled else 'suppressed-') + group] += 1
            print(f'Logger enabled={enabled}: {len(rows)} records match', flush=True)
        (root / 'input_sha256.json').write_text(json.dumps(inputs, indent=2) + '\n')
        for name, expected in inputs.items():
            if digest(root / name) != expected:
                raise AssertionError('input or settings changed')
        if (tree_hash(source) != PINNED_SOURCE_SHA256 or tree_hash(root / 'src') != PINNED_SOURCE_SHA256
                or stdlib_hash(zig) != PINNED_STDLIB_SHA256 or implementation_hashes(repo) != implementations
                or digest(Path(__file__)) != runner_hash):
            raise AssertionError('Source, dependency, implementation or runner changed')
        for name, expected in fixtures.items():
            if any(digest(path) != expected for path in (root / name, probe / name)):
                raise AssertionError('fixture changed')
        for name, expected in helpers.items():
            if digest(repo / 'zigimg' / name) != expected:
                raise AssertionError('proof helper changed')
        for name, expected in v_log.items():
            if digest(v.parent / 'vlib/log' / name) != expected:
                raise AssertionError('V logging library changed')
        for name, expected in FORMAT_FILES.items():
            if digest(zig.parent / 'lib/std' / name) != expected:
                raise AssertionError('formatter library changed')
        summary = dict(returning_records=len(rows) * 2, return_groups=dict(groups), sha256=h.hexdigest(),
                       bmhd_cases=sum(g.startswith('bmhd-') for g, _, _ in rows),
                       dgbl_cases=sum(g.startswith('dgbl-') for g, _, _ in rows),
                       logger_configurations=2)
        (root / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
        print(json.dumps(summary, indent=2), flush=True)
        if summary['returning_records'] != EXPECTED_RETURNS or h.hexdigest() != EXPECTED_SHA256:
            raise AssertionError('locked IFF debug golden changed')


if __name__ == '__main__':
    main()
