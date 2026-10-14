"""Compare public rebasing, fixed EOF, compaction, no IO and retained failure state."""
import argparse
from collections import Counter
import hashlib,itertools,json,os,re,shutil
from pathlib import Path
from verify_jpeg_contracts_reference import implementation_hashes
from verify_tiff_decode_reference import ProofLog,tree_hash,work_directory,PINNED_SOURCE_SHA256,checked_trap
from verify_stream_guards_reference import stdlib_hash,PINNED_STDLIB_SHA256
from verify_image_open_reference import PATH_LIBRARIES,path_library_hashes
from verify_image_tty_reference import ENCODER_LIBRARIES,encoder_library_hashes

EXPECTED_ROWS = 13626
EXPECTED_SHA256 = 'e6efc4fa8584b25d60117d83fef6c5c076feab4ccde687d1cc988e8043ef6ca0'
EXPECTED_CONTROLS = 40
EXPECTED_CONTROL_SHA256 = 'cf834fc7c956bcea92c0dbd4ab5564a5f1e5d1e9aa98cb2967fa575597b1d963'
EXPECTED_TRAPS = 70
EXPECTED_STATE_SHA256 = 'f286aebbca3601dba4a2d5021693ab2f2c2de02f83c0372dd6cdae259bd5cd4b'

MAX_USIZE=(1<<64)-1

def spec(kind=1,warmup=0,cap=8,start=0,consume_mode=1,payload=b'abcdefghi',replacement=0,consumed=0,seed=0,prime=0,delta=0,request=0):
    return '|'.join(map(str,(kind,warmup,cap,start,consume_mode)))+'|'+payload.hex()+'|'+'|'.join(map(str,(replacement,consumed,seed,prime,delta,request)))

def corpus():
    rows=[]
    for kind,cap,length in itertools.product(range(3),(0,1,4,8),(0,1,7,8,17)):
        payload=bytes((i*37+19)&255 for i in range(length))
        requests=sorted({0,1,length,length+1,MAX_USIZE}) if kind==0 else sorted({0,cap//2,cap})
        for start,prime,mode,delta,request in itertools.product(sorted({0,1,length}),range(3),(0,1,3),(-1,0,1),requests):
            rows.append(('basic',spec(kind,cap=cap,start=start,consume_mode=mode,payload=payload,prime=prime,delta=delta,request=request)))
    payload=bytes((i*37+19)&255 for i in range(128))
    for kind,cap,consumed,request,delta in itertools.product((1,2),(1,4,8),(0,1),range(2),(-1,0,1)):
        rows.append(('prefilled',spec(kind,warmup=1,cap=cap,consumed=consumed,payload=payload,request=cap if request else 0,delta=delta)))
    for cap,start,consumed,closed,prime,mode,request in itertools.product((4,8),(0,1),(1,3),(1,2),(0,1,2),(0,1,3),(0,1)):
        for seed in sorted({cap-consumed,cap+start,cap+start+cap}):
            rows.append(('replacement',spec(warmup=1,cap=cap,start=start,consume_mode=mode,payload=payload,replacement=closed,consumed=consumed,seed=seed,prime=prime,request=cap if request else 0)))
    if len({data for _,data in rows})!=len(rows):raise AssertionError('duplicate returning input')
    return rows

def controls():
    rows=[];payload=bytes((i*37+19)&255 for i in range(128))
    for kind,cap,prime,request in itertools.product(range(3),(0,1,4,8),(0,1,2),(0,1)):
        capacity=len(payload) if kind==0 else cap
        n=MAX_USIZE if request else capacity+1
        rows.append((f'oversize-{kind}-{cap}-{prime}-{request}',spec(kind,cap=cap,payload=payload,prime=prime,request=n),'reached unreachable code'))
    for kind,cap,consumed in itertools.product((1,2),(1,4,8),(1,)):
        rows.append((f'oversize-pending-{kind}-{cap}',spec(kind,warmup=1,cap=cap,payload=payload,consumed=consumed,request=cap+1),'reached unreachable code'))
    for cap,start,consumed,closed,prime in itertools.product((4,8),(0,1),(1,3),(1,2),(1,2)):
        seed=cap-consumed-1
        rows.append((f'position-{cap}-{start}-{consumed}-{closed}-{prime}',spec(warmup=1,cap=cap,start=start,payload=payload,replacement=closed,consumed=consumed,seed=seed,prime=prime,request=cap),'integer overflow'))
    if len({name for name,_,_ in rows})!=len(rows) or len({data for _,data,_ in rows})!=len(rows):raise AssertionError('duplicate control label/input')
    return rows

def parse_snapshot(part):
    status,metadata,buffer,output,pending=part.split('|')
    m=metadata.split(':')
    if len(m)!=6:raise AssertionError('missing cursor/end metadata')
    return status,m,bytes.fromhex(buffer),bytes.fromhex(output),bytes.fromhex(pending)

def snapshot_checks(line,data):
    f=data.split('|');kind,warmup,cap,start,mode=map(int,f[:5]);payload=bytes.fromhex(f[5]);replacement,consumed,seed,prime,delta,request=map(int,f[6:]);parts=line.decode().split('~')
    if len(parts)!=10:raise AssertionError('missing rebase snapshots')
    snapshots=[parse_snapshot(part) for part in parts[:-1]]
    for index,(status,m,buffer,output,pending) in enumerate(snapshots):
        if m[2:4]!=(['0','0'] if kind==0 else ['1',str(2 if index==0 or replacement==0 else (2 if replacement==2 else 3))]):raise AssertionError('reader ownership differs')
        maximum=len(payload) if kind==0 else cap;seek,end=map(int,m[4:])
        if len(buffer)!=maximum or not 0<=seek<=end<=maximum or pending!=buffer[seek:end]:raise AssertionError('initialized reader spans differ')
        if status not in ('ok','skip','EndOfStream','ReadFailed','Unseekable') and not (status.startswith('consumed-') and status[9:].isdecimal()):raise AssertionError('unexpected rebase status '+status)
    for before,after in ((1,2),(4,5),(6,7)):
        _,m,buffer,old_output,pending=snapshots[before];status,later,changed,output,tail=snapshots[after];seek,end=map(int,m[4:]);room=len(buffer)-seek
        if later[:4]!=m[:4] or tail!=pending:raise AssertionError('rebase consumed/read input or changed file metadata')
        if request<=room:
            if status!='ok' or changed!=buffer or later[4:]!=m[4:] or output!=pending:raise AssertionError('no-op rebase changed state')
        elif kind==0:
            if status!='EndOfStream' or changed!=buffer or later[4:]!=m[4:] or output!=old_output:raise AssertionError('fixed rebase moved bytes or lost retained output')
        else:
            if request>len(buffer) or status!='ok' or later[4:]!=['0',str(len(pending))] or changed!=pending+buffer[len(pending):] or output!=pending:raise AssertionError('file compaction differs')
    for call,after in ((2,3),(5,6),(7,8)):
        _,m,buffer,output,pending=snapshots[call];status,later,changed,saved,tail=snapshots[after];n=int(status[9:]);expected=(len(pending) if mode==1 else ((len(pending)+1)//2 if mode==3 else 0))
        if n!=expected or tail!=pending[n:] or changed!=buffer or saved!=output or later[1:4]!=m[1:4] or int(later[0])!=int(m[0])+n or list(map(int,later[4:]))!=[int(m[4])+n,int(m[5])]:raise AssertionError('caller consumption differs')
    wire_status,wire_hex=parts[-1].split(':');wire=bytes.fromhex(wire_hex)
    if wire_status!=('-3' if replacement==0 else ('0' if replacement==2 else '-1')):raise AssertionError('reader wire status differs')
    if replacement and prime==0 and wire!=bytes((i*31+7)&255 for i in range(seed)):raise AssertionError('rebase or in-buffer seek read the pipe')

def classify(native,translated,name,data,category,paths):
    if native.returncode==0:
        if translated.returncode or native.stdout!=translated.stdout or native.stderr or translated.stderr or not native.stdout:raise AssertionError(name+': returning control differs')
        snapshot_checks(native.stdout.strip(),data);return ('return',native.stdout)
    for result in (native,translated):
        checked_trap(result,name,category)
        messages=[m.group(1) for line in result.stderr.decode().splitlines() if (m:=re.fullmatch(r'(?:thread \d+ |V )?panic:\s*(.*)',line.strip()))]
        if messages!=[category]:raise AssertionError(name+': panic message differs')
    states=[p.read_bytes() for p in paths]
    if not states[0] or states[0]!=states[1]:raise AssertionError(name+': retained failure state differs')
    fields=states[0].decode().split('|');f=data.split('|');kind=int(f[0]);cap=int(f[2]);payload=bytes.fromhex(f[5]);consumed=int(f[7])
    if len(fields)!=5:raise AssertionError(name+': invalid panic observer')
    metadata=fields[1].split(':');seek,end=map(int,metadata[3:]);buffer=bytes.fromhex(fields[2]);pending=bytes.fromhex(fields[4])
    if len(metadata)!=5 or metadata[1:3]!=['1',str(2 if f[6] in ('0','2') else 3)] or len(buffer)!=cap or not 0<=seek<=end<=cap or pending!=buffer[seek:end] or fields[3]!='':raise AssertionError(name+': invalid initialized spans')
    if fields[0]!=('calling' if category=='reached unreachable code' else 'ok'):raise AssertionError(name+': unexpected failure order')
    if category=='reached unreachable code':
        if seek!=0 or int(f[11])<=cap:raise AssertionError(name+': trap preceded compaction')
        if name.startswith('oversize-pending-') and (pending!=payload[consumed:cap] or buffer!=payload[consumed:cap]+payload[cap-consumed:cap]):raise AssertionError(name+': compacted failure bytes differ')
    return ('trap',category.encode()+b'\0'+states[0]+b'\n')

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source',type=Path);parser.add_argument('zig',type=Path);parser.add_argument('v',type=Path)
    parser.add_argument('--target',default='aarch64-macos.14.0');parser.add_argument('--v-prod',action='store_true');parser.add_argument('--workdir',type=Path);parser.add_argument('--timeout',type=int,default=600)
    args=parser.parse_args()
    if args.timeout<=0:parser.error('--timeout must be positive')
    source=args.source.resolve()/'src';zig=args.zig.resolve();v=args.v.resolve()
    if tree_hash(source)!=PINNED_SOURCE_SHA256 or stdlib_hash(zig)!=PINNED_STDLIB_SHA256 or path_library_hashes(zig)!=PATH_LIBRARIES or encoder_library_hashes(zig)!=ENCODER_LIBRARIES:parser.error('Source/compiler library differs from pins')
    repo=Path(__file__).resolve().parent.parent;probe=repo/'zigimg/reference_probes/reader_rebase';mode='ReleaseSafe' if args.v_prod else 'Debug'
    with work_directory(args.workdir,'witty-reader-rebase-') as root:
        tmp=root/'tmp';tmp.mkdir();env=dict(os.environ,TMPDIR=str(tmp),VTMP=str(tmp),VEXE=str(v),V_C_ERROR_BUG_REPORT_DISABLED='1')
        proof=ProofLog(root);shutil.copytree(source,root/'src');fixtures={}
        for name in ('main.v','reference.zig','fixture_shims.h','fixture_shims.c'):
            shutil.copyfile(probe/name,root/name);fixtures[name]=hashlib.sha256((root/name).read_bytes()).hexdigest()
        shared_hash={}
        for directory in ('reader_delimiter','reader_exclusive'):
            shared=root/directory;shared.mkdir();shutil.copyfile(repo/'zigimg/reference_probes'/directory/'fixture_shims.h',shared/'fixture_shims.h');shared_hash[directory]=hashlib.sha256((shared/'fixture_shims.h').read_bytes()).hexdigest()
        versions=[proof.run([str(exe),'version'],label,env=env).stdout.decode().strip() for exe,label in ((zig,'zig-version'),(v,'v-version'))]
        if versions[0]!='0.15.2' or not re.match(r'^V 0\.5\.2(?: |$)',versions[1]):raise AssertionError('compiler versions differ')
        impl=implementation_hashes(repo);runner_hash=hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
        helpers={name:hashlib.sha256((repo/'zigimg'/name).read_bytes()).hexdigest() for name in ('verify_jpeg_contracts_reference.py','verify_tiff_decode_reference.py','verify_stream_guards_reference.py','verify_image_open_reference.py','verify_image_tty_reference.py')}
        (root/'provenance.json').write_text(json.dumps(dict(source_sha256=PINNED_SOURCE_SHA256,stdlib_sha256=PINNED_STDLIB_SHA256,path_libraries=PATH_LIBRARIES,encoder_libraries=ENCODER_LIBRARIES,versions=versions,target=args.target,zig_mode=mode,v_prod=args.v_prod,implementation_sha256=impl,runner_sha256=runner_hash,fixtures=fixtures,helper_sha256=helpers,shared_fixture_sha256=shared_hash),indent=2)+'\n')
        print(f'Building public rebases: Source {mode}, V {"production" if args.v_prod else "ordinary"}',flush=True)
        proof.run([str(zig),'build-exe','-target',args.target,'-lc','-I',str(root),'-O',mode,'--global-cache-dir',str(root.parent/'zig-global'),'--cache-dir',str(root/'zig-cache'),'-femit-bin='+str(root/'native'),str(root/'reference.zig'),str(root/'fixture_shims.c')],'build-source',env=env,timeout=args.timeout)
        proof.run([str(v),'-enable-globals',*(['-prod'] if args.v_prod else []),'-path',f'{repo}|@vlib|@vmodules','-o',str(root/'translated'),str(root/'main.v')],'build-v',env=env,timeout=args.timeout)
        rows=corpus();path=root/'corpus.txt';path.write_text('\n'.join(data for _,data in rows)+'\n');inputs={'corpus.txt':hashlib.sha256(path.read_bytes()).hexdigest()};(root/'input_sha256.json').write_text(json.dumps(inputs,indent=2)+'\n')
        outputs=[]
        for exe in ('native','translated'):
            result=proof.run([str(root/exe),str(path)],'returning-'+exe,env=env,timeout=args.timeout)
            if result.stderr or len(result.stdout.splitlines())!=len(rows):raise AssertionError('invalid returning output')
            outputs.append(result.stdout.splitlines())
        for i,((group,data),native,translated) in enumerate(zip(rows,*outputs)):
            if native!=translated:raise AssertionError(f'{i}/{group}: rebase record differs; see retained proof')
            snapshot_checks(native,data)
        digest=hashlib.sha256(b'\n'.join(outputs[0])).hexdigest()
        if EXPECTED_ROWS is not None and (len(rows)!=EXPECTED_ROWS or digest!=EXPECTED_SHA256):raise AssertionError('returning golden changed')
        returns=hashlib.sha256();states=hashlib.sha256();return_count=0;trap_count=0
        print(f'{len(rows)} returning rebase records match; checking failure controls',flush=True)
        for name,data,category in controls():
            pair=[]
            for exe in ('native','translated'):
                state_path=root/(name+'-'+exe+'.state')
                pair.append((proof.run([str(root/exe),'--trap',str(state_path),data],name+'-'+exe,env=env,timeout=args.timeout,check=False),state_path))
            classification,out=classify(pair[0][0],pair[1][0],name,data,category,[p for _,p in pair])
            (returns if classification=='return' else states).update(name.encode()+b'\0'+out)
            if classification=='return':return_count+=1
            else:trap_count+=1
        if EXPECTED_CONTROLS is not None and (return_count!=EXPECTED_CONTROLS or returns.hexdigest()!=EXPECTED_CONTROL_SHA256):raise AssertionError('returning control golden changed')
        if EXPECTED_TRAPS is not None and (trap_count!=EXPECTED_TRAPS or states.hexdigest()!=EXPECTED_STATE_SHA256):raise AssertionError('panic golden changed')
        if tree_hash(source)!=PINNED_SOURCE_SHA256 or tree_hash(root/'src')!=PINNED_SOURCE_SHA256 or stdlib_hash(zig)!=PINNED_STDLIB_SHA256 or path_library_hashes(zig)!=PATH_LIBRARIES or encoder_library_hashes(zig)!=ENCODER_LIBRARIES or implementation_hashes(repo)!=impl or hashlib.sha256(Path(__file__).read_bytes()).hexdigest()!=runner_hash:raise AssertionError('dependency/implementation/runner changed')
        for name,pin in fixtures.items():
            if any(hashlib.sha256((base/name).read_bytes()).hexdigest()!=pin for base in (root,probe)):raise AssertionError('fixture changed')
        for name,pin in inputs.items():
            if hashlib.sha256((root/name).read_bytes()).hexdigest()!=pin:raise AssertionError('input changed')
        for name,pin in helpers.items():
            if hashlib.sha256((repo/'zigimg'/name).read_bytes()).hexdigest()!=pin:raise AssertionError('helper changed')
        for directory,pin in shared_hash.items():
            if any(hashlib.sha256(p.read_bytes()).hexdigest()!=pin for p in (root/directory/'fixture_shims.h',repo/'zigimg/reference_probes'/directory/'fixture_shims.h')):raise AssertionError('shared fixture changed')
        if list(root.glob('*.owned*')):raise AssertionError('owned paths survived')
        summary=dict(returning_records=len(rows),rebase_calls=3*len(rows),primary_calls=7*len(rows),returning_groups=dict(Counter(group for group,_ in rows)),output_sha256=digest,return_controls=return_count,control_sha256=returns.hexdigest(),paired_traps=trap_count,state_sha256=states.hexdigest(),zig_mode=mode,v_prod=args.v_prod)
        (root/'summary.json').write_text(json.dumps(summary,indent=2)+'\n');print(json.dumps(summary),flush=True)

if __name__=='__main__':main()
