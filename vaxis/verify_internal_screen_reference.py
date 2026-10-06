"""Compare AllocatingScreen retained cells, ownership, equality and checked indexing with unchanged Vaxis."""
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

PROBE = Path(__file__).resolve().parent / 'reference_probes/internal_screen'
sys.path.insert(0, str(PROBE.parent / 'widgets_classic'))
from source_build import VAXIS_SHA256, UUCODE_PACKAGE, module, prepare_uucode, tree_hash
from verify_vxfw_surface_reference import checked_trap


def corpus():
    rows = []
    def add(*values):
        rows.append('|'.join(map(str, values)))
    for n in range(256):
        add('E', n)
    for w, h in itertools.product(range(9), repeat=2):
        add('N', w, h)
    add('N', 65535, 0)
    add('N', 0, 65535)
    add('N', 65535, 1)
    for w, h in ((2, 1), (1, 2), (2, 2)):
        add('P', w, h, 0, 0, 0, 0, 0, 0, 0, 0, 0)
    for n in range(256):
        col, row = ((2, 0), (0, 2), (1, 1))[n % 3]
        add('B' if n % 2 else 'O', 2, 2, 9, col, row, col, row, 0, n, 1, n)
    choices = (0, 1, 2, 3, 7, 255, 256, 32768, 65534, 65535)
    rng = random.Random(0x494e5445524e414c)
    for _ in range(8192):
        op = rng.choice(('O', 'R', 'W', 'B'))
        w, h = rng.choice(choices), rng.choice(choices)
        length = rng.randrange(17)
        wc, wr, rc, rr = (rng.choice(choices) for _ in range(4))
        if op != 'R' and wc <= w and wr <= h and wr*w+wc >= length:
            continue
        if op != 'W' and rc <= w and rr <= h and (rr*w+rc > 65535 or rr*w+rc >= length):
            continue
        add(op, w, h, length, wc, wr, rc, rr, 0, rng.randrange(256), rng.randrange(2), rng.randrange(256))
    for w, h in itertools.product(choices, repeat=2):
        add('O', w, h, 1, 0, 0, 0, 0, 0, 255, 1, 255)
    for w, h in ((0, 0), (1, 1), (2, 2), (255, 255), (65534, 65534)):
        for op in ('O', 'R', 'W'):
            add(op, w, h, 0, w+1, h, w, h+1, 0, 0, 1, 0)
    for field in range(3):
        for first in (1, 2, 3, 127, 128, 129, 130, 319, 320, 321, 608, 609):
            capacity = 1 if field == 0 else 0
            while capacity < first:
                capacity += capacity//2 + 128
            for second in sorted({0, 1, first, capacity-1, capacity}):
                add('F', field, first, second)
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
    with tempfile.TemporaryDirectory(prefix='witty-internal-screen-') as directory:
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
        cases = ((0, 0, 0, 0, 0), (2, 2, 0, 0, 0), (2, 2, 1, 1, 0), (2, 2, 4, 0, 2),
                 (65535, 65535, 1, 0, 1))
        traps = 0
        for i, (w, h, length, col, row) in enumerate(cases):
            for op in ('R', 'W'):
                data.write_text(f'{op}|{w}|{h}|{length}|{col}|{row}|{col}|{row}|0|0|0|0\n')
                for executable, category in (('native', 'reached unreachable code'), ('translated', 'Assertion failed')):
                    result = subprocess.run([str(root / executable), str(data)], env=env, capture_output=True, timeout=15)
                    checked_trap(result, f'{op}_short_{i}', category, executable)
                traps += 1
        for col, row in ((0, 32769), (65534, 65534)):
            data.write_text(f'W|65535|65535|1|{col}|{row}|0|0|0|0|0|0\n')
            for executable, category in (('native', 'reached unreachable code'), ('translated', 'Assertion failed')):
                result = subprocess.run([str(root / executable), str(data)], env=env, capture_output=True, timeout=15)
                checked_trap(result, 'write_high_index', category, executable)
            traps += 1
        for label, w, h, col, row in (('mul', 256, 256, 0, 256), ('add', 65535, 1, 1, 1),
                                       ('high_mul', 65535, 65535, 0, 32769)):
            data.write_text(f'R|{w}|{h}|1|0|0|{col}|{row}|0|0|0|0\n')
            for executable in ('native', 'translated'):
                result = subprocess.run([str(root / executable), str(data)], env=env, capture_output=True, timeout=15)
                checked_trap(result, label, 'integer overflow', executable)
            traps += 1
        states=[]
        for label in ('alias_self', 'alias_uri', 'alias_id', 'alias_partial'):
            pair=[]
            for executable in ('native', 'translated'):
                state_path=root / (label+'-'+executable+'.state')
                result = subprocess.run([str(root / executable), label, str(state_path)], env=env, capture_output=True, timeout=15)
                checked_trap(result, label, '@memcpy arguments alias', executable)
                if not state_path.is_file() or state_path.stat().st_size == 0:
                    raise AssertionError(executable+' '+label+' did not write its panic-state observation')
                pair.append(state_path.read_bytes())
            if pair[0] != pair[1]:
                raise AssertionError(label+' panic states differ: '+repr(pair))
            states.append(label.encode()+b'|'+pair[0])
            traps += 1
        boundaries = (
            ('alloc_init', b'INIT_ERROR: OutOfMemory\n', b'INIT_MANAGED: 1\n', b''),
            ('alloc_write', b'WRITE: 0,URI,id0,1,1\n', b'WRITE: 8192,URI,id0,1,1\n', b"warning(vaxis): couldn't write grapheme\n"),
        )
        for label, source_output, v_output, source_diagnostic in boundaries:
            for executable, output, diagnostic in (('native', source_output, source_diagnostic), ('translated', v_output, b'')):
                result = subprocess.run([str(root / executable), label], env=env, capture_output=True, timeout=15)
                if result.returncode or result.stdout != output or result.stderr != diagnostic:
                    raise AssertionError(f'{executable} {label} boundary failed: ' + repr(result))
        array_limit = subprocess.run([str(root / 'translated'), 'array_limit'], env=env, capture_output=True, timeout=15)
        checked_trap(array_limit, 'array_limit', 'V array length limit', 'translated')
        contracts(args, root, graph, env, mode)
        print('Alias failure-state SHA256 '+hashlib.sha256(b'\n'.join(states)).hexdigest())
        print(f'InternalScreen: {len(rows)} returning records, {traps} strict paired traps/4 failure-state observations, 2 Source/V allocator boundaries, 1 V array-limit trap, 1 complete/1 omission constructor pair; SHA256 ' + hashlib.sha256(b'\n'.join(outputs[0])).hexdigest())


def contracts(args, root, graph, env, mode):
    from verify_vxfw_constructors_reference import ordinary_rejection
    native_path = root / 'contract.zig'
    translated_path = root / 'contract.v'
    for omitted in (False, True):
        native_path.write_text('const std=@import("std");const vx=@import("vaxis");pub fn main() void {'
                              'var arena=std.heap.ArenaAllocator.init(std.heap.page_allocator);'
                              'const value:vx.AllocatingScreen=.{.arena=&arena' + ('' if omitted else ',.buf=&.{}') + '};'
                              'std.mem.doNotOptimizeAway(value);}')
        translated_path.write_text('module main\nimport vaxis\nfn main(){value:=vaxis.InternalScreen{' +
                                  ('' if omitted else 'buf: []vaxis.InternalCell{}') + '} println(value.width)}\n')
        commands = [('Source', [str(args.zig.resolve()), 'build-exe', '-O', mode, '-target', args.target, '-lc',
                    *module('root', native_path, ['vaxis']), *module('vaxis', root / 'src/main.zig', ['uucode']),
                    *graph, f'-femit-bin={root / "contract_native"}']),
                    ('V', [str(args.v.resolve()), '-enable-globals', *(['-prod'] if args.v_prod else []),
                           '-path', args.v_path or str(PROBE.parents[2]) + '|@vlib|@vmodules',
                           '-o', str(root / 'contract_translated'), str(translated_path)])]
        for label, command in commands:
            result = subprocess.run(command, env=env, capture_output=True)
            if omitted:
                if not ordinary_rejection(result, 'buf'):
                    raise AssertionError(label + ' missing-buffer constructor did not ordinarily reject: ' + (result.stdout + result.stderr).decode(errors='replace'))
            elif result.returncode:
                raise AssertionError(label + ' complete constructor failed: ' + result.stderr.decode(errors='replace'))



if __name__ == '__main__':
    main()
