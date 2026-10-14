"""Compare one-callback fills, zero progress, compaction and retained failure state."""
import argparse
from collections import Counter
import hashlib,itertools,json,os,re,shutil
from pathlib import Path
from verify_jpeg_contracts_reference import implementation_hashes
from verify_tiff_decode_reference import ProofLog,tree_hash,work_directory,PINNED_SOURCE_SHA256,checked_trap
from verify_stream_guards_reference import stdlib_hash,PINNED_STDLIB_SHA256
from verify_image_open_reference import PATH_LIBRARIES,path_library_hashes
from verify_image_tty_reference import ENCODER_LIBRARIES,encoder_library_hashes

EXPECTED_ROWS = 3794
EXPECTED_SHA256 = '12dd485c887eac00bbbd73a11ee017b558af2367e50c35b648cd3adaf0188919'
EXPECTED_CONTROLS = 350
EXPECTED_CONTROL_SHA256 = '98afd96ac4a10bafe0b94155609a1a13f2f468a97fd861f382d5ffe221a625bf'
EXPECTED_TRAPS = 226
EXPECTED_STATE_SHA256 = '9a9e02daa7a6d12f6b289d97b995ee3d75f47f722ca54a7c7e47d585f81bce7e'

def spec(kind=1,warmup=0,cap=8,start=0,consume_mode=1,payload=b'abcdefghi',replacement=0,consumed=0,seed=0,prime=0,delta=0):
    return '|'.join(map(str,(kind,warmup,cap,start,consume_mode)))+'|'+payload.hex()+'|'+'|'.join(map(str,(replacement,consumed,seed,prime,delta)))

def corpus():
    rows=[]
    for length,mode,delta in itertools.product((0,1,7,8,9,31,32,33,64),range(4),(-1,0,1)):
        payload=bytes((i*37+19)&255 for i in range(length))
        for start in sorted({0,1,length//2,length}):rows.append(('memory',spec(0,start=start,consume_mode=mode,payload=payload,delta=delta)))
    for kind,cap,length in itertools.product((1,2),(1,2,8,32),(0,1,7,8,9,31,32,33,64)):
        payload=bytes((i*37+19)&255 for i in range(length))
        for start,mode in itertools.product(sorted({0,1,length//2,length}),(1,2,3)):
            for delta in ((-1,0,1) if mode==1 and cap>1 else (0,1)):
                rows.append(('file',spec(kind,cap=cap,start=start,consume_mode=mode,payload=payload,delta=delta)))
        if length<cap:
            for start in sorted({0,1,length//2,length}):rows.append(('retained-eof',spec(kind,cap=cap,start=start,consume_mode=0,payload=payload)))
    payload=bytes((i*37+19)&255 for i in range(128))
    for cap,start,closed,mode in itertools.product((1,8,32),(0,1,7),(1,2),(1,2,3)):
        for seed,delta in itertools.product(sorted({0,1,cap,cap+1,start+2*cap+1}),(0,1)):
            rows.append(('transition-empty',spec(cap=cap,start=start,consume_mode=mode,payload=payload,replacement=closed,seed=seed,delta=delta)))
        for consumed in sorted({1,max(1,cap//2),cap}):
            for seed,delta in itertools.product(sorted({cap-consumed,start+cap,start+2*cap+1}),(0,1)):
                rows.append(('transition-prefilled',spec(warmup=1,cap=cap,start=start,consume_mode=mode,payload=payload,replacement=closed,consumed=consumed,seed=seed,delta=delta)))
    for kind,cap,start,mode,refill in itertools.product((1,2),(1,8,32),(0,1,7),(1,2,3),(1,8,33)):
        rows.append(('reseed',spec(kind,warmup=2,cap=cap,start=start,consume_mode=mode,payload=payload,replacement=1,consumed=refill)))
    for cap,consumed,closed,prime,mode,delta in itertools.product((8,32),(1,7),(1,2),(1,2),range(4),(-1,0,1)):
        rows.append(('failed-pending' if prime==1 else 'failed-consumed',spec(warmup=1,cap=cap,consume_mode=mode,payload=payload,replacement=closed,consumed=consumed,seed=cap-consumed,prime=prime,delta=delta)))
    return rows

def controls():
    rows=[]
    for kind,payload in itertools.product(range(3),(b'',b'a\nlast')):
        name=f'capacity-{kind}-{len(payload)}';rows.append((name,spec(kind,cap=0,consume_mode=0,payload=payload),'reached unreachable code'))
    payload=bytes((i*37+19)&255 for i in range(128))
    for kind,cap,start in itertools.product((1,2),(1,8,32),(0,1,7)):
        rows.append((f'full-second-{kind}-{cap}-{start}',spec(kind,cap=cap,start=start,consume_mode=0,payload=payload),'reached unreachable code'))
        rows.append((f'full-rewind-{kind}-{cap}-{start}',spec(kind,cap=cap,start=start,consume_mode=2,payload=payload,delta=-1),'reached unreachable code'))
    for cap,start,closed in itertools.product((1,8,32),(0,1,7),(1,2)):
        rows.append((f'full-prefill-{cap}-{start}-{closed}',spec(warmup=1,cap=cap,start=start,consume_mode=0,payload=payload,replacement=closed,seed=cap),'reached unreachable code'))
    for cap,start,consumed,closed,prime,mode in itertools.product((8,32),(0,1,7),(1,7),(1,2),(0,1,2),(0,1)):
        for seed in sorted({0,cap-consumed-1,cap-consumed,cap+start-1}):
            name=f'position-{cap}-{start}-{consumed}-{closed}-{prime}-{mode}-{seed}'
            rows.append((name,spec(warmup=1,cap=cap,start=start,consume_mode=mode,payload=payload,replacement=closed,consumed=consumed,seed=seed,prime=prime),'integer overflow'))
    if len({name for name,_,_ in rows})!=len(rows) or len({data for _,data,_ in rows})!=len(rows):raise AssertionError('duplicate control label/input')
    return rows

def snapshot_checks(line,data):
    f=data.split('|');kind,warmup,cap,start,mode=map(int,f[:5]);payload=bytes.fromhex(f[5]);replacement,consumed,seed,prime,delta=map(int,f[6:]);parts=line.decode().split('~')
    if len(parts)!=10:raise AssertionError('missing one-callback snapshots')
    for index,part in enumerate(parts[:-1]):
        status,metadata,buffer,output,pending=part.split('|');m=metadata.split(':')
        if len(m)!=4 or m[-2:]!=(['0','0'] if kind==0 else ['1',str(2 if index==0 or replacement==0 else (2 if replacement==2 else 3))]):raise AssertionError('reader ownership differs')
        maximum=len(payload) if kind==0 else cap
        if len(bytes.fromhex(buffer))!=maximum or len(bytes.fromhex(output))>maximum or len(bytes.fromhex(pending))>maximum:raise AssertionError('initialized reader spans differ')
        if status not in ('ok','skip','EndOfStream','ReadFailed','Unseekable'):
            if not status.startswith('consumed-') or not status[9:].isdecimal():raise AssertionError('unexpected fill status '+status)
    for call,after in ((2,3),(5,6),(7,8)):
        before=parts[call].split('|');later=parts[after].split('|');pending=bytes.fromhex(before[4]);n=int(later[0][9:])
        expected=(len(pending) if mode==1 else (min(1,len(pending)) if mode==2 else ((len(pending)+1)//2 if mode==3 else 0)))
        if n!=expected or bytes.fromhex(later[4])!=pending[n:] or later[2:4]!=before[2:4] or int(later[1].split(':')[0])!=int(before[1].split(':')[0])+n:raise AssertionError('caller consumption differs')
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
    if len(fields)!=5 or fields[1].split(':')[-2:]!=['1',str(2 if f[6] in ('0','2') else 3)]:raise AssertionError(name+': invalid panic observer')
    expected='calling' if category=='reached unreachable code' else ('ReadFailed' if f[9]=='0' else 'ok')
    if fields[0]!=expected:raise AssertionError(name+': unexpected failure order')
    return ('trap',category.encode()+b'\0'+states[0]+b'\n')

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source',type=Path);parser.add_argument('zig',type=Path);parser.add_argument('v',type=Path)
    parser.add_argument('--target',default='aarch64-macos.14.0');parser.add_argument('--v-prod',action='store_true');parser.add_argument('--workdir',type=Path);parser.add_argument('--timeout',type=int,default=600)
    args=parser.parse_args()
    if args.timeout<=0:parser.error('--timeout must be positive')
    source=args.source.resolve()/'src';zig=args.zig.resolve();v=args.v.resolve()
    if tree_hash(source)!=PINNED_SOURCE_SHA256 or stdlib_hash(zig)!=PINNED_STDLIB_SHA256 or path_library_hashes(zig)!=PATH_LIBRARIES or encoder_library_hashes(zig)!=ENCODER_LIBRARIES:parser.error('Source/compiler library differs from pins')
    repo=Path(__file__).resolve().parent.parent;probe=repo/'zigimg/reference_probes/reader_fill_more';mode='ReleaseSafe' if args.v_prod else 'Debug'
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
        print(f'Building one-callback fills: Source {mode}, V {"production" if args.v_prod else "ordinary"}',flush=True)
        proof.run([str(zig),'build-exe','-target',args.target,'-lc','-I',str(root),'-O',mode,'--global-cache-dir',str(root.parent/'zig-global'),'--cache-dir',str(root/'zig-cache'),'-femit-bin='+str(root/'native'),str(root/'reference.zig'),str(root/'fixture_shims.c')],'build-source',env=env,timeout=args.timeout)
        proof.run([str(v),'-enable-globals',*(['-prod'] if args.v_prod else []),'-path',f'{repo}|@vlib|@vmodules','-o',str(root/'translated'),str(root/'main.v')],'build-v',env=env,timeout=args.timeout)
        rows=corpus();path=root/'corpus.txt';path.write_text('\n'.join(data for _,data in rows)+'\n');inputs={'corpus.txt':hashlib.sha256(path.read_bytes()).hexdigest()};(root/'input_sha256.json').write_text(json.dumps(inputs,indent=2)+'\n')
        outputs=[]
        for exe in ('native','translated'):
            result=proof.run([str(root/exe),str(path)],'returning-'+exe,env=env,timeout=args.timeout)
            if result.stderr or len(result.stdout.splitlines())!=len(rows):raise AssertionError('invalid returning output')
            outputs.append(result.stdout.splitlines())
        for i,((group,data),native,translated) in enumerate(zip(rows,*outputs)):
            if native!=translated:raise AssertionError(f'{i}/{group}: one-callback reader record differs; see retained proof')
            snapshot_checks(native,data)
        digest=hashlib.sha256(b'\n'.join(outputs[0])).hexdigest()
        if EXPECTED_ROWS is not None and (len(rows)!=EXPECTED_ROWS or digest!=EXPECTED_SHA256):raise AssertionError('returning golden changed')
        returns=hashlib.sha256();states=hashlib.sha256();return_count=0;trap_count=0
        print(f'{len(rows)} returning one-callback fill records match; checking failure controls',flush=True)
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
        summary=dict(returning_records=len(rows),fill_calls=3*len(rows),primary_calls=7*len(rows),returning_groups=dict(Counter(group for group,_ in rows)),output_sha256=digest,return_controls=return_count,control_sha256=returns.hexdigest(),paired_traps=trap_count,state_sha256=states.hexdigest(),zig_mode=mode,v_prod=args.v_prod)
        (root/'summary.json').write_text(json.dumps(summary,indent=2)+'\n');print(json.dumps(summary),flush=True)

if __name__=='__main__':main()
