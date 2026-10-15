"""Compare scatter reads, destination headers, read-ahead and retained failure state."""
import argparse
from collections import Counter
import hashlib,itertools,json,os,re,shutil
from pathlib import Path
from verify_jpeg_contracts_reference import implementation_hashes
from verify_tiff_decode_reference import ProofLog,tree_hash,work_directory,PINNED_SOURCE_SHA256,checked_trap
from verify_stream_guards_reference import stdlib_hash,PINNED_STDLIB_SHA256
from verify_image_open_reference import PATH_LIBRARIES,path_library_hashes
from verify_image_tty_reference import ENCODER_LIBRARIES,encoder_library_hashes


EXPECTED_ROWS = 10476
EXPECTED_SHA256 = '69dc9cba6c055b4eb57ffcbbf7a5deb1df8f8bae431d2eaef2fd917247062856'
EXPECTED_CONTROLS = 370
EXPECTED_CONTROL_SHA256 = '6ee504eef56d51ea0a87055fa830b6b16c70c13fcff1d799ace488cb1d764225'
EXPECTED_TRAPS = 110
EXPECTED_STATE_SHA256 = 'c6b0b03d6bba78dfae2e0f72e63e85f248fe10d6ce24eeca4cdd9153e913c12f'

LAYOUTS=((),((0,0),),((1,1),),((0,0),(1,2),(5,0),(7,3)),((2,3),(1,4),(9,0)),tuple((i*2,1) for i in range(15)),tuple((i*2,1) for i in range(16))+((33,0),),tuple((i*2,1) for i in range(17))+((35,0),))
CAPACITY_PANIC='index out of bounds: index 16, len 16'
def layout_text(layout):return ','.join(f'{offset}:{length}' for offset,length in layout) if layout else '-'
def parse_layout(text):return tuple(tuple(map(int,item.split(':'))) for item in text.split(',')) if text and text!='-' else ()
def spec(kind=1,warmup=0,cap=8,start=0,consume_mode=0,payload=b'abcdefghi',replacement=0,consumed=0,seed=0,prime=0,delta=0,op=0,layout=LAYOUTS[3]):
    return '|'.join(map(str,(kind,warmup,cap,start,consume_mode)))+'|'+payload.hex()+'|'+'|'.join(map(str,(replacement,consumed,seed,prime,delta,op)))+'|'+layout_text(layout)
def corpus():
    rows=[]
    for kind,cap,length,op,profile in itertools.product(range(3),(0,1,8),(0,1,7,8,17,33),range(2),range(len(LAYOUTS))):
        payload=bytes((i*37+19)&255 for i in range(length));layout=LAYOUTS[profile]
        for start,prime,mode in itertools.product(sorted({0,1,length}),(0,1),(0,3)):
            rows.append(('basic',spec(kind,cap=cap,start=start,consume_mode=mode,payload=payload,prime=prime,op=op,layout=layout)))
    payload=bytes((i*37+19)&255 for i in range(128))
    for op,profile,kind,delta in itertools.product(range(2),(2,3,4,5,6,7),range(3),(-1,0,1)):
        rows.append(('relative-seek',spec(kind,cap=8,payload=payload,prime=1,delta=delta,op=op,layout=LAYOUTS[profile])))
    for op,profile,cap,start,consumed,closed,prime in itertools.product(range(2),(0,2,3,4,5,6),(8,32),(0,1),(1,7),(1,2),(0,1,2)):
        for seed in sorted({cap-consumed,cap+start+21}):
            rows.append(('replacement',spec(warmup=1,cap=cap,start=start,payload=payload,replacement=closed,consumed=consumed,seed=seed,prime=prime,op=op,layout=LAYOUTS[profile])))
    if len({data for _,data in rows})!=len(rows):raise AssertionError('duplicate returning input')
    return rows

def controls():
    rows=[]
    for kind,cap,length,op,n,tail in itertools.product(range(3),(0,8),(0,1,17,64),range(2),(16,17,18),(0,1)):
        layout=tuple((i*2,1) for i in range(n))+(((2*n,0),) if tail else ())
        name=f'slots-{kind}-{cap}-{length}-{op}-{n}-{tail}'
        rows.append((name,spec(kind,cap=cap,payload=bytes((i*37+19)&255 for i in range(length)),op=op,layout=layout),CAPACITY_PANIC))
    payload=bytes((i*37+19)&255 for i in range(128))
    for kind,op,consumed,n,closed,prime in itertools.product((1,2),range(2),(1,7),(16,17),(0,1,2),(0,1)):
        name=f'pending-slots-{kind}-{op}-{consumed}-{n}-{closed}-{prime}'
        rows.append((name,spec(kind,warmup=1,cap=8,start=1,payload=payload,replacement=closed,consumed=consumed,seed=8-consumed,prime=prime,op=op,layout=tuple((2*i,1) for i in range(n))),CAPACITY_PANIC))
    for op,profile,cap,consumed,closed,prime in itertools.product(range(2),(0,3,6),(8,32),(1,7),(1,2),(1,2)):
        name=f'position-{op}-{profile}-{cap}-{consumed}-{closed}-{prime}'
        rows.append((name,spec(warmup=1,cap=cap,start=1,payload=payload,replacement=closed,consumed=consumed,seed=cap-consumed-1,prime=prime,op=op,layout=LAYOUTS[profile]),'integer overflow'))
    if len({name for name,_,_ in rows})!=len(rows) or len({data for _,data,_ in rows})!=len(rows):raise AssertionError('duplicate control label/input')
    return rows

def fields(part,panic=False):
    status,metadata,buffer,output,heads,result,pending=part.split('|');m=metadata.split(':')
    if len(m)!=(5 if panic else 6):raise AssertionError('missing vector reader metadata')
    return status,m,bytes.fromhex(buffer),bytes.fromhex(output),parse_layout(heads),result,bytes.fromhex(pending)

def modeled_call(kind,op,payload,old_buffer,seek,end,file_pos,old_output,layout):
    buffer=bytearray(old_buffer);output=bytearray(old_output)
    def read_once(active):
        nonlocal seek,end,file_pos
        start=seek
        for index,(offset,length) in enumerate(active):
            count=min(end-seek,length);output[offset:offset+count]=buffer[seek:seek+count];seek+=count
            if count==length:continue
            copied=seek-start
            if kind==0:return ('ok',copied) if copied else ('EndOfStream',None)
            tail=((offset+count,length-count),)+active[index+1:];io=[];data_size=0;full=False
            for off,n in tail:
                if len(io)==16:full=True;break
                if n:io.append((off,n));data_size+=n
            if not full and buffer:
                seek=end=0
                if len(io)==16:return ('trap',None)
                io.append((-1,len(buffer)))
            capacity=sum(n for _,n in io) if kind==2 else io[0][1]
            n=min(capacity,max(0,len(payload)-file_pos))
            if n==0:return ('ok',copied) if copied else ('EndOfStream',None)
            used=0
            for off,length in io:
                count=min(length,n-used)
                if off==-1:buffer[:count]=payload[file_pos+used:file_pos+used+count]
                else:output[off:off+count]=payload[file_pos+used:file_pos+used+count]
                used+=count
                if used==n:break
            file_pos+=n
            if n>data_size:end+=n-data_size
            return ('ok',copied+min(n,data_size))
        return ('ok',seek-start)
    if op==0:status,result=read_once(layout)
    else:
        index=truncate=0;status='ok';result='all'
        while index<len(layout):
            offset,length=layout[index];active=((offset+truncate,length-truncate),)+layout[index+1:]
            status,n=read_once(active)
            if status!='ok':result=None;break
            truncate+=n
            while index<len(layout) and truncate>=layout[index][1]:truncate-=layout[index][1];index+=1
    return status,result,bytes(buffer),seek,end,file_pos,bytes(output)

def snapshot_checks(line,data):
    f=data.split('|');kind,warmup,cap,start,mode=map(int,f[:5]);payload=bytes.fromhex(f[5]);replacement,consumed,seed,prime,delta,op=map(int,f[6:12]);layout=parse_layout(f[12]);parts=line.decode().split('~');size=max((o+n for o,n in layout),default=0)+8
    if len(parts)!=10:raise AssertionError('missing vector snapshots')
    states=[fields(part) for part in parts[:-1]]
    for index,(status,m,buffer,output,heads,result,pending) in enumerate(states):
        maximum=len(payload) if kind==0 else cap;seek,end=map(int,m[4:])
        if m[2:4]!=(['0','0'] if kind==0 else ['1',str(2 if index==0 or replacement==0 else (2 if replacement==2 else 3))]):raise AssertionError('reader ownership differs')
        if len(buffer)!=maximum or len(output)!=size or not 0<=seek<=end<=maximum or pending!=buffer[seek:end]:raise AssertionError('initialized vector spans differ')
        if heads!=layout:raise AssertionError('destination headers not restored')
        if status not in ('ok','skip','EndOfStream','ReadFailed','Unseekable') and not (status.startswith('consumed-') and status[9:].isdecimal()):raise AssertionError('unexpected vector status '+status)
        if result!='-' and (result!='all' if op else (not result.isdecimal() or int(result)>sum(n for _,n in layout))):raise AssertionError('invalid retained vector result')
    for before,call in ((1,2),(4,5),(6,7)):
        _,m,buffer,output,_,result,pending=states[before];status,later,changed,written,_,saved,tail=states[call]
        if status!='ok' and saved!=result:raise AssertionError('failed vector call replaced retained result')
        if not any(n for _,n in layout):
            if status!='ok' or m!=later or buffer!=changed or output!=written or pending!=tail or saved!=('all' if op else '0'):raise AssertionError('empty vector read performed IO')
        if replacement==0 and (kind!=2 or delta==0):
            status_model,n,buffer_model,seek,end,file_pos,output_model=modeled_call(kind,op,payload,buffer,int(m[4]),int(m[5]),int(m[0])+len(pending),output,layout)
            position=seek if kind==0 else file_pos-(end-seek)
            expected_result=str(n) if status_model=='ok' else result
            if status!=status_model or saved!=expected_result or written!=output_model or changed!=buffer_model or list(map(int,later[4:]))!=[seek,end] or int(later[0])!=position:raise AssertionError('independent scatter value/progress differs')
    for call,after in ((2,3),(5,6),(7,8)):
        _,m,buffer,output,heads,result,pending=states[call];status,later,changed,written,heads2,result2,tail=states[after];n=int(status[9:]);expected=(len(pending) if mode==1 else ((len(pending)+1)//2 if mode==3 else 0))
        if n!=expected or tail!=pending[n:] or changed!=buffer or written!=output or heads2!=heads or result2!=result or int(later[0])!=int(m[0])+n or later[1:4]!=m[1:4] or list(map(int,later[4:]))!=[int(m[4])+n,int(m[5])]:raise AssertionError('caller vector consumption differs')
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
    if not states[0] or states[0]!=states[1]:raise AssertionError(name+': retained vector failure state differs')
    status,m,buffer,output,heads,result,pending=fields(states[0].decode(),True);f=data.split('|');kind=int(f[0]);layout=parse_layout(f[12]);maximum=len(bytes.fromhex(f[5])) if kind==0 else int(f[2]);seek,end=map(int,m[3:]);size=max((o+n for o,n in layout),default=0)+8
    if m[1:3]!=(['0','0'] if kind==0 else ['1',str(2 if f[6] in ('0','2') else 3)]) or len(buffer)!=maximum or len(output)!=size or not 0<=seek<=end<=maximum or pending!=buffer[seek:end] or len(heads)!=len(layout):raise AssertionError(name+': invalid failure spans/ownership')
    if any(not o<=a<=o+n or a+b!=o+n for (a,b),(o,n) in zip(heads,layout)):raise AssertionError(name+': invalid temporarily shortened header')
    if status!=('calling' if category==CAPACITY_PANIC else 'ok'):raise AssertionError(name+': unexpected failure order')
    if category==CAPACITY_PANIC and (kind==0 or maximum==0 or seek!=0 or end!=0):raise AssertionError(name+': slot trap did not follow buffer reset')
    return ('trap',category.encode()+b'\0'+states[0]+b'\n')

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source',type=Path);parser.add_argument('zig',type=Path);parser.add_argument('v',type=Path)
    parser.add_argument('--target',default='aarch64-macos.14.0');parser.add_argument('--v-prod',action='store_true');parser.add_argument('--workdir',type=Path);parser.add_argument('--timeout',type=int,default=600)
    args=parser.parse_args()
    if args.timeout<=0:parser.error('--timeout must be positive')
    source=args.source.resolve()/'src';zig=args.zig.resolve();v=args.v.resolve()
    if tree_hash(source)!=PINNED_SOURCE_SHA256 or stdlib_hash(zig)!=PINNED_STDLIB_SHA256 or path_library_hashes(zig)!=PATH_LIBRARIES or encoder_library_hashes(zig)!=ENCODER_LIBRARIES:parser.error('Source/compiler library differs from pins')
    repo=Path(__file__).resolve().parent.parent;probe=repo/'zigimg/reference_probes/reader_vectors';mode='ReleaseSafe' if args.v_prod else 'Debug'
    with work_directory(args.workdir,'witty-reader-vectors-') as root:
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
        print(f'Building scatter reads: Source {mode}, V {"production" if args.v_prod else "ordinary"}',flush=True)
        proof.run([str(zig),'build-exe','-target',args.target,'-lc','-I',str(root),'-O',mode,'--global-cache-dir',str(root.parent/'zig-global'),'--cache-dir',str(root/'zig-cache'),'-femit-bin='+str(root/'native'),str(root/'reference.zig'),str(root/'fixture_shims.c')],'build-source',env=env,timeout=args.timeout)
        proof.run([str(v),'-enable-globals',*(['-prod'] if args.v_prod else []),'-path',f'{repo}|@vlib|@vmodules','-o',str(root/'translated'),str(root/'main.v')],'build-v',env=env,timeout=args.timeout)
        rows=corpus();path=root/'corpus.txt';path.write_text('\n'.join(data for _,data in rows)+'\n');inputs={'corpus.txt':hashlib.sha256(path.read_bytes()).hexdigest()};(root/'input_sha256.json').write_text(json.dumps(inputs,indent=2)+'\n')
        outputs=[]
        for exe in ('native','translated'):
            result=proof.run([str(root/exe),str(path)],'returning-'+exe,env=env,timeout=args.timeout)
            if result.stderr or len(result.stdout.splitlines())!=len(rows):raise AssertionError('invalid returning output')
            outputs.append(result.stdout.splitlines())
        for i,((group,data),native,translated) in enumerate(zip(rows,*outputs)):
            if native!=translated:raise AssertionError(f'{i}/{group}: scatter reader record differs; see retained proof')
            snapshot_checks(native,data)
        digest=hashlib.sha256(b'\n'.join(outputs[0])).hexdigest()
        if EXPECTED_ROWS is not None and (len(rows)!=EXPECTED_ROWS or digest!=EXPECTED_SHA256):raise AssertionError('returning golden changed')
        returns=hashlib.sha256();states=hashlib.sha256();return_count=0;trap_count=0
        print(f'{len(rows)} returning scatter records match; checking failure controls',flush=True)
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
        summary=dict(returning_records=len(rows),vector_calls=3*len(rows),primary_calls=7*len(rows),returning_groups=dict(Counter(group for group,_ in rows)),output_sha256=digest,return_controls=return_count,control_sha256=returns.hexdigest(),paired_traps=trap_count,state_sha256=states.hexdigest(),zig_mode=mode,v_prod=args.v_prod)
        (root/'summary.json').write_text(json.dumps(summary,indent=2)+'\n');print(json.dumps(summary),flush=True)

if __name__=='__main__':main()
