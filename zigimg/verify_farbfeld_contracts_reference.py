"""Compare unchanged Farbfeld headers, stream behavior and checked image casts."""
import argparse
from collections import Counter
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import struct

from verify_jpeg_contracts_reference import implementation_hashes
from verify_tga_decode_reference import stdlib_hash, PINNED_STDLIB_SHA256
from verify_tiff_decode_reference import (
    ProofLog, tree_hash, work_directory, PINNED_SOURCE_SHA256, checked_trap,
)

EXPECTED_MAIN_SHA256 = '30e565c1698cf8f2571c3405cc15e428acd7036147fa212e996733267dea1b33'
EXPECTED_RETURN_SHA256 = '37dc326a7a00abc25b65792b07f77531565d3208007ad1425e21df2a3d63db35'
EXPECTED_STATE_SHA256 = 'ac87959369cc8d77564382026061029c1d58bce6f7c6266cdd616e6a9ee5b287'
EXPECTED_MAIN = 43226
EXPECTED_RETURNS = 1309
EXPECTED_TRAPS = 240
CAST_PANIC = 'integer does not fit in destination type'


def header(width, height):
    return b'farbfeld' + struct.pack('>II', width, height)


def reads():
    cases = []

    def add(group, name, data, entry, start=0):
        cases.append((group, name, data, ['--read', entry, start]))

    for width, height in ((0, 0), (0, 3), (3, 0), (1, 1), (1, 2), (2, 1), (2, 2), (3, 2)):
        data = header(width, height) + bytes((i * 37 + 19) & 255 for i in range(width * height * 8))
        for cut in range(len(data) + 1):
            for entry in (0, 1):
                for start in (0, 3):
                    add('read-prefix', f'read-{width}-{height}-{cut}-{entry}-{start}',
                        b'\xa5' * start + data[:cut], entry, start)
        for entry in (0, 1):
            add('read-trailing', f'trailing-{width}-{height}-{entry}', data + b'\x63\x58', entry)
    for width, height in ((0, 0x80000000), (0x80000000, 0), (0, 0xffffffff), (0xffffffff, 0)):
        for entry in (0, 1):
            add('read-wide-zero', f'wide-zero-{width}-{height}-{entry}', header(width, height), entry)
    for pos in range(8):
        invalid = bytearray(header(1, 1))
        invalid[pos] ^= 255
        for entry in (0, 1):
            add('read-magic', f'wrong-magic-{pos}-{entry}', bytes(invalid), entry)
    magics = [b'farbfeld', b'farbfeld\x63']
    for pos in range(8):
        invalid = bytearray(b'farbfeld')
        invalid[pos] ^= 255
        magics.append(bytes(invalid))
    for mi, magic in enumerate(magics):
        for cut in range(len(magic) + 1):
            for start in (0, 3):
                add('detect', f'detect-{mi}-{cut}-{start}', b'\xa5' * start + magic[:cut], 2, start)
    return cases


def writes():
    cases = []
    for wide in (0x100000000, 0x100000001, 0x8000000000000000, 0xffffffffffffffff):
        for width, height in ((wide, 0), (0, wide), (wide, wide), (wide, 0xffffffff), (0xffffffff, wide)):
            for fmt in (0, 0x308, 0x410):
                for capacity, start in ((0, 0), (8, 0), (8, 7), (64, 7)):
                    name = f'cast-{width}-{height}-{fmt}-{capacity}-{start}'
                    cases.append(('cast', name, [width, height, fmt, capacity, start]))
    # Nonzero starting cursors and exact/short capacity controls use the same
    # observer as traps, with all image dimensions inside Source's cast domain.
    for width, height in ((0, 0), (1, 2), (0xffffffff, 0xffffffff)):
        for fmt in (0, 0x308, 0x410):
            for capacity, start in ((0, 0), (8, 0), (8, 7), (31, 7), (32, 0), (39, 7), (64, 7)):
                name = f'write-control-{width}-{height}-{fmt}-{capacity}-{start}'
                cases.append(('write-control', name, [width, height, fmt, capacity, start]))
    return cases


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
    source = args.source.resolve() / 'src'
    zig = args.zig.resolve()
    v = args.v.resolve()
    if tree_hash(source) != PINNED_SOURCE_SHA256 or stdlib_hash(zig) != PINNED_STDLIB_SHA256:
        parser.error('Source or selected library differs from pins')
    repo = Path(__file__).resolve().parent.parent
    probe = repo / 'zigimg/reference_probes/farbfeld_contracts'
    mode = 'ReleaseSafe' if args.v_prod else 'Debug'
    env = dict(os.environ, VEXE=str(v), V_C_ERROR_BUG_REPORT_DISABLED='1')
    with work_directory(args.workdir, 'witty-farbfeld-contracts-') as root:
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
            fixtures=fixtures, implementation_sha256=implementations, runner_sha256=runner_hash,
        ), indent=2) + '\n')
        zbase = [str(zig), 'build-exe', '-target', args.target, '-lc', '-O', mode,
                 '--global-cache-dir', str(root / 'zig-global')]
        vbase = [str(v), '-enable-globals', *(['-prod'] if args.v_prod else []),
                 '-path', f'{repo}|@vlib|@vmodules']
        print(f'Building Farbfeld contracts: Source {mode}, V {"production" if args.v_prod else "ordinary"}', flush=True)
        proof.run(zbase + ['-femit-bin=' + str(root / 'native'), str(root / 'reference.zig')],
                  'build-source', timeout=args.timeout)
        proof.run(vbase + ['-o', str(root / 'translated'), str(root / 'main.v')],
                  'build-v', env=env, timeout=args.timeout)
        outputs = []
        for exe in ('native', 'translated'):
            result = proof.run([str(root / exe)], 'records-' + exe, timeout=args.timeout)
            if result.stderr:
                raise AssertionError('unexpected records stderr')
            outputs.append(result.stdout)
        if outputs[0] != outputs[1] or len(outputs[0].splitlines()) != EXPECTED_MAIN:
            raise AssertionError('header/write records differ')
        main_digest = hashlib.sha256(b'\n'.join(outputs[0].splitlines())).hexdigest()
        if main_digest != EXPECTED_MAIN_SHA256:
            raise AssertionError('main golden changed: ' + main_digest)
        returns = hashlib.sha256()
        states = hashlib.sha256()
        return_groups = Counter()
        trap_groups = Counter()
        inputs = {}

        def compare(group, name, arguments, trap=False):
            records = []
            for exe in ('native', 'translated'):
                path = root / (name + '-' + exe + '.state')
                command = [str(root / exe)] + [str(path) if arg is None else str(arg) for arg in arguments]
                records.append((proof.run(command, name + '-' + exe, timeout=args.timeout, check=False), path))
            if trap:
                for (result, path), exe in zip(records, ('native', 'translated')):
                    checked_trap(result, name + '/' + exe, CAST_PANIC)
                    messages = [m.group(1) for line in result.stderr.decode().splitlines()
                                if (m := re.fullmatch(r'(?:thread \d+ |V )?panic:\s*(.*)', line.strip()))]
                    if messages != [CAST_PANIC]:
                        raise AssertionError(f'{name}/{exe}: exact panic text differs')
                    if not path.exists():
                        raise AssertionError('missing state')
                snapshots = [path.read_bytes() for result, path in records]
                if not snapshots[0] or snapshots[0] != snapshots[1]:
                    raise AssertionError(f'{name}: state differs {snapshots}')
                states.update(name.encode() + b'\0' + CAST_PANIC.encode() + b'\0' + snapshots[0] + b'\n')
                trap_groups[group] += 1
            else:
                native, translated = [record[0] for record in records]
                if (native.returncode or translated.returncode or native.stderr or translated.stderr
                        or native.stdout != translated.stdout or len(native.stdout.splitlines()) != 1):
                    raise AssertionError(f'{name}: returns differ {native.stdout!r} {translated.stdout!r} {native.stderr!r} {translated.stderr!r}')
                returns.update(name.encode() + b'\0' + native.stdout)
                return_groups[group] += 1

        for group, name, data, arguments in reads():
            file = root / (name + '.ff')
            file.write_bytes(data)
            inputs[file.name] = hashlib.sha256(data).hexdigest()
            compare(group, name, arguments + [file])
        for group, name, arguments in writes():
            compare(group, name, ['--write', None] + arguments, group == 'cast')
        (root / 'input_sha256.json').write_text(json.dumps(inputs, indent=2) + '\n')
        for name, digest in inputs.items():
            if hashlib.sha256((root / name).read_bytes()).hexdigest() != digest:
                raise AssertionError('input changed')
        return_digest = returns.hexdigest()
        state_digest = states.hexdigest()
        if sum(return_groups.values()) != EXPECTED_RETURNS:
            raise AssertionError('return count changed')
        if sum(trap_groups.values()) != EXPECTED_TRAPS:
            raise AssertionError('trap count changed')
        if return_digest != EXPECTED_RETURN_SHA256:
            raise AssertionError('return golden changed')
        if state_digest != EXPECTED_STATE_SHA256:
            raise AssertionError('state golden changed')
        if (tree_hash(source) != PINNED_SOURCE_SHA256 or tree_hash(root / 'src') != PINNED_SOURCE_SHA256
                or stdlib_hash(zig) != PINNED_STDLIB_SHA256 or implementation_hashes(repo) != implementations
                or hashlib.sha256(Path(__file__).read_bytes()).hexdigest() != runner_hash):
            raise AssertionError('dependency, implementation or runner changed')
        for name, expected in fixtures.items():
            if any(hashlib.sha256((base / name).read_bytes()).hexdigest() != expected for base in (root, probe)):
                raise AssertionError('fixture changed')
        summary = dict(main_records=EXPECTED_MAIN, main_sha256=main_digest,
                       returning_records=sum(return_groups.values()), return_groups=dict(return_groups),
                       return_sha256=return_digest, paired_traps=sum(trap_groups.values()),
                       failure_groups=dict(trap_groups), state_sha256=state_digest,
                       zig_mode=mode, v_prod=args.v_prod)
        (root / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
        print(json.dumps(summary), flush=True)


if __name__ == '__main__':
    main()
