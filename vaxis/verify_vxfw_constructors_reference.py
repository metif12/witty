"""Compare framework constructor requirements with unchanged locked Vaxis."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

PROBE = Path(__file__).resolve().parent / 'reference_probes/vxfw_constructors'
sys.path.insert(0, str(PROBE.parent / 'widgets_classic'))
from source_build import VAXIS_SHA256, UUCODE_PACKAGE, module, prepare_uucode, tree_hash

# V field, original field, original value, V value. The two allocator fields
# have no GC counterpart and are always supplied to the original constructors.
WIDGET_Z = '.{.userdata=@ptrFromInt(1),.drawFn=draw}'
WIDGET_V = 'vxfw.Widget{userdata: voidptr(1), draw_fn: draw}'
SURFACE_Z = '.{.size=.{},.widget=' + WIDGET_Z + ',.buffer=&.{},.children=&.{}}'
SURFACE_V = 'vxfw.Surface{size:vxfw.Size{},widget:' + WIDGET_V + ',buffer:[]vaxis.Cell{},children:[]vxfw.SubSurface{}}'
CONTRACTS = [
    ('UserEvent', [('name', 'name', '"event"', "'event'")]),
    ('Tick', [('deadline_ms', 'deadline_ms', '17', '17'), ('widget', 'widget', WIDGET_Z, WIDGET_V)]),
    ('SetMouseShape', [('shape', 'set_mouse_shape', '.text', '.text')]),
    ('RequestFocus', [('widget', 'request_focus', WIDGET_Z, WIDGET_V)]),
    ('CopyToClipboard', [('content', 'copy_to_clipboard', '"text"', "'text'")]),
    ('SetTitle', [('title', 'set_title', '"title"', "'title'")]),
    ('Notification', [('title', 'title', 'null', 'none'), ('body', 'body', '"body"', "'body'")]),
    ('QueryColor', [('kind', 'query_color', '.fg', 'vaxis.ColorReportFg{}')]),
    ('EventContext', [('cmds', 'cmds', '.empty', '[]vxfw.Command{}')]),
    ('DrawContext', [('min', 'min', '.{}', 'vxfw.Size{}'), ('max', 'max', '.{}', 'vxfw.MaxSize{}'), ('cell_size', 'cell_size', '.{}', 'vxfw.Size{}')]),
    ('Widget', [('userdata', 'userdata', '@ptrFromInt(1)', 'voidptr(1)'), ('draw_fn', 'drawFn', 'draw', 'draw')]),
    ('FlexItem', [('widget', 'widget', WIDGET_Z, WIDGET_V)]),
    ('Point', [('row', 'row', '0', '0'), ('col', 'col', '0', '0')]),
    ('RelativePoint', [('row', 'row', '0', '0'), ('col', 'col', '0', '0')]),
    ('HitResult', [('local', 'local', '.{.row=0,.col=0}', 'vxfw.Point{row:0,col:0}'), ('widget', 'widget', WIDGET_Z, WIDGET_V)]),
    ('CursorState', [('row', 'row', '0', '0'), ('col', 'col', '0', '0')]),
    ('Surface', [('size', 'size', '.{}', 'vxfw.Size{}'), ('widget', 'widget', WIDGET_Z, WIDGET_V), ('buffer', 'buffer', '&.{}', '[]vaxis.Cell{}'), ('children', 'children', '&.{}', '[]vxfw.SubSurface{}')]),
    ('SubSurface', [('origin', 'origin', '.{.row=0,.col=0}', 'vxfw.RelativePoint{row:0,col:0}'), ('surface', 'surface', SURFACE_Z, SURFACE_V)]),
]
# Keep the first 18 core contracts intact; widget constructors extend them.
CORE_CONTRACT_COUNT = 18
assert len(CONTRACTS) == CORE_CONTRACT_COUNT and sum(len(fields) for _, fields in CONTRACTS) == 31
CONTRACTS += [
    ('Center', [('child', 'child', WIDGET_Z, WIDGET_V)]),
    ('Padding', [('child', 'child', WIDGET_Z, WIDGET_V)]),
    ('SizedBox', [('child', 'child', WIDGET_Z, WIDGET_V), ('size', 'size', '.{}', 'vxfw.Size{}')]),
    ('Border', [('child', 'child', WIDGET_Z, WIDGET_V)]),
    ('BorderLabel', [('text', 'text', '"label"', "'label'"), ('alignment', 'alignment', '.top_right', '.top_right')]),
    ('FlexColumn', [('children', 'children', '&.{}', '[]vxfw.FlexItem{}')]),
    ('FlexRow', [('children', 'children', '&.{}', '[]vxfw.FlexItem{}')]),
    ('Button', [('label', 'label', '"button"', "'button'"), ('on_click', 'onClick', 'click', 'click')]),
    ('Text', [('text', 'text', '"text"', "'text'")]),
    ('RichText', [('text', 'text', '&.{}', '[]vxfw.TextSpan{}')]),
    ('TextField', [('buf', 'buf', 'fw.TextField.Buffer.init(std.heap.page_allocator)', 'vaxis.TextInputBuffer.new()')]),
    ('ScrollBars', [('scroll_view', 'scroll_view', '.{.children=.{.slice=&.{}}}', 'vxfw.ScrollView{children:vxfw.ScrollSlice{widgets:[]}}')]),
    ('SplitView', [('lhs', 'lhs', WIDGET_Z, WIDGET_V), ('rhs', 'rhs', WIDGET_Z, WIDGET_V), ('width', 'width', '7', '7')]),
    ('Spinner', []),
    ('ListView', [('children', 'children', '.{.slice=&.{}}', 'vxfw.ListSlice{widgets:[]}')]),
    ('ListBuilder', [('userdata', 'userdata', '@ptrFromInt(1)', 'voidptr(1)'), ('build_fn', 'buildFn', 'build', 'build')]),
    ('ListSlice', [('widgets', 'slice', '&.{}', '[]vxfw.Widget{}')]),
    ('ScrollView', [('children', 'children', '.{.slice=&.{}}', 'vxfw.ScrollSlice{widgets:[]}')]),
    ('ScrollBuilder', [('userdata', 'userdata', '@ptrFromInt(1)', 'voidptr(1)'), ('build_fn', 'buildFn', 'build', 'build')]),
    ('ScrollSlice', [('widgets', 'slice', '&.{}', '[]vxfw.Widget{}')]),
]
SOURCE_TYPES = {'BorderLabel':'fw.Border.BorderLabel', 'ListBuilder':'fw.ListView.Builder',
                'ListSlice':'fw.ListView.Source', 'ScrollBuilder':'fw.ScrollView.Builder', 'ScrollSlice':'fw.ScrollView.Source'}
SOURCE_SLICES = {'ListSlice', 'ScrollSlice'}
PAYLOADS = {'SetMouseShape', 'RequestFocus', 'CopyToClipboard', 'SetTitle', 'QueryColor'}
SOURCE_FIXED = {'EventContext': '.alloc=std.heap.page_allocator,', 'DrawContext': '.arena=std.heap.page_allocator,'}


def constructors(kind, fields, missing):
    selected = [field for field in fields if field[0] != missing]
    translated = 'vxfw.' + kind + '{' + ','.join(v + ':' + expr for v, _, _, expr in selected) + '}'
    values = ','.join('.' + z + '=' + expr for _, z, expr, _ in selected)
    original_type = SOURCE_TYPES.get(kind, 'fw.' + kind)
    original = '.{' + SOURCE_FIXED.get(kind, '') + values + '}'
    if kind in SOURCE_SLICES:
        original = '.{.slice=&.{}}' if missing is None else '.slice'
    elif kind in PAYLOADS:
        original_type = 'fw.Command'
        original = '.{' + values + '}' if missing is None else '.' + fields[0][1]
    elif kind == 'Notification':
        original_type = 'fw.Command'
        original = '.{.notify=.{' + values + '}}'
    return original_type, original, translated


def ordinary_rejection(result, marker):
    diagnostic = result.stdout + result.stderr
    return (result.returncode > 0 and b'error:' in diagnostic and marker.encode() in diagnostic
            and not any(text in diagnostic.lower() for text in
                        (b'panic:', b'compiler bug', b'segmentation fault', b'c error found')))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('zig', type=Path)
    parser.add_argument('v', type=Path)
    parser.add_argument('--target', default='aarch64-macos.14.0')
    parser.add_argument('--uucode', type=Path, default=Path.home() / '.cache/zig/p' / UUCODE_PACKAGE)
    parser.add_argument('--v-prod', action='store_true')
    parser.add_argument('--zig-mode', choices=('Debug', 'ReleaseSafe'))
    args = parser.parse_args()
    source = args.source.resolve() / 'src'
    if tree_hash(source) != VAXIS_SHA256:
        parser.error('vaxis source differs from the recorded locked source')
    env = dict(os.environ, VEXE=str(args.v.resolve()), V_C_ERROR_BUG_REPORT_DISABLED='1')
    mode = args.zig_mode or ('ReleaseSafe' if args.v_prod else 'Debug')
    with tempfile.TemporaryDirectory(prefix='witty-vxfw-constructors-') as directory:
        root = Path(directory)
        shutil.copytree(source, root / 'src')
        graph = prepare_uucode(args.zig.resolve(), root, args.uucode.resolve(), args.target)
        path = str(PROBE.parents[2]) + '|@vlib|@vmodules'
        options = ['-enable-globals'] + (['-prod'] if args.v_prod else [])

        def commands(zpath, vpath, emit=False):
            return [
                [str(args.zig.resolve()), 'build-exe', '-O', mode, '-target', args.target, '-lc',
                 *module('root', zpath, ['vaxis']), *module('vaxis', root / 'src/main.zig', ['uucode']),
                 *graph, f'-femit-bin={root / "native"}' if emit else '-fno-emit-bin'],
                [str(args.v.resolve()), *options, '-path', path,
                 *(['-o', str(root / 'translated')] if emit else ['-check']), str(vpath)],
            ]

        # Build and run actual consumers, including all optional defaults.
        for language, command in zip(('source', 'V'), commands(PROBE / 'reference.zig', PROBE / 'main.v', True)):
            print('Building '+language+' default consumer ('+mode+')', file=sys.stderr, flush=True)
            result = subprocess.run(command, env=env, capture_output=True, timeout=300)
            if result.returncode:
                raise AssertionError(language + ' default consumer failed: ' + (result.stdout + result.stderr).decode(errors='replace'))
        results = [subprocess.run([str(root / name)], env=env, capture_output=True, timeout=15) for name in ('native', 'translated')]
        if any(result.returncode or result.stderr for result in results) or results[0].stdout != results[1].stdout:
            raise AssertionError('default consumers differ: ' + repr([(r.returncode, r.stdout, r.stderr) for r in results]))

        omissions = 0
        for kind, fields in CONTRACTS:
            print('Checking '+kind, file=sys.stderr, flush=True)
            for missing in [None] + [field[0] for field in fields]:
                ztype, zvalue, vvalue = constructors(kind, fields, missing)
                zpath, vpath = root / 'contract.zig', root / 'contract.v'
                zpath.write_text('const std=@import("std");const vaxis=@import("vaxis");const fw=vaxis.vxfw;'
                    'fn draw(_: *anyopaque,_:fw.DrawContext) std.mem.Allocator.Error!fw.Surface{return fw.Surface.empty(' + WIDGET_Z + ');}'
                    'fn click(_: ?*anyopaque,_:*fw.EventContext) anyerror!void {}'
                    'fn build(_: *const anyopaque,_:usize,_:usize) ?fw.Widget {return null;}'
                    'pub fn main() void {const value:' + ztype + '=' + zvalue + ';_ = value;}\n')
                vpath.write_text('module main\nimport vaxis\nimport vaxis.vxfw\n'
                    'fn draw(_ voidptr,_ vxfw.DrawContext) !vxfw.Surface {return vxfw.Surface.empty(' + WIDGET_V + ')}\n'
                    'fn click(_ voidptr,mut ctx vxfw.EventContext) ! {_ = ctx}\n'
                    'fn build(_ voidptr,_ usize,_ usize) ?vxfw.Widget {return none}\n'
                    'fn main(){value:=' + vvalue + ' println(sizeof(value))}\n')
                for language, command in zip(('source', 'V'), commands(zpath, vpath)):
                    result = subprocess.run(command, env=env, capture_output=True, timeout=120)
                    if missing is None:
                        good = result.returncode == 0
                    else:
                        zfield = next(z for v, z, _, _ in fields if v == missing)
                        marker = zfield if kind in PAYLOADS or kind in SOURCE_SLICES else 'missing struct field: ' + zfield
                        if language == 'V': marker = 'vaxis.vxfw.' + kind + '.' + missing
                        good = ordinary_rejection(result, marker)
                    if not good:
                        raise AssertionError(f'{kind}.{missing or "complete"}: {language} constructor mismatch: ' + (result.stdout + result.stderr).decode(errors='replace'))
                omissions += missing is not None
        print(f'Framework constructors ({mode}, V {"production" if args.v_prod else "ordinary"}): '
              f'{len(CONTRACTS)} complete pairs, {omissions} paired omission rejections; '
              f'default consumer {results[0].stdout.decode().strip()}')


if __name__ == '__main__':
    main()
