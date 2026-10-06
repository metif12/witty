"""Compare public packed Cell.Scale construction, mutation, copies and equality."""
import argparse
from collections import Counter
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
from unittest.mock import patch

PROBE = Path(__file__).resolve().parent / 'reference_probes/cell_scale'
sys.path.insert(0, str(PROBE.parent / 'widgets_classic'))
from source_build import VAXIS_SHA256, UUCODE_SHA256, UUCODE_PACKAGE, module, prepare_uucode, tree_hash
from verify_vxfw_surface_reference import checked_trap


def corpus():
    rows = ['D'] + [f'A|{n}' for n in range(3)]
    for scale, numerator, denominator, alignment in itertools.product(range(8), range(16), range(16), range(4)):
        rows.append(f'C|{scale}|{numerator}|{denominator}|{alignment}')
    for bits in range(8192):
        rows.append(f'R|{bits}')
        rows.append(f'M|{bits}|{(bits*7+1)%8}|{(bits*11+3)%16}|{(bits*3+5)%16}|{((bits>>8)+1)%4}')
    return rows


TRAPS = []
for field, first in (('scale', 8), ('numerator', 16), ('denominator', 16), ('alignment', 4)):
    for operation, value in itertools.product(('init', 'set'), (first, 255)):
        TRAPS.append((f'{operation}_{field}_{value}', 'integer does not fit in destination type'))
TRAPS += [('enum_3', 'invalid enum value'), ('enum_4', 'integer does not fit in destination type'),
          ('enum_255', 'integer does not fit in destination type'),
          ('bits_8192', 'integer does not fit in destination type'),
          ('bits_65535', 'integer does not fit in destination type')]
for field, operation, value in itertools.product(('scale', 'numerator', 'denominator'), ('init', 'set'), (256, 65535, 18446744073709551615)):
    TRAPS.append((f'{operation}_{field}_{value}', 'integer does not fit in destination type'))
for value in (256, 65535, 18446744073709551615):
    TRAPS.append((f'enum_{value}', 'integer does not fit in destination type'))
for value in (65536, 18446744073709551615):
    TRAPS.append((f'bits_{value}', 'integer does not fit in destination type'))


def ordinary_rejection(result, label, diagnostic):
    text = (result.stdout + result.stderr).decode(errors='replace')
    errors = [line.split('error:', 1)[1] for line in text.splitlines() if 'error:' in line]
    if (result.returncode != 1 or not errors or not any(re.search(diagnostic, line, re.I) for line in errors)
            or re.search(r'panic:|Segmentation|Bus error|compiler bug|internal compiler|C compilation failed|C compiler error|builder error|\.tmp\.c:.*error:|LLVM ERROR', text, re.I)):
        raise AssertionError(label + ' was not the expected ordinary compiler rejection: ' + text)


def contracts(root, commands, invoke):
    source_command = [argument for argument in commands[0][1] if not argument.startswith('-femit-bin=')]
    v_command = commands[1][1][:-3]

    def check(label, source_body, v_body, source_error=None, v_error=None, declarations=('', '')):
        zp, vp = root / (label + '.zig'), root / (label + '.v')
        zp.write_text('const v=@import("vaxis");const S=v.Cell.Scale;const A=@FieldType(S,"vertical_alignment");'
                      + declarations[0] + 'pub fn main()void{' + source_body + '}\n')
        vp.write_text('module main\nimport vaxis as v\n' + declarations[1] + '\nfn main(){\n' + v_body + '\n}\n')
        native = [f'-Mroot={zp}' if argument.startswith('-Mroot=') else argument for argument in source_command]
        for executable, command, expected in (('native', [*native, '-fno-emit-bin'], source_error),
                                               ('translated', [*v_command, '-check', str(vp)], v_error)):
            result = invoke(label + '-' + executable + '-compile', command)
            if expected is not None:
                ordinary_rejection(result, label + ' ' + executable, expected)
            elif result.returncode:
                raise AssertionError(label + ' ' + executable + ' did not compile: ' + (result.stdout+result.stderr).decode(errors='replace'))

    complete = [('default', 'const value:S=.{};_=value;', 'value:=v.CellScale{}\n_ = value')]
    for field, value, setter in (('scale', '7', 'set_scale'), ('numerator', '15', 'set_numerator'),
                                  ('denominator', '0', 'set_denominator'), ('vertical_alignment', '.center', 'set_vertical_alignment')):
        complete.append(('partial_' + field, f'const value:S=.{{.{field}={value}}};_=value;',
                         f'mut value:=v.CellScale{{}}\nvalue.{setter}({value})\n_ = value'))
    complete.append(('public_mutation', 'var value:S=@bitCast(@as(u13,8191));const copied=value;value.scale=0;value.numerator=0;value.denominator=0;value.vertical_alignment=.top;_=value.eql(copied);',
                     'mut value:=v.CellScale.from_bits(8191)\ncopied:=value\nvalue.set_scale(0)\nvalue.set_numerator(0)\nvalue.set_denominator(0)\nvalue.set_vertical_alignment(.top)\n_ = value.eql(copied)'))
    for name, source_body, v_body in complete:
        check('complete_' + name, source_body, v_body)

    paired = [
        ('negative', 'const value:S=.{.scale=-1};_=value;', 'value:=v.CellScale.init(-1,1,1,.top)\n_ = value',
         r"u3.*cannot represent.*-1", r'literal signed integer.*u64|negative|cannot.*-1|overflows.*u64'),
        ('wrong_boolean', 'const value:S=.{.scale=true};_=value;', 'value:=v.CellScale.init(true,1,1,.top)\n_ = value',
         r"expected type 'u3'", r'cannot use.*bool.*u64|expected.*u64'),
        ('wrong_scalar', 'const value:S=.{.denominator="bad"};_=value;', "value:=v.CellScale.init(1,1,'bad',.top)\n_ = value",
         r"expected type 'u4'", r'cannot use.*string.*u64|expected.*u64'),
        ('alignment_integer', 'const value:S=.{.vertical_alignment=1};_=value;', 'value:=v.CellScale.init(1,1,1,1)\n_ = value',
         r'expected type .*enum', r'cannot use.*VerticalAlignment|expected.*VerticalAlignment'),
        ('alignment_unknown', 'const value:S=.{.vertical_alignment=.sideways};_=value;', 'value:=v.CellScale.init(1,1,1,.sideways)\n_ = value',
         r'(no|unknown|invalid).*sideways', r'(no|unknown|invalid).*sideways'),
    ]
    for name, source_body, v_body, source_error, v_error in paired:
        check(name, source_body, v_body, source_error, v_error)
    check('alignment_other_enum', 'const value:S=.{.vertical_alignment=Other.top};_=value;',
          'value:=v.CellScale.init(1,1,1,Other.top)\n_ = value', r'expected type .*enum.*found.*Other',
          r'cannot use.*Other.*VerticalAlignment|expected.*VerticalAlignment',
          ('const Other=enum(u2){top};', 'enum Other as u8 {top}\n'))

    # Source constants are checked during compilation. Native V factory calls
    # check the wider carrier at runtime; the same values have paired traps above.
    boundaries = []
    for field, value in (('scale', 8), ('numerator', 16), ('denominator', 16)):
        values = {'scale': 1, 'numerator': 1, 'denominator': 1, field: value}
        boundaries.append(('constant_' + field, f'const value:S=.{{.{field}={value}}};_=value;',
                           'value:=v.CellScale.init(' + ','.join(str(values[name]) for name in ('scale', 'numerator', 'denominator')) + ',.top)\n_ = value', r'cannot represent integer value'))
    boundaries += [('constant_enum', 'const value:A=@enumFromInt(3);_=value;', 'value:=v.VerticalAlignment.from_int(3)\n_ = value', r'no tag.*3'),
                   ('constant_bits', 'const value:S=@bitCast(@as(u13,8192));_=value;', 'value:=v.CellScale.from_bits(8192)\n_ = value', r'u13.*cannot represent.*8192')]
    for name, source_body, v_body, source_error in boundaries:
        check(name, source_body, v_body, source_error)
    # Source forbids integer->enum @bitCast. Pinned V accepts an unsafe literal
    # in ordinary mode, but rejects this undeclared tag during a -prod check.
    check('enum_bitcast', 'const value:A=@bitCast(@as(u2,3));_=value;',
          'value:=unsafe{v.VerticalAlignment(3)}\n_ = value', r'cannot @bitCast',
          r'does not represent.*VerticalAlignment' if '-prod' in v_command else None)
    return len(complete), len(paired) + 1, len(boundaries)


def verify(args, root, env, mode):
    source = args.source.resolve() / 'src'
    shutil.copytree(source, root / 'src')
    fixtures = {path.name: hashlib.sha256(path.read_bytes()).hexdigest()
                for path in (PROBE / 'reference.zig', PROBE / 'main.v', Path(__file__))}
    metadata = {'source_sha256': VAXIS_SHA256, 'uucode_sha256': UUCODE_SHA256, 'fixtures': fixtures,
                'source_mode': mode, 'v_mode': 'production' if args.v_prod else 'ordinary',
                'target': args.target, 'environment': env,
                'source_api': 'unchanged public Cell.Scale fields/eql and language cast/bitcast builtins',
                'source_build_sha256': hashlib.sha256((PROBE.parent / 'widgets_classic/source_build.py').read_bytes()).hexdigest()}
    (root / 'metadata.json').write_text(json.dumps(metadata, indent=2) + '\n')

    def invoke(label, command, timeout=args.timeout, **kwargs):
        (root / (label + '-argv.json')).write_text(json.dumps({'argv': command, 'cwd': str(kwargs.get('cwd', Path.cwd()))}, indent=2) + '\n')
        result = original_run(command, env=env, capture_output=True, timeout=timeout, **kwargs)
        (root / (label + '.stdout')).write_bytes(result.stdout)
        (root / (label + '.stderr')).write_bytes(result.stderr)
        return result

    original_run = subprocess.run
    dependency_commands = 0

    def dependency_run(command, **kwargs):
        nonlocal dependency_commands
        check = kwargs.pop('check', False)
        result = invoke('unicode-' + str(dependency_commands), command, **kwargs)
        dependency_commands += 1
        if check:
            result.check_returncode()
        return result

    print('Generating unchanged locked Unicode dependency tables', file=sys.stderr, flush=True)
    with patch('source_build.subprocess.run', dependency_run):
        graph = prepare_uucode(args.zig.resolve(), root, args.uucode.resolve(), args.target)
    commands = [('native ' + mode, [str(args.zig.resolve()), 'build-exe', '-O', mode, '-target', args.target, '-lc',
                 *module('root', PROBE / 'reference.zig', ['vaxis']), *module('vaxis', root / 'src/main.zig', ['uucode']),
                 *graph, f'-femit-bin={root / "native"}']),
                ('V production' if args.v_prod else 'V ordinary', [str(args.v.resolve()), '-enable-globals',
                 *(['-prod'] if args.v_prod else []), '-path', args.v_path or str(PROBE.parents[2]) + '|@vlib|@vmodules',
                 '-o', str(root / 'translated'), str(PROBE / 'main.v')])]
    for index, (label, command) in enumerate(commands):
        print('Building ' + label, file=sys.stderr, flush=True)
        result = invoke(('native' if index == 0 else 'translated') + '-build', command)
        if result.returncode:
            raise AssertionError(label + ' failed to build: ' + (result.stdout+result.stderr).decode(errors='replace'))
    rows = corpus()
    data = root / 'cases.txt'
    data.write_text('\n'.join(rows) + '\n')
    outputs = []
    for executable in ('native', 'translated'):
        print(f'Running {executable}: {len(rows)} returning records', file=sys.stderr, flush=True)
        start = time.monotonic()
        command = [str(root / executable), str(data)]
        (root / (executable + '-argv.json')).write_text(json.dumps({'argv': command, 'cwd': str(Path.cwd())}, indent=2) + '\n')
        with (root / (executable + '.stdout')).open('wb') as out, (root / (executable + '.stderr')).open('wb') as err:
            result = original_run(command, env=env, stdout=out, stderr=err, timeout=args.timeout)
        output = (root / (executable + '.stdout')).read_bytes().splitlines()
        error = (root / (executable + '.stderr')).read_bytes()
        if result.returncode or error or len(output) != len(rows):
            raise AssertionError(f'{executable} failed after {len(output)} of {len(rows)} records: ' + error.decode(errors='replace'))
        outputs.append(output)
        print(f'{executable} completed in {time.monotonic()-start:.2f}s', file=sys.stderr, flush=True)
    for i, (case, expected, actual) in enumerate(zip(rows, *outputs)):
        if expected != actual:
            raise AssertionError(f'record {i} ({case}): source={expected!r}, V={actual!r}')
    states = []
    for label, category in TRAPS:
        observations = []
        for executable in ('native', 'translated'):
            path = root / (executable + '-' + label + '.state')
            result = invoke(executable + '-' + label, [str(root / executable), '--trap', label, str(path)])
            checked_trap(result, label, category, executable)
            observations.append(path.read_bytes())
        if observations[0] != observations[1]:
            raise AssertionError(f'{label} panic state: source={observations[0]!r}, V={observations[1]!r}')
        if observations[0] != b'3805,5,11,13,1,0':
            raise AssertionError(label + ' changed the previous packed value before its cast failure')
        states.append(label.encode() + b'|' + observations[0])
        print(f'{label}: strict panic category and retained state match', file=sys.stderr, flush=True)
    print('Checking complete consumers, ordinary type rejections and Source-only compiler boundaries', file=sys.stderr, flush=True)
    complete, paired, boundaries = contracts(root, commands, invoke)
    for name, path, expected in (('original source', source, VAXIS_SHA256), ('copied source', root / 'src', VAXIS_SHA256),
            ('original Unicode', args.uucode.resolve(), UUCODE_SHA256), ('copied Unicode', root / 'uucode', UUCODE_SHA256)):
        if tree_hash(path) != expected:
            raise AssertionError(name + ' changed during verification')
    for path in (PROBE / 'reference.zig', PROBE / 'main.v', Path(__file__)):
        if hashlib.sha256(path.read_bytes()).hexdigest() != fixtures[path.name]:
            raise AssertionError('fixture changed during verification: ' + str(path))
    output_hash = hashlib.sha256(b'\n'.join(outputs[0])).hexdigest()
    state_hash = hashlib.sha256(b'\n'.join(states)).hexdigest()
    metadata.update({'returning_records': len(rows), 'strict_traps': len(TRAPS), 'panic_states': len(states),
                     'complete_consumers': complete, 'paired_ordinary_compiler_rejections': paired,
                     'source_only_compiler_boundaries': boundaries,
                     'enum_bitcast_compiler_boundary': {'source': 'integer-to-enum bitcast rejected',
                         'v_unsafe_literal_3': 'ordinary enum-value rejection' if args.v_prod else 'accepted'},
                     'output_sha256': output_hash, 'panic_state_sha256': state_hash, 'unchanged_source_postcheck': True})
    (root / 'metadata.json').write_text(json.dumps(metadata, indent=2) + '\n')
    print(f'CellScale: {len(rows)} returning records {dict(Counter(row[0] for row in rows))}, {len(TRAPS)} strict traps and panic states; '
          f'{complete} complete consumers, {paired} paired ordinary compiler rejections, {boundaries} Source-only compiler boundaries, 1 measured enum-bitcast/literal boundary; '
          'SHA256 ' + output_hash + '; state SHA256 ' + state_hash)


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
    parser.add_argument('--build-dir', type=Path, help='Keep fresh artifacts for inspection; directory must not exist')
    args = parser.parse_args()
    if args.timeout <= 0:
        parser.error('--timeout must be positive')
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
    if tree_hash(args.source.resolve() / 'src') != VAXIS_SHA256:
        parser.error('vaxis source differs from the recorded local source')
    # Record the complete child environment without retaining unrelated secrets.
    keys = ('PATH', 'HOME', 'TMPDIR', 'SDKROOT', 'MACOSX_DEPLOYMENT_TARGET', 'LANG', 'LC_ALL')
    env = {key: os.environ[key] for key in keys if key in os.environ}
    env.update(VEXE=str(args.v.resolve()), V_C_ERROR_BUG_REPORT_DISABLED='1')
    mode = args.zig_mode or ('ReleaseSafe' if args.v_prod else 'Debug')
    if args.build_dir:
        args.build_dir.mkdir(parents=True, exist_ok=False)
        verify(args, args.build_dir.resolve(), env, mode)
    else:
        with tempfile.TemporaryDirectory(prefix='witty-cell-scale-') as directory:
            verify(args, Path(directory), env, mode)


if __name__ == '__main__':
    main()
