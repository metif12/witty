"""Compare checked PixelStorage slices and live iterators against pinned Source."""
import argparse
from collections import Counter
import hashlib
import json
import os
from pathlib import Path
import re
import shutil

from verify_jpeg_contracts_reference import implementation_hashes
from verify_tga_decode_reference import stdlib_hash, PINNED_STDLIB_SHA256
from verify_tiff_decode_reference import ProofLog, tree_hash, work_directory, PINNED_SOURCE_SHA256, checked_trap
from verify_simd_reference import ordinary_rejection

EXPECTED_ROWS = 18028
EXPECTED_SHA256 = '3fc36e2d20b78dd224bb160ad63b2c89a4c60203be140cab6bdb8d8173690f99'
EXPECTED_STATE_SHA256 = 'e486145175e57fc2962952fea09e5292f443be38d460a45c5b0ccf8475dae528'
TAGS = (0,1,2,4,8,16,0x101,0x102,0x104,0x108,0x110,0x208,0x210,
        0x303,0x305,0x3305,0x308,0x408,0x1305,0x1308,0x1408,0x310,0x410,0x2420)
MAX = 0xffffffffffffffff


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('zig', type=Path)
    parser.add_argument('v', type=Path)
    parser.add_argument('--target', default='aarch64-macos.14.0')
    parser.add_argument('--v-prod', action='store_true')
    parser.add_argument('--workdir', type=Path)
    parser.add_argument('--timeout', type=int, default=180)
    args = parser.parse_args()
    if args.timeout <= 0: parser.error('--timeout must be positive')
    source = args.source.resolve() / 'src'
    zig, v = args.zig.resolve(), args.v.resolve()
    if tree_hash(source) != PINNED_SOURCE_SHA256 or stdlib_hash(zig) != PINNED_STDLIB_SHA256:
        parser.error('Source or selected compiler library differs from the pins')
    mode = 'ReleaseSafe' if args.v_prod else 'Debug'
    repo = Path(__file__).resolve().parent.parent
    probe = repo / 'zigimg/reference_probes/pixel_views'
    env = dict(os.environ, VEXE=str(v), V_C_ERROR_BUG_REPORT_DISABLED='1')
    with work_directory(args.workdir, 'witty-pixel-views-') as root:
        proof = ProofLog(root)
        shutil.copytree(source, root / 'src')
        fixtures = {}
        for name in ('main.v', 'reference.zig'):
            shutil.copyfile(probe / name, root / name)
            fixtures[name] = hashlib.sha256((root / name).read_bytes()).hexdigest()
        versions = [proof.run([str(exe), 'version'], label, env=env).stdout.decode().strip()
                    for exe, label in ((zig, 'zig-version'), (v, 'v-version'))]
        if versions[0] != '0.15.2' or not re.match(r'^V 0\.5\.2(?: |$)', versions[1]):
            raise AssertionError('unexpected compiler versions')
        implementations = implementation_hashes(repo)
        runner_hash = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
        (root / 'provenance.json').write_text(json.dumps(dict(
            source_sha256=PINNED_SOURCE_SHA256, stdlib_sha256=PINNED_STDLIB_SHA256,
            versions=versions, target=args.target, zig_mode=mode, v_prod=args.v_prod,
            fixtures=fixtures, implementation_sha256=implementations, runner_sha256=runner_hash), indent=2) + '\n')
        zbase = [str(zig), 'build-exe', '-target', args.target, '-lc', '-O', mode,
                 '--global-cache-dir', str(root / 'zig-global')]
        vbase = [str(v), '-enable-globals', *(['-prod'] if args.v_prod else []), '-path', f'{repo}|@vlib|@vmodules']
        print(f'Building pixel views: Source {mode}, V {"production" if args.v_prod else "ordinary"}', flush=True)
        proof.run(zbase + ['-femit-bin=' + str(root / 'native'), str(root / 'reference.zig')], 'build-source', timeout=args.timeout)
        proof.run(vbase + ['-o', str(root / 'translated'), str(root / 'main.v')], 'build-v', env=env, timeout=args.timeout)
        outputs = []
        for exe in ('native', 'translated'):
            r = proof.run([str(root / exe)], 'returning-' + exe, timeout=args.timeout)
            if r.stderr: raise AssertionError('unexpected returning stderr')
            outputs.append(r.stdout.splitlines())
        if len(outputs[0]) != len(outputs[1]): raise AssertionError(f'row counts differ: {[len(x) for x in outputs]}')
        for index, (native, translated) in enumerate(zip(*outputs)):
            if native != translated: raise AssertionError(f'{index}: Source={native!r}, V={translated!r}')
        if len(outputs[0]) != EXPECTED_ROWS: raise AssertionError(f'expected {EXPECTED_ROWS}, got {len(outputs[0])}')
        digest = hashlib.sha256(b'\n'.join(outputs[0])).hexdigest()
        if digest != EXPECTED_SHA256: raise AssertionError('returning golden changed')
        counts = Counter(row[:1].decode() for row in outputs[0])
        print(f'{EXPECTED_ROWS} returning rows match; checking failure state', flush=True)
        states = hashlib.sha256()
        traps = Counter()

        def trap(group, name, arguments, category):
            observed = []
            for exe in ('native', 'translated'):
                path = root / (name + '-' + exe + '.state')
                r = proof.run([str(root / exe), arguments[0], str(path), *map(str, arguments[1:])],
                              name + '-' + exe, timeout=args.timeout, check=False)
                checked_trap(r, name + '/' + exe, category)
                if not path.exists(): raise AssertionError('missing panic observer')
                observed.append(path.read_bytes())
            if not observed[0] or observed[0] != observed[1]: raise AssertionError(f'{name}: differing states {observed}')
            states.update(name.encode() + b'\0' + observed[0] + b'\n')
            traps[group] += 1

        for tag in TAGS[1:]:
            for count in (0,1,4):
                bounds = ((0,count+1),(count+1,count+1),(1,0),(count+1,count),
                          (MAX,MAX),(MAX,0),(0,MAX),(MAX,MAX-1),(0x100000000,0x100000001))
                for begin, end in bounds:
                    category = (f'start index {begin} is larger than end index {end}' if begin > end
                                else f'index out of bounds: index {end}, len {count}')
                    trap('slice', f'slice-{tag}-{count}-{begin}-{end}', ['--slice',tag,count,begin,end], category)
                for index in (count,count+7,0x80000000,0x100000000,MAX-1):
                    trap('iterator-data', f'iterator-{tag}-{count}-{index}', ['--next',tag,count,index,index+1],
                         f'index out of bounds: index {index}, len {count}')
            for index in (1,3):
                trap('live-replacement', f'replacement-{tag}-{index}', ['--replace',tag,4,index,4],
                     f'index out of bounds: index {index}, len 1')
        for bits in (1,2,4,8,16):
            length=min(1<<bits,16)
            for size in (0,1):
                for index in (0,1,3):
                    palette_index=(index+1)%length
                    if palette_index < size: continue
                    trap('iterator-palette', f'palette-{bits}-{size}-{index}', ['--palette',bits,4,index,4,size],
                         f'index out of bounds: index {palette_index}, len {size}')
        state_digest = states.hexdigest()
        if state_digest != EXPECTED_STATE_SHA256: raise AssertionError('failure-state golden changed')

        def pair(label, zbody, vbody, zmarker=None, vmarker=None):
            zp, vp = root / (label + '.zig'), root / (label + '.v')
            zp.write_text('const p=@import("src/color.zig");pub fn main() void {' + zbody + '}\n')
            vp.write_text('module main\nimport zigimg as p\nfn main(){\n' + vbody + '\n}\n')
            for language, command, marker in (
                    ('Source', zbase + ['-fno-emit-bin', str(zp)], zmarker),
                    ('V', vbase + ['-check', str(vp)], vmarker)):
                r = proof.run(command, label + '-' + language, env=env, timeout=args.timeout, check=False)
                diagnostic = (r.stdout + r.stderr).decode(errors='replace')
                errors = [line for line in diagnostic.splitlines() if re.search(r'\berror:', line)]
                if marker is None:
                    if r.returncode or errors: raise AssertionError(f'{label}/{language}: expected acceptance\n{diagnostic}')
                else:
                    ordinary_rejection(r, label + '/' + language)
                    if not any(marker in line for line in errors): raise AssertionError(f'{label}/{language}: missing actual error {marker!r}\n{diagnostic}')
        pair('default-iterator', 'var x:p.PixelStorageIterator=.{};_=x.next();', 'mut x:=p.PixelStorageIterator{}\n_=x.next()')
        pair('readonly-init', 'const pixels:p.PixelStorage=.invalid;var x=p.PixelStorageIterator.init(&pixels);_=x.next();',
             'pixels:=p.PixelStorage(p.InvalidPixels{})\nmut x:=p.PixelStorageIterator.init(&pixels)\n_=x.next()')
        pair('readonly-next', 'const x:p.PixelStorageIterator=.{};_=x.next();', 'x:=p.PixelStorageIterator{}\n_=x.next()', 'expected type', 'immutable')
        for field, zvalue, vvalue in (('pixels','undefined','unsafe {nil}'),('current_index','1','1'),('end','1','1')):
            pair('readonly-field-'+field, 'const x:p.PixelStorageIterator=.{};x.'+field+'='+zvalue+';',
                 'x:=p.PixelStorageIterator{}\nx.'+field+'='+vvalue, 'cannot assign to constant','immutable')
        pair('const-pointer-constructor', 'const pixels:p.PixelStorage=.invalid;var x:p.PixelStorageIterator=.{.pixels=&pixels};_=x.next();',
             'pixels:=p.PixelStorage(p.InvalidPixels{})\nmut x:=p.PixelStorageIterator{pixels:&pixels}\n_=x.next()', None, 'mutable reference')
        if (tree_hash(source) != PINNED_SOURCE_SHA256 or tree_hash(root / 'src') != PINNED_SOURCE_SHA256
                or stdlib_hash(zig) != PINNED_STDLIB_SHA256 or implementation_hashes(repo) != implementations
                or hashlib.sha256(Path(__file__).read_bytes()).hexdigest() != runner_hash):
            raise AssertionError('dependency, implementation or runner changed')
        for name, expected in fixtures.items():
            if any(hashlib.sha256((p / name).read_bytes()).hexdigest() != expected for p in (root, probe)): raise AssertionError('fixture changed')
        summary=dict(returning_records=EXPECTED_ROWS,groups=dict(counts),output_sha256=digest,
                     paired_traps=sum(traps.values()),failure_groups=dict(traps),state_sha256=state_digest,
                     compile_acceptance_pairs=2,readonly_rejections=4,const_pointer_constructor_difference=1,
                     zig_mode=mode,v_prod=args.v_prod)
        (root/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
        print(json.dumps(summary),flush=True)


if __name__ == '__main__':
    main()
