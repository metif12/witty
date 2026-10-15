"""Compare text formatting, byte padding, Unicode, hex, Base64 and exact failure state."""
import argparse
from collections import Counter
import base64,hashlib,itertools,json,os,re,shutil
from pathlib import Path
from verify_jpeg_contracts_reference import implementation_hashes
from verify_tiff_decode_reference import ProofLog,tree_hash,work_directory,PINNED_SOURCE_SHA256,checked_trap
from verify_stream_guards_reference import stdlib_hash,PINNED_STDLIB_SHA256
from verify_image_open_reference import PATH_LIBRARIES,path_library_hashes
from verify_image_tty_reference import ENCODER_LIBRARIES,encoder_library_hashes





EXPECTED_ROWS = 36852
EXPECTED_SHA256 = '58e0014715351e78da9be5515aa662042b5b5427cca2615a171a5f707e8b18f1'
EXPECTED_CONTROLS = 512
EXPECTED_CONTROL_SHA256 = 'f44ede993d6d5eda6c01e71998feb8bc24724e3c5c68cccbb7b8086bc16d787f'
EXPECTED_TRAPS = 188
EXPECTED_STATE_SHA256 = 'e197512268320b43d73ad4686c4deabf926ba1bb794865ef14e62cc9d977937a'
IO_LIBRARY_SHA256='09df1114cba703f824337f20489c7df5294db9f07961d4ac46abbbbf9c7ecaef'
def io_library_hash(zig):return hashlib.sha256((zig.parent/'lib/std/Io.zig').read_bytes()).hexdigest()
FORMAT_LIBRARY_SHA256='667eac6285e472b5516ebebf8a6e69959a171be4fb97cac1e56419ffec20d500'
def format_library_hash(zig):return hashlib.sha256((zig.parent/'lib/std/fmt.zig').read_bytes()).hexdigest()
TEXT_LIBRARIES={'unicode.zig':'541dbd778c2765ea7c6479a873c234f32ad5ca4b7a96252410bea075a71c8348','base64.zig':'f506bb85c053a0bda914258c3c295107e9987c48674c2addf57ffecd5dddca8d'}
def text_library_hashes(zig):return {n:hashlib.sha256((zig.parent/'lib/std'/n).read_bytes()).hexdigest() for n in TEXT_LIBRARIES}
MAX_USIZE=(1<<64)-1
def spec(kind=0,cap=8,start=0,prefix=0,length=3,width=8,binding=0,finish=0,api=0,fill=91,alignment=0,present=1,precision=None,codepoint=65,letter_case=0):
 return '|'.join(map(str,(kind,cap,start,prefix,length,width,binding,finish,api,fill,alignment,present,'-' if precision is None else precision,codepoint,letter_case)))
def initial_end(kind,cap,start,prefix):return (start if kind==0 and start<cap else 0)+prefix

def fields(part):
 status,metadata,buffer,pending,unused,inputs,contents=part.split('|');m=list(map(int,metadata.split(':')));assert len(m)==6
 payload,headers,options=inputs.split('#');spans=tuple(tuple(map(int,h.split(','))) for h in headers.split(';')) if headers else ()
 opts=tuple(None if v=='-' else int(v) for v in options.split(':'));assert len(opts)==4
 return status,m,bytes.fromhex(buffer),bytes.fromhex(pending),bytes.fromhex(unused),(bytes.fromhex(payload),spans,opts),bytes.fromhex(contents)

class ModelTrap(Exception):pass
class WriteFailed(Exception):pass
class ModelLimit(Exception):pass

def modeled(data):
 f=data.split('|');kind,cap,start,prefix,length,width,binding,finish,api,fill,alignment,present=map(int,f[:12]);precision=None if f[12]=='-' else int(f[12]);codepoint,letter_case=map(int,f[13:15])
 end=initial_end(kind,cap,start,prefix);pos=start if kind else 0;mode=kind;wire=bytearray();calls=0
 buffer=bytearray((i*17+165)&255 for i in range(cap));begin=end-prefix;buffer[begin:end]=bytes((i*31+7)&255 for i in range(prefix))
 payload=bytes((i*23+fill)&255 for i in range(256));spans=((2,length),);source=payload[2:2+length];opts=(precision,width if present else None,alignment,fill)
 source=bytes([fill]) if api==0 else source
 effective=width if present else len(source)
 contents=bytearray((i*37+19)&255 for i in range(32)) if kind and not binding else bytearray()
 def state(status):
  return status,[pos+end,cap-end,end,end,0 if not kind or binding==2 else 1,0 if not kind else (3 if binding==1 else 2)],bytes(buffer),bytes(buffer[:end]),bytes(buffer[end:]),(payload,spans,opts),bytes(contents)
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
   if calls>2048:raise ModelLimit()
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
   if calls>2048:raise ModelLimit()
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
 states=[state('setup'),state('ready')];status='ok'
 padding=max(0,effective-len(source))
 try:
  if api in (0,1):
   if padding==0:write_all(source)
   elif alignment==0:write_all(source);splat_all(padding)
   elif alignment==1:
    left=padding//2
    if padding==MAX_USIZE:raise ModelTrap('integer overflow')
    right=(padding+1)//2;splat_all(left);write_all(source);splat_all(right)
   else:splat_all(padding);write_all(source)
  elif api==2:
   if codepoint>0x1fffff:raise ModelTrap('integer does not fit in destination type')
   c=0xfffd if codepoint>0x10ffff or 0xd800<=codepoint<=0xdfff else codepoint
   write_all(chr(c).encode('utf-8'))
  elif api==3:
   encoded=source.hex().upper() if letter_case else source.hex()
   for char in encoded:write_all(char.encode('ascii'))
  elif api==4:
   for offset in range(0,len(source),3):write_all(base64.b64encode(source[offset:offset+3]))
  else:raise AssertionError('unknown api')
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
 for kind,cap,start in itertools.product(range(3),(0,1,2,3,4,8,65),(0,3)):
  begin=initial_end(kind,cap,start,0)
  for prefix in sorted({0,cap-begin}):
   for binding in ((0,) if kind==0 else (0,1,2)):
    yield kind,cap,start,prefix,binding

def corpus():
 rows=[];seen=set()
 for kind,cap,start,prefix,binding in states():
  common=dict(kind=kind,cap=cap,start=start,prefix=prefix,binding=binding,finish=1)
  for api in range(5):
   lengths=(1,) if api==0 else ((0,) if api==2 else (0,1,2,3,4,5,6,17,64))
   for length in lengths:
    if api<2:
     for alignment,width in itertools.product(range(3),(0,length,length+1,length+4)):
      rows.append(('ascii-writes',spec(**common,api=api,length=length,width=width,alignment=alignment)))
    elif api==2:
     for c in (0,0x7f,0x80,0x7ff,0x800,0xd7ff,0xd800,0xdfff,0xe000,0xffff,0x10000,0x10ffff,0x110000,0x1fffff):
      rows.append(('unicode-writes',spec(**common,api=api,length=length,codepoint=c)))
    elif api==3:
     for letter_case in range(2):rows.append(('hex-writes',spec(**common,api=api,length=length,letter_case=letter_case)))
    else:rows.append(('base64-writes',spec(**common,api=api,length=length)))
 for byte,api in itertools.product(range(256),(0,1,3,4)):
  for kind in range(3):rows.append(('every-byte',spec(kind=kind,cap=8,api=api,length=3 if api==4 else 1,fill=byte,finish=1,width=4,alignment=byte%3,letter_case=byte%2)))
 for c in range(0xd800,0xe000):
  for cap in (2,4):rows.append(('every-surrogate',spec(cap=cap,api=2,length=0,codepoint=c,finish=1)))
 for c in sorted({*(range(0,0x110000,4093)),*(0x10000+(i<<12)+j for i in range(256) for j in (0,0xfff)),0x1fffff}):
  rows.append(('unicode-plane-samples',spec(cap=8,api=2,length=0,codepoint=c,finish=1)))
 for api,alignment,present,precision in itertools.product((0,1),range(3),range(2),(None,0,MAX_USIZE)):
  rows.append(('ascii-options',spec(api=api,length=1,width=5,alignment=alignment,present=present,precision=precision,finish=1)))
 for api,length,cap in itertools.product((1,3,4),(63,64,65,127,128,129,253,254),(0,1,3,8,65)):
  rows.append(('long-input',spec(kind=2,cap=cap,api=api,length=length,width=3,finish=1)))
 result=[]
 for group,data in rows:
  if data in seen:continue
  seen.add(data)
  try:trap=modeled(data)[1]
  except ModelLimit:continue
  assert trap is None
  result.append((group,data))
 return result

def controls():
 rows=[];seen=set()
 for kind,cap,start,prefix,binding in states():
  if cap not in (0,8):continue
  for api,alignment,present,length in itertools.product((0,1),range(3),range(2),(0,1)):
   if api==0 and length!=1:continue
   data=spec(kind,cap,start,prefix,length,MAX_USIZE,binding,1,api,alignment=alignment,present=present,precision=MAX_USIZE)
   if data in seen:continue
   seen.add(data)
   try:trap=modeled(data)[1]
   except ModelLimit:continue
   rows.append((f'boundary-{len(rows)}',data,trap[1] if trap else None))
  for c in (0x200000,0xffffffff):
   data=spec(kind=kind,cap=cap,start=start,prefix=prefix,binding=binding,finish=1,api=2,length=0,codepoint=c)
   rows.append((f'u21-{len(rows)}',data,'integer does not fit in destination type'))
 return rows

def snapshot_checks(line,data):
 parts=line.decode().split('~');assert len(parts)==6
 states=[fields(part) for part in parts[:-1]];model,trap,wire=modeled(data);assert trap is None and states==model,'independent text encoding/write order/options/input state differs'
 f=list(map(int,data.split('|')[:12]));assert parts[-1]==('-1:'+wire.hex() if f[0] and f[6]==1 else '-3:')

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
    if tree_hash(source)!=PINNED_SOURCE_SHA256 or text_library_hashes(zig)!=TEXT_LIBRARIES or format_library_hash(zig)!=FORMAT_LIBRARY_SHA256 or io_library_hash(zig)!=IO_LIBRARY_SHA256 or stdlib_hash(zig)!=PINNED_STDLIB_SHA256 or path_library_hashes(zig)!=PATH_LIBRARIES or encoder_library_hashes(zig)!=ENCODER_LIBRARIES:parser.error('Source/compiler library differs from pins')
    repo=Path(__file__).resolve().parent.parent;probe=repo/'zigimg/reference_probes/writer_text';mode='ReleaseSafe' if args.v_prod else 'Debug'
    with work_directory(args.workdir,'witty-writer-text-') as root:
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
        (root/'provenance.json').write_text(json.dumps(dict(source_sha256=PINNED_SOURCE_SHA256,stdlib_sha256=PINNED_STDLIB_SHA256,io_library_sha256=IO_LIBRARY_SHA256,format_library_sha256=FORMAT_LIBRARY_SHA256,text_libraries=TEXT_LIBRARIES,path_libraries=PATH_LIBRARIES,encoder_libraries=ENCODER_LIBRARIES,versions=versions,target=args.target,zig_mode=mode,v_prod=args.v_prod,implementation_sha256=impl,runner_sha256=runner_hash,fixtures=fixtures,helper_sha256=helpers,shared_fixture_sha256=shared_hash),indent=2)+'\n')
        print(f'Building text-formatting operations: Source {mode}, V {"production" if args.v_prod else "ordinary"}',flush=True)
        proof.run([str(zig),'build-exe','-target',args.target,'-lc','-I',str(root),'-O',mode,'--global-cache-dir',str(root.parent/'zig-global'),'--cache-dir',str(root/'zig-cache'),'-femit-bin='+str(root/'native'),str(root/'reference.zig'),str(root/'fixture_shims.c')],'build-source',env=env,timeout=args.timeout)
        proof.run([str(v),'-enable-globals',*(['-prod'] if args.v_prod else []),'-path',f'{repo}|@vlib|@vmodules','-o',str(root/'translated'),str(root/'main.v')],'build-v',env=env,timeout=args.timeout)
        rows=corpus();path=root/'corpus.txt';path.write_text('\n'.join(data for _,data in rows)+'\n');inputs={'corpus.txt':hashlib.sha256(path.read_bytes()).hexdigest()};(root/'input_sha256.json').write_text(json.dumps(inputs,indent=2)+'\n')
        outputs=[]
        for exe in ('native','translated'):
            result=proof.run([str(root/exe),str(path)],'returning-'+exe,env=env,timeout=args.timeout)
            if result.stderr or len(result.stdout.splitlines())!=len(rows):raise AssertionError('invalid returning output')
            outputs.append(result.stdout.splitlines())
        for i,((group,data),native,translated) in enumerate(zip(rows,*outputs)):
            if native!=translated:raise AssertionError(f'{i}/{group}: text-formatting record differs; see retained proof')
            snapshot_checks(native,data)
        digest=hashlib.sha256(b'\n'.join(outputs[0])).hexdigest()
        if EXPECTED_ROWS is not None and (len(rows)!=EXPECTED_ROWS or digest!=EXPECTED_SHA256):raise AssertionError('returning golden changed')
        returns=hashlib.sha256();states=hashlib.sha256();return_count=0;trap_count=0
        print(f'{len(rows)} returning text-formatting records match; checking failure controls',flush=True)
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
        if tree_hash(source)!=PINNED_SOURCE_SHA256 or tree_hash(root/'src')!=PINNED_SOURCE_SHA256 or text_library_hashes(zig)!=TEXT_LIBRARIES or format_library_hash(zig)!=FORMAT_LIBRARY_SHA256 or io_library_hash(zig)!=IO_LIBRARY_SHA256 or stdlib_hash(zig)!=PINNED_STDLIB_SHA256 or path_library_hashes(zig)!=PATH_LIBRARIES or encoder_library_hashes(zig)!=ENCODER_LIBRARIES or implementation_hashes(repo)!=impl or hashlib.sha256(Path(__file__).read_bytes()).hexdigest()!=runner_hash:raise AssertionError('dependency/implementation/runner changed')
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
