"""Compare private POSIX image close ownership, buffered state and BADF traps."""
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
from verify_image_open_reference import ENCODER_LIBRARIES, encoder_library_hashes, PATH_LIBRARIES, path_library_hashes

EXPECTED_ROWS = 328
EXPECTED_SHA256 = '7a25a87d2f39b9644eefd873ac9a72b3f4ab0239909ca07e4c8daa11ca3004fc'
EXPECTED_TRAPS = 264
EXPECTED_STATE_SHA256 = '2f59f51f2fd0faf9b77a9c4bd5b8428e5415a23403b1d7daffe45f80ee872221'
HELPERS = ('verify_jpeg_contracts_reference.py','verify_tiff_decode_reference.py','verify_tga_decode_reference.py','verify_image_open_reference.py')


def spec(kind=0, writing=1, cap=8, count=7, flush=0, choice=0, attempts=2, ahead=0):
    return '|'.join(map(str,(kind,writing,cap,count,flush,choice,attempts,ahead)))


def contexts():
    return [(kind,writing) for kind in range(5) for writing in range(2) if not (kind==2 and writing)]


def corpus():
    rows=[('write-close' if writing else 'read-close',spec(kind,writing,cap,count,flush,choice)) for kind,writing in contexts() for cap,count,flush,choice in itertools.product((0,1,8,32),(0,1,7),(0,1) if writing else (0,),range(2))]
    rows += [('read-ahead-close',spec(kind,0,cap,1,0,choice,ahead=1)) for kind,cap,choice in itertools.product((0,1,3,4),(8,32),range(2))]
    return rows


def controls():
    rows=[('invalid-close',spec(kind,writing,cap,count,flush,choice,1)) for kind,writing in contexts() for cap,count,flush,choice in itertools.product((0,8,32),(0,7),(0,1) if writing else (0,),(2,3,4))]
    rows += [('negative-descriptor',spec(writing=writing,cap=cap,count=0,choice=5,attempts=1)) for writing,cap in itertools.product(range(2),(0,8,32))]
    rows += [('read-ahead-invalid-close',spec(kind,0,cap,1,0,choice,1,ahead=1)) for kind,cap,choice in itertools.product((0,1,3,4),(8,32),(2,3,4))]
    return [(group,f'control-{i}',data) for i,(group,data) in enumerate(rows)]


def snapshot_checks(line,data):
    f=list(map(int,data.split('|')));kind,writing,cap,count,flush,choice,attempts,ahead=f
    states=line.decode().split('~')
    if len(states)!=2*attempts+1 or states[-1]!='':raise AssertionError('missing close snapshots')
    for i,state in enumerate(states[:-1]):
        fields=state.split('|');meta=list(map(int,fields[0].split(':')))
        valid=1 if i%2==0 and choice!=5 else 0
        expected=[valid,1,1+valid,1 if kind==1 else 2 if kind==2 else 0,-3 if i==0 else (-1 if kind==1 else 0),10+writing if valid else -1]
        if meta!=expected:raise AssertionError(f'close ownership/flags/drain differ: {meta} versus {expected}')
        if len(fields)!=6 or len(fields[1])!=cap*2 or len(fields[2])!=count*2:raise AssertionError('initialized close buffers differ')
    for i in range(0,len(states)-1,2):
        before=states[i].split('|');after=states[i+1].split('|')
        if before[1:5]!=after[1:5]:raise AssertionError('close changed retained stream/caller state')


def build_v(proof,root,repo,v,prod,env,timeout):
    copied=root/'zigimg';copied.mkdir()
    for name in implementation_hashes(repo):shutil.copyfile(repo/name,root/name)
    shutil.copyfile(repo/'v.mod',root/'v.mod')
    shutil.copyfile(root/'fixture_shims.h',copied/'fixture_shims.h')
    shutil.copyfile(root/'driver.v',copied/'driver_test.v')
    proof.run([str(v),'-enable-globals',*(['-prod'] if prod else []),'-skip-running','-path',f'{repo}|@vlib|@vmodules','-o',str(root/'translated'),str(copied/'driver_test.v')],'build-v',env=env,timeout=timeout)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source',type=Path);parser.add_argument('zig',type=Path);parser.add_argument('v',type=Path)
    parser.add_argument('--target',default='aarch64-macos.14.0');parser.add_argument('--v-prod',action='store_true')
    parser.add_argument('--workdir',type=Path);parser.add_argument('--timeout',type=int,default=600)
    args=parser.parse_args()
    if args.timeout<=0:parser.error('--timeout must be positive')
    source=args.source.resolve()/'src';zig=args.zig.resolve();v=args.v.resolve()
    if tree_hash(source)!=PINNED_SOURCE_SHA256 or stdlib_hash(zig)!=PINNED_STDLIB_SHA256 or encoder_library_hashes(zig)!=ENCODER_LIBRARIES or path_library_hashes(zig)!=PATH_LIBRARIES:parser.error('Source or compiler library differs from pins')
    repo=Path(__file__).resolve().parent.parent;probe=repo/'zigimg/reference_probes/image_close';mode='ReleaseSafe' if args.v_prod else 'Debug'
    with work_directory(args.workdir,'witty-image-close-') as root:
        tmp=root/'tmp';tmp.mkdir();env=dict(os.environ,TMPDIR=str(tmp),VTMP=str(tmp),VEXE=str(v),V_C_ERROR_BUG_REPORT_DISABLED='1')
        proof=ProofLog(root);shutil.copytree(source,root/'src');fixtures={}
        for name in ('driver.v','reference.zig','fixture_shims.h','fixture_shims.c'):
            shutil.copyfile(probe/name,root/name);fixtures[name]=hashlib.sha256((root/name).read_bytes()).hexdigest()
        versions=[proof.run([str(exe),'version'],label,env=env).stdout.decode().strip() for exe,label in ((zig,'zig-version'),(v,'v-version'))]
        if versions[0]!='0.15.2' or not re.match(r'^V 0\.5\.2(?: |$)',versions[1]):raise AssertionError('unexpected compiler versions')
        impl=implementation_hashes(repo);runner_hash=hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
        helpers={name:hashlib.sha256((repo/'zigimg'/name).read_bytes()).hexdigest() for name in HELPERS}
        (root/'provenance.json').write_text(json.dumps(dict(source_sha256=PINNED_SOURCE_SHA256,stdlib_sha256=PINNED_STDLIB_SHA256,encoder_libraries=ENCODER_LIBRARIES,path_libraries=PATH_LIBRARIES,versions=versions,target=args.target,zig_mode=mode,v_prod=args.v_prod,implementation_sha256=impl,runner_sha256=runner_hash,fixtures=fixtures,helper_sha256=helpers,vmod_sha256=hashlib.sha256((repo/'v.mod').read_bytes()).hexdigest()),indent=2)+'\n')
        print(f'Building image close contracts: Source {mode}, V {"production" if args.v_prod else "ordinary"}',flush=True)
        proof.run([str(zig),'build-exe','-target',args.target,'-lc','-I',str(root),'-O',mode,'--global-cache-dir',str(root.parent/'zig-global'),'--cache-dir',str(root/'zig-cache'),'-femit-bin='+str(root/'native'),str(root/'reference.zig'),str(root/'fixture_shims.c')],'build-source',env=env,timeout=args.timeout)
        build_v(proof,root,repo,v,args.v_prod,env,args.timeout)
        rows=corpus();path=root/'corpus.txt';path.write_text('\n'.join(data for _,data in rows)+'\n')
        (root/'input_sha256.json').write_text(json.dumps({'corpus.txt':hashlib.sha256(path.read_bytes()).hexdigest()},indent=2)+'\n')
        outputs=[]
        for exe in ('native','translated'):
            r=proof.run([str(root/exe),str(path)],'returning-'+exe,env=env,timeout=args.timeout,check=False)
            if r.returncode or r.stderr or len(r.stdout.splitlines())!=len(rows):raise AssertionError(f'{exe}: invalid returning output; see raw proof files')
            outputs.append(r.stdout.splitlines())
        for i,(native,translated) in enumerate(zip(*outputs)):
            if native!=translated:raise AssertionError(f'{i}/{rows[i][0]}: output differs; see raw proof files')
            snapshot_checks(native,rows[i][1])
        digest=hashlib.sha256(b'\n'.join(outputs[0])).hexdigest()
        if EXPECTED_ROWS is not None and (len(rows)!=EXPECTED_ROWS or digest!=EXPECTED_SHA256):raise AssertionError('returning golden changed')
        print(f'{len(rows)} returning records match; checking invalid closes',flush=True)
        states=hashlib.sha256();groups=Counter()
        for group,name,data in controls():
            results=[]
            for exe in ('native','translated'):
                state=root/(name+'-'+exe+'.state')
                result=proof.run([str(root/exe),'--trap',str(state),data],name+'-'+exe,env=env,timeout=args.timeout,check=False)
                messages=[m.group(1) for line in result.stderr.decode().splitlines() if (m:=re.fullmatch(r'(?:thread \d+ |V )?panic:\s*(.*)',line.strip()))]
                if messages!=['reached unreachable code']:raise AssertionError(f'{name}/{exe}: expected sole native BADF panic, got {messages}')
                checked_trap(result,name+'/'+exe,'reached unreachable code')
                if not state.exists():raise AssertionError('missing close panic state')
                results.append(state.read_bytes())
            if not results[0] or results[0]!=results[1]:raise AssertionError(f'{name}: close failure state differs')
            kind=int(data.split('|')[0]);meta=list(map(int,results[0].split(b'|')[0].split(b':')))
            if meta!=[0,1,1,1 if kind==1 else 2 if kind==2 else 0,-1 if kind==1 else 0,-1]:raise AssertionError('invalid close must retain only the keeper')
            states.update(name.encode()+b'\0'+b'reached unreachable code\0'+results[0]+b'\n');groups[group]+=1
        if list(root.glob('*.case')):raise AssertionError('owned close directory cleanup failed')
        state_digest=states.hexdigest()
        if EXPECTED_TRAPS is not None and (sum(groups.values())!=EXPECTED_TRAPS or state_digest!=EXPECTED_STATE_SHA256):raise AssertionError('failure golden changed')
        if tree_hash(source)!=PINNED_SOURCE_SHA256 or tree_hash(root/'src')!=PINNED_SOURCE_SHA256 or stdlib_hash(zig)!=PINNED_STDLIB_SHA256 or encoder_library_hashes(zig)!=ENCODER_LIBRARIES or path_library_hashes(zig)!=PATH_LIBRARIES or implementation_hashes(repo)!=impl or implementation_hashes(root)!=dict(impl,**{'zigimg/fixture_shims.h':fixtures['fixture_shims.h']}) or hashlib.sha256(Path(__file__).read_bytes()).hexdigest()!=runner_hash:raise AssertionError('dependency, implementation or runner changed')
        for name,expected in fixtures.items():
            if any(hashlib.sha256((base/name).read_bytes()).hexdigest()!=expected for base in (root,probe)):raise AssertionError('fixture changed')
        if hashlib.sha256((root/'zigimg/driver_test.v').read_bytes()).hexdigest()!=fixtures['driver.v']:raise AssertionError('module fixture changed')
        for name,expected in helpers.items():
            if hashlib.sha256((repo/'zigimg'/name).read_bytes()).hexdigest()!=expected:raise AssertionError('helper changed')
        if hashlib.sha256(path.read_bytes()).hexdigest()!=json.loads((root/'input_sha256.json').read_text())['corpus.txt'] or hashlib.sha256((root/'v.mod').read_bytes()).hexdigest()!=hashlib.sha256((repo/'v.mod').read_bytes()).hexdigest():raise AssertionError('input or v.mod changed')
        summary=dict(returning_records=len(rows),calls=sum(int(data.split('|')[6]) for _,data in rows),returning_groups=dict(Counter(group for group,_ in rows)),output_sha256=digest,paired_traps=sum(groups.values()),failure_groups=dict(groups),state_sha256=state_digest,zig_mode=mode,v_prod=args.v_prod)
        (root/'summary.json').write_text(json.dumps(summary,indent=2)+'\n');print(json.dumps(summary),flush=True)


if __name__=='__main__':main()
