"""Compare vxfw TextField against unchanged pinned source and locked uucode."""
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

PROBE = Path(__file__).resolve().parent / 'reference_probes/vxfw_text_field'
sys.path.insert(0, str(PROBE.parent / 'widgets_classic'))
from source_build import VAXIS_SHA256, UUCODE_PACKAGE, module, prepare_uucode, tree_hash


def corpus():
    rng = random.Random(0x544558544649454c44)
    cases = []

    def add(*values):
        cases.append('|'.join(map(str, values)))

    def lefts(text):
        try:
            decoded = text.decode()
        except UnicodeDecodeError:
            return list(range(len(text) + 2))
        boundaries = [0]
        for cp in decoded:
            boundaries.append(boundaries[-1] + len(cp.encode()))
        # Valid UTF-8 fixtures also split grapheme clusters at codepoint
        # boundaries. Mid-codepoint-plus-Extend underflow remains a trap case.
        return sorted({len(text) - offset for offset in boundaries} | {len(text) + 1})

    texts = [b'', b'abc', b'hello  world ', b'\x00a\x00', b'\r\n', b'\t', b' ' * 7]
    texts += [value.encode() for value in ('界aé', 'é', '👩\u200d🚀', '🏳️\u200d🌈', '👍🏽', '🇺🇸🇨🇦', '\u0600a', '각', '́', 'a\u200db', '❤️', '❤︎')]
    texts += [bytes.fromhex(value) for value in ('ff', 'c0', '80', 'f09f', 'e180', 'eda080', 'f4908080', '61ff62', 'e18061', '61c062', 'ff80ff', 'e2808dff')]
    for text, count in itertools.product(texts, (0, 1, 2, 4)):
        add('I', text.hex(), count)
    for byte in range(256):
        add('I', bytes((byte,)).hex(), 1)
    for size in (511, 512, 513, 1024, 1025):
        add('I', (b'a' * size).hex(), 1)
    for text in texts:
        for left, action, method in itertools.product(lefts(text), range(16), range(3)):
            add('M', text.hex(), left, action, method, rng.choice((0, 1, 3, 65535)), 13, rng.randrange(16))
    for size, offset in itertools.product((65535, 65536, 65537), (0, 65535)):
        if size > 65535 and offset == 0:
            continue  # checked width overflow is tested separately
        add('M', (b'a' * size).hex(), 0, 14, 0, offset, 1, 15)
    for text in texts:
        for left, width, method, offset in itertools.product(sorted({0, len(text) + 1, *lefts(text)[1:3]}), (0, 1, 2, 3, 8, 16), range(3), (0, 1, 65535)):
            add('D', text.hex(), left, width, method, offset, rng.choice((width, 17)), rng.randrange(16), rng.randrange(4), rng.randrange(4))
    for text, left, extra in itertools.product(texts + [b'a' * 513], (0, 1, 3, 1000), (0, 1, 8)):
        add('S', text.hex(), left, extra)
    for code, mods, handler, text in itertools.product(range(17), (0, 1, 2, 4, 64, 128, 193), range(10), (b'abc def', 'é👩\u200d🚀 x'.encode())):
        add('E', text.hex(), rng.choice(lefts(text)), code, mods, rng.choice(('none', '', '62', 'ff', 'f09f')), 0, handler, rng.choice(('', text.hex(), '6f6c64')), rng.randrange(8))
    for event, handler, flags in itertools.product(range(1, 5), range(10), range(8)):
        add('E', '616263', 1, 14, 0, 'ff', event, handler, '616263', flags)
    for text in texts:
        for left, width, method in itertools.product(lefts(text), (0, 1, 3, 16), range(3)):
            add('P', text.hex(), left, width, method, 0, 0, 4, 1, 1)
    return cases


TRAPS = {
    'trap_count': b'integer overflow',
    'trap_second_count': b'integer overflow',
    'trap_width': b'integer overflow',
    'trap_grapheme_width': b'integer does not fit in destination type',
    'trap_surface_size': b'integer overflow',
    'trap_unbounded': (b'reached unreachable code', b'TextField requires bounded width'),
    **{f'trap_utf8_{action}': b'integer overflow' for action in ('left', 'delete', 'count', 'width', 'right', 'after', 'draw')},
    'trap_unicode': b'integer overflow',
    'trap_slice_short': (b'reached unreachable code', b'Assertion failed'),
    'trap_slice_alias': b'@memcpy arguments alias',
}


def panic_category(result, expected):
    if result.returncode == 0 or result.stdout:
        return False
    if any(line.startswith(b'UNEXPECTED:') for line in result.stderr.splitlines()):
        return False
    return any(match.group(1).startswith(expected) for line in result.stderr.splitlines()
               if (match := re.fullmatch(rb'(?:thread [0-9]+ )?(?:V )?panic:\s*(.*)', line)))


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
    zig_mode = args.zig_mode or ('ReleaseSafe' if args.v_prod else 'Debug')
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
    source = args.source.resolve() / 'src'
    if tree_hash(source) != VAXIS_SHA256:
        parser.error('vaxis source differs from pinned source tree')
    environment = dict(os.environ, VEXE=str(args.v.resolve()), V_C_ERROR_BUG_REPORT_DISABLED='1')
    with tempfile.TemporaryDirectory(prefix='witty-text-field-') as folder:
        root = Path(folder)
        shutil.copytree(source, root / 'src')
        graph = prepare_uucode(args.zig.resolve(), root, args.uucode.resolve(), args.target)
        options = ['-prod'] if args.v_prod else []

        def native(path, output):
            return [str(args.zig.resolve()), 'build-exe', '-target', args.target, '-lc', '-O', zig_mode,
                    *module('root', path, ['vaxis']), *module('vaxis', root / 'src/main.zig', ['uucode']), *graph, output]

        try:
            print(f'Building unchanged source ({zig_mode}) and V ({"production" if args.v_prod else "ordinary"})', flush=True)
            subprocess.run(native(PROBE / 'reference.zig', f'-femit-bin={root / "native"}'), check=True)
            subprocess.run([str(args.v.resolve()), *options, '-o', str(root / 'translated'), str(PROBE / 'main.v')], env=environment, check=True)
            cases = corpus()
            corpus_path = root / 'corpus.txt'
            corpus_path.write_text('\n'.join(cases) + '\n')
            print(f'Comparing {len(cases)} returning records', flush=True)
            outputs = []
            for executable in ('native', 'translated'):
                result = subprocess.run([str(root / executable), str(corpus_path)], capture_output=True, timeout=120)
                if result.returncode:
                    raise AssertionError(f'{executable} returning corpus failed: {result.stderr.decode(errors="replace")}')
                outputs.append(result.stdout.splitlines())
            if any(len(output) != len(cases) for output in outputs):
                raise AssertionError([len(cases)] + [len(output) for output in outputs])
            for index, (record, expected, actual) in enumerate(zip(cases, *outputs)):
                if expected != actual:
                    raise AssertionError(f'row {index} ({record}): native={expected!r}\nV={actual!r}')
            print(f'Checking {len(TRAPS)} isolated traps and u4 constructor boundary', flush=True)
            for name, categories in TRAPS.items():
                for index, executable in enumerate(('native', 'translated')):
                    result = subprocess.run([str(root / executable), name], capture_output=True, timeout=10)
                    expected = categories[index] if isinstance(categories, tuple) else categories
                    if not panic_category(result, expected):
                        raise AssertionError(f'{executable} checked trap {name} did not match {expected!r}: {result.returncode}\n{result.stderr.decode(errors="replace")}')
            result = subprocess.run(native(PROBE / 'scroll_offset_unsupported.zig', '-fno-emit-bin'), capture_output=True, timeout=120)
            diagnostics = result.stdout + result.stderr
            if result.returncode != 1 or b"cannot represent integer value '16'" not in diagnostics or b'panic:' in diagnostics:
                raise AssertionError(f'ordinary source u4 literal boundary failed: {diagnostics.decode(errors="replace")}')
            result = subprocess.run([str(args.v.resolve()), *options, '-check', str(PROBE / 'scroll_offset_unsupported.v')], env=environment, capture_output=True, timeout=120)
            if result.returncode:
                raise AssertionError(f'V u8 representation boundary did not compile: {(result.stdout + result.stderr).decode(errors="replace")}')
            print(f'TextField: {len(cases)} returning records, {len(TRAPS)} checked trap pairs, 1 measured source-only u4 constructor boundary, SHA256 ' + hashlib.sha256(b'\n'.join(outputs[0])).hexdigest())
        finally:
            if args.keep:
                shutil.copytree(root, args.keep, dirs_exist_ok=True)


if __name__ == '__main__':
    main()
