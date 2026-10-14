"""Compare public image open flags, creation modes and exec inheritance."""
import argparse
from collections import Counter
import hashlib
import itertools
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import time
from verify_jpeg_contracts_reference import implementation_hashes
from verify_tiff_decode_reference import ProofLog, tree_hash, work_directory, PINNED_SOURCE_SHA256, checked_trap, no_core
from verify_tga_decode_reference import stdlib_hash, PINNED_STDLIB_SHA256

ENCODER_LIBRARIES = {'simd.zig': 'cc554020cebe55782b38c18c56a011b61a42f332781e5d0a5b1be3003eddd7a3', 'math.zig': '65645001357d5f78cbf646485e009a048b828680bb1b47fb3de0fd8617d91af1'}

def encoder_library_hashes(zig):
    return {name: hashlib.sha256((zig.parent/'lib/std'/name).read_bytes()).hexdigest() for name in ENCODER_LIBRARIES}

EXPECTED_ROWS = 9792
EXPECTED_SHA256 = '666e219554bee00361c39fc88e367143b44f1f7656813dee05e7e4af736121e0'
EXPECTED_CONTROLS = 144
EXPECTED_CONTROL_SHA256 = 'aed2f32a9dd98f56f7ea0340764fff5445837c0a291a893bf5b8913500bf2c66'
EXPECTED_TRAPS = 72
EXPECTED_STATE_SHA256 = '0fda43a6d11c4659af35eeb7c1a2a0b9431afb9beed8184bd9b85955b2dfa902'
PATH_LIBRARIES = {'fs/Dir.zig': '46ccade4f81b6bd772459d801a955a7cf417d77d2052fb38ddacfc65b3ed25f6', 'c.zig': 'a8138d10955a61fae402e1235e81685732f46e4cacca1e922609034183824bb1', 'c/darwin.zig': '4565e4abbe32fa6cdbdcee67d52376dacee82aa7c489d0048e509663500358c9'}

def path_library_hashes(zig):
    return {name: hashlib.sha256((zig.parent/'lib/std'/name).read_bytes()).hexdigest() for name in PATH_LIBRARIES}

from verify_image_read_reference import examples, GENERATOR_HELPERS, flate_hash, PINNED_FLATE_SHA256


def spec(op=0, fmt=0, profile=1, cap=8, managed=0, kind=0, mask=18, shape=0, attempts=2):
    return '|'.join(map(str,(op,fmt,profile,cap,managed,kind,mask,shape,attempts)))


def corpus():
    return [('create-and-truncate',spec(fmt=fmt,profile=profile,cap=cap,managed=managed,kind=kind,mask=mask)) for fmt,profile,cap,managed,kind,mask in itertools.product(range(17),range(8),(0,8,32),range(2),range(4),(0,18,63))]


def controls():
    return [('png-open-flags',f'control-{i}',spec(fmt=9,profile=profile,cap=cap,managed=managed,kind=kind,mask=mask,shape=1,attempts=1)) for i,(profile,cap,managed,kind,mask) in enumerate(itertools.product((1,3,7),(0,8,32),range(2),range(4),(0,18,63)))]


def loops():
    return [(f'loop-{i}',spec(op=op,cap=cap,managed=managed,kind=kind,mask=mask,attempts=1)) for i,(op,cap,managed,kind,mask) in enumerate(itertools.product((1,2),(32,128),range(2),(1,2,3),(0,18)))]


def snapshot_checks(line, data):
    f=list(map(int,data.split('|')));kind=f[5];mask=f[6]
    states=line.decode().split('~');initial=states[0].split('|')
    if initial[0]!='-' or initial[1]!=('-1:-1' if kind==0 else f'{1 if kind==2 else 0}:416'):
        raise AssertionError('initialized open state differs')
    for part in states[1:-1]:
        state=part.split('|',1)[1].split('|')
        if state[0]!='-' or state[1]!=f'{1 if kind==2 else 0}:{(438 & ~mask) if kind==0 else 416}':
            raise AssertionError('returned path descriptor, link kind or creation mode differs')
        if kind in (2,3) and state[-1]!=state[-2]:raise AssertionError('alias bytes differ')


def bounded_loop(proof,root,exe,row,label,env):
    ready=root/(label+'.ready');argv=[str(root/exe),'--loop',str(ready),row]
    start=time.monotonic();process=subprocess.Popen(argv,stdout=subprocess.PIPE,stderr=subprocess.PIPE,env=env,preexec_fn=no_core)
    try:
        while not ready.exists() and process.poll() is None and time.monotonic()-start<10:time.sleep(0.01)
        if not ready.exists() or process.poll() is not None:raise AssertionError(f'{label}: missing live descriptor readiness')
        # The watcher closes its ready file before exiting; allow the small write to complete.
        state=ready.read_bytes()
        while not state and time.monotonic()-start<10:time.sleep(0.01);state=ready.read_bytes()
        try:
            stdout,stderr=process.communicate(timeout=0.5)
            raise AssertionError(f'{label}: native detector loop returned {process.returncode}')
        except subprocess.TimeoutExpired:
            process.kill();stdout,stderr=process.communicate()
    finally:
        if process.poll() is None:process.kill();process.communicate()
    prefix=f'{len(proof.commands):03d}-{label}'
    proof.commands.append(dict(label=label,argv=argv,cwd=os.getcwd(),timeout=0.5,bounded_loop=True,killed_after_readiness=True,returncode=process.returncode,ready_sha256=hashlib.sha256(state).hexdigest()))
    (root/(prefix+'.stdout')).write_bytes(stdout);(root/(prefix+'.stderr')).write_bytes(stderr)
    (root/'commands.json').write_text(json.dumps(proof.commands,indent=2)+'\n')
    if stdout or stderr or process.returncode!=-9:raise AssertionError('loop emitted output or ended unexpectedly')
    case=Path(str(ready)+'.case')
    # All names are fixture-owned, including link/target files; no shared cleanup.
    for name in ('target','seed'):
        p=case/name
        if p.exists() or p.is_symlink():p.unlink()
    case.rmdir()
    return state

EXPECTED_LOOPS = 48
EXPECTED_READY_SHA256 = '7aedf0063107a514c81a1573d529f2011fb0420febbbee72e2f5c9bfcceb1e77'


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source',type=Path);parser.add_argument('zig',type=Path);parser.add_argument('v',type=Path)
    parser.add_argument('--target',default='aarch64-macos.14.0');parser.add_argument('--v-prod',action='store_true')
    parser.add_argument('--workdir',type=Path);parser.add_argument('--timeout',type=int,default=180)
    args=parser.parse_args()
    if args.timeout<=0:parser.error('--timeout must be positive')
    source=args.source.resolve()/'src';zig=args.zig.resolve();v=args.v.resolve()
    if tree_hash(source)!=PINNED_SOURCE_SHA256 or stdlib_hash(zig)!=PINNED_STDLIB_SHA256 or encoder_library_hashes(zig)!=ENCODER_LIBRARIES or flate_hash(zig)!=PINNED_FLATE_SHA256 or path_library_hashes(zig)!=PATH_LIBRARIES:parser.error('Source or compiler library differs from pins')
    repo=Path(__file__).resolve().parent.parent;probe=repo/'zigimg/reference_probes/image_open'
    mode='ReleaseSafe' if args.v_prod else 'Debug'
    with work_directory(args.workdir,'witty-image-open-') as root:
        tmp=root/'tmp';tmp.mkdir();env=dict(os.environ,TMPDIR=str(tmp),VTMP=str(tmp),VEXE=str(v),V_C_ERROR_BUG_REPORT_DISABLED='1')
        proof=ProofLog(root);shutil.copytree(source,root/'src');fixtures={}
        for name in ('main.v','reference.zig','fixture_shims.h','fixture_shims.c'):
            shutil.copyfile(probe/name,root/name);fixtures[name]=hashlib.sha256((root/name).read_bytes()).hexdigest()
        versions=[proof.run([str(exe),'version'],label,env=env).stdout.decode().strip() for exe,label in ((zig,'zig-version'),(v,'v-version'))]
        if versions[0]!='0.15.2' or not re.match(r'^V 0\.5\.2(?: |$)',versions[1]):raise AssertionError('unexpected compiler versions')
        impl=implementation_hashes(repo);runner_hash=hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
        helpers={name:hashlib.sha256((repo/'zigimg'/name).read_bytes()).hexdigest() for name in ('verify_jpeg_contracts_reference.py','verify_tiff_decode_reference.py','verify_tga_decode_reference.py','verify_image_read_reference.py',*GENERATOR_HELPERS)}
        (root/'provenance.json').write_text(json.dumps(dict(source_sha256=PINNED_SOURCE_SHA256,stdlib_sha256=PINNED_STDLIB_SHA256,encoder_libraries=ENCODER_LIBRARIES,path_libraries=PATH_LIBRARIES,flate_sha256=PINNED_FLATE_SHA256,versions=versions,target=args.target,zig_mode=mode,v_prod=args.v_prod,implementation_sha256=impl,runner_sha256=runner_hash,fixtures=fixtures,helper_sha256=helpers),indent=2)+'\n')
        print(f'Building image open contracts: Source {mode}, V {"production" if args.v_prod else "ordinary"}',flush=True)
        proof.run([str(zig),'build-exe','-target',args.target,'-lc','-I',str(root),'-O',mode,'--global-cache-dir',str(root.parent/'zig-global'),'--cache-dir',str(root/'zig-cache'),'-femit-bin='+str(root/'native'),str(root/'reference.zig'),str(root/'fixture_shims.c')],'build-source',env=env,timeout=args.timeout)
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
        for (_,data),row in zip(rows,outputs[0]):snapshot_checks(row,data)
        if path.with_name(path.name+'.case').exists():raise AssertionError('owned directory cleanup failed')
        digest=hashlib.sha256(b'\n'.join(outputs[0])).hexdigest()
        if EXPECTED_ROWS is not None and (len(rows)!=EXPECTED_ROWS or digest!=EXPECTED_SHA256):raise AssertionError('returning golden changed')
        print(f'{len(rows)} returning records match; checking live flags and exec inheritance',flush=True)
        returns=hashlib.sha256();states=hashlib.sha256();return_groups=Counter();trap_groups=Counter()
        for group,name,data in controls():
            records=[]
            for exe in ('native','translated'):
                state=root/(name+'-'+exe+'.state')
                records.append((proof.run([str(root/exe),'--trap',str(state),data],name+'-'+exe,env=env,timeout=args.timeout,check=False),state))
            native,translated=records[0][0],records[1][0]
            if native.returncode==0:
                if native.stderr or translated.returncode or translated.stderr or native.stdout!=translated.stdout or len(native.stdout.splitlines())!=1:raise AssertionError(f'{name}: control return differs')
                snapshot_checks(native.stdout.strip(),data)
                returns.update(name.encode()+b'\0'+native.stdout);return_groups[group]+=1
            else:
                messages=[]
                for (result,state),exe in zip(records,('native','translated')):
                    found=[m.group(1) for line in result.stderr.decode().splitlines() if (m:=re.fullmatch(r'(?:thread \d+ |V )?panic:\s*(.*)',line.strip()))]
                    if len(found)!=1 or not re.fullmatch(r'reached unreachable code|integer overflow|index out of bounds: index \d+, len \d+',found[0]):raise AssertionError(f'{name}/{exe}: unexpected panic {found}')
                    checked_trap(result,name+'/'+exe,found[0]);messages.append(found[0])
                    if not state.exists():raise AssertionError('missing panic observer')
                if messages[0]!=messages[1]:raise AssertionError(f'{name}: exact panic differs: {messages}')
                observed=[state.read_bytes() for _,state in records]
                if not observed[0] or observed[0]!=observed[1]:raise AssertionError(f'{name}: failure state differs')
                if observed[0].split(b'|',1)[0]!=b'1:1:0:0':raise AssertionError('path writer must be write-only and closed on exec')
                if observed[0].split(b'|')[2]!=b'a5'*int(data.split('|')[3]):raise AssertionError('header panic changed caller buffer')
                states.update(name.encode()+b'\0'+messages[0].encode()+b'\0'+observed[0]+b'\n');trap_groups[group]+=1
        ready=hashlib.sha256()
        for name,data in loops():
            output=[bounded_loop(proof,root,exe,data,name+'-'+exe,env) for exe in ('native','translated')]
            if output[0]!=output[1]:raise AssertionError(f'{name}: read open flags or exec inheritance differ')
            kind=int(data.split('|')[5]);expected=f'1:0:0:0|{1 if kind==2 else 0}:416'.encode()
            if output[0]!=expected:raise AssertionError('reader must be read-only and closed on exec')
            ready.update(name.encode()+b'\0'+output[0])
        if EXPECTED_LOOPS is not None and (len(loops())!=EXPECTED_LOOPS or ready.hexdigest()!=EXPECTED_READY_SHA256):raise AssertionError('loop descriptor golden changed')
        if list(root.glob('*.case')):raise AssertionError('owned directory observer cleanup failed')
        controls_digest=returns.hexdigest();state_digest=states.hexdigest()
        if EXPECTED_CONTROLS is not None and (sum(return_groups.values())!=EXPECTED_CONTROLS or controls_digest!=EXPECTED_CONTROL_SHA256):raise AssertionError('return controls changed')
        if EXPECTED_TRAPS is not None and (sum(trap_groups.values())!=EXPECTED_TRAPS or state_digest!=EXPECTED_STATE_SHA256):raise AssertionError('failure golden changed')
        if tree_hash(source)!=PINNED_SOURCE_SHA256 or tree_hash(root/'src')!=PINNED_SOURCE_SHA256 or stdlib_hash(zig)!=PINNED_STDLIB_SHA256 or encoder_library_hashes(zig)!=ENCODER_LIBRARIES or flate_hash(zig)!=PINNED_FLATE_SHA256 or path_library_hashes(zig)!=PATH_LIBRARIES or implementation_hashes(repo)!=impl or hashlib.sha256(Path(__file__).read_bytes()).hexdigest()!=runner_hash:raise AssertionError('dependency, implementation or runner changed')
        for name,expected in fixtures.items():
            if any(hashlib.sha256((base/name).read_bytes()).hexdigest()!=expected for base in (root,probe)):raise AssertionError('fixture changed')
        for name,expected in inputs.items():
            if hashlib.sha256((root/name).read_bytes()).hexdigest()!=expected:raise AssertionError('input changed')
        for name,expected in helpers.items():
            if hashlib.sha256((repo/'zigimg'/name).read_bytes()).hexdigest()!=expected:raise AssertionError('helper changed')
        summary=dict(returning_records=len(rows),calls=sum(int(data.split('|')[8]) for _,data in rows),returning_groups=dict(Counter(group for group,_ in rows)),output_sha256=digest,return_controls=sum(return_groups.values()),return_control_groups=dict(return_groups),control_sha256=controls_digest,paired_traps=sum(trap_groups.values()),failure_groups=dict(trap_groups),state_sha256=state_digest,paired_loops=len(loops()),ready_sha256=ready.hexdigest(),zig_mode=mode,v_prod=args.v_prod)
        (root/'summary.json').write_text(json.dumps(summary,indent=2)+'\n');print(json.dumps(summary),flush=True)


if __name__=='__main__':main()
