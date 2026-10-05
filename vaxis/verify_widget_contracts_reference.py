"""Check required widget fields against unchanged Vaxis constructors."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

PROBE = Path(__file__).resolve().parent / 'reference_probes/widgets_classic'
sys.path.insert(0, str(PROBE))
from source_build import VAXIS_SHA256, UUCODE_PACKAGE, module, prepare_uucode, tree_hash

# Original type, V type (vaxis namespace by default), source and V field values.
CONTRACTS = [
    ('vaxis.widgets.Scrollbar', 'Scrollbar', [('total', '0', '0'), ('view_size', '0', '0')]),
    ('vaxis.widgets.View.Config', 'ViewConfig', [('width', '0', '0'), ('height', '0', '0')]),
    ('vaxis.widgets.TextView.Buffer.Style', 'TextViewBufferStyle', [('begin', '0', '0'), ('end', '0', '0'), ('style', '.{}', 'vaxis.Style{}')]),
    ('vaxis.widgets.ScrollView.BoundingBox', 'ScrollViewBoundingBox', [(name, '0', '0') for name in ('x1', 'y1', 'x2', 'y2')]),
    ('@typeInfo(@TypeOf(vaxis.widgets.ScrollView.draw)).@"fn".params[2].type.?', 'ScrollViewContentSize', [('cols', '0', '0'), ('rows', '0', '0')]),
    ('vaxis.widgets.TextView.Buffer.Content', 'TextViewBufferContent', [('bytes', '""', '""')]),
    ('@TypeOf(@as(vaxis.widgets.TextView.Buffer, undefined).grapheme.get(0))', 'TextViewGrapheme', [('len', '0', '0'), ('offset', '0', '0')]),
    ('vaxis.widgets.TextView.BufferWriter', 'TextViewBufferWriter', [('buffer', 'undefined', '&vaxis.TextViewBuffer{}')]),
    ('vaxis.widgets.View', 'View', [('screen', 'undefined', 'vaxis.Screen{}')]),
    ('vaxis.widgets.TextInput', 'TextInput', [('buf', 'vaxis.widgets.TextInput.Buffer.init(@import("std").heap.page_allocator)', 'vaxis.TextInputBuffer.new()')]),
    ('vaxis.widgets.TextInput.Buffer', 'TextInputBuffer', [('buffer', '&.{}', '[]'), ('cursor', '0', '0'), ('gap_size', '0', '0')]),
    ('vaxis.vxfw.TextField', 'vxfw.TextField', [('buf', 'vaxis.vxfw.TextField.Buffer.init(@import("std").heap.page_allocator)', 'vaxis.TextInputBuffer.new()')]),
]

# Source allocators are represented by V's managed storage. Always supply them
# when checking a source constructor, and do not count their omission as parity.
SOURCE_FIXED_FIELDS = {
    'vaxis.widgets.TextView.BufferWriter': [('allocator', '@import("std").heap.page_allocator')],
    'vaxis.widgets.View': [('alloc', '@import("std").heap.page_allocator')],
    'vaxis.widgets.TextInput.Buffer': [('allocator', '@import("std").heap.page_allocator')],
}


def ordinary_rejection(result, marker):
    diagnostics = result.stdout + result.stderr
    return (result.returncode > 0 and b'error:' in diagnostics and marker.encode() in diagnostics
            and not any(item in diagnostics.lower() for item in (b'panic:', b'compiler bug', b'segmentation fault', b'c error found')))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('zig', type=Path)
    parser.add_argument('v', type=Path)
    parser.add_argument('--target', default='aarch64-macos.14.0')
    parser.add_argument('--uucode', type=Path, default=Path.home() / '.cache/zig/p' / UUCODE_PACKAGE)
    args = parser.parse_args()
    source = args.source.resolve() / 'src'
    if tree_hash(source) != VAXIS_SHA256:
        parser.error('vaxis src differs from recorded local source')
    environment = dict(os.environ, VEXE=str(args.v.resolve()), V_C_ERROR_BUG_REPORT_DISABLED='1')
    missing_count = 0
    with tempfile.TemporaryDirectory(prefix='witty-widget-contracts-') as directory:
        root = Path(directory)
        shutil.copytree(source, root / 'src')
        graph = prepare_uucode(args.zig.resolve(), root, args.uucode.resolve(), args.target)
        for original_type, translated_type, fields in CONTRACTS:
            for missing in [None] + [field[0] for field in fields]:
                selected = [field for field in fields if field[0] != missing]
                native_values = SOURCE_FIXED_FIELDS.get(original_type, []) + [(name, value) for name, value, _ in selected]
                native_fields = ', '.join('.' + name + ' = ' + value for name, value in native_values)
                v_fields = ', '.join(name + ': ' + value for name, _, value in selected)
                native_path = root / 'contract.zig'
                native_path.write_text('const vaxis = @import("vaxis");\npub fn main() void { const value: ' + original_type + ' = .{' + native_fields + '}; _ = value; }\n')
                v_path = root / 'contract.v'
                namespace = translated_type.split('.', 1)[0] if '.' in translated_type else 'vaxis'
                imports = 'import vaxis\n' + ('import vaxis.' + namespace + '\n' if namespace != 'vaxis' else '')
                v_type = translated_type if '.' in translated_type else 'vaxis.' + translated_type
                v_path.write_text('module main\n' + imports + 'fn main() { value := ' + v_type + '{' + v_fields + '} println(sizeof(value)) }\n')
                native = [str(args.zig.resolve()), 'build-exe', '-target', args.target, '-lc',
                          *module('root', native_path, ['vaxis']), *module('vaxis', root / 'src/main.zig', ['uucode']), *graph, '-fno-emit-bin']
                commands = [native, [str(args.v.resolve()), '-check', '-path', str(PROBE.parents[2]) + '|@vlib|@vmodules', str(v_path)]]
                for language, command in zip(('source', 'V'), commands):
                    result = subprocess.run(command, env=environment, capture_output=True, timeout=120)
                    if missing is None:
                        if result.returncode:
                            raise AssertionError(f'{translated_type} complete {language} constructor failed: ' + (result.stdout + result.stderr).decode(errors='replace'))
                    elif not ordinary_rejection(result, 'missing struct field: ' + missing if language == 'source' else 'must be initialized'):
                        raise AssertionError(f'{translated_type}.{missing}: {language} did not ordinarily reject omission: ' + (result.stdout + result.stderr).decode(errors='replace'))
                if missing is not None:
                    missing_count += 1
    print(f'Widget contracts: {len(CONTRACTS)} complete constructors, {missing_count} paired required-field rejections')


if __name__ == '__main__':
    main()
