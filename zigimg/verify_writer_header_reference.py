"""Compare header writes, typed limits, direct drains, input aliases, and failures."""
import argparse
from collections import Counter
import hashlib,itertools,json,os,re,shutil
from pathlib import Path
from verify_jpeg_contracts_reference import implementation_hashes
from verify_tiff_decode_reference import ProofLog,tree_hash,work_directory,PINNED_SOURCE_SHA256,checked_trap
from verify_stream_guards_reference import stdlib_hash,PINNED_STDLIB_SHA256
from verify_image_open_reference import PATH_LIBRARIES,path_library_hashes
from verify_image_tty_reference import ENCODER_LIBRARIES,encoder_library_hashes





EXPECTED_ROWS = 16178
EXPECTED_SHA256 = '1e0679205ce4588b29831b2d82123193e83484e18d0ab64c01cb32ac45d446df'
EXPECTED_CONTROLS = 774
EXPECTED_CONTROL_SHA256 = 'f8e1a498bb355c9003f1557b2fb24c1cd8061ad91bf64659be0ff48915bc098d'
EXPECTED_TRAPS = 276
EXPECTED_STATE_SHA256 = 'e58c3d07ad1dd7b624ca38493980756c5b0ef602a30e27cfe85370ba84acacf9'
IO_LIBRARY_SHA256='09df1114cba703f824337f20489c7df5294db9f07961d4ac46abbbbf9c7ecaef'
def io_library_hash(zig):return hashlib.sha256((zig.parent/'lib/std/Io.zig').read_bytes()).hexdigest()
MAX_USIZE=(1<<64)-1
PROFILES=[[], [[0, 0]], [[0, 1]], [[0, 3]], [[0, 2], [4, 0], [6, 3]], [[0, 1], [0, 1], [0, 1]], [[2, 4], [0, 3], [3, 5], [2, 0]], [[0, 1], [3, 2], [6, 3], [9, 1], [12, 2], [15, 3], [18, 1], [21, 2], [24, 3], [27, 1], [30, 2], [33, 3], [36, 1], [39, 2], [42, 3]], [[0, 1], [3, 2], [6, 3], [9, 1], [12, 2], [15, 3], [18, 1], [21, 2], [24, 3], [27, 1], [30, 2], [33, 3], [36, 1], [39, 2], [42, 3], [45, 1]], [[0, 1], [3, 2], [6, 3], [9, 1], [12, 2], [15, 3], [18, 1], [21, 2], [24, 3], [27, 1], [30, 2], [33, 3], [36, 1], [39, 2], [42, 3], [45, 1], [48, 2]], [[0, 1], [3, 2], [6, 3], [9, 1], [12, 2], [15, 3], [18, 1], [21, 2], [24, 3], [27, 1], [30, 2], [33, 3], [36, 1], [39, 2], [42, 3], [45, 1], [48, 2], [51, 3], [54, 1], [57, 2], [60, 3], [63, 1], [66, 2], [69, 3], [72, 1], [75, 2], [78, 3], [81, 1], [84, 2], [87, 3], [90, 1], [93, 2]], [[0, 1], [3, 2], [6, 3], [9, 1], [12, 2], [15, 3], [18, 1], [21, 2], [24, 3], [27, 1], [30, 2], [33, 3], [36, 1], [39, 2], [42, 3], [45, 1], [48, 2], [51, 3], [54, 1], [57, 2], [60, 3], [63, 1], [66, 2], [69, 3], [72, 1], [75, 2], [78, 3], [81, 1], [84, 2], [87, 3], [90, 1], [93, 2], [96, 3]], [[0, 0], [1, 3], [2, 0], [3, 3], [4, 0], [5, 3], [6, 0], [7, 3], [8, 0], [9, 3], [10, 0], [11, 3], [12, 0], [13, 3], [14, 0], [15, 3]], [[0, 0], [1, 3], [2, 0], [3, 3], [4, 0], [5, 3], [6, 0], [7, 3], [8, 0], [9, 3], [10, 0], [11, 3], [12, 0], [13, 3], [14, 0], [15, 3], [16, 0]], [[0, 0], [1, 3], [2, 0], [3, 3], [4, 0], [5, 3], [6, 0], [7, 3], [8, 0], [9, 3], [10, 0], [11, 3], [12, 0], [13, 3], [14, 0], [15, 3], [16, 0], [17, 3], [18, 0], [19, 3], [20, 0], [21, 3], [22, 0], [23, 3], [24, 0], [25, 3], [26, 0], [27, 3], [28, 0], [29, 3], [30, 0], [31, 3], [32, 0]], [[0, 0], [1, 0], [2, 0]], [[4, 1], [0, 1]], [[4, 1], [0, 2]], [[4, 0], [0, 1]], [[0, 32], [32, 64], [16, 128]], [[0, 0], [0, 0], [0, 0]], [[0, 255]]]

def spec(kind=0,cap=8,start=0,prefix=0,profile=2,repeat=1,binding=0,finish=0,api=0,mask=91,offset=2,header=1,limit=MAX_USIZE):
 return '|'.join(map(str,(kind,cap,start,prefix,profile,repeat,binding,finish,api,mask,offset,header,limit)))
def initial_end(kind,cap,start,prefix):return (start if kind==0 and start<cap else 0)+prefix

def fields(part):
 status,metadata,buffer,pending,unused,inputs,contents=part.split('|');m=list(map(int,metadata.split(':')));assert len(m)==6
 payload,headers=inputs.split('#');spans=tuple(tuple(map(int,h.split(','))) for h in headers.split(';')) if headers else ()
 return status,m,bytes.fromhex(buffer),bytes.fromhex(pending),bytes.fromhex(unused),(bytes.fromhex(payload),spans),bytes.fromhex(contents)

class Panic(Exception):pass
class WriteFailed(Exception):pass

def modeled(data):
 kind,cap,start,prefix,profile,repeat,binding,finish,api,mask,offset,header_len,limit=map(int,data.split('|'))
 if api==0:limit=MAX_USIZE
 end=initial_end(kind,cap,start,prefix);pos=start if kind else 0;mode=kind;wire=bytearray()
 buffer=bytearray((i*17+165)&255 for i in range(cap));begin=end-prefix;buffer[begin:end]=bytes((i*31+7)&255 for i in range(prefix))
 payload=bytes((i*23+mask)&255 for i in range(256));spans=((offset,header_len),*map(tuple,PROFILES[profile]));inputs=[payload[o:o+n] for o,n in spans];header=inputs[0];vectors=inputs[1:]
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
 def drain(vecs,repeats):
  nonlocal end,pos,mode
  if not kind:
   if not vecs:return 0
   for b in vecs[:-1]:
    n=min(len(b),cap-end);copy(b[:n])
    if n<len(b):raise WriteFailed()
   pattern=vecs[-1]
   if not pattern:return 0
   if len(pattern)==1:
    if repeats<cap-end:raise Panic('reached unreachable code')
    copy(pattern*(cap-end));raise WriteFailed()
   # Successful iterations are bounded by the finite destination.
   for _ in range(min(repeats,(cap-end)//len(pattern)+1)):
    n=min(len(pattern),cap-end);copy(pattern[:n])
    if n<len(pattern):raise WriteFailed()
   raise Panic('reached unreachable code')
  segments=([bytes(buffer[:end])] if end else [])+[b for b in vecs[:-1] if b];segments=segments[:16];pattern=vecs[-1]
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
  if mode<0 or binding==2:raise WriteFailed()
  if binding==1 and mode==1:
   mode=2
   if pos:pos=0;mode=-1;raise WriteFailed()
   return 0
  emitted=segments[0] if kind==1 and not binding else b''.join(segments)
  n=len(emitted);output(emitted);consumed=max(0,n-end)
  if n<end:buffer[:end-n]=buffer[n:end];end-=n
  else:end=0
  return consumed
 def finish_header(h,vecs,repeats,remaining):
  batch=[]
  if h:
   n=min(len(h),remaining);batch.append(h[:n]);remaining-=n
   if not remaining:return drain(batch,1)
  if not vecs:raise Panic('integer overflow')
  for b in vecs[:-1]:
   if not b:continue
   n=min(len(h),remaining);batch.append(b);remaining-=n
   if not remaining or len(batch)==8:return drain(batch,1)
  pattern=vecs[-1]
  if repeats==1:batch.append(pattern[:min(remaining,len(pattern))]);return drain(batch,1)
  batch.append(pattern)
  if not pattern:raise Panic('division by zero')
  return drain(batch,min(remaining//len(pattern),repeats))
 def write():
  remaining=limit;n=min(len(header),cap-end,remaining)
  if n<len(header):return finish_header(header,vectors,repeat,remaining)
  copy(header);remaining-=n
  if not vectors:raise Panic('integer overflow')
  for i,b in enumerate(vectors[:-1]):
   n=min(len(b),cap-end,remaining)
   if n<len(b):return limit-remaining+finish_header(b'',vectors[i:],repeat,remaining)
   copy(b);remaining-=n
  pattern=vectors[-1];n=len(pattern)*repeat
  if n>MAX_USIZE:raise Panic('integer overflow')
  if n>min(cap-end,remaining):return limit-remaining+finish_header(b'',vectors[-1:],repeat,remaining)
  copy(pattern*repeat if pattern else b'');remaining-=n
  return limit-remaining
 states=[state('setup'),state('ready')]
 try:status='write='+str(write())
 except Panic as e:return states,('write',str(e),state('write')),bytes(wire)
 except WriteFailed:status='WriteFailed'
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
 choices=[(0,p,r,h,MAX_USIZE) for p in (1,2,3,4,5,6,7,12,19,21) for r in (0,1,3) for h in (0,1,9)]
 choices += [(1,p,(p+h+limit)%4,h,limit) for p in (0,1,2,4,7,15,19) for h in (0,1,9) for limit in (0,1,3,8,64,MAX_USIZE)]
 for kind,cap,start in itertools.product(range(3),(0,8,64),(0,3)):
  begin=initial_end(kind,cap,start,0)
  for prefix in sorted({0,cap-begin}):
   for api,profile,repeat,header,limit in choices:
    for binding in ((0,) if kind==0 else (0,1,2)):
     rows.append(('headers',spec(kind,cap,start,prefix,profile,repeat,binding,1 if binding==0 else 0,api,header=header,limit=limit)))
 for kind,cap,prefix,profile,repeat,limit in itertools.product((1,2),(63,64,65,128),(0,1),(2,5,7),(2,65,129),(0,1,65,MAX_USIZE)):
  for binding in (0,1,2):rows.append(('scratch-and-slots',spec(kind,cap,prefix=prefix,profile=profile,repeat=repeat,binding=binding,api=1,header=1,limit=limit)))
 for kind,api,mask in itertools.product(range(3),range(2),range(256)):
  rows.append(('every-byte',spec(kind,64,profile=4,repeat=3,finish=1,api=api,mask=mask,header=3,limit=8)))
 result=[]
 for group,data in rows:
  if data not in seen and modeled(data)[1] is None:seen.add(data);result.append((group,data))
 return result

def controls():
 rows=[];seen=set()
 cases=[(0,0,1,0,MAX_USIZE),(0,0,1,1,MAX_USIZE),(1,0,1,1,0),(1,1,0,9,8),(1,6,0,9,64),(1,6,3,1,0),(1,4,1,1,2),(1,3,1,0,1),(1,3,3,0,1)]
 cases += [(api,p,MAX_USIZE,h,l) for api,p,h,l in ((0,3,1,MAX_USIZE),(1,3,1,MAX_USIZE),(1,3,9,8),(1,2,1,0),(0,19,1,MAX_USIZE),(1,19,0,8))]
 for kind,cap,start in itertools.product(range(3),(0,8,64),(0,3)):
  begin=initial_end(kind,cap,start,0)
  for prefix in sorted({0,cap-begin}):
   for binding in ((0,) if kind==0 else (0,1,2)):
    for api,profile,repeat,header,limit in cases:
     data=spec(kind,cap,start,prefix,profile,repeat,binding,api=api,header=header,limit=limit)
     if data not in seen:
      seen.add(data);trap=modeled(data)[1];rows.append((f'boundary-{len(rows)}',data,trap[1] if trap else None))
 return rows

def snapshot_checks(line,data):
 parts=line.decode().split('~');assert len(parts)==6
 states=[fields(part) for part in parts[:-1]];model,trap,wire=modeled(data);assert trap is None and states==model,'independent header/limit/drain/input state differs'
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
    repo=Path(__file__).resolve().parent.parent;probe=repo/'zigimg/reference_probes/writer_header';mode='ReleaseSafe' if args.v_prod else 'Debug'
    with work_directory(args.workdir,'witty-writer-header-') as root:
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
        print(f'Building header-write operations: Source {mode}, V {"production" if args.v_prod else "ordinary"}',flush=True)
        proof.run([str(zig),'build-exe','-target',args.target,'-lc','-I',str(root),'-O',mode,'--global-cache-dir',str(root.parent/'zig-global'),'--cache-dir',str(root/'zig-cache'),'-femit-bin='+str(root/'native'),str(root/'reference.zig'),str(root/'fixture_shims.c')],'build-source',env=env,timeout=args.timeout)
        proof.run([str(v),'-enable-globals',*(['-prod'] if args.v_prod else []),'-path',f'{repo}|@vlib|@vmodules','-o',str(root/'translated'),str(root/'main.v')],'build-v',env=env,timeout=args.timeout)
        rows=corpus();path=root/'corpus.txt';path.write_text('\n'.join(data for _,data in rows)+'\n');inputs={'corpus.txt':hashlib.sha256(path.read_bytes()).hexdigest()};(root/'input_sha256.json').write_text(json.dumps(inputs,indent=2)+'\n')
        outputs=[]
        for exe in ('native','translated'):
            result=proof.run([str(root/exe),str(path)],'returning-'+exe,env=env,timeout=args.timeout)
            if result.stderr or len(result.stdout.splitlines())!=len(rows):raise AssertionError('invalid returning output')
            outputs.append(result.stdout.splitlines())
        for i,((group,data),native,translated) in enumerate(zip(rows,*outputs)):
            if native!=translated:raise AssertionError(f'{i}/{group}: header-write record differs; see retained proof')
            snapshot_checks(native,data)
        digest=hashlib.sha256(b'\n'.join(outputs[0])).hexdigest()
        if EXPECTED_ROWS is not None and (len(rows)!=EXPECTED_ROWS or digest!=EXPECTED_SHA256):raise AssertionError('returning golden changed')
        returns=hashlib.sha256();states=hashlib.sha256();return_count=0;trap_count=0
        print(f'{len(rows)} returning header-write records match; checking failure controls',flush=True)
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
