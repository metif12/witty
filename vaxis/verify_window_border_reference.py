"""Compare unchanged public Window.child borders with checked native Vaxis."""
import argparse
import hashlib
import itertools
import json
import os
from pathlib import Path
import random
import re
import resource
import shutil
import subprocess
import sys
import tempfile

PROBE = Path(__file__).resolve().parent / 'reference_probes/window_border'
sys.path.insert(0, str(PROBE.parent / 'widgets_classic'))
from source_build import VAXIS_SHA256, UUCODE_PACKAGE, module, prepare_uucode, tree_hash
sys.path.insert(0, str(PROBE.parents[1]))
from verify_vxfw_surface_reference import checked_trap


def locations(index):
    return (0, 15, 1, 2, 4, 8)[index] if index < 6 else index - 6


def returning(case):
    sw, sh, length, width, height, x, y, px, py, cx, cy, cw, ch, loc, *_ = case
    length = sw * sh if length < 0 else length

    def checked(value):
        if not -65536 <= value <= 65535:
            raise OverflowError
        return value

    def child(w, h, ax, ay, rx, ry, ox, oy, maybe_w, maybe_h):
        max_h = max(checked(h - oy), 0)
        max_w = max(checked(w - ox), 0)
        return (min(max_w, maybe_w if maybe_w >= 0 else max_w),
                min(max_h, maybe_h if maybe_h >= 0 else max_h),
                checked(ax + ox), checked(ay + oy),
                min(checked(rx + ox), 0), min(checked(ry + oy), 0))

    try:
        w, h, ax, ay, rx, ry = child(width, height, x, y, px, py, cx, cy, cw, ch)
        if loc == 0:
            return True
        mask = locations(loc)

        def write(col, row):
            if row >= h or col >= w:
                return
            abs_x = checked(ax + col)
            if abs_x < 0:
                return
            abs_y = checked(ay + row)
            if abs_y < 0 or checked(rx + col) < 0 or checked(ry + row) < 0:
                return
            if abs_x >= sw or abs_y >= sh:
                return
            if abs_y * sw + abs_x >= length:
                raise IndexError

        if mask & 1:
            for i in range(w):
                write(i, 0)
        if mask & 4:
            for i in range(w):
                write(i, max(h - 1, 0))
        if mask & 8:
            for i in range(h):
                write(0, i)
        if mask & 2:
            for i in range(h):
                write(max(w - 1, 0), i)
        if mask & 1 and mask & 8:
            write(0, 0)
        if mask & 1 and mask & 2:
            write(max(w - 1, 0), 0)
        if mask & 4 and mask & 8:
            write(0, max(h - 1, 0))
        if mask & 4 and mask & 2:
            write(max(w - 1, 0), max(h - 1, 0))
        ox, oy = int(bool(mask & 8)), int(bool(mask & 1))
        child(w, h, ax, ay, rx, ry, ox, oy,
              max(max(w - ox, 0) - int(bool(mask & 2)), 0),
              max(max(h - oy, 0) - int(bool(mask & 4)), 0))
        return True
    except (OverflowError, IndexError):
        return False


def corpus():
    rows = []
    seen = set()
    rng = random.Random(0x424F52444552)

    def add(*case):
        if returning(case):
            row = '|'.join(map(str, case))
            if row not in seen:
                seen.add(row)
                rows.append(row)

    for w, h, loc, glyph, style, mutation in itertools.product(range(5), range(5), range(22), range(4), range(3), range(2)):
        add(6, 6, -1, w, h, 0, 0, 0, 0, 0, 0, -1, -1, loc, glyph, style, mutation)
    offsets = (-65536, -32769, -8, -2, -1, 0, 1, 2, 8, 32768, 65534, 65535)
    for _ in range(16384):
        w, h = rng.randrange(9), rng.randrange(9)
        sw, sh = rng.randrange(9), rng.randrange(9)
        x, y, px, py, cx, cy = (rng.choice(offsets) for _ in range(6))
        add(sw, sh, rng.choice((-1, 0, 1, 3, 17)), w, h, x, y, px, py, cx, cy,
            rng.choice((-1, 0, 1, 2, 8, 65535)), rng.choice((-1, 0, 1, 2, 8, 65535)),
            rng.randrange(22), rng.randrange(4), rng.randrange(3), rng.randrange(2))
    for width, height, loc, glyph in itertools.product((0, 1, 2, 65535), (0, 1, 2, 65535), (0, 2, 3, 4, 5, 6, 7, 8, 10, 14), (0, 2)):
        # Empty screen storage is safe when Screen clipping excludes every write.
        add(0, 0, 0, width, height, 0, 0, 0, 0, 0, 0, -1, -1, loc, glyph, 1, 1)
    for loc, glyph in itertools.product(range(22), range(4)):
        add(65535, 65535, 0, 0, 0, 65535, 65535, 0, 0, 0, 0, -1, -1, loc, glyph, 2, 1)
        add(1, 1, 1, 2, 2, -1, -1, -1, -1, 0, 0, -1, -1, loc, glyph, 2, 1)
        add(1, 1, 0, 2, 2, -1, -1, -1, -1, 0, 0, 0, 0, loc, glyph, 0, 0)
    # Returning neighbors of border endpoint and interior-offset failures.
    for loc in (0, 2, 3, 4, 5, 6, 7, 8, 10, 14):
        add(0, 0, 0, 1, 1, 65534, 65534, 0, 0, 0, 0, -1, -1, loc, 2, 1, 1)
        add(0, 0, 0, 0, 0, 65535, 65535, 0, 0, 0, 0, -1, -1, loc, 3, 2, 1)
    return rows


def verify(args, root):
    source = args.source.resolve() / 'src'
    if tree_hash(source) != VAXIS_SHA256:
        raise ValueError('vaxis source differs from the recorded pinned tree')
    shutil.copytree(source, root / 'src')
    env = dict(os.environ, VEXE=str(args.v.resolve()), V_C_ERROR_BUG_REPORT_DISABLED='1')
    print('Generating unchanged locked Unicode tables', file=sys.stderr, flush=True)
    graph = prepare_uucode(args.zig.resolve(), root, args.uucode.resolve(), 'aarch64-macos.14.0')
    mode = args.zig_mode or ('ReleaseSafe' if args.v_prod else 'Debug')
    native = [str(args.zig.resolve()), 'build-exe', '-O', mode, '-target', 'aarch64-macos.14.0', '-lc',
              *module('root', PROBE / 'reference.zig', ['vaxis']),
              *module('vaxis', root / 'src/main.zig', ['uucode']), *graph, f'-femit-bin={root/"native"}']
    translated = [str(args.v.resolve()), '-enable-globals', *(['-prod'] if args.v_prod else []), '-path',
                  f'{PROBE.parents[2]}|@vlib|@vmodules', '-o', str(root / 'translated'), str(PROBE / 'main.v')]
    (root / 'commands.json').write_text(json.dumps([native, translated], indent=2) + '\n')
    for name, command in (('native ' + mode, native), ('V production' if args.v_prod else 'V ordinary', translated)):
        print('Building ' + name, file=sys.stderr, flush=True)
        subprocess.run(command, env=env, check=True)
    rows = corpus()
    data = root / 'cases.txt'
    data.write_text('\n'.join(rows) + '\n')
    outputs = []
    for name in ('native', 'translated'):
        print(f'Running {name}: {len(rows)} returning records', file=sys.stderr, flush=True)
        result = subprocess.run([str(root / name), str(data)], env=env, capture_output=True, timeout=args.timeout)
        (root / (name + '.stdout')).write_bytes(result.stdout)
        (root / (name + '.stderr')).write_bytes(result.stderr)
        if result.returncode or result.stderr:
            raise AssertionError(f'{name} failed after {len(result.stdout.splitlines())} records: {result.stderr.decode(errors="replace")}')
        records = result.stdout.splitlines()
        if len(records) != len(rows):
            raise AssertionError(f'{name}: {len(records)} of {len(rows)} records')
        outputs.append(records)
    for index, (case, expected, actual) in enumerate(zip(rows, *outputs)):
        if expected != actual:
            raise AssertionError(f'record {index} ({case}): Source={expected!r}; V={actual!r}')
    overflows = ('init_width', 'init_height', 'init_x', 'init_y', 'init_parent_x', 'init_parent_y',
                 'top_x', 'bottom_y', 'left_y', 'right_x', 'inner_x', 'inner_y')
    assertions = ('top_bottom_order', 'left_right_order', 'empty_buffer', 'large_index')
    states = []
    for name in (*overflows, *assertions):
        label = 'trap_' + name
        snapshots = []
        categories = ('reached unreachable code', 'Assertion failed') if name in assertions else ('integer overflow', 'integer overflow')
        for executable, category in zip(('native', 'translated'), categories):
            path = root / (executable + '-' + label + '.state')
            result = subprocess.run([str(root / executable), label, str(path)], env=env, capture_output=True, timeout=args.trap_timeout)
            (root / (executable + '-' + label + '.stderr')).write_bytes(result.stderr)
            checked_trap(result, label, category, executable)
            state = path.read_bytes()
            if not re.fullmatch(rb'[0-9a-f]{1,16}\n', state):
                raise AssertionError(f'{executable}: missing/invalid failure-state observation for {label}')
            snapshots.append(state)
        if snapshots[0] != snapshots[1]:
            raise AssertionError(f'{label}: failure state differs: Source={snapshots[0]!r}; V={snapshots[1]!r}')
        states.append(label.encode() + b'|' + snapshots[0].rstrip(b'\n'))
    print(f'Window borders: {len(rows)} returning records, {len(states)} strict traps and fixture failure-state pairs; SHA256 ' + hashlib.sha256(b'\n'.join(outputs[0])).hexdigest())
    print('Fixture failure-state SHA256 ' + hashlib.sha256(b'\n'.join(states)).hexdigest())


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('zig', type=Path)
    parser.add_argument('v', type=Path)
    parser.add_argument('--uucode', type=Path, default=Path.home() / '.cache/zig/p' / UUCODE_PACKAGE)
    parser.add_argument('--v-prod', action='store_true')
    parser.add_argument('--zig-mode', choices=('Debug', 'ReleaseSafe'))
    parser.add_argument('--timeout', type=int, default=180)
    parser.add_argument('--trap-timeout', type=int, default=15)
    parser.add_argument('--workdir', type=Path)
    args = parser.parse_args()
    if args.timeout <= 0 or args.trap_timeout <= 0:
        parser.error('timeouts must be positive')
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
    if args.workdir:
        root = args.workdir.resolve()
        root.mkdir()
        verify(args, root)
    else:
        with tempfile.TemporaryDirectory(prefix='witty-window-border-') as directory:
            verify(args, Path(directory))


if __name__ == '__main__':
    main()
