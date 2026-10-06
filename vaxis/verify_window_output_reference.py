"""Compare public Window fill/clear/print methods with unchanged pinned Vaxis."""
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

PROBE = Path(__file__).resolve().parent / 'reference_probes/window_output'
sys.path.insert(0, str(PROBE.parent / 'widgets_classic'))
from source_build import VAXIS_SHA256, UUCODE_PACKAGE, module, prepare_uucode, tree_hash
sys.path.insert(0, str(PROBE.parents[1]))
from verify_vxfw_surface_reference import checked_trap


def corpus():
    result = []
    rng = random.Random(0x57494E444F57)

    def add(*parts):
        result.append('|'.join(map(str, parts)))

    def fill(sw, sh, length, width, height, x, y, px=0, py=0, clear=0):
        first = x + width
        if not -65536 <= first <= 65535:
            return
        if first >= 0 and not -65536 <= y + height <= 65535:
            return
        add('F', sw, sh, length, width, height, x, y, px, py, clear)

    for sw, sh, width, height, x, y, clear in itertools.product(range(5), range(4), range(5), range(4), (-3, -1, 0, 1, 4), (-3, -1, 0, 1, 4), (0, 1)):
        fill(sw, sh, sw*sh, width, height, x, y, -2, -2, clear)
    sizes = (0, 1, 2, 32768, 65535)
    offsets = (-65536, -32769, -1, 0, 1, 32768, 65535)
    for _ in range(2048):
        sw, sh, width, height = (rng.choice(sizes) for _ in range(4))
        fill(sw, sh, rng.randrange(17), width, height, rng.choice(offsets), rng.choice(offsets), -65536, 65535)
    fill(65535, 65535, 0, 65535, 0, 0, 65535)
    fill(65535, 65535, 0, 65535, 65535, 0, 0)
    fill(1, 1, 1, 0, 1, -1, 65535)  # First clipping test skips the y overflow.

    texts = [b'', b'a', b'abcd', b'a b', b' a\t b ', b'a\nb', b'a\r\nb', b'a\rX', b'\n\n', b'\r',
             '界x'.encode(), 'é 👩‍🚀'.encode(), '🇬🇧🇺🇸'.encode(), b'\x00x', b'\x1b', b'\xffa', b'\xc0\xaf', b'\xe2\x82', b'\xf4\x90\x80\x80']

    def output(width, height, wrap, ro, co, commit, method, text, cut=-1, x=0, y=0, px=0, py=0):
        add('P', 8, 6, 0, width, height, x, y, px, py, wrap, ro, co, commit, method, cut, text.hex())

    for width, height, wrap, commit, method, text in itertools.product(range(7), range(4), range(3), range(2), range(3), texts):
        output(width, height, wrap, 0, 0, commit, method, text)
    for _ in range(2048):
        text = rng.choice(texts)
        try:
            decoded = text.decode('utf-8')
            positions = [0]
            for char in decoded:
                positions.append(positions[-1] + len(char.encode('utf-8')))
        except UnicodeDecodeError:
            positions = [0, len(text)]
        output(rng.randrange(9), rng.randrange(6), rng.randrange(3), rng.randrange(8), rng.randrange(10),
               rng.randrange(2), rng.randrange(3), text, rng.choice(positions),
               rng.choice((-2,-1,0,1,3)), rng.choice((-2,-1,0,1,3)), rng.choice((-3,0)), rng.choice((-3,0)))
    for wrap, commit, method, co, text in itertools.product(range(3), range(2), range(3), (0, 65530), (b'a', '界'.encode(), b'\n', b'\r\n')):
        output(65535, 1, wrap, 0, co, commit, method, text)
    for commit, method in itertools.product(range(2), range(3)):
        output(65535, 1, 2, 0, 65534, commit, method, '界'.encode())
        output(1, 65535, 0, 65534, 0, commit, method, b'\n')
    for wrap in range(3):
        output(65535, 1, wrap, 0, 0, 0, 2, '👩\u200d'.encode()*130)
    return result


def verify(args, root):
    source = args.source.resolve()/'src'
    if tree_hash(source) != VAXIS_SHA256:
        raise ValueError('vaxis source differs from the recorded local source')
    shutil.copytree(source, root/'src')
    environment = dict(os.environ, VEXE=str(args.v.resolve()), V_C_ERROR_BUG_REPORT_DISABLED='1')
    graph = prepare_uucode(args.zig.resolve(), root, args.uucode.resolve(), 'aarch64-macos.14.0')
    mode = 'ReleaseSafe' if args.v_prod else 'Debug'
    native = [str(args.zig.resolve()), 'build-exe', '-O', mode, '-target', 'aarch64-macos.14.0', '-lc',
              *module('root', PROBE/'reference.zig', ['vaxis']), *module('vaxis', root/'src/main.zig', ['uucode']),
              *graph, f'-femit-bin={root/"native"}']
    translated = [str(args.v.resolve()), *(['-prod'] if args.v_prod else []), '-path',
                  f'{PROBE.parents[2]}|@vlib|@vmodules', '-o', str(root/'translated'), str(PROBE/'main.v')]
    for name, command in (('native', native), ('translated', translated)):
        print('Building '+name+' '+mode, file=sys.stderr, flush=True)
        subprocess.run(command, env=environment, check=True)
    rows = corpus()
    data = root/'cases.txt'; data.write_text('\n'.join(rows)+'\n')
    records = []
    for name in ('native', 'translated'):
        print(f'Running {name}: {len(rows)} records', file=sys.stderr, flush=True)
        outcome = subprocess.run([str(root/name), str(data)], env=environment, capture_output=True, timeout=120)
        (root/(name+'.stdout')).write_bytes(outcome.stdout)
        (root/(name+'.stderr')).write_bytes(outcome.stderr)
        if outcome.returncode or outcome.stderr:
            raise AssertionError(f'{name} failed after {len(outcome.stdout.splitlines())} records: {outcome.stderr.decode(errors="replace")}')
        values = outcome.stdout.splitlines()
        if len(values) != len(rows):
            raise AssertionError(f'{name}: {len(values)} of {len(rows)} records')
        records.append(values)
    for i, (case, expected, actual) in enumerate(zip(rows, *records)):
        if expected != actual:
            raise AssertionError(f'record {i} ({case}): Source={expected!r}; V={actual!r}')
    traps = ('fill_x', 'fill_y', 'row_initial', 'row_final', 'col', 'wrapped', 'word_sum', 'word_whitespace', 'word_defer',
             'unicode_grapheme', 'unicode_word', 'unicode_none', 'width_grapheme', 'width_word', 'width_none')
    for name in traps:
        label = 'trap_'+name
        for executable in ('native', 'translated'):
            outcome = subprocess.run([str(root/executable), label], env=environment, capture_output=True, timeout=15)
            (root/(executable+'-'+label+'.stderr')).write_bytes(outcome.stderr)
            category = ('integer does not fit in destination type' if executable == 'native' else 'integer cast truncated bits') if name.startswith('width_') else 'integer overflow'
            checked_trap(outcome, label, category, executable)
    print(f'Window output: {len(rows)} returning records, {len(traps)} strict traps; SHA256 '+hashlib.sha256(b'\n'.join(records[0])).hexdigest())


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('zig', type=Path)
    parser.add_argument('v', type=Path)
    parser.add_argument('--uucode', type=Path, default=Path.home()/'.cache/zig/p'/UUCODE_PACKAGE)
    parser.add_argument('--v-prod', action='store_true')
    parser.add_argument('--workdir', type=Path)
    args = parser.parse_args()
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
    if args.workdir:
        root = args.workdir.resolve(); root.mkdir(); verify(args, root)
    else:
        with tempfile.TemporaryDirectory(prefix='witty-window-output-') as directory:
            verify(args, Path(directory))


if __name__ == '__main__':
    main()
