#!/usr/bin/env python3
"""Compare pinned upstream std AutoContext hashes and compile-time rejection rules."""
import argparse
import os
import pathlib
import subprocess
import tempfile

parser = argparse.ArgumentParser()
parser.add_argument('zig')
parser.add_argument('v')
parser.add_argument('repository', type=pathlib.Path)
args = parser.parse_args()
repository = args.repository.resolve()
env = os.environ | {'VEXE': args.v, 'V_C_ERROR_BUG_REPORT_DISABLED': '1'}
v_prefix = [args.v, '-path', f'{repository}|@vlib|@vmodules']
expected = dict(scalar=4378133365921508531, fixed=9630118702735392078,
    present=4378133365921508531, absent=290873116282709081,
    empty=18151106360299273605, tagged=12856782651805138456,
    error=4180067508479897175, success=4378133365921508531,
    failure=4180067508479897175, null_pointer=16624905383039181106,
    padded=13689850338909966510, enum=15579651072214242561,
    bool=15398492003712018733, signed=2743915450954940543, unique=13742470547990004151)
result = subprocess.run([args.zig, 'run', str(pathlib.Path(__file__).with_name('main.zig')),
    '-target', 'aarch64-macos.14.0', '-lc'], capture_output=True, text=True, check=True)
actual = dict((name, int(value)) for name, value in
    (line.split('=') for line in result.stderr.splitlines()))
assert actual == expected, (actual, expected)
print(f'{len(actual)} upstream hash values match the V fixture', flush=True)
subprocess.run(v_prefix + ['-d', 'release_safe', str(repository/'terminal/hash_map_generic_test.v')],
    env=env, check=True)

cases = {
    'float': ('const key:f64=1.0;', 'key := f64(1.0)'),
    'string': ('const key:[]const u8="text";', "key := 'text'"),
    'dynamic_array': ('const key:[]const u32=&.{1,2};', 'key := [u32(1),2]'),
    'nested_slice': ('const Key=struct{bytes:[]const u8};const key=Key{.bytes="text"};',
        "struct Key { bytes string }\nfn main() { key := Key{bytes:'text'}"),
    'inactive_union_slice': ('const Key=union(enum){empty:struct{},bytes:[]const u8};const key:Key=.{.empty=.{}};',
        'struct Empty {}\nstruct Text { bytes string }\ntype Key = Empty | Text\nfn main() { key := Key(Empty{})'),
}
with tempfile.TemporaryDirectory(prefix='witty-auto-hash-rejections-') as directory:
    root = pathlib.Path(directory)
    for name, (zig_body, v_body) in cases.items():
        zig_file = root/(name+'.zig')
        zig_file.write_text('const std=@import("std");pub fn main() void {'+zig_body+
            '_=std.hash_map.AutoContext(@TypeOf(key)).hash(.{},key);}\n')
        native = subprocess.run([args.zig, 'build-exe', str(zig_file), '-fno-emit-bin'],
            capture_output=True, text=True)
        assert native.returncode != 0, f'upstream unexpectedly accepted {name}'
        assert 'unable to hash type' in native.stderr or 'does not allow slices' in native.stderr, native.stderr
        v_file = root/(name+'.v')
        if 'fn main()' not in v_body:
            v_body = 'fn main() {'+v_body
        v_file.write_text('module main\nimport terminal\n'+v_body+
            '\n_ = context_hash(key)\n}\nfn context_hash[T](key T) u64 {return terminal.AutoHashContext[T]{}.hash(key)}\n')
        translated = subprocess.run(v_prefix + ['-check', str(v_file)], env=env,
            capture_output=True, text=True)
        assert translated.returncode != 0, f'V unexpectedly accepted {name}'
        assert 'source std.hash.autoHash rejects slices' in translated.stderr or 'key type is rejected by source' in translated.stderr, translated.stderr
        print(f'{name}: both compilers reject', flush=True)
    # Optional aliases expose a pinned compiler limitation, not a source rule.
    alias_file = root/'optional_alias.v'
    alias_file.write_text('module main\nimport terminal\ntype OptionalKey = ?u32\n'+
        'fn main() {key := OptionalKey(u32(7))\n_ = terminal.AutoHashContext[OptionalKey]{}.hash(key)}\n')
    alias = subprocess.run(v_prefix + ['-check', str(alias_file)], env=env, capture_output=True, text=True)
    assert alias.returncode != 0, 'optional alias boundary changed; remove the documented restriction'
    print('optional alias compiler boundary confirmed; inferred source adapter map passes', flush=True)
