"""Compare vxfw ScrollView with unchanged pinned source and locked uucode."""
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

PROBE = Path(__file__).resolve().parent / 'reference_probes/vxfw_scroll_view'
sys.path.insert(0, str(PROBE.parent / 'widgets_classic'))
from source_build import VAXIS_SHA256, UUCODE_PACKAGE, module, prepare_uucode, tree_hash

COUNTS = [0, 1, 4, 3, 5, 3, 1, 2, 3]
HEIGHTS = [[], [1], [3, 1, 1, 2], [0, 0, 0], [5, 2, 7, 1, 3], [255, 256, 1000], [65535], [65535, 65535], [1, 1, 1]]


def row(kind='D', action=0, source=0, dataset=2, cursor=0, top=0,
        offset=0, pending=0, left=0, more_v=1, more_h=1, wants=0,
        count=-1, draw_cursor=0, wheel=3, last_height=0, build_mode=0,
        draw_mode=0, flags=0, width=8, height=4):
    return '|'.join(map(str, (kind, action, source, dataset, cursor, top, offset,
        pending, left, more_v, more_h, wants, count, draw_cursor, wheel,
        last_height, build_mode, draw_mode, flags, width, height)))


def corpus():
    records = []
    rng = random.Random(0x5343524f4c4c56494557)
    for action, pending, amount, top, offset, more in itertools.product(range(2),
            (-65536, -65535, -255, -1, 0, 1, 255, 65534, 65535), (0, 1, 2, 255),
            (0, 1, 0xffffffff), (-1, 0, 1), (0, 1)):
        active = more if action == 0 else top != 0 or offset != 0
        result = pending + amount if action == 0 else pending - amount
        if active and not -65536 <= result <= 65535:
            continue
        records.append(row('S', action, top=top, offset=offset, pending=pending,
                           more_v=more, width=amount))
    for action, left, amount, more in itertools.product((2, 3),
            (0, 1, 2, 254, 255, 256, 0xfffffffe, 0xffffffff), (0, 1, 2, 255), (0, 1)):
        records.append(row('S', action, left=left, more_h=more, width=amount))
    for dataset, source, action, cursor, top, count in itertools.product(range(5),
            (0, 1), range(4), (0, 1, 3, 6), (0, 1, 3), (-1, 1, 3, 0xffffffff)):
        if action in (0, 1) and count == -1 and dataset == 0 and (action == 0 or cursor != 0):
            continue  # Empty slices trap; missing builder index zero loops.
        records.append(row('N', action, source, dataset, cursor, top,
            offset=rng.choice((-1, 0, 1)), pending=2, count=count,
            flags=rng.randrange(8), build_mode=0))
    for source, action, cursor, top, count in itertools.product((0, 1), range(3),
            (0, 0xffffffff), (0, 0xffffffff), (1, 0xffffffff)):
        records.append(row('N', action, source, 2, cursor, top, count=count, flags=0))
    for mode, action, cursor in itertools.product(range(1, 6), range(4), range(4)):
        records.append(row('N', action, 1, 2, cursor, build_mode=mode, flags=0))
    for action, draw_cursor, cursor, more_v, more_h, flags in itertools.product(
            range(28), (0, 1), (0, 1, 3), (0, 1), (0, 1), (0, 3, 7)):
        records.append(row('E', action, 0, 2, cursor, top=1, offset=1,
            more_v=more_v, more_h=more_h, draw_cursor=draw_cursor, count=4,
            left=1, last_height=rng.choice((0, 1, 2, 3, 254, 255)), flags=flags))
    for dataset, source, width, height, offset, pending in itertools.product(range(5),
            (0, 1), (0, 2, 3, 8), (0, 1, 4, 10), (0, 1, 4), (-3, 0, 1, 3)):
        for top in range(COUNTS[dataset] + 1):
            records.append(row('D', source=source, dataset=dataset, top=top,
                offset=offset, pending=pending, width=width, height=height))
    for dataset, source, cursor, width, height, pending, draw_cursor in itertools.product(
            (1, 2, 3, 4), (0, 1), (0, 1, 3), (2, 3, 8), (0, 1, 4, 10), (0, 2), (0, 1)):
        if cursor >= COUNTS[dataset]:
            continue
        records.append(row('D', source=source, dataset=dataset, cursor=cursor,
            pending=pending, width=width, height=height, draw_cursor=draw_cursor))
        # The original else branch deinitializes the list, then appends to
        # its undefined state. Keep that branch out of defined parity.
        if HEIGHTS[dataset][cursor] < height:
            records.append(row('D', source=source, dataset=dataset, cursor=cursor,
                pending=pending, width=width, height=height, draw_cursor=draw_cursor, wants=1))
    for dataset, source in itertools.product(range(5), (0, 1)):
        records.append(row('D', source=source, dataset=dataset, cursor=0xffffffff,
                           draw_cursor=1, width=2, height=4))
    for source, dataset, action, width, height, draw_cursor in itertools.product((0, 1),
            (1, 2, 3, 4), range(8), (2, 3, 8), (4, 10), (0, 1)):
        # Skip the undefined-list reuse branch after navigation/ensure.
        if max(HEIGHTS[dataset]) >= height:
            continue
        records.append(row('T', action, source, dataset, width=width, height=height,
            draw_cursor=draw_cursor, flags=rng.randrange(8), last_height=3))
    for mode, draw_mode, top, pending in itertools.product(range(6), range(6), (0, 1), (-2, 0, 2)):
        # Sparse builder holes can leave top nonzero with no prior items.
        if mode == 1 and top != 0:
            continue
        records.append(row('D', source=1, top=top, pending=pending,
                           build_mode=mode, draw_mode=draw_mode, width=8, height=4))
    for dataset, source, top, left in itertools.product((5, 6), (0, 1), (0, 1), (0, 65535)):
        records.append(row('D', source=source, dataset=dataset, top=top, left=left,
                           width=65535, height=1))
    for left in (0, 65536, 0xffffffff):
        records.append(row('D', dataset=0, left=left, width=0, height=0))
    records.append(row('D', source=1, dataset=8, top=0xfffffffd, pending=2,
                       build_mode=6, width=3, height=1))
    return list(dict.fromkeys(records))


TRAPS = {
    'lines_down': (row('S', 0, pending=65535, width=1), b'integer overflow'),
    'lines_up': (row('S', 1, top=1, pending=-65536, width=1), b'integer overflow'),
    'draw_add': (row(offset=65535, pending=1), b'integer overflow'),
    'draw_neg': (row(offset=-65536), b'integer overflow'),
    'count_next': (row('N', 0, count=0), b'integer overflow'),
    'count_prev': (row('N', 1, cursor=1, count=0), b'integer overflow'),
    'slice_next_empty': (row('N', 0, dataset=0), b'integer overflow'),
    'slice_prev_empty': (row('N', 1, dataset=0, cursor=1), b'integer overflow'),
    'next_increment': (row('N', 0, cursor=0xffffffff), b'integer overflow'),
    'builder_increment': (row('N', 0, source=1, cursor=0xffffffff), b'integer overflow'),
    'cursor_sub': (row(source=1, top=1, wants=1, width=3, height=1), b'integer overflow'),
    'cursor_bounds': (row(source=1, dataset=1, cursor=5, wants=1, height=1), b'index out of bounds'),
    'child_width': (row(draw_cursor=1, width=1), b'integer overflow'),
    'left_cast': (row(left=65536), (b'integer does not fit in destination type', b'integer cast truncated bits')),
    'height_accumulate': (row(dataset=7, cursor=1, wants=1, width=0, height=1), b'integer overflow'),
    'cursor_anchor_sub': (row(dataset=7, cursor=1, wants=1, offset=65535, width=0, height=0), b'integer overflow'),
    'cursor_buffer_product': (row(dataset=6, draw_cursor=1, width=2, height=1), b'integer overflow'),
    'insert_empty': (row(source=1, dataset=0, top=1, offset=-1, height=1), b'integer overflow'),
    'short_top': (row(source=1, dataset=0, top=2, height=1), (b'reached unreachable code', b'Assertion failed')),
    'top_add': (row(source=1, dataset=8, top=0xffffffff, pending=2, build_mode=6, width=3, height=1), b'integer overflow'),
    'unbounded_width': (row(width=-1), (b'reached unreachable code', b'Assertion failed')),
    'unbounded_height': (row(height=-1), (b'reached unreachable code', b'Assertion failed')),
}
HANGS = {name: row('N', action, source=1, dataset=0, cursor=cursor)
         for name, action, cursor in (('next_missing_zero', 0, 0), ('prev_missing_zero', 1, 1))}
UNDEFINED = row(dataset=1, cursor=0, wants=1, width=3, height=1)
COMPILER_FAILURES = ('segmentation fault', 'segfault', 'bus error', 'illegal instruction',
    'panic:', 'assertion failed', 'internal compiler error', 'compiler bug',
    'please report this bug', 'c compilation failed', 'c compilation error',
    'c error found', 'c compiler error', 'c backend failure', 'failed in the c backend',
    'linker command failed', 'undefined reference')


def panic_category(result, expected):
    if result.returncode == 0 or result.stdout:
        return False
    if any(line.startswith(b'UNEXPECTED:') for line in result.stderr.splitlines()):
        return False
    return any(match.group(1).startswith(expected) for line in result.stderr.splitlines()
        if (match := re.fullmatch(rb'(?:thread [0-9]+ )?(?:V )?panic:\s*(.*)', line)))


def ordinary_rejection(result, label):
    text = (result.stdout + result.stderr).decode(errors='replace')
    if result.returncode != 1 or 'error:' not in text or any(tag in text.lower() for tag in COMPILER_FAILURES):
        raise AssertionError(f'{label}: expected ordinary type rejection: {text}')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('zig', type=Path)
    parser.add_argument('v', type=Path)
    parser.add_argument('--uucode', type=Path, default=Path.home() / '.cache/zig/p' / UUCODE_PACKAGE)
    parser.add_argument('--target', default='aarch64-macos.14.0')
    parser.add_argument('--v-prod', action='store_true')
    parser.add_argument('--zig-mode', choices=('Debug', 'ReleaseSafe'))
    parser.add_argument('--keep', type=Path, help=argparse.SUPPRESS)
    args = parser.parse_args()
    mode = args.zig_mode or ('ReleaseSafe' if args.v_prod else 'Debug')
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
    source = args.source.resolve() / 'src'
    if tree_hash(source) != VAXIS_SHA256:
        parser.error('vaxis source differs from pinned source tree')
    environment = dict(os.environ, VEXE=str(args.v.resolve()), V_C_ERROR_BUG_REPORT_DISABLED='1')
    with tempfile.TemporaryDirectory(prefix='witty-scroll-view-') as folder:
        root = Path(folder)
        shutil.copytree(source, root / 'src')
        graph = prepare_uucode(args.zig.resolve(), root, args.uucode.resolve(), args.target)
        options = ['-prod'] if args.v_prod else []
        def native(path, output):
            return [str(args.zig.resolve()), 'build-exe', '-target', args.target, '-lc', '-O', mode,
                *module('root', path, ['vaxis']), *module('vaxis', root / 'src/main.zig', ['uucode']), *graph, output]
        try:
            print(f'Building unchanged source ({mode}) and V ({"production" if args.v_prod else "ordinary"})', flush=True)
            subprocess.run(native(PROBE / 'reference.zig', f'-femit-bin={root / "native"}'), check=True)
            subprocess.run([str(args.v.resolve()), *options, '-o', str(root / 'translated'), str(PROBE / 'main.v')], env=environment, check=True)
            rows = corpus()
            path = root / 'corpus.txt'; path.write_text('\n'.join(rows) + '\n')
            print(f'Comparing {len(rows)} returning records', flush=True)
            outputs = []
            for executable in ('native', 'translated'):
                result = subprocess.run([str(root / executable), str(path)], capture_output=True, timeout=120)
                if result.returncode:
                    raise AssertionError(f'{executable} returning corpus failed: {result.stderr.decode(errors="replace")}')
                outputs.append(result.stdout.splitlines())
            if any(len(output) != len(rows) for output in outputs):
                raise AssertionError([len(rows)] + [len(output) for output in outputs])
            for index, (record, expected, actual) in enumerate(zip(rows, *outputs)):
                if expected != actual:
                    raise AssertionError(f'row {index} ({record}): native={expected!r}\nV={actual!r}')
            print(f'Checking {len(TRAPS)} isolated traps, {len(HANGS)} inherited loops and constructor constraints', flush=True)
            for name, (record, categories) in TRAPS.items():
                path = root / f'{name}.txt'; path.write_text(record + '\n')
                for index, executable in enumerate(('native', 'translated')):
                    result = subprocess.run([str(root / executable), str(path)], capture_output=True, timeout=10)
                    expected = categories[index] if isinstance(categories, tuple) else categories
                    if not panic_category(result, expected):
                        raise AssertionError(f'{executable} checked trap {name} failed {expected!r}: {result.returncode}\n{result.stderr.decode(errors="replace")}')
            for name, record in HANGS.items():
                path = root / f'{name}.txt'; path.write_text(record + '\n')
                for executable in ('native', 'translated'):
                    try:
                        result = subprocess.run([str(root / executable), str(path)], capture_output=True, timeout=1)
                    except subprocess.TimeoutExpired as timeout:
                        if timeout.stdout or timeout.stderr:
                            raise AssertionError(f'{executable} loop {name} emitted output')
                    else:
                        raise AssertionError(f'{executable} loop {name} returned {result.returncode}')
            for fixture in sorted((PROBE / 'contracts').glob('*.zig')):
                ordinary_rejection(subprocess.run(native(fixture, '-fno-emit-bin'), capture_output=True, timeout=120), 'Source ' + fixture.stem)
                ordinary_rejection(subprocess.run([str(args.v.resolve()), *options, '-check', str(fixture.with_suffix('.v'))], env=environment, capture_output=True, timeout=120), 'V ' + fixture.stem)
            subprocess.run(native(PROBE / 'complete.zig', f'-femit-bin={root / "complete"}'), check=True)
            subprocess.run([str(root / 'complete')], check=True)
            subprocess.run([str(args.v.resolve()), *options, '-check', str(PROBE / 'complete.v')], env=environment, check=True)
            for fixture in sorted((PROBE / 'boundaries').glob('*.zig')):
                ordinary_rejection(subprocess.run(native(fixture, '-fno-emit-bin'), capture_output=True, timeout=120), 'Source i17 constructor ' + fixture.stem)
                subprocess.run([str(args.v.resolve()), *options, '-check', str(fixture.with_suffix('.v'))], env=environment, check=True)
            path = root / 'undefined_list.txt'; path.write_text(UNDEFINED + '\n')
            # This is an observation of undefined Source list state, not parity.
            try:
                result = subprocess.run([str(root / 'native'), str(path)], capture_output=True, timeout=2)
                observation = f'exit {result.returncode}, stdout SHA256 {hashlib.sha256(result.stdout).hexdigest()}'
            except subprocess.TimeoutExpired:
                observation = 'two-second timeout'
            print(f'Source deinit-then-append observation: {observation}; excluded from returning/trap parity', flush=True)
            digest = hashlib.sha256(b'\n'.join(outputs[0])).hexdigest()
            print(f'ScrollView: {len(rows)} returning records, {len(TRAPS)} strict trap pairs, {len(HANGS)} inherited loop pairs, {len(list((PROBE / "contracts").glob("*.zig")))} ordinary constructor rejection pairs, {len(list((PROBE / "boundaries").glob("*.zig")))} measured Source-only i17 constructor rejections, one excluded Source undefined-list observation, SHA256 {digest}')
        finally:
            if args.keep:
                shutil.copytree(root, args.keep, dirs_exist_ok=True)


if __name__ == '__main__':
    main()
