#!/usr/bin/env python3
"""Run original Zig factories and compile/run V factory output."""
import pathlib, shutil, subprocess, sys, tempfile, os, json
reference = pathlib.Path(sys.argv[1]); zig = sys.argv[2]; v = sys.argv[3]
repo = pathlib.Path(__file__).resolve().parents[2]
with tempfile.TemporaryDirectory(prefix='witty-abi-reference-') as directory:
    root = pathlib.Path(directory); (root/'lib').mkdir()
    for name in ('enum.zig','struct.zig','union.zig','target.zig'):
        shutil.copyfile(reference/'src'/'lib'/name, root/'lib'/name)
    shutil.copyfile(pathlib.Path(__file__).with_name('main.zig'),root/'main.zig')
    subprocess.run([zig,'run',str(root/'main.zig'),'-target','aarch64-macos.14.0','-lc'],check=True)
    env=dict(os.environ,VEXE=v)
    command=[v,'-path',str(repo)+'|@vlib|@vmodules']
    subprocess.run(command+['run',str(repo/'tools/lib_abi_generate'),str(pathlib.Path(__file__).with_name('schema.json')),str(root/'generated')],env=env,check=True)
    subprocess.run(command+['run',str(root/'generated')],env=env,check=True)

    # The source compiler itself rejects these reflected extern layouts.
    invalid_zig = {
        'tuple': ('const S = @import("lib/struct.zig").Struct(.c, struct { u8, u64 });', 'extern tuples are not supported'),
        'comptime': ('const S = @import("lib/struct.zig").Struct(.c, struct { comptime n: u8 = 9 });', 'extern struct fields cannot be marked comptime'),
        'padding': ('const Tag = enum(c_int) { a }; const S = @import("lib/union.zig").TaggedUnion(.c, union(Tag) { a: u64 }, u32).CValue;', 'TaggedUnion CValue size does not match expected fixed size'),
    }
    for name, (decl, expected) in invalid_zig.items():
        probe = root / ('invalid_' + name + '.zig')
        probe.write_text(decl + '\npub fn main() void { _ = @sizeOf(S); }\n')
        result = subprocess.run([zig, 'build-exe', str(probe), '-target', 'aarch64-macos.14.0', '-lc', '-fno-emit-bin'], capture_output=True, text=True)
        assert result.returncode != 0 and expected in result.stderr, result.stderr
    # The generated types, rather than a metadata-only check, enforce padding.
    schema = json.loads(pathlib.Path(__file__).with_name('schema.json').read_text())
    schema['unions'][0]['padding'] = {'v_type': 'u16', 'c_type': 'uint16_t'}
    invalid_schema = root / 'invalid_padding.json'
    invalid_schema.write_text(json.dumps(schema))
    subprocess.run(command + ['run', str(repo/'tools/lib_abi_generate'), str(invalid_schema), str(root/'invalid_generated')], env=env, check=True)
    result = subprocess.run(command + [str(root/'invalid_generated')], env=env, capture_output=True, text=True)
    assert result.returncode != 0, result.stdout + result.stderr
    result = subprocess.run(['cc', '-std=c11', '-x', 'c', '-fsyntax-only', str(root/'invalid_generated/types.h')], capture_output=True, text=True)
    assert result.returncode != 0 and 'TaggedUnion CValue size does not match expected fixed size' in result.stderr, result.stderr
    print('ABI factories: original and generated compiled fixtures, extern rejection and padding failure passed')
