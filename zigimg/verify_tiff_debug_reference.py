"""Compare public TIFF debug payloads, logger classification and caller immutability."""
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

EXPECTED_RETURNS = 3708
EXPECTED_SHA256 = 'd2b914e99be534e8d5b9dd464680bafef5522f9a052b41695b6a1c217957cc48'
FORMAT_FILES = {
    'fmt.zig': '667eac6285e472b5516ebebf8a6e69959a171be4fb97cac1e56419ffec20d500',
    'log.zig': 'a501bbda527d502fcc1cd0595a20c2487076c7e83c7636d6910ec2935ce8d59e',
    'std.zig': 'b78c7a6dec7a3ea3381bae30533309bd8de71994422c3f87fc9760e378c7e427',
    'Io/Writer.zig': 'f541f60754a1c4835381217e5072ce0eb311393efc38eb180c0adb740dd50543',
}
STATE_FILES = {'crypto.zig': '41bde1efcf6ddd6f1adbaefbb2559ff7dc281bf00da03b91cb069a7bf952066c', 'crypto/sha2.zig': 'b69748641b6505170756eb7f006c44ca1971f56f5aeab0d2848681698bfefcb9'}
V_STATE_FILES = ('crypto/sha256/sha256.v', 'crypto/sha256/sha256block_generic.v', 'encoding/binary/big_endian.v', 'encoding/binary/big_endian_fixed.v', 'encoding/binary/little_endian.v', 'encoding/binary/little_endian_fixed.v', 'encoding/binary/serialize.v', 'encoding/binary/stream.v', 'encoding/binary/unions.v', 'encoding/hex/hex.v', 'math/bits/bits.amd64.v', 'math/bits/bits.arm64.v', 'math/bits/bits.c.v', 'math/bits/bits.v', 'math/bits/bits_tables.v', 'math/bits/unsafe_bits.js.v', 'math/bits/unsafe_bits.v')
LOG_FILES = ('log.v', 'default.v', 'logger_interface.v', 'common.v', 'default.c.v')


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def corpus():
    rows = []
    counts = Counter()
    default = [1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 1, 1, 1]
    compressions = (1, 2, 3, 4, 5, 6, 8, 32771, 32773, 32946)
    bounds16 = (0, 1, 9, 10, 99, 100, 255, 256, 32767, 32768, 65534, 65535)
    bounds32 = sorted({0, 1, 255, 256, 65535, 65536, 2147483647, 2147483648,
                       4294967294, 4294967295} |
                      {10 ** power + delta for power in range(1, 10) for delta in (-1, 0, 1)})
    def csv(values): return ','.join(map(str, values))
    def add(group, scalars=None, offsets='n', byte_counts='n', bits=(0,)*8, bits_data='e:',
            extra=(0,)*8, extra_data='e:', palette=bytes(1024), palette_data='e:'):
        name = f'{group}-{counts[group]}'; counts[group] += 1
        fields = list(map(str, default if scalars is None else scalars))
        fields += [offsets, byte_counts, csv(bits), bits_data, csv(extra), extra_data,
                   palette.hex(), palette_data]
        rows.append((group, name, '|'.join(fields)))
    add('source-samples')
    add('source-samples', (1,32946,4294967295,2147483648,65535,4294967295,
        4294967295,1,0,2147483648,3,4294967295,65535,32768,255,65535),
        offsets='a:0,4294967295,10', byte_counts='a:', bits=(0,1,9,10,99,100,32768,65535),
        bits_data='v:1:3', extra=(65535,)*8, extra_data='e:65535,1',
        palette_data='e:00225cff0a80ff00')
    for compression, resolution, repeats in itertools.product(compressions, (1,2,3), range(4)):
        f=default.copy();f[0]=repeats;f[1]=compression;f[10]=resolution
        add('enums-repeat', f, offsets='n' if repeats%2==0 else 'a:',
            byte_counts='n' if repeats%2 else 'a:')
    for field, value in itertools.product((2,3,5,6,7,8,9,11), bounds32):
        f=default.copy();f[field]=value;add('u32-decimal-boundaries', f)
    for field, value in itertools.product((4,12,13,14,15), bounds16):
        f=default.copy();f[field]=value;add('u16-boundaries', f)
    for value in range(256):
        add('word-patterns', bits=tuple(((value+i)%256)*257 for i in range(8)),
            extra=tuple(((value+17*i)%256)*257 for i in range(8)),
            bits_data='v:0:8', extra_data='v:0:8')
    for buffer, position, value in itertools.product(range(2), range(8), bounds16):
        words=[0]*8;words[position]=value
        add('word-single-position', bits=words if buffer==0 else (0,)*8,
            extra=words if buffer else (0,)*8, bits_data='v:0:8', extra_data='v:0:8')
    for start in range(9):
        for length in range(9-start):
            add('word-borrowed-windows', bits=bounds16[:8], extra=bounds16[4:],
                bits_data=f'v:{start}:{length}', extra_data=f'v:{start}:{length}')
    ramp=bytes(i%256 for i in range(1024))
    for start, length in itertools.product((0,1,127,128,255,256),(0,1,2,8,127,128,255,256)):
        if start+length<=256:
            add('palette-borrowed-windows', palette=ramp, palette_data=f'v:{start}:{length}')
    for length, color_length in itertools.product((0,1,2,8,9,17),(0,1,2,255,256,257)):
        add('external-data-lengths', bits=bounds16[:8], extra=bounds16[4:],
            bits_data='e:'+csv((i*101)%65536 for i in range(length)),
            extra_data='e:'+csv(65535-(i*113)%65536 for i in range(length)),
            palette=ramp, palette_data='e:'+bytes(i%256 for i in range(color_length*4)).hex())
    optionals=('n', 'a:', *('a:'+csv((i*1234567)%4294967296 for i in range(n)) for n in (1,2,8,17,257)))
    for offsets, byte_counts in itertools.product(optionals, repeat=2):
        add('optional-strip-arrays', offsets=offsets, byte_counts=byte_counts)
    for byte in range(256):
        add('hidden-palette-components', palette=bytes((byte+i)%256 for i in range(1024)),
            palette_data='v:0:256')
    rng=random.Random(20261013)
    for i in range(512):
        f=[2, rng.choice(compressions), rng.randrange(4294967296), rng.randrange(4294967296),
           rng.randrange(65536), rng.randrange(4294967296), rng.randrange(4294967296),
           rng.randrange(4294967296), rng.randrange(4294967296), rng.randrange(4294967296),
           rng.randrange(1,4), rng.randrange(4294967296), rng.randrange(65536),
           rng.randrange(65536), rng.randrange(65536), rng.randrange(65536)]
        start=rng.randrange(9);length=rng.randrange(9-start)
        cstart=rng.randrange(257);clength=rng.randrange(257-cstart)
        add('seeded', f, offsets=rng.choice(optionals), byte_counts=rng.choice(optionals),
            bits=tuple(rng.randrange(65536) for _ in range(8)),
            extra=tuple(rng.randrange(65536) for _ in range(8)),
            bits_data=f'v:{start}:{length}' if i%2 else 'e:'+csv(rng.randrange(65536) for _ in range(length)),
            extra_data=f'v:{start}:{length}' if i%2 else 'e:'+csv(rng.randrange(65536) for _ in range(length)),
            palette=rng.randbytes(1024), palette_data=f'v:{cstart}:{clength}' if i%2 else 'e:'+rng.randbytes(clength*4).hex())
    return rows


def expected_state(row):
    """Fingerprint fixture inputs only; expected debug text comes exclusively from Source."""
    f = row.split('|')
    canonical = ':'.join(f[1:16]) + ';' + f[16] + ';' + f[17] + ';'
    for storage, data, separator in ((18, 19, ','), (20, 21, ','), (22, 23, '')):
        descriptor = f[data]
        if descriptor.startswith('v:'):
            start, length = map(int, descriptor[2:].split(':'))
            values = f[storage].split(',') if separator else [f[storage][i:i+8] for i in range(0, len(f[storage]), 8)]
            text = separator.join(values[start:start+length])
            alias = start if length else -2
        else:
            text = descriptor[2:]
            alias = -1 if text else -2
        canonical += text + '@' + str(alias) + ':' + f[storage] + ';'
    return hashlib.sha256(canonical.encode()).hexdigest().encode()


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
    for name, expected in {**FORMAT_FILES, **STATE_FILES}.items():
        if digest(zig.parent / 'lib/std' / name) != expected:
            parser.error('formatter/logging library differs from pins: ' + name)
    repo = Path(__file__).resolve().parent.parent
    probe = repo / 'zigimg/reference_probes/tiff_debug'
    mode = 'ReleaseSafe' if args.v_prod else 'Debug'
    with work_directory(args.workdir, 'witty-tiff-debug-') as root:
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
        v_state = {name: digest(v.parent / 'vlib' / name) for name in V_STATE_FILES}
        provenance = dict(source_sha256=PINNED_SOURCE_SHA256, stdlib_sha256=PINNED_STDLIB_SHA256,
            formatter_sha256=FORMAT_FILES, state_sha256=STATE_FILES, v_state_sha256=v_state, v_log_sha256=v_log, versions=versions, target=args.target,
            zig_mode=mode, v_prod=args.v_prod, fixtures=fixtures, implementation_sha256=implementations,
            runner_sha256=runner_hash, helper_sha256=helpers)
        (root / 'provenance.json').write_text(json.dumps(provenance, indent=2) + '\n')
        zbase = [str(zig), 'build-exe', '-target', args.target, '-lc', '-O', mode,
                 '--global-cache-dir', str(root / 'zig-global'), '--cache-dir', str(root / 'zig-cache')]
        vbase = [str(v), '-enable-globals', *(['-prod'] if args.v_prod else []), '-path', f'{repo}|@vlib|@vmodules']
        print(f'Building TIFF debug: Source {mode}, V production={args.v_prod}', flush=True)
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
                if len(fields) != 4 or fields[2] != fields[3] or fields[2] != expected_state(row):
                    raise AssertionError('caller mutated or malformed observation')
                expected_count = int(row.split('|')[0]) if enabled else 0
                if int(fields[0]) != expected_count or fields[1].count(b'debug:default:') != expected_count:
                    raise AssertionError('callback count or classification differs')
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
        for name, expected in v_state.items():
            if digest(v.parent / 'vlib' / name) != expected:
                raise AssertionError('V fingerprint or encoding library changed')
        for name, expected in {**FORMAT_FILES, **STATE_FILES}.items():
            if digest(zig.parent / 'lib/std' / name) != expected:
                raise AssertionError('formatter library changed')
        summary = dict(returning_records=len(rows) * 2, return_groups=dict(groups), sha256=h.hexdigest(),
                       tiff_cases=len(rows),
                       logger_configurations=2)
        (root / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
        print(json.dumps(summary, indent=2), flush=True)
        if summary['returning_records'] != EXPECTED_RETURNS or h.hexdigest() != EXPECTED_SHA256:
            raise AssertionError('locked TIFF debug golden changed')


if __name__ == '__main__':
    main()
