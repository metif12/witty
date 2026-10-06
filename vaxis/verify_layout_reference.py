"""Compare public layout widgets with unchanged pinned Vaxis source."""
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

PROBE = Path(__file__).resolve().parent / 'reference_probes/vxfw_layout'
sys.path.insert(0, str(PROBE.parent / 'widgets_classic'))
from source_build import VAXIS_SHA256, UUCODE_PACKAGE, module, prepare_uucode, tree_hash

SIZES = [[], [(0, 0)], [(1, 1)], [(3, 1), (2, 2), (4, 3)], [(0, 0)] * 3,
         [(65535, 0)], [(0, 65535)], [(65535, 65535), (1, 1)],
         [(32767, 32767), (32768, 32768)], [(65534, 65534), (1, 1), (1, 1)],
         [(5, 2), (8, 0), (2, 5)], [(0, 0)] * 258]


def row(kind='C', width=20, height=20, min_w=0, min_h=0, dataset=3,
        weights=0x010101, reply=3, mutation=0, fail=-1, left=0, right=0,
        top=0, bottom=0, label=0, align=0, method=0):
    return '|'.join(map(str, (kind, width, height, min_w, min_h, dataset, weights,
        reply, mutation, fail, left, right, top, bottom, label, align, method)))


def child_size(dataset):
    return SIZES[dataset][0] if SIZES[dataset] else (0, 0)


def flex_valid(kind, dataset, weights, reply, width, height):
    values = SIZES[dataset]
    if not values:
        return True
    flex = [(weights >> ((i % 3) * 8)) & 255 for i in range(len(values))]
    axis = 1 if kind == 'V' else 0
    first = [0 if reply == 1 else size[axis] for size in values]
    first_sum = sum(first if kind == 'V' else [n for n, f in zip(first, flex) if f == 0])
    maximum = height if kind == 'V' else width
    if first_sum > 65535 or (kind == 'V' and first_sum > maximum):
        return False
    remaining = max(maximum - first_sum, 0)
    total_flex = sum(flex)
    actual = 0
    for index, (size, f) in enumerate(zip(values, flex)):
        if f == 0:
            requested = first[index]
        elif index == len(values) - 1:
            requested = maximum - actual if kind == 'V' else max(maximum - actual, 0)
            if requested < 0:
                return False
        else:
            product = remaining * f
            if product > 65535:
                return False
            requested = product // total_flex + (first[index] if kind == 'V' else 0)
            if requested > 65535:
                return False
        actual += size[axis] if reply == 0 else requested
        if actual > 65535:
            return False
    return True


def corpus():
    rows = []
    rng = random.Random(0x4c41594f5554)
    for amount in (0, 1, 2, 3, 255, 32767, 32768, 65534, 65535):
        rows.append(row('A', left=amount))
    for dataset, width, height, reply, fail in itertools.product(range(7),
            (0, 1, 2, 3, 8, 20, 65535), (0, 1, 2, 8, 20, 65535), range(4), (-1, 0)):
        w, h = child_size(dataset)
        if reply == 0 and fail < 0 and (w > width or h > height):
            continue
        rows.append(row('C', width, height, dataset=dataset, reply=reply, fail=fail))
    pads = [(0, 0, 0, 0), (1, 2, 3, 4), (0, 1, 0, 1), (65534, 1, 0, 0), (0, 0, 32767, 32768)]
    for dataset, width, height, reply, pad in itertools.product(range(7),
            (-1, 0, 3, 8, 20, 65535), (-1, 0, 3, 8, 20, 65535), range(4), pads):
        l, r, t, b = pad
        if (l or r) and width < 0 or (t or b) and height < 0:
            continue
        w, h = child_size(dataset)
        if (reply == 0 or reply == 3 and (width < 0 or height < 0)) and (w + l + r > 65535 or h + t + b > 65535):
            continue
        rows.append(row('P', width, height, dataset=dataset, reply=reply,
                        left=l, right=r, top=t, bottom=b))
    for width, height, min_w, min_h, box_w, box_h, reply in itertools.product(
            (-1, 0, 3, 20, 65535), (-1, 0, 3, 20, 65535), (0, 8), (0, 8),
            (0, 1, 7, 65535), (0, 1, 7, 65535), range(4)):
        rows.append(row('S', width, height, min_w, min_h, reply=reply, left=box_w, right=box_h))
    label_width = {0: 0, 1: 3, 2: 1, 3: 4, 4: 2, 5: 2, 8: 2}
    for _ in range(2500):
        dataset = rng.choice((0, 1, 2, 3, 10))
        width, height = rng.choice((-1, 0, 1, 2, 3, 8, 20)), rng.choice((-1, 0, 1, 2, 3, 8, 20))
        min_w, min_h, reply = rng.choice((0, 2, 8)), rng.choice((0, 2, 8)), rng.randrange(4)
        label, align, method = rng.choice((0, 1, 2, 3, 4, 5, 8)), rng.randrange(7), rng.randrange(3)
        if label == 4 and method != 0:
            continue
        w, h = child_size(dataset)
        if reply == 1 or reply == 3 and width >= 0 and height >= 0:
            w, h = min_w, min_h
        elif reply == 2:
            w, h = (max(width - 2, 0) if width >= 0 else w), (max(height - 2, 0) if height >= 0 else h)
        size_w = w + 2
        text_width = 4 if label == 5 and method != 0 else label_width[label]
        if align in (1, 4, 6) and text_width > size_w or align in (2, 5, 6) and text_width > size_w - 1:
            continue
        rows.append(row('B', width, height, min_w, min_h, dataset, reply=reply,
                        label=label, align=align, method=method))
    for kind, dataset, weights, reply, width, height in itertools.product(('V', 'H'),
            (0, 1, 2, 3, 4, 8, 10), (0, 0x010101, 0x020301, 0x00ff01, 0x020100, 0x000102, 0xffffff),
            range(4), (0, 1, 6, 20, 255, 65535), (0, 1, 6, 20, 255, 65535)):
        if flex_valid(kind, dataset, weights, reply, width, height):
            rows.append(row(kind, width, height, dataset=dataset, weights=weights, reply=reply))
    for kind, mutation, reply, weights, fail in itertools.product(('P', 'B', 'V', 'H'),
            range(7), range(4), (0x010101, 0x020100, 0x000102), (-1, 0, 1, 3, 5)):
        rows.append(row(kind, mutation=mutation, reply=reply, weights=weights, fail=fail,
                        label=1 if kind == 'B' else 0))
    # Errors occur before later geometry/proportion checks.
    for kind, dataset, width, height, pad in [('C', 7, 0, 0, 0), ('P', 5, 1, 1, 1),
            ('B', 7, 1, 1, 0), ('V', 3, 0, 0, 0), ('V', 7, 65535, 65535, 0)]:
        rows.append(row(kind, width, height, dataset=dataset, fail=0, left=pad, right=pad, reply=0))
    return list(dict.fromkeys(rows))


ASSERT = (b'reached unreachable code', b'Assertion failed')
CAST = (b'integer does not fit in destination type', b'integer cast truncated bits')
TRAPS = {
    'center_width_bound': (row('C', width=-1), ASSERT),
    'center_height_bound': (row('C', height=-1), ASSERT),
    'center_width_sub': (row('C', width=0, dataset=2, reply=0), b'integer overflow'),
    'center_height_sub': (row('C', height=0, dataset=2, reply=0), b'integer overflow'),
    'padding_width_bound': (row('P', width=-1, left=1), ASSERT),
    'padding_height_bound': (row('P', height=-1, top=1), ASSERT),
    'padding_horizontal_sum': (row('P', left=65535, right=1), b'integer overflow'),
    'padding_vertical_sum': (row('P', top=65535, bottom=1), b'integer overflow'),
    'padding_width_sum': (row('P', dataset=5, reply=0, left=1), b'integer overflow'),
    'padding_height_sum': (row('P', dataset=6, reply=0, top=1), b'integer overflow'),
    'border_width_sum': (row('B', dataset=5, reply=0), b'integer overflow'),
    'border_height_sum': (row('B', dataset=6, reply=0), b'integer overflow'),
    'border_product': (row('B', dataset=3, reply=1, min_w=255, min_h=255), b'integer overflow'),
    'border_center_sub': (row('B', dataset=1, reply=0, label=1, align=1), b'integer overflow'),
    'border_right_sub': (row('B', dataset=1, reply=0, label=8, align=2), b'integer overflow'),
    'border_label_width': (row('B', label=7), b'integer overflow'),
    'border_grapheme_cast': (row('B', label=9, method=1), CAST),
    'border_column_sum': (row('B', label=6), b'integer overflow'),
    'column_width_bound': (row('V', width=-1, dataset=0), ASSERT),
    'column_height_bound': (row('V', height=-1, dataset=0), ASSERT),
    'row_width_bound': (row('H', width=-1, dataset=0), ASSERT),
    'row_height_bound': (row('H', height=-1, dataset=0), ASSERT),
    'column_first_sum': (row('V', dataset=7, reply=0, height=65535), b'integer overflow'),
    'row_first_sum': (row('H', dataset=7, reply=0, weights=0), b'integer overflow'),
    'column_flex_sum': (row('V', dataset=11, weights=999, reply=0), b'integer overflow'),
    'row_flex_sum': (row('H', dataset=11, weights=999, reply=0), b'integer overflow'),
    'column_remaining_sub': (row('V', height=0, reply=0), b'integer overflow'),
    'column_product': (row('V', height=65535, dataset=4, weights=0x020202), b'integer overflow'),
    'row_product': (row('H', width=65535, dataset=4, weights=0x020202), b'integer overflow'),
    'column_child_height_sum': (row('V', dataset=13, reply=0, weights=1, mutation=4, height=65535), b'integer overflow'),
    'column_second_sum': (row('V', dataset=4, reply=4, weights=0), b'integer overflow'),
    'row_second_sum': (row('H', dataset=12, reply=4), b'integer overflow'),
    'column_last_remainder_sub': (row('V', dataset=12, reply=4), b'integer overflow'),
    'column_div_zero': (row('V', dataset=3, weights=0, mutation=8, reply=3), b'division by zero'),
    'row_div_zero': (row('H', dataset=3, weights=0, mutation=8, reply=3), b'division by zero'),
    'empty_column_product': (row('V', dataset=0, min_w=256, min_h=256), b'integer overflow'),
    'empty_row_product': (row('H', dataset=0, min_w=256, min_h=256), b'integer overflow'),
}


def checked_trap(result, expected):
    if result.returncode == 0 or result.stdout:
        return False
    if any(line.startswith(b'UNEXPECTED:') for line in result.stderr.splitlines()):
        return False
    return any(match.group(1).startswith(expected) for line in result.stderr.splitlines()
        if (match := re.fullmatch(rb'(?:thread [0-9]+ )?(?:V )?panic:\s*(.*)', line)))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path); parser.add_argument('zig', type=Path); parser.add_argument('v', type=Path)
    parser.add_argument('--target', default='aarch64-macos.14.0')
    parser.add_argument('--uucode', type=Path, default=Path.home() / '.cache/zig/p' / UUCODE_PACKAGE)
    parser.add_argument('--v-prod', action='store_true'); parser.add_argument('--zig-mode', choices=('Debug', 'ReleaseSafe'))
    parser.add_argument('--keep', type=Path, help=argparse.SUPPRESS)
    args = parser.parse_args(); mode = args.zig_mode or ('ReleaseSafe' if args.v_prod else 'Debug')
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
    source = args.source.resolve() / 'src'
    if tree_hash(source) != VAXIS_SHA256: parser.error('Source differs from unchanged pinned Vaxis')
    env = dict(os.environ, VEXE=str(args.v.resolve()), V_C_ERROR_BUG_REPORT_DISABLED='1')
    with tempfile.TemporaryDirectory(prefix='witty-layout-') as directory:
        root = Path(directory); shutil.copytree(source, root / 'src')
        graph = prepare_uucode(args.zig.resolve(), root, args.uucode.resolve(), args.target)
        try:
            print(f'Building unchanged Source {mode} and V {"production" if args.v_prod else "ordinary"}', flush=True)
            subprocess.run([str(args.zig.resolve()), 'build-exe', '-target', args.target, '-lc', '-O', mode,
                *module('root', PROBE / 'reference.zig', ['vaxis']), *module('vaxis', root / 'src/main.zig', ['uucode']), *graph, f'-femit-bin={root / "native"}'], check=True)
            subprocess.run([str(args.v.resolve()), *(['-prod'] if args.v_prod else []), '-o', str(root / 'translated'), str(PROBE / 'main.v')], env=env, check=True)
            rows = corpus(); path = root / 'corpus.txt'; path.write_text('\n'.join(rows) + '\n')
            print(f'Comparing {len(rows)} returning callback/draw records', flush=True)
            outputs = []
            for executable in ('native', 'translated'):
                result = subprocess.run([str(root / executable), str(path)], capture_output=True, timeout=120)
                if result.returncode: raise AssertionError(f'{executable} returning corpus failed: {result.stderr.decode(errors="replace")}')
                outputs.append(result.stdout.splitlines())
            if any(len(output) != len(rows) for output in outputs): raise AssertionError([len(rows)] + [len(output) for output in outputs])
            for index, (record, native, translated) in enumerate(zip(rows, *outputs)):
                if native != translated: raise AssertionError(f'row {index} ({record}): Source={native!r}\nV={translated!r}')
            print(f'Checking {len(TRAPS)} strict isolated traps', flush=True)
            for name, (record, categories) in TRAPS.items():
                path = root / f'{name}.txt'; path.write_text(record + '\n')
                for index, executable in enumerate(('native', 'translated')):
                    result = subprocess.run([str(root / executable), str(path)], capture_output=True, timeout=10)
                    category = categories[index] if isinstance(categories, tuple) else categories
                    if not checked_trap(result, category): raise AssertionError(f'{executable} trap {name} failed ({category!r}): {result.returncode}\n{result.stderr.decode(errors="replace")}')
            digest = hashlib.sha256(b'\n'.join(outputs[0])).hexdigest()
            print(f'Layout: {len(rows)} returning records, {len(TRAPS)} strict trap pairs, SHA256 {digest}', flush=True)
        finally:
            if args.keep: shutil.copytree(root, args.keep, dirs_exist_ok=True)


if __name__ == '__main__': main()
