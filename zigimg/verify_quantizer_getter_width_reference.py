"""Compare RGB quantizer getter widths, invocation order and failure state."""
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
from verify_tga_decode_reference import stdlib_hash, PINNED_STDLIB_SHA256
from verify_tiff_decode_reference import ProofLog, tree_hash, work_directory, PINNED_SOURCE_SHA256, checked_trap
from verify_simd_reference import ordinary_rejection

EXPECTED_RETURNS = 15012
EXPECTED_TRAPS = 864
EXPECTED_RETURN_SHA256 = 'a42d9d71684d4e710d460a54f48c1fd93de9452e830855e65a2081939e4807fd'
EXPECTED_STATE_SHA256 = '23c05fb50943d60a7dbf64fcff1ac189ed1811815ab5549cd08fdb5fbbc3a068'
CAST = 'integer does not fit in destination type'
OVERFLOW = 'integer overflow'
MAX = (1 << 32) - 1


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def corpus():
    rows, traps, counters = [], [], Counter()
    def add(group, row, message=None):
        name = f'{group}-{counters[group]}'; counters[group] += 1
        (traps if message else rows).append((group, name, row, message))
    rng = random.Random(20261013)
    seeds = [0, 1, 0x7f7f7f, 0x808080, 0xffffff, 0xff000000, MAX - 1, MAX]
    seeds += [rng.getrandbits(32) for _ in range(16)]
    for kind, seed, mode, count, budget in itertools.product(range(6), seeds, range(3), range(6), (0, 1, 2, 4, 16)):
        add('whole-quantizer', f'{kind}|{seed}|{mode}|{count}|{budget}')
    def node(group, kind, seed, mode, op, level, rgb=(10, 20, 30), ref=1, message=None):
        add(group, '|'.join(map(str, ('N', kind, seed, mode, op, level, *rgb, ref, 17))), message)
    for kind, seed, mode, level, ref in itertools.product(range(6), seeds[:8], range(3), (-2147483648, -1, 0, 1, 7, 8, 9, 2147483647), (0, 1)):
        node('node-lookup', kind, seed, mode, 2, level, ref=ref,
             message=CAST if ref == 0 and (level < 0 or level >= 8) else None)
    for kind, seed, mode, level in itertools.product(range(6), seeds[:8], range(3), (8, 9, 2147483647)):
        node('node-leaf-add', kind, seed, mode, 1, level)
    for kind, mode, level in itertools.product(range(6), range(3), (-2147483648, -1)):
        node('add-invalid-level', kind, 0x12345678, mode, 1, level, message=CAST)
    for kind, mode, channel, level in itertools.product(range(6), range(3), range(4), (8, 9)):
        rgb = [10, 20, 30]; ref = 1
        if channel < 3:
            rgb[channel] = MAX
        else:
            ref = MAX
        node('leaf-mutation-order', kind, 0x010203, mode, 1, level, rgb=rgb, ref=ref, message=OVERFLOW if channel == 3 or channel >= 2 - (kind % 3) else None)
    return rows, traps


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('source', 'zig', 'v'):
        parser.add_argument(name, type=Path)
    parser.add_argument('--target', default='aarch64-macos.14.0')
    parser.add_argument('--v-prod', action='store_true')
    parser.add_argument('--workdir', type=Path)
    parser.add_argument('--timeout', type=int, default=600)
    args = parser.parse_args()
    if args.timeout <= 0:
        parser.error('--timeout must be positive')
    source, zig, v = args.source.resolve() / 'src', args.zig.resolve(), args.v.resolve()
    if tree_hash(source) != PINNED_SOURCE_SHA256 or stdlib_hash(zig) != PINNED_STDLIB_SHA256:
        parser.error('Source or library differs from pins')
    repo = Path(__file__).resolve().parent.parent
    probe = repo / 'zigimg/reference_probes/quantizer_getter_width'
    mode = 'ReleaseSafe' if args.v_prod else 'Debug'
    with work_directory(args.workdir, 'witty-quantizer-getter-width-') as root:
        proof = ProofLog(root)
        tmp = root / 'tmp'; tmp.mkdir()
        env = dict(os.environ, VEXE=str(v), V_C_ERROR_BUG_REPORT_DISABLED='1', TMPDIR=str(tmp), VTMP=str(tmp))
        shutil.copytree(source, root / 'src')
        fixtures = {}
        for name in ('main.v', 'reference.zig'):
            shutil.copyfile(probe / name, root / name); fixtures[name] = digest(probe / name)
        versions = [proof.run([str(exe), 'version'], label, env=env).stdout.decode().strip()
                    for exe, label in ((zig, 'zig-version'), (v, 'v-version'))]
        if versions[0] != '0.15.2' or not re.match(r'^V 0\.5\.2(?: |$)', versions[1]):
            raise AssertionError('compiler version changed')
        implementations, runner_hash = implementation_hashes(repo), digest(Path(__file__))
        helpers = {name: digest(repo / "zigimg" / name) for name in
                   ("verify_jpeg_contracts_reference.py", "verify_tga_decode_reference.py",
                    "verify_tiff_decode_reference.py", "verify_simd_reference.py")}
        provenance = dict(source_sha256=PINNED_SOURCE_SHA256, stdlib_sha256=PINNED_STDLIB_SHA256,
                          versions=versions, target=args.target, zig_mode=mode, v_prod=args.v_prod,
                          fixtures=fixtures, implementation_sha256=implementations, runner_sha256=runner_hash,
                          helper_sha256=helpers)
        (root / 'provenance.json').write_text(json.dumps(provenance, indent=2) + '\n')
        zbase = [str(zig), 'build-exe', '-target', args.target, '-lc', '-O', mode,
                 '--global-cache-dir', str(root / 'zig-global'), '--cache-dir', str(root / 'zig-cache')]
        vbase = [str(v), '-enable-globals', *(['-prod'] if args.v_prod else []), '-path', f'{repo}|@vlib|@vmodules']
        print(f'Building getter widths: Source {mode}, V production={args.v_prod}', flush=True)
        proof.run(zbase + ['-femit-bin=' + str(root / 'native'), str(root / 'reference.zig')], 'build-source', env=env, timeout=args.timeout)
        proof.run(vbase + ['-o', str(root / 'translated'), str(root / 'main.v')], 'build-v', env=env, timeout=args.timeout)
        rows, traps = corpus(); path = root / 'corpus.txt'
        path.write_text('\n'.join(row for _, _, row, _ in rows) + '\n')
        inputs = {path.name: digest(path)}; outputs = []
        for exe in ('native', 'translated'):
            result = proof.run([str(root / exe), str(path)], 'corpus-' + exe, env=env, timeout=args.timeout, check=False)
            if result.returncode or result.stderr:
                raise AssertionError('corpus failed; see retained diagnostics')
            outputs.append(result.stdout.splitlines())
        if any(len(output) != len(rows) for output in outputs):
            raise AssertionError('corpus counts differ')
        returns, states = hashlib.sha256(), hashlib.sha256()
        for (_, name, row, _), a, b in zip(rows, *outputs):
            if a != b:
                raise AssertionError(f'{name}: differing output; input {row}\n{a!r}\n{b!r}')
            returns.update(name.encode() + b'\0' + a + b'\n')
        print(f'{len(rows)} returns match, SHA256 {returns.hexdigest()}; checking {len(traps)} failures', flush=True)
        for _, name, row, message in traps:
            path = root / (name + '.txt'); path.write_text(row); inputs[path.name] = digest(path)
            records = []
            for exe in ('native', 'translated'):
                state = root / (name + '-' + exe + '.state')
                result = proof.run([str(root / exe), '--case', str(state), row], name + '-' + exe,
                                   env=env, timeout=args.timeout, check=False)
                checked_trap(result, name + '/' + exe, message)
                messages = [m.group(1) for line in result.stderr.decode().splitlines()
                            if (m := re.fullmatch(r'(?:thread \d+ |V )?panic:\s*(.*)', line.strip()))]
                if messages != [message] or not state.exists():
                    raise AssertionError('exact panic or state missing')
                records.append(state.read_bytes())
            if not records[0] or records[0] != records[1]:
                raise AssertionError(f'{name}: differing retained state {records}')
            states.update(name.encode() + b'\0' + message.encode() + b'\0' + records[0] + b'\n')
        consumers = {}
        def pair(label, zdecl, vdecl, zcall, vcall, zmarker=None, vmarker=None, execute=False):
            paths = (root / (label + '.zig'), root / (label + '.v'))
            paths[0].write_text('const std=@import("std");const p=@import("src/OctTreeQuantizer.zig");const c=@import("src/color.zig");' + zdecl + 'pub fn main() void {var q=p{.area_allocator=std.heap.ArenaAllocator.init(std.heap.page_allocator)};q.root_node.init(0,&q);const value=Color{};' + zcall + '}\n')
            paths[1].write_text('module main\nimport zigimg as p\n' + vdecl + '\nfn main(){mut q:=p.OctTreeQuantizer{}\nq.root_node.init(0,mut q)\nvalue:=Color{}\n' + vcall + '\n}\n')
            for path in paths:
                consumers[path.name] = digest(path)
            for language, command, marker in (
                    ('Source', zbase + (['-femit-bin=' + str(root / (label + '-S'))] if execute else ['-fno-emit-bin']) + [str(paths[0])], zmarker),
                    ('V', vbase + ([] if execute else ['-check']) + ['-o', str(root / (label + '-V')), str(paths[1])], vmarker)):
                result = proof.run(command, label + '-' + language, env=env, timeout=args.timeout, check=False)
                errors = [line for line in (result.stdout + result.stderr).decode(errors='replace').splitlines()
                          if re.search(r'\berror:', line)]
                if marker is None:
                    if result.returncode or errors:
                        raise AssertionError(label + '/' + language + ': expected acceptance; see diagnostics')
                else:
                    ordinary_rejection(result, label + '/' + language)
                    if not any(marker in line for line in errors):
                        raise AssertionError(label + '/' + language + ': expected diagnostic missing')
                if execute:
                    binary = root / (label + ('-S' if language == 'Source' else '-V'))
                    executed = proof.run([str(binary)], label + '-' + language + '-run', env=env, timeout=args.timeout)
                    if executed.stdout or executed.stderr:
                        raise AssertionError('unexpected private-alpha consumer output')
        calls = (
            ('q-add', 'q.addColor(value) catch {};', 'q.add_color(value) or {}'),
            ('q-lookup', '_=q.getPaletteIndex(value) catch 0;', '_=q.get_palette_index(value) or {usize(0)}'),
            ('node-add', 'q.root_node.addColor(value,8,&q) catch {};', 'q.root_node.add_color(value,8,mut q) or {}'),
            ('node-lookup', '_=q.root_node.getPaletteIndex(value,0) catch 0;', '_=q.root_node.get_palette_index(value,0) or {usize(0)}'))
        for alias,width in itertools.product((False,True),('u8','u16','u32')):
            zdecl='const Getter=struct{pub fn u32Rgb(_: @This()) '+width+'{return 7;}};const Base=struct{to:Getter=.{}};const Color=Base;'
            vdecl='struct Base {}\npub fn (value Base) to_u32_rgb() '+width+' {return 7}\ntype Color=Base'
            if not alias:
                vdecl=vdecl.replace('Base','Color').replace('\ntype Color=Color','')
            for name,zcall,vcall in calls:
                pair(f'accepted-{int(alias)}-{width}-{name}',zdecl,vdecl,zcall,vcall)
        for width in ('i8','i16','i32','i64','u64','bool','f32'):
            result='true' if width=='bool' else '7'
            zdecl='const Getter=struct{pub fn u32Rgb(_: @This()) '+width+'{return '+result+';}};const Color=struct{to:Getter=.{}};'
            vdecl='struct Color {}\npub fn (value Color) to_u32_rgb() '+width+' {return '+result+'}'
            for name,zcall,vcall in calls:
                pair(f'invalid-{width}-{name}',zdecl,vdecl,zcall,vcall,"expected type 'u32'",'has no field named `a`')
        for width in ('u8','u16','u32'):
            zdecl='const Word='+width+';const Getter=struct{pub fn u32Rgb(_: @This()) Word{return 7;}};const Color=struct{to:Getter=.{}};'
            vdecl='type Word='+width+'\nstruct Color {}\npub fn (value Color) to_u32_rgb() Word {return Word(7)}'
            for name,zcall,vcall in calls:
                pair(f'result-alias-{width}-{name}',zdecl,vdecl,zcall,vcall,None,'has no field named `a`')
        for width in ('u8','u16'):
            zdecl='const Getter=struct{pub fn u32Rgb(_: @This()) '+width+'{@panic("RGB getter must not run");}pub fn premultipliedAlpha(_: @This()) c.Rgba32{return c.Rgba32.from.rgba(1,2,3,4);}};const Color=struct{a:bool=true,to:Getter=.{}};'
            vdecl='struct Color {a bool}\npub fn (value Color) to_u32_rgb() '+width+' {panic("RGB getter must not run")}\npub fn (value Color) premultiplied_alpha() p.Rgba32 {return p.Rgba32.rgba(1,2,3,4)}'
            for name,zcall,vcall in calls:
                pair(f'private-alpha-{width}-{name}',zdecl,vdecl,zcall,vcall,execute=True)
        (root / 'input_sha256.json').write_text(json.dumps(inputs, indent=2) + '\n')
        (root / 'consumer_sha256.json').write_text(json.dumps(consumers, indent=2) + '\n')
        for name, expected in {**inputs, **consumers}.items():
            if digest(root / name) != expected:
                raise AssertionError('input or consumer changed')
        if (tree_hash(source) != PINNED_SOURCE_SHA256 or tree_hash(root / 'src') != PINNED_SOURCE_SHA256
                or stdlib_hash(zig) != PINNED_STDLIB_SHA256 or implementation_hashes(repo) != implementations
                or digest(Path(__file__)) != runner_hash):
            raise AssertionError('Source, dependency, implementation or runner changed')
        for name, expected in fixtures.items():
            if any(digest(path) != expected for path in (root / name, probe / name)):
                raise AssertionError('fixture changed')
        for name, expected in helpers.items():
            if digest(repo / 'zigimg' / name) != expected:
                raise AssertionError('proof helper changed')
        summary = dict(returning_records=len(rows), return_groups=dict(Counter(g for g, _, _, _ in rows)),
                       return_sha256=returns.hexdigest(), paired_traps=len(traps),
                       failure_groups=dict(Counter(g for g, _, _, _ in traps)),
                       panic_categories=dict(Counter(m for _, _, _, m in traps)), state_sha256=states.hexdigest(),
                       accepted_operation_pairs=24, invalid_width_pairs=28, result_alias_boundaries=12, private_alpha_acceptance_pairs=8, private_alpha_runtime_pairs=8)
        (root / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
        print(json.dumps(summary, indent=2), flush=True)
        if (len(rows) != EXPECTED_RETURNS or len(traps) != EXPECTED_TRAPS
                or returns.hexdigest() != EXPECTED_RETURN_SHA256 or states.hexdigest() != EXPECTED_STATE_SHA256):
            raise AssertionError('locked getter width golden changed')


if __name__ == '__main__':
    main()
