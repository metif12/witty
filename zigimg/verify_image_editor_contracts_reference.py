"""Compare public image editing, row sizes and retained checked-failure state."""
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

EXPECTED_ROWS = 42007
EXPECTED_CONTROLS = 27
EXPECTED_TRAPS = 524
EXPECTED_SHA256 = '6e4fbba5bf6989991bc3265f8853403464eea19843ed7056094ece7414d1faa3'
EXPECTED_CONTROL_SHA256 = '9ad6adc71fc4b52ef25731150dbd38ec3571611a5e1a673f54874026c9661c91'
EXPECTED_STATE_SHA256 = '913682a5a4bf69433ecdf609cf1e39b27a194d7c61291f0b2cb2bc7b3cf243cd'
MAX = (1 << 64) - 1
FORMATS = [0,1,2,4,8,16,0x101,0x102,0x104,0x108,0x110,0x208,0x210,0x303,0x305,0x3305,0x308,0x408,0x1305,0x1308,0x1408,0x310,0x410,0x2420]
def stride(fmt):
    return 0 if fmt==0 else 2 if fmt==16 else 1 if fmt<256 or fmt in (0x101,0x102,0x104,0x108,0x303) else 2 if fmt in (0x110,0x208,0x305,0x1305,0x3305) else 3 if fmt in (0x308,0x1308) else 4 if fmt in (0x210,0x408,0x1408) else 6 if fmt==0x310 else 8 if fmt==0x410 else 16

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path); parser.add_argument('zig', type=Path); parser.add_argument('v', type=Path)
    parser.add_argument('--target', default='aarch64-macos.14.0'); parser.add_argument('--v-prod', action='store_true')
    parser.add_argument('--workdir', type=Path); parser.add_argument('--timeout', type=int, default=180)
    args = parser.parse_args()
    if args.timeout <= 0: parser.error('--timeout must be positive')
    source = args.source.resolve() / 'src'; zig = args.zig.resolve(); v = args.v.resolve()
    if tree_hash(source) != PINNED_SOURCE_SHA256 or stdlib_hash(zig) != PINNED_STDLIB_SHA256:
        parser.error('Source or selected library differs from pins')
    repo = Path(__file__).resolve().parent.parent; probe = repo / 'zigimg/reference_probes/image_editor_contracts'
    mode = 'ReleaseSafe' if args.v_prod else 'Debug'
    env = dict(os.environ, VEXE=str(v), V_C_ERROR_BUG_REPORT_DISABLED='1')
    with work_directory(args.workdir, 'witty-bmp-contracts-') as root:
        proof = ProofLog(root); shutil.copytree(source, root / 'src'); fixtures = {}
        for name in ('main.v', 'reference.zig'):
            shutil.copyfile(probe / name, root / name)
            fixtures[name] = hashlib.sha256((root / name).read_bytes()).hexdigest()
        versions = [proof.run([str(exe), 'version'], label, env=env).stdout.decode().strip()
                    for exe, label in ((zig, 'zig-version'), (v, 'v-version'))]
        if versions[0] != '0.15.2' or not re.match(r'^V 0\.5\.2(?: |$)', versions[1]):
            raise AssertionError('unexpected compiler versions')
        implementations = implementation_hashes(repo); runner_hash = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
        (root / 'provenance.json').write_text(json.dumps(dict(source_sha256=PINNED_SOURCE_SHA256, stdlib_sha256=PINNED_STDLIB_SHA256,
            versions=versions, target=args.target, zig_mode=mode, v_prod=args.v_prod, fixtures=fixtures,
            implementation_sha256=implementations, runner_sha256=runner_hash), indent=2) + '\n')
        zbase = [str(zig), 'build-exe', '-target', args.target, '-lc', '-O', mode, '--global-cache-dir', str(root / 'zig-global')]
        vbase = [str(v), '-enable-globals', *(['-prod'] if args.v_prod else []), '-path', f'{repo}|@vlib|@vmodules']
        print(f'Building image editor contracts: Source {mode}, V {"production" if args.v_prod else "ordinary"}', flush=True)
        proof.run(zbase + ['-femit-bin=' + str(root / 'native'), str(root / 'reference.zig')], 'build-source', timeout=args.timeout)
        proof.run(vbase + ['-o', str(root / 'translated'), str(root / 'main.v')], 'build-v', env=env, timeout=args.timeout)
        outputs=[]
        for exe in ('native','translated'):
            result=proof.run([str(root/exe)],'returning-'+exe,timeout=args.timeout)
            if result.stderr: raise AssertionError('unexpected returning stderr')
            outputs.append(result.stdout.splitlines())
        if len(outputs[0])!=len(outputs[1]): raise AssertionError(f'row counts differ: {[len(x) for x in outputs]}')
        for index,(native,translated) in enumerate(zip(*outputs)):
            if native!=translated: raise AssertionError(f'{index}: Source={native!r}, V={translated!r}')
        if len(outputs[0])!=EXPECTED_ROWS: raise AssertionError('returning count changed')
        digest=hashlib.sha256(b'\n'.join(outputs[0])).hexdigest()
        if digest!=EXPECTED_SHA256: raise AssertionError('returning golden changed')
        groups=Counter(row[:1].decode() for row in outputs[0]); controls=hashlib.sha256(); control_count=0
        def returning(name,arguments):
            nonlocal control_count
            results=[]
            for exe in ('native','translated'):
                result=proof.run([str(root/exe),arguments[0],'-',*map(str,arguments[1:])],name+'-'+exe,timeout=args.timeout)
                if result.stderr or len(result.stdout.splitlines())!=1: raise AssertionError('invalid returning control')
                results.append(result.stdout)
            if results[0]!=results[1]: raise AssertionError(f'{name}: differing return {results}')
            controls.update(name.encode()+b'\0'+results[0]);control_count+=1
        for fmt in (1,2,4,8,16,0x108,0x110,0x2420):
            for api in range(3):
                returning(f'wide-empty-{fmt}-{api}',['--crop',api,fmt,3,MAX,MAX,MAX,MAX,0,0])
        for dims,box in (((MAX,MAX),(MAX,MAX,0,0)),((MAX,MAX),(0,0,MAX,MAX)),((0,MAX),(0,MAX,0,0))):
            returning('clamp-'+str(dims)+str(box),['--clamp',0,0,0,*dims,*box])
        if control_count != EXPECTED_CONTROLS: raise AssertionError('control count changed')
        control_digest=controls.hexdigest()
        if control_digest!=EXPECTED_CONTROL_SHA256: raise AssertionError('control golden changed')
        print(f'{len(outputs[0])} main rows and {control_count} returning controls match; checking strict state',flush=True)
        states=hashlib.sha256();traps=Counter()
        def trap(group,name,arguments,category):
            observed=[]
            for exe in ('native','translated'):
                path=root/(name+'-'+exe+'.state')
                result=proof.run([str(root/exe),arguments[0],str(path),*map(str,arguments[1:])],name+'-'+exe,timeout=args.timeout,check=False)
                checked_trap(result,name+'/'+exe,category)
                if not path.exists(): raise AssertionError('missing panic observer')
                observed.append(path.read_bytes())
            if not observed[0] or observed[0]!=observed[1]: raise AssertionError(f'{name}: states differ {observed}')
            states.update(name.encode()+b'\0'+observed[0]+b'\n');traps[group]+=1
        for fmt in FORMATS:
            for count in (0,2):
                for api in range(3):
                    trap('zero-flip',f'zero-flip-{fmt}-{count}-{api}',['--flip',api,fmt,count,7,0],'division by zero')
                for api in (1,2):
                    trap('zero-row',f'zero-row-{fmt}-{count}-{api}',['--row',api,fmt,count,7,0],'division by zero')
            if fmt==0: continue
            for api in range(3):
                step=stride(fmt)
                trap('crop-short',f'crop-short-{fmt}-{api}',['--crop',api,fmt,3,3,2,0,0,3,2],f'index out of bounds: index {6*step}, len {3*step}')
                for x in (1<<31,1<<32):
                    trap('crop-wide',f'crop-wide-{fmt}-{api}-{x}',['--crop',api,fmt,3,MAX,1,x,0,1,1],f'index out of bounds: index {(x+1)*step}, len {3*step}')
        for fmt,count,height in ((0x108,7,3),(0x108,10,3),(0x110,5,3),(0x308,5,6),(0x408,4,3),(0x2420,1,3),(8,7,3),(16,5,3)):
            for api in range(3):
                trap('flip-alias',f'flip-alias-{fmt}-{count}-{height}-{api}',['--flip',api,fmt,count,7,height],'@memcpy arguments alias')
        faults=[('x-mul',0x110,MAX,1,(MAX//2+1,0,1,1)),('row-mul',0x108,MAX,3,(0,2,1,1)),
                ('row-byte-mul',0x110,MAX,2,(0,1,1,1)),('start-sum',0x108,MAX-3,2,(4,1,1,1)),
                ('end-sum',0x108,MAX,2,(0,1,1,1))]
        for name,fmt,width,height,box in faults:
            for api in range(3): trap('crop-offset',name+'-'+str(api),['--crop',api,fmt,3,width,height,*box],'integer overflow')
        for fmt in (0,0x108,8):
            for api in range(3): trap('crop-count',f'crop-count-{fmt}-{api}',['--crop',api,fmt,3,MAX,2,0,0,MAX,2],'integer overflow')
        for dims,box in (((0,0),(0,0,0,0)),((1,1),(0,0,0,0)),((1,1),(0,0,1,1))):
            for api in range(3): trap('invalid-palette',f'invalid-{dims}-{box}-{api}',['--crop',api,0,0,*dims,*box],'attempt to use null value')
        clamp_faults=[(MAX,MAX,(MAX,MAX,1,1)),(MAX,MAX,(MAX,MAX,0,1)),(0,1,(1,0,0,1)),(1,0,(0,1,1,0)),(MAX,MAX,(0,MAX,1,1))]
        for n,(width,height,box) in enumerate(clamp_faults):
            trap('clamp',f'clamp-fault-{n}',['--clamp',0,0,0,width,height,*box],'integer overflow')
            for api in range(3): trap('crop-clamp',f'crop-clamp-{n}-{api}',['--crop',api,0,0,width,height,*box],'integer overflow')
        if sum(traps.values()) != EXPECTED_TRAPS: raise AssertionError('trap count changed')
        state_digest=states.hexdigest()
        if state_digest!=EXPECTED_STATE_SHA256: raise AssertionError('failure-state golden changed')
        loops=0
        for api in range(3):
            for exe in ('native','translated'):
                label=f'zero-row-loop-{api}-{exe}'
                try: proof.run([str(root/exe),'--flip','-',str(api),str(0x108),'1','7','2'],label,timeout=1)
                except AssertionError:
                    if not proof.commands[-1].get('timed_out'): raise
                    prefix=f'{len(proof.commands)-1:03d}-{label}'
                    if (root/(prefix+'.stdout')).read_bytes() or (root/(prefix+'.stderr')).read_bytes(): raise AssertionError('loop emitted output')
                else: raise AssertionError('nonadvancing flip returned')
            loops+=1
        if (tree_hash(source) != PINNED_SOURCE_SHA256 or tree_hash(root / 'src') != PINNED_SOURCE_SHA256
                or stdlib_hash(zig) != PINNED_STDLIB_SHA256 or implementation_hashes(repo) != implementations
                or hashlib.sha256(Path(__file__).read_bytes()).hexdigest() != runner_hash): raise AssertionError('dependency, implementation or runner changed')
        for name, expected in fixtures.items():
            if any(hashlib.sha256((base / name).read_bytes()).hexdigest() != expected for base in (root, probe)): raise AssertionError('fixture changed')
        summary=dict(returning_records=len(outputs[0]),groups=dict(groups),output_sha256=digest,return_controls=control_count,
            control_sha256=control_digest,paired_traps=sum(traps.values()),failure_groups=dict(traps),state_sha256=state_digest,
            inherited_loops=loops,zig_mode=mode,v_prod=args.v_prod)
        (root/'summary.json').write_text(json.dumps(summary,indent=2)+'\n');print(json.dumps(summary),flush=True)

if __name__=='__main__': main()
