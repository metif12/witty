"""Compare public image pseudo-terminals, controlling sessions and streaming IO."""
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

EXPECTED_ROWS = 853
EXPECTED_SHA256 = '40d7262b0449afa7959e672e0defc768b9595731d55de42dd441ac36c9fe8ca5'
EXPECTED_CONTROLS = 12
EXPECTED_CONTROL_SHA256 = '63d9ebf8c8fd649b7b5e01762b386b24e84c4dee24b2ad4f111dc41987fde49f'
EXPECTED_TRAPS = 22
EXPECTED_STATE_SHA256 = '05b5e362cc894a4db7146b09e2fa335cb27d80ee5399e5d176208c155c4216de'
from verify_image_read_reference import GENERATOR_HELPERS, flate_hash, PINNED_FLATE_SHA256
from verify_image_open_reference import PATH_LIBRARIES, path_library_hashes


def spec(op=0, fmt=9, profile=1, variant=0, cap=8, managed=0, shape=0, attempts=2, seed=b''):
    return '|'.join(map(str,(op,fmt,profile,variant,cap,managed,shape,attempts,seed.hex())))


def corpus():
    rows=[('tty-writer',spec(fmt=fmt,profile=profile,cap=cap,managed=managed)) for fmt,profile,cap,managed in itertools.product(range(17),range(8),(0,8,32),range(2))]
    rows += [('tty-reader',spec(op=op,cap=cap,managed=managed,seed=seed)) for op,cap,managed,seed in itertools.product((1,2),(0,8,32),range(2),(b'',b'\x89PNG\r\n\x1a\n'))]
    rows += [('direct-slice-reader',spec(op=3,fmt=count,cap=cap,attempts=1,seed=b'\x89PNG\r\n\x1a\n')) for count,cap in itertools.product((0,1,7),(0,8,32))]
    rows += [('direct-buffered-reader',spec(op=4,fmt=count,cap=cap,attempts=1,seed=b'\x89PNG\r\n\x1a\n')) for count,cap in itertools.product((1,7),(8,32))]
    return rows


def controls():
    rows=[('png-header',spec(fmt=9,profile=profile,cap=cap,managed=managed,shape=1,attempts=1)) for profile,cap,managed in itertools.product((1,3,7),(0,8,32),range(2))]
    rows += [('tga-short',spec(fmt=14,profile=profile,cap=cap,managed=managed,shape=3,attempts=1)) for profile,cap,managed in itertools.product((1,2,3,4),(8,32),range(2))]
    return [(group,f'control-{i}',data) for i,(group,data) in enumerate(rows)]


def snapshot_checks(line,data,mutated=False):
    f=list(data.split('|'));op=int(f[0]);parts=line.decode().split('~')
    if len(parts)!=int(f[7])+2 or parts[-1]!='':raise AssertionError('missing terminal snapshots')
    states=[parts[0],*(part.split('|',1)[1] for part in parts[1:-1])]
    for i,state in enumerate(states):
        tty=0 if i==0 or op>2 else (int(op!=0) if mutated else int(op==0))
        if state.split('|')[0]!=f'{tty}:1:1:{-3 if i==0 else -1}:{-3 if i==0 else -1}':
            raise AssertionError('controlling tty, session ownership, descriptor cleanup or drain differs')
        if i and op in (1,2) and (state.split('|')[1]!='a5'*int(f[4]) or parts[i].split('|')[0]!='Unseekable:-' or state.split('|')[5]!=f[8]):
            raise AssertionError('public tty readers must reject their initial seek without consumption')


def mutation_cases():
    return [spec(op=op,managed=managed,seed=b'\x89PNG\r\n\x1a\n' if op else b'') for op,managed in itertools.product(range(3),range(2))]

EXPECTED_CALIBRATION_SHA256 = '2cbdabd5f026297bde9cc44955d1780d728107a3107587945ed2c81b20313c3a'
EXPECTED_MUTATION_SHA256 = '750d69c6f91b50c1678d39c69d66971c22d47d5f3f91a1e28cfd523f41b7fb91'


def mutation_build(proof,root,repo,impl,v,prod,env,timeout):
    copied=root/'reversed-noctty-module'
    for name in impl:
        target=copied/name;target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(repo/name,target)
    shutil.copyfile(repo/'v.mod',copied/'v.mod')
    target=copied/'zigimg/file_io_shims.h';original=target.read_text();branch='if (!writing) flags |= O_NOCTTY;'
    if original.count(branch)!=1:raise AssertionError('NOCTTY branch differs')
    target.write_text(original.replace(branch,'if (writing) flags |= O_NOCTTY;'))
    (root/'mutation_sha256.json').write_text(json.dumps(implementation_hashes(copied),indent=2)+'\n')
    proof.run([str(v),'-enable-globals',*(['-prod'] if prod else []),'-path',f'{copied}|{repo}|@vlib|@vmodules','-o',str(root/'reversed-noctty'),str(root/'main.v')],'build-reversed-noctty-v',env=env,timeout=timeout)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source',type=Path);parser.add_argument('zig',type=Path);parser.add_argument('v',type=Path)
    parser.add_argument('--target',default='aarch64-macos.14.0');parser.add_argument('--v-prod',action='store_true')
    parser.add_argument('--workdir',type=Path);parser.add_argument('--timeout',type=int,default=600)
    args=parser.parse_args()
    if args.timeout<=0:parser.error('--timeout must be positive')
    source=args.source.resolve()/'src';zig=args.zig.resolve();v=args.v.resolve()
    if tree_hash(source)!=PINNED_SOURCE_SHA256 or stdlib_hash(zig)!=PINNED_STDLIB_SHA256 or encoder_library_hashes(zig)!=ENCODER_LIBRARIES or flate_hash(zig)!=PINNED_FLATE_SHA256 or path_library_hashes(zig)!=PATH_LIBRARIES:parser.error('Source or compiler library differs from pins')
    repo=Path(__file__).resolve().parent.parent;probe=repo/'zigimg/reference_probes/image_tty'
    mode='ReleaseSafe' if args.v_prod else 'Debug'
    with work_directory(args.workdir,'witty-image-tty-') as root:
        tmp=root/'tmp';tmp.mkdir();env=dict(os.environ,TMPDIR=str(tmp),VTMP=str(tmp),VEXE=str(v),V_C_ERROR_BUG_REPORT_DISABLED='1')
        proof=ProofLog(root);shutil.copytree(source,root/'src');fixtures={}
        for name in ('main.v','reference.zig','fixture_shims.h','fixture_shims.c'):
            shutil.copyfile(probe/name,root/name);fixtures[name]=hashlib.sha256((root/name).read_bytes()).hexdigest()
        versions=[proof.run([str(exe),'version'],label,env=env).stdout.decode().strip() for exe,label in ((zig,'zig-version'),(v,'v-version'))]
        if versions[0]!='0.15.2' or not re.match(r'^V 0\.5\.2(?: |$)',versions[1]):raise AssertionError('unexpected compiler versions')
        impl=implementation_hashes(repo);runner_hash=hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
        helpers={name:hashlib.sha256((repo/'zigimg'/name).read_bytes()).hexdigest() for name in ('verify_jpeg_contracts_reference.py','verify_tiff_decode_reference.py','verify_tga_decode_reference.py','verify_image_read_reference.py','verify_image_open_reference.py',*GENERATOR_HELPERS)}
        (root/'provenance.json').write_text(json.dumps(dict(source_sha256=PINNED_SOURCE_SHA256,stdlib_sha256=PINNED_STDLIB_SHA256,encoder_libraries=ENCODER_LIBRARIES,path_libraries=PATH_LIBRARIES,flate_sha256=PINNED_FLATE_SHA256,versions=versions,target=args.target,zig_mode=mode,v_prod=args.v_prod,implementation_sha256=impl,runner_sha256=runner_hash,fixtures=fixtures,helper_sha256=helpers),indent=2)+'\n')
        print(f'Building image terminal contracts: Source {mode}, V {"production" if args.v_prod else "ordinary"}',flush=True)
        proof.run([str(zig),'build-exe','-target',args.target,'-lc','-I',str(root),'-O',mode,'--global-cache-dir',str(root.parent/'zig-global'),'--cache-dir',str(root/'zig-cache'),'-femit-bin='+str(root/'native'),str(root/'reference.zig'),str(root/'fixture_shims.c')],'build-source',env=env,timeout=args.timeout)
        proof.run([str(v),'-enable-globals',*(['-prod'] if args.v_prod else []),'-path',f'{repo}|@vlib|@vmodules','-o',str(root/'translated'),str(root/'main.v')],'build-v',env=env,timeout=args.timeout)
        calibration=hashlib.sha256()
        for writing,noctty in itertools.product(range(2),range(2)):
            outputs=[]
            for exe in ('native','translated'):
                result=proof.run([str(root/exe),'--calibrate',str(writing),str(noctty)],f'calibrate-{writing}-{noctty}-{exe}',env=env,timeout=args.timeout)
                expected=f'{writing}:{noctty}|{1-noctty}:{1-noctty}:1:1\n'.encode()
                if result.stderr or result.stdout!=expected:raise AssertionError('actual terminal open/close or ENXIO calibration differs')
                outputs.append(result.stdout)
            calibration.update(outputs[0])
        calibration_digest=calibration.hexdigest()
        if EXPECTED_CALIBRATION_SHA256 is not None and calibration_digest!=EXPECTED_CALIBRATION_SHA256:raise AssertionError('calibration golden changed')
        rows=corpus();path=root/'corpus.txt';path.write_text('\n'.join(data for _,data in rows)+'\n')
        mutation_path=root/'mutation.txt';mutation_path.write_text('\n'.join(mutation_cases())+'\n')
        inputs={name:hashlib.sha256((root/name).read_bytes()).hexdigest() for name in ('corpus.txt','mutation.txt')}
        (root/'input_sha256.json').write_text(json.dumps(inputs,indent=2)+'\n')
        observed=[]
        for i,(group,data) in enumerate(rows):
            outputs=[]
            for exe in ('native','translated'):
                r=proof.run([str(root/exe),data],f'row-{i}-{exe}',env=env,timeout=args.timeout)
                if r.stderr or len(r.stdout.splitlines())!=1:raise AssertionError('invalid terminal returning record')
                outputs.append(r.stdout.strip())
            if outputs[0]!=outputs[1]:raise AssertionError(f'{i}/{group}: terminal record differs; see retained proof')
            snapshot_checks(outputs[0],data);observed.append(outputs[0])
        digest=hashlib.sha256(b'\n'.join(observed)).hexdigest()
        if EXPECTED_ROWS is not None and (len(rows)!=EXPECTED_ROWS or digest!=EXPECTED_SHA256):raise AssertionError('returning golden changed')
        mutation_build(proof,root,repo,impl,v,args.v_prod,env,args.timeout)
        mutated=hashlib.sha256()
        for i,data in enumerate(mutation_cases()):
            result=proof.run([str(root/'reversed-noctty'),data],f'mutation-{i}',env=env,timeout=args.timeout)
            if result.stderr or len(result.stdout.splitlines())!=1:raise AssertionError('invalid NOCTTY control')
            snapshot_checks(result.stdout.strip(),data,mutated=True);mutated.update(result.stdout)
        mutation_digest=mutated.hexdigest()
        if EXPECTED_MUTATION_SHA256 is not None and mutation_digest!=EXPECTED_MUTATION_SHA256:raise AssertionError('NOCTTY control changed')
        print(f'{len(rows)} returning records match; checking terminal failure ownership',flush=True)
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
                if observed[0].split(b'|',1)[0]!=b'1:1:2:-1:-1':raise AssertionError('panic must retain the open path descriptor before process exit')
                states.update(name.encode()+b'\0'+messages[0].encode()+b'\0'+observed[0]+b'\n');trap_groups[group]+=1

        controls_digest=returns.hexdigest();state_digest=states.hexdigest()
        if EXPECTED_CONTROLS is not None and (sum(return_groups.values())!=EXPECTED_CONTROLS or controls_digest!=EXPECTED_CONTROL_SHA256):raise AssertionError('return controls changed')
        if EXPECTED_TRAPS is not None and (sum(trap_groups.values())!=EXPECTED_TRAPS or state_digest!=EXPECTED_STATE_SHA256):raise AssertionError('failure golden changed')
        if tree_hash(source)!=PINNED_SOURCE_SHA256 or tree_hash(root/'src')!=PINNED_SOURCE_SHA256 or stdlib_hash(zig)!=PINNED_STDLIB_SHA256 or encoder_library_hashes(zig)!=ENCODER_LIBRARIES or flate_hash(zig)!=PINNED_FLATE_SHA256 or path_library_hashes(zig)!=PATH_LIBRARIES or implementation_hashes(repo)!=impl or hashlib.sha256(Path(__file__).read_bytes()).hexdigest()!=runner_hash:raise AssertionError('dependency, implementation or runner changed')
        if {name for name in impl if implementation_hashes(root/'reversed-noctty-module')[name]!=impl[name]}!={'zigimg/file_io_shims.h'}:raise AssertionError('NOCTTY control changed another implementation file')
        for name,expected in fixtures.items():
            if any(hashlib.sha256((base/name).read_bytes()).hexdigest()!=expected for base in (root,probe)):raise AssertionError('fixture changed')
        for name,expected in inputs.items():
            if hashlib.sha256((root/name).read_bytes()).hexdigest()!=expected:raise AssertionError('input changed')
        for name,expected in helpers.items():
            if hashlib.sha256((repo/'zigimg'/name).read_bytes()).hexdigest()!=expected:raise AssertionError('helper changed')
        summary=dict(calibration_sha256=calibration_digest,mutation_records=len(mutation_cases()),mutation_sha256=mutation_digest,returning_records=len(rows),calls=sum(int(data.split('|')[7]) for _,data in rows),returning_groups=dict(Counter(group for group,_ in rows)),output_sha256=digest,return_controls=sum(return_groups.values()),return_control_groups=dict(return_groups),control_sha256=controls_digest,paired_traps=sum(trap_groups.values()),failure_groups=dict(trap_groups),state_sha256=state_digest,zig_mode=mode,v_prod=args.v_prod)
        (root/'summary.json').write_text(json.dumps(summary,indent=2)+'\n');print(json.dumps(summary),flush=True)


if __name__=='__main__':main()
