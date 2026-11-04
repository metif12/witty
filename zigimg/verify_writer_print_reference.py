"""Compare record Writer.print composition with pinned Zig and a writer-state model."""
import argparse
from collections import Counter
import hashlib
import itertools
import json
import os
from pathlib import Path
import re
import shutil

from verify_format_parser_reference import pins
from verify_format_placeholder_reference import modeled as placeholder_model
from verify_jpeg_contracts_reference import implementation_hashes
from verify_simd_reference import ordinary_rejection
from verify_tiff_decode_reference import ProofLog, tree_hash, work_directory, PINNED_SOURCE_SHA256, checked_trap

EXPECTED_ROWS = 13286
EXPECTED_SHA256 = 'f86f839c327b16f29cc9091df3681b55c759a0144fa465fd0855d13b88c19b99'
EXPECTED_TRAPS = 9
EXPECTED_RETURN_CONTROLS = 9
EXPECTED_STATE_SHA256 = '5b006bdbfb3d3141308759bfe429b504dcc46e46de6311a7c5b84eac377987b2'
EXPECTED_COMPILER_PAIRS = 26
MAX = (1 << 64) - 1
TEMPLATES = {
    'literal': [b'', b'abc', b'{{', b'}}', b'{{}}', b'{{{{}}}}', b'a{{b}}c{{d}}', b'a\0{{\xff}}z'],
    'pair': [b'{d}:{s}', b'{1s}:{d}:{1s}:{s}', b'{[text]s}{{{[value]d}}}',
             b'{0d}/{0x}/{1s}', b'{1s}{0b}', b'a{{b}}{d}c{{d}}{s}e', b'{d:0>8}{s:.<8}'],
    'sized': [b'{[value]d:0>[width].[precision]}:{[text]s}',
              b'{d:^[width].[precision]}|{s}',
              b'{[text]s:_<[width].[precision]}{{{[value]d}}}',
              b'{[value]x:.[precision]}{[text]s:->[width]}',
              b'{0d:[width]}{1s:.[precision]}{0d}{1s}'],
    'custom': [b'A{{B}}{[value]f:>[width].[precision]}:{[text]s}!',
               b'{0f:0>[width].[precision]}{1s}{0f}',
               b'{1s}{{{0f:.[precision]}}}{1s:[width]}'],
}


def spec(family, fmt, kind=0, cap=32, start=0, prefix=0, binding=0, finish=1,
         value=-17, text=b'hi\0\xff', width=9, precision=None, stop=0):
    return '|'.join(map(str, (family, fmt.hex(), kind, cap, start, prefix, binding,
                              finish, value, text.hex(), width,
                              '-' if precision is None else precision, stop)))


class WriteFailed(Exception):
    pass


def modeled(line):
    f = line.split('|')
    family = int(f[0]); fmt = bytes.fromhex(f[1])
    kind, cap, start, prefix, binding, finish, value = map(int, f[2:9])
    text = bytes.fromhex(f[9]); width = int(f[10]); precision = None if f[11] == '-' else int(f[11]); stop = int(f[12])
    end = (start if not kind and start < cap else 0) + prefix
    pos = start if kind else 0; mode = kind; calls = 0
    buffer = bytearray((i * 17 + 165) & 255 for i in range(cap))
    buffer[end-prefix:end] = bytes((i * 31 + 7) & 255 for i in range(prefix))
    contents = bytearray((i * 37 + 19) & 255 for i in range(32)) if kind and not binding else bytearray()
    wire = bytearray()

    def state(status):
        return '|'.join((status, f'{pos+end}:{cap-end}:{end}:{end}:{int(bool(kind) and binding != 2)}',
                         buffer.hex(), buffer[:end].hex(), buffer[end:].hex(), str(calls), contents.hex()))

    def prepare():
        nonlocal mode, pos
        if mode < 0 or binding == 2: raise WriteFailed()
        if binding == 1 and mode == 1:
            mode = 2
            if pos: pos = 0; mode = -1; raise WriteFailed()
            return False
        return True

    def output(data):
        nonlocal pos
        assert pos + len(data) <= 4096
        if binding == 1: wire.extend(data)
        else:
            if len(contents) < pos + len(data): contents.extend(bytes(pos+len(data)-len(contents)))
            contents[pos:pos+len(data)] = data
        pos += len(data)

    def copy(data):
        nonlocal end
        buffer[end:end+len(data)] = data; end += len(data)

    def write_all(data):
        nonlocal end
        index = 0
        while index < len(data):
            left = data[index:]
            if len(left) <= cap-end: copy(left); return
            if not kind: copy(left[:cap-end]); raise WriteFailed()
            if not prepare(): continue
            pending = bytes(buffer[:end])
            emitted = (pending if pending else left) if kind == 1 and not binding else pending + left
            output(emitted); n = len(emitted)
            if n < end: buffer[:end-n] = buffer[n:end]; end -= n
            else: index += n-end; end = 0

    def splat(n, fill):
        nonlocal end
        pattern = bytes([fill])
        while n:
            if n <= cap-end: copy(pattern*n); return
            if not kind: copy(pattern*(cap-end)); raise WriteFailed()
            segments = [bytes(buffer[:end])] if end else []
            if n == 1: segments.append(pattern)
            else:
                capacity = max(64, cap-end); k = min(n, capacity); scratch = pattern*k
                if cap-end >= 64: buffer[end:end+k] = scratch
                segments.append(scratch); remaining = n-k
                while remaining > capacity and len(segments) < 16: segments.append(scratch); remaining -= capacity
                if remaining and len(segments) < 16: segments.append(pattern*remaining)
            if not prepare(): continue
            emitted = segments[0] if kind == 1 and not binding else b''.join(segments)
            output(emitted); count = len(emitted)
            if count < end: buffer[:end-count] = buffer[count:end]; end -= count
            else: n -= count-end; end = 0

    def aligned(data, w, alignment, fill):
        padding = max(0, (len(data) if w is None else w) - len(data))
        if alignment == 0: write_all(data); splat(padding, fill)
        elif alignment == 1: splat(padding//2, fill); write_all(data); splat((padding+1)//2, fill)
        else: splat(padding, fill); write_all(data)

    names = ('value', 'text', 'width', 'precision')[:(0, 2, 4, 4)[family]]
    values = (value, text, width, precision); next_arg = 0; used = set()

    def resolve(s):
        kind, v = s
        return None if kind == '-' else v if kind == 'n' else names.index(v.decode())

    def size(s):
        if s[0] != 's': return s[1]
        index = resolve(s); used.add(index); return values[index]

    def emit(index, fmt, fill, alignment, w, p):
        nonlocal calls
        if family == 3 and index == 0:
            assert fmt == b'f'
            calls += 1
            if stop == 1: raise WriteFailed()
            write_all(b'<')
            if stop == 2: raise WriteFailed()
            write_all(str(value).encode()); write_all(b'>'); return
        if index == 1: assert fmt == b's'; data = text
        else:
            v = values[index]; assert v is not None
            digits = format(abs(v), {b'd': 'd', b'x': 'x', b'b': 'b'}[fmt])
            data = (('-' if v < 0 else '+' if w else '') + digits).encode() if index == 0 else digits.encode()
        aligned(data, w, alignment, fill)

    def composition():
        nonlocal next_arg
        literal = bytearray(); i = 0
        while True:
            while i < len(fmt) and fmt[i] not in b'{}': literal.append(fmt[i]); i += 1
            if i+1 < len(fmt) and fmt[i] == fmt[i+1]: literal.append(fmt[i]); i += 2; continue
            if literal: write_all(literal); literal.clear()
            if i == len(fmt): break
            assert fmt[i] == 123
            closing = fmt.index(b'}', i+1)
            parsed, error = placeholder_model(fmt[i+1:closing]); assert error is None
            specifier, fill, alignment, arg, ws, ps = parsed
            w, p = size(ws), size(ps); index = resolve(arg)
            if index is None: index = next_arg; next_arg += 1
            used.add(index); emit(index, specifier, fill, alignment, w, p); i = closing+1
        assert len(used) == len(names)

    states = [state('ready')]; status = 'ok'
    try: composition()
    except WriteFailed: status = 'WriteFailed'
    states.append(state(status))
    if cap: buffer[0] ^= 0x5a
    states.append(state('caller')); status = 'skip'
    if finish:
        status = 'ok'
        if kind and end:
            try:
                if not prepare(): assert prepare()
                output(bytes(buffer[:end])); end = 0
            except WriteFailed: status = 'WriteFailed'
    states.append(state(status))
    return ('~'.join(states) + '~' + ('-1:'+wire.hex() if kind and binding == 1 else '-3:')).encode()


def corpus():
    rows = []; seen = set()
    def add(group, line):
        if line not in seen: seen.add(line); rows.append((group, line))
    for family, formats in enumerate(TEMPLATES.values()):
        for fmt, cap, value, precision in itertools.product(formats, range(41), (-17, 0, 42), (None, 0, 3)):
            add('every-capacity', spec(family, fmt, cap=cap, value=value, precision=precision))
        for fmt, kind, cap, start in itertools.product(formats, range(3), (0, 1, 8, 65), (0, 3)):
            begin = start if not kind and start < cap else 0
            for prefix, binding, finish in itertools.product(sorted({0, cap-begin}), (0,) if kind == 0 else (0, 1, 2), (0, 1)):
                add('writer-state', spec(family, fmt, kind=kind, cap=cap, start=start, prefix=prefix, binding=binding, finish=finish, width=80))
    for fmt, stop, cap in itertools.product(TEMPLATES['custom'], (1, 2), range(41)):
        add('formatter-failure', spec(3, fmt, stop=stop, cap=cap, width=MAX, precision=MAX))
    for family in (1, 2, 3):
        for fmt, text in itertools.product(list(TEMPLATES.values())[family], (b'', b'{}', bytes(range(256)))):
            add('binary-and-empty', spec(family, fmt, cap=400, text=text, width=0, value=-(1 << 63)))
    return rows


def source_templates():
    return '\n'.join('pub const '+name+' = [_][]const u8{'+','.join('&.{'+','.join(map(str, fmt))+'}' for fmt in formats)+'};' for name, formats in TEMPLATES.items())+'\n'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def compiler_cases():
    """Each invalid static Source call has an explicit V runtime boundary."""
    cases = []

    def accepted(name, zbody, vbody, output):
        cases.append((name, zbody, vbody, output, output))

    def invalid(name, fmt, zargs, vargs, message, prefix=''):
        vbody = (f"w.print('{fmt}', {vargs}) or {{\n"
                 f"verify_control(err.msg() == {message!r})\n"
                 f"verify_control(w.buffered().bytestr() == {prefix!r})\n"
                 "if w.buffered().len == 0 { verify_control(backing == before) }\n"
                 "print('rejected')\nreturn\n}\npanic('unexpected success')")
        cases.append((name, f'try w.print("{fmt}", {zargs});', vbody, None, b'rejected'))

    accepted('record-alias-and-optional-sizes',
             'try w.print("{d:_>[width].[precision]}", Sized{.value=7,.width=5,.precision=null});',
             "w.print('{d:_>[width].[precision]}', SizedAlias(Sized{7, Width(5), none}))!", b'___+7')
    accepted('present-optional-size',
             'try w.print("{d:_>[width].[precision]}", Sized{.value=-7,.width=5,.precision=2});',
             "w.print('{d:_>[width].[precision]}', Sized{-7, Width(5), ?usize(2)})!", b'___-7')
    accepted('optional-width-and-reused-size',
             'try w.print("{[value]d:[width]}|{[width]?d}", .{.value=@as(i32,7),.width=@as(?usize,null)});',
             "w.print('{[value]d:[width]}|{[width]?d}', OptionalWidth{7, none})!", b'7|null')
    accepted('optional-u64-width',
             'try w.print("{d:_>[width]}", .{.value=@as(i32,-7),.width=@as(?u64,5)});',
             "w.print('{d:_>[width]}', OptionalU64Size{-7, ?u64(5)})!", b'___-7')
    accepted('mixed-carriers-and-depth',
             'try w.print("{any}|{}|{?d}|{any}", .{[_]u8{1,255},error.PrintError,@as(?i32,-7),@as([]const []const []const []const i32,&.{&.{&.{&.{1}}}})});',
             "w.print('{any}|{}|{?d}|{any}', Mixed{[u8(1),255]!, PrintError{}, ?int(-7), [[[[1]]]]})!",
             b'{ 1, 255 }|error.PrintError|-7|{ { { { ... } } } }')
    accepted('scalar-pointer',
             'var value:u8=7;try w.print("{*}", .{&value});std.debug.assert(std.mem.startsWith(u8,w.buffered(),"u8@"));w.end=0;',
             "mut value:=u8(7)\nw.print('{*}', Pointer{&value})!\nverify_control(w.buffered().bytestr().starts_with('u8@'))\nw.seek_to(0)!", b'')
    for count in (32, 33):
        fmt = '{d}' * count
        zargs = '.{' + ','.join('@as(u8,1)' for _ in range(count)) + '}'
        vargs = 'Many{' + ','.join('1' for _ in range(count)) + '}'
        if count == 32:
            accepted('32-arguments', f'try w.print("{fmt}",{zargs});',
                     f"w.print('{fmt}', {vargs})!", b'1' * 32)
        else:
            invalid('33-arguments', fmt, zargs, vargs, '32 arguments max are supported per format call')
    for name, fmt, zargs, vargs, message in (
        ('missing-opening', 'before}', '.{}', 'Empty{}', 'missing opening {'),
        ('missing-closing', 'before{', '.{}', 'Empty{}', 'missing closing }'),
        ('too-few', 'before{d}', '.{}', 'Empty{}', 'too few arguments'),
        ('out-of-range', 'before{2d}', '.{@as(u8,7)}', 'One{7}', 'too few arguments'),
        ('unused', 'before', '.{@as(u8,7)}', 'One{7}', 'unused arguments'),
        ('unknown-argument', 'before{[missing]d}', '.{@as(u8,7)}', 'One{7}', "no argument with name 'missing'"),
        ('unknown-width', 'before{d:[missing]}', '.{@as(u8,7)}', 'One{7}', "no argument with name 'missing'"),
        ('unknown-precision', 'before{d:.[missing]}', '.{@as(u8,7)}', 'One{7}', "no argument with name 'missing'"),
        ('signed-width', 'before{d:[width]}', 'SignedSize{.value=7,.width=5}', 'SignedSize{7,5}',
         'named format size requires an unsigned integer or usize-sized optional unsigned integer'),
        ('absent-signed-width', 'before{d:[width]}', '.{.value=@as(i32,7),.width=@as(?i32,null)}', 'OptionalSignedSize{7,none}',
         'named format size requires an unsigned integer or usize-sized optional unsigned integer'),
        ('absent-narrow-width', 'before{d:[width]}', '.{.value=@as(i32,7),.width=@as(?u8,null)}', 'OptionalNarrowSize{7,none}',
         'named format size requires an unsigned integer or usize-sized optional unsigned integer'),
        ('present-narrow-width', 'before{d:[width]}', '.{.value=@as(i32,7),.width=@as(?u8,5)}', 'OptionalNarrowSize{7,?u8(5)}',
         'named format size requires an unsigned integer or usize-sized optional unsigned integer'),
        ('boolean-precision', 'before{d:.[precision]}', '.{.value=@as(i32,7),.precision=true}', 'BoolSize{7,true}',
         'named format size requires an unsigned integer or usize-sized optional unsigned integer'),
        ('invalid-placeholder', 'before{d:bad}', '.{@as(u8,7)}', 'One{7}', "expected . or }, found 'b'"),
    ):
        invalid(name, fmt, zargs, vargs, message)
    invalid('unsupported-value-format', 'before{z}', '.{@as(u8,7)}', 'One{7}',
            'unsupported print_value integer format', 'before')
    cases.append(('non-record', 'try w.print("literal", @as(u8,7));',
                  "w.print('literal', 7) or {verify_control(err.msg()=='expected struct argument')\nverify_control(backing==before)\nprint('rejected')\nreturn}\npanic('unexpected success')",
                  None, b'rejected'))
    cases.append(('runtime-format', 'const args=try std.process.argsAlloc(std.heap.page_allocator);try w.print(args[0],.{});',
                  "format:=if os.args.len>0 {'runtime{{ok}}'} else {''}\nw.print(format, Empty{})!", None, b'runtime{ok}'))
    cases.append(('format-type', 'try w.print(true,.{});', "w.print(true, Empty{})!", None, None))
    return cases


def compiler_texts(name, zbody, vbody):
    count = 33 if name == '33-arguments' else 32
    tail = '' if vbody.endswith("panic('unexpected success')") else '\nprint(w.buffered().bytestr())'
    ztext = ('const std=@import("std");const Sized=struct{value:i32,width:u16,precision:?usize};'
             'const SignedSize=struct{value:i32,width:i32};'
             'pub fn main() !void {var backing:[256]u8=undefined;var w:std.Io.Writer=.fixed(&backing);'
             '_=&w;' + zbody + 'var out=std.fs.File.stdout().writer(&.{});try out.interface.writeAll(w.buffered());}\n')
    vtext = '''module main
import os
import zigimg as p
fn verify_control(ok bool) {
 if !ok { panic('control assertion failed') }
}
type Width = u16
struct Sized {
 value int
 width Width
 precision ?usize
}
type SizedAlias = Sized
struct Empty {}
struct One { value int }
struct SignedSize {
 value int
 width int
}
struct OptionalSignedSize {
 value int
 width ?int
}
struct OptionalNarrowSize {
 value int
 width ?u8
}
struct BoolSize {
 value int
 precision bool
}
struct OptionalWidth {
 value int
 width ?usize
}
struct OptionalU64Size {
 value int
 width ?u64
}
struct PrintError {}
pub fn (e PrintError) msg() string { return 'PrintError' }
pub fn (e PrintError) code() int { return 47 }
struct Mixed {
 bytes [2]u8
 value IError
 optional ?int
 nested [][][][]int
}
struct Pointer { value &u8 }
struct Many {
''' + '\n'.join(f' f{i} u8' for i in range(count)) + '''
}
fn run() ! {
 mut backing:=[]u8{len:256,init:0xa5}
 before:=backing.clone()
 _=before
 mut w:=p.WriteStream.init_memory(mut backing)
 _=w
''' + vbody + tail + "\n}\nfn main() { run() or { panic(err) } }\n"
    return ztext, vtext


def compiler_controls(proof, root, repo, zig, v, args, env):
    outcomes = {}; inputs = {}
    for name, zbody, vbody, zout, vout in compiler_cases():
        ztext, vtext = compiler_texts(name, zbody, vbody)
        outcomes[name] = {}
        for lang, extension, code, expected in (('native', '.zig', ztext, zout), ('translated', '.v', vtext, vout)):
            path = root / (name + extension); path.write_text(code); inputs[path.name] = sha(path)
            binary = root / (name + '-' + lang)
            command = ([str(zig), 'build-exe', '-target', args.target, '-lc', '-O', 'ReleaseSafe' if args.v_prod else 'Debug',
                        '--global-cache-dir', str(root.parent/'zig-global'), '--cache-dir', str(root/'zig-cache'),
                        '-femit-bin='+str(binary), str(path)] if lang == 'native' else
                       [str(v), '-enable-globals', *(['-prod'] if args.v_prod else []), '-path', f'{repo}|@vlib|@vmodules',
                        '-o', str(binary), str(path)])
            result = proof.run(command, name+'-'+lang+'-compile', env=env, timeout=args.timeout, check=False)
            if expected is None:
                ordinary_rejection(result, name+'-'+lang)
                outcomes[name][lang] = 'reject'
            else:
                assert result.returncode == 0, (name, lang, result.stdout, result.stderr)
                result = proof.run([str(binary)], name+'-'+lang+'-run', env=env, timeout=args.timeout)
                assert result.stdout == expected and not result.stderr, (name, lang, result.stdout, result.stderr, expected)
                outcomes[name][lang] = 'return:'+expected.hex()
    assert all(sha(root/path) == pin for path, pin in inputs.items()), 'compiler inputs changed'
    (root/'compiler-inputs.json').write_text(json.dumps(inputs, indent=2)+'\n')
    return outcomes


def trap_controls(proof, root, repo, zig, v, args, env):
    proof.run([str(zig), 'build-exe', '-target', args.target, '-lc', '-O', 'ReleaseSafe' if args.v_prod else 'Debug',
               '--global-cache-dir', str(root.parent/'zig-global'), '--cache-dir', str(root/'zig-cache'),
               '-femit-bin='+str(root/'trap-native'), str(root/'trap.zig')], 'trap-build-source', env=env, timeout=args.timeout)
    proof.run([str(v), '-enable-globals', *(['-prod'] if args.v_prod else []), '-path', f'{repo}|@vlib|@vmodules',
               '-o', str(root/'trap-translated'), str(root/'trap.v')], 'trap-build-v', env=env, timeout=args.timeout)
    records = []; traps = 0; returns = 0
    for case, capacity in itertools.product(range(3), (0, 3, 5, 6, 7, 64)):
        end = min(capacity, 6); backing = b'before'[:end] + b'\xa5' * (capacity-end)
        expected = f'{end}|{backing.hex()}|{backing[:end].hex()}|{backing[end:].hex()}'.encode()
        for lang in ('native', 'translated'):
            label = f'trap-{case}-{capacity}-{lang}'; path = root/(label+'.state')
            result = proof.run([str(root/('trap-'+lang)), str(path), str(capacity), str(case)], label,
                               env=env, timeout=args.timeout, check=False)
            if capacity >= 6:
                category = 'reached unreachable code'
                checked_trap(result, label, category)
                messages = [m.group(1) for line in result.stderr.decode().splitlines()
                            if (m := re.fullmatch(r'(?:thread \d+ |V )?panic:\s*(.*)', line.strip()))]
                assert messages == [category], (label, messages)
            else:
                assert result.returncode == 0 and result.stdout == b'WriteFailed\n' and not result.stderr, label
            assert path.read_bytes() == expected, (label, path.read_bytes(), expected)
        traps += capacity >= 6; returns += capacity < 6
        records.append(f'{case}:{capacity}:'.encode()+expected)
    return dict(paired_traps=traps, returning_controls=returns,
                state_sha256=hashlib.sha256(b'\n'.join(records)).hexdigest())


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path); parser.add_argument('zig', type=Path); parser.add_argument('v', type=Path)
    parser.add_argument('--target', default='aarch64-macos.14.0'); parser.add_argument('--v-prod', action='store_true')
    parser.add_argument('--workdir', type=Path); parser.add_argument('--timeout', type=int, default=600)
    args = parser.parse_args()
    if args.timeout <= 0: parser.error('--timeout must be positive')
    source = args.source.resolve()/'src'; zig = args.zig.resolve(); v = args.v.resolve()
    pins(source, zig)
    repo = Path(__file__).resolve().parent.parent; probe = repo/'zigimg/reference_probes/writer_print'
    with work_directory(args.workdir, 'witty-writer-print-') as root:
        tmp = root/'tmp'; tmp.mkdir(); env = dict(os.environ, TMPDIR=str(tmp), VTMP=str(tmp), VEXE=str(v), V_C_ERROR_BUG_REPORT_DISABLED='1')
        proof = ProofLog(root); shutil.copytree(source, root/'src')
        files = ('main.v', 'reference.zig', 'fixture_shims.h', 'fixture_shims.c', 'trap.v', 'trap.zig', 'portable.v')
        for name in files: shutil.copyfile(probe/name, root/name)
        shared = repo/'zigimg/reference_probes/writer_seek/fixture_shims.h'
        (root/'writer_seek').mkdir(); shutil.copyfile(shared, root/'writer_seek/fixture_shims.h')
        (root/'templates.zig').write_text(source_templates())
        versions = [proof.run([str(exe), 'version'], label, env=env).stdout.decode().strip() for exe, label in ((zig, 'zig-version'), (v, 'v-version'))]
        assert versions[0] == '0.15.2' and re.match(r'^V 0\.5\.2(?: |$)', versions[1])
        impl = implementation_hashes(repo)
        helpers = ('verify_format_parser_reference.py', 'verify_format_placeholder_reference.py', 'verify_jpeg_contracts_reference.py', 'verify_tiff_decode_reference.py', 'verify_stream_guards_reference.py', 'verify_image_open_reference.py', 'verify_image_tty_reference.py', 'verify_simd_reference.py', 'verify_png_foundation_reference.py')
        retained = {str(p.relative_to(repo)): sha(p) for p in [Path(__file__), shared, *(probe/n for n in files), *(repo/'zigimg'/n for n in helpers)]}
        compiler_hashes = {str(exe): sha(exe) for exe in (zig, v)}
        provenance = dict(source_sha256=PINNED_SOURCE_SHA256, implementation_sha256=impl, files=retained, versions=versions, compiler_sha256=compiler_hashes, target=args.target, v_prod=args.v_prod, templates_sha256=sha(root/'templates.zig'))
        (root/'provenance.json').write_text(json.dumps(provenance, indent=2)+'\n')
        mode = 'ReleaseSafe' if args.v_prod else 'Debug'
        proof.run([str(zig), 'build-exe', '-target', args.target, '-lc', '-I', str(root), '-O', mode, '--global-cache-dir', str(root.parent/'zig-global'), '--cache-dir', str(root/'zig-cache'), '-femit-bin='+str(root/'native'), str(root/'reference.zig'), str(root/'fixture_shims.c')], 'build-source', env=env, timeout=args.timeout)
        proof.run([str(v), '-enable-globals', *(['-prod'] if args.v_prod else []), '-path', f'{repo}|@vlib|@vmodules', '-o', str(root/'translated'), str(root/'main.v')], 'build-v', env=env, timeout=args.timeout)
        rows = corpus(); path = root/'corpus.txt'; path.write_text('\n'.join(line for _, line in rows)+'\n')
        outputs = []
        for exe in ('native', 'translated'):
            result = proof.run([str(root/exe), str(path)], 'returning-'+exe, env=env, timeout=args.timeout)
            assert not result.stderr and len(result.stdout.splitlines()) == len(rows), 'invalid returning output'
            outputs.append(result.stdout.splitlines())
        for i, ((group, data), native, translated) in enumerate(zip(rows, *outputs)):
            assert native == translated, f'{i}/{group}: native/V print state differs'
            assert native == modeled(data), f'{i}/{group}: independent print/write model differs'
        digest = hashlib.sha256(b'\n'.join(outputs[0])).hexdigest()
        assert len(rows) == EXPECTED_ROWS and digest == EXPECTED_SHA256, 'returning golden changed'
        print(f'{mode}: {len(rows)} modeled print records match', flush=True)
        outcomes = compiler_controls(proof, root, repo, zig, v, args, env)
        assert len(outcomes) == EXPECTED_COMPILER_PAIRS
        traps = trap_controls(proof, root, repo, zig, v, args, env)
        assert traps == dict(paired_traps=EXPECTED_TRAPS, returning_controls=EXPECTED_RETURN_CONTROLS, state_sha256=EXPECTED_STATE_SHA256)
        assert tree_hash(source) == tree_hash(root/'src') == PINNED_SOURCE_SHA256
        pins(source, zig)
        assert implementation_hashes(repo) == impl and all(sha(repo/p) == pin for p, pin in retained.items()), 'implementation/proof changed'
        assert all(sha(Path(exe)) == pin for exe, pin in compiler_hashes.items()), 'compiler changed'
        assert all(sha(root/n) == retained[str((probe/n).relative_to(repo))] for n in files) and sha(root/'writer_seek/fixture_shims.h') == sha(shared)
        assert (root/'templates.zig').read_text() == source_templates() and not list(root.glob('*.owned*'))
        (root/'input_sha256.json').write_text(json.dumps({'corpus.txt': sha(path)}, indent=2)+'\n')
        summary = dict(returning_records=len(rows), output_sha256=digest, write_failed=sum(b'~WriteFailed|' in line for line in outputs[0]), groups=dict(Counter(group for group, _ in rows)), compiler_outcomes=outcomes, trap_controls=traps, zig_mode=mode, v_prod=args.v_prod)
        (root/'summary.json').write_text(json.dumps(summary, indent=2)+'\n'); print(json.dumps(summary), flush=True)


if __name__ == '__main__':
    main()
