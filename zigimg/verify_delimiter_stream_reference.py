"""Compare delimiter writer streaming, bounds, EOF and retained failure state."""
import argparse
from collections import Counter
import hashlib,itertools,json,os,re,shutil
from pathlib import Path
from verify_jpeg_contracts_reference import implementation_hashes
from verify_tiff_decode_reference import ProofLog,tree_hash,work_directory,PINNED_SOURCE_SHA256,checked_trap
from verify_stream_guards_reference import stdlib_hash,PINNED_STDLIB_SHA256
from verify_image_open_reference import PATH_LIBRARIES,path_library_hashes
from verify_image_tty_reference import ENCODER_LIBRARIES,encoder_library_hashes

EXPECTED_ROWS = 49500
EXPECTED_SHA256 = '1525e99b06bb47e5f627d13699e1c7c57f0aad1b39a5fd4e05f81858fcf17fdf'
EXPECTED_CONTROLS = 84
EXPECTED_CONTROL_SHA256 = '1fe9aad4034d0f0c3ff7318ead2bdd934fca35d64da61265a0ecfb8824b2c344'
EXPECTED_TRAPS = 120
EXPECTED_STATE_SHA256 = '0829ace76ae607860124ece9fbfe5c357d5bb3a1ba8b8394486ae59b19b1320d'

UNLIMITED=(1<<64)-1

def spec(kind=0,api=0,rcap=8,wkind=0,wcap=32,prefill=0,start=0,delimiter=10,limit=UNLIMITED,payload=b'a\nlast',replace=0,consumed=0,seed=0,prime=0,delta=0):
    return '|'.join(map(str,(kind,api,rcap,wkind,wcap,prefill,start,delimiter,limit)))+'|'+payload.hex()+'|'+'|'.join(map(str,(replace,consumed,seed,prime,delta)))

def writer_profiles():
    return [(0,cap,prefix) for cap in (0,1,8,32) for prefix in sorted({0,cap})]+[(kind,cap,prefix) for kind,cap in itertools.product(range(1,7),(0,8)) for prefix in sorted({0,cap})]

def bounds(api,length,cap):
    return (UNLIMITED,) if api<2 else sorted({0,1,length,length+1,cap,cap+1,UNLIMITED})

def corpus():
    rows=[]
    readers=[(0,8),*( (kind,cap) for kind,cap in itertools.product((1,2),(1,8,32)) )]
    for (kind,rcap),api,length,(wkind,wcap,prefill) in itertools.product(readers,range(3),(0,1,7,8,9,33,64),writer_profiles()):
        payload=bytes((i*37+19)&255 for i in range(length))
        for delimiter,limit in itertools.product(sorted({10,19,*payload[-1:]}),bounds(api,length,rcap)):
            rows.append(('basic',spec(kind,api,rcap,wkind,wcap,prefill,delimiter=delimiter,limit=limit,payload=payload)))
    for kind,api,rcap in itertools.product(range(3),range(3),(1,8)):
        for payload in (b'\n',b'\n\n\n',b'a\n\nb\n',b'last',b'a\nlast',b'a\n\n'):
            for wkind,wcap,prefill in ((0,0,0),(0,8,0),(1,1,1),(4,8,8),(5,0,0)):
                for limit in bounds(api,len(payload),rcap):
                    rows.append(('lines',spec(kind,api,rcap,wkind,wcap,prefill,limit=limit,payload=payload)))
    for kind,api,length,start_selector,delta in itertools.product(range(3),range(3),(9,33),(0,1,2),(-1,0,1)):
        payload=bytes((i*37+19)&255 for i in range(length));start=(1,length//2,length)[start_selector]
        for wkind,wcap,prefill in ((0,8,0),(1,8,0),(4,8,8),(5,0,0)):
            for limit in ((1,8,UNLIMITED) if api==2 else (UNLIMITED,)):
                rows.append(('seek',spec(kind,api,8,wkind,wcap,prefill,start,255,limit,payload,delta=delta)))
    for kind,api,delimiter in itertools.product(range(3),range(3),range(256)):
        for wkind,wcap,prefill in ((0,0,0),(0,8,0),(1,0,0),(4,8,8),(5,0,0)):
            rows.append(('all-bytes',spec(kind,api,8,wkind,wcap,prefill,delimiter=delimiter,limit=17,payload=bytes(range(16)))))
    payload=bytes((i*37+19)&255 for i in range(128))
    for api,rcap,replace in itertools.product(range(3),(1,8,32),(1,2)):
        for consumed in sorted({0,1,rcap-1,rcap}):
            for delimiter,seed in itertools.product(sorted({0,255,(consumed*37+19)&255,7}), (0,rcap,2*rcap+1)):
                for wkind,wcap,prefill in ((0,3,0),(0,8,8),(1,8,0),(3,8,0),(5,0,0),(6,8,8)):
                    for limit in ((0,1,rcap+1,UNLIMITED) if api==2 else (UNLIMITED,)):
                        rows.append(('replacement',spec(1,api,rcap,wkind,wcap,prefill,delimiter=delimiter,limit=limit,payload=payload,replace=replace,consumed=consumed,seed=seed)))
    return rows

def controls():
    rows=[]
    for kind,api,payload in itertools.product((1,2),range(3),(b'',b'a\nlast')):
        for wkind,wcap,prefill in ((0,0,0),(1,8,8),(5,0,0)):
            for limit in ((0,1,7) if api==2 else (7,)):
                rows.append((f'capacity-{kind}-{api}-{len(payload)}-{wkind}-{limit}',spec(kind,api,0,wkind,wcap,prefill,limit=limit,payload=payload),'reached unreachable code'))
    payload=bytes((i*37+19)&255 for i in range(128))
    for api,cap,consumed_selector,closed,prime,wkind in itertools.product(range(3),(8,32),(0,1),(1,2),(1,2),(0,5)):
        consumed=1 if consumed_selector==0 else cap-1
        for seed in sorted({0,cap-consumed-1}):
            name=f'position-{api}-{cap}-{consumed}-{seed}-{closed}-{prime}-{wkind}'
            rows.append((name,spec(1,api,cap,wkind,3,0,delimiter=255,limit=cap+1,payload=payload,replace=closed,consumed=consumed,seed=seed,prime=prime),'integer overflow'))
    return rows

def snapshot_checks(line,data):
    f=data.split('|');kind,api,rcap,wkind,wcap,prefill,start,delimiter,limit=map(int,f[:9]);payload=bytes.fromhex(f[9]);replace,consumed,seed,prime,delta=map(int,f[10:]);parts=line.decode().split('~')
    if len(parts)!=8:raise AssertionError('missing reader/writer snapshots')
    for index,part in enumerate(parts[:-1]):
        status,metadata,input_hex,pending_hex,writer,output_hex,buffered_hex,actual_hex,count=part.split('|')
        m=metadata.split(':');w=writer.split(':')
        if len(m)!=4 or len(w)!=3:raise AssertionError('invalid metadata')
        if m[-2:]!=([ '0','0'] if kind==0 else ['1',str(2 if index==0 or replace==0 else (2 if replace==2 else 3))]):raise AssertionError('reader ownership differs')
        if w[-2:]!=(['0','0'] if wkind==0 else ['1',str(2 if wkind<3 else 3)]):raise AssertionError('writer ownership differs')
        if len(bytes.fromhex(input_hex))!=(len(payload) if kind==0 else rcap) or len(bytes.fromhex(pending_hex))>(len(payload) if kind==0 else rcap):raise AssertionError('reader spans differ')
        if len(bytes.fromhex(output_hex))!=wcap or len(bytes.fromhex(buffered_hex))>wcap or len(bytes.fromhex(actual_hex))>4096:raise AssertionError('writer spans differ')
        if count!='-' and not count.isdecimal():raise AssertionError('invalid saved count')
        if status not in ('ok','skip','ReadFailed','WriteFailed','EndOfStream','StreamTooLong','Unseekable'):raise AssertionError('unexpected status '+status)
    reader_wire,writer_wire=parts[-1].split('/')
    if reader_wire.split(':')[0]!=('skip' if replace==0 else ('0' if replace==2 else '-1')):raise AssertionError('reader drain differs')
    if writer_wire.split(':')[0]!=('skip' if wkind==0 else '-1'):raise AssertionError('writer drain differs')
    if wkind>=5 and writer_wire!='-1:':raise AssertionError('full writer pipe changed')

def classify(native,translated,name,data,category,paths):
    if native.returncode==0:
        if translated.returncode or native.stdout!=translated.stdout or native.stderr or translated.stderr or not native.stdout:raise AssertionError(name+': returning control differs')
        snapshot_checks(native.stdout.strip(),data)
        return ('return',native.stdout)
    for result in (native,translated):
        checked_trap(result,name,category)
        messages=[m.group(1) for line in result.stderr.decode().splitlines() if (m:=re.fullmatch(r'(?:thread \d+ |V )?panic:\s*(.*)',line.strip()))]
        if messages!=[category]:raise AssertionError(name+': panic message differs')
    states=[p.read_bytes() for p in paths]
    if not states[0] or states[0]!=states[1]:raise AssertionError(name+': retained failure state differs')
    state=states[0].decode().split('|');f=data.split('|');capacity=name.startswith('capacity-')
    if len(state)!=9 or state[1].split(':')[-2:]!=['1',str(2 if capacity or f[10]=='2' else 3)] or state[0]!=('calling' if capacity else 'ok'):raise AssertionError(name+': invalid panic observer')
    return ('trap',category.encode()+b'\0'+states[0]+b'\n')

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source',type=Path);parser.add_argument('zig',type=Path);parser.add_argument('v',type=Path)
    parser.add_argument('--target',default='aarch64-macos.14.0');parser.add_argument('--v-prod',action='store_true');parser.add_argument('--workdir',type=Path);parser.add_argument('--timeout',type=int,default=600)
    args=parser.parse_args()
    if args.timeout<=0:parser.error('--timeout must be positive')
    source=args.source.resolve()/'src';zig=args.zig.resolve();v=args.v.resolve()
    if tree_hash(source)!=PINNED_SOURCE_SHA256 or stdlib_hash(zig)!=PINNED_STDLIB_SHA256 or path_library_hashes(zig)!=PATH_LIBRARIES or encoder_library_hashes(zig)!=ENCODER_LIBRARIES:parser.error('Source/compiler library differs from pins')
    repo=Path(__file__).resolve().parent.parent;probe=repo/'zigimg/reference_probes/delimiter_stream';mode='ReleaseSafe' if args.v_prod else 'Debug'
    with work_directory(args.workdir,'witty-delimiter-stream-') as root:
        tmp=root/'tmp';tmp.mkdir();env=dict(os.environ,TMPDIR=str(tmp),VTMP=str(tmp),VEXE=str(v),V_C_ERROR_BUG_REPORT_DISABLED='1')
        proof=ProofLog(root);shutil.copytree(source,root/'src');fixtures={}
        for name in ('main.v','reference.zig','fixture_shims.h','fixture_shims.c'):
            shutil.copyfile(probe/name,root/name);fixtures[name]=hashlib.sha256((root/name).read_bytes()).hexdigest()
        shared_hash={}
        for directory in ('reader_delimiter','reader_exclusive','writer_seek'):
            shared=root/directory;shared.mkdir();shutil.copyfile(repo/'zigimg/reference_probes'/directory/'fixture_shims.h',shared/'fixture_shims.h');shared_hash[directory]=hashlib.sha256((shared/'fixture_shims.h').read_bytes()).hexdigest()
        versions=[proof.run([str(exe),'version'],label,env=env).stdout.decode().strip() for exe,label in ((zig,'zig-version'),(v,'v-version'))]
        if versions[0]!='0.15.2' or not re.match(r'^V 0\.5\.2(?: |$)',versions[1]):raise AssertionError('compiler versions differ')
        impl=implementation_hashes(repo);runner_hash=hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
        helpers={name:hashlib.sha256((repo/'zigimg'/name).read_bytes()).hexdigest() for name in ('verify_jpeg_contracts_reference.py','verify_tiff_decode_reference.py','verify_stream_guards_reference.py','verify_image_open_reference.py','verify_image_tty_reference.py')}
        (root/'provenance.json').write_text(json.dumps(dict(source_sha256=PINNED_SOURCE_SHA256,stdlib_sha256=PINNED_STDLIB_SHA256,path_libraries=PATH_LIBRARIES,encoder_libraries=ENCODER_LIBRARIES,versions=versions,target=args.target,zig_mode=mode,v_prod=args.v_prod,implementation_sha256=impl,runner_sha256=runner_hash,fixtures=fixtures,helper_sha256=helpers,shared_fixture_sha256=shared_hash),indent=2)+'\n')
        print(f'Building delimiter streaming: Source {mode}, V {"production" if args.v_prod else "ordinary"}',flush=True)
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
        returns=hashlib.sha256();states=hashlib.sha256();return_count=0;trap_count=0
        print(f'{len(rows)} returning delimiter stream records match; checking failure controls',flush=True)
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
        summary=dict(returning_records=len(rows),stream_calls=3*len(rows),primary_calls=5*len(rows),returning_groups=dict(Counter(group for group,_ in rows)),output_sha256=digest,return_controls=return_count,control_sha256=returns.hexdigest(),paired_traps=trap_count,state_sha256=states.hexdigest(),zig_mode=mode,v_prod=args.v_prod)
        (root/'summary.json').write_text(json.dumps(summary,indent=2)+'\n');print(json.dumps(summary),flush=True)

if __name__=='__main__':main()
