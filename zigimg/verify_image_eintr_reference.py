"""Compare interrupted public image FIFO opens with actual targeted POSIX signals."""
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

EXPECTED_ROWS = 1680
EXPECTED_SHA256 = '855b29bfcdac9879e3c326cfc1a4a93316af1dbac5fa724da4af9709a4fc6119'
EXPECTED_CONTROLS = 24
EXPECTED_CONTROL_SHA256 = 'f58555e192da9baed2431dab4a4100caa79f84584820ce73601ac3e2aeca5fc8'
EXPECTED_TRAPS = 44
EXPECTED_STATE_SHA256 = '60b7a7c09a3d40b4c7a6c5ef31f1e7cf4aa51d909a559fd9d4a8abc39fc3c1d2'
from verify_image_read_reference import GENERATOR_HELPERS, flate_hash, PINNED_FLATE_SHA256
from verify_image_open_reference import PATH_LIBRARIES, path_library_hashes


def spec(op=0, fmt=9, profile=1, variant=0, cap=8, managed=0, shape=0, attempts=2, seed=b'', signals=1):
    return '|'.join(map(str,(op,fmt,profile,variant,cap,managed,shape,attempts,seed.hex(),signals)))


def corpus():
    rows=[('interrupted-writer',spec(fmt=fmt,profile=profile,cap=cap,managed=managed,signals=signals)) for fmt,profile,cap,managed,signals in itertools.product(range(17),range(8),(0,8,32),range(2),(1,3))]
    for op,cap,managed,signals,seed in itertools.product((1,2),(0,8,32),range(2),(1,3),(b'',b'\x89PNG\r\n\x1a\n')):
        rows.append(('interrupted-reader',spec(op=op,cap=cap,managed=managed,signals=signals,seed=seed)))
    return rows


def controls():
    cases=[]
    for profile,cap,managed,signals in itertools.product((1,3,7),(0,8,32),range(2),(1,3)):
        cases.append(('png-header',f'control-{len(cases)}',spec(fmt=9,profile=profile,cap=cap,managed=managed,signals=signals,shape=1,attempts=1)))
    for profile,cap,managed,signals in itertools.product((1,2,3,4),(8,32),range(2),(1,3)):
        cases.append(('tga-short-storage',f'control-{len(cases)}',spec(fmt=14,profile=profile,cap=cap,managed=managed,signals=signals,shape=3,attempts=1)))
    return cases


def signal_checks(state, signals, early=0):
    if state != f'{signals}:{early}:0:1:1:0':
        raise AssertionError('signal deliveries, pending open, inode references or restored handler/mask differ: '+state)


def snapshot_checks(line, data):
    parts=line.decode().split('~');f=data.split('|');signals=int(f[9])
    if parts[0].split('|')[0]!='1:0:0:-3' or parts[0].split('|')[-1]!='0:0:0:0:0:0':
        raise AssertionError('initial FIFO must have no open descriptors or signal worker')
    for part in parts[1:-1]:
        state=part.split('|',1)[1].split('|')
        if state[0]!='1:1:1:-1':raise AssertionError('returned FIFO must retain only the worker keeper')
        signal_checks(state[-1],signals)
        if int(f[0])>0 and (state[1] != 'a5'*int(f[4]) or part.split('|')[0]!='Unseekable:-'):
            raise AssertionError('initial rejected seek must leave the caller buffer untouched')


def calibration_checks(output):
    expected=[f'{writing}:{signals}|1|{signals}:1:0:1:1:0' for writing in range(2) for signals in (1,3)]
    if output.decode().splitlines()!=expected:raise AssertionError('actual no-retry libc open did not establish EINTR')

EXPECTED_CALIBRATION_SHA256 = 'f8b0982971a5d9dbb2ba5befbedab4ebd0ae646dfc20ed216da7d235b89617c5'
EXPECTED_MUTATION_SHA256 = '1f0593c557c9936967d064c271760a0ac2269d94603838600a2f59d6aa7bbb4a'


def mutation_cases():
    return [spec(op=op,managed=managed,signals=signals) for op,managed,signals in itertools.product(range(3),range(2),(1,3))]


def mutation_checks(output, rows):
    lines=output.splitlines()
    if len(lines)!=len(rows):raise AssertionError('missing no-retry control records')
    for data,line in zip(rows,lines):
        f=data.split('|')
        for part in line.decode().split('~')[1:-1]:
            state=part.split('|',1)[1].split('|')
            if part.split('|')[0]!='Unexpected:-' or state[0]!='1:1:1:-1' or state[1]!='a5'*int(f[4]) or state[-2]!='':
                raise AssertionError('no-retry control must return before codec dispatch with unchanged buffers')
            signal_checks(state[-1],int(f[9]),early=1)


def no_retry_control(proof, root, repo, impl, v, prod, env, timeout):
    copied=root/'no-retry-module'
    for name in impl:
        target=copied/name;target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(repo/name,target)
    shutil.copyfile(repo/'v.mod',copied/'v.mod')
    target=copied/'zigimg/io_paths.v';original=target.read_text()
    branch='if C.witty_image_file_open_interrupted(saved_error) == 1 { continue'
    if original.count(branch)!=1:raise AssertionError('retry branch differs from the mutation pin')
    target.write_text(original.replace(branch,'if false { continue'))
    mutated=implementation_hashes(copied)
    if {name for name in impl if impl[name]!=mutated[name]}!={'zigimg/io_paths.v'}:raise AssertionError('no-retry control changed another implementation file')
    (root/'mutation_sha256.json').write_text(json.dumps(mutated,indent=2)+'\n')
    proof.run([str(v),'-enable-globals',*(['-prod'] if prod else []),'-path',f'{copied}|{repo}|@vlib|@vmodules','-o',str(root/'no-retry'),str(root/'main.v')],'build-no-retry-v',env=env,timeout=timeout)
    rows=mutation_cases();path=root/'mutation.txt';path.write_text('\n'.join(rows)+'\n')
    result=proof.run([str(root/'no-retry'),str(path)],'no-retry-control',env=env,timeout=timeout)
    if result.stderr:raise AssertionError('no-retry control emitted diagnostics')
    mutation_checks(result.stdout,rows)
    digest=hashlib.sha256(b'\n'.join(result.stdout.splitlines())).hexdigest()
    if EXPECTED_MUTATION_SHA256 is not None and digest!=EXPECTED_MUTATION_SHA256:raise AssertionError('no-retry control changed')
    return digest


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source',type=Path);parser.add_argument('zig',type=Path);parser.add_argument('v',type=Path)
    parser.add_argument('--target',default='aarch64-macos.14.0');parser.add_argument('--v-prod',action='store_true')
    parser.add_argument('--workdir',type=Path);parser.add_argument('--timeout',type=int,default=600)
    args=parser.parse_args()
    if args.timeout<=0:parser.error('--timeout must be positive')
    source=args.source.resolve()/'src';zig=args.zig.resolve();v=args.v.resolve()
    if tree_hash(source)!=PINNED_SOURCE_SHA256 or stdlib_hash(zig)!=PINNED_STDLIB_SHA256 or encoder_library_hashes(zig)!=ENCODER_LIBRARIES or flate_hash(zig)!=PINNED_FLATE_SHA256 or path_library_hashes(zig)!=PATH_LIBRARIES:parser.error('Source or compiler library differs from pins')
    repo=Path(__file__).resolve().parent.parent;probe=repo/'zigimg/reference_probes/image_eintr'
    mode='ReleaseSafe' if args.v_prod else 'Debug'
    with work_directory(args.workdir,'witty-image-eintr-') as root:
        tmp=root/'tmp';tmp.mkdir();env=dict(os.environ,TMPDIR=str(tmp),VTMP=str(tmp),VEXE=str(v),V_C_ERROR_BUG_REPORT_DISABLED='1')
        proof=ProofLog(root);shutil.copytree(source,root/'src');fixtures={}
        for name in ('main.v','reference.zig','fixture_shims.h','fixture_shims.c'):
            shutil.copyfile(probe/name,root/name);fixtures[name]=hashlib.sha256((root/name).read_bytes()).hexdigest()
        versions=[proof.run([str(exe),'version'],label,env=env).stdout.decode().strip() for exe,label in ((zig,'zig-version'),(v,'v-version'))]
        if versions[0]!='0.15.2' or not re.match(r'^V 0\.5\.2(?: |$)',versions[1]):raise AssertionError('unexpected compiler versions')
        impl=implementation_hashes(repo);runner_hash=hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
        helpers={name:hashlib.sha256((repo/'zigimg'/name).read_bytes()).hexdigest() for name in ('verify_jpeg_contracts_reference.py','verify_tiff_decode_reference.py','verify_tga_decode_reference.py','verify_image_read_reference.py','verify_image_open_reference.py',*GENERATOR_HELPERS)}
        (root/'provenance.json').write_text(json.dumps(dict(source_sha256=PINNED_SOURCE_SHA256,stdlib_sha256=PINNED_STDLIB_SHA256,encoder_libraries=ENCODER_LIBRARIES,path_libraries=PATH_LIBRARIES,flate_sha256=PINNED_FLATE_SHA256,versions=versions,target=args.target,zig_mode=mode,v_prod=args.v_prod,implementation_sha256=impl,runner_sha256=runner_hash,fixtures=fixtures,helper_sha256=helpers),indent=2)+'\n')
        print(f'Building interrupted image FIFO opens: Source {mode}, V {"production" if args.v_prod else "ordinary"}',flush=True)
        proof.run([str(zig),'build-exe','-target',args.target,'-lc','-I',str(root),'-O',mode,'--global-cache-dir',str(root.parent/'zig-global'),'--cache-dir',str(root/'zig-cache'),'-femit-bin='+str(root/'native'),str(root/'reference.zig'),str(root/'fixture_shims.c')],'build-source',env=env,timeout=args.timeout)
        proof.run([str(v),'-enable-globals',*(['-prod'] if args.v_prod else []),'-path',f'{repo}|@vlib|@vmodules','-o',str(root/'translated'),str(root/'main.v')],'build-v',env=env,timeout=args.timeout)
        calibration=[]
        for exe in ('native','translated'):
            result=proof.run([str(root/exe),'--calibrate',str(root/('calibration-'+exe))],'calibrate-'+exe,env=env,timeout=args.timeout)
            if result.stderr:raise AssertionError('calibration emitted diagnostics')
            calibration_checks(result.stdout);calibration.append(result.stdout)
        if calibration[0]!=calibration[1]:raise AssertionError('calibrations differ')
        calibration_digest=hashlib.sha256(calibration[0]).hexdigest()
        if EXPECTED_CALIBRATION_SHA256 is not None and calibration_digest!=EXPECTED_CALIBRATION_SHA256:raise AssertionError('calibration changed')
        mutation_digest=no_retry_control(proof,root,repo,impl,v,args.v_prod,env,args.timeout)
        rows=corpus();path=root/'corpus.txt';path.write_text('\n'.join(data for _,data in rows)+'\n')
        inputs={name:hashlib.sha256((root/name).read_bytes()).hexdigest() for name in ('corpus.txt','mutation.txt')}
        (root/'input_sha256.json').write_text(json.dumps(inputs,indent=2)+'\n')
        outputs=[]
        for exe in ('native','translated'):
            r=proof.run([str(root/exe),str(path)],'returning-'+exe,env=env,timeout=args.timeout,check=False)
            if r.returncode or r.stderr or len(r.stdout.splitlines())!=len(rows):raise AssertionError(f'{exe}: invalid returning output; see raw proof files')
            outputs.append(r.stdout.splitlines())
        for i,(native,translated) in enumerate(zip(*outputs)):
            if native!=translated:raise AssertionError(f'{i}/{rows[i][0]}: output differs; see raw proof files')
        for (_,data),row in zip(rows,outputs[0]):snapshot_checks(row,data)
        if path.with_name(path.name+'.fifo').exists():raise AssertionError('FIFO cleanup failed')
        digest=hashlib.sha256(b'\n'.join(outputs[0])).hexdigest()
        if EXPECTED_ROWS is not None and (len(rows)!=EXPECTED_ROWS or digest!=EXPECTED_SHA256):raise AssertionError('returning golden changed')
        print(f'{len(rows)} returning records match; checking failures after interrupted opens',flush=True)
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
                if observed[0].split(b'|',1)[0]!=b'1:1:2:-1':raise AssertionError('panic must retain the open path descriptor before process exit')
                signal_checks(observed[0].decode().split('|')[-1],int(data.split('|')[9]))
                states.update(name.encode()+b'\0'+messages[0].encode()+b'\0'+observed[0]+b'\n');trap_groups[group]+=1
        if list(root.glob('*.fifo')):raise AssertionError('FIFO observer cleanup failed')
        controls_digest=returns.hexdigest();state_digest=states.hexdigest()
        if EXPECTED_CONTROLS is not None and (sum(return_groups.values())!=EXPECTED_CONTROLS or controls_digest!=EXPECTED_CONTROL_SHA256):raise AssertionError('return controls changed')
        if EXPECTED_TRAPS is not None and (sum(trap_groups.values())!=EXPECTED_TRAPS or state_digest!=EXPECTED_STATE_SHA256):raise AssertionError('failure golden changed')
        if tree_hash(source)!=PINNED_SOURCE_SHA256 or tree_hash(root/'src')!=PINNED_SOURCE_SHA256 or stdlib_hash(zig)!=PINNED_STDLIB_SHA256 or encoder_library_hashes(zig)!=ENCODER_LIBRARIES or flate_hash(zig)!=PINNED_FLATE_SHA256 or path_library_hashes(zig)!=PATH_LIBRARIES or implementation_hashes(repo)!=impl or hashlib.sha256(Path(__file__).read_bytes()).hexdigest()!=runner_hash:raise AssertionError('dependency, implementation or runner changed')
        for name,expected in fixtures.items():
            original=probe/name
            if any(hashlib.sha256(path.read_bytes()).hexdigest()!=expected for path in (root/name,original)):raise AssertionError('fixture changed')
        for name,expected in inputs.items():
            if hashlib.sha256((root/name).read_bytes()).hexdigest()!=expected:raise AssertionError('input changed')
        for name,expected in helpers.items():
            if hashlib.sha256((repo/'zigimg'/name).read_bytes()).hexdigest()!=expected:raise AssertionError('helper changed')
        if implementation_hashes(root/'no-retry-module')!=json.loads((root/'mutation_sha256.json').read_text()):raise AssertionError('mutated implementation changed')
        summary=dict(calibration_sha256=calibration_digest,mutation_records=len(mutation_cases()),mutation_sha256=mutation_digest,returning_records=len(rows),calls=sum(int(data.split('|')[7]) for _,data in rows),returning_groups=dict(Counter(group for group,_ in rows)),output_sha256=digest,return_controls=sum(return_groups.values()),return_control_groups=dict(return_groups),control_sha256=controls_digest,paired_traps=sum(trap_groups.values()),failure_groups=dict(trap_groups),state_sha256=state_digest,zig_mode=mode,v_prod=args.v_prod)
        (root/'summary.json').write_text(json.dumps(summary,indent=2)+'\n');print(json.dumps(summary),flush=True)


if __name__=='__main__':main()
