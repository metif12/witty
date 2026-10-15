"""Compare writer consumption, overlapping compaction, saved views, and later output."""
import argparse
from collections import Counter
import hashlib,itertools,json,os,re,shutil
from pathlib import Path
from verify_jpeg_contracts_reference import implementation_hashes
from verify_tiff_decode_reference import ProofLog,tree_hash,work_directory,PINNED_SOURCE_SHA256,checked_trap
from verify_stream_guards_reference import stdlib_hash,PINNED_STDLIB_SHA256
from verify_image_open_reference import PATH_LIBRARIES,path_library_hashes
from verify_image_tty_reference import ENCODER_LIBRARIES,encoder_library_hashes





EXPECTED_ROWS = 29078
EXPECTED_SHA256 = 'd2d163291c934845b3c6383a9dc78fc583a9ab352f969f8b486cb97b66e302ca'
EXPECTED_CONTROLS = 366
EXPECTED_CONTROL_SHA256 = 'f74c68332a27cd56879be6ae686f07e935469693aecf38f2e52ee9b69a5a1673'
EXPECTED_TRAPS = 0
EXPECTED_STATE_SHA256 = 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'
IO_LIBRARY_SHA256='09df1114cba703f824337f20489c7df5294db9f07961d4ac46abbbbf9c7ecaef'
def io_library_hash(zig):return hashlib.sha256((zig.parent/'lib/std/Io.zig').read_bytes()).hexdigest()
MAX_USIZE=(1<<64)-1
def spec(kind=0,cap=8,start=0,prefix=0,consume=1,all=0,binding=0,finish=0,mode=1,mask=91,second=0,refill=2,mutation=3):
 return '|'.join(map(str,(kind,cap,start,prefix,consume,all,binding,finish,mode,mask,second,refill,mutation)))
def initial_end(kind,cap,start,prefix):return (start if kind==0 and start<cap else 0)+prefix

def fields(part):
 status,metadata,buffer,pending,unused,saved,contents=part.split('|');m=list(map(int,metadata.split(':')));assert len(m)==6
 views=None if saved=='-' else tuple((int(o),int(n),bytes.fromhex(h)) for o,n,h in (v.split(':') for v in saved.split('#')))
 return status,m,bytes.fromhex(buffer),bytes.fromhex(pending),bytes.fromhex(unused),views,bytes.fromhex(contents)

class WriteFailed(Exception):pass

def modeled(data):
 kind,cap,start,prefix,consume,all,binding,finish,mode,mask,second,refill,mutation=map(int,data.split('|'))
 end=initial_end(kind,cap,start,prefix);pos=start if kind else 0;file_mode=kind;wire=bytearray();saved=None
 buffer=bytearray((i*17+165)&255 for i in range(cap));begin=end-prefix;buffer[begin:end]=bytes((i*31+7)&255 for i in range(prefix))
 contents=bytearray((i*37+19)&255 for i in range(32)) if kind and not binding else bytearray()
 def state(status):
  views=None if saved is None else ((0,saved,bytes(buffer[:saved])),(saved,cap-saved,bytes(buffer[saved:])))
  return status,[pos+end,cap-end,end,end,0 if not kind or binding==2 else 1,0 if not kind else (3 if binding==1 else 2)],bytes(buffer),bytes(buffer[:end]),bytes(buffer[end:]),views,bytes(contents)
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
 def change(offset,length):
  if mode and length:buffer[offset+(0 if mode==1 else length-1)]^=mask
 def prepare_file():
  nonlocal file_mode,pos
  if file_mode<0 or binding==2:raise WriteFailed()
  if binding==1 and file_mode==1:
   file_mode=2
   if pos:pos=0;file_mode=-1;raise WriteFailed()
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
 def consumed(n):
  nonlocal end
  if n<end:buffer[:end-n]=buffer[n:end];end-=n;return 0
  excess=n-end;end=0;return excess
 states=[state('setup')];saved=end;states.append(state('borrow'));change(0,cap);states.append(state('caller'))
 if mutation in (1,3):change(0,saved)
 if mutation in (2,3):change(saved,cap-saved)
 states.append(state('saved'));first=consumed(consume);states.append(state('consume='+str(first)))
 if all:end=0;value=0
 else:value=consumed(second)
 states.append(state('second='+str(value)));change(end,cap-end);states.append(state('unused'))
 status='skip'
 if finish==1:
  status='ok'
  try:write_all(bytes((i*23+mask)&255 for i in range(refill)))
  except WriteFailed:status='WriteFailed'
 states.append(state(status));status='skip'
 if finish:
  status='ok'
  if kind and end:
   try:
    if not prepare_file():assert prepare_file()
    output(bytes(buffer[:end]));end=0
   except WriteFailed:status='WriteFailed'
 states.append(state(status));return states,None,bytes(wire)

def corpus():
 rows=[];seen=set()
 for kind,cap,start in itertools.product(range(3),(0,1,8,17),(0,3)):
  begin=initial_end(kind,cap,start,0)
  for prefix in sorted({0,min(1,cap-begin),(cap-begin)//2,cap-begin}):
   end=begin+prefix
   for consume in sorted({0,min(1,end),end//2,end,end+1,MAX_USIZE}):
    for all in range(2):
     for binding in ((0,) if kind==0 else (0,1,2)):
      for finish in (0,1,2):
       rows.append(('consume-and-clear',spec(kind,cap,start,prefix,consume,all,binding,finish,second=(end-consume)//2 if consume<end else 1,refill=cap+1)))
 for kind,cap,consume,all,mode,byte in itertools.product(range(3),(1,8),(0,1,4,MAX_USIZE),range(2),(1,2),range(256)):
  rows.append(('every-byte',spec(kind,cap,prefix=cap,consume=consume,all=all,finish=1,mode=mode,mask=byte,second=1,refill=3)))
 for kind,cap,start,mutation,mode,all in itertools.product(range(3),(1,8,17),(0,3),range(4),(0,1,2),range(2)):
  begin=initial_end(kind,cap,start,0)
  rows.append(('saved-views',spec(kind,cap,start,(cap-begin)//2,consume=1,all=all,finish=1,mode=mode,second=1,mutation=mutation,refill=9)))
 result=[]
 for group,data in rows:
  if data not in seen:seen.add(data);result.append((group,data))
 return result

def controls():
 rows=[];seen=set()
 for kind,cap,start,all in itertools.product(range(3),(0,8),(0,3),range(2)):
  begin=initial_end(kind,cap,start,0)
  for prefix in sorted({0,cap-begin}):
   end=begin+prefix
   for count in sorted({0,end,end+1,MAX_USIZE-1,MAX_USIZE}):
    for binding in ((0,) if kind==0 else (0,1,2)):
     data=spec(kind,cap,start,prefix,count,all,binding,1,second=MAX_USIZE,refill=3)
     if data not in seen:seen.add(data);rows.append((f'boundary-{len(rows)}',data,None))
 return rows

def snapshot_checks(line,data):
 parts=line.decode().split('~');assert len(parts)==10
 states=[fields(part) for part in parts[:-1]];model,trap,wire=modeled(data);assert trap is None and states==model,'independent consumption/buffer/saved-view state differs'
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
    repo=Path(__file__).resolve().parent.parent;probe=repo/'zigimg/reference_probes/writer_consume';mode='ReleaseSafe' if args.v_prod else 'Debug'
    with work_directory(args.workdir,'witty-writer-consume-') as root:
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
        print(f'Building buffer-consumption operations: Source {mode}, V {"production" if args.v_prod else "ordinary"}',flush=True)
        proof.run([str(zig),'build-exe','-target',args.target,'-lc','-I',str(root),'-O',mode,'--global-cache-dir',str(root.parent/'zig-global'),'--cache-dir',str(root/'zig-cache'),'-femit-bin='+str(root/'native'),str(root/'reference.zig'),str(root/'fixture_shims.c')],'build-source',env=env,timeout=args.timeout)
        proof.run([str(v),'-enable-globals',*(['-prod'] if args.v_prod else []),'-path',f'{repo}|@vlib|@vmodules','-o',str(root/'translated'),str(root/'main.v')],'build-v',env=env,timeout=args.timeout)
        rows=corpus();path=root/'corpus.txt';path.write_text('\n'.join(data for _,data in rows)+'\n');inputs={'corpus.txt':hashlib.sha256(path.read_bytes()).hexdigest()};(root/'input_sha256.json').write_text(json.dumps(inputs,indent=2)+'\n')
        outputs=[]
        for exe in ('native','translated'):
            result=proof.run([str(root/exe),str(path)],'returning-'+exe,env=env,timeout=args.timeout)
            if result.stderr or len(result.stdout.splitlines())!=len(rows):raise AssertionError('invalid returning output')
            outputs.append(result.stdout.splitlines())
        for i,((group,data),native,translated) in enumerate(zip(rows,*outputs)):
            if native!=translated:raise AssertionError(f'{i}/{group}: buffer-consumption record differs; see retained proof')
            snapshot_checks(native,data)
        digest=hashlib.sha256(b'\n'.join(outputs[0])).hexdigest()
        if EXPECTED_ROWS is not None and (len(rows)!=EXPECTED_ROWS or digest!=EXPECTED_SHA256):raise AssertionError('returning golden changed')
        returns=hashlib.sha256();states=hashlib.sha256();return_count=0;trap_count=0
        print(f'{len(rows)} returning buffer-consumption records match; checking failure controls',flush=True)
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
        summary=dict(returning_records=len(rows),primary_calls=2*len(rows),consume_calls=2*len(rows)-sum(int(data.split('|')[5]) for _,data in rows),consume_all_calls=sum(int(data.split('|')[5]) for _,data in rows),returning_groups=dict(Counter(group for group,_ in rows)),output_sha256=digest,return_controls=return_count,control_sha256=returns.hexdigest(),paired_traps=trap_count,state_sha256=states.hexdigest(),zig_mode=mode,v_prod=args.v_prod)
        (root/'summary.json').write_text(json.dumps(summary,indent=2)+'\n');print(json.dumps(summary),flush=True)

if __name__=='__main__':main()
