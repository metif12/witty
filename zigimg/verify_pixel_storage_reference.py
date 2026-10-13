"""Compare indexed constructors, palette mutation and borrowed raw PixelStorage."""
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

EXPECTED_ROWS = 4393
EXPECTED_SHA256 = '8967f88d0296ceb0499e115b004ce6579c8fe87682fc6bd2b40b1f4f36a2823e'
EXPECTED_STATE_SHA256 = 'bc8fdb7c1c467f766f59bd7490211ddb0666cf8e4426fa2b2077fa4a3a506849'
# Raw formats: integer tag, stride, required alignment.
RAW = [(0x101,1,1),(0x102,1,1),(0x104,1,1),(0x108,1,1),
       (0x208,2,1),(0x210,4,2),(0x303,1,1),(0x305,2,2),(0x3305,2,2),
       (0x308,3,1),(0x408,4,1),(0x1305,2,2),(0x1308,3,1),(0x1408,4,1),
       (0x310,6,1),(0x410,8,1),(0x2420,16,1)]


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
    probe = repo / 'zigimg/reference_probes/pixel_storage'
    env = dict(os.environ, VEXE=str(v), V_C_ERROR_BUG_REPORT_DISABLED='1')
    with work_directory(args.workdir, 'witty-pixel-storage-') as root:
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
        print(f'Building pixel storage: Source {mode}, V {"production" if args.v_prod else "ordinary"}', flush=True)
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
        print(f'{EXPECTED_ROWS} returning rows match; checking failures and construction', flush=True)
        states = hashlib.sha256()
        traps = 0

        def trap(name, arguments, category):
            nonlocal traps
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
            traps += 1

        for bits in (1,2,4,8,16):
            for size in ((1 << bits)+1, (1 << bits)+7, 0xffffffffffffffff):
                for flag in ('--init','--resize','--union-resize'):
                    trap(f'{flag[2:]}-{bits}-{size}', [flag,bits,size], 'reached unreachable code')
        for tag, stride, alignment in RAW:
            for remainder in range(1,stride):
                # Odd input exercises exact-division failure before the alignCast.
                trap(f'remainder-{tag}-{remainder}', ['--raw',tag,1,stride+remainder], 'exact division produced remainder')
            if alignment == 2:
                for length in (stride,stride*3):
                    trap(f'alignment-{tag}-{length}', ['--raw',tag,1,length], 'incorrect alignment')
        state_digest = states.hexdigest()
        if state_digest != EXPECTED_STATE_SHA256: raise AssertionError('failure-state golden changed')

        def pair(label, zbody, vbody, zmarker=None, vmarker=None):
            zp, vp = root / (label + '.zig'), root / (label + '.v')
            zp.write_text('const std=@import("std");const p=@import("src/color.zig");const a=std.heap.page_allocator;pub fn main() !void {' + zbody + '}\n')
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

        for bits in (1,2,4,8,16):
            typ=f'IndexedStorage{bits}'
            carrier='u16' if bits==16 else 'u8'
            fields={'palette':('&.{}','[]p.Rgba32{}'),'indices':('&.{}',f'[]{carrier}{{}}')}
            for missing in (None,*fields):
                zfields=','.join('.'+name+'='+values[0] for name,values in fields.items() if name!=missing)
                vfields=','.join(name+':'+values[1] for name,values in fields.items() if name!=missing)
                label=('complete-' if missing is None else 'missing-')+typ+('-'+missing if missing else '')
                pair(label,'const x:p.'+typ+'=.{'+zfields+'};_=x;', 'x:=p.'+typ+'{'+vfields+'}\n_=x',
                     None if missing is None else 'missing struct field: '+missing,
                     None if missing is None else 'zigimg.'+typ+'.'+missing)
            pair('readonly-resize-'+typ, 'const x=try p.'+typ+'.init(a,0);x.resizePalette(0);',
                 'x:=p.'+typ+'.init(0)\nx.resize_palette(0)', 'expected type', 'immutable')
            pair('const-pointee-'+typ, 'var data=[_]u'+str(bits)+'{0};const x:p.'+typ+'=.{.palette=&.{},.indices=&data};x.indices[0]=1;',
                 'mut data:= ['+carrier+'(0)]\nx:=p.'+typ+'{palette:[]p.Rgba32{},indices:data}\nx.indices[0]=1',None,'immutable')
            if bits < 8:
                pair('narrow-literal-'+typ, 'var data=[_]u'+str(bits)+'{'+str(1<<bits)+'};const x:p.'+typ+'=.{.palette=&.{},.indices=&data};_=x;',
                     'data:= ['+carrier+'('+str(1<<bits)+')]\nx:=p.'+typ+'{palette:[]p.Rgba32{},indices:data}\n_=x', 'cannot represent integer value',None)
        pair('const-byte-view', 'var data=[_]u8{1,2,3};const x=try p.PixelStorage.initRawPixels(&data,.rgb24);const bytes=x.asConstBytes();bytes[0]=4;',
             'data:=[u8(1),2,3]\nx:=p.PixelStorage.init_raw_pixels(data,.rgb24) or {panic(err)}\nmut bytes:=x.as_const_bytes()\nbytes[0]=4', 'cannot assign to constant', None)
        boxed=[]
        for bits in (1,2,4,8,16):
            observed=[]
            for exe,expected in (('native',f'1|{1<<bits}\n'.encode()),('translated',b'1|1\n')):
                r=proof.run([str(root/exe),'--boxed',str(bits)],f'boxed-{bits}-{exe}',timeout=args.timeout)
                if r.stderr or r.stdout!=expected: raise AssertionError('boxed payload difference changed')
                observed.append(r.stdout.decode().strip())
            boxed.append(dict(bits=bits,source=observed[0],v=observed[1]))
        if (tree_hash(source) != PINNED_SOURCE_SHA256 or tree_hash(root / 'src') != PINNED_SOURCE_SHA256
                or stdlib_hash(zig) != PINNED_STDLIB_SHA256 or implementation_hashes(repo) != implementations
                or hashlib.sha256(Path(__file__).read_bytes()).hexdigest() != runner_hash):
            raise AssertionError('dependency, implementation or runner changed')
        for name, expected in fixtures.items():
            if any(hashlib.sha256((p / name).read_bytes()).hexdigest() != expected for p in (root, probe)): raise AssertionError('fixture changed')
        summary=dict(returning_records=EXPECTED_ROWS,groups=dict(counts),output_sha256=digest,
                     paired_traps=traps,state_sha256=state_digest,complete_constructors=5,
                     required_omissions=10,readonly_resize_rejections=5,const_pointee_differences=5,
                     narrow_literal_differences=3,const_byte_view_difference=1,boxed_payload_differences=boxed,zig_mode=mode,v_prod=args.v_prod)
        (root/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
        print(json.dumps(summary),flush=True)


if __name__ == '__main__':
    main()
