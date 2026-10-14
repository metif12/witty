"""Compare integer peeks, variable-width reads and retained failure state."""
import argparse
from collections import Counter
import hashlib,itertools,json,os,re,shutil
from pathlib import Path
from verify_jpeg_contracts_reference import implementation_hashes
from verify_tiff_decode_reference import ProofLog,tree_hash,work_directory,PINNED_SOURCE_SHA256,checked_trap
from verify_stream_guards_reference import stdlib_hash,PINNED_STDLIB_SHA256
from verify_image_open_reference import PATH_LIBRARIES,path_library_hashes
from verify_image_tty_reference import ENCODER_LIBRARIES,encoder_library_hashes

EXPECTED_ROWS = 56640
EXPECTED_SHA256 = '8f95f7708e71ef902ecec73fdc067b10c5ee3625c7a0f6fa25d9931562420a77'
EXPECTED_CONTROLS = 808
EXPECTED_CONTROL_SHA256 = 'cfc8891571a3cd8a28c666dbd923f1db147a0292954ea8db3833de27400eba76'
EXPECTED_TRAPS = 1048
EXPECTED_STATE_SHA256 = 'fd6261efd9ad3994720c9317ac6d0cc7f301f3bee64c0154e161108f7d1f2ac5'

WIDTHS=(1,2,4,8,1,2,4,8,8,8)
def spec(kind=1,warmup=0,cap=8,start=0,consume_mode=0,payload=b'abcdefghi',replacement=0,consumed=0,seed=0,prime=0,delta=0,op=0,tag=0,order=0,count=0):
    return '|'.join(map(str,(kind,warmup,cap,start,consume_mode)))+'|'+payload.hex()+'|'+'|'.join(map(str,(replacement,consumed,seed,prime,delta,op,tag,order,count)))
def operations(tag):
    width=WIDTHS[tag%10]
    return [(0,width)]+[(1,n) for n in range(width+1)]
def corpus():
    rows=[]
    for tag,order,kind,length in itertools.product(range(20),range(4),range(3),(0,1,7,8,9,17)):
        payload=bytes((i*37+19)&255 for i in range(length))
        for start,(op,count) in itertools.product(sorted({0,1,length}),operations(tag)):
            rows.append(('basic',spec(kind,cap=8,start=start,payload=payload,op=op,tag=tag,order=order,count=count)))
    for byte,tag,order,kind,op in itertools.product(range(256),(0,4,10,14),range(2),range(3),range(2)):
        rows.append(('every-byte',spec(kind,cap=8,payload=bytes([byte,byte,byte]),op=op,tag=tag,order=order,count=1)))
    payload=bytes((i*37+19)&255 for i in range(128))
    for tag,order,cap,start,consumed,closed,prime in itertools.product((0,3,4,7,11,17),range(2),(8,32),(0,1),(1,7),(1,2),range(3)):
        width=WIDTHS[tag%10]
        for seed,(op,count),delta in itertools.product(sorted({cap-consumed,cap+start,cap+start+width+1}),[(0,width)]+[(1,n) for n in sorted({0,1,width})],(-1,0,1)):
            rows.append(('prefilled',spec(warmup=1,cap=cap,start=start,payload=payload,replacement=closed,consumed=consumed,seed=seed,prime=prime,delta=delta,op=op,tag=tag,order=order,count=count)))
    if len({data for _,data in rows})!=len(rows):raise AssertionError('duplicate returning input')
    return rows

def controls():
    rows=[];payload=bytes((i*37+19)&255 for i in range(128))
    for tag,order,kind in itertools.product(range(20),range(2),range(3)):
        width=WIDTHS[tag%10]
        for cap,(op,count) in itertools.product(sorted({0,width-1}),[(0,width),(1,0),(1,width),(1,width+1)]):
            name=f'capacity-{tag}-{order}-{kind}-{cap}-{op}-{count}'
            rows.append((name,spec(kind,cap=cap,payload=payload,op=op,tag=tag,order=order,count=count),'reached unreachable code'))
    for tag,order,cap,consumed,op in itertools.product((3,7,13,17),range(2),(1,2,4),(0,1),range(2)):
        name=f'pending-{tag}-{order}-{cap}-{consumed}-{op}'
        rows.append((name,spec(warmup=1,cap=cap,start=1,payload=payload,replacement=2,consumed=consumed,op=op,tag=tag,order=order,count=8),'reached unreachable code'))
    for tag,order,cap,start,consumed,closed,op in itertools.product((0,3,4,7),range(2),(8,32),(0,1),(1,7),(1,2),range(2)):
        for seed in sorted({0,cap-consumed-1,cap-consumed,cap+start-1}):
            name=f'position-{tag}-{order}-{cap}-{start}-{consumed}-{closed}-{op}-{seed}'
            rows.append((name,spec(warmup=1,cap=cap,start=start,payload=payload,replacement=closed,consumed=consumed,seed=seed,prime=1,op=op,tag=tag,order=order,count=WIDTHS[tag%10]),'integer overflow'))
    if len({name for name,_,_ in rows})!=len(rows) or len({data for _,data,_ in rows})!=len(rows):raise AssertionError('duplicate control label/input')
    return rows

def snapshot_checks(line,data):
    f=data.split('|');kind,warmup,cap,start,mode=map(int,f[:5]);payload=bytes.fromhex(f[5]);replacement,consumed,seed,prime,delta,op,tag,order,count=map(int,f[6:]);parts=line.decode().split('~');width=WIDTHS[tag%10]
    if len(parts)!=10:raise AssertionError('missing integer snapshots')
    for index,part in enumerate(parts[:-1]):
        status,metadata,buffer,output,pending=part.split('|');m=metadata.split(':')
        if len(m)!=4 or m[-2:]!=(['0','0'] if kind==0 else ['1',str(2 if index==0 or replacement==0 else (2 if replacement==2 else 3))]):raise AssertionError('reader ownership differs')
        maximum=len(payload) if kind==0 else cap
        if len(bytes.fromhex(buffer))!=maximum or len(bytes.fromhex(pending))>maximum:raise AssertionError('initialized reader spans differ')
        if output:
            value,bits=map(int,output.split(':'));signed=tag%10 in (4,5,6,7,9);expected=bits-(1<<(width*8)) if signed and bits&(1<<(width*8-1)) else bits
            if bits<0 or bits>=1<<(width*8) or value!=expected:raise AssertionError('integer value and representation differ')
        if status not in ('ok','skip','EndOfStream','ReadFailed','Unseekable'):
            if not status.startswith('consumed-') or not status[9:].isdecimal():raise AssertionError('unexpected integer status '+status)
    for call,after in ((2,3),(5,6),(7,8)):
        before=parts[call].split('|');later=parts[after].split('|');pending=bytes.fromhex(before[4]);n=int(later[0][9:])
        expected=(len(pending) if mode==1 else (min(1,len(pending)) if mode==2 else ((len(pending)+1)//2 if mode==3 else 0)))
        if n!=expected or bytes.fromhex(later[4])!=pending[n:] or later[2:4]!=before[2:4] or int(later[1].split(':')[0])!=int(before[1].split(':')[0])+n:raise AssertionError('caller consumption differs')
        if before[0]=='ok':
            if not before[3]:raise AssertionError('missing successful integer')
            if op==0:
                expected_bits=int.from_bytes(pending[:width],'big' if order%2==0 else 'little')
                if len(pending)<width or int(before[3].split(':')[1])!=expected_bits:raise AssertionError('peek disagrees with pending bytes')
            elif count==0 and before[3]!='0:0':raise AssertionError('zero-width read differs')
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
    expected='calling' if category=='reached unreachable code' else 'ok'
    if fields[0]!=expected:raise AssertionError(name+': unexpected failure order')
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
    repo=Path(__file__).resolve().parent.parent;probe=repo/'zigimg/reference_probes/reader_integer';mode='ReleaseSafe' if args.v_prod else 'Debug'
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
        print(f'Building integer peeks and variable-width reads: Source {mode}, V {"production" if args.v_prod else "ordinary"}',flush=True)
        proof.run([str(zig),'build-exe','-target',args.target,'-lc','-I',str(root),'-O',mode,'--global-cache-dir',str(root.parent/'zig-global'),'--cache-dir',str(root/'zig-cache'),'-femit-bin='+str(root/'native'),str(root/'reference.zig'),str(root/'fixture_shims.c')],'build-source',env=env,timeout=args.timeout)
        proof.run([str(v),'-enable-globals',*(['-prod'] if args.v_prod else []),'-path',f'{repo}|@vlib|@vmodules','-o',str(root/'translated'),str(root/'main.v')],'build-v',env=env,timeout=args.timeout)
        rows=corpus();path=root/'corpus.txt';path.write_text('\n'.join(data for _,data in rows)+'\n');inputs={'corpus.txt':hashlib.sha256(path.read_bytes()).hexdigest()};(root/'input_sha256.json').write_text(json.dumps(inputs,indent=2)+'\n')
        outputs=[]
        for exe in ('native','translated'):
            result=proof.run([str(root/exe),str(path)],'returning-'+exe,env=env,timeout=args.timeout)
            if result.stderr or len(result.stdout.splitlines())!=len(rows):raise AssertionError('invalid returning output')
            outputs.append(result.stdout.splitlines())
        for i,((group,data),native,translated) in enumerate(zip(rows,*outputs)):
            if native!=translated:raise AssertionError(f'{i}/{group}: integer reader record differs; see retained proof')
            snapshot_checks(native,data)
        digest=hashlib.sha256(b'\n'.join(outputs[0])).hexdigest()
        if EXPECTED_ROWS is not None and (len(rows)!=EXPECTED_ROWS or digest!=EXPECTED_SHA256):raise AssertionError('returning golden changed')
        returns=hashlib.sha256();states=hashlib.sha256();return_count=0;trap_count=0
        print(f'{len(rows)} returning integer read records match; checking failure controls',flush=True)
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
        summary=dict(returning_records=len(rows),integer_calls=3*len(rows),primary_calls=7*len(rows),returning_groups=dict(Counter(group for group,_ in rows)),output_sha256=digest,return_controls=return_count,control_sha256=returns.hexdigest(),paired_traps=trap_count,state_sha256=states.hexdigest(),zig_mode=mode,v_prod=args.v_prod)
        (root/'summary.json').write_text(json.dumps(summary,indent=2)+'\n');print(json.dumps(summary),flush=True)

if __name__=='__main__':main()
