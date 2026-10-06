"""Compare Screen creation, borrowed cells, clipping and clear with unchanged Vaxis."""
import argparse
import hashlib
import itertools
import os
from pathlib import Path
import random
import resource
import shutil
import subprocess
import sys
import tempfile
import time

PROBE = Path(__file__).resolve().parent / 'reference_probes/screen_cells'
sys.path.insert(0, str(PROBE.parent / 'widgets_classic'))
from source_build import VAXIS_SHA256, UUCODE_PACKAGE, module, prepare_uucode, tree_hash
from verify_vxfw_surface_reference import checked_trap


def corpus():
    rows = ['D']
    def add(*values):
        rows.append('|'.join(map(str, values)))
    for w, h in itertools.product(range(9), repeat=2):
        add('N', w, h, w * 8191, h * 8191)
    add('N', 65535, 0, 65535, 0)
    add('N', 0, 65535, 0, 65535)
    for n in range(256):
        add('O', 2, 2, 5, 1, 1, 1, 1, 1, n, 1, n)
    choices = (0, 1, 2, 3, 7, 255, 256, 32768, 65534, 65535)
    rng = random.Random(0x53435245454e)
    for _ in range(8192):
        op = rng.choice(('O', 'R', 'W'))
        w, h = rng.choice(choices), rng.choice(choices)
        length = rng.randrange(17)
        wc, wr, rc, rr = (rng.choice(choices) for _ in range(4))
        if op != 'R' and wc < w and wr < h and wr*w+wc >= length:
            continue
        if op != 'W' and rc < w and rr < h and rr*w+rc >= length:
            continue
        add(op, w, h, length, wc, wr, rc, rr, rng.randrange(2), rng.randrange(256), rng.randrange(2), rng.randrange(256))
    for w, h in itertools.product(choices, repeat=2):
        add('O', w, h, 1, 0, 0, 0, 0, 1, 255, 1, 255)
        add('O', w, h, 0, w, h, w, h, 1, 254, 1, 254)
    for w, h in ((0, 0), (1, 1), (65535, 65535)):
        add('R', w, h, 16, 0, 0, w, h, 1, 0, 1, 0)
    return rows


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
    parser.add_argument('--timeout', type=int, default=120)
    args = parser.parse_args()
    if args.timeout <= 0:
        parser.error('--timeout must be positive')
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
    source = args.source.resolve() / 'src'
    if tree_hash(source) != VAXIS_SHA256:
        parser.error('vaxis source differs from the recorded local source')
    env = dict(os.environ, VEXE=str(args.v.resolve()), V_C_ERROR_BUG_REPORT_DISABLED='1')
    mode = args.zig_mode or ('ReleaseSafe' if args.v_prod else 'Debug')
    rows = corpus()
    with tempfile.TemporaryDirectory(prefix='witty-screen-cells-') as directory:
        root = Path(directory)
        shutil.copytree(source, root / 'src')
        print('Generating unchanged locked Unicode dependency tables', file=sys.stderr, flush=True)
        graph = prepare_uucode(args.zig.resolve(), root, args.uucode.resolve(), args.target)
        commands = [('native ' + mode, [str(args.zig.resolve()), 'build-exe', '-O', mode, '-target', args.target, '-lc',
                     *module('root', PROBE / 'reference.zig', ['vaxis']), *module('vaxis', root / 'src/main.zig', ['uucode']),
                     *graph, f'-femit-bin={root / "native"}']),
                    ('V production' if args.v_prod else 'V ordinary', [str(args.v.resolve()), '-enable-globals',
                     *(['-prod'] if args.v_prod else []), '-path', args.v_path or str(PROBE.parents[2]) + '|@vlib|@vmodules',
                     '-o', str(root / 'translated'), str(PROBE / 'main.v')])]
        for label, command in commands:
            print('Building ' + label, file=sys.stderr, flush=True)
            subprocess.run(command, env=env, check=True)
        data = root / 'cases.txt'
        data.write_text('\n'.join(rows) + '\n')
        outputs = []
        for executable in ('native', 'translated'):
            print(f'Running {executable}: {len(rows)} returning records', file=sys.stderr, flush=True)
            start = time.monotonic()
            result = subprocess.run([str(root / executable), str(data)], env=env, capture_output=True, timeout=args.timeout)
            if result.returncode or result.stderr:
                raise AssertionError(f'{executable} failed after {len(result.stdout.splitlines())} records: ' + result.stderr.decode(errors='replace'))
            output = result.stdout.splitlines()
            if len(output) != len(rows):
                raise AssertionError(f'{executable} returned {len(output)} of {len(rows)} records')
            outputs.append(output)
            print(f'{executable} completed in {time.monotonic()-start:.2f}s', file=sys.stderr, flush=True)
        for i, (case, expected, actual) in enumerate(zip(rows, *outputs)):
            if expected != actual:
                raise AssertionError(f'record {i} ({case}): source={expected!r}, V={actual!r}')
        cases = ((2, 2, 0, 0, 0), (2, 2, 1, 1, 0), (2, 32769, 1, 0, 32768),
                 (65535, 65535, 1, 0, 32769), (65535, 65535, 1, 65534, 65534), (65535, 2, 0, 65534, 1))
        for i, (w, h, length, col, row) in enumerate(cases):
            for op in ('R', 'W'):
                data.write_text(f'{op}|{w}|{h}|{length}|{col}|{row}|{col}|{row}|0|0|0|0\n')
                for executable, category in (('native', 'reached unreachable code'), ('translated', 'Assertion failed')):
                    result = subprocess.run([str(root / executable), str(data)], env=env, capture_output=True, timeout=15)
                    checked_trap(result, f'{op}_short_{i}', category, executable)
        print(f'Screen cells: {len(rows)} returning records, {2*len(cases)} strict traps; SHA256 ' + hashlib.sha256(b'\n'.join(outputs[0])).hexdigest())


if __name__ == '__main__':
    main()
