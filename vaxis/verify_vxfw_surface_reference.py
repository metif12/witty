"""Compare Surface/SubSurface and delegated Window paths with unchanged Vaxis."""
import argparse
import hashlib
import itertools
import os
from pathlib import Path
import random
import re
import resource
import shutil
import subprocess
import sys
import tempfile
import time

PROBE = Path(__file__).resolve().parent / 'reference_probes/vxfw_surface'
sys.path.insert(0, str(PROBE.parent / 'widgets_classic'))
from source_build import VAXIS_SHA256, UUCODE_PACKAGE, module, prepare_uucode, tree_hash


def corpus():
    rows = []
    rng = random.Random(0x53555246414345)

    def add(*parts):
        rows.append('|'.join(map(str, parts)))

    for width, height in itertools.product(range(16), repeat=2):
        add('N', width, height)
    for width, height in ((0, 65535), (65535, 0), (1, 65535), (65535, 1), (255, 257)):
        add('N', width, height)
    for width, height in itertools.product(range(1, 9), repeat=2):
        for wc, wr, rc, rr, trim in ((0, 0, 0, 0, 0), (width-1, height-1, width-1, height-1, height),
                                     (width, height, 0, 0, height//2), (65535, 65535, width-1, height-1, height)):
            add('O', width, height, wc, wr, rc, rr, trim)
    for _ in range(1024):
        width, height = rng.randrange(1, 10), rng.randrange(1, 10)
        add('O', width, height, rng.randrange(width+2), rng.randrange(height+2),
            rng.randrange(width), rng.randrange(height), rng.randrange(height+1))

    offsets = (-65536, -32769, -1, 0, 1, 32768, 65534, 65535)
    sizes = (0, 1, 2, 32767, 32768, 65535)
    points = (0, 1, 32768, 65534, 65535)
    for _ in range(8192):
        x, y, width, height, col, row = (rng.choice(offsets), rng.choice(offsets), rng.choice(sizes),
                                      rng.choice(sizes), rng.choice(points), rng.choice(points))
        if col >= x and row >= y:
            if x + width > 65535:
                continue
            if col < x + width and y + height > 65535:
                continue
        add('S', x, y, width, height, col, row)
    # Explicit short-circuit returning neighbors of the isolated endpoint traps.
    add('S', 65535, 0, 1, 1, 65534, 0)
    add('S', 0, 65535, 1, 1, 1, 65535)
    add('S', -65536, -65536, 65535, 65535, 0, 0)
    add('S', 32768, 32768, 1, 1, 32768, 32768)

    for _ in range(4096):
        width, height = rng.choice(sizes), rng.choice(sizes)
        x, y, px, py, cx, cy = (rng.choice(offsets) for _ in range(6))
        if width-cx > 65535 or height-cy > 65535:
            continue
        if any(not -65536 <= value <= 65535 for value in (x+cx, y+cy, px+cx, py+cy)):
            continue
        add('W', width, height, x, y, px, py, cx, cy, rng.choice((-1, 0, 1, 2, 65535)), rng.choice((-1, 0, 1, 2, 65535)))
    for x, y in itertools.product((-32769, -1, 0, 32768), repeat=2):
        add('W', 2, 2, 0, 0, 0, 0, x, y, -1, -1)
        add('W', 2, 2, 0, 0, 0, 0, x, y, 1, 1)

    for _ in range(512):
        width, height = rng.randrange(1, 9), rng.randrange(1, 9)
        choices = (-32769, -1, 0, 1, 2, 3, 32768)
        add('T', width, height, rng.choice(choices), rng.choice(choices), rng.randrange(5),
            rng.choice(choices), rng.choice(choices), rng.randrange(5), rng.randrange(5),
            rng.randrange(width), rng.randrange(height))
    for z1, z2, focus in itertools.product(range(3), range(3), range(5)):
        add('T', 3, 3, 0, 0, z1, 0, 0, z2, focus, 0, 0)

    for _ in range(1024):
        width, height = rng.randrange(7), rng.randrange(7)
        x, y, px, py = (rng.choice(offsets[1:]) for _ in range(4))
        col, row = rng.randrange(9), rng.randrange(9)
        # Cursor adds absolute offsets before checking dimensions; reads/writes
        # check dimensions first and then each clipping expression in order.
        if x + col > 65535:
            continue
        if x + col >= 0 and y + row > 65535:
            continue
        if row < height and col < width and x + col >= 0 and y + row >= 0:
            if px + col > 65535 or (px + col >= 0 and py + row > 65535):
                continue
        add('C', width, height, x, y, px, py, col, row)
    add('C', 0, 0, 0, 0, 65535, 65535, 1, 1)
    add('C', 0, 0, -1, 65535, 65535, 65535, 0, 1)
    add('C', 2, 2, -1, 65535, 65535, 65535, 0, 1)
    return rows


def checked_trap(result, label, category, executable):
    texts = [value.decode(errors='replace') for value in (result.stdout, result.stderr)]
    headers = [match.group(1) for text in texts for line in text.splitlines()
               if (match := re.match(r'^(?:thread \d+ )?(?:V )?panic:\s*(.*)$', line))]
    unexpected = any(line.lstrip().startswith('UNEXPECTED') for text in texts for line in text.splitlines())
    if result.returncode == 0 or result.stdout or unexpected or not any(value.startswith(category) for value in headers):
        raise AssertionError(f'{executable}: {label} did not preserve {category!r}: ' + '\n'.join(texts))


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
    mode = args.zig_mode or ('ReleaseSafe' if args.v_prod else 'Debug')
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
    source = args.source.resolve() / 'src'
    if tree_hash(source) != VAXIS_SHA256:
        parser.error('vaxis source differs from the recorded local source')
    env = dict(os.environ, VEXE=str(args.v.resolve()), V_C_ERROR_BUG_REPORT_DISABLED='1')
    rows = corpus()
    with tempfile.TemporaryDirectory(prefix='witty-vxfw-surface-') as directory:
        root = Path(directory)
        shutil.copytree(source, root / 'src')
        print('Generating unchanged locked Unicode dependency tables', file=sys.stderr, flush=True)
        graph = prepare_uucode(args.zig.resolve(), root, args.uucode.resolve(), args.target)
        native = [str(args.zig.resolve()), 'build-exe', '-O', mode, '-target', args.target, '-lc',
                  *module('root', PROBE / 'reference.zig', ['vaxis']), *module('vaxis', root / 'src/main.zig', ['uucode']),
                  *graph, f'-femit-bin={root / "native"}']
        options = ['-enable-globals'] + (['-prod'] if args.v_prod else [])
        path = ['-path', args.v_path or str(PROBE.parents[2]) + '|@vlib|@vmodules']
        for label, command in [('native ' + mode, native), ('V production' if args.v_prod else 'V ordinary',
                               [str(args.v.resolve()), *options, *path, '-o', str(root / 'translated'), str(PROBE / 'main.v')])]:
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
                raise AssertionError(f'{executable} failed after {len(result.stdout.splitlines())} complete output rows: ' + result.stderr.decode(errors='replace'))
            output = result.stdout.splitlines()
            if len(output) != len(rows):
                raise AssertionError(f'{executable} returned {len(output)} of {len(rows)} records')
            outputs.append(output)
            print(f'{executable} completed in {time.monotonic()-start:.2f}s', file=sys.stderr, flush=True)
        for index, (case, expected, actual) in enumerate(zip(rows, *outputs)):
            if expected != actual:
                raise AssertionError(f'record {index} ({case}): source={expected!r}, V={actual!r}')
        assertions = ('write_short', 'read_col', 'read_row', 'read_short', 'trim_height', 'hit', 'render_short')
        overflows = ('create', 'write_mul', 'write_add', 'trim_mul', 'render_mul', 'contains_col', 'contains_row',
                     'child_max_x', 'child_max_y', 'child_abs_x', 'child_abs_y', 'child_parent_x', 'child_parent_y',
                     'child_negative_parent', 'cursor_x', 'cursor_y', 'window_write_abs', 'window_read_abs',
                     'window_write_parent', 'window_read_parent')
        traps = {f'trap_{name}': ('reached unreachable code', 'Assertion failed') for name in assertions}
        traps.update({f'trap_{name}': ('integer overflow', 'integer overflow') for name in overflows})
        traps['trap_trim_short'] = ('index out of bounds', 'index out of bounds')
        for label, categories in traps.items():
            for executable, category in zip(('native', 'translated'), categories):
                result = subprocess.run([str(root / executable), label], env=env, capture_output=True, timeout=15)
                checked_trap(result, label, category, executable)
        print(f'Surface/Window: {len(rows)} returning records, {len(traps)} strict traps; SHA256 ' + hashlib.sha256(b'\n'.join(outputs[0])).hexdigest())


if __name__ == '__main__':
    main()
