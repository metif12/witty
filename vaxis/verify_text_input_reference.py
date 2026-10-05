"""Compare TextInput insertion, gap movement and drawing against unchanged source."""
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
PROBE = Path(__file__).resolve().parent / 'reference_probes/text_input'
sys.path.insert(0, str(PROBE.parent / 'widgets_classic'))
from source_build import VAXIS_SHA256, UUCODE_PACKAGE, module, prepare_uucode, tree_hash

def corpus():
    rng = random.Random(203052317)
    cases = []

    def add(*values):
        cases.append('|'.join(map(str, values)))
    texts = ['', 'abc', 'hello  world', 'é', '👩\u200d🚀', '🏳️\u200d🌈', '界aé', '\r\n', '\t', '\x00', '👍🏽', '🇺🇸🇨🇦', '\u0600a', '각', '́', 'a\u200db', ' ', 'word ' * 128]
    raw = [text.encode() for text in texts]
    raw += [bytes.fromhex(s) for s in ('ff', 'c0', '80', 'f09f', 'e180', 'ff61', '61ff', 'e18061', 'ed a0 80', 'f4 90 80 80')]
    for (text, repeats) in itertools.product(raw, (0, 1, 2, 4)):
        add('I', text.hex(), repeats)
    for count in (511, 512, 513, 1024, 1025, 2048):
        add('I', ('a' * count).encode().hex(), 1)
    for _ in range(1024):
        text = ''.join(rng.choices(texts[:17], k=rng.randrange(1, 20))).encode()
        add('I', text.hex(), rng.randrange(1, 4))
    for _ in range(2048):
        text = rng.randbytes(rng.randrange(33))
        left = rng.randrange(len(text) + 5)
        cursor = max(len(text) - left, 0)
        right = rng.randrange(len(text) - cursor + 1)
        cursor += right
        growleft = rng.randrange(cursor + 5)
        add('B', text.hex(), left, right, growleft, rng.randrange(len(text) + 5))
    for _ in range(3072):
        text = ''.join(rng.choices(texts[:17], k=rng.randrange(9))).encode()
        add('D', text.hex(), rng.randrange(15), rng.randrange(17), rng.randrange(3), rng.randrange(3), rng.choice((0, 1, 3, 12, 65535)), rng.randrange(4))
    for (code, mods, text, left) in itertools.product(range(15), (0, 1, 2, 4, 64, 128, 193), ('abc def', 'é👩\u200d🚀 x'), (0, 1, 3)):
        add('U', text.encode().hex(), left, code, mods, '62')
    for (width, method, left, offset) in itertools.product((0, 1, 2, 3, 8, 16), range(3), (0, 1, 7), (0, 1, 65535)):
        add('D', '6162636465666768', left, width, 1, method, offset, 1)
    malformed = [bytes.fromhex(value) for value in ('ff','c0','80','f09f','e180','ed a0 80','f4 90 80 80','61ff62','e18061','61c062','ff80ff','e2808dff')]
    for text in malformed:
        for left, action, method, offset, width in itertools.product(range(len(text)+2),range(5),range(3),(0,1,65535),(0,3,16)):
            add('E',text.hex(),left,action,method,offset,width,rng.randrange(4))
    for count in (65534,65535):
        add('E',('a'*count).encode().hex(),0,4,1,65535,0,1)
    return cases

def slice_corpus():
    cases = []
    raw = [b'', b'abc', b'a\x00b', 'ab界c'.encode(), 'é👩\u200d🚀'.encode(), bytes.fromhex('ffcc8161'), bytes(range(32)), b'a' * 513]
    for text, left, extra in itertools.product(raw, (0, 1, 3, 1000), (0, 1, 8)):
        cases.append(f'S|{text.hex()}|{left}|{extra}')
    return cases

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('zig', type=Path)
    parser.add_argument('v', type=Path)
    parser.add_argument('--uucode', type=Path, default=Path.home() / '.cache/zig/p' / UUCODE_PACKAGE)
    parser.add_argument('--target', default='aarch64-macos.14.0')
    parser.add_argument('--v-prod', action='store_true')
    parser.add_argument('--slice-only', action='store_true', help='compare caller-buffer sliceToCursor alone')
    parser.add_argument('--v-path', help=argparse.SUPPRESS)
    args = parser.parse_args()
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
    source = args.source.resolve() / 'src'
    if tree_hash(source) != VAXIS_SHA256:
        parser.error('vaxis src differs from the recorded local source')
    cases = slice_corpus() if args.slice_only else corpus() + slice_corpus()
    with tempfile.TemporaryDirectory(prefix='witty-text-input-') as directory:
        root = Path(directory)
        shutil.copytree(source, root / 'src')
        graph = prepare_uucode(args.zig.resolve(), root, args.uucode.resolve(), args.target)
        zig = str(args.zig.resolve())

        def native(path, output):
            return [zig, 'build-exe', '-target', args.target, '-lc', *module('root', path, ['vaxis']), *module('vaxis', root / 'src/main.zig', ['uucode']), *graph, output]
        subprocess.run(native(PROBE / 'reference.zig', f"-femit-bin={root / 'native'}"), check=True)
        options = ['-prod'] if args.v_prod else []
        if args.v_path:
            options += ['-path', args.v_path]
        environment = dict(os.environ, VEXE=str(args.v.resolve()), V_C_ERROR_BUG_REPORT_DISABLED='1')
        subprocess.run([str(args.v.resolve()), *options, '-o', str(root / 'translated'), str(PROBE / 'main.v')], env=environment, check=True)
        corpus_path = root / 'corpus.txt'
        corpus_path.write_text('\n'.join(cases) + '\n')
        outputs = [subprocess.run([str(root / executable), str(corpus_path)], capture_output=True, check=True, timeout=60).stdout.splitlines() for executable in ('native', 'translated')]
        if any((len(output) != len(cases) for output in outputs)):
            raise AssertionError([len(cases)] + [len(output) for output in outputs])
        for (index, (data, expected, actual)) in enumerate(zip(cases, *outputs)):
            if expected != actual:
                raise AssertionError(f'row {index} ({data}): native={expected!r}, V={actual!r}')
        traps = {'trap_right': 'index out of bounds', 'trap_right_order': 'is larger than end index', 'trap_right_add': 'integer overflow', 'trap_right_end': 'integer overflow', 'trap_gap_left': 'integer overflow', 'trap_unicode': 'integer overflow'}
        traps.update(dict.fromkeys(('trap_count','trap_width','trap_utf8_left','trap_utf8_delete','trap_utf8_count','trap_utf8_width','trap_utf8_right','trap_utf8_after'),'integer overflow'))
        traps.update(dict.fromkeys(('trap_grow', 'trap_second_half', 'trap_left_add', 'trap_gap_right_add', 'trap_gap_right_sub', 'trap_insert_add'), 'integer overflow'))
        traps.update(dict.fromkeys(('trap_first_half', 'trap_left_zero'), 'index out of bounds'))
        traps['trap_left_zero'] = ('is larger than end index', 'index out of bounds')
        slice_traps = {'trap_slice_short': ('reached unreachable code', 'Assertion failed'), 'trap_slice_alias': '@memcpy arguments alias'}
        traps = slice_traps if args.slice_only else dict(traps, **slice_traps)
        for (mode, message) in traps.items():
            messages = message if isinstance(message, tuple) else (message, message)
            for executable, expected in zip(('native', 'translated'), messages):
                result = subprocess.run([str(root / executable), mode], capture_output=True, timeout=10)
                if result.returncode == 0 or b'UNEXPECTED' in result.stderr + result.stdout or expected.encode() not in result.stderr + result.stdout:
                    raise AssertionError(f'{mode}: {executable} did not retain the checked trap: ' + (result.stderr + result.stdout).decode(errors='replace'))
        if not args.slice_only:
            baseline_count = len(corpus())
            baseline_hash = hashlib.sha256(b'\n'.join(outputs[0][:baseline_count])).hexdigest()
            if baseline_hash != '4003872debd68d8f2886119b492cc0d14ac1c5692a049662b043074cb67aaaf0':
                raise AssertionError(f'original TextInput corpus changed: {baseline_hash}')
            print(f'Original {baseline_count} records retain SHA256 {baseline_hash}')
        print(f'TextInput: {len(cases)} cases, {len(traps)} traps, SHA256 ' + hashlib.sha256(b'\n'.join(outputs[0])).hexdigest())
if __name__ == '__main__':
    main()
