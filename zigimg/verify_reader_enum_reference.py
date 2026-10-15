"""Compare checked enum reads, unnamed tags, and retained failure state."""
import argparse
from collections import Counter
import hashlib,itertools,json,os,re,shutil
from pathlib import Path
from verify_jpeg_contracts_reference import implementation_hashes
from verify_tiff_decode_reference import ProofLog,tree_hash,work_directory,PINNED_SOURCE_SHA256,checked_trap
from verify_stream_guards_reference import stdlib_hash,PINNED_STDLIB_SHA256
from verify_image_open_reference import PATH_LIBRARIES,path_library_hashes
from verify_image_tty_reference import ENCODER_LIBRARIES,encoder_library_hashes

ENUM_LIBRARIES = {'meta.zig': '3cf9b3eb6c6b6f9b101f06f0562a4071c81a5fbc6de63d8197e837e10cedfc40', 'enums.zig': 'd6da51cbd1e4ef79570318b0ba1cc1a2127c8afe7b96f91dbba94c9dfe2498bc'}

def enum_library_hashes(zig):
    return {name:hashlib.sha256((zig.parent/"lib/std"/name).read_bytes()).hexdigest() for name in ENUM_LIBRARIES}


EXPECTED_ROWS = 33504
EXPECTED_SHA256 = 'afa3ea7a87cb13544863b2957f1c31b1af7d211b98704b7845e1451a359be955'
EXPECTED_CONTROLS = 160
EXPECTED_CONTROL_SHA256 = '483ff19b2f300d286be8c7310b561a4f7ca1b1f285422957d7687ce7fc7c4f3d'
EXPECTED_TRAPS = 192
EXPECTED_STATE_SHA256 = '3cef7fe799e64aa751e283552ed5f446b810246a17241986874cfeb59e330c7f'

WIDTHS=(1,2,4,8,1,2,4,8)*4+(1,1,1,1)
def signed(tag):return tag<32 and tag%8>=4
def opened(tag):return tag>=32 or tag%16>=8
def values(tag):
    bits=8*WIDTHS[tag];mask=(1<<bits)-1
    return {1<<(bits-1),(-3)&mask,0,(1<<(bits-1))-2} if signed(tag) else {0,2,(1<<(bits-1))+3,mask}
def spec(kind=1,warmup=0,cap=8,start=0,consume_mode=0,payload=b'abcdefghi',replacement=0,consumed=0,seed=0,prime=0,delta=0,tag=0,order=0):
    return '|'.join(map(str,(kind,warmup,cap,start,consume_mode)))+'|'+payload.hex()+'|'+'|'.join(map(str,(replacement,consumed,seed,prime,delta,0,tag,order,0)))
def corpus():
    rows=[]
    for tag,order,kind in itertools.product(range(36),range(4),range(3)):
        width=WIDTHS[tag]
        for length in sorted({0,1,width-1,width,3*width+1}):
            payload=bytes((i*37+19)&255 for i in range(length))
            for start,mode in itertools.product(sorted({0,1,length}),(0,3)):
                rows.append(('basic',spec(kind,cap=8,start=start,consume_mode=mode,payload=payload,tag=tag,order=order)))
        bits=width*8;mask=(1<<bits)-1
        for value in sorted(values(tag)|{1,2,3,mask,mask-1,(1<<(bits-1))-1}):
            payload=value.to_bytes(width,'big' if order%2==0 else 'little')*3+b'\x01'
            rows.append(('tag-boundaries',spec(kind,cap=8,payload=payload,tag=tag,order=order)))
    for byte,tag,order,kind in itertools.product(range(256),(0,4,8,12,16,20,24,28,32,33,34,35),range(2),range(3)):
        rows.append(('every-byte',spec(kind,cap=8,payload=bytes([byte])*3,tag=tag,order=order)))
    payload=bytes((i*37+19)&255 for i in range(128))
    for tag,order,cap,start,consumed,closed,prime in itertools.product((0,3,4,7,8,11,12,15,16,24,32,35),range(2),(8,32),(0,1),(1,7),(1,2),range(3)):
        width=WIDTHS[tag]
        for seed in sorted({cap-consumed,cap+start+width+1}):
            rows.append(('replacement',spec(warmup=1,cap=cap,start=start,payload=payload,replacement=closed,consumed=consumed,seed=seed,prime=prime,tag=tag,order=order)))
    if len({data for _,data in rows})!=len(rows):raise AssertionError('duplicate returning input')
    return rows

def controls():
    rows=[];payload=bytes((i*37+19)&255 for i in range(128))
    for tag,order,kind in itertools.product((0,3,4,7,8,11,12,15,16,24,32,35),range(2),range(3)):
        for cap in sorted({0,WIDTHS[tag]-1}):
            rows.append((f'capacity-{tag}-{order}-{kind}-{cap}',spec(kind,cap=cap,payload=payload,tag=tag,order=order),'reached unreachable code'))
    for tag,order,cap,consumed,closed,prime in itertools.product((0,3,4,7,8,15,32,35),range(2),(8,32),(1,7),(1,2),(1,2)):
        seed=cap-consumed-1
        rows.append((f'position-{tag}-{order}-{cap}-{consumed}-{closed}-{prime}',spec(warmup=1,cap=cap,start=1,payload=payload,replacement=closed,consumed=consumed,seed=seed,prime=prime,tag=tag,order=order),'integer overflow'))
    if len({name for name,_,_ in rows})!=len(rows) or len({data for _,data,_ in rows})!=len(rows):raise AssertionError('duplicate control label/input')
    return rows

def snapshot_checks(line,data):
    f=data.split('|');kind,warmup,cap,start,mode=map(int,f[:5]);payload=bytes.fromhex(f[5]);replacement,consumed,seed,prime,delta,op,tag,order,count=map(int,f[6:]);parts=line.decode().split('~');width=WIDTHS[tag]
    if len(parts)!=10:raise AssertionError('missing enum snapshots')
    for index,part in enumerate(parts[:-1]):
        status,metadata,buffer,output,pending=part.split('|');m=metadata.split(':')
        if len(m)!=4 or m[-2:]!=(['0','0'] if kind==0 else ['1',str(2 if index==0 or replacement==0 else (2 if replacement==2 else 3))]):raise AssertionError('reader ownership differs')
        maximum=len(payload) if kind==0 else cap
        if len(bytes.fromhex(buffer))!=maximum or len(bytes.fromhex(pending))>maximum:raise AssertionError('initialized reader spans differ')
        if output:
            value,bits=map(int,output.split(':'));expected=bits-(1<<(width*8)) if signed(tag) and bits&(1<<(width*8-1)) else bits
            if bits<0 or bits>=1<<(width*8) or value!=expected or (not opened(tag) and bits not in values(tag)):raise AssertionError('enum value/tag representation differs')
        if status not in ('ok','skip','EndOfStream','ReadFailed','Unseekable','InvalidEnumTag'):
            if not status.startswith('consumed-') or not status[9:].isdecimal():raise AssertionError('unexpected enum status '+status)
        if status=='InvalidEnumTag' and opened(tag):raise AssertionError('nonexhaustive tag rejected')
    for before,call in ((1,2),(4,5),(6,7)):
        a=parts[before].split('|');b=parts[call].split('|');pending=bytes.fromhex(a[4]);position=int(a[1].split(':')[0])
        if b[0]!='ok' and b[3]!=a[3]:raise AssertionError('failed enum read changed retained output')
        source=pending if len(pending)>=width else (payload[position:] if replacement==0 else None)
        if source is None:continue
        if len(source)<width:
            if b[0]!='EndOfStream' or int(b[1].split(':')[0])!=position or bytes.fromhex(b[4])!=source:raise AssertionError('incomplete enum tag consumed bytes')
            continue
        bits=int.from_bytes(source[:width],'big' if order%2==0 else 'little');valid=opened(tag) or bits in values(tag)
        if b[0]!=('ok' if valid else 'InvalidEnumTag') or int(b[1].split(':')[0])!=position+width:raise AssertionError('tag validation/consumption order differs')
        if valid and (not b[3] or int(b[3].split(':')[1])!=bits):raise AssertionError('successful enum disagrees with input tag')
        if len(pending)>=width and bytes.fromhex(b[4])!=pending[width:]:raise AssertionError('buffered enum read consumed wrong span')
    for call,after in ((2,3),(5,6),(7,8)):
        before=parts[call].split('|');later=parts[after].split('|');pending=bytes.fromhex(before[4]);n=int(later[0][9:]);expected=(len(pending) if mode==1 else ((len(pending)+1)//2 if mode==3 else 0))
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
    if tree_hash(source)!=PINNED_SOURCE_SHA256 or stdlib_hash(zig)!=PINNED_STDLIB_SHA256 or path_library_hashes(zig)!=PATH_LIBRARIES or encoder_library_hashes(zig)!=ENCODER_LIBRARIES or enum_library_hashes(zig)!=ENUM_LIBRARIES:parser.error('Source/compiler library differs from pins')
    repo=Path(__file__).resolve().parent.parent;probe=repo/'zigimg/reference_probes/reader_enum';mode='ReleaseSafe' if args.v_prod else 'Debug'
    with work_directory(args.workdir,'witty-reader-enum-') as root:
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
        (root/'provenance.json').write_text(json.dumps(dict(source_sha256=PINNED_SOURCE_SHA256,stdlib_sha256=PINNED_STDLIB_SHA256,path_libraries=PATH_LIBRARIES,encoder_libraries=ENCODER_LIBRARIES,enum_libraries=ENUM_LIBRARIES,versions=versions,target=args.target,zig_mode=mode,v_prod=args.v_prod,implementation_sha256=impl,runner_sha256=runner_hash,fixtures=fixtures,helper_sha256=helpers,shared_fixture_sha256=shared_hash),indent=2)+'\n')
        print(f'Building checked enum reads: Source {mode}, V {"production" if args.v_prod else "ordinary"}',flush=True)
        proof.run([str(zig),'build-exe','-target',args.target,'-lc','-I',str(root),'-O',mode,'--global-cache-dir',str(root.parent/'zig-global'),'--cache-dir',str(root/'zig-cache'),'-femit-bin='+str(root/'native'),str(root/'reference.zig'),str(root/'fixture_shims.c')],'build-source',env=env,timeout=args.timeout)
        proof.run([str(v),'-enable-globals',*(['-prod'] if args.v_prod else []),'-path',f'{repo}|@vlib|@vmodules','-o',str(root/'translated'),str(root/'main.v')],'build-v',env=env,timeout=args.timeout)
        rows=corpus();path=root/'corpus.txt';path.write_text('\n'.join(data for _,data in rows)+'\n');inputs={'corpus.txt':hashlib.sha256(path.read_bytes()).hexdigest()};(root/'input_sha256.json').write_text(json.dumps(inputs,indent=2)+'\n')
        outputs=[]
        for exe in ('native','translated'):
            result=proof.run([str(root/exe),str(path)],'returning-'+exe,env=env,timeout=args.timeout)
            if result.stderr or len(result.stdout.splitlines())!=len(rows):raise AssertionError('invalid returning output')
            outputs.append(result.stdout.splitlines())
        for i,((group,data),native,translated) in enumerate(zip(rows,*outputs)):
            if native!=translated:raise AssertionError(f'{i}/{group}: enum reader record differs; see retained proof')
            snapshot_checks(native,data)
        digest=hashlib.sha256(b'\n'.join(outputs[0])).hexdigest()
        if EXPECTED_ROWS is not None and (len(rows)!=EXPECTED_ROWS or digest!=EXPECTED_SHA256):raise AssertionError('returning golden changed')
        returns=hashlib.sha256();states=hashlib.sha256();return_count=0;trap_count=0
        print(f'{len(rows)} returning enum read records match; checking failure controls',flush=True)
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
        if tree_hash(source)!=PINNED_SOURCE_SHA256 or tree_hash(root/'src')!=PINNED_SOURCE_SHA256 or stdlib_hash(zig)!=PINNED_STDLIB_SHA256 or path_library_hashes(zig)!=PATH_LIBRARIES or encoder_library_hashes(zig)!=ENCODER_LIBRARIES or enum_library_hashes(zig)!=ENUM_LIBRARIES or implementation_hashes(repo)!=impl or hashlib.sha256(Path(__file__).read_bytes()).hexdigest()!=runner_hash:raise AssertionError('dependency/implementation/runner changed')
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
