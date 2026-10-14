"""Compare public image path validation, open failures and retained state."""
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

ENCODER_LIBRARIES = {'simd.zig': 'cc554020cebe55782b38c18c56a011b61a42f332781e5d0a5b1be3003eddd7a3', 'math.zig': '65645001357d5f78cbf646485e009a048b828680bb1b47fb3de0fd8617d91af1'}

def encoder_library_hashes(zig):
    return {name: hashlib.sha256((zig.parent/'lib/std'/name).read_bytes()).hexdigest() for name in ENCODER_LIBRARIES}

EXPECTED_ROWS = 12160
EXPECTED_SHA256 = '36bd463ce8ce5ec452f0bea5e38b2860f818add39d93a90f480d9faf6cdf14b9'
EXPECTED_CONTROLS = 264
EXPECTED_CONTROL_SHA256 = 'd55f7627c54b82fc41b7d0986561a18bd6458c5a56c48f5d58df1d6bb7a79e0b'
EXPECTED_TRAPS = 224
EXPECTED_STATE_SHA256 = '681998441896c2156e3191f21f6eba9a40b8f7c06e5f4b58916833286c207117'
PATH_LIBRARIES = {'fs/Dir.zig': '46ccade4f81b6bd772459d801a955a7cf417d77d2052fb38ddacfc65b3ed25f6', 'c.zig': 'a8138d10955a61fae402e1235e81685732f46e4cacca1e922609034183824bb1', 'c/darwin.zig': '4565e4abbe32fa6cdbdcee67d52376dacee82aa7c489d0048e509663500358c9'}

def path_library_hashes(zig):
    return {name: hashlib.sha256((zig.parent/'lib/std'/name).read_bytes()).hexdigest() for name in PATH_LIBRARIES}

from verify_image_read_reference import examples, GENERATOR_HELPERS, flate_hash, PINNED_FLATE_SHA256


def spec(op, fmt=0, profile=1, cap=8, managed=0, kind=0, attempts=2, shape=0):
    return '|'.join(map(str,(op,fmt,profile,cap,managed,kind,attempts,shape)))


def corpus():
    rows=[]
    for fmt,profile,cap,managed,kind in itertools.product(range(17),range(8),(0,1,8,32),range(2),(*range(10),15)):
        rows.append(('open-before-encoder',spec(0,fmt,profile,cap,managed,kind)))
    for op,cap,managed,kind in itertools.product((1,2),(0,1,8,32),range(2),(*range(11),15)):
        rows.append(('open-before-reader',spec(op,cap=cap,managed=managed,kind=kind)))
    return rows


def controls():
    cases=[]
    for fmt,profile,cap,managed,kind,shape in itertools.product((9,14),(1,3,7),(0,8),range(2),range(11,15),(0,1)):
        cases.append(('nul-before-encoder',f'control-{len(cases)}',spec(0,fmt,profile,cap,managed,kind,1,shape)))
    for op,cap,managed,kind in itertools.product((1,2),(0,8),range(2),range(11,15)):
        cases.append(('nul-before-reader',f'control-{len(cases)}',spec(op,cap=cap,managed=managed,kind=kind,attempts=1)))
    for fmt,profile,cap,managed,kind in itertools.product((9,14),(1,3,7),(0,8),range(2),(*range(10),15)):
        cases.append(('open-before-zero-extents',f'control-{len(cases)}',spec(0,fmt,profile,cap,managed,kind,1,1)))
    return cases


SEED_HEX='6661726266656c64000000010000000100130038005dffff'

def snapshot_checks(line, kind):
    parts=line.decode().split('~')
    snapshots=[parts[0],*(part.split('|',1)[1] for part in parts[1:-1])]
    for state in snapshots:
        fields=state.split('|')
        if fields[0]!=f'1:0:{0 if kind==3 else 384}' or fields[-1]!=SEED_HEX:
            raise AssertionError('descriptor cleanup, permissions or retained disk changed')
    if any(state!=snapshots[0] for state in snapshots):
        raise AssertionError('path failure changed caller buffer or image state')


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source',type=Path);parser.add_argument('zig',type=Path);parser.add_argument('v',type=Path)
    parser.add_argument('--target',default='aarch64-macos.14.0');parser.add_argument('--v-prod',action='store_true')
    parser.add_argument('--workdir',type=Path);parser.add_argument('--timeout',type=int,default=180)
    args=parser.parse_args()
    if args.timeout<=0:parser.error('--timeout must be positive')
    source=args.source.resolve()/'src';zig=args.zig.resolve();v=args.v.resolve()
    if tree_hash(source)!=PINNED_SOURCE_SHA256 or stdlib_hash(zig)!=PINNED_STDLIB_SHA256 or encoder_library_hashes(zig)!=ENCODER_LIBRARIES or flate_hash(zig)!=PINNED_FLATE_SHA256 or path_library_hashes(zig)!=PATH_LIBRARIES:parser.error('Source or compiler library differs from pins')
    repo=Path(__file__).resolve().parent.parent;probe=repo/'zigimg/reference_probes/image_path'
    mode='ReleaseSafe' if args.v_prod else 'Debug'
    with work_directory(args.workdir,'witty-image-path-') as root:
        tmp=root/'tmp';tmp.mkdir();env=dict(os.environ,TMPDIR=str(tmp),VTMP=str(tmp),VEXE=str(v),V_C_ERROR_BUG_REPORT_DISABLED='1')
        proof=ProofLog(root);shutil.copytree(source,root/'src');fixtures={}
        for name in ('main.v','reference.zig','fixture_shims.h','fixture_shims.c'):
            shutil.copyfile(probe/name,root/name);fixtures[name]=hashlib.sha256((root/name).read_bytes()).hexdigest()
        versions=[proof.run([str(exe),'version'],label,env=env).stdout.decode().strip() for exe,label in ((zig,'zig-version'),(v,'v-version'))]
        if versions[0]!='0.15.2' or not re.match(r'^V 0\.5\.2(?: |$)',versions[1]):raise AssertionError('unexpected compiler versions')
        impl=implementation_hashes(repo);runner_hash=hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
        helpers={name:hashlib.sha256((repo/'zigimg'/name).read_bytes()).hexdigest() for name in ('verify_jpeg_contracts_reference.py','verify_tiff_decode_reference.py','verify_tga_decode_reference.py','verify_image_read_reference.py',*GENERATOR_HELPERS)}
        (root/'provenance.json').write_text(json.dumps(dict(source_sha256=PINNED_SOURCE_SHA256,stdlib_sha256=PINNED_STDLIB_SHA256,encoder_libraries=ENCODER_LIBRARIES,path_libraries=PATH_LIBRARIES,flate_sha256=PINNED_FLATE_SHA256,versions=versions,target=args.target,zig_mode=mode,v_prod=args.v_prod,implementation_sha256=impl,runner_sha256=runner_hash,fixtures=fixtures,helper_sha256=helpers),indent=2)+'\n')
        print(f'Building image path failures: Source {mode}, V {"production" if args.v_prod else "ordinary"}',flush=True)
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
        for (_,data),row in zip(rows,outputs[0]):snapshot_checks(row,int(data.split('|')[5]))
        if path.with_name(path.name+'.case').exists():raise AssertionError('owned directory cleanup failed')
        digest=hashlib.sha256(b'\n'.join(outputs[0])).hexdigest()
        if EXPECTED_ROWS is not None and (len(rows)!=EXPECTED_ROWS or digest!=EXPECTED_SHA256):raise AssertionError('returning golden changed')
        print(f'{len(rows)} returning records match; checking embedded NUL precedence',flush=True)
        returns=hashlib.sha256();states=hashlib.sha256();return_groups=Counter();trap_groups=Counter()
        for group,name,data in controls():
            records=[]
            for exe in ('native','translated'):
                state=root/(name+'-'+exe+'.state')
                records.append((proof.run([str(root/exe),'--trap',str(state),data],name+'-'+exe,env=env,timeout=args.timeout,check=False),state))
            native,translated=records[0][0],records[1][0]
            if native.returncode==0:
                if native.stderr or translated.returncode or translated.stderr or native.stdout!=translated.stdout or len(native.stdout.splitlines())!=1:raise AssertionError(f'{name}: control return differs')
                snapshot_checks(native.stdout.strip(),int(data.split('|')[5]))
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
                if observed[0].split(b'|',1)[0]!=b'1:0:384' or observed[0].split(b'|')[-1].decode()!=SEED_HEX:raise AssertionError('NUL panic changed owned descriptors or disk')
                if observed[0].split(b'|')[1]!=b'a5'*int(data.split('|')[3]):raise AssertionError('NUL panic changed caller buffer')
                states.update(name.encode()+b'\0'+messages[0].encode()+b'\0'+observed[0]+b'\n');trap_groups[group]+=1
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
        summary=dict(returning_records=len(rows),calls=sum(int(data.split('|')[6]) for _,data in rows),returning_groups=dict(Counter(group for group,_ in rows)),output_sha256=digest,return_controls=sum(return_groups.values()),return_control_groups=dict(return_groups),control_sha256=controls_digest,paired_traps=sum(trap_groups.values()),failure_groups=dict(trap_groups),state_sha256=state_digest,zig_mode=mode,v_prod=args.v_prod)
        (root/'summary.json').write_text(json.dumps(summary,indent=2)+'\n');print(json.dumps(summary),flush=True)


if __name__=='__main__':main()
