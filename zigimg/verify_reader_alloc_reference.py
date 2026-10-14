"""Compare allocated byte/endian slices, ownership and retained failure state."""
import argparse
from collections import Counter
import hashlib,itertools,json,os,re,shutil
from pathlib import Path
from verify_jpeg_contracts_reference import implementation_hashes
from verify_tiff_decode_reference import ProofLog,tree_hash,work_directory,PINNED_SOURCE_SHA256,checked_trap
from verify_stream_guards_reference import stdlib_hash,PINNED_STDLIB_SHA256
from verify_image_open_reference import PATH_LIBRARIES,path_library_hashes
from verify_image_tty_reference import ENCODER_LIBRARIES,encoder_library_hashes

EXPECTED_ROWS = 27585
EXPECTED_SHA256 = 'de092f84619d3966654e8beb1b7fcc7a06febb8f9f9cf8f21a3c0cbf64365b35'
EXPECTED_CONTROLS = 96
EXPECTED_CONTROL_SHA256 = '17278d55c05ea3acc324e9869abbbed9ee273db9883ae712bbac162dc265b822'
EXPECTED_TRAPS = 168
EXPECTED_STATE_SHA256 = '8ebe110126543970be692cd35b4799b35bfb941dd29c64f4daf80a094400ef63'

WIDTHS=(1,2,4,8,1,2,4,8,8,8)
PROFILES=((0,0,0),(1,1,0),(1,17,1))
def spec(kind=1,warmup=0,cap=8,start=0,consume_mode=0,payload=b'abcdefghi',replacement=0,consumed=0,seed=0,prime=0,delta=0,op=0,tag=0,order=0,count=1):
    return '|'.join(map(str,(kind,warmup,cap,start,consume_mode)))+'|'+payload.hex()+'|'+'|'.join(map(str,(replacement,consumed,seed,prime,delta,op,tag,order,count)))
def corpus():
    rows=[]
    profiles=[(1,t,e) for t,e in itertools.product(range(20),range(4))]+[(0,0,0)]
    for (op,tag,order),kind,length in itertools.product(profiles,range(3),(0,1,7,8,17)):
        payload=bytes((i*37+19)&255 for i in range(length))
        for cap,start,count in itertools.product((8,) if kind==0 else (0,8),sorted({0,1,length}),(0,1,3)):
            rows.append(('basic',spec(kind,cap=cap,start=start,payload=payload,op=op,tag=tag,order=order,count=count)))
    for byte,(op,tag,order),kind in itertools.product(range(256),[(0,0,0)]+[(1,t,e) for t,e in itertools.product((0,4,1,5),range(2))],range(3)):
        rows.append(('every-byte',spec(kind,cap=8,payload=bytes([byte,byte,byte]),op=op,tag=tag,order=order)))
    payload=bytes((i*37+19)&255 for i in range(128))
    for (op,tag,order),cap,start,consumed,closed,prime in itertools.product(PROFILES,(8,32),(0,1),(1,7),(1,2),range(3)):
        for seed,count,delta in itertools.product(sorted({cap-consumed,cap+start,cap+start+17}),(0,1,3),(-1,0,1)):
            rows.append(('prefilled',spec(warmup=1,cap=cap,start=start,payload=payload,replacement=closed,consumed=consumed,seed=seed,prime=prime,delta=delta,op=op,tag=tag,order=order,count=count)))
    payload=bytes((i*37+19)&255 for i in range(33))
    for (op,tag,order),kind,mode,delta in itertools.product([(0,0,0)]+[(1,t,e) for t,e in itertools.product((0,1,3,11,17),range(2))],range(3),(0,1,2),(-1,0,1)):
        for cap,count in itertools.product((8,) if kind==0 else (1,8),(1,2)):
            rows.append(('owned-mutation',spec(kind,cap=cap,payload=payload,consume_mode=mode,delta=delta,op=op+2,tag=tag,order=order,count=count)))
    seen=set();result=[]
    for group,data in rows:
        if data not in seen:seen.add(data);result.append((group,data))
    return result

def controls():
    rows=[];payload=bytes((i*37+19)&255 for i in range(128))
    for (op,tag,order),cap,start,consumed,closed,count in itertools.product(PROFILES,(8,32),(0,1),(1,7),(1,2),(0,2)):
        for seed in sorted({0,cap-consumed-1,cap-consumed}):
            name=f'position-{op}-{tag}-{order}-{cap}-{start}-{consumed}-{closed}-{count}-{seed}'
            rows.append((name,spec(warmup=1,cap=cap,start=start,payload=payload,replacement=closed,consumed=consumed,seed=seed,prime=1,op=op,tag=tag,order=order,count=count),'integer overflow'))
    if len({name for name,_,_ in rows})!=len(rows) or len({data for _,data,_ in rows})!=len(rows):raise AssertionError('duplicate control label/input')
    return rows

def result_fields(value):
    a,b,alias=value.split(':');return bytes.fromhex(a),bytes.fromhex(b),alias

def snapshot_checks(line,data):
    f=data.split('|');kind,warmup,cap,start,mode=map(int,f[:5]);payload=bytes.fromhex(f[5]);replacement,consumed,seed,prime,delta,op,tag,order,count=map(int,f[6:]);parts=line.decode().split('~');width=WIDTHS[tag%10] if op%2 else 1;requested=count*width
    if len(parts)!=10:raise AssertionError('missing allocated-read snapshots')
    for index,part in enumerate(parts[:-1]):
        status,metadata,buffer,output,pending=part.split('|');m=metadata.split(':');active,held,alias=result_fields(output)
        if len(m)!=4 or m[-2:]!=(['0','0'] if kind==0 else ['1',str(2 if index==0 or replacement==0 else (2 if replacement==2 else 3))]):raise AssertionError('reader ownership differs')
        maximum=len(payload) if kind==0 else cap
        if len(bytes.fromhex(buffer))!=maximum or len(bytes.fromhex(pending))>maximum or len(active) not in (0,requested) or len(held) not in (0,requested):raise AssertionError('allocated spans differ')
        if alias not in ('0','1','-') or ((alias=='-')!=(not active or not held)) or (alias=='1' and active!=held):raise AssertionError('retained allocation alias differs')
        if status not in ('ok','skip','EndOfStream','ReadFailed','Unseekable'):
            if not status.startswith('consumed-') or not status[9:].isdecimal():raise AssertionError('unexpected allocation status '+status)
    if parts[0].split('|')[3]!='::-' or parts[1].split('|')[3]!='::-':raise AssertionError('result appeared before read')
    physical=min(cap,len(payload)) if kind==2 and prime>0 else 0
    for prior,call,after in ((1,2,3),(4,5,6),(6,7,8)):
        old=parts[prior].split('|');before=parts[call].split('|');now=parts[after].split('|');pending=bytes.fromhex(before[4]);n=int(now[0][9:]);active,held,alias=result_fields(before[3]);old_active,old_held,old_alias=result_fields(old[3])
        expected=(len(pending) if mode==1 else (min(1,len(pending)) if mode==2 else ((len(pending)+1)//2 if mode==3 else 0)))
        a=bytearray(active);h=bytearray(held)
        if op>=2 and a:
            a[0]^=90
            if alias=='1':h[0]^=90
        if n!=expected or bytes.fromhex(now[4])!=pending[n:] or now[2]!=before[2] or result_fields(now[3])!=(a,h,alias) or int(now[1].split(':')[0])!=int(before[1].split(':')[0])+n:raise AssertionError('caller consumption/owned mutation differs')
        if before[0]!='ok' and before[3]!=old[3]:raise AssertionError('failed allocation replaced retained result')
        if before[0]=='ok':
            if len(active)!=requested:raise AssertionError('successful allocation length differs')
            expected_held=old_held or active;expected_alias='-' if not active else ('0' if old_held else '1')
            if held!=expected_held or alias!=expected_alias:raise AssertionError('successful allocation shares previous storage')
        if requested==0 and (before[0]!='ok' or before[1:3]!=old[1:3] or before[4]!=old[4]):raise AssertionError('zero allocation performed IO')
        if replacement==0:
            position=int(old[1].split(':')[0]);old_pending=bytes.fromhex(old[4]);source=payload[position:] if kind!=2 else old_pending+payload[physical:];used=min(requested,len(source));status='ok' if used==requested else 'EndOfStream'
            expected_active=old_active
            if status=='ok':
                expected_active=source[:used]
                if op%2:expected_active=b''.join(int.from_bytes(source[i:i+width],'big' if order%2==0 else 'little').to_bytes(width,'little') for i in range(0,used,width))
            if before[0]!=status or active!=expected_active or int(before[1].split(':')[0])!=position+used:raise AssertionError('independent allocated value/progress differs')
            if kind==2:physical+=max(used-len(old_pending),0)+len(pending)-max(len(old_pending)-used,0)
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
    fields=states[0].decode().split('|');f=data.split('|')
    if len(fields)!=5 or fields[0]!='ok' or fields[1].split(':')[-2:]!=['1',str(2 if f[6]=='2' else 3)]:raise AssertionError(name+': invalid panic observer/order')
    if len(bytes.fromhex(fields[2]))!=int(f[2]) or len(bytes.fromhex(fields[4]))>int(f[2]) or fields[3]!='::-':raise AssertionError(name+': invalid initialized spans')
    return ('trap',category.encode()+b'\0'+states[0]+b'\n')

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source',type=Path);parser.add_argument('zig',type=Path);parser.add_argument('v',type=Path)
    parser.add_argument('--target',default='aarch64-macos.14.0');parser.add_argument('--v-prod',action='store_true');parser.add_argument('--workdir',type=Path);parser.add_argument('--timeout',type=int,default=600)
    args=parser.parse_args()
    if args.timeout<=0:parser.error('--timeout must be positive')
    source=args.source.resolve()/'src';zig=args.zig.resolve();v=args.v.resolve()
    if tree_hash(source)!=PINNED_SOURCE_SHA256 or stdlib_hash(zig)!=PINNED_STDLIB_SHA256 or path_library_hashes(zig)!=PATH_LIBRARIES or encoder_library_hashes(zig)!=ENCODER_LIBRARIES:parser.error('Source/compiler library differs from pins')
    repo=Path(__file__).resolve().parent.parent;probe=repo/'zigimg/reference_probes/reader_alloc';mode='ReleaseSafe' if args.v_prod else 'Debug'
    with work_directory(args.workdir,'witty-reader-alloc-') as root:
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
        print(f'Building allocated bytes and endian slices: Source {mode}, V {"production" if args.v_prod else "ordinary"}',flush=True)
        proof.run([str(zig),'build-exe','-target',args.target,'-lc','-I',str(root),'-O',mode,'--global-cache-dir',str(root.parent/'zig-global'),'--cache-dir',str(root/'zig-cache'),'-femit-bin='+str(root/'native'),str(root/'reference.zig'),str(root/'fixture_shims.c')],'build-source',env=env,timeout=args.timeout)
        proof.run([str(v),'-enable-globals',*(['-prod'] if args.v_prod else []),'-path',f'{repo}|@vlib|@vmodules','-o',str(root/'translated'),str(root/'main.v')],'build-v',env=env,timeout=args.timeout)
        rows=corpus();path=root/'corpus.txt';path.write_text('\n'.join(data for _,data in rows)+'\n');inputs={'corpus.txt':hashlib.sha256(path.read_bytes()).hexdigest()};(root/'input_sha256.json').write_text(json.dumps(inputs,indent=2)+'\n')
        outputs=[]
        for exe in ('native','translated'):
            result=proof.run([str(root/exe),str(path)],'returning-'+exe,env=env,timeout=args.timeout)
            if result.stderr or len(result.stdout.splitlines())!=len(rows):raise AssertionError('invalid returning output')
            outputs.append(result.stdout.splitlines())
        for i,((group,data),native,translated) in enumerate(zip(rows,*outputs)):
            if native!=translated:raise AssertionError(f'{i}/{group}: allocated reader record differs; see retained proof')
            snapshot_checks(native,data)
        digest=hashlib.sha256(b'\n'.join(outputs[0])).hexdigest()
        if EXPECTED_ROWS is not None and (len(rows)!=EXPECTED_ROWS or digest!=EXPECTED_SHA256):raise AssertionError('returning golden changed')
        returns=hashlib.sha256();states=hashlib.sha256();return_count=0;trap_count=0
        print(f'{len(rows)} returning allocated read records match; checking failure controls',flush=True)
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
        summary=dict(returning_records=len(rows),allocated_calls=3*len(rows),primary_calls=7*len(rows),returning_groups=dict(Counter(group for group,_ in rows)),output_sha256=digest,return_controls=return_count,control_sha256=returns.hexdigest(),paired_traps=trap_count,state_sha256=states.hexdigest(),zig_mode=mode,v_prod=args.v_prod)
        (root/'summary.json').write_text(json.dumps(summary,indent=2)+'\n');print(json.dumps(summary),flush=True)

if __name__=='__main__':main()
