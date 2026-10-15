"""Compare integer slice writes, byte swapping, borrowed inputs, and partial failures."""
import argparse
from collections import Counter
import hashlib,itertools,json,os,re,shutil
from pathlib import Path
from verify_jpeg_contracts_reference import implementation_hashes
from verify_tiff_decode_reference import ProofLog,tree_hash,work_directory,PINNED_SOURCE_SHA256,checked_trap
from verify_stream_guards_reference import stdlib_hash,PINNED_STDLIB_SHA256
from verify_image_open_reference import PATH_LIBRARIES,path_library_hashes
from verify_image_tty_reference import ENCODER_LIBRARIES,encoder_library_hashes





EXPECTED_ROWS = 25740
EXPECTED_SHA256 = 'f06bcdf9eead5f6decc922a0e71609c608ab7f3b5edbb6c3defc6f9a114eed3d'
EXPECTED_CONTROLS = 756
EXPECTED_CONTROL_SHA256 = 'c94e4f0ecdb9a4f52ad7233cc2513598235b4768084b7dbf7bc6711a99f5a7b0'
EXPECTED_TRAPS = 0
EXPECTED_STATE_SHA256 = 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'
IO_LIBRARY_SHA256='09df1114cba703f824337f20489c7df5294db9f07961d4ac46abbbbf9c7ecaef'
def io_library_hash(zig):return hashlib.sha256((zig.parent/'lib/std/Io.zig').read_bytes()).hexdigest()
MAX_USIZE=(1<<64)-1
WIDTHS=(1,2,4,8,8,1,2,4,8,8)
def spec(kind=0,cap=8,start=0,prefix=0,tag=1,binding=0,finish=0,api=0,mask=91,order=0,count=3,offset=1):
 return '|'.join(map(str,(kind,cap,start,prefix,tag,0,binding,finish,api,mask,order,count,offset)))
def initial_end(kind,cap,start,prefix):return (start if kind==0 and start<cap else 0)+prefix

def fields(part):
 status,metadata,buffer,pending,unused,inputs,contents=part.split('|');m=list(map(int,metadata.split(':')));assert len(m)==6
 payload,headers=inputs.split('#');spans=tuple(tuple(map(int,h.split(','))) for h in headers.split(';')) if headers else ()
 return status,m,bytes.fromhex(buffer),bytes.fromhex(pending),bytes.fromhex(unused),(bytes.fromhex(payload),spans),bytes.fromhex(contents)

class WriteFailed(Exception):pass

def modeled(data):
 kind,cap,start,prefix,tag,reserved,binding,finish,api,mask,order,count,offset=map(int,data.split('|'));assert reserved==0
 end=initial_end(kind,cap,start,prefix);pos=start if kind else 0;mode=kind;wire=bytearray()
 buffer=bytearray((i*17+165)&255 for i in range(cap));begin=end-prefix;buffer[begin:end]=bytes((i*31+7)&255 for i in range(prefix))
 width=WIDTHS[tag%10];payload=bytes((i*23+mask)&255 for i in range((count+2)*width));spans=((offset*width,count*width),);source=payload[offset*width:(offset+count)*width]
 contents=bytearray((i*37+19)&255 for i in range(32)) if kind and not binding else bytearray()
 def state(status):
  return status,[pos+end,cap-end,end,end,0 if not kind or binding==2 else 1,0 if not kind else (3 if binding==1 else 2)],bytes(buffer),bytes(buffer[:end]),bytes(buffer[end:]),(payload,spans),bytes(contents)
 def output(b):
  nonlocal pos
  if binding==1:wire.extend(b)
  else:
   if len(contents)<pos+len(b):contents.extend(bytes(pos+len(b)-len(contents)))
   contents[pos:pos+len(b)]=b
  pos+=len(b)
 def copy(b):
  nonlocal end
  buffer[end:end+len(b)]=b;end+=len(b)
 def prepare_file():
  nonlocal mode,pos
  if mode<0 or binding==2:raise WriteFailed()
  if binding==1 and mode==1:
   mode=2
   if pos:pos=0;mode=-1;raise WriteFailed()
   return False
  return True
 def write_all(b):
  nonlocal end
  index=0
  while index<len(b):
   left=b[index:]
   if len(left)<=cap-end:copy(left);return
   if not kind:copy(left[:cap-end]);raise WriteFailed()
   if not prepare_file():continue
   pending=bytes(buffer[:end]);emitted=(pending if pending else left) if kind==1 and not binding else pending+left
   n=len(emitted);output(emitted)
   if n<end:buffer[:end-n]=buffer[n:end];end-=n
   else:index+=n-end;end=0
 states=[state('setup'),state('ready')]
 chunks=[source[i:i+width][::-1] for i in range(0,len(source),width)] if api==1 or order%2==0 else [source]
 status='ok'
 try:
  for chunk in chunks:write_all(chunk)
 except WriteFailed:status='WriteFailed'
 states.append(state(status))
 if cap:buffer[0]^=mask
 states.append(state('caller'));status='skip'
 if finish:
  status='ok'
  if kind and end:
   try:
    if not prepare_file():assert prepare_file()
    output(bytes(buffer[:end]));end=0
   except WriteFailed:status='WriteFailed'
 states.append(state(status));return states,None,bytes(wire)

def corpus():
 rows=[];seen=set();operations=[(0,order) for order in range(4)]+[(1,0)]
 for tag,(api,order),kind,cap,start,count in itertools.product(range(20),operations,range(3),(0,1,8,17),(0,3),(0,1,3)):
  begin=initial_end(kind,cap,start,0)
  for prefix in sorted({0,cap-begin}):rows.append(('integer-slices',spec(kind,cap,start,prefix,tag,finish=1,api=api,order=order,count=count)))
 for tag,(api,order),kind,cap,start,count,binding in itertools.product((0,1,3,6,11,18),operations,(1,2),(0,3,8),(0,3),(0,1,3),(1,2)):
  for prefix in sorted({0,cap}):rows.append(('io-failure-order',spec(kind,cap,start,prefix,tag,binding=binding,finish=1,api=api,order=order,count=count)))
 for byte,tag,(api,order),kind in itertools.product(range(256),(0,1,5,16),((0,0),(0,1),(1,0)),range(3)):
  rows.append(('every-byte',spec(kind,8,tag=tag,finish=1,api=api,order=order,mask=byte,count=3)))
 for tag,(api,order),kind,cap,offset in itertools.product((1,3,11,18),operations,range(3),(1,8,17),(0,2)):
  rows.append(('input-guards',spec(kind,cap,tag=tag,finish=1,api=api,order=order,count=9,offset=offset)))
 result=[]
 for group,data in rows:
  if data not in seen:seen.add(data);result.append((group,data))
 return result

def controls():
 rows=[];seen=set()
 for kind,cap,start,tag,(api,order),count in itertools.product(range(3),(0,8),(0,3),(1,3,16),((0,0),(0,1),(1,0)),(0,3)):
  begin=initial_end(kind,cap,start,0)
  for prefix in sorted({0,cap-begin}):
   for binding in ((0,) if kind==0 else (0,1,2)):
    data=spec(kind,cap,start,prefix,tag,binding,1,api,order=order,count=count)
    if data not in seen:seen.add(data);rows.append((f'boundary-{len(rows)}',data,None))
 return rows

def snapshot_checks(line,data):
 parts=line.decode().split('~');assert len(parts)==6
 states=[fields(part) for part in parts[:-1]];model,trap,wire=modeled(data);assert trap is None and states==model,'independent integer-slice/buffer/input state differs'
 f=list(map(int,data.split('|')));assert parts[-1]==('-1:'+wire.hex() if f[0] and f[6]==1 else '-3:')

def classify(native,translated,name,data,category,paths):
 if native.returncode==0:
  assert category is None and translated.returncode==0 and native.stdout==translated.stdout and native.stdout and not native.stderr+translated.stderr
  snapshot_checks(native.stdout.strip(),data);return 'return',native.stdout
 for result in (native,translated):
  checked_trap(result,name,category)
  messages=[m.group(1) for line in result.stderr.decode().splitlines() if (m:=re.fullmatch(r'(?:thread \d+ |V )?panic:\s*(.*)',line.strip()))];assert messages==[category]
 states=[p.read_bytes() for p in paths];assert states[0] and states[0]==states[1]
 _,trap,_=modeled(data);assert trap is not None and trap[1]==category and fields(states[0].decode())==trap[2],'rebase failure state differs'
 return 'trap',category.encode()+b'\0'+states[0]+b'\n'

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source',type=Path);parser.add_argument('zig',type=Path);parser.add_argument('v',type=Path)
    parser.add_argument('--target',default='aarch64-macos.14.0');parser.add_argument('--v-prod',action='store_true');parser.add_argument('--workdir',type=Path);parser.add_argument('--timeout',type=int,default=600)
    args=parser.parse_args()
    if args.timeout<=0:parser.error('--timeout must be positive')
    source=args.source.resolve()/'src';zig=args.zig.resolve();v=args.v.resolve()
    if tree_hash(source)!=PINNED_SOURCE_SHA256 or io_library_hash(zig)!=IO_LIBRARY_SHA256 or stdlib_hash(zig)!=PINNED_STDLIB_SHA256 or path_library_hashes(zig)!=PATH_LIBRARIES or encoder_library_hashes(zig)!=ENCODER_LIBRARIES:parser.error('Source/compiler library differs from pins')
    repo=Path(__file__).resolve().parent.parent;probe=repo/'zigimg/reference_probes/writer_slice_endian';mode='ReleaseSafe' if args.v_prod else 'Debug'
    with work_directory(args.workdir,'witty-writer-slice-endian-') as root:
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
        helpers={name:hashlib.sha256((repo/'zigimg'/name).read_bytes()).hexdigest() for name in ('verify_jpeg_contracts_reference.py','verify_tiff_decode_reference.py','verify_stream_guards_reference.py','verify_image_open_reference.py','verify_image_tty_reference.py')}
        (root/'provenance.json').write_text(json.dumps(dict(source_sha256=PINNED_SOURCE_SHA256,stdlib_sha256=PINNED_STDLIB_SHA256,io_library_sha256=IO_LIBRARY_SHA256,path_libraries=PATH_LIBRARIES,encoder_libraries=ENCODER_LIBRARIES,versions=versions,target=args.target,zig_mode=mode,v_prod=args.v_prod,implementation_sha256=impl,runner_sha256=runner_hash,fixtures=fixtures,helper_sha256=helpers,shared_fixture_sha256=shared_hash),indent=2)+'\n')
        print(f'Building integer-slice operations: Source {mode}, V {"production" if args.v_prod else "ordinary"}',flush=True)
        proof.run([str(zig),'build-exe','-target',args.target,'-lc','-I',str(root),'-O',mode,'--global-cache-dir',str(root.parent/'zig-global'),'--cache-dir',str(root/'zig-cache'),'-femit-bin='+str(root/'native'),str(root/'reference.zig'),str(root/'fixture_shims.c')],'build-source',env=env,timeout=args.timeout)
        proof.run([str(v),'-enable-globals',*(['-prod'] if args.v_prod else []),'-path',f'{repo}|@vlib|@vmodules','-o',str(root/'translated'),str(root/'main.v')],'build-v',env=env,timeout=args.timeout)
        rows=corpus();path=root/'corpus.txt';path.write_text('\n'.join(data for _,data in rows)+'\n');inputs={'corpus.txt':hashlib.sha256(path.read_bytes()).hexdigest()};(root/'input_sha256.json').write_text(json.dumps(inputs,indent=2)+'\n')
        outputs=[]
        for exe in ('native','translated'):
            result=proof.run([str(root/exe),str(path)],'returning-'+exe,env=env,timeout=args.timeout)
            if result.stderr or len(result.stdout.splitlines())!=len(rows):raise AssertionError('invalid returning output')
            outputs.append(result.stdout.splitlines())
        for i,((group,data),native,translated) in enumerate(zip(rows,*outputs)):
            if native!=translated:raise AssertionError(f'{i}/{group}: integer-slice record differs; see retained proof')
            snapshot_checks(native,data)
        digest=hashlib.sha256(b'\n'.join(outputs[0])).hexdigest()
        if EXPECTED_ROWS is not None and (len(rows)!=EXPECTED_ROWS or digest!=EXPECTED_SHA256):raise AssertionError('returning golden changed')
        returns=hashlib.sha256();states=hashlib.sha256();return_count=0;trap_count=0
        print(f'{len(rows)} returning integer-slice records match; checking failure controls',flush=True)
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
        if tree_hash(source)!=PINNED_SOURCE_SHA256 or tree_hash(root/'src')!=PINNED_SOURCE_SHA256 or io_library_hash(zig)!=IO_LIBRARY_SHA256 or stdlib_hash(zig)!=PINNED_STDLIB_SHA256 or path_library_hashes(zig)!=PATH_LIBRARIES or encoder_library_hashes(zig)!=ENCODER_LIBRARIES or implementation_hashes(repo)!=impl or hashlib.sha256(Path(__file__).read_bytes()).hexdigest()!=runner_hash:raise AssertionError('dependency/implementation/runner changed')
        for name,pin in fixtures.items():
            if any(hashlib.sha256((base/name).read_bytes()).hexdigest()!=pin for base in (root,probe)):raise AssertionError('fixture changed')
        for name,pin in inputs.items():
            if hashlib.sha256((root/name).read_bytes()).hexdigest()!=pin:raise AssertionError('input changed')
        for name,pin in helpers.items():
            if hashlib.sha256((repo/'zigimg'/name).read_bytes()).hexdigest()!=pin:raise AssertionError('helper changed')
        for directory,pin in shared_hash.items():
            if any(hashlib.sha256(p.read_bytes()).hexdigest()!=pin for p in (root/directory/'fixture_shims.h',repo/'zigimg/reference_probes'/directory/'fixture_shims.h')):raise AssertionError('shared fixture changed')
        if list(root.glob('*.owned*')):raise AssertionError('owned paths survived')
        summary=dict(returning_records=len(rows),primary_calls=len(rows),apis=dict(Counter(int(data.split('|')[8]) for _,data in rows)),returning_groups=dict(Counter(group for group,_ in rows)),output_sha256=digest,return_controls=return_count,control_sha256=returns.hexdigest(),paired_traps=trap_count,state_sha256=states.hexdigest(),zig_mode=mode,v_prod=args.v_prod)
        (root/'summary.json').write_text(json.dumps(summary,indent=2)+'\n');print(json.dumps(summary),flush=True)

if __name__=='__main__':main()
