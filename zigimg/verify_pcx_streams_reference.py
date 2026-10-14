"""Compare PCX positional file encoding, retained buffers and checked short storage."""
import argparse
from collections import Counter
import hashlib
import itertools
import json
import os
from pathlib import Path
import re
import shutil
from verify_jpeg_contracts_reference import implementation_hashes
from verify_tiff_decode_reference import ProofLog, tree_hash, work_directory, PINNED_SOURCE_SHA256, checked_trap
from verify_tga_decode_reference import stdlib_hash, PINNED_STDLIB_SHA256

EXPECTED_ROWS = 31926
EXPECTED_SHA256 = '5aa80bb7a8cba801fa567fd16de6e7e424757fd3e077975c430a1fedb1311e5d'
EXPECTED_CONTROLS = 67
EXPECTED_CONTROL_SHA256 = '7478420d1dbafe2e6bf577d14a9404151236ece9a3c1808d7bcf8ee90e572e29'
EXPECTED_TRAPS = 523
EXPECTED_STATE_SHA256 = 'b7fc8e58519d7344a17c309b60ac76bcf633a69687386446dd732ce0ed338a87'
FORMATS = (1, 4, 8, 0x308, 0x108)
BUFFERS = (-1, -2, -128, -129, -130, -161, -257, -1025, 0, 1, 2, 3, 8, 16, 63, 127, 128, 129, 256, 1024)


def spec(cap, op=0, w=1, h=1, fmt=8, count=1, pattern=0, palette=4, start=0, attempts=2, coords=0):
    return '|'.join(map(str, (cap, op, w, h, fmt, count, pattern, palette, start, attempts, coords)))


def corpus():
    rows = []
    shapes = ((1,1),(2,1),(3,1),(7,2),(8,2),(15,1),(16,2),(17,2),(31,1),(32,2),(63,1),(64,1),(65,2))
    for cap,op,fmt,dims,pattern,start in itertools.product(BUFFERS,range(3),FORMATS,shapes,range(4),(0,7)):
        if cap in (-1,-2) and start: continue
        w,h=dims
        rows.append(('buffered-encoding',spec(cap,op,w,h,fmt,w*h,pattern,start=start)))
    for cap,op,fmt,palette,pattern in itertools.product((-1025,0,1,3,128,256),range(3),(1,4,8),(0,1,2,4,16,256),(0,2)):
        rows.append(('palette-length',spec(cap,op,3,2,fmt,6,pattern,palette)))
    for cap,op,count,pattern in itertools.product((-1025,0,1,8,128),range(3),(0,1,15,16,17,31,32,33,62,63,64,65,127,128,129),range(6)):
        rows.append(('whole-slice-even-indexed8',spec(cap,op,2,1,8,count,pattern)))
    for cap,op,dims,fmt in itertools.product((-1,-129,-1025,0,1,128), (1,2), ((65536,0),(0,65536),(2**64-1,1),(1,2**64-1),(1,1)),FORMATS):
        if dims==(1,1) and fmt!=0x108:continue
        rows.append(('unsupported-before-output',spec(cap,op,*dims,fmt,count=0)))
    for cap,fmt,coords in itertools.product((-1,-129,-1025,0,1,128),FORMATS,range(1,5)):
        if fmt==0x108 or (fmt==8 and coords in (3,4)):
            rows.append(('direct-rejection-or-ignored-height',spec(cap,0,2,1,fmt,count=4,coords=coords)))
    return rows


def controls():
    cases=[]
    for cap,op,fmt,shape in itertools.product((-129,-257,-1025,0,1,8,128,256),range(3),FORMATS[:-1],((1,1,0),(3,2,4),(8,1,7))):
        w,h,count=shape
        cases.append(('short-storage',f'short-{cap}-{op}-{fmt}-{w}-{h}-{count}',spec(cap,op,w,h,fmt,count,pattern=1,attempts=1)))
    for cap,op,fmt,dims in itertools.product((-1,-129,-1025,0,1,128),(1,2),FORMATS,((0,1),(1,0),(0,0))):
        cases.append(('zero-dimensions',f'zero-{cap}-{op}-{fmt}-{dims[0]}-{dims[1]}',spec(cap,op,*dims,fmt,count=0,attempts=1)))
    for cap,op,fmt in itertools.product((-1,-129,-1025,0,1,128),(1,2),(8,0x308)):
        cases.append(('odd-stride',f'stride-{cap}-{op}-{fmt}',spec(cap,op,65535,1,fmt,count=0,attempts=1)))
    for cap,fmt,coords in itertools.product((-1,-128,-129,-1025,0,1,128),FORMATS[:-1],range(1,5)):
        if fmt==8 and coords in (3,4):continue
        cases.append(('direct-coordinates',f'coords-{cap}-{fmt}-{coords}',spec(cap,0,1,1,fmt,count=1,attempts=1,coords=coords)))
    return cases


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source',type=Path);parser.add_argument('zig',type=Path);parser.add_argument('v',type=Path)
    parser.add_argument('--target',default='aarch64-macos.14.0');parser.add_argument('--v-prod',action='store_true')
    parser.add_argument('--workdir',type=Path);parser.add_argument('--timeout',type=int,default=180)
    args=parser.parse_args()
    if args.timeout<=0:parser.error('--timeout must be positive')
    source=args.source.resolve()/'src';zig=args.zig.resolve();v=args.v.resolve()
    if tree_hash(source)!=PINNED_SOURCE_SHA256 or stdlib_hash(zig)!=PINNED_STDLIB_SHA256:parser.error('Source or compiler library differs from pins')
    repo=Path(__file__).resolve().parent.parent;probe=repo/'zigimg/reference_probes/pcx_streams'
    mode='ReleaseSafe' if args.v_prod else 'Debug'
    with work_directory(args.workdir,'witty-pcx-streams-') as root:
        tmp=root/'tmp';tmp.mkdir();env=dict(os.environ,TMPDIR=str(tmp),VTMP=str(tmp),VEXE=str(v),V_C_ERROR_BUG_REPORT_DISABLED='1')
        proof=ProofLog(root);shutil.copytree(source,root/'src');fixtures={}
        for name in ('main.v','reference.zig'):
            shutil.copyfile(probe/name,root/name);fixtures[name]=hashlib.sha256((root/name).read_bytes()).hexdigest()
        versions=[proof.run([str(exe),'version'],label,env=env).stdout.decode().strip() for exe,label in ((zig,'zig-version'),(v,'v-version'))]
        if versions[0]!='0.15.2' or not re.match(r'^V 0\.5\.2(?: |$)',versions[1]):raise AssertionError('unexpected compiler versions')
        impl=implementation_hashes(repo);runner_hash=hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
        helpers={name:hashlib.sha256((repo/'zigimg'/name).read_bytes()).hexdigest() for name in ('verify_jpeg_contracts_reference.py','verify_tiff_decode_reference.py','verify_tga_decode_reference.py')}
        (root/'provenance.json').write_text(json.dumps(dict(source_sha256=PINNED_SOURCE_SHA256,stdlib_sha256=PINNED_STDLIB_SHA256,versions=versions,target=args.target,zig_mode=mode,v_prod=args.v_prod,implementation_sha256=impl,runner_sha256=runner_hash,fixtures=fixtures,helper_sha256=helpers),indent=2)+'\n')
        print(f'Building PCX streams: Source {mode}, V {"production" if args.v_prod else "ordinary"}',flush=True)
        proof.run([str(zig),'build-exe','-target',args.target,'-lc','-O',mode,'--global-cache-dir',str(root.parent/'zig-global'),'--cache-dir',str(root/'zig-cache'),'-femit-bin='+str(root/'native'),str(root/'reference.zig')],'build-source',env=env,timeout=args.timeout)
        proof.run([str(v),'-enable-globals',*(['-prod'] if args.v_prod else []),'-path',f'{repo}|@vlib|@vmodules','-o',str(root/'translated'),str(root/'main.v')],'build-v',env=env,timeout=args.timeout)
        rows=corpus();path=root/'corpus.txt';path.write_text('\n'.join(data for _,data in rows)+'\n')
        inputs={'corpus.txt':hashlib.sha256(path.read_bytes()).hexdigest()}
        (root/'input_sha256.json').write_text(json.dumps(inputs,indent=2)+'\n')
        outputs=[]
        for exe in ('native','translated'):
            r=proof.run([str(root/exe),str(path)],'returning-'+exe,env=env,timeout=args.timeout,check=False)
            if r.returncode or r.stderr or len(r.stdout.splitlines())!=len(rows):raise AssertionError(f'{exe}: invalid returning output; see raw proof files')
            outputs.append(r.stdout.splitlines())
        for i,(native,translated) in enumerate(zip(*outputs)):
            if native!=translated:raise AssertionError(f'{i}/{rows[i][0]}: output differs; see raw proof files')
        digest=hashlib.sha256(b'\n'.join(outputs[0])).hexdigest()
        if EXPECTED_ROWS is not None and (len(rows)!=EXPECTED_ROWS or digest!=EXPECTED_SHA256):raise AssertionError('returning golden changed')
        print(f'{len(rows)} returning records match; checking short storage and arithmetic',flush=True)
        returns=hashlib.sha256();states=hashlib.sha256();return_groups=Counter();trap_groups=Counter()
        for group,name,data in controls():
            records=[]
            for exe in ('native','translated'):
                state=root/(name+'-'+exe+'.state')
                records.append((proof.run([str(root/exe),'--trap',str(state),data],name+'-'+exe,env=env,timeout=args.timeout,check=False),state))
            native,translated=records[0][0],records[1][0]
            if native.returncode==0:
                if native.stderr or translated.returncode or translated.stderr or native.stdout!=translated.stdout or len(native.stdout.splitlines())!=1:raise AssertionError(f'{name}: control return differs')
                returns.update(name.encode()+b'\0'+native.stdout);return_groups[group]+=1
            else:
                messages=[]
                for (result,state),exe in zip(records,('native','translated')):
                    found=[m.group(1) for line in result.stderr.decode().splitlines() if (m:=re.fullmatch(r'(?:thread \d+ |V )?panic:\s*(.*)',line.strip()))]
                    if len(found)!=1 or not re.fullmatch(r'integer overflow|index out of bounds: index \d+, len \d+',found[0]):raise AssertionError(f'{name}/{exe}: unexpected panic {found}')
                    checked_trap(result,name+'/'+exe,found[0]);messages.append(found[0])
                    if not state.exists():raise AssertionError('missing panic observer')
                if messages[0]!=messages[1]:raise AssertionError(f'{name}: exact panic differs: {messages}')
                observed=[state.read_bytes() for _,state in records]
                if not observed[0] or observed[0]!=observed[1]:raise AssertionError(f'{name}: failure state differs')
                states.update(name.encode()+b'\0'+messages[0].encode()+b'\0'+observed[0]+b'\n');trap_groups[group]+=1
        controls_digest=returns.hexdigest();state_digest=states.hexdigest()
        if EXPECTED_CONTROLS is not None and (sum(return_groups.values())!=EXPECTED_CONTROLS or controls_digest!=EXPECTED_CONTROL_SHA256):raise AssertionError('return controls changed')
        if EXPECTED_TRAPS is not None and (sum(trap_groups.values())!=EXPECTED_TRAPS or state_digest!=EXPECTED_STATE_SHA256):raise AssertionError('failure golden changed')
        if tree_hash(source)!=PINNED_SOURCE_SHA256 or tree_hash(root/'src')!=PINNED_SOURCE_SHA256 or stdlib_hash(zig)!=PINNED_STDLIB_SHA256 or implementation_hashes(repo)!=impl or hashlib.sha256(Path(__file__).read_bytes()).hexdigest()!=runner_hash:raise AssertionError('dependency, implementation or runner changed')
        for name,expected in fixtures.items():
            if any(hashlib.sha256((base/name).read_bytes()).hexdigest()!=expected for base in (root,probe)):raise AssertionError('fixture changed')
        for name,expected in inputs.items():
            if hashlib.sha256((root/name).read_bytes()).hexdigest()!=expected:raise AssertionError('input changed')
        for name,expected in helpers.items():
            if hashlib.sha256((repo/'zigimg'/name).read_bytes()).hexdigest()!=expected:raise AssertionError('helper changed')
        summary=dict(returning_records=len(rows),calls=sum(int(data.split('|')[9]) for _,data in rows),returning_groups=dict(Counter(group for group,_ in rows)),output_sha256=digest,return_controls=sum(return_groups.values()),return_control_groups=dict(return_groups),control_sha256=controls_digest,paired_traps=sum(trap_groups.values()),failure_groups=dict(trap_groups),state_sha256=state_digest,zig_mode=mode,v_prod=args.v_prod)
        (root/'summary.json').write_text(json.dumps(summary,indent=2)+'\n');print(json.dumps(summary),flush=True)


if __name__=='__main__':main()
