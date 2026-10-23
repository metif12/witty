"""Compare native custom value dispatch and exact retained writer state."""
import argparse
from collections import Counter
import base64,hashlib,itertools,json,os,re,shutil
from pathlib import Path
from verify_jpeg_contracts_reference import implementation_hashes
from verify_tiff_decode_reference import ProofLog,tree_hash,work_directory,PINNED_SOURCE_SHA256,checked_trap
from verify_stream_guards_reference import stdlib_hash,PINNED_STDLIB_SHA256
from verify_image_open_reference import PATH_LIBRARIES,path_library_hashes
from verify_image_tty_reference import ENCODER_LIBRARIES,encoder_library_hashes





EXPECTED_ROWS = 6125
EXPECTED_SHA256 = '722ae4a32f6d881fe3189ea0bedfd6ee4648a998b63d7d8e288e815ea7fbe9a0'
EXPECTED_CONTROLS = 106
EXPECTED_CONTROL_SHA256 = 'ac3c5bf0362ea046c99d2135bb0b2281385406df0b371b08f7516e9a7a073468'
EXPECTED_TRAPS = 2
EXPECTED_STATE_SHA256 = '36d4f88f11bcbc83180f6cefcd3894ac0f515c3cc82cd947f2d4a1a14d2338f3'
IO_LIBRARY_SHA256='09df1114cba703f824337f20489c7df5294db9f07961d4ac46abbbbf9c7ecaef'
def io_library_hash(zig):return hashlib.sha256((zig.parent/'lib/std/Io.zig').read_bytes()).hexdigest()
FORMAT_LIBRARY_SHA256='667eac6285e472b5516ebebf8a6e69959a171be4fb97cac1e56419ffec20d500'
def format_library_hash(zig):return hashlib.sha256((zig.parent/'lib/std/fmt.zig').read_bytes()).hexdigest()
INTEGER_LIBRARIES={'math.zig':'65645001357d5f78cbf646485e009a048b828680bb1b47fb3de0fd8617d91af1','meta.zig':'3cf9b3eb6c6b6f9b101f06f0562a4071c81a5fbc6de63d8197e837e10cedfc40'}
def integer_library_hashes(zig):return {n:hashlib.sha256((zig.parent/'lib/std'/n).read_bytes()).hexdigest() for n in INTEGER_LIBRARIES}
from verify_format_parser_reference import EXTRA_LIBRARIES,library_hashes
VALUE_LIBRARIES={'base64.zig':'f506bb85c053a0bda914258c3c295107e9987c48674c2addf57ffecd5dddca8d'}
def value_library_hashes(zig):return {name:hashlib.sha256((zig.parent/'lib/std'/name).read_bytes()).hexdigest() for name in VALUE_LIBRARIES}
from functools import lru_cache
from verify_writer_float_reference import FLOAT_LIBRARIES,float_library_hashes
from verify_float_render_reference import spec as render_spec,modeled as render_model
ENUM_LIBRARY_SHA256='d6da51cbd1e4ef79570318b0ba1cc1a2127c8afe7b96f91dbba94c9dfe2498bc'
def enum_library_hash(zig):return hashlib.sha256((zig.parent/'lib/std/enums.zig').read_bytes()).hexdigest()
MAX_USIZE=(1<<64)-1
def spec(kind=0,cap=8,start=0,prefix=0,base=0,width=8,binding=0,finish=1,api=0,fill=91,alignment=2,present=0,precision=None,value=0,tag=1,letter_case=1):
 return '|'.join(map(str,(kind,cap,start,prefix,base,width,binding,finish,api,fill,alignment,present,'-' if precision is None else precision,value&MAX_USIZE,tag,letter_case)))
def initial_end(kind,cap,start,prefix):return (start if kind==0 and start<cap else 0)+prefix

def fields(part):
 status,metadata,buffer,pending,unused,inputs,contents=part.split('|');m=list(map(int,metadata.split(':')));assert len(m)==6
 payload,headers,options,elements,shape=inputs.split('#');spans=tuple(tuple(map(int,h.split(','))) for h in headers.split(';'))
 opts=tuple(None if v=='-' else int(v) for v in options.split(':'));assert len(opts)==8
 return status,m,bytes.fromhex(buffer),bytes.fromhex(pending),bytes.fromhex(unused),(bytes.fromhex(payload),spans,opts,bytes.fromhex(elements),shape),bytes.fromhex(contents)

class ModelTrap(Exception):pass
class WriteFailed(Exception):pass
class ModelLimit(Exception):pass

def modeled(data):
 f=data.split('|');kind,cap,start,prefix,base,width,binding,finish,api,fill,alignment,present=map(int,f[:12]);precision=None if f[12]=='-' else int(f[12]);raw,tag,letter_case=map(int,f[13:])
 end=initial_end(kind,cap,start,prefix);pos=start if kind else 0;mode=kind;wire=bytearray();calls=0
 buffer=bytearray((i*17+165)&255 for i in range(cap));begin=end-prefix;buffer[begin:end]=bytes((i*31+7)&255 for i in range(prefix))
 payload=raw.to_bytes(8,'little')+bytes((i*23+fill)&255 for i in range(256));spans=((0,8),(10,api));opts=(precision,width if present else None,alignment,fill,base,letter_case,tag,api)
 contents=bytearray((i*37+19)&255 for i in range(32)) if kind and not binding else bytearray()
 data_bytes=payload[10:10+api];typed_bytes=b'\0' if tag==3 else raw.to_bytes(8,'little')+bytes([base])+data_bytes;shape=('record','alias','optional','none','union','error')[tag];entered=completed=0
 def state(status):
  return status,[pos+end,cap-end,end,end,0 if not kind or binding==2 else 1,0 if not kind else (3 if binding==1 else 2)],bytes(buffer),bytes(buffer[:end]),bytes(buffer[end:]),(payload,spans,opts,typed_bytes,f'{shape}:{entered}:{completed}'),bytes(contents)
 def output(b):
  nonlocal pos
  if pos+len(b)>4096 or len(wire)+len(b)>4096:raise ModelLimit()
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
  nonlocal end,calls
  index=0
  while index<len(b):
   calls+=1
   if calls>128:raise ModelLimit()
   left=b[index:]
   if len(left)<=cap-end:copy(left);return
   if not kind:copy(left[:cap-end]);raise WriteFailed()
   if not prepare_file():continue
   pending=bytes(buffer[:end]);emitted=(pending if pending else left) if kind==1 and not binding else pending+left
   n=len(emitted);output(emitted)
   if n<end:buffer[:end-n]=buffer[n:end];end-=n
   else:index+=n-end;end=0
 def splat_all(n):
  nonlocal end,calls
  pattern=bytes([fill])
  while n:
   calls+=1
   if calls>128:raise ModelLimit()
   if n>MAX_USIZE-end:raise ModelTrap('integer overflow')
   if n<=cap-end:copy(pattern*n);return
   if not kind:copy(pattern*(cap-end));raise WriteFailed()
   segments=[bytes(buffer[:end])] if end else []
   if n==1:segments.append(pattern)
   else:
    capacity=cap-end if cap-end>=64 else 64;k=min(n,capacity);scratch=pattern*k
    if cap-end>=64:buffer[end:end+k]=scratch
    segments.append(scratch);remaining=n-k
    while remaining>capacity and len(segments)<16:segments.append(scratch);remaining-=capacity
    if remaining and len(segments)<16:segments.append(pattern*remaining)
   if not prepare_file():continue
   emitted=segments[0] if kind==1 and not binding else b''.join(segments)
   written=len(emitted);output(emitted)
   if written<end:buffer[:end-written]=buffer[written:end];end-=written
   else:n-=written-end;end=0
 def aligned(source):
  effective=width if present else len(source);padding=max(0,effective-len(source))
  if padding==0:write_all(source)
  elif alignment==0:write_all(source);splat_all(padding)
  elif alignment==1:
   left=padding//2
   if padding==MAX_USIZE:raise ModelTrap('integer overflow')
   right=(padding+1)//2;splat_all(left);write_all(source);splat_all(right)
  else:splat_all(padding);write_all(source)
 def vectors(parts):
  nonlocal end,calls
  remaining=list(parts)
  while remaining:
   calls+=1
   if calls>128:raise ModelLimit()
   data=b''.join(remaining)
   if len(data)<=cap-end:copy(data);return
   if not kind:copy(data[:cap-end]);raise WriteFailed()
   if not prepare_file():continue
   segments=([bytes(buffer[:end])] if end else [])+[b for b in remaining if b]
   emitted=segments[0] if kind==1 and not binding else b''.join(segments)
   count=len(emitted);output(emitted)
   if count<end:buffer[:end-count]=buffer[count:end];end-=count;continue
   count-=end;end=0
   while remaining and count>=len(remaining[0]):count-=len(remaining.pop(0))
   if remaining and count:remaining[0]=remaining[0][count:]
 def emit():
  nonlocal entered,completed
  if tag==3:aligned(b'null');return
  entered+=1
  if base==1:raise WriteFailed()
  write_all(b'custom(');completed=1
  if base==2:raise WriteFailed()
  write_all(str((raw&255)-128).encode());completed=2
  write_all(b':');completed=3
  write_all(data_bytes);completed=4
  if base==3:raise WriteFailed()
  write_all(b')');completed=5
 states=[state('setup'),state('ready')];status='ok'
 try:
  emit()
 except ModelTrap as e:return states,('write',str(e),state('write')),bytes(wire)
 except WriteFailed:status='WriteFailed'
 states.append(state(status))
 if cap:buffer[0]^=fill
 states.append(state('caller'));status='skip'
 if finish:
  status='ok'
  if kind and end:
   try:
    if not prepare_file():assert prepare_file()
    output(bytes(buffer[:end]));end=0
   except WriteFailed:status='WriteFailed'
 states.append(state(status));return states,None,bytes(wire)

def states():
 for kind,cap,start in itertools.product(range(3),(0,1,8,65),(0,3)):
  begin=initial_end(kind,cap,start,0)
  for prefix in sorted({0,cap-begin}):
   for binding in ((0,) if kind==0 else (0,1,2)):
    yield kind,cap,start,prefix,binding

def candidates():
 for tag,value,stop,cap,kind in itertools.product(range(6),(0,127,128,255,MAX_USIZE),range(4),(0,1,7,8,16,32),range(3)):
  yield 'carriers-and-stops',spec(tag=tag,value=value,base=stop,cap=cap,kind=kind,api=value%17)
 for kind,cap,start,prefix,binding in states():
  for tag,stop in itertools.product(range(6),range(4)):
   yield 'write-order-and-failure',spec(kind=kind,cap=cap,start=start,prefix=prefix,binding=binding,tag=tag,base=stop,value=255,api=16)
 for tag,alignment,width,precision,depth in itertools.product(range(6),range(3),(0,1,8,24),(None,0,MAX_USIZE),(0,1,MAX_USIZE)):
  yield 'options-and-depth',spec(tag=tag,value=42,base=0,cap=65,api=3,alignment=alignment,width=width,present=1,precision=precision,letter_case=depth,fill=255)
 for tag,stop,cap in itertools.product(range(6),range(4),range(40)):
  yield 'every-capacity',spec(cap=cap,tag=tag,value=0,base=stop,api=16,letter_case=0,fill=0)
 # All these options are ignored by a present formatter, even maximal usize.
 for tag in (0,1,2,4,5):
  yield 'maximal-ignored-options',spec(tag=tag,width=MAX_USIZE,present=1,precision=MAX_USIZE,letter_case=0)

def corpus():
 seen=set();rows=[]
 for group,data in candidates():
  if data in seen:continue
  seen.add(data)
  assert modeled(data)[1] is None;rows.append((group,data))
 return rows

def controls():
 contexts=((0,0,0,0,0),(0,8,0,8,0),(1,0,3,0,2),(2,8,0,8,2))
 rows=[]
 for context,tag,stop in itertools.product(contexts,range(6),range(4)):
  kind,cap,start,prefix,binding=context
  data=spec(kind=kind,cap=cap,start=start,prefix=prefix,binding=binding,tag=tag,base=stop,value=255,api=16,width=MAX_USIZE,present=int(tag!=3),precision=MAX_USIZE)
  rows.append(('early-failure-'+str(len(rows)),data,None))
 for context,alignment in itertools.product(contexts,range(3)):
  kind,cap,start,prefix,binding=context
  data=spec(kind=kind,cap=cap,start=start,prefix=prefix,binding=binding,tag=3,present=1,width=MAX_USIZE,alignment=alignment)
  try:trap=modeled(data)[1]
  except ModelLimit:continue
  rows.append(('absent-huge-width-'+str(len(rows)),data,trap[1] if trap else None))
 return rows

def snapshot_checks(line,data):
 parts=line.decode().split('~');assert len(parts)==6
 states=[fields(part) for part in parts[:-1]];model,trap,wire=modeled(data);assert trap is None and states==model,'independent custom/call/write boundaries/argument state differs'
 f=list(map(int,data.split('|')[:12]));assert parts[-1]==('-1:'+wire.hex() if f[0] and f[6]==1 else '-3:')

def classify(native,translated,name,data,category,paths):
 if native.returncode==0:
  assert category is None and translated.returncode==0 and native.stdout==translated.stdout and native.stdout and not native.stderr+translated.stderr
  snapshot_checks(native.stdout.strip(),data);return 'return',native.stdout
 for result in (native,translated):
  checked_trap(result,name,category)
  messages=[m.group(1) for line in result.stderr.decode().splitlines() if (m:=re.fullmatch(r'(?:thread \d+ |V )?panic:\s*(.*)',line.strip()))];assert messages==[category]
 states=[p.read_bytes() for p in paths];assert states[0] and states[0]==states[1]
 _,trap,_=modeled(data);assert trap is not None and trap[1]==category and fields(states[0].decode())==trap[2],'value dispatch failure state differs'
 return 'trap',category.encode()+b'\0'+states[0]+b'\n'

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source',type=Path);parser.add_argument('zig',type=Path);parser.add_argument('v',type=Path)
    parser.add_argument('--target',default='aarch64-macos.14.0');parser.add_argument('--v-prod',action='store_true');parser.add_argument('--workdir',type=Path);parser.add_argument('--timeout',type=int,default=600)
    args=parser.parse_args()
    if args.timeout<=0:parser.error('--timeout must be positive')
    source=args.source.resolve()/'src';zig=args.zig.resolve();v=args.v.resolve()
    if enum_library_hash(zig)!=ENUM_LIBRARY_SHA256 or float_library_hashes(zig)!=FLOAT_LIBRARIES or value_library_hashes(zig)!=VALUE_LIBRARIES or library_hashes(zig)!=EXTRA_LIBRARIES or tree_hash(source)!=PINNED_SOURCE_SHA256 or integer_library_hashes(zig)!=INTEGER_LIBRARIES or format_library_hash(zig)!=FORMAT_LIBRARY_SHA256 or io_library_hash(zig)!=IO_LIBRARY_SHA256 or stdlib_hash(zig)!=PINNED_STDLIB_SHA256 or path_library_hashes(zig)!=PATH_LIBRARIES or encoder_library_hashes(zig)!=ENCODER_LIBRARIES:parser.error('Source/compiler library differs from pins')
    repo=Path(__file__).resolve().parent.parent;probe=repo/'zigimg/reference_probes/writer_value_custom';mode='ReleaseSafe' if args.v_prod else 'Debug'
    with work_directory(args.workdir,'witty-writer-value-custom-') as root:
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
        helpers={name:hashlib.sha256((repo/'zigimg'/name).read_bytes()).hexdigest() for name in ('verify_jpeg_contracts_reference.py','verify_tiff_decode_reference.py','verify_stream_guards_reference.py','verify_image_open_reference.py','verify_image_tty_reference.py','verify_format_parser_reference.py','verify_writer_float_reference.py','verify_float_render_reference.py','verify_float_decimal_reference.py')}
        (root/'provenance.json').write_text(json.dumps(dict(enum_library_sha256=ENUM_LIBRARY_SHA256,source_sha256=PINNED_SOURCE_SHA256,stdlib_sha256=PINNED_STDLIB_SHA256,io_library_sha256=IO_LIBRARY_SHA256,format_library_sha256=FORMAT_LIBRARY_SHA256,float_libraries=FLOAT_LIBRARIES,value_libraries=VALUE_LIBRARIES,extra_libraries=EXTRA_LIBRARIES,integer_libraries=INTEGER_LIBRARIES,path_libraries=PATH_LIBRARIES,encoder_libraries=ENCODER_LIBRARIES,versions=versions,target=args.target,zig_mode=mode,v_prod=args.v_prod,implementation_sha256=impl,runner_sha256=runner_hash,fixtures=fixtures,helper_sha256=helpers,shared_fixture_sha256=shared_hash),indent=2)+'\n')
        print(f'Building custom-value-dispatch operations: Source {mode}, V {"production" if args.v_prod else "ordinary"}',flush=True)
        proof.run([str(zig),'build-exe','-target',args.target,'-lc','-I',str(root),'-O',mode,'--global-cache-dir',str(root.parent/'zig-global'),'--cache-dir',str(root/'zig-cache'),'-femit-bin='+str(root/'native'),str(root/'reference.zig'),str(root/'fixture_shims.c')],'build-source',env=env,timeout=args.timeout)
        proof.run([str(v),'-enable-globals',*(['-prod'] if args.v_prod else []),'-path',f'{repo}|@vlib|@vmodules','-o',str(root/'translated'),str(root/'main.v')],'build-v',env=env,timeout=args.timeout)
        rows=corpus();path=root/'corpus.txt';path.write_text('\n'.join(data for _,data in rows)+'\n');inputs={'corpus.txt':hashlib.sha256(path.read_bytes()).hexdigest()};(root/'input_sha256.json').write_text(json.dumps(inputs,indent=2)+'\n')
        outputs=[]
        for exe in ('native','translated'):
            result=proof.run([str(root/exe),str(path)],'returning-'+exe,env=env,timeout=args.timeout)
            if result.stderr or len(result.stdout.splitlines())!=len(rows):raise AssertionError('invalid returning output')
            outputs.append(result.stdout.splitlines())
        for i,((group,data),native,translated) in enumerate(zip(rows,*outputs)):
            if native!=translated:raise AssertionError(f'{i}/{group}: custom-value-dispatch record differs; see retained proof')
            snapshot_checks(native,data)
        digest=hashlib.sha256(b'\n'.join(outputs[0])).hexdigest()
        if EXPECTED_ROWS is not None and (len(rows)!=EXPECTED_ROWS or digest!=EXPECTED_SHA256):raise AssertionError('returning golden changed')
        returns=hashlib.sha256();states=hashlib.sha256();return_count=0;trap_count=0
        print(f'{len(rows)} returning custom-value-dispatch records match; checking failure controls',flush=True)
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
        if enum_library_hash(zig)!=ENUM_LIBRARY_SHA256 or float_library_hashes(zig)!=FLOAT_LIBRARIES or value_library_hashes(zig)!=VALUE_LIBRARIES or library_hashes(zig)!=EXTRA_LIBRARIES or tree_hash(source)!=PINNED_SOURCE_SHA256 or tree_hash(root/'src')!=PINNED_SOURCE_SHA256 or integer_library_hashes(zig)!=INTEGER_LIBRARIES or format_library_hash(zig)!=FORMAT_LIBRARY_SHA256 or io_library_hash(zig)!=IO_LIBRARY_SHA256 or stdlib_hash(zig)!=PINNED_STDLIB_SHA256 or path_library_hashes(zig)!=PATH_LIBRARIES or encoder_library_hashes(zig)!=ENCODER_LIBRARIES or implementation_hashes(repo)!=impl or hashlib.sha256(Path(__file__).read_bytes()).hexdigest()!=runner_hash:raise AssertionError('dependency/implementation/runner changed')
        for name,pin in fixtures.items():
            if any(hashlib.sha256((base/name).read_bytes()).hexdigest()!=pin for base in (root,probe)):raise AssertionError('fixture changed')
        for name,pin in inputs.items():
            if hashlib.sha256((root/name).read_bytes()).hexdigest()!=pin:raise AssertionError('input changed')
        for name,pin in helpers.items():
            if hashlib.sha256((repo/'zigimg'/name).read_bytes()).hexdigest()!=pin:raise AssertionError('helper changed')
        for directory,pin in shared_hash.items():
            if any(hashlib.sha256(p.read_bytes()).hexdigest()!=pin for p in (root/directory/'fixture_shims.h',repo/'zigimg/reference_probes'/directory/'fixture_shims.h')):raise AssertionError('shared fixture changed')
        if list(root.glob('*.owned*')):raise AssertionError('owned paths survived')
        summary=dict(write_failed=sum(fields(line.decode().split('~')[2])[0]=='WriteFailed' for line in outputs[0]),returning_records=len(rows),primary_calls=len(rows),stops=dict(Counter(int(data.split('|')[4]) for _,data in rows)),types=dict(Counter(int(data.split('|')[14]) for _,data in rows)),returning_groups=dict(Counter(group for group,_ in rows)),output_sha256=digest,return_controls=return_count,control_sha256=returns.hexdigest(),paired_traps=trap_count,state_sha256=states.hexdigest(),zig_mode=mode,v_prod=args.v_prod)
        (root/'summary.json').write_text(json.dumps(summary,indent=2)+'\n');print(json.dumps(summary),flush=True)

if __name__=='__main__':main()
