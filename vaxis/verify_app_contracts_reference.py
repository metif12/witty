"""Compare represented App constructors and public copies with unchanged Vaxis."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

PROBE = Path(__file__).resolve().parent / 'reference_probes/vxfw_app_contracts'
sys.path.insert(0, str(PROBE.parent / 'widgets_classic'))
from source_build import VAXIS_SHA256, UUCODE_PACKAGE, module, prepare_uucode, tree_hash

SOURCE_FIELDS = {
    'allocator': 'std.heap.page_allocator',
    'tty': 'undefined',
    'vx': 'undefined',
    'timers': '.empty',
    'wants_focus': 'null',
    'buffer': 'undefined',
}
V_FIELDS = {
    'tty': 'vaxis.Tty{}',
    'vx': 'vaxis.Vaxis.new(vaxis.VaxisOptions{})',
    'timers': '[]vxfw.Tick{}',
    'wants_focus': 'none',
}


def ordinary_rejection(result, marker):
    diagnostic = result.stdout + result.stderr
    return (result.returncode > 0 and b'error:' in diagnostic and marker.encode() in diagnostic
            and not any(word in diagnostic.lower() for word in
                        (b'panic:', b'compiler bug', b'segmentation fault', b'segfault', b'c error found'))
            and not any(line.lstrip().startswith(b'UNEXPECTED:') for line in diagnostic.splitlines()))


def source_constructor(missing=None):
    return '.{' + ','.join('.' + name + '=' + value for name, value in SOURCE_FIELDS.items()
                          if name != missing) + '}'


def v_constructor(missing=None, kind='vxfw.App'):
    return kind + '{' + ','.join(name + ':' + value for name, value in V_FIELDS.items()
                                if name != missing) + '}'


def run(args, root):
    source = args.source.resolve() / 'src'
    if tree_hash(source) != VAXIS_SHA256:
        raise ValueError('vaxis source differs from the pinned source')
    shutil.copytree(source, root / 'src')
    mode = args.zig_mode or ('ReleaseSafe' if args.v_prod else 'Debug')
    env = dict(os.environ, VEXE=str(args.v.resolve()), V_C_ERROR_BUG_REPORT_DISABLED='1')
    print('Preparing unchanged locked Unicode graph', file=sys.stderr, flush=True)
    graph = prepare_uucode(args.zig.resolve(), root, args.uucode.resolve(), args.target)
    options = ['-prod'] if args.v_prod else []
    path = str(PROBE.parents[2]) + '|@vlib|@vmodules'
    commands = []

    def source_command(file, emit=False):
        return [str(args.zig.resolve()), 'build-exe', '-O', mode, '-target', args.target, '-lc',
                *module('root', file, ['vaxis']),
                *module('vaxis', root / 'src/main.zig', ['uucode']), *graph,
                f'-femit-bin={root / "native"}' if emit else '-fno-emit-bin']

    def v_command(file, emit=False):
        return [str(args.v.resolve()), *options, '-path', path,
                *(['-o', str(root / 'translated')] if emit else ['-check']), str(file)]

    def execute(command, label):
        commands.append({'label': label, 'command': command})
        (root / 'commands.json').write_text(json.dumps(commands, indent=2) + '\n')
        result = subprocess.run(command, env=env, capture_output=True, timeout=args.timeout)
        (root / (label + '.stdout')).write_bytes(result.stdout)
        (root / (label + '.stderr')).write_bytes(result.stderr)
        return result

    print('Building batched public state/default/copy consumer (' + mode + ')', file=sys.stderr, flush=True)
    for name, command in [('source-build', source_command(PROBE / 'reference.zig', True)),
                          ('v-build', v_command(PROBE / 'main.v', True))]:
        result = execute(command, name)
        if result.returncode:
            raise AssertionError(name + ': ' + (result.stdout + result.stderr).decode(errors='replace'))
    outputs = []
    for name in ('native', 'translated'):
        result = execute([str(root / name)], name + '-run')
        if result.returncode or result.stderr:
            raise AssertionError(name + ' consumer failed: ' + repr((result.returncode, result.stdout, result.stderr)))
        outputs.append(result.stdout.splitlines())
    if len(outputs[0]) != 5377 or len(outputs[1]) != 5377:
        raise AssertionError('unexpected returning record count: ' + repr([len(output) for output in outputs]))
    for index, (original, translated) in enumerate(zip(*outputs)):
        if original != translated:
            raise AssertionError(f'record {index}: Source={original!r}, V={translated!r}')

    print('Checking independent constructor rejections', file=sys.stderr, flush=True)
    for missing in SOURCE_FIELDS:
        zfile = root / ('missing-' + missing + '.zig')
        zfile.write_text('const std=@import("std");const vaxis=@import("vaxis");'
                         'pub fn main() void {const value:vaxis.vxfw.App=' + source_constructor(missing) + ';_ = value;}\n')
        result = execute(source_command(zfile), 'source-missing-' + missing)
        if not ordinary_rejection(result, 'missing struct field: ' + missing):
            raise AssertionError('Source required ' + missing + ': ' + (result.stdout + result.stderr).decode(errors='replace'))
        if missing in V_FIELDS:
            vfile = root / ('missing-' + missing + '.v')
            vfile.write_text('module main\nimport vaxis\nimport vaxis.vxfw\n'
                             'fn main(){value:=' + v_constructor(missing) + '\nprintln(sizeof(value))}\n')
            result = execute(v_command(vfile), 'v-missing-' + missing)
            if not ordinary_rejection(result, 'vaxis.vxfw.App.' + missing):
                raise AssertionError('V required ' + missing + ': ' + (result.stdout + result.stderr).decode(errors='replace'))
        else:
            vfile = root / ('unrepresented-' + missing + '.v')
            vfile.write_text('module main\nimport vaxis\nimport vaxis.vxfw\n'
                             'fn main(){value:=' + v_constructor() + '\nprintln(value.' + missing + ')}\n')
            result = execute(v_command(vfile), 'v-unrepresented-' + missing)
            if not ordinary_rejection(result, 'type `vaxis.vxfw.App` has no field named `' + missing + '`.'):
                raise AssertionError('V unrepresented ' + missing + ': ' + (result.stdout + result.stderr).decode(errors='replace'))

    # V 0.5.2 does not inherit @[required] through a public struct alias. This
    # is deliberately an asymmetric compiler boundary, never a paired success.
    zfile, vfile = root / 'alias-missing-timers.zig', root / 'alias-missing-timers.v'
    zfile.write_text('const std=@import("std");const vaxis=@import("vaxis");const Alias=vaxis.vxfw.App;'
                     'pub fn main() void{const value:Alias=' + source_constructor('timers') + ';_ = value;}\n')
    vfile.write_text('module main\nimport vaxis\nimport vaxis.vxfw\ntype Alias = vxfw.App\n'
                     'fn main(){value:=' + v_constructor('timers', 'Alias') + '\nprintln(sizeof(value))}\n')
    original = execute(source_command(zfile), 'source-alias-missing-timers')
    translated = execute(v_command(vfile), 'v-alias-missing-timers')
    if not ordinary_rejection(original, 'missing struct field: timers') or translated.returncode:
        raise AssertionError('alias boundary changed: ' + (original.stdout + original.stderr + translated.stdout + translated.stderr).decode(errors='replace'))

    digest = hashlib.sha256(b'\n'.join(outputs[0])).hexdigest()
    print(f'App contracts ({mode}, V {"production" if args.v_prod else "ordinary"}): '
          f'5377 public state/default/copy records, 2 complete constructor types in batched consumer, '
          f'4 paired omission rejections, 2 source-only required fields/2 unavailable V fields, '
          f'1 asymmetric alias-marker boundary; SHA256 {digest}')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('zig', type=Path)
    parser.add_argument('v', type=Path)
    parser.add_argument('--target', default='aarch64-macos.14.0')
    parser.add_argument('--uucode', type=Path, default=Path.home() / '.cache/zig/p' / UUCODE_PACKAGE)
    parser.add_argument('--v-prod', action='store_true')
    parser.add_argument('--zig-mode', choices=('Debug', 'ReleaseSafe'))
    parser.add_argument('--workdir', type=Path)
    parser.add_argument('--timeout', type=int, default=600)
    args = parser.parse_args()
    if args.timeout <= 0:
        parser.error('timeout must be positive')
    if args.workdir:
        args.workdir.mkdir(parents=True, exist_ok=False)
        run(args, args.workdir)
    else:
        with tempfile.TemporaryDirectory(prefix='witty-vxfw-app-contracts-') as directory:
            run(args, Path(directory))


if __name__ == '__main__':
    main()
