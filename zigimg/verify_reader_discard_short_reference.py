"""Compare short/remaining/64-bit discard, partial progress and retained failure state."""
import argparse
from collections import Counter
import hashlib,itertools,json,os,re,shutil
from pathlib import Path
from verify_jpeg_contracts_reference import implementation_hashes
from verify_tiff_decode_reference import ProofLog,tree_hash,work_directory,PINNED_SOURCE_SHA256,checked_trap
from verify_stream_guards_reference import stdlib_hash,PINNED_STDLIB_SHA256
from verify_image_open_reference import PATH_LIBRARIES,path_library_hashes
from verify_image_tty_reference import ENCODER_LIBRARIES,encoder_library_hashes

EXPECTED_ROWS = 24400
EXPECTED_SHA256 = 'ecc351a0a2d9bc3950ea56395b793ee57a386872bad3a785cc7a4eeba67a7c7f'
EXPECTED_CONTROLS = 102
EXPECTED_CONTROL_SHA256 = 'ca5d8060fc2a563278f156c237cc7e17f6b71d4564f72b9ea6df0d357649f9ef'
EXPECTED_TRAPS = 102
EXPECTED_STATE_SHA256 = '16372345d783cbd6f5a09a534e2238e5da3b006d4ab3544c483b58176eda1d31'

MAXIMUM=(1<<64)-1
def spec(kind=1,warmup=0,cap=8,start=0,consume_mode=0,payload=b'abcdefghi',replacement=0,consumed=0,seed=0,prime=0,delta=0,op=0,count=0,later=0):
    return '|'.join(map(str,(kind,warmup,cap,start,consume_mode)))+'|'+payload.hex()+'|'+'|'.join(map(str,(replacement,consumed,seed,prime,delta,op,count,later)))
def corpus():
    rows=[]
    for kind,length in itertools.product(range(3),(0,1,7,8,9,31,32,33,127,128,129,257)):
        payload=bytes((i*37+19)&255 for i in range(length))
        for cap,start,op in itertools.product((8,) if kind==0 else (0,1,8,32),sorted({0,1,length//2,length}),range(3)):
            if kind==1 and op==1:continue
            available=length-(start if 0<start<length and kind!=2 else 0)
            for count in ((0,) if op==1 else sorted({0,1,7,8,31,32,127,128,129,512,MAXIMUM})):
                if kind==1 and count>available:continue
                if kind==0 and count>MAXIMUM-(length-available):continue
                for delta in (-1,0,1):rows.append(('basic',spec(kind,cap=cap,start=start,payload=payload,delta=delta,op=op,count=count)))
    payload=bytes((i*37+19)&255 for i in range(128))
    for kind,cap,op,prime in itertools.product((1,2),(1,8,32),range(3),(1,2)):
        if kind==1 and op==1:continue
        for count,delta in itertools.product((0,1,7,8,31,32),(-1,0,1)):
            rows.append(('buffered',spec(kind,cap=cap,payload=payload,prime=prime,delta=delta,op=op,count=count)))
    for op,cap,seed,closed in itertools.product(range(3),(0,1,8,32),(0,1,7,8,31,32,127,128,129,257),(1,2)):
        for count in ((0,) if op==1 else (0,1,7,8,31,32,127,128,129,512,MAXIMUM)):
            rows.append(('streaming-pipe',spec(2,cap=cap,payload=payload,replacement=closed,seed=seed,op=op,count=count)))
    for cap,start,consumed,closed,op,prime in itertools.product((8,32),(0,1),(1,7),(1,2),range(3),(1,2)):
        for seed,count,delta in itertools.product(sorted({cap-consumed,cap+start-1}),((0,) if op==1 else (0,1,7,32)),(-1,0,1)):
            rows.append(('failed-prefill',spec(warmup=1,cap=cap,start=start,payload=payload,replacement=closed,consumed=consumed,seed=seed,prime=prime,delta=delta,op=op,count=count)))
    seen=set();result=[]
    for group,data in rows:
        if data not in seen:seen.add(data);result.append((group,data))
    return result

def controls():
    rows=[];payload=bytes((i*37+19)&255 for i in range(128))
    for op,start,count in itertools.product((0,2),(1,7),(MAXIMUM,MAXIMUM-1,MAXIMUM-7)):
        rows.append((f'add-memory-{op}-{start}-{count}',spec(0,start=start,payload=payload,op=op,count=count),'integer overflow'))
    for cap,consumed,op,count in itertools.product((8,32),(1,7),(0,2),(MAXIMUM,MAXIMUM-1,MAXIMUM-7)):
        rows.append((f'add-prefilled-{cap}-{consumed}-{op}-{count}',spec(2,warmup=1,cap=cap,payload=payload,replacement=2,consumed=consumed,op=op,count=count),'integer overflow'))
    for cap,start,consumed,closed,op in itertools.product((8,32),(0,1),(1,7),(1,2),range(3)):
        for seed in sorted({0,cap-consumed-1,cap-consumed,cap+start-1}):
            name=f'position-{cap}-{start}-{consumed}-{closed}-{op}-{seed}'
            rows.append((name,spec(warmup=1,cap=cap,start=start,payload=payload,replacement=closed,consumed=consumed,seed=seed,prime=1,op=op,count=1),'integer overflow'))
    if len({name for name,_,_ in rows})!=len(rows) or len({data for _,data,_ in rows})!=len(rows):raise AssertionError('duplicate control label/input')
    return rows

def loop_cases():
    rows=[]
    for cap,length,op in itertools.product((0,8),(0,7),range(3)):
        rows.append((f'cached-{cap}-{length}-{op}',spec(cap=cap,payload=bytes(range(length)),op=op,count=length+1)))
    return rows

def snapshot_checks(line,data):
    f=data.split('|');kind,warmup,cap,start,mode=map(int,f[:5]);payload=bytes.fromhex(f[5]);replacement,consumed,seed,prime,delta,op,count,later=map(int,f[6:]);parts=line.decode().split('~')
    if len(parts)!=10:raise AssertionError('missing discard snapshots')
    for index,part in enumerate(parts[:-1]):
        status,metadata,buffer,output,pending=part.split('|');m=metadata.split(':')
        if len(m)!=4 or m[-2:]!=(['0','0'] if kind==0 else ['1',str(2 if index==0 or replacement==0 else (2 if replacement==2 else 3))]):raise AssertionError('reader ownership differs')
        maximum=len(payload) if kind==0 else cap
        if len(bytes.fromhex(buffer))!=maximum or len(bytes.fromhex(pending))>maximum or (output and not output.isdecimal()):raise AssertionError('initialized discard spans/count differ')
        if status not in ('ok','skip','EndOfStream','ReadFailed','Unseekable'):
            if not status.startswith('consumed-') or not status[9:].isdecimal():raise AssertionError('unexpected discard status '+status)
    physical=min(cap,len(payload)) if kind==2 and prime>0 else 0
    for prior,call,after in ((1,2,3),(4,5,6),(6,7,8)):
        old=parts[prior].split('|');before=parts[call].split('|');now=parts[after].split('|');pending=bytes.fromhex(before[4]);n=int(now[0][9:]);requested=count if call==2 else later
        expected=(len(pending) if mode==1 else (min(1,len(pending)) if mode==2 else ((len(pending)+1)//2 if mode==3 else 0)))
        if n!=expected or bytes.fromhex(now[4])!=pending[n:] or now[2:4]!=before[2:4] or int(now[1].split(':')[0])!=int(before[1].split(':')[0])+n:raise AssertionError('caller consumption differs')
        if before[2]!=old[2]:raise AssertionError('discard modified caller backing')
        if before[0]=='ok' and not before[3]:raise AssertionError('missing successful discard count')
        if before[0]!='ok' and before[3]!=old[3]:raise AssertionError('failed discard replaced saved count')
        if replacement==0:
            position=int(old[1].split(':')[0]);old_pending=len(bytes.fromhex(old[4]));available=old_pending+len(payload)-physical if kind==2 else len(payload)-position;used=available if op==1 else min(requested,available);status='EndOfStream' if op==2 and used<requested else 'ok'
            if kind==2:physical+=used-(old_pending if op==1 else min(requested,old_pending))
            if before[0]!=status or int(before[1].split(':')[0])!=position+used or before[3]!=(str(used) if status=='ok' else old[3]):raise AssertionError('independent discard count/progress differs')
    if parts[-1].split(':')[0]!=('-3' if replacement==0 else ('0' if replacement==2 else '-1')):raise AssertionError('reader wire status differs')

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
    fields=states[0].decode().split('|');f=data.split('|');kind=int(f[0])
    if len(fields)!=5 or fields[1].split(':')[-2:]!=(['0','0'] if kind==0 else ['1',str(2 if f[6] in ('0','2') else 3)]):raise AssertionError(name+': invalid panic observer')
    if fields[0]!=('calling' if name.startswith('add-') else 'ok'):raise AssertionError(name+': unexpected failure order')
    maximum=len(bytes.fromhex(f[5])) if kind==0 else int(f[2])
    if len(bytes.fromhex(fields[2]))!=maximum or len(bytes.fromhex(fields[4]))>maximum or fields[3]!='':raise AssertionError(name+': invalid initialized spans')
    return ('trap',category.encode()+b'\0'+states[0]+b'\n')

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source',type=Path);parser.add_argument('zig',type=Path);parser.add_argument('v',type=Path)
    parser.add_argument('--target',default='aarch64-macos.14.0');parser.add_argument('--v-prod',action='store_true');parser.add_argument('--workdir',type=Path);parser.add_argument('--timeout',type=int,default=600)
    args=parser.parse_args()
    if args.timeout<=0:parser.error('--timeout must be positive')
    source=args.source.resolve()/'src';zig=args.zig.resolve();v=args.v.resolve()
    if tree_hash(source)!=PINNED_SOURCE_SHA256 or stdlib_hash(zig)!=PINNED_STDLIB_SHA256 or path_library_hashes(zig)!=PATH_LIBRARIES or encoder_library_hashes(zig)!=ENCODER_LIBRARIES:parser.error('Source/compiler library differs from pins')
    repo=Path(__file__).resolve().parent.parent;probe=repo/'zigimg/reference_probes/reader_discard_short';mode='ReleaseSafe' if args.v_prod else 'Debug'
    with work_directory(args.workdir,'witty-reader-fill-more-') as root:
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
        print(f'Building reader discard methods: Source {mode}, V {"production" if args.v_prod else "ordinary"}',flush=True)
        proof.run([str(zig),'build-exe','-target',args.target,'-lc','-I',str(root),'-O',mode,'--global-cache-dir',str(root.parent/'zig-global'),'--cache-dir',str(root/'zig-cache'),'-femit-bin='+str(root/'native'),str(root/'reference.zig'),str(root/'fixture_shims.c')],'build-source',env=env,timeout=args.timeout)
        proof.run([str(v),'-enable-globals',*(['-prod'] if args.v_prod else []),'-path',f'{repo}|@vlib|@vmodules','-o',str(root/'translated'),str(root/'main.v')],'build-v',env=env,timeout=args.timeout)
        rows=corpus();path=root/'corpus.txt';path.write_text('\n'.join(data for _,data in rows)+'\n');inputs={'corpus.txt':hashlib.sha256(path.read_bytes()).hexdigest()};(root/'input_sha256.json').write_text(json.dumps(inputs,indent=2)+'\n')
        outputs=[]
        for exe in ('native','translated'):
            result=proof.run([str(root/exe),str(path)],'returning-'+exe,env=env,timeout=args.timeout)
            if result.stderr or len(result.stdout.splitlines())!=len(rows):raise AssertionError('invalid returning output')
            outputs.append(result.stdout.splitlines())
        for i,((group,data),native,translated) in enumerate(zip(rows,*outputs)):
            if native!=translated:raise AssertionError(f'{i}/{group}: reader discarder record differs; see retained proof')
            snapshot_checks(native,data)
        digest=hashlib.sha256(b'\n'.join(outputs[0])).hexdigest()
        if EXPECTED_ROWS is not None and (len(rows)!=EXPECTED_ROWS or digest!=EXPECTED_SHA256):raise AssertionError('returning golden changed')
        returns=hashlib.sha256();states=hashlib.sha256();return_count=0;trap_count=0
        print(f'{len(rows)} returning reader discard records match; checking failure controls',flush=True)
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
        summary=dict(returning_records=len(rows),discard_calls=3*len(rows),primary_calls=7*len(rows),returning_groups=dict(Counter(group for group,_ in rows)),output_sha256=digest,return_controls=return_count,control_sha256=returns.hexdigest(),paired_traps=trap_count,state_sha256=states.hexdigest(),zig_mode=mode,v_prod=args.v_prod)
        (root/'summary.json').write_text(json.dumps(summary,indent=2)+'\n');print(json.dumps(summary),flush=True)

if __name__=='__main__':main()
