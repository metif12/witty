"""Compare public Vaxis URI reports, rendering, pretty-print and pixel mouse."""
import argparse
from collections import Counter
import hashlib
import itertools
import json
import os
from pathlib import Path
import random
import resource
import shutil
import subprocess
import sys
import tempfile
import time
from unittest.mock import patch

PROBE = Path(__file__).resolve().parent / 'reference_probes/session'
sys.path.insert(0, str(PROBE.parent / 'widgets_classic'))
from source_build import VAXIS_SHA256, UUCODE_SHA256, UUCODE_PACKAGE, module, prepare_uucode, tree_hash
from verify_vxfw_surface_reference import checked_trap


def corpus():
    rows = []

    def add(*values):
        rows.append('|'.join(map(str, values)))

    def uri(path, host):
        add('U', path.hex(), '-' if host is None else host.hex())

    hosts = (None, b'', b'localhost', b'host name/@', b'[::1]', b'%#?', b'\xe9\xff', b'host:123')
    for byte, host in itertools.product(range(256), hosts):
        uri(b'/a' + bytes((byte,)) + b'z', host)
    for byte in range(1, 256):  # Environment variables cannot contain a NUL byte.
        uri(b'/a b#c%25?@[]', b'a' + bytes((byte,)) + b'z')
    for path, host in itertools.product((b'', b'.', b'a/b', b'\0/', b'/', b'//',
            b'/hello\xc3\xa9/\xf0\x9f\x98\x80', bytes(range(256)), b'/' + bytes(range(256)),
            b'/a' * 4096), hosts):
        uri(path, host)

    buttons = (0, 1, 2, 3, 64, 65, 66, 67, 128, 129, 130, 131)
    dimensions = (0, 1, 2, 3, 80, 65535)
    pixels = (0, 1, 7, 200, 65535)
    rng = random.Random(0x53455353494F4E)
    for w, h, pw, ph, pixel in itertools.product(dimensions, dimensions, pixels, pixels, range(2)):
        add('M', w, h, pw, ph, pixel, rng.randrange(65536), rng.randrange(65536),
            0 if pixel else rng.randrange(65536), 0 if pixel else rng.randrange(65536),
            rng.choice(buttons), rng.randrange(4), rng.randrange(8))
    for button, kind, mods in itertools.product(buttons, range(4), range(8)):
        add('M', 3, 5, 10, 17, 1, 65535, 65535, 0, 0, button, kind, mods)
        add('M', 3, 5, 10, 17, 0, 65535, 65535, 7, 9, button, kind, mods)
    for w, h, pw, ph in ((0, 1, 5, 7), (1, 0, 5, 7), (0, 0, 65535, 65535)):
        add('M', w, h, pw, ph, 1, 10, 20, 1, 2, 0, 0, 0)
    for _ in range(2048):
        add('M', rng.choice(dimensions), rng.choice(dimensions), rng.choice(pixels), rng.choice(pixels),
            1, rng.randrange(65536), rng.randrange(65536), 0, 0,
            rng.choice(buttons), rng.randrange(4), rng.randrange(8))

    flags = (0, 1, 2, 3, 4, 8, 16, 24, 32, 48, 64, 96, 128, 129, 248, 255)
    for w, h, pattern, flag in itertools.product(range(8), range(8), range(7), flags):
        if pattern == 4 and flag & 16 and w*h and (w < 2 or h < 2):
            continue
        seed = (w*29 + h*17 + pattern*13 + flag) % 256
        # Three frames measure unchanged-cache, default/skip flags, then mutation.
        add('R' if (w+h+pattern+flag) % 2 else 'P', w, h, pattern, seed, flag,
            seed % 9, seed % 7, seed % 4, seed % 5, b'x'.hex(), 1)
    for seed, pattern in itertools.product(range(256), (1, 5, 6)):
        add('R' if seed % 2 else 'P', 4, 3, pattern, seed, seed,
            seed % 9, seed % 7, seed % 4, seed % 5, b'x'.hex(), 1)
    texts = (b'', b'a', b'a\n', b'\xcc\x81', b'\xe7\x95\x8c', b'\xf0\x9f\x98\x80',
             b'\xe1\x80a', b'\xf0\x9fab')
    for method, text, width, flag in itertools.product(range(3), texts, (0, 1, 2, 255), (0, 1, 8, 24, 255)):
        for op in ('R', 'P'):
            add(op, 5, 3, 1, method, flag, 6, 6, 1, 2, text.hex(), width)
    for shape, cursor, flag in itertools.product(range(9), range(7), (0, 1, 128, 129)):
        add('R', 0, 0, 0, 0, flag, shape, cursor, 5, 7, '', 1)
    # Source prettyPrint's u16 counter returns through 65,535, render uses usize.
    for op, w, h in (('R', 65535, 1), ('P', 65535, 1), ('R', 2, 32768)):
        add(op, w, h, 0, 0, 1 if op == 'R' else 0, 0, 0, 0, 0, '', 1)
    return rows


TRAPS = (
    ('mouse_x', 'reached unreachable code', 'Assertion failed'),
    ('mouse_y', 'reached unreachable code', 'Assertion failed'),
    ('render_size', 'reached unreachable code', 'Assertion failed'),
    ('render_last', 'reached unreachable code', 'Assertion failed'),
    ('cursor_row', 'integer overflow', 'integer overflow'),
    ('cursor_col', 'integer overflow', 'integer overflow'),
    ('pretty_index', 'integer overflow', 'integer overflow'),
    ('render_col', 'integer overflow', 'integer overflow'),
    ('scaled_unknown', 'reached unreachable code', 'Assertion failed'),
    ('scaled_overflow', 'integer overflow', 'integer overflow'),
    ('scaled_bounds', 'index out of bounds', 'index out of bounds'),
    ('denominator', 'reached unreachable code', 'reached unreachable code'),
)


def verify(args, root, env, mode):
    source = args.source.resolve() / 'src'
    shutil.copytree(source, root / 'src')
    fixtures = {path.name: hashlib.sha256(path.read_bytes()).hexdigest()
                for path in (PROBE / 'reference.zig', PROBE / 'main.v', Path(__file__))}
    metadata = {'source_sha256': VAXIS_SHA256, 'uucode_sha256': UUCODE_SHA256, 'fixtures': fixtures,
                'source_mode': mode, 'v_mode': 'production' if args.v_prod else 'ordinary',
                'target': args.target, 'environment': env,
                'source_writer': 'std.Io.Writer.Allocating with successful allocations',
                'source_build_sha256': hashlib.sha256((PROBE.parent / 'widgets_classic/source_build.py').read_bytes()).hexdigest()}
    (root / 'metadata.json').write_text(json.dumps(metadata, indent=2) + '\n')

    def invoke(label, command, timeout=args.timeout, **kwargs):
        (root / (label + '-argv.json')).write_text(json.dumps({'argv': command, 'cwd': str(kwargs.get('cwd', Path.cwd()))}, indent=2) + '\n')
        result = original_run(command, env=env, capture_output=True, timeout=timeout, **kwargs)
        (root / (label + '.stdout')).write_bytes(result.stdout)
        (root / (label + '.stderr')).write_bytes(result.stderr)
        return result

    original_run = subprocess.run
    dependency_commands = 0

    def dependency_run(command, **kwargs):
        nonlocal dependency_commands
        check = kwargs.pop('check', False)
        result = invoke('unicode-' + str(dependency_commands), command, **kwargs)
        dependency_commands += 1
        if check:
            result.check_returncode()
        return result

    print('Generating unchanged locked Unicode dependency tables', file=sys.stderr, flush=True)
    with patch('source_build.subprocess.run', dependency_run):
        graph = prepare_uucode(args.zig.resolve(), root, args.uucode.resolve(), args.target)
    commands = [('native ' + mode, [str(args.zig.resolve()), 'build-exe', '-O', mode, '-target', args.target, '-lc',
                 *module('root', PROBE / 'reference.zig', ['vaxis']), *module('vaxis', root / 'src/main.zig', ['uucode']),
                 *graph, f'-femit-bin={root / "native"}']),
                ('V production' if args.v_prod else 'V ordinary', [str(args.v.resolve()), '-enable-globals',
                 *(['-prod'] if args.v_prod else []), '-path', args.v_path or str(PROBE.parents[2]) + '|@vlib|@vmodules',
                 '-o', str(root / 'translated'), str(PROBE / 'main.v')])]
    for index, (label, command) in enumerate(commands):
        print('Building ' + label, file=sys.stderr, flush=True)
        result = invoke(('native' if index == 0 else 'translated') + '-build', command)
        if result.returncode:
            raise AssertionError(label + ' failed to build: ' + (result.stdout+result.stderr).decode(errors='replace'))
    rows = corpus()
    data = root / 'cases.txt'
    data.write_text('\n'.join(rows) + '\n')
    outputs = []
    for executable in ('native', 'translated'):
        print(f'Running {executable}: {len(rows)} returning records', file=sys.stderr, flush=True)
        start = time.monotonic()
        command = [str(root / executable), str(data)]
        (root / (executable + '-argv.json')).write_text(json.dumps({'argv': command, 'cwd': str(Path.cwd())}, indent=2) + '\n')
        with (root / (executable + '.stdout')).open('wb') as out, (root / (executable + '.stderr')).open('wb') as err:
            result = original_run(command, env=env, stdout=out, stderr=err, timeout=args.timeout)
        output = (root / (executable + '.stdout')).read_bytes().splitlines()
        error = (root / (executable + '.stderr')).read_bytes()
        if result.returncode or error or len(output) != len(rows):
            raise AssertionError(f'{executable} failed after {len(output)} of {len(rows)} records: ' + error.decode(errors='replace'))
        outputs.append(output)
        print(f'{executable} completed in {time.monotonic()-start:.2f}s', file=sys.stderr, flush=True)
    for i, (case, expected, actual) in enumerate(zip(rows, *outputs)):
        if expected != actual:
            raise AssertionError(f'record {i} ({case}): source={expected!r}, V={actual!r}')
    states = []
    for label, source_category, v_category in TRAPS:
        observations = []
        for executable, category in (('native', source_category), ('translated', v_category)):
            path = root / (executable + '-' + label + '.state')
            result = invoke(executable + '-' + label, [str(root / executable), '--trap', label, str(path)])
            checked_trap(result, label, category, executable)
            observations.append(path.read_bytes())
        if observations[0] != observations[1]:
            raise AssertionError(f'{label} panic state: source={observations[0]!r}, V={observations[1]!r}')
        states.append(label.encode() + b'|' + observations[0])
        print(f'{label}: strict panic category and retained state match', file=sys.stderr, flush=True)
    for name, path, expected in (('original source', source, VAXIS_SHA256), ('copied source', root / 'src', VAXIS_SHA256),
            ('original Unicode', args.uucode.resolve(), UUCODE_SHA256), ('copied Unicode', root / 'uucode', UUCODE_SHA256)):
        if tree_hash(path) != expected:
            raise AssertionError(name + ' changed during verification')
    for path in (PROBE / 'reference.zig', PROBE / 'main.v', Path(__file__)):
        if hashlib.sha256(path.read_bytes()).hexdigest() != fixtures[path.name]:
            raise AssertionError('fixture changed during verification: ' + str(path))
    output_hash = hashlib.sha256(b'\n'.join(outputs[0])).hexdigest()
    state_hash = hashlib.sha256(b'\n'.join(states)).hexdigest()
    metadata.update({'returning_records': len(rows), 'strict_traps': len(TRAPS), 'panic_states': len(states),
                     'output_sha256': output_hash, 'panic_state_sha256': state_hash, 'unchanged_source_postcheck': True})
    (root / 'metadata.json').write_text(json.dumps(metadata, indent=2) + '\n')
    print(f'Session: {len(rows)} returning records {dict(Counter(row[0] for row in rows))}, {len(TRAPS)} strict traps and panic states; '
          'SHA256 ' + output_hash + '; state SHA256 ' + state_hash)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('zig', type=Path)
    parser.add_argument('v', type=Path)
    parser.add_argument('--uucode', type=Path, default=Path.home() / '.cache/zig/p' / UUCODE_PACKAGE)
    parser.add_argument('--target', default='aarch64-macos.14.0')
    parser.add_argument('--v-prod', action='store_true')
    parser.add_argument('--zig-mode', choices=('Debug', 'ReleaseSafe'))
    parser.add_argument('--v-path', help=argparse.SUPPRESS)
    parser.add_argument('--timeout', type=int, default=180)
    parser.add_argument('--build-dir', type=Path, help='Keep fresh artifacts for inspection; directory must not exist')
    args = parser.parse_args()
    if args.timeout <= 0:
        parser.error('--timeout must be positive')
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
    if tree_hash(args.source.resolve() / 'src') != VAXIS_SHA256:
        parser.error('vaxis source differs from the recorded local source')
    # Record the complete child environment without retaining unrelated secrets.
    keys = ('PATH', 'HOME', 'TMPDIR', 'SDKROOT', 'MACOSX_DEPLOYMENT_TARGET', 'LANG', 'LC_ALL')
    env = {key: os.environ[key] for key in keys if key in os.environ}
    env.update(VEXE=str(args.v.resolve()), V_C_ERROR_BUG_REPORT_DISABLED='1')
    mode = args.zig_mode or ('ReleaseSafe' if args.v_prod else 'Debug')
    if args.build_dir:
        args.build_dir.mkdir(parents=True, exist_ok=False)
        verify(args, args.build_dir.resolve(), env, mode)
    else:
        with tempfile.TemporaryDirectory(prefix='witty-session-') as directory:
            verify(args, Path(directory), env, mode)


if __name__ == '__main__':
    main()
