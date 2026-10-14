"""Compare buffered reader access, byte reads, aliases and retained failures."""
import argparse
from collections import Counter
import hashlib,itertools,json,os,re,shutil
from pathlib import Path
from verify_jpeg_contracts_reference import implementation_hashes
from verify_tiff_decode_reference import ProofLog,tree_hash,work_directory,PINNED_SOURCE_SHA256,checked_trap
from verify_stream_guards_reference import stdlib_hash,PINNED_STDLIB_SHA256
from verify_image_open_reference import PATH_LIBRARIES,path_library_hashes
from verify_image_tty_reference import ENCODER_LIBRARIES,encoder_library_hashes

EXPECTED_ROWS = 14784
EXPECTED_SHA256 = '4104b891822a2dd76c7e96e63cf204477b1e86dfa815804b2d3625b50e75d4a3'
EXPECTED_BORROWS = 412
EXPECTED_BORROW_SHA256 = '42309fdc2de38f70adaeda3a8abdce6ff28417248c9e73394f152df3b3162825'
EXPECTED_CONTROLS = 472
EXPECTED_CONTROL_SHA256 = '60f1c53c3b84c15493d1e5bff2f4766ec64b31e764abb63c5e9cb3739bfd3a2c'
EXPECTED_TRAPS = 216
EXPECTED_STATE_SHA256 = '9205d55daef26b3c2d42fc037d408d97b5fa80185bedfc73f6ffdd35b4205164'

def spec(kind=0,api=0,cap=8,start=0,count=0,payload=b'abcdefghi',replacement=0,consumed=0,seed=0,prime=0,delta=0):
    return '|'.join(map(str,(kind,api,cap,start,count)))+'|'+payload.hex()+'|'+'|'.join(map(str,(replacement,consumed,seed,prime,delta)))

def counts(api,cap):
    return sorted({0,1,max(0,cap-1),cap}) if api in (1,2) else (0,)

def corpus():
    rows=[]
    readers=[(0,8),*((kind,cap) for kind,cap in itertools.product((1,2),(0,1,2,8,32)))]
    for (kind,cap),api,length in itertools.product(readers,range(6),(0,1,7,8,9,31,32,33,64)):
        if kind>0 and cap==0 and api in (4,5):continue
        payload=bytes((i*37+19)&255 for i in range(length))
        for count,start,delta in itertools.product(counts(api,cap),sorted({0,1,length//2,length}),(-1,0,1)):
            if kind>0 and count>cap:continue
            rows.append(('basic',spec(kind,api,cap,start,count,payload,delta=delta)))
    for kind,api,byte in itertools.product(range(3),(4,5),range(256)):
        rows.append(('all-bytes',spec(kind,api,8,payload=bytes((byte,byte^128,0,127,128,255)))))
    payload=bytes((i*37+19)&255 for i in range(128))
    for api,cap,start in itertools.product(range(6),(1,8,32),(0,7)):
        for consumed,count,closed,seed,delta in itertools.product(sorted({0,1,cap-1,cap}),counts(api,cap),(1,2),sorted({cap,start+2*cap+1}),(-1,0,1)):
            rows.append(('replacement',spec(1,api,cap,start,count,payload,closed,consumed,seed,0,delta)))
    for api,cap,consumed,closed,prime in itertools.product(range(6),(8,32),(1,7),(1,2),(1,2)):
        if consumed>=cap:continue
        for count,delta in itertools.product(counts(api,cap),(-1,0,1)):
            rows.append(('failed-pending' if prime==1 else 'failed-consumed',spec(1,api,cap,0,count,payload,closed,consumed,cap-consumed,prime,delta)))
    return rows

def controls():
    rows=[]
    for kind,api,payload in itertools.product((1,2),range(6),(b'',b'a\nlast')):
        for count in ((0,1) if api in (1,2) else (0,)):
            name=f'capacity-{kind}-{api}-{len(payload)}-{count}'
            rows.append((name,spec(kind,api,0,count=count,payload=payload),'reached unreachable code'))
    for kind,api,payload,start in itertools.product((1,2),(1,2),(b'',bytes(range(17))),(0,1)):
        name=f'oversize-{kind}-{api}-{len(payload)}-{start}'
        rows.append((name,spec(kind,api,8,start,9,payload),'reached unreachable code'))
    payload=bytes((i*37+19)&255 for i in range(128))
    for api,cap,start,consumed in itertools.product((1,2),(8,32),(0,7),(1,7)):
        name=f'oversize-pending-{api}-{cap}-{start}-{consumed}'
        rows.append((name,spec(1,api,cap,start,cap+1,payload,1,consumed,2*cap+1),'reached unreachable code'))
    for api,cap,consumed,closed,prime in itertools.product(range(6),(8,32),(1,7),(1,2),(1,2)):
        for seed,count in itertools.product(sorted({0,cap-consumed-1,cap-consumed,cap-1}),counts(api,cap)):
            name=f'position-{api}-{cap}-{consumed}-{closed}-{prime}-{seed}-{count}'
            rows.append((name,spec(1,api,cap,0,count,payload,closed,consumed,seed,prime),'integer overflow'))
    if len({name for name,_,_ in rows})!=len(rows) or len({data for _,data,_ in rows})!=len(rows):raise AssertionError('duplicate control label/input')
    return rows

def borrow_corpus():
    rows=[]
    for kind,api,cap,length in itertools.product(range(3),(0,1),(0,1,8,32),(0,1,7,8,9,33)):
        if kind==0 and cap!=8:continue
        payload=bytes((i*37+19)&255 for i in range(length))
        for start in sorted({0,1,length//2}):
            for count in ((0,) if api==0 else sorted({0,1,cap})):
                if kind>0 and count>min(cap,length-(start if kind==1 and start<length else 0)):continue
                if kind==0 and count>max(0,length-(start if start<length else 0)):continue
                rows.append(spec(kind,api,cap,start,count,payload))
    return rows

def snapshot_checks(line,data):
    f=data.split('|');kind,api,cap,start,count=map(int,f[:5]);payload=bytes.fromhex(f[5]);replacement,consumed,seed,prime,delta=map(int,f[6:]);parts=line.decode().split('~')
    if len(parts)!=7:raise AssertionError('missing buffered reader snapshots')
    for index,part in enumerate(parts[:-1]):
        status,metadata,buffer,output,pending=part.split('|');m=metadata.split(':')
        if len(m)!=4 or m[-2:]!=(['0','0'] if kind==0 else ['1',str(2 if index==0 or replacement==0 else (2 if replacement==2 else 3))]):raise AssertionError('reader ownership differs')
        if len(bytes.fromhex(buffer))!=(len(payload) if kind==0 else cap) or len(bytes.fromhex(pending))>(len(payload) if kind==0 else cap):raise AssertionError('reader spans differ')
        if len(bytes.fromhex(output))>max(1,len(payload) if kind==0 else cap):raise AssertionError('saved result span differs')
        if status not in ('ok','skip','EndOfStream','ReadFailed','Unseekable'):
            if not status.startswith('ok:') or api not in (4,5):raise AssertionError('unexpected reader status '+status)
            value=int(status[3:]);expected=bytes((value&255,))
            if bytes.fromhex(output)!=expected or not (0<=value<=255 if api==4 else -128<=value<=127):raise AssertionError('invalid byte result')
    if parts[-1].split(':')[0]!=('-3' if replacement==0 else ('0' if replacement==2 else '-1')):raise AssertionError('reader wire status differs')

def borrow_checks(line,data):
    f=data.split('|');kind,api,cap,start,count=map(int,f[:5]);payload=bytes.fromhex(f[5]);parts=line.decode().split('~')
    if len(parts)!=5:raise AssertionError('missing borrow snapshots')
    states=[p.split('|') for p in parts];initial=states[0];b,c,m,t=states[1:]
    if [s[0] for s in states[1:]]!=['borrow','caller','alias','toss']:raise AssertionError('borrow phases differ')
    size=len(payload) if kind==0 else cap
    for s in states:
        if len(s)!=(5 if s is initial else 6) or len(bytes.fromhex(s[2]))!=size:raise AssertionError('borrow backing span differs')
    for s in states:
        metadata=s[1].split(':')
        if len(metadata)!=4 or metadata[-2:]!=(['0','0'] if kind==0 else ['1','2']):raise AssertionError('borrow ownership differs')
    original,flipped,mutated,retained=map(lambda s:bytes.fromhex(s[5]),(b,c,m,t));saved=bytes.fromhex(b[3])
    if saved!=original or any(bytes.fromhex(s[3])!=saved for s in (c,m,t)):raise AssertionError('copied borrow changed')
    if flipped!=bytes(byte^128 for byte in original):raise AssertionError('caller mutation not visible through alias')
    if mutated!=(bytes((flipped[0]^64,))+flipped[1:] if flipped else b'') or retained!=mutated:raise AssertionError('alias mutation/toss lifetime differs')
    if bytes.fromhex(c[2])!=bytes(byte^128 for byte in bytes.fromhex(b[2])):raise AssertionError('complete caller mutation differs')
    before,after=bytes.fromhex(c[2]),bytes.fromhex(m[2]);offset=(int(b[1].split(':')[0]) if kind==0 else 0)
    if after!=(before[:offset]+bytes((before[offset]^64,))+before[offset+1:] if original else before) or m[2]!=t[2]:raise AssertionError('alias mutation not visible in caller storage')
    if any(s[4]!=s[5] for s in (b,c,m)) or t[4]!='':raise AssertionError('borrowed pending/toss spans differ')
    if any(s[1].split(':')[0]!=b[1].split(':')[0] for s in (c,m)):raise AssertionError('borrow advanced reader')
    if int(t[1].split(':')[0])!=int(b[1].split(':')[0])+len(original):raise AssertionError('buffered toss count differs')

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
    if len(fields)!=5 or fields[1].split(':')[-2:]!=['1',str(2 if f[6] in ('0','2') else 3)]:raise AssertionError(name+': invalid panic observer')
    if category=='reached unreachable code' and fields[0]!='calling':raise AssertionError(name+': unexpected failure order')
    if category=='integer overflow' and fields[0]!='ok':raise AssertionError(name+': unexpected position failure order')
    return ('trap',category.encode()+b'\0'+states[0]+b'\n')

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source',type=Path);parser.add_argument('zig',type=Path);parser.add_argument('v',type=Path)
    parser.add_argument('--target',default='aarch64-macos.14.0');parser.add_argument('--v-prod',action='store_true');parser.add_argument('--workdir',type=Path);parser.add_argument('--timeout',type=int,default=600)
    args=parser.parse_args()
    if args.timeout<=0:parser.error('--timeout must be positive')
    source=args.source.resolve()/'src';zig=args.zig.resolve();v=args.v.resolve()
    if tree_hash(source)!=PINNED_SOURCE_SHA256 or stdlib_hash(zig)!=PINNED_STDLIB_SHA256 or path_library_hashes(zig)!=PATH_LIBRARIES or encoder_library_hashes(zig)!=ENCODER_LIBRARIES:parser.error('Source/compiler library differs from pins')
    repo=Path(__file__).resolve().parent.parent;probe=repo/'zigimg/reference_probes/reader_buffered';mode='ReleaseSafe' if args.v_prod else 'Debug'
    with work_directory(args.workdir,'witty-reader-buffered-') as root:
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
        print(f'Building buffered readers: Source {mode}, V {"production" if args.v_prod else "ordinary"}',flush=True)
        proof.run([str(zig),'build-exe','-target',args.target,'-lc','-I',str(root),'-O',mode,'--global-cache-dir',str(root.parent/'zig-global'),'--cache-dir',str(root/'zig-cache'),'-femit-bin='+str(root/'native'),str(root/'reference.zig'),str(root/'fixture_shims.c')],'build-source',env=env,timeout=args.timeout)
        proof.run([str(v),'-enable-globals',*(['-prod'] if args.v_prod else []),'-path',f'{repo}|@vlib|@vmodules','-o',str(root/'translated'),str(root/'main.v')],'build-v',env=env,timeout=args.timeout)
        rows=corpus();path=root/'corpus.txt';path.write_text('\n'.join(data for _,data in rows)+'\n');inputs={'corpus.txt':hashlib.sha256(path.read_bytes()).hexdigest()};(root/'input_sha256.json').write_text(json.dumps(inputs,indent=2)+'\n')
        outputs=[]
        for exe in ('native','translated'):
            result=proof.run([str(root/exe),str(path)],'returning-'+exe,env=env,timeout=args.timeout)
            if result.stderr or len(result.stdout.splitlines())!=len(rows):raise AssertionError('invalid returning output')
            outputs.append(result.stdout.splitlines())
        for i,((group,data),native,translated) in enumerate(zip(rows,*outputs)):
            if native!=translated:raise AssertionError(f'{i}/{group}: reader/writer record differs; see retained proof')
            snapshot_checks(native,data)
        digest=hashlib.sha256(b'\n'.join(outputs[0])).hexdigest()
        if EXPECTED_ROWS is not None and (len(rows)!=EXPECTED_ROWS or digest!=EXPECTED_SHA256):raise AssertionError('returning golden changed')
        borrowed=borrow_corpus();bpath=root/'borrow.txt';bpath.write_text('\n'.join(borrowed)+'\n');inputs['borrow.txt']=hashlib.sha256(bpath.read_bytes()).hexdigest();(root/'input_sha256.json').write_text(json.dumps(inputs,indent=2)+'\n');boutputs=[]
        for exe in ('native','translated'):
            result=proof.run([str(root/exe),'--borrow',str(bpath)],'borrow-'+exe,env=env,timeout=args.timeout)
            if result.stderr or len(result.stdout.splitlines())!=len(borrowed):raise AssertionError('invalid borrowed output')
            boutputs.append(result.stdout.splitlines())
        if boutputs[0]!=boutputs[1]:raise AssertionError('borrowed records differ')
        for data,line in zip(borrowed,boutputs[0]):borrow_checks(line,data)
        bdigest=hashlib.sha256(b'\n'.join(boutputs[0])).hexdigest()
        if EXPECTED_BORROWS is not None and (len(borrowed)!=EXPECTED_BORROWS or bdigest!=EXPECTED_BORROW_SHA256):raise AssertionError('borrow golden changed')
        returns=hashlib.sha256();states=hashlib.sha256();return_count=0;trap_count=0
        print(f'{len(rows)} returning buffered reader records match; checking failure controls',flush=True)
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
        summary=dict(returning_records=len(rows),primary_calls=4*len(rows),borrow_records=len(borrowed),borrow_primary_calls=2*len(borrowed),borrow_sha256=bdigest,returning_groups=dict(Counter(group for group,_ in rows)),output_sha256=digest,return_controls=return_count,control_sha256=returns.hexdigest(),paired_traps=trap_count,state_sha256=states.hexdigest(),zig_mode=mode,v_prod=args.v_prod)
        (root/'summary.json').write_text(json.dumps(summary,indent=2)+'\n');print(json.dumps(summary),flush=True)

if __name__=='__main__':main()
