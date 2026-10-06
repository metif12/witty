"""Compare public Spinner state, atomic counters, callbacks and draw with unchanged Vaxis."""
import argparse
import hashlib
import itertools
import json
import os
from pathlib import Path
import re
import resource
import shutil
import subprocess
import sys
import tempfile
import time

PROBE = Path(__file__).resolve().parent / 'reference_probes/vxfw_spinner'
sys.path.insert(0, str(PROBE.parent / 'widgets_classic'))
from source_build import VAXIS_SHA256, UUCODE_PACKAGE, module, prepare_uucode, tree_hash


def corpus():
    rows = []

    def add(kind, count, frame, was, style=0, phase=1, flags=0, *extra):
        rows.append('|'.join(map(str, (kind, count, frame, was, style, phase, flags, *extra))))

    def sequence_returns(count, frame, ops):
        for op in ops:
            if op == 's':
                count = (count + 1) & 65535
            elif op == 'p':
                count = max(0, count - 1)
            elif op in 'tu' and count:
                if frame == 15:
                    return False
                frame += 1
                if frame >= 8:
                    frame = 0
        return True

    # Each publicly representable frame value, count saturation/wrap neighbors,
    # both remembered states, retained flags/phases, and direct/erased callbacks.
    sequences = ('ncc', 'sppstunp', 'ttt', 'uuu', 'psu', 'psstncu', 'pput', 'c')
    for count, frame, was, ops in itertools.product((0, 1, 2, 32767, 65534, 65535), range(16), range(2), sequences):
        if sequence_returns(count, frame, ops):
            add('S', count, frame, was, (count + frame) % 3, frame % 3, count % 8, ops)
    for phase, flags, was in itertools.product(range(3), range(8), range(2)):
        add('S', 1, 7, was, 2, phase, flags, 'nctup')
        add('S', 0, 15, was, 1, phase, flags, 'nctup')
    for count, frame, was, ops in itertools.product((0, 1, 65535), (0, 7, 8, 14, 15), range(2), itertools.product('sptu', repeat=4)):
        ops = ''.join(ops)
        if sequence_returns(count, frame, ops):
            add('S', count, frame, was, 0, 1, 0, ops)
    sizes = ((0, 0), (0, 3), (3, 0), (1, 1), (2, 3), (7, 7), (31, 2))
    for count, frame, was, style, size, bounded, callback in itertools.product((0, 1, 2, 65535), range(16), range(2), range(3), sizes, range(2), range(2)):
        if count and frame >= 8:
            continue
        add('D', count, frame, was, style, frame % 3, count % 8, *size, bounded, callback)
    for count, frame, size in itertools.product((0, 1), (0, 7, 15), ((1, 65535), (65535, 1), (255, 257))):
        if count and frame >= 8:
            continue
        add('D', count, frame, 1, 2, 0, 7, *size, 1, 1)
    for count, frame, was in itertools.product((0, 1, 2, 65534, 65535), range(16), range(2)):
        after = max(0, ((count + 1) & 65535) - 2)
        if after and frame == 15:
            continue
        add('C', count, frame, was, frame % 3, 1, 0)
    # Four threads share a live widget; each atomic old value of zero must
    # produce precisely one command, including after u16 wraparound.
    for count, n in itertools.product((0, 1, 65534, 65535), (0, 1, 31, 1024, 20000)):
        add('A', count, 0, 0, 0, 1, 0, n)
    return rows


def checked_trap(result, label, category, executable):
    texts = [value.decode(errors='replace') for value in (result.stdout, result.stderr)]
    headers = [match.group(1) for text in texts for line in text.splitlines()
               if (match := re.match(r'^(?:thread \d+ )?(?:V )?panic:\s*(.*)$', line))]
    unexpected = any(line.lstrip().startswith('UNEXPECTED') for text in texts for line in text.splitlines())
    if result.returncode == 0 or result.stdout or unexpected or not any(value.startswith(category) for value in headers):
        raise AssertionError(f'{executable}: {label} did not preserve {category!r}: ' + '\n'.join(texts))


def ordinary_rejection(result, executable):
    diagnostic = (result.stdout + result.stderr).decode(errors='replace')
    bug = re.search(r'(?im)(?:panic:|segmentation fault|compiler bug|compiler error:|C compilation failed|builder error:|internal compiler|report a bug|please report this)', diagnostic)
    if result.returncode == 0 or bug or not re.search(r'(?m)^.*(?:error:|error\[).*$', diagnostic):
        raise AssertionError(f'{executable} did not ordinarily reject the invalid literal: {diagnostic}')


def compare(args, root, env, rows):
    source = args.source.resolve() / 'src'
    if tree_hash(source) != VAXIS_SHA256:
        raise ValueError('vaxis source differs from the recorded local source')
    mode = args.zig_mode or ('ReleaseSafe' if args.v_prod else 'Debug')
    shutil.copytree(source, root / 'src')
    graph = prepare_uucode(args.zig.resolve(), root, args.uucode.resolve(), args.target)
    native_prefix = [str(args.zig.resolve()), 'build-exe', '-O', mode, '-target', args.target, '-lc']
    native = [*native_prefix, *module('root', PROBE / 'reference.zig', ['vaxis']), *module('vaxis', root / 'src/main.zig', ['uucode']), *graph, f'-femit-bin={root / "native"}']
    options = ['-enable-globals'] + (['-prod'] if args.v_prod else [])
    path = ['-path', args.v_path or str(PROBE.parents[2]) + '|@vlib|@vmodules']
    translated = [str(args.v.resolve()), *options, *path, '-o', str(root / 'translated'), str(PROBE / 'main.v')]
    for label, command in [('native ' + mode, native), ('V production' if args.v_prod else 'V ordinary', translated)]:
        print('Building ' + label, file=sys.stderr, flush=True)
        (root / (label.replace(' ', '-') + '-argv.json')).write_text(json.dumps(command))
        subprocess.run(command, env=env, check=True)
    data = root / 'cases.txt'
    data.write_text('\n'.join(rows) + '\n')
    outputs = []
    for executable in ('native', 'translated'):
        print(f'Running {executable}: {len(rows)} returning records', file=sys.stderr, flush=True)
        start = time.monotonic()
        result = subprocess.run([str(root / executable), str(data)], env=env, capture_output=True, timeout=args.timeout)
        (root / (executable + '.stdout')).write_bytes(result.stdout)
        (root / (executable + '.stderr')).write_bytes(result.stderr)
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
    traps = {'trap_tick_direct': 'integer overflow', 'trap_tick_callback': 'integer overflow',
             'trap_draw_direct': 'index out of bounds', 'trap_draw_callback': 'index out of bounds',
             'trap_area': 'integer overflow', 'trap_area_before_frame': 'integer overflow'}
    for label, category in traps.items():
        for executable in ('native', 'translated'):
            result = subprocess.run([str(root / executable), label], env=env, capture_output=True, timeout=15)
            (root / f'{executable}-{label}.stderr').write_bytes(result.stderr)
            checked_trap(result, label, category, executable)
    # The source u4 field has no V integer-width equivalent. Measure the accepted
    # V u8 constructor separately instead of claiming a paired compiler rejection.
    z = root / 'frame_width.zig'
    z.write_text('const fw=@import("vaxis").vxfw;pub fn main()void{var s:fw.Spinner=.{.frame=16};_ = s.start();}\n')
    result = subprocess.run([*native_prefix, *module('root', z, ['vaxis']), *module('vaxis', root / 'src/main.zig', ['uucode']), *graph, f'-femit-bin={root / "frame_width"}'], env=env, capture_output=True)
    ordinary_rejection(result, 'source frame width')
    (root / 'frame_width-source.stderr').write_bytes(result.stderr)
    v = root / 'frame_width.v'
    v.write_text('module main\nimport vaxis.vxfw\nfn main(){mut s:=vxfw.Spinner{frame:16};assert s.frame==16}\n')
    subprocess.run([str(args.v.resolve()), *options, *path, '-o', str(root / 'frame_width_v'), str(v)], env=env, check=True)
    subprocess.run([str(root / 'frame_width_v')], env=env, check=True)
    allocation = {'oom_tick': b'OutOfMemory|1,0,1,1,0,0,0,0\n',
                  'oom_draw': b'OutOfMemory|1,7,1,1,0,0,0,0\n',
                  'oom_stopped_draw': b'OutOfMemory|0,7,1,1,0,0,0,0\n'}
    for label, expected in allocation.items():
        result = subprocess.run([str(root / 'native'), label], env=env, capture_output=True, timeout=15)
        if result.returncode or result.stderr or result.stdout != expected:
            raise AssertionError(f'source-only {label}: {result}')
        (root / (label + '.stdout')).write_bytes(result.stdout)
    digest = hashlib.sha256(b'\n'.join(outputs[0])).hexdigest()
    print(f'Spinner: {len(rows)} returning records, {len(traps)} strict traps, 1 measured u4/u8 constructor boundary, 3 source-only allocator failure cases; SHA256 {digest}')


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
    parser.add_argument('--workdir', type=Path, help='retain artifacts in a new directory')
    parser.add_argument('--timeout', type=int, default=120)
    args = parser.parse_args()
    if args.timeout <= 0:
        parser.error('--timeout must be positive')
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
    env = dict(os.environ, VEXE=str(args.v.resolve()), V_C_ERROR_BUG_REPORT_DISABLED='1')
    rows = corpus()
    if args.workdir:
        root = args.workdir.resolve(); root.mkdir()
        compare(args, root, env, rows)
    else:
        with tempfile.TemporaryDirectory(prefix='witty-spinner-') as directory:
            compare(args, Path(directory), env, rows)


if __name__ == '__main__':
    main()
