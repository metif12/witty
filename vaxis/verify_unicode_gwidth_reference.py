"""Compare public Unicode spans and widths against the unchanged locked source."""
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

PROBE = Path(__file__).resolve().parent / 'reference_probes/unicode_gwidth'
sys.path.insert(0, str(PROBE.parent / 'widgets_classic'))
from source_build import VAXIS_SHA256, UUCODE_PACKAGE, module, prepare_uucode, tree_hash


def corpus():
    rows = []

    def add(text, repeat=1, spans=True):
        if isinstance(text, str):
            text = text.encode()
        rows.append(f'{"S" if spans else "R"}|{text.hex()}|{repeat}')

    add('')
    for byte in range(256):
        add(bytes([byte]))
    # Every two-byte input exercises the locked UTF-8 decoder's consumption,
    # including truncated prefixes and invalid continuation pairs.
    for first, second in itertools.product(range(256), repeat=2):
        add(bytes([first, second]))
    clusters = ['', 'a', 'é', '界', '\x00', '\r\n', '\t', '\x1b', 'e\u0301', '\u0301',
                '\u00ad', '\u200b', '\u200c', '\u200d', '\u2060', '\u034f', '\ufeff',
                '❤', '❤\ufe0e', '❤\ufe0f', '1️⃣', '👩‍🚀', '👋🏿', '🏳️‍🌈', '🇺🇸',
                '각', 'क्\u200dष', '\u0600a', '\u0903', '\U000e0100']
    for left, right in itertools.product(clusters, repeat=2):
        add(left + right)
    # Boundary samples from all Unicode planes; surrogate values have no UTF-8
    # scalar encoding and are represented by malformed-byte cases instead.
    scalars = set(range(0x400))
    for plane in range(17):
        for offset in (0, 1, 0x7f, 0x80, 0x7ff, 0x800, 0xd7ff, 0xe000, 0xfffd, 0xfffe, 0xffff):
            cp = plane * 0x10000 + offset
            if cp <= 0x10ffff and not 0xd800 <= cp <= 0xdfff:
                scalars.add(cp)
    for cp in sorted(scalars):
        add(chr(cp))
    rng = random.Random(0x554e49434f4445)
    tokens = [text.encode() for text in clusters] + [bytes.fromhex(text) for text in
        ('ff', '80', 'c0af', 'c1bf', 'e18061', 'f09f6162', 'eda080', 'f4908080', 'e282', 'f09f92', 'fe', 'f5808080')]
    # A four-byte ASCII prefix prevents the source's deliberately isolated
    # replacement-character start subtraction from underflowing. Its unusual
    # backwards spans are still serialized byte-for-byte.
    for _ in range(4096):
        text = b'abcd' + b''.join(rng.choice(tokens) for _ in range(rng.randrange(1, 9)))
        # no_zwj restarts its Unicode iterator on each raw ZWJ-delimited
        # piece, so give each such piece the same safe prefix.
        add(text.replace('\u200d'.encode(), '\u200d'.encode() + b'abcd'))
    for text in (bytes.fromhex('e18061'), bytes.fromhex('f09f6162'), bytes.fromhex('ff'),
                 bytes.fromhex('eda080'), bytes.fromhex('f4908080')):
        add(text)
    for text, count in [('a', 65535), ('界', 32767), ('\u0301', 65536), ('\u200d', 65536),
                        ('a\u200d', 32767), ('🇺🇸', 16383), ('👩‍🚀', 16383), ('a', 0)]:
        add(text, count, False)
    for text in ('abcdef', 'aé界'):
        for start in range(len(text.encode()) + 1):
            for length in range(len(text.encode()) - start + 1):
                rows.append(f'B|{text.encode().hex()}|1|{start}|{length}')
    for text in (b'abcde', b'\r\nabc', '😀ab'.encode(), bytes.fromhex('e1806162'), b'', b'a',
                 'ébc'.encode(), b'\x00abc', '界abc'.encode(), '́abc'.encode()):
        choices = ['', '0:78' if text else '',
                   f'{len(text)-2}:cc,{len(text)-1}:81' if len(text) >= 2 else '',
                   ','.join(f'{i}:{byte:02x}' for i, byte in enumerate(b'bcde'[:len(text)]))]
        for initial, later in itertools.product(choices, repeat=2):
            rows.append(f'M|{text.hex()}|1|{initial}|{later}')
    return rows


def checked_trap(result, label, category, executable):
    streams = [value.decode(errors='replace') for value in (result.stdout, result.stderr)]
    headers = [match.group(1) for text in streams for line in text.splitlines()
               if (match := re.match(r'^(?:thread \d+ )?(?:V )?panic:\s*(.*)$', line))]
    unexpected = any(line.lstrip().startswith('UNEXPECTED') for text in streams for line in text.splitlines())
    if result.returncode == 0 or result.stdout or unexpected or not any(value.startswith(category) for value in headers):
        raise AssertionError(f'{executable}: {label} did not preserve {category!r}: ' + '\n'.join(streams))


def ordinary_rejection(result, field):
    text = (result.stdout + result.stderr).decode(errors='replace')
    return (result.returncode > 0 and 'error:' in text and field in text
            and not any(token in text.lower() for token in ('panic:', 'compiler bug', 'segmentation fault', 'c error found')))


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
    parser.add_argument('--timeout', type=int, default=180)
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
    with tempfile.TemporaryDirectory(prefix='witty-unicode-gwidth-') as directory:
        root = Path(directory)
        shutil.copytree(source, root / 'src')
        print('Generating unchanged locked Unicode dependency tables', file=sys.stderr, flush=True)
        graph = prepare_uucode(args.zig.resolve(), root, args.uucode.resolve(), args.target)

        def native(path, output):
            return [str(args.zig.resolve()), 'build-exe', '-O', mode, '-target', args.target, '-lc',
                    *module('root', path, ['vaxis']), *module('vaxis', root / 'src/main.zig', ['uucode']),
                    *graph, output]

        options = ['-enable-globals'] + (['-prod'] if args.v_prod else [])
        path_option = ['-path', args.v_path or str(PROBE.parents[2]) + '|@vlib|@vmodules']
        for label, command in [('native ' + mode, native(PROBE / 'reference.zig', f'-femit-bin={root / "native"}')),
                               ('V production' if args.v_prod else 'V ordinary',
                                [str(args.v.resolve()), *options, *path_option, '-o', str(root / 'translated'), str(PROBE / 'main.v')])]:
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
                completed = len(result.stdout.splitlines())
                raise AssertionError(f'{executable} failed after {completed} complete output rows: ' + result.stderr.decode(errors='replace'))
            output = result.stdout.splitlines()
            if len(output) != len(rows):
                raise AssertionError(f'{executable} returned {len(output)} of {len(rows)} records')
            outputs.append(output)
            print(f'{executable} completed in {time.monotonic() - start:.2f}s', file=sys.stderr, flush=True)
        for index, (case, expected, actual) in enumerate(zip(rows, *outputs)):
            if expected != actual:
                raise AssertionError(f'record {index} ({case}): source={expected!r}, V={actual!r}')
        baseline = hashlib.sha256(b'\n'.join(outputs[0][:72065])).hexdigest()
        if baseline != 'a0ef6a61b659d36d44e691ba5d0bb02afb6473b4059d038768e328512a2e98e9':
            raise AssertionError('original immutable corpus hash changed: ' + baseline)
        traps = {'trap_iter_underflow': 'integer overflow', 'trap_context_underflow': 'integer overflow',
                 'trap_width_underflow_unicode': 'integer overflow', 'trap_width_underflow_no_zwj': 'integer overflow',
                 'trap_width_split': 'integer overflow', 'trap_span_add': 'integer overflow',
                 'trap_span_bound': 'index out of bounds', 'trap_span_start': 'index out of bounds'}
        for kind, method in itertools.product(('ascii', 'wide'), ('unicode', 'wcwidth', 'no_zwj')):
            traps[f'trap_width_{kind}_{method}'] = 'integer overflow'
        for label, category in traps.items():
            for executable in ('native', 'translated'):
                result = subprocess.run([str(root / executable), label], env=env, capture_output=True, timeout=20)
                checked_trap(result, label, category, executable)
        for missing in (None, 'start', 'len'):
            fields = [('start', '1'), ('len', '1')]
            selected = [(name, value) for name, value in fields if name != missing]
            zig_fields = ', '.join(f'.{name}={value}' for name, value in selected)
            v_fields = ', '.join(f'{name}:{value}' for name, value in selected)
            zig_path, v_path = root / 'contract.zig', root / 'contract.v'
            zig_path.write_text('const vaxis=@import("vaxis"); pub fn main() void {_ = vaxis.unicode.Grapheme{' + zig_fields + '};}\n')
            v_path.write_text('module main\nimport vaxis\nfn main(){g:=vaxis.Grapheme{' + v_fields + '} println(g.len)}\n')
            for executable, command in [('native', native(zig_path, '-fno-emit-bin')),
                                        ('translated', [str(args.v.resolve()), *path_option, '-check', str(v_path)])]:
                result = subprocess.run(command, env=env, capture_output=True, timeout=90)
                if missing is None and result.returncode:
                    raise AssertionError(f'{executable} rejected complete constructor: ' + (result.stdout + result.stderr).decode(errors='replace'))
                if missing is not None and not ordinary_rejection(result, missing):
                    raise AssertionError(f'{executable} did not ordinarily reject missing {missing}: ' + (result.stdout + result.stderr).decode(errors='replace'))
        print(f'Unicode/gwidth: {len(rows)} records, {len(traps)} strict traps, 1 complete constructor, 2 paired omission rejections; SHA256 ' + hashlib.sha256(b'\n'.join(outputs[0])).hexdigest())


if __name__ == '__main__':
    main()
