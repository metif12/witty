"""Compare the classic Terminal Screen API with unchanged pinned source."""
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
import time
import tempfile
PROBE = Path(__file__).resolve().parent / 'reference_probes/terminal_screen'
sys.path.insert(0, str(PROBE.parent / 'widgets_classic'))
from source_build import VAXIS_SHA256, UUCODE_PACKAGE, module, prepare_uucode, tree_hash

def corpus():
    rng = random.Random(203052318)
    cases = []

    def add(*values):
        cases.append('|'.join(map(str, values)))
    for (w, h) in itertools.product(range(1, 9), repeat=2):
        add('N', w, h)
    sgr = ['', '0', '1;2;3;4;5;7;8;9', '21;22;23;24;25;27;28;29', '30;39;40;49;90;100', '38;2;1;2;3', '48;2;4;5;6', '38:2::1:2:3', '48:2::4:5:6', '38;5;255', '48;5;9', '4:0', '4:1', '4:2', '4:3', '4:4', '4:5', '38', '38;2', '38;2;1', '38;2;1;2', '38;5', '38;9;1', '48;2;1;2', '1;38;9;0', '38:2::', ';;', '1x;2', '?1', '254;255', '58;5;7']
    for _ in range(6144):
        (w, h) = (rng.randrange(1, 10), rng.randrange(1, 9))
        top = rng.randrange(h)
        bottom = rng.randrange(top, h)
        left = rng.randrange(w)
        right = rng.randrange(left, w)
        (col, row) = (rng.randrange(w + 2), rng.randrange(h + 2))
        op = rng.randrange(22)
        n = rng.choice((0, 1, 2, 5, 64, 65535))
        inside = left <= col <= right and top <= row <= bottom
        if op == 4 and col + n > 65535:
            n = 1
        if op in (6, 7, 8, 11, 12):
            (col, row) = (rng.randrange(w), rng.randrange(h))
        if op == 0 and rng.randrange(2) == 0:
            (col, row) = (rng.randrange(w), rng.randrange(h))
        wrap = rng.randrange(2)
        if op in (10, 15, 16) and top == 0 and (op == 10 and n > 0 and inside and (bottom == row) or (op == 15 and row == top and (left <= col <= right) and (bottom == top)) or (op == 16 and n > 0 and (bottom == top))):
            continue
        text = rng.choice(('a', '界', 'é', '👩\u200d🚀', '', '\x00')).encode().hex()
        (a, b) = (rng.randrange(4), rng.randrange(2))
        if op == 17:
            text = rng.choice(sgr).encode().hex()
        if op == 21:
            (a, b) = (rng.randrange(w + 2), rng.randrange(h + 2))
            if a <= w and b <= h and (b * w + a >= w * h):
                continue
        add('O', w, h, top, bottom, left, right, col, row, wrap, op, n, text, a, b)
    for params in sgr:
        add('O', 3, 2, 0, 1, 0, 2, 1, 1, 1, 17, 0, params.encode().hex(), 0, 0)
    for code in range(256):
        if code == 4:
            continue
        add('O', 3, 2, 0, 1, 0, 2, 1, 1, 1, 17, 0, str(code).encode().hex(), 0, 0)
    for op in (2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 18, 19, 20, 21):
        add('O', 4, 3, 1, 2, 1, 3, 2, 1, 1, op, 0, '61', 0, 0)
    add('O', 2, 2, 0, 1, 0, 1, 0, 0, 0, 21, 0, '61', (1 << 64) - 1, (1 << 64) - 1)
    for w, h in ((1, 65535), (65535, 1)):
        add('N', w, h)
    add('O', 255, 257, 0, 256, 0, 254, 0, 0, 0, 11, 0, '61', 0, 0)
    return cases

def constructor_consumers():
    consumers = []
    for omitted in (None, 'top', 'bottom', 'left', 'right'):
        fields = {name: number for name, number in (('top', 0), ('bottom', 1), ('left', 0), ('right', 1)) if name != omitted}
        zig_fields = ', '.join(f'.{name} = {value}' for name, value in fields.items())
        v_fields = ', '.join(f'{name}: {value}' for name, value in fields.items())
        consumers.append((f'region-{omitted or "complete"}', omitted is None,
            'const vaxis = @import("vaxis"); const Screen = @FieldType(vaxis.widgets.Terminal, "front_screen"); pub fn main() void { _ = Screen.ScrollingRegion{' + zig_fields + '}; }',
            'module main\nimport vaxis\nfn main() { value := vaxis.TerminalScrollingRegion{' + v_fields + '} println(value) }'))
    for complete in (True, False):
        zig_region = ', .scrolling_region = .{.top=0,.bottom=1,.left=0,.right=1}' if complete else ''
        v_region = 'scrolling_region: vaxis.TerminalScrollingRegion{top:0,bottom:1,left:0,right:1}' if complete else ''
        consumers.append((f'screen-{ "complete" if complete else "region"}', complete,
            'const std = @import("std"); const vaxis = @import("vaxis"); const Screen = @FieldType(vaxis.widgets.Terminal, "front_screen"); pub fn main() void { _ = Screen{.allocator=std.heap.c_allocator' + zig_region + '}; }',
            'module main\nimport vaxis\nfn main() { value := vaxis.TerminalScreen{' + v_region + '} println(value.width) }'))
    return consumers


def checked_trap(result, mode, message, executable):
    # Match the diagnostic header, excluding source/backtrace literals that may
    # mention the expected category while a different operation actually traps.
    text = '\n'.join(stream.decode(errors='replace') for stream in (result.stdout, result.stderr))
    messages = []
    for line in text.splitlines():
        header = re.match(r'^(?:thread \d+ )?(?:V )?panic:\s*(.*)$', line)
        if header:
            messages.append(header.group(1))
    unexpected = any(line.lstrip().startswith('UNEXPECTED') for line in text.splitlines())
    # Zig spells the checked alias category "@memcpy arguments alias"; the V
    # guard spells it without the builtin sigil.
    if result.returncode == 0 or result.stdout or unexpected or not any(value.removeprefix('@').startswith(message) for value in messages):
        raise AssertionError(f'{mode}: {executable} did not retain source trap {message!r}: {text}')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('zig', type=Path)
    parser.add_argument('v', type=Path)
    parser.add_argument('--uucode', type=Path, default=Path.home() / '.cache/zig/p' / UUCODE_PACKAGE)
    parser.add_argument('--target', default='aarch64-macos.14.0')
    parser.add_argument('--v-prod', action='store_true')
    parser.add_argument('--zig-mode', choices=('Debug', 'ReleaseSafe'), default='Debug')
    parser.add_argument('--timeout', type=int, help='positive runtime limit per returning batch (default 60 seconds, or 180 with --v-prod)')
    parser.add_argument('--v-path', help=argparse.SUPPRESS)
    args = parser.parse_args()
    if args.timeout is not None and args.timeout <= 0:
        parser.error('--timeout must be positive')
    timeout = args.timeout if args.timeout is not None else (180 if args.v_prod else 60)
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
    source = args.source.resolve() / 'src'
    if tree_hash(source) != VAXIS_SHA256:
        parser.error('vaxis src differs from the recorded local source')
    cases = corpus()
    with tempfile.TemporaryDirectory(prefix='witty-terminal-screen-') as directory:
        root = Path(directory)
        shutil.copytree(source, root / 'src')
        graph = prepare_uucode(args.zig.resolve(), root, args.uucode.resolve(), args.target)
        zig = str(args.zig.resolve())

        def native(path, output):
            return [zig, 'build-exe', '-O', args.zig_mode, '-target', args.target, '-lc', *module('root', path, ['vaxis']), *module('vaxis', root / 'src/main.zig', ['uucode']), *graph, output]
        subprocess.run(native(PROBE / 'reference.zig', f"-femit-bin={root / 'native'}"), check=True)
        options = ['-prod'] if args.v_prod else []
        if args.v_path:
            options += ['-path', args.v_path]
        environment = dict(os.environ, VEXE=str(args.v.resolve()), V_C_ERROR_BUG_REPORT_DISABLED='1')
        subprocess.run([str(args.v.resolve()), *options, '-o', str(root / 'translated'), str(PROBE / 'main.v')], env=environment, check=True)
        # Isolate the three large returning records so a deadline identifies
        # its exact case instead of obscuring completed smaller comparisons.
        batches = [('regular', cases[:-3])] + [(f'large-{i}', [case]) for i, case in enumerate(cases[-3:])]
        outputs = [[], []]
        for label, batch in batches:
            corpus_path = root / f'{label}.txt'
            corpus_path.write_text('\n'.join(batch) + '\n')
            for index, executable in enumerate(('native', 'translated')):
                print(f'{executable}: {label}, {len(batch)} records, runtime limit {timeout}s', file=sys.stderr, flush=True)
                started = time.monotonic()
                result = subprocess.run([str(root / executable), str(corpus_path)], capture_output=True, check=True, timeout=timeout)
                rows = result.stdout.splitlines()
                if len(rows) != len(batch):
                    raise AssertionError(f'{executable}: {label} returned {len(rows)} of {len(batch)} records')
                outputs[index].extend(rows)
                print(f'{executable}: {label} completed in {time.monotonic() - started:.2f}s', file=sys.stderr, flush=True)
        if any((len(output) != len(cases) for output in outputs)):
            raise AssertionError([len(cases)] + [len(output) for output in outputs])
        for (index, (data, expected, actual)) in enumerate(zip(cases, *outputs)):
            if expected != actual:
                raise AssertionError(f'row {index} ({data}): native={expected!r}, V={actual!r}')
        traps = {'trap_zero_w': 'integer overflow', 'trap_zero_h': 'integer overflow', 'trap_read': 'reached unreachable code', 'trap_right': 'integer overflow', 'trap_down': 'integer overflow', 'trap_index': 'integer overflow', 'trap_print': 'integer overflow', 'trap_erase': 'integer overflow', 'trap_erase_below_count':'integer overflow', 'trap_delete_count': 'integer overflow', 'trap_enum': 'invalid enum value', 'trap_sgr': 'integer overflow', 'trap_copy': 'index out of bounds', 'trap_self_to': 'memcpy arguments alias'}
        for (mode, message) in traps.items():
            for executable in ('native', 'translated'):
                result = subprocess.run([str(root / executable), mode], capture_output=True, timeout=10)
                checked_trap(result, mode, message, executable)
        for executable in ('native', 'translated'):
            try:
                result = subprocess.run([str(root / executable), 'hang_insert'], capture_output=True, timeout=1)
            except subprocess.TimeoutExpired:
                continue
            raise AssertionError(f'{executable}: inherited insertLine zero-adjustment loop returned: {result.stderr.decode()}')
        complete_count = rejected_count = 0
        for label, accepted, zig_text, v_text in constructor_consumers():
            source_consumer = root / f'{label}.zig'
            translated_consumer = root / f'{label}.v'
            source_consumer.write_text(zig_text)
            translated_consumer.write_text(v_text)
            consumer_options = ['-path', args.v_path] if args.v_path else []
            commands = (native(source_consumer, '-fno-emit-bin'), [str(args.v.resolve()), *consumer_options, '-check', str(translated_consumer)])
            for executable, command in zip(('native', 'translated'), commands):
                result = subprocess.run(command, env=environment, capture_output=True, timeout=60)
                diagnostic = (result.stdout + result.stderr).decode(errors='replace')
                if accepted:
                    if result.returncode != 0:
                        raise AssertionError(f'{label}: {executable} rejected complete constructor: {diagnostic}')
                elif result.returncode <= 0 or 'error:' not in diagnostic or any(token in diagnostic.lower() for token in ('panic', 'compiler bug', 'segmentation fault', 'c error found')):
                    raise AssertionError(f'{label}: {executable} did not produce an ordinary omission rejection: {diagnostic}')
            if accepted:
                complete_count += 1
            else:
                rejected_count += 1
        print(f'TerminalScreen: {len(cases)} cases, {len(traps)} traps, {complete_count} complete constructors, {rejected_count} paired omission rejections, SHA256 ' + hashlib.sha256(b'\n'.join(outputs[0])).hexdigest())
if __name__ == '__main__':
    main()
