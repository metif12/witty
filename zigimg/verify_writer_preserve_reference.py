"""Compare preserved byte repetitions, compaction, scratch effects, and failures."""
import argparse
from collections import Counter
import hashlib,itertools,json,os,re,shutil
from pathlib import Path
from verify_jpeg_contracts_reference import implementation_hashes
from verify_tiff_decode_reference import ProofLog,tree_hash,work_directory,PINNED_SOURCE_SHA256,checked_trap
from verify_stream_guards_reference import stdlib_hash,PINNED_STDLIB_SHA256
from verify_image_open_reference import PATH_LIBRARIES,path_library_hashes
from verify_image_tty_reference import ENCODER_LIBRARIES,encoder_library_hashes





EXPECTED_ROWS = 18079
EXPECTED_SHA256 = 'a95d29c7312843dc2a621c842e4a0bd3a46be85c2c8844a47ebbdf3a1e05ceb7'
EXPECTED_CONTROLS = 984
EXPECTED_CONTROL_SHA256 = '489cf5e120fadc21e51a1d073e63be157a8212fb9663de5f7fb94a40732698da'
EXPECTED_TRAPS = 360
EXPECTED_STATE_SHA256 = '94f7ad5da10c18d47efd467ae9f9c94c29aefe4f7ba82347fe314aa040da9ed0'
MAX_USIZE=(1<<64)-1
def spec(kind=0,cap=8,start=0,prefix=0,preserve=0,repeat=1,binding=0,finish=0,mask=91):
 return '|'.join(map(str,(kind,cap,start,prefix,preserve,repeat,binding,finish,0,mask)))
def initial_end(kind,cap,start,prefix):return (start if kind==0 and start<cap else 0)+prefix

def fields(part):
 status,metadata,buffer,pending,unused,inputs,contents=part.split('|');m=list(map(int,metadata.split(':')));assert len(m)==6
 payload,headers=inputs.split('#');spans=tuple(tuple(map(int,h.split(','))) for h in headers.split(';')) if headers else ()
 return status,m,bytes.fromhex(buffer),bytes.fromhex(pending),bytes.fromhex(unused),(bytes.fromhex(payload),spans),bytes.fromhex(contents)

class ModelTrap(Exception):pass
class WriteFailure(Exception):pass
class ModelLimit(Exception):pass

def modeled(data):
 kind,cap,start,prefix,preserve,count,binding,finish,unused,mask=map(int,data.split('|'));assert unused==0
 end=initial_end(kind,cap,start,prefix);pos=start if kind else 0;mode=kind;wire=bytearray();calls=0
 buffer=bytearray((i*17+165)&255 for i in range(cap));begin=end-prefix;buffer[begin:end]=bytes((i*31+7)&255 for i in range(prefix))
 payload=bytes((i*23+mask)&255 for i in range(256));byte=payload[:1]
 contents=bytearray((i*37+19)&255 for i in range(32)) if kind and not binding else bytearray()
 def state(status):
  return status,[pos+end,cap-end,end,end,0 if not kind or binding==2 else 1,0 if not kind else (3 if binding==1 else 2)],bytes(buffer),bytes(buffer[:end]),bytes(buffer[end:]),(payload,((0,1),)),bytes(contents)
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
 def short(repeat):
  nonlocal end,pos,mode,calls
  calls+=1
  if calls>128:raise ModelLimit()
  total=checked(end+repeat)
  if total<=cap:buffer[end:total]=byte*repeat;end=total;return repeat
  if not kind:buffer[end:cap]=byte*(cap-end);end=cap;raise WriteFailure()
  segments=[bytes(buffer[:end])] if end else []
  if repeat==1:segments.append(byte)
  elif repeat>1:
   capacity=cap-end if cap-end>=64 else 64;n=min(capacity,repeat);scratch=byte*n
   if cap-end>=64:buffer[end:end+n]=scratch
   segments.append(scratch);remaining=repeat-n
   while remaining>capacity and len(segments)<16:segments.append(scratch);remaining-=capacity
   if remaining and len(segments)<16:segments.append(byte*remaining)
  if not segments:return 0
  if mode<0 or binding==2:raise WriteFailure()
  if binding==1 and mode==1:
   mode=2
   if pos:pos=0;mode=-1;raise WriteFailure()
   return 0
  emitted=segments[0] if kind==1 and not binding else b''.join(segments);n=len(emitted);output(emitted);consumed=max(0,n-end)
  if n<end:buffer[:end-n]=buffer[n:end];end-=n
  else:end=0
  return consumed
 states=[state('setup'),state('ready')]
 try:
  total=checked(end+count)
  if total<=cap:buffer[end:total]=byte*count;end=total
  else:
   remaining=count
   while remaining>preserve:
    remaining=checked(remaining-short(remaining-preserve))
    if checked(end+remaining)<=cap:buffer[end:end+remaining]=byte*remaining;end+=remaining;break
   else:
    if preserve<end:buffer[:preserve]=buffer[end-preserve:end];end=preserve
    while remaining:remaining=checked(remaining-short(remaining))
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
 for kind,cap,start in itertools.product(range(3),(0,1,8,64,128),(0,3)):
  begin=initial_end(kind,cap,start,0)
  for prefix in sorted({0,(cap-begin)//2,cap-begin}):
   for preserve,count in itertools.product(sorted({0,1,cap//2,cap,cap+1,MAX_USIZE}),(0,1,2,3,8,9,65,129)):
    for binding in ((0,) if kind==0 else (0,1,2)):
     for finish in ((0,1) if binding==0 else (0,)):
      rows.append(('preserve',spec(kind,cap,start,prefix,preserve,count,binding,finish)))
 for kind,cap in itertools.product((1,2),(63,64,65,128)):
  for prefix in sorted({0,1,cap,*((63,64,65) if cap==128 else ())}):
   for preserve,count in itertools.product((0,1,2,63,64,65,MAX_USIZE),(63,64,65,129,513)):
    for binding in (0,1,2):
     for finish in ((0,1) if binding==0 else (0,)):
      rows.append(('scratch',spec(kind,cap,prefix=prefix,preserve=preserve,repeat=count,binding=binding,finish=finish)))
 for kind,preserve,mask in itertools.product(range(3),(0,2,5,8,9),range(256)):
  rows.append(('every-byte',spec(kind,8,prefix=8,preserve=preserve,repeat=3,finish=1,mask=mask)))
 result=[]
 for group,data in rows:
  if data in seen:continue
  try:trap=modeled(data)[1]
  except ModelLimit:continue
  if trap is None:seen.add(data);result.append((group,data))
 return result

def controls():
 rows=[];seen=set()
 for kind,cap,start in itertools.product(range(3),(0,8,64),(0,3)):
  begin=initial_end(kind,cap,start,0)
  for prefix in sorted({0,cap-begin}):
   for binding in ((0,) if kind==0 else (0,1,2)):
    for preserve,count in itertools.product(sorted({0,1,cap,cap+1,MAX_USIZE-1,MAX_USIZE}),(0,1,MAX_USIZE-1,MAX_USIZE)):
     data=spec(kind,cap,start,prefix,preserve,count,binding)
     if data in seen:continue
     seen.add(data)
     try:trap=modeled(data)[1]
     except ModelLimit:continue
     rows.append((f'boundary-{len(rows)}',data,trap[1] if trap else None))
 return rows

def snapshot_checks(line,data):
 parts=line.decode().split('~');assert len(parts)==6
 states=[fields(part) for part in parts[:-1]];model,trap,wire=modeled(data);assert trap is None and states==model,'independent preserved byte/scratch/input state differs'
 f=list(map(int,data.split('|')));assert parts[-1]==('-1:'+wire.hex() if f[0] and f[6]==1 else '-3:')

def classify(native,translated,name,data,category,paths):
 if native.returncode==0:
  assert category is None and translated.returncode==0 and native.stdout==translated.stdout and native.stdout and not native.stderr+translated.stderr
  snapshot_checks(native.stdout.strip(),data);return 'return',native.stdout
 for result in (native,translated):
  checked_trap(result,name,category)
  messages=[m.group(1) for line in result.stderr.decode().splitlines() if (m:=re.fullmatch(r'(?:thread \d+ |V )?panic:\s*(.*)',line.strip()))];assert messages==[category]
 states=[p.read_bytes() for p in paths];assert states[0] and states[0]==states[1]
 _,trap,_=modeled(data);assert trap is not None and trap[1]==category and fields(states[0].decode())==trap[2],'preserved repetition failure state differs'
 return 'trap',category.encode()+b'\0'+states[0]+b'\n'

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source',type=Path);parser.add_argument('zig',type=Path);parser.add_argument('v',type=Path)
    parser.add_argument('--target',default='aarch64-macos.14.0');parser.add_argument('--v-prod',action='store_true');parser.add_argument('--workdir',type=Path);parser.add_argument('--timeout',type=int,default=600)
    args=parser.parse_args()
    if args.timeout<=0:parser.error('--timeout must be positive')
    source=args.source.resolve()/'src';zig=args.zig.resolve();v=args.v.resolve()
    if tree_hash(source)!=PINNED_SOURCE_SHA256 or stdlib_hash(zig)!=PINNED_STDLIB_SHA256 or path_library_hashes(zig)!=PATH_LIBRARIES or encoder_library_hashes(zig)!=ENCODER_LIBRARIES:parser.error('Source/compiler library differs from pins')
    repo=Path(__file__).resolve().parent.parent;probe=repo/'zigimg/reference_probes/writer_preserve';mode='ReleaseSafe' if args.v_prod else 'Debug'
    with work_directory(args.workdir,'witty-writer-preserve-') as root:
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
        print(f'Building preserved byte-repetition operations: Source {mode}, V {"production" if args.v_prod else "ordinary"}',flush=True)
        proof.run([str(zig),'build-exe','-target',args.target,'-lc','-I',str(root),'-O',mode,'--global-cache-dir',str(root.parent/'zig-global'),'--cache-dir',str(root/'zig-cache'),'-femit-bin='+str(root/'native'),str(root/'reference.zig'),str(root/'fixture_shims.c')],'build-source',env=env,timeout=args.timeout)
        proof.run([str(v),'-enable-globals',*(['-prod'] if args.v_prod else []),'-path',f'{repo}|@vlib|@vmodules','-o',str(root/'translated'),str(root/'main.v')],'build-v',env=env,timeout=args.timeout)
        rows=corpus();path=root/'corpus.txt';path.write_text('\n'.join(data for _,data in rows)+'\n');inputs={'corpus.txt':hashlib.sha256(path.read_bytes()).hexdigest()};(root/'input_sha256.json').write_text(json.dumps(inputs,indent=2)+'\n')
        outputs=[]
        for exe in ('native','translated'):
            result=proof.run([str(root/exe),str(path)],'returning-'+exe,env=env,timeout=args.timeout)
            if result.stderr or len(result.stdout.splitlines())!=len(rows):raise AssertionError('invalid returning output')
            outputs.append(result.stdout.splitlines())
        for i,((group,data),native,translated) in enumerate(zip(rows,*outputs)):
            if native!=translated:raise AssertionError(f'{i}/{group}: preserved byte-repetition record differs; see retained proof')
            snapshot_checks(native,data)
        digest=hashlib.sha256(b'\n'.join(outputs[0])).hexdigest()
        if EXPECTED_ROWS is not None and (len(rows)!=EXPECTED_ROWS or digest!=EXPECTED_SHA256):raise AssertionError('returning golden changed')
        returns=hashlib.sha256();states=hashlib.sha256();return_count=0;trap_count=0
        print(f'{len(rows)} returning preserved byte-repetition records match; checking failure controls',flush=True)
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
