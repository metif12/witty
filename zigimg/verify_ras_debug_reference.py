"""Compare direct RAS stderr diagnostics, logger independence and unchanged header fields."""
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

EXPECTED_RETURNS = 13494
EXPECTED_SHA256 = '5851cec9d8d4540cdba6c32cb4b769b08d122c4100f05735b7f759d3f58c0734'
FORMAT_FILES = {
    'fmt.zig': '667eac6285e472b5516ebebf8a6e69959a171be4fb97cac1e56419ffec20d500',
    'log.zig': 'a501bbda527d502fcc1cd0595a20c2487076c7e83c7636d6910ec2935ce8d59e',
    'std.zig': 'b78c7a6dec7a3ea3381bae30533309bd8de71994422c3f87fc9760e378c7e427',
    'Io/Writer.zig': 'f541f60754a1c4835381217e5072ce0eb311393efc38eb180c0adb740dd50543',
}
STDERR_FILES = {'debug.zig': '347b67786d8b399584770955c25efff75aa14f541a9eeee66f3c9848ff072b92'}
V_STDERR_FILES = ('builtin/printing.c.v',)
LOG_FILES = ('log.v', 'default.v', 'logger_interface.v', 'common.v', 'default.c.v')


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def corpus():
    rows = []
    counts = Counter()
    def add(group, fields):
        name = f'{group}-{counts[group]}'; counts[group] += 1
        rows.append((group, name, '|'.join(map(str, fields))))
    kinds = (0, 1, 2, 3, 4, 5, 65535)
    add('source-samples', (1,0,0,0,0,0,0,0))
    add('source-samples', (1,4294967295,2147483648,4294967295,4294967295,65535,2,4294967295))
    for kind, cmap, byte in itertools.product(kinds, range(3), range(256)):
        add('enums-byte-patterns', (1,byte*16843009,(255-byte)*16843009,byte,
            byte*257,kind,cmap,byte*16843009))
    bounds = sorted({0,1,255,256,65535,65536,2147483647,2147483648,4294967294,4294967295} |
                    {10**power+delta for power in range(1,10) for delta in (-1,0,1)})
    for field, value in itertools.product((1,2,3,4,7), bounds):
        f=[1,4294967295,2147483648,32,0,65535,2,0];f[field]=value
        add('u32-decimal-boundaries', f)
    for kind, cmap, value, repeats in itertools.product(kinds, range(3),
            (0,1,9,10,99,100,2147483648,4294967295), range(4)):
        add('enums-boundaries-repeat', (repeats,value,value^4294967295,value,value,kind,cmap,value))
    rng=random.Random(20261014)
    for _ in range(512):
        add('seeded', (2,rng.randrange(4294967296),rng.randrange(4294967296),
            rng.randrange(4294967296),rng.randrange(4294967296),rng.choice(kinds),
            rng.randrange(3),rng.randrange(4294967296)))
    return rows


def observations(rows, stdout, stderr):
    records = stdout.splitlines()
    lines = stderr.splitlines(keepends=True)
    if len(records) != len(rows):
        raise AssertionError('record counts differ')
    result = []
    position = 0
    for (_, name, row), record in zip(rows, records):
        inputs = row.split('|'); repeats = int(inputs[0])
        fields = record.split(b'|'); expected = ':'.join(inputs[1:]).encode()
        if (len(fields) != 3 or fields[0] != inputs[0].encode()
                or fields[1] != fields[2] or fields[1] != expected):
            raise AssertionError('caller changed or fixture inputs differ: ' + name)
        end = position + repeats * 5
        if end > len(lines) or any(not line.endswith(b'\n') for line in lines[position:end]):
            raise AssertionError('missing or unterminated direct diagnostics: ' + name)
        messages = [b''.join(lines[i:i+5]) for i in range(position, end, 5)]
        if len(set(messages)) > 1:
            raise AssertionError('repeated messages differ: ' + name)
        # Framing establishes five lines per call; actual Source bytes remain the oracle.
        for message in messages:
            parts = message.splitlines()
            if not all(part.startswith(prefix) for part, prefix in zip(parts,
                    (b'size: ', b'len=', b'type=', b'cmap=', b'cmap_len='))):
                raise AssertionError('unexpected output route or message framing: ' + name)
        position = end
        result.append(record + b'|' + b';'.join(message.hex().encode() for message in messages))
    if position != len(lines):
        raise AssertionError('unexpected trailing stderr')
    return result


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
    for name, expected in {**FORMAT_FILES, **STDERR_FILES}.items():
        if digest(zig.parent / 'lib/std' / name) != expected:
            parser.error('formatter/logging library differs from pins: ' + name)
    repo = Path(__file__).resolve().parent.parent
    probe = repo / 'zigimg/reference_probes/ras_debug'
    mode = 'ReleaseSafe' if args.v_prod else 'Debug'
    with work_directory(args.workdir, 'witty-ras-debug-') as root:
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
        v_stderr = {name: digest(v.parent / 'vlib' / name) for name in V_STDERR_FILES}
        provenance = dict(source_sha256=PINNED_SOURCE_SHA256, stdlib_sha256=PINNED_STDLIB_SHA256,
            formatter_sha256=FORMAT_FILES, stderr_sha256=STDERR_FILES, v_stderr_sha256=v_stderr, v_log_sha256=v_log, versions=versions, target=args.target,
            zig_mode=mode, v_prod=args.v_prod, fixtures=fixtures, implementation_sha256=implementations,
            runner_sha256=runner_hash, helper_sha256=helpers)
        (root / 'provenance.json').write_text(json.dumps(provenance, indent=2) + '\n')
        zbase = [str(zig), 'build-exe', '-target', args.target, '-lc', '-O', mode,
                 '--global-cache-dir', str(root / 'zig-global'), '--cache-dir', str(root / 'zig-cache')]
        vbase = [str(v), '-enable-globals', *(['-prod'] if args.v_prod else []), '-path', f'{repo}|@vlib|@vmodules']
        print(f'Building RAS debug: Source {mode}, V production={args.v_prod}', flush=True)
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
                outputs.append(observations(rows, result.stdout, result.stderr))
            for (group, name, row), a, b in zip(rows, *outputs):
                if a != b:
                    raise AssertionError(f'{enabled}/{name}: differing observation\n{row}\n{a!r}\n{b!r}')
                h.update(str(enabled).encode() + b'\0' + name.encode() + b'\0' + a + b'\n')
                groups[('debug-threshold-' if enabled else 'info-threshold-') + group] += 1
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
        for name, expected in v_stderr.items():
            if digest(v.parent / 'vlib' / name) != expected:
                raise AssertionError('V stderr implementation changed')
        for name, expected in {**FORMAT_FILES, **STDERR_FILES}.items():
            if digest(zig.parent / 'lib/std' / name) != expected:
                raise AssertionError('formatter library changed')
        summary = dict(returning_records=len(rows) * 2, return_groups=dict(groups), sha256=h.hexdigest(),
                       ras_cases=len(rows),
                       logger_configurations=2, direct_messages=sum(int(row.split('|')[0]) for _,_,row in rows)*2)
        (root / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
        print(json.dumps(summary, indent=2), flush=True)
        if summary['returning_records'] != EXPECTED_RETURNS or h.hexdigest() != EXPECTED_SHA256:
            raise AssertionError('locked RAS debug golden changed')


if __name__ == '__main__':
    main()
