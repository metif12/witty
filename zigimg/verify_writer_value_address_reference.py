"""Compare pointer-address value dispatch and ignored options and exact failure state."""
import argparse
from collections import Counter
import hashlib,itertools,json,os,re,shutil
from pathlib import Path
import verify_writer_address_reference as address
from verify_jpeg_contracts_reference import implementation_hashes
from verify_tiff_decode_reference import ProofLog,tree_hash,work_directory,PINNED_SOURCE_SHA256,checked_trap
from verify_stream_guards_reference import stdlib_hash,PINNED_STDLIB_SHA256
from verify_image_open_reference import PATH_LIBRARIES,path_library_hashes
from verify_image_tty_reference import ENCODER_LIBRARIES,encoder_library_hashes





EXPECTED_ROWS = 39484
EXPECTED_SHA256 = '1ce2999c904df36a3c8b2f2b8fa7160e2fa6d0427abe4db5691d811d1e6566bc'
EXPECTED_CONTROLS = 3234
EXPECTED_CONTROL_SHA256 = '04a44532abf84d9a8d63fa9e596ae1fd1b112f4f3092c28848f840fc0cf768a2'
EXPECTED_TRAPS = 0
EXPECTED_STATE_SHA256 = 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'
IO_LIBRARY_SHA256='09df1114cba703f824337f20489c7df5294db9f07961d4ac46abbbbf9c7ecaef'
def io_library_hash(zig):return hashlib.sha256((zig.parent/'lib/std/Io.zig').read_bytes()).hexdigest()
FORMAT_LIBRARY_SHA256='667eac6285e472b5516ebebf8a6e69959a171be4fb97cac1e56419ffec20d500'
def format_library_hash(zig):return hashlib.sha256((zig.parent/'lib/std/fmt.zig').read_bytes()).hexdigest()
INTEGER_LIBRARIES={'math.zig':'65645001357d5f78cbf646485e009a048b828680bb1b47fb3de0fd8617d91af1','meta.zig':'3cf9b3eb6c6b6f9b101f06f0562a4071c81a5fbc6de63d8197e837e10cedfc40'}
def integer_library_hashes(zig):return {n:hashlib.sha256((zig.parent/'lib/std'/n).read_bytes()).hexdigest() for n in INTEGER_LIBRARIES}
TIME_LIBRARY_SHA256='b8b686d5ecaa81cb25b3234229a85cf0ff99c5bd6153283b272fe586c558d7f1'
def time_library_hash(zig):return hashlib.sha256((zig.parent/'lib/std/time.zig').read_bytes()).hexdigest()
MAX_USIZE=(1<<64)-1
OPS=(0,1,2,3,4,5,8)
TYPE_NAMES=('u8','u16','u32','u64','usize','i8','i16','i32','i64','isize','f32','f64','bool')

ModelLimit=address.ModelLimit

def spec(kind=0,cap=8,start=0,prefix=0,binding=0,finish=1,api=0,mask=91,value=0,tag=0,length=0,alignment=0,width=0,present=0,precision=None,depth=0):
 return address.spec(kind,cap,start,prefix,binding,finish,api,mask,value,tag,length)+'|'+ '|'.join(map(str,(alignment,width,present,'-' if precision is None else precision,depth)))

def fields(part):
 status,metadata,buffer,pending,unused,inputs,contents=part.split('|');m=list(map(int,metadata.split(':')));assert len(m)==6
 payload,headers,options=inputs.split('#');spans=tuple(tuple(map(int,h.split(','))) for h in headers.split(';')) if headers else ()
 opts=tuple(None if v=='-' else int(v) for v in options.split(':'));assert len(opts)==8
 return status,m,bytes.fromhex(buffer),bytes.fromhex(pending),bytes.fromhex(unused),(bytes.fromhex(payload),spans,opts),bytes.fromhex(contents)

def modeled(data):
 f=data.split('|');api,fill,raw,tag,length,alignment,width,present=map(int,f[6:14]);precision=None if f[14]=='-' else int(f[14]);depth=int(f[15])
 states,trap,wire=address.modeled('|'.join(f[:11]))
 def mapped(state):
  result=list(state);payload,spans,_=result[5];result[5]=(payload,spans,(precision,width if present else None,alignment,fill,api,tag,length,depth));return tuple(result)
 return [mapped(state) for state in states],None if trap is None else (trap[0],trap[1],mapped(trap[2])),wire

def remap(data,index):
 return data+'|'+ '|'.join(map(str,(index%3,(0,MAX_USIZE)[index%2],index%2,(None,0,MAX_USIZE)[index%3],(0,1,MAX_USIZE)[index%3]))).replace('None','-')

def candidates():
 rows=[(group,remap(data,i)) for i,(group,data) in enumerate(address.candidates())]
 for api,tag in itertools.product(OPS,(0,7,12)):
  if api==8 and tag:continue
  for cap,(present,width),precision,alignment,fill,depth in itertools.product((0,8,24),((0,0),(1,0),(1,MAX_USIZE)),(None,0,MAX_USIZE),range(3),(0,255),(0,1,MAX_USIZE)):
   rows.append(('ignored-options-and-depth',spec(api=api,tag=tag,value=0x1234,kind=alignment,cap=cap,present=present,width=width,precision=precision,alignment=alignment,mask=fill,depth=depth,length=3 if api in (2,5) else 0)))
 return rows

def corpus():
 seen=set();result=[]
 for group,data in candidates():
  if data in seen:continue
  seen.add(data);assert modeled(data)[1] is None;result.append((group,data))
 return result

def controls():
 return [(name,remap(data,i),category) for i,(name,data,category) in enumerate(address.controls())]

def snapshot_checks(line,data):
 parts=line.decode().split('~');assert len(parts)==6
 states=[fields(part) for part in parts[:-1]];model,trap,wire=modeled(data);assert trap is None and states==model,'independent pointer-address value dispatch/write boundaries/argument state state differs'
 f=list(map(int,data.split('|')[:11]));assert parts[-1]==('-1:'+wire.hex() if f[0] and f[4]==1 else '-3:')

def classify(native,translated,name,data,category,paths):
 if native.returncode==0:
  assert category is None and translated.returncode==0 and native.stdout==translated.stdout and native.stdout and not native.stderr+translated.stderr
  snapshot_checks(native.stdout.strip(),data);return 'return',native.stdout
 for result in (native,translated):
  checked_trap(result,name,category)
  messages=[m.group(1) for line in result.stderr.decode().splitlines() if (m:=re.fullmatch(r'(?:thread \d+ |V )?panic:\s*(.*)',line.strip()))];assert messages==[category]
 states=[p.read_bytes() for p in paths];assert states[0] and states[0]==states[1]
 _,trap,_=modeled(data);assert trap is not None and trap[1]==category and fields(states[0].decode())==trap[2],'pointer-address value dispatch failure state differs'
 return 'trap',category.encode()+b'\0'+states[0]+b'\n'

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source',type=Path);parser.add_argument('zig',type=Path);parser.add_argument('v',type=Path)
    parser.add_argument('--target',default='aarch64-macos.14.0');parser.add_argument('--v-prod',action='store_true');parser.add_argument('--workdir',type=Path);parser.add_argument('--timeout',type=int,default=600)
    args=parser.parse_args()
    if args.timeout<=0:parser.error('--timeout must be positive')
    source=args.source.resolve()/'src';zig=args.zig.resolve();v=args.v.resolve()
    if tree_hash(source)!=PINNED_SOURCE_SHA256 or time_library_hash(zig)!=TIME_LIBRARY_SHA256 or integer_library_hashes(zig)!=INTEGER_LIBRARIES or format_library_hash(zig)!=FORMAT_LIBRARY_SHA256 or io_library_hash(zig)!=IO_LIBRARY_SHA256 or stdlib_hash(zig)!=PINNED_STDLIB_SHA256 or path_library_hashes(zig)!=PATH_LIBRARIES or encoder_library_hashes(zig)!=ENCODER_LIBRARIES:parser.error('Source/compiler library differs from pins')
    repo=Path(__file__).resolve().parent.parent;probe=repo/'zigimg/reference_probes/writer_value_address';mode='ReleaseSafe' if args.v_prod else 'Debug'
    with work_directory(args.workdir,'witty-writer-value-address-') as root:
        tmp=root/'tmp';tmp.mkdir();env=dict(os.environ,TMPDIR=str(tmp),VTMP=str(tmp),VEXE=str(v),V_C_ERROR_BUG_REPORT_DISABLED='1')
        proof=ProofLog(root);shutil.copytree(source,root/'src');fixtures={}
        for name in ('main.v','reference.zig','fixture_shims.h','fixture_shims.c'):
            shutil.copyfile(probe/name,root/name);fixtures[name]=hashlib.sha256((root/name).read_bytes()).hexdigest()
        shared_hash={}
        for directory in ('writer_seek',):
            shared=root/directory;shared.mkdir();shutil.copyfile(repo/'zigimg/reference_probes'/directory/'fixture_shims.h',shared/'fixture_shims.h');shared_hash[directory]=hashlib.sha256((shared/'fixture_shims.h').read_bytes()).hexdigest()
        versions=[proof.run([str(exe),'version'],label,env=env).stdout.decode().strip() for exe,label in ((zig,'zig-version'),(v,'v-version'))]
        if versions[0]!='0.15.2' or not re.match(r'^V 0\.5\.2(?: |$)',versions[1]):raise AssertionError('compiler versions differ')
        impl=implementation_hashes(repo);runner_hash=hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
        helpers={name:hashlib.sha256((repo/'zigimg'/name).read_bytes()).hexdigest() for name in ('verify_writer_address_reference.py','verify_jpeg_contracts_reference.py','verify_tiff_decode_reference.py','verify_stream_guards_reference.py','verify_image_open_reference.py','verify_image_tty_reference.py')}
        (root/'provenance.json').write_text(json.dumps(dict(source_sha256=PINNED_SOURCE_SHA256,stdlib_sha256=PINNED_STDLIB_SHA256,io_library_sha256=IO_LIBRARY_SHA256,format_library_sha256=FORMAT_LIBRARY_SHA256,integer_libraries=INTEGER_LIBRARIES,time_library_sha256=TIME_LIBRARY_SHA256,path_libraries=PATH_LIBRARIES,encoder_libraries=ENCODER_LIBRARIES,versions=versions,target=args.target,zig_mode=mode,v_prod=args.v_prod,implementation_sha256=impl,runner_sha256=runner_hash,fixtures=fixtures,helper_sha256=helpers,shared_fixture_sha256=shared_hash),indent=2)+'\n')
        print(f'Building pointer-address-formatting operations: Source {mode}, V {"production" if args.v_prod else "ordinary"}',flush=True)
        proof.run([str(zig),'build-exe','-target',args.target,'-lc','-I',str(root),'-O',mode,'--global-cache-dir',str(root.parent/'zig-global'),'--cache-dir',str(root/'zig-cache'),'-femit-bin='+str(root/'native'),str(root/'reference.zig'),str(root/'fixture_shims.c')],'build-source',env=env,timeout=args.timeout)
        proof.run([str(v),'-enable-globals',*(['-prod'] if args.v_prod else []),'-path',f'{repo}|@vlib|@vmodules','-o',str(root/'translated'),str(root/'main.v')],'build-v',env=env,timeout=args.timeout)
        rows=corpus();path=root/'corpus.txt';path.write_text('\n'.join(data for _,data in rows)+'\n');inputs={'corpus.txt':hashlib.sha256(path.read_bytes()).hexdigest()};(root/'input_sha256.json').write_text(json.dumps(inputs,indent=2)+'\n')
        outputs=[]
        for exe in ('native','translated'):
            result=proof.run([str(root/exe),str(path)],'returning-'+exe,env=env,timeout=args.timeout)
            if result.stderr or len(result.stdout.splitlines())!=len(rows):raise AssertionError('invalid returning output')
            outputs.append(result.stdout.splitlines())
        for i,((group,data),native,translated) in enumerate(zip(rows,*outputs)):
            if native!=translated:raise AssertionError(f'{i}/{group}: pointer-address-formatting record differs; see retained proof')
            snapshot_checks(native,data)
        digest=hashlib.sha256(b'\n'.join(outputs[0])).hexdigest()
        if EXPECTED_ROWS is not None and (len(rows)!=EXPECTED_ROWS or digest!=EXPECTED_SHA256):raise AssertionError('returning golden changed')
        returns=hashlib.sha256();states=hashlib.sha256();return_count=0;trap_count=0
        print(f'{len(rows)} returning pointer-address-formatting records match; checking failure controls',flush=True)
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
        if tree_hash(source)!=PINNED_SOURCE_SHA256 or tree_hash(root/'src')!=PINNED_SOURCE_SHA256 or time_library_hash(zig)!=TIME_LIBRARY_SHA256 or integer_library_hashes(zig)!=INTEGER_LIBRARIES or format_library_hash(zig)!=FORMAT_LIBRARY_SHA256 or io_library_hash(zig)!=IO_LIBRARY_SHA256 or stdlib_hash(zig)!=PINNED_STDLIB_SHA256 or path_library_hashes(zig)!=PATH_LIBRARIES or encoder_library_hashes(zig)!=ENCODER_LIBRARIES or implementation_hashes(repo)!=impl or hashlib.sha256(Path(__file__).read_bytes()).hexdigest()!=runner_hash:raise AssertionError('dependency/implementation/runner changed')
        for name,pin in fixtures.items():
            if any(hashlib.sha256((base/name).read_bytes()).hexdigest()!=pin for base in (root,probe)):raise AssertionError('fixture changed')
        for name,pin in inputs.items():
            if hashlib.sha256((root/name).read_bytes()).hexdigest()!=pin:raise AssertionError('input changed')
        for name,pin in helpers.items():
            if hashlib.sha256((repo/'zigimg'/name).read_bytes()).hexdigest()!=pin:raise AssertionError('helper changed')
        for directory,pin in shared_hash.items():
            if any(hashlib.sha256(p.read_bytes()).hexdigest()!=pin for p in (root/directory/'fixture_shims.h',repo/'zigimg/reference_probes'/directory/'fixture_shims.h')):raise AssertionError('shared fixture changed')
        if list(root.glob('*.owned*')):raise AssertionError('owned paths survived')
        summary=dict(returning_records=len(rows),primary_calls=len(rows),pointer_forms=dict(Counter(int(data.split('|')[6]) for _,data in rows)),types=dict(Counter(int(data.split('|')[9]) for _,data in rows)),returning_groups=dict(Counter(group for group,_ in rows)),output_sha256=digest,return_controls=return_count,control_sha256=returns.hexdigest(),paired_traps=trap_count,state_sha256=states.hexdigest(),zig_mode=mode,v_prod=args.v_prod)
        (root/'summary.json').write_text(json.dumps(summary,indent=2)+'\n');print(json.dumps(summary),flush=True)

if __name__=='__main__':main()
