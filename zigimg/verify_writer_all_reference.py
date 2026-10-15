"""Compare complete vector/repeated output, restored input headers, and failures."""
import argparse
from collections import Counter
import hashlib,itertools,json,os,re,shutil
from pathlib import Path
from verify_jpeg_contracts_reference import implementation_hashes
from verify_tiff_decode_reference import ProofLog,tree_hash,work_directory,PINNED_SOURCE_SHA256,checked_trap
from verify_stream_guards_reference import stdlib_hash,PINNED_STDLIB_SHA256
from verify_image_open_reference import PATH_LIBRARIES,path_library_hashes
from verify_image_tty_reference import ENCODER_LIBRARIES,encoder_library_hashes





EXPECTED_ROWS = 32016
EXPECTED_SHA256 = '502310555124f915d2936f00247b223335a4535edaa976ac6d9031ed4de1ea97'
EXPECTED_CONTROLS = 1176
EXPECTED_CONTROL_SHA256 = '7898d58c2de377fa6b3a544fba20a0a59e17cca347bf6acc623640a6bb505652'
EXPECTED_TRAPS = 770
EXPECTED_STATE_SHA256 = '32858e7a9472822eaa24f8cc6431f5beac669d09f1ed6f2d020b6720d54bf4f2'
MAX_USIZE=(1<<64)-1
PROFILES=[[], [[0, 0]], [[0, 1]], [[0, 3]], [[0, 2], [4, 0], [6, 3]], [[0, 1], [0, 1], [0, 1]], [[2, 4], [0, 3], [3, 5], [2, 0]], [[0, 1], [3, 2], [6, 3], [9, 1], [12, 2], [15, 3], [18, 1], [21, 2], [24, 3], [27, 1], [30, 2], [33, 3], [36, 1], [39, 2], [42, 3]], [[0, 1], [3, 2], [6, 3], [9, 1], [12, 2], [15, 3], [18, 1], [21, 2], [24, 3], [27, 1], [30, 2], [33, 3], [36, 1], [39, 2], [42, 3], [45, 1]], [[0, 1], [3, 2], [6, 3], [9, 1], [12, 2], [15, 3], [18, 1], [21, 2], [24, 3], [27, 1], [30, 2], [33, 3], [36, 1], [39, 2], [42, 3], [45, 1], [48, 2]], [[0, 1], [3, 2], [6, 3], [9, 1], [12, 2], [15, 3], [18, 1], [21, 2], [24, 3], [27, 1], [30, 2], [33, 3], [36, 1], [39, 2], [42, 3], [45, 1], [48, 2], [51, 3], [54, 1], [57, 2], [60, 3], [63, 1], [66, 2], [69, 3], [72, 1], [75, 2], [78, 3], [81, 1], [84, 2], [87, 3], [90, 1], [93, 2]], [[0, 1], [3, 2], [6, 3], [9, 1], [12, 2], [15, 3], [18, 1], [21, 2], [24, 3], [27, 1], [30, 2], [33, 3], [36, 1], [39, 2], [42, 3], [45, 1], [48, 2], [51, 3], [54, 1], [57, 2], [60, 3], [63, 1], [66, 2], [69, 3], [72, 1], [75, 2], [78, 3], [81, 1], [84, 2], [87, 3], [90, 1], [93, 2], [96, 3]], [[0, 0], [1, 3], [2, 0], [3, 3], [4, 0], [5, 3], [6, 0], [7, 3], [8, 0], [9, 3], [10, 0], [11, 3], [12, 0], [13, 3], [14, 0], [15, 3]], [[0, 0], [1, 3], [2, 0], [3, 3], [4, 0], [5, 3], [6, 0], [7, 3], [8, 0], [9, 3], [10, 0], [11, 3], [12, 0], [13, 3], [14, 0], [15, 3], [16, 0]], [[0, 0], [1, 3], [2, 0], [3, 3], [4, 0], [5, 3], [6, 0], [7, 3], [8, 0], [9, 3], [10, 0], [11, 3], [12, 0], [13, 3], [14, 0], [15, 3], [16, 0], [17, 3], [18, 0], [19, 3], [20, 0], [21, 3], [22, 0], [23, 3], [24, 0], [25, 3], [26, 0], [27, 3], [28, 0], [29, 3], [30, 0], [31, 3], [32, 0]], [[0, 0], [1, 0], [2, 0]], [[4, 1], [0, 1]], [[4, 1], [0, 2]], [[4, 0], [0, 1]], [[0, 32], [32, 64], [16, 128]], [[0, 0], [0, 0], [0, 0]], [[0, 255]]]

def spec(kind=0,cap=8,start=0,prefix=0,profile=2,repeat=1,binding=0,finish=0,api=0,mask=91):
 return '|'.join(map(str,(kind,cap,start,prefix,profile,repeat,binding,finish,api,mask)))
def initial_end(kind,cap,start,prefix):return (start if kind==0 and start<cap else 0)+prefix

def fields(part):
 status,metadata,buffer,pending,unused,inputs,contents=part.split('|');m=list(map(int,metadata.split(':')));assert len(m)==6
 payload,headers=inputs.split('#');spans=tuple(tuple(map(int,h.split(','))) for h in headers.split(';')) if headers else ()
 return status,m,bytes.fromhex(buffer),bytes.fromhex(pending),bytes.fromhex(unused),(bytes.fromhex(payload),spans),bytes.fromhex(contents)

class ModelTrap(Exception):pass
class WriteFailure(Exception):pass
class ModelLimit(Exception):pass

def modeled(data):
 kind,cap,start,prefix,profile,repeat,binding,finish,api,mask=map(int,data.split('|'))
 end=initial_end(kind,cap,start,prefix);pos=start if kind else 0;mode=kind;wire=bytearray();calls=0
 buffer=bytearray((i*17+165)&255 for i in range(cap));begin=end-prefix;buffer[begin:end]=bytes((i*31+7)&255 for i in range(prefix))
 payload=bytes((i*23+mask)&255 for i in range(256));spans=list(map(tuple,PROFILES[profile]))
 contents=bytearray((i*37+19)&255 for i in range(32)) if kind and not binding else bytearray()
 def state(status):
  return status,[pos+end,cap-end,end,end,0 if not kind or binding==2 else 1,0 if not kind else (3 if binding==1 else 2)],bytes(buffer),bytes(buffer[:end]),bytes(buffer[end:]),(payload,tuple(spans)),bytes(contents)
 def output(b):
  nonlocal pos
  if pos+len(b)>4096 or len(wire)+len(b)>4096:raise ModelLimit()
  if binding==1:wire.extend(b)
  else:
   if len(contents)<pos+len(b):contents.extend(bytes(pos+len(b)-len(contents)))
   contents[pos:pos+len(b)]=b
  pos+=len(b)
 def checked(n):
  if n>MAX_USIZE or n<0:raise ModelTrap('integer overflow')
  return n
 def short(vectors,repeats):
  nonlocal end,pos,mode,calls
  calls+=1
  if calls>128:raise ModelLimit()
  assert vectors
  inputs=[payload[o:o+n] for o,n in vectors];head=b''.join(inputs[:-1]);pattern=inputs[-1]
  total=checked(len(head)+checked(len(pattern)*repeats));checked(end+total)
  if end+total<=cap:
   buffer[end:end+total]=head+(pattern*repeats if pattern else b'');end+=total;return total
  if not kind:
   n=cap-end;joined=head[:n];left=n-len(joined)
   if left and pattern:joined+=(pattern*((left+len(pattern)-1)//len(pattern)))[:left]
   assert len(joined)==n;buffer[end:cap]=joined;end=cap;raise WriteFailure()
  segments=([bytes(buffer[:end])] if end else [])+[b for b in inputs[:-1] if b];segments=segments[:16]
  if len(segments)<16 and pattern and repeats:
   if repeats==1:segments.append(pattern)
   elif len(pattern)==1:
    capacity=cap-end if cap-end>=64 else 64;n=min(capacity,repeats);scratch=pattern*n
    if cap-end>=64:buffer[end:end+n]=scratch
    segments.append(scratch);remaining=repeats-n
    while remaining>capacity and len(segments)<16:segments.append(scratch);remaining-=capacity
    if remaining and len(segments)<16:segments.append(pattern*remaining)
   else:segments.extend([pattern]*min(repeats,16-len(segments)))
  if not segments:return 0
  if mode<0 or binding==2:raise WriteFailure()
  if binding==1 and mode==1:
   mode=2
   if pos:pos=0;mode=-1;raise WriteFailure()
   return 0
  emitted=segments[0] if kind==1 and not binding else b''.join(segments)
  n=len(emitted);output(emitted);consumed=max(0,n-end)
  if n<end:buffer[:end-n]=buffer[n:end];end-=n
  else:end=0
  return consumed
 def vector_prefix(index,truncate,repeats):
  original=spans[index];o,n=original;assert truncate<=n;spans[index]=(o+truncate,n-truncate)
  try:n=short(spans[index:],repeats)
  except WriteFailure:spans[index]=original;raise
  truncate=checked(truncate+n);spans[index]=original;return truncate
 states=[state('setup'),state('ready')]
 try:
  if api in (0,1):
   index=0;truncate=0
   while (index<len(spans) if api==0 else index+1<len(spans)):
    truncate=vector_prefix(index,truncate,1 if api==0 else repeat)
    while (index<len(spans) and truncate>=spans[index][1]) if api==0 else (truncate>=spans[index][1] and index+1<len(spans)):
     truncate-=spans[index][1];index+=1
   if api==1 and spans and truncate<checked(spans[index][1]*repeat):
    assert index==len(spans)-1;remaining=repeat;offset,length=spans[index]
    while True:
     remaining=checked(remaining-truncate//length);truncate%=length
     if not remaining:break
     truncate=checked(truncate+short([(offset+truncate,length-truncate),spans[index]],remaining-1))
  elif api==2:
   remaining=repeat
   while remaining:remaining=checked(remaining-short([(0,1)],remaining))
  else:
   pattern=spans[-1] if spans else (0,0);offset,length=pattern
   remaining=checked(length*repeat);remaining=checked(remaining-short([pattern],repeat))
   while remaining:
    splats,leftover=divmod(remaining,length)
    remaining=checked(remaining-short([(offset+length-leftover,leftover),pattern],splats))
  status='ok'
 except WriteFailure:status='WriteFailed'
 except ModelTrap as error:return states,('write',str(error),state('write')),bytes(wire)
 states.append(state(status))
 if cap:buffer[0]^=mask
 states.append(state('caller'));status='skip'
 if finish:
  status='ok'
  if kind and end:
   if mode<0 or binding==2:status='WriteFailed'
   else:output(bytes(buffer[:end]));end=0
 states.append(state(status));return states,None,bytes(wire)

def corpus():
 rows=[];seen=set()
 choices=[(0,p,1) for p in range(len(PROFILES))]
 choices += [(1,p,r) for p in range(len(PROFILES)) for r in (0,1,3)]
 choices += [(2,2,r) for r in (0,1,3)]+[(3,p,r) for p in (0,2,3,19,21) for r in (0,1,3)]
 for kind,cap,start in itertools.product(range(3),(0,1,8,64,128),(0,3)):
  begin=initial_end(kind,cap,start,0)
  for prefix in sorted({0,(cap-begin)//2,cap-begin}):
   for api,profile,repeat in choices:
    for binding in ((0,) if kind==0 else (0,1,2)):
     for finish in ((0,1) if binding==0 else (0,)):
      rows.append(('complete',spec(kind,cap,start,prefix,profile,repeat,binding,finish,api)))
 for kind,cap in itertools.product((1,2),(63,64,65,128)):
  for prefix in sorted({0,1,cap,*((63,64,65) if cap==128 else ())}):
   for api,profile in ((1,2),(1,5),(1,8),(2,2),(3,2)):
    for repeat,binding in itertools.product((2,63,64,65,129,513),(0,1,2)):
     for finish in ((0,1) if binding==0 else (0,)):
      rows.append(('scratch-retry',spec(kind,cap,prefix=prefix,profile=profile,repeat=repeat,binding=binding,finish=finish,api=api)))
 for kind,api,mask in itertools.product(range(3),range(4),range(256)):
  rows.append(('every-byte',spec(kind,64,profile=2,repeat=129,finish=1,api=api,mask=mask)))
 result=[]
 for group,data in rows:
  if data in seen:continue
  try:trap=modeled(data)[1]
  except ModelLimit:continue
  if trap is None:seen.add(data);result.append((group,data))
 return result

def controls():
 rows=[];seen=set();cases=[(api,p,n) for api in range(4) for p,n in ((0,0),(0,MAX_USIZE),(2,MAX_USIZE),(16,MAX_USIZE),(17,MAX_USIZE),(18,MAX_USIZE),(19,MAX_USIZE),(16,MAX_USIZE-1))]
 for kind,cap,start in itertools.product(range(3),(0,8,64),(0,3)):
  begin=initial_end(kind,cap,start,0)
  for prefix in sorted({0,cap-begin}):
   for binding in ((0,) if kind==0 else (0,1,2)):
    for api,profile,repeat in cases:
     data=spec(kind,cap,start,prefix,profile,repeat,binding,api=api)
     if data in seen:continue
     seen.add(data)
     try:trap=modeled(data)[1]
     except ModelLimit:continue
     rows.append((f'boundary-{len(rows)}',data,trap[1] if trap else None))
 return rows

def snapshot_checks(line,data):
 parts=line.decode().split('~');assert len(parts)==6
 states=[fields(part) for part in parts[:-1]];model,trap,wire=modeled(data);assert trap is None and states==model,'independent complete output/scratch/restored-header state differs'
 f=list(map(int,data.split('|')));assert parts[-1]==('-1:'+wire.hex() if f[0] and f[6]==1 else '-3:')

def classify(native,translated,name,data,category,paths):
 if native.returncode==0:
  assert category is None and translated.returncode==0 and native.stdout==translated.stdout and native.stdout and not native.stderr+translated.stderr
  snapshot_checks(native.stdout.strip(),data);return 'return',native.stdout
 for result in (native,translated):
  checked_trap(result,name,category)
  messages=[m.group(1) for line in result.stderr.decode().splitlines() if (m:=re.fullmatch(r'(?:thread \d+ |V )?panic:\s*(.*)',line.strip()))];assert messages==[category]
 states=[p.read_bytes() for p in paths];assert states[0] and states[0]==states[1]
 _,trap,_=modeled(data);assert trap is not None and trap[1]==category and fields(states[0].decode())==trap[2],'complete-write failure state differs'
 return 'trap',category.encode()+b'\0'+states[0]+b'\n'

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source',type=Path);parser.add_argument('zig',type=Path);parser.add_argument('v',type=Path)
    parser.add_argument('--target',default='aarch64-macos.14.0');parser.add_argument('--v-prod',action='store_true');parser.add_argument('--workdir',type=Path);parser.add_argument('--timeout',type=int,default=600)
    args=parser.parse_args()
    if args.timeout<=0:parser.error('--timeout must be positive')
    source=args.source.resolve()/'src';zig=args.zig.resolve();v=args.v.resolve()
    if tree_hash(source)!=PINNED_SOURCE_SHA256 or stdlib_hash(zig)!=PINNED_STDLIB_SHA256 or path_library_hashes(zig)!=PATH_LIBRARIES or encoder_library_hashes(zig)!=ENCODER_LIBRARIES:parser.error('Source/compiler library differs from pins')
    repo=Path(__file__).resolve().parent.parent;probe=repo/'zigimg/reference_probes/writer_all';mode='ReleaseSafe' if args.v_prod else 'Debug'
    with work_directory(args.workdir,'witty-writer-all-') as root:
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
        (root/'provenance.json').write_text(json.dumps(dict(source_sha256=PINNED_SOURCE_SHA256,stdlib_sha256=PINNED_STDLIB_SHA256,path_libraries=PATH_LIBRARIES,encoder_libraries=ENCODER_LIBRARIES,versions=versions,target=args.target,zig_mode=mode,v_prod=args.v_prod,implementation_sha256=impl,runner_sha256=runner_hash,fixtures=fixtures,helper_sha256=helpers,shared_fixture_sha256=shared_hash),indent=2)+'\n')
        print(f'Building complete vector/repeated-output operations: Source {mode}, V {"production" if args.v_prod else "ordinary"}',flush=True)
        proof.run([str(zig),'build-exe','-target',args.target,'-lc','-I',str(root),'-O',mode,'--global-cache-dir',str(root.parent/'zig-global'),'--cache-dir',str(root/'zig-cache'),'-femit-bin='+str(root/'native'),str(root/'reference.zig'),str(root/'fixture_shims.c')],'build-source',env=env,timeout=args.timeout)
        proof.run([str(v),'-enable-globals',*(['-prod'] if args.v_prod else []),'-path',f'{repo}|@vlib|@vmodules','-o',str(root/'translated'),str(root/'main.v')],'build-v',env=env,timeout=args.timeout)
        rows=corpus();path=root/'corpus.txt';path.write_text('\n'.join(data for _,data in rows)+'\n');inputs={'corpus.txt':hashlib.sha256(path.read_bytes()).hexdigest()};(root/'input_sha256.json').write_text(json.dumps(inputs,indent=2)+'\n')
        outputs=[]
        for exe in ('native','translated'):
            result=proof.run([str(root/exe),str(path)],'returning-'+exe,env=env,timeout=args.timeout)
            if result.stderr or len(result.stdout.splitlines())!=len(rows):raise AssertionError('invalid returning output')
            outputs.append(result.stdout.splitlines())
        for i,((group,data),native,translated) in enumerate(zip(rows,*outputs)):
            if native!=translated:raise AssertionError(f'{i}/{group}: complete vector/repeated-output record differs; see retained proof')
            snapshot_checks(native,data)
        digest=hashlib.sha256(b'\n'.join(outputs[0])).hexdigest()
        if EXPECTED_ROWS is not None and (len(rows)!=EXPECTED_ROWS or digest!=EXPECTED_SHA256):raise AssertionError('returning golden changed')
        returns=hashlib.sha256();states=hashlib.sha256();return_count=0;trap_count=0
        print(f'{len(rows)} returning complete vector/repeated-output records match; checking failure controls',flush=True)
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
        summary=dict(returning_records=len(rows),primary_calls=len(rows),apis=dict(Counter(int(data.split('|')[8]) for _,data in rows)),returning_groups=dict(Counter(group for group,_ in rows)),output_sha256=digest,return_controls=return_count,control_sha256=returns.hexdigest(),paired_traps=trap_count,state_sha256=states.hexdigest(),zig_mode=mode,v_prod=args.v_prod)
        (root/'summary.json').write_text(json.dumps(summary,indent=2)+'\n');print(json.dumps(summary),flush=True)

if __name__=='__main__':main()
