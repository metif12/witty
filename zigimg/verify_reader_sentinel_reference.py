"""Compare sentinel slices, required terminators, aliases and retained failures."""
import argparse
from collections import Counter
import hashlib,itertools,json,os,re,shutil
from pathlib import Path
from verify_jpeg_contracts_reference import implementation_hashes
from verify_tiff_decode_reference import ProofLog,tree_hash,work_directory,PINNED_SOURCE_SHA256,checked_trap
from verify_stream_guards_reference import stdlib_hash,PINNED_STDLIB_SHA256
from verify_image_open_reference import PATH_LIBRARIES,path_library_hashes
from verify_image_tty_reference import ENCODER_LIBRARIES,encoder_library_hashes

EXPECTED_ROWS = 12192
EXPECTED_SHA256 = '24d156384636b33317352082b3fd68a7a0f2b6300b7b55233f8e90ebac05a8c4'
EXPECTED_BORROWS = 3120
EXPECTED_BORROW_SHA256 = 'dac10ac470a9d1c38d17383af20fe209dc452b3177fea44ddfdcfe15c82dda1d'
EXPECTED_CONTROLS = 48
EXPECTED_CONTROL_SHA256 = '98bd55c52b3a4ff654d075287a96e18ca6affc11c54f5ba338dee77fcf602b94'
EXPECTED_TRAPS = 84
EXPECTED_STATE_SHA256 = '409750f80c4727cbc6664d64fd0c0df30cc2aa568a09cfd3d665f27bfb4108b3'

def spec(kind=0,api=0,cap=8,start=0,sentinel=0,payload=b'abcdefghi',replacement=0,consumed=0,seed=0,prime=0,delta=0):
    return '|'.join(map(str,(kind,api,cap,start,sentinel)))+'|'+payload.hex()+'|'+'|'.join(map(str,(replacement,consumed,seed,prime,delta)))
def corpus():
    rows=[]
    for kind,api,length in itertools.product(range(3),range(2),(0,1,7,8,9,31,32,33,64)):
        payload=bytes((i*37+19)&255 for i in range(length))
        markers=sorted({0,19,255,*payload[length//2:length//2+1],*payload[-1:]})
        for cap,start,marker,delta in itertools.product((8,) if kind==0 else (0,1,8,32),sorted({0,1,length//2,length}),markers,(-1,0,1)):
            rows.append(('basic',spec(kind,api,cap,start,marker,payload,delta=delta)))
    for kind,api,marker in itertools.product(range(3),range(2),range(256)):
        rows.append(('every-sentinel',spec(kind,api,8,sentinel=marker,payload=bytes((marker^128,marker,marker^127,marker)))))
    payload=bytes((i*37+19)&255 for i in range(128))
    for api,cap,start,consumed,closed,prime,delta in itertools.product(range(2),(8,32),(0,1),(1,7),(1,2),range(3),(-1,0,1)):
        for seed in sorted({cap-consumed,start+cap+17}):
            for marker in sorted({0,255,payload[start+consumed],payload[start+cap-1],(cap*31+7)&255}):
                rows.append(('replacement',spec(1,api,cap,start,marker,payload,closed,consumed,seed,prime,delta)))
    seen=set();result=[]
    for group,data in rows:
        if data not in seen:seen.add(data);result.append((group,data))
    return result

def controls():
    rows=[];payload=bytes((i*37+19)&255 for i in range(128))
    for api,marker,cap,consumed,closed in itertools.product(range(2),(0,7,255),(8,32),(1,7),(1,2)):
        for seed in sorted({0,cap-consumed-1,cap-consumed}):
            rows.append((f'position-{api}-{marker}-{cap}-{consumed}-{closed}-{seed}',spec(1,api,cap,sentinel=marker,payload=payload,replacement=closed,consumed=consumed,seed=seed,prime=1),'integer overflow'))
    assert len(rows)==len({name for name,_,_ in rows})==len({data for _,data,_ in rows})
    return rows

def borrow_corpus():
    rows=[]
    for marker,api,kind,prefix_len in itertools.product(range(256),range(2),range(3),(0,3)):
        payload=bytes((marker+1+37*i)&255 for i in range(prefix_len))+bytes((marker,marker^32))
        rows.append(spec(kind,api,8,sentinel=marker,payload=payload))
    for marker,api,kind,prefix_len in itertools.product((0,10,19,255),range(2),range(3),(1,7)):
        payload=bytes((marker^128,))+bytes((marker+1+37*i)&255 for i in range(prefix_len))+bytes((marker,marker^32))
        rows.append(spec(kind,api,32,start=1,sentinel=marker,payload=payload))
    return rows

def snapshot_checks(line,data):
    f=data.split('|');kind,api,cap,start,marker=map(int,f[:5]);payload=bytes.fromhex(f[5]);replacement,consumed,seed,prime,delta=map(int,f[6:]);parts=line.decode().split('~')
    assert len(parts)==7
    for index,part in enumerate(parts[:-1]):
        status,metadata,buffer,output,pending=part.split('|');m=metadata.split(':');maximum=len(payload) if kind==0 else cap;copied=bytes.fromhex(output)
        assert len(m)==4 and m[-2:]==(['0','0'] if kind==0 else ['1',str(2 if index==0 or replacement==0 else (2 if replacement==2 else 3))])
        assert len(bytes.fromhex(buffer))==maximum and len(bytes.fromhex(pending))<=maximum and len(copied)<=maximum
        assert status in ('ok','skip','EndOfStream','ReadFailed','StreamTooLong','Unseekable')
        if copied:assert copied[-1]==marker and marker not in copied[:-1]
    physical=min(cap,len(payload)) if kind==2 and prime>0 else 0
    for prior,index in ((1,2),(3,4),(4,5)):
        old=parts[prior].split('|');now=parts[index].split('|');pending=bytes.fromhex(now[4]);old_pending=bytes.fromhex(old[4]);position=int(old[1].split(':')[0])
        if now[0]!='ok':assert now[3]==old[3]
        else:assert bytes.fromhex(now[3])
        if replacement==0:
            source=payload[position:] if kind!=2 else old_pending+payload[physical:];found=source.find(bytes((marker,)));maximum=len(source) if kind==0 else cap
            success=found>=0 and found<maximum;status='ok' if success else ('EndOfStream' if kind==0 or len(source)<cap else 'StreamTooLong');used=found+1 if success and api==1 else 0
            assert now[0]==status and int(now[1].split(':')[0])==position+used
            assert bytes.fromhex(now[3])==(source[:found+1] if success else bytes.fromhex(old[3]))
            if kind==2:physical+=used+len(pending)-len(old_pending)
    assert parts[-1].split(':')[0]==('-3' if replacement==0 else ('0' if replacement==2 else '-1'))

def borrow_checks(line,data):
    f=data.split('|');kind,api,cap,start,marker=map(int,f[:5]);payload=bytes.fromhex(f[5]);parts=[p.split('|') for p in line.decode().split('~')];assert len(parts)==5
    initial=parts[0];b,c,m,t=parts[1:];assert [s[0] for s in parts[1:]]==['borrow','caller','alias','toss'];maximum=len(payload) if kind==0 else cap;offset=int(b[6]);original=bytes.fromhex(b[5]);saved=bytes.fromhex(b[3]);position=int(initial[1].split(':')[0]);count=payload[position:].index(marker)+1
    assert offset==(position if kind==0 else 0) and len(original)==count and saved==original and original[-1]==marker and marker not in original[:-1]
    assert int(b[1].split(':')[0])==position+(count if api==1 else 0)
    for phase,s in enumerate(parts):assert len(s)==(5 if phase==0 else 7) and len(bytes.fromhex(s[2]))==maximum and s[1].split(':')[-2:]==(['0','0'] if kind==0 else ['1','2'])
    flipped=bytes(x^128 for x in original[:-1])+original[-1:];changed=(bytes((flipped[0]^64,))+flipped[1:] if count>1 else flipped)
    assert all(s[3]==b[3] and s[6]==b[6] for s in (c,m,t)) and bytes.fromhex(c[5])==flipped and bytes.fromhex(m[5])==bytes.fromhex(t[5])==changed
    before=bytes.fromhex(b[2]);end=offset+count-1;caller=bytes(x if i==end else x^128 for i,x in enumerate(before));mutated=caller[:offset]+bytes((caller[offset]^64,))+caller[offset+1:] if count>1 else caller
    assert bytes.fromhex(c[2])==caller and bytes.fromhex(m[2])==bytes.fromhex(t[2])==mutated
    assert int(c[1].split(':')[0])==int(m[1].split(':')[0])==int(b[1].split(':')[0]) and int(t[1].split(':')[0])==int(m[1].split(':')[0])+len(bytes.fromhex(m[4])) and t[4]==''

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
    if len(fields)!=5 or fields[1].split(':')[-2:]!=(['0','0'] if f[0]=='0' else ['1',str(2 if f[6] in ('0','2') else 3)]):raise AssertionError(name+': invalid panic observer')
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
    repo=Path(__file__).resolve().parent.parent;probe=repo/'zigimg/reference_probes/reader_sentinel';mode='ReleaseSafe' if args.v_prod else 'Debug'
    with work_directory(args.workdir,'witty-reader-sentinel-') as root:
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
        print(f'Building sentinel slices: Source {mode}, V {"production" if args.v_prod else "ordinary"}',flush=True)
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
        print(f'{len(rows)} returning sentinel records match; checking failure controls',flush=True)
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
