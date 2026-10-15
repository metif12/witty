"""Compare numeric format records, optional fields, copies and conversion contracts."""
import argparse
from collections import Counter
import hashlib
import itertools
import json
import os
from pathlib import Path
import random
import re
import shutil

from verify_jpeg_contracts_reference import implementation_hashes
from verify_tiff_decode_reference import ProofLog, tree_hash, work_directory, PINNED_SOURCE_SHA256
from verify_stream_guards_reference import stdlib_hash, PINNED_STDLIB_SHA256
from verify_simd_reference import ordinary_rejection

FORMAT_LIBRARY_SHA256 = '667eac6285e472b5516ebebf8a6e69959a171be4fb97cac1e56419ffec20d500'
IO_LIBRARY_SHA256 = '09df1114cba703f824337f20489c7df5294db9f07961d4ac46abbbbf9c7ecaef'
NUMERIC_LIBRARIES = {
    'math.zig': '65645001357d5f78cbf646485e009a048b828680bb1b47fb3de0fd8617d91af1',
    'meta.zig': '3cf9b3eb6c6b6f9b101f06f0562a4071c81a5fbc6de63d8197e837e10cedfc40',
}
EXPECTED_ROWS = 25480
EXPECTED_SHA256 = 'cce7031efc0a921872f0c3c3d655676ecdaee0d02e878b02451ba770c08c83e1'
MAX_USIZE = (1 << 64) - 1


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def corpus():
    rows = []
    options = ((None, None), (0, 0), (1, MAX_USIZE), (MAX_USIZE, 1),
               (MAX_USIZE, None), (None, MAX_USIZE), (1 << 63, MAX_USIZE - 1), (63, 255))

    def add(group, values):
        row = '|'.join('-' if v is None else str(v) for v in values)
        rows.append((group, f'{group}-{len(rows)}', row))

    for form, operation, field, mode, case, index in itertools.product(
            range(5), range(7), range(6), range(5), range(2), range(len(options))):
        precision, width = options[index]
        seed = (0, 1, 2, 3, 4, 255, 256, MAX_USIZE - 1)[index]
        # seed+1 is used only in operation 4; no fixture arithmetic overflow.
        add(f'form-{form}-operation-{operation}',
            (form, operation, field, mode, case, precision, width, index % 3,
             (field * 37 + index * 43) & 255, seed))
    for mode, case, alignment, fill in itertools.product(range(5), range(2), range(3), range(256)):
        add('every-fill', (3, 6, fill % 6, mode, case, None if fill % 2 else 0,
                           MAX_USIZE if fill % 2 else None, alignment, fill, fill))
    rng = random.Random(0xd7b7ab0b)
    for _ in range(1000):
        add('random-optional-values', (rng.randrange(5), rng.randrange(7), rng.randrange(6),
            rng.randrange(5), rng.randrange(2), rng.choice((None, rng.getrandbits(64))),
            rng.choice((None, rng.getrandbits(64))), rng.randrange(3), rng.randrange(256),
            rng.randrange(MAX_USIZE)))
    return rows


def modeled(row):
    values = [None if v == '-' else int(v) for v in row.split('|')]
    form, operation, field, mode, case, precision, width, alignment, fill, seed = values
    args = [precision, width, alignment, fill]
    default = [0, 0, None, None, 2, 32]
    original = default[:]
    if form in (1, 2, 3):
        original[:2] = [mode, case]
    if form in (2, 3):
        original[2:] = args
    if form == 4:
        original[2:4] = args[:2]
    copy, returned = original[:], original[:]

    def number(n):
        return ','.join('-' if v is None else str(v) for v in n + [(10, 2, 8, 16, None)[n[0]]]) + ';'

    def options(o):
        return ','.join('-' if v is None else str(v) for v in o) + ';'

    def changed(n, f, s):
        result = n[:]
        result[f] = (s % 5, s % 2, None if s % 3 == 0 else s,
                     None if s % 4 == 0 else MAX_USIZE - s, s % 3, s & 255)[f]
        return result

    def changed_options(o):
        result = o[:]
        f = field % 4
        result[f] = (None if seed % 3 == 0 else seed,
                     None if seed % 4 == 0 else MAX_USIZE - seed, seed % 3, seed & 255)[f]
        return result

    initial = number(original) + options(args)
    if operation == 1:
        copy = changed(copy, field, seed)
    elif operation == 2:
        original = changed(original, field, seed)
    elif operation == 3:
        args = changed_options(args)
    elif operation == 4:
        copy = changed(copy, field, seed)
        returned = changed(copy, (field + 1) % 6, seed + 1)
    elif operation == 5:
        original = default[:]
    elif operation == 6:
        args = changed_options(args)
        original = [seed % 5, seed % 2, *args]
    return (initial + number(original) + number(copy) + number(returned) + options(args)).encode()


def compiler_controls(proof, root, zbase, vbase, env, timeout):
    consumers = {}
    outcomes = []

    def pair(label, zbody, vbody, accepted=False, markers=()):
        zfile, vfile = root / (label + '.zig'), root / (label + '.v')
        zfile.write_text('const std=@import("std");const Number=std.fmt.Number;const Options=std.fmt.Options;'
            'const Mode=Number.Mode;const Case=std.fmt.Case;fn needByte(x:u8) void{_=x;}'
            'pub fn main() !void {' + zbody + '}\n')
        vfile.write_text('module main\nimport zigimg as p\ntype Mode=p.NumberMode\ntype Case=p.FormatCase\n'
            'type Options=p.FormatOptions\nfn need_byte(x u8) {}\nfn main(){\n' + vbody + '\n}\n')
        for file in (zfile, vfile):
            consumers[file.name] = digest(file)
        for language, command in (
                ('source', zbase + ['-femit-bin=' + str(root / (label + '-source')), str(zfile)]),
                ('v', vbase + ['-o', str(root / (label + '-v')), str(vfile)])):
            result = proof.run(command, label + '-' + language, env=env, timeout=timeout, check=False)
            if accepted:
                if result.returncode or re.search(rb'\berror:', result.stderr + result.stdout):
                    raise AssertionError(label + '/' + language + ': expected acceptance')
                run = proof.run([str(root / (label + '-' + language))], label + '-' + language + '-run',
                                env=env, timeout=timeout)
                if run.stdout != b'ok\n' or run.stderr:
                    raise AssertionError(label + '/' + language + ': consumer output differs')
            else:
                ordinary_rejection(result, label + '/' + language)
                marker = markers[language == 'v'] if markers else 'error:'
                if marker.encode() not in result.stdout + result.stderr:
                    raise AssertionError(label + '/' + language + ': missing diagnostic ' + marker)
            outcomes.append(dict(label=label, language=language, outcome='accepted' if accepted else 'rejected'))

    pair('defaults-and-bases',
         'const n=Number{};std.debug.assert(n.mode==.decimal and n.case==.lower and n.precision==null and n.width==null and n.alignment==.right and n.fill==32);'
         'inline for(.{Mode.decimal,Mode.binary,Mode.octal,Mode.hex},.{10,2,8,16}) |m,b| std.debug.assert(m.base().?==b);'
         'std.debug.assert(Mode.scientific.base()==null);var out=std.fs.File.stdout().writer(&.{});try out.interface.writeAll("ok\\n");',
         'n:=p.NumberFormat{}\nassert n.mode==.decimal && n.letter_case==.lower && n.precision==none && n.width==none && n.alignment==.right && n.fill==32\n'
         'for i,m in [p.NumberMode.decimal,.binary,.octal,.hex] { assert m.base()?==[u8(10),2,8,16][i] }\n'
         'assert p.NumberMode.scientific.base()==none\nprintln("ok")', accepted=True)
    pair('aliases-conversion-and-mutation',
         'var o:Options=.{.precision=0,.width=std.math.maxInt(usize),.alignment=.left,.fill=255};'
         'const m:Mode=.hex;const c:Case=.upper;var n=o.toNumber(m,c);var copy=n;'
         'o.precision=null;o.width=0;o.alignment=.right;o.fill=0;'
         'n.mode=.binary;n.case=.lower;n.precision=null;n.width=1;n.alignment=.center;n.fill=1;'
         'std.debug.assert(copy.mode==.hex and copy.case==.upper and copy.precision.?==0 and copy.width.?==std.math.maxInt(usize) and copy.alignment==.left and copy.fill==255);'
         'copy.precision=std.math.maxInt(usize);copy.width=null;std.debug.assert(n.precision==null and n.width.?==1 and o.width.?==0);'
         'var out=std.fs.File.stdout().writer(&.{});try out.interface.writeAll("ok\\n");',
         'mut o:=Options{precision:usize(0),width:~usize(0),alignment:.left,fill:u8(255)}\nm:=Mode.hex\nc:=Case.upper\n'
         'mut n:=o.to_number(m,c)\nmut copy:=n\no.precision=none\no.width=usize(0)\no.alignment=.right\no.fill=0\n'
         'n.mode=.binary\nn.letter_case=.lower\nn.precision=none\nn.width=usize(1)\nn.alignment=.center\nn.fill=1\n'
         'assert copy.mode==.hex && copy.letter_case==.upper && copy.precision?==usize(0) && copy.width?==~usize(0) && copy.alignment==.left && copy.fill==255\n'
         'copy.precision=~usize(0)\ncopy.width=none\nassert n.precision==none && n.width?==usize(1) && o.width?==usize(0)\nprintln("ok")', accepted=True)
    fields = ('mode', 'case', 'precision', 'width', 'alignment', 'fill')
    vfields = ('mode', 'letter_case', 'precision', 'width', 'alignment', 'fill')
    zvalues = ('.hex', '.upper', '0', '0', '.left', '0')
    vvalues = ('.hex', '.upper', 'usize(0)', 'usize(0)', '.left', '0')
    for field, vfield, zvalue, vvalue in zip(fields, vfields, zvalues, vvalues):
        for converted in (False, True):
            label = ('immutable-converted-' if converted else 'immutable-direct-') + field
            zinit = '(Options{}).toNumber(.hex,.upper)' if converted else 'Number{}'
            vinit = 'p.FormatOptions{}.to_number(.hex,.upper)' if converted else 'p.NumberFormat{}'
            pair(label, 'const n=' + zinit + ';n.' + field + '=' + zvalue + ';',
                 'n:=' + vinit + '\nn.' + vfield + '=' + vvalue,
                 markers=('cannot assign to constant', 'immutable'))
    invalid = (
        ('mode-type', 'const n=Number{.mode=Case.upper};_=n;', 'n:=p.NumberFormat{mode:p.FormatCase.upper}\n_=n'),
        ('case-type', 'const n=Number{.case=Mode.hex};_=n;', 'n:=p.NumberFormat{letter_case:p.NumberMode.hex}\n_=n'),
        ('precision-type', 'const n=Number{.precision=true};_=n;', 'n:=p.NumberFormat{precision:true}\n_=n'),
        ('width-type', 'const n=Number{.width=true};_=n;', 'n:=p.NumberFormat{width:true}\n_=n'),
        ('alignment-type', 'const n=Number{.alignment=Mode.hex};_=n;', 'n:=p.NumberFormat{alignment:p.NumberMode.hex}\n_=n'),
        ('fill-type', 'const n=Number{.fill=true};_=n;', 'n:=p.NumberFormat{fill:true}\n_=n'),
        ('conversion-mode-type', 'const n=(Options{}).toNumber(Case.upper,.lower);_=n;', 'n:=p.FormatOptions{}.to_number(p.FormatCase.upper,.lower)\n_=n'),
        ('conversion-case-type', 'const n=(Options{}).toNumber(.hex,Mode.hex);_=n;', 'n:=p.FormatOptions{}.to_number(.hex,p.NumberMode.hex)\n_=n'),
        ('base-optional', 'needByte(Mode.hex.base());', 'need_byte(p.NumberMode.hex.base())'),
        ('unknown-mode', 'const n=Number{.mode=.invalid};_=n;', 'n:=p.NumberFormat{mode:.invalid}\n_=n'),
        ('unknown-case', 'const n=Number{.case=.invalid};_=n;', 'n:=p.NumberFormat{letter_case:.invalid}\n_=n'),
    )
    for label, zbody, vbody in invalid:
        pair(label, zbody, vbody)
    (root / 'consumer_sha256.json').write_text(json.dumps(consumers, indent=2) + '\n')
    (root / 'compiler_outcomes.json').write_text(json.dumps(outcomes, indent=2) + '\n')
    return consumers, outcomes


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('zig', type=Path)
    parser.add_argument('v', type=Path)
    parser.add_argument('--target', default='aarch64-macos.14.0')
    parser.add_argument('--v-prod', action='store_true')
    parser.add_argument('--workdir', type=Path)
    parser.add_argument('--timeout', type=int, default=180)
    parser.add_argument('--preflight', action='store_true', help='sample corpus and check compiler consumers without golden enforcement')
    args = parser.parse_args()
    if args.timeout <= 0:
        parser.error('--timeout must be positive')
    source, zig, v = args.source.resolve() / 'src', args.zig.resolve(), args.v.resolve()
    repo = Path(__file__).resolve().parent.parent
    probe = repo / 'zigimg/reference_probes/format_number'
    libraries = {'fmt.zig': FORMAT_LIBRARY_SHA256, 'Io.zig': IO_LIBRARY_SHA256, **NUMERIC_LIBRARIES}

    def check_pins():
        if tree_hash(source) != PINNED_SOURCE_SHA256 or stdlib_hash(zig) != PINNED_STDLIB_SHA256:
            raise AssertionError('Source or selected library changed')
        for name, pin in libraries.items():
            if digest(zig.parent / 'lib/std' / name) != pin:
                raise AssertionError(name + ' changed')

    check_pins()
    mode = 'production' if args.v_prod else 'ordinary'
    native_mode = 'ReleaseSafe' if args.v_prod else 'Debug'
    with work_directory(args.workdir, 'witty-format-number-') as root:
        proof = ProofLog(root)
        tmp = root / 'tmp'; tmp.mkdir()
        env = dict(os.environ, VEXE=str(v), V_C_ERROR_BUG_REPORT_DISABLED='1', TMPDIR=str(tmp), VTMP=str(tmp))
        shutil.copytree(source, root / 'src')
        fixtures = {}
        for name in ('main.v', 'reference.zig'):
            shutil.copyfile(probe / name, root / name)
            fixtures[name] = digest(probe / name)
        implementations, runner_hash = implementation_hashes(repo), digest(Path(__file__))
        versions = [proof.run([str(exe), 'version'], label, env=env).stdout.decode().strip()
                    for exe, label in ((zig, 'zig-version'), (v, 'v-version'))]
        if versions[0] != '0.15.2' or not re.match(r'^V 0\.5\.2(?: |$)', versions[1]):
            raise AssertionError('compiler versions differ')
        helpers = {name: digest(repo / 'zigimg' / name) for name in (
            'verify_jpeg_contracts_reference.py', 'verify_tiff_decode_reference.py',
            'verify_stream_guards_reference.py', 'verify_simd_reference.py')}
        (root / 'provenance.json').write_text(json.dumps(dict(source_sha256=PINNED_SOURCE_SHA256,
            stdlib_sha256=PINNED_STDLIB_SHA256, libraries=libraries, versions=versions, target=args.target,
            v_prod=args.v_prod, zig_mode=native_mode, preflight=args.preflight, fixtures=fixtures,
            implementation_sha256=implementations, runner_sha256=runner_hash, helpers=helpers), indent=2) + '\n')
        zbase = [str(zig), 'build-exe', '-target', args.target, '-lc', '-O', native_mode,
                 '--global-cache-dir', str(root / 'zig-global'), '--cache-dir', str(root / 'zig-cache')]
        vbase = [str(v), *(['-prod'] if args.v_prod else []), '-path', f'{repo}|@vlib|@vmodules']
        print(f'Building numeric format records: Source {native_mode}, V {mode}', flush=True)
        proof.run(zbase + ['-femit-bin=' + str(root / 'native'), str(root / 'reference.zig')], 'build-source', env=env, timeout=args.timeout)
        proof.run(vbase + ['-o', str(root / 'translated'), str(root / 'main.v')], 'build-v', env=env, timeout=args.timeout)
        rows = corpus()
        if args.preflight:
            groups = sorted({group for group, _, _ in rows})
            rows = [row for group in groups for row in [x for x in rows if x[0] == group][::max(1, sum(x[0] == group for x in rows) // 4 - 1)]]
        path = root / 'corpus.txt'
        path.write_text('\n'.join(row for _, _, row in rows) + '\n')
        inputs = {path.name: digest(path)}
        outputs = []
        for exe in ('native', 'translated'):
            result = proof.run([str(root / exe), str(path)], 'corpus-' + exe, env=env, timeout=args.timeout)
            if result.stderr:
                raise AssertionError(exe + ': unexpected stderr')
            outputs.append(result.stdout.splitlines())
        if any(len(output) != len(rows) for output in outputs):
            raise AssertionError('record count differs')
        h, groups = hashlib.sha256(), Counter()
        for (group, name, row), native, translated in zip(rows, *outputs):
            if native != translated or native != modeled(row):
                raise AssertionError(name + ': record differs from native or model; input ' + row)
            h.update(name.encode() + b'\0' + native + b'\n')
            groups[group] += 1
        print(f'{len(rows)} numeric format records, SHA256 {h.hexdigest()}', flush=True)
        consumers, outcomes = compiler_controls(proof, root, zbase, vbase, env, args.timeout)
        (root / 'input_sha256.json').write_text(json.dumps(inputs, indent=2) + '\n')
        check_pins()
        if (tree_hash(root / 'src') != PINNED_SOURCE_SHA256 or implementation_hashes(repo) != implementations
                or digest(Path(__file__)) != runner_hash):
            raise AssertionError('Source copy, implementation or runner changed')
        for name, pin in fixtures.items():
            if digest(probe / name) != pin or digest(root / name) != pin:
                raise AssertionError('fixture changed')
        for name, pin in {**inputs, **consumers}.items():
            if digest(root / name) != pin:
                raise AssertionError('input or consumer changed')
        for name, pin in helpers.items():
            if digest(repo / 'zigimg' / name) != pin:
                raise AssertionError('helper changed')
        summary = dict(returning_records=len(rows), return_groups=dict(groups), sha256=h.hexdigest(),
            accepted_consumer_pairs=2, rejected_consumer_pairs=23, compiler_outcomes=outcomes)
        (root / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
        print(json.dumps(summary, indent=2), flush=True)
        if not args.preflight and (len(rows) != EXPECTED_ROWS or h.hexdigest() != EXPECTED_SHA256):
            raise AssertionError('locked numeric format golden differs')


if __name__ == '__main__':
    main()
