"""Compare hexadecimal floats, ties-to-even, special values and exact writer failures."""
import argparse
from collections import Counter
import hashlib,itertools,json,os,re,shutil
from pathlib import Path
from verify_jpeg_contracts_reference import implementation_hashes
from verify_tiff_decode_reference import ProofLog,tree_hash,work_directory,PINNED_SOURCE_SHA256,checked_trap
from verify_stream_guards_reference import stdlib_hash,PINNED_STDLIB_SHA256
from verify_image_open_reference import PATH_LIBRARIES,path_library_hashes
from verify_image_tty_reference import ENCODER_LIBRARIES,encoder_library_hashes





EXPECTED_ROWS = 18492
EXPECTED_SHA256 = '40940467b0c4025e61f4905771c4810d420ff81bf5835fbdf4d459bd9596b70d'
EXPECTED_CONTROLS = 288
EXPECTED_CONTROL_SHA256 = '03acfd647a36adc653242af869f0edcde560e6e3c23c7ebc8022f2782154629f'
EXPECTED_TRAPS = 312
EXPECTED_STATE_SHA256 = '5a7f1e06714fe2444cde2d09c8e808786056f5517070e3cb918f351fcc581424'
IO_LIBRARY_SHA256='09df1114cba703f824337f20489c7df5294db9f07961d4ac46abbbbf9c7ecaef'
def io_library_hash(zig):return hashlib.sha256((zig.parent/'lib/std/Io.zig').read_bytes()).hexdigest()
FORMAT_LIBRARY_SHA256='667eac6285e472b5516ebebf8a6e69959a171be4fb97cac1e56419ffec20d500'
def format_library_hash(zig):return hashlib.sha256((zig.parent/'lib/std/fmt.zig').read_bytes()).hexdigest()
INTEGER_LIBRARIES={'math.zig':'65645001357d5f78cbf646485e009a048b828680bb1b47fb3de0fd8617d91af1','meta.zig':'3cf9b3eb6c6b6f9b101f06f0562a4071c81a5fbc6de63d8197e837e10cedfc40'}
def integer_library_hashes(zig):return {n:hashlib.sha256((zig.parent/'lib/std'/n).read_bytes()).hexdigest() for n in INTEGER_LIBRARIES}
TIME_LIBRARY_SHA256='b8b686d5ecaa81cb25b3234229a85cf0ff99c5bd6153283b272fe586c558d7f1'
def time_library_hash(zig):return hashlib.sha256((zig.parent/'lib/std/time.zig').read_bytes()).hexdigest()
MAX_USIZE=(1<<64)-1
BITS=(32,64,32,64)
FLOAT_LIBRARIES={'math/float.zig':'89498b527221904e328326ab55b8c0755977ac4104e2c3e814e3b0c4c73356d3','math/isnan.zig':'9dee284f974e89bcfc81fd90d45c496663fce6c2567e636aa8ca26598b74524e','math/isinf.zig':'9252e2a7668feb48b0d87ff5b5e40a904a62e61838eb187a979f2f390612b004','math/signbit.zig':'7d9fdef881d5e3dec3462602542a2d25a20b1b638c55b7514f2e08a0a631a9e2'}
def float_library_hashes(zig):return {n:hashlib.sha256((zig.parent/'lib/std'/n).read_bytes()).hexdigest() for n in FLOAT_LIBRARIES}
def spec(kind=0,cap=8,start=0,prefix=0,binding=0,finish=1,api=1,fill=91,alignment=0,width=0,present=1,precision=None,raw=0,tag=1,case=0,mode=3):
 return '|'.join(map(str,(kind,cap,start,prefix,binding,finish,api,fill,alignment,width,present,'-' if precision is None else precision,raw&((1<<BITS[tag])-1),tag,case,mode)))
def initial_end(kind,cap,start,prefix):return (start if kind==0 and start<cap else 0)+prefix

def fields(part):
 status,metadata,buffer,pending,unused,inputs,contents=part.split('|');m=list(map(int,metadata.split(':')));assert len(m)==6
 payload,headers,options=inputs.split('#');spans=tuple(tuple(map(int,h.split(','))) for h in headers.split(';')) if headers else ()
 opts=tuple(None if v=='-' else int(v) for v in options.split(':'));assert len(opts)==7
 return status,m,bytes.fromhex(buffer),bytes.fromhex(pending),bytes.fromhex(unused),(bytes.fromhex(payload),spans,opts),bytes.fromhex(contents)

class ModelTrap(Exception):pass
class WriteFailed(Exception):pass
class ModelLimit(Exception):pass

def modeled(data):
 f=data.split('|');kind,cap,start,prefix,binding,finish,api,fill,alignment,width,present=map(int,f[:11]);precision=None if f[11]=='-' else int(f[11]);raw,tag,case,number_mode=map(int,f[12:])
 end=initial_end(kind,cap,start,prefix);pos=start if kind else 0;mode=kind;wire=bytearray();calls=0
 buffer=bytearray((i*17+165)&255 for i in range(cap));begin=end-prefix;buffer[begin:end]=bytes((i*31+7)&255 for i in range(prefix))
 payload=raw.to_bytes(8,'little');spans=((0,8),);opts=(precision,width if present else None,alignment,fill,tag,case,number_mode)
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
   if calls>128:raise ModelLimit()
   left=b[index:]
   if len(left)<=cap-end:copy(left);return
   if not kind:copy(left[:cap-end]);raise WriteFailed()
   if not prepare_file():continue
   pending=bytes(buffer[:end]);emitted=(pending if pending else left) if kind==1 and not binding else pending+left
   n=len(emitted);output(emitted)
   if n<end:buffer[:end-n]=buffer[n:end];end-=n
   else:index+=n-end;end=0
 def splat_all(n,byte=None):
  nonlocal end,calls
  pattern=bytes([fill if byte is None else byte])
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
 states=[state('setup'),state('ready')];status='ok'
 try:
  if api==1 and number_mode!=3:raise ModelTrap('TODO' if number_mode in (1,2) else 'reached unreachable code')
  pieces=float_pieces(raw,tag,case,precision)
  if api==0:
   for piece in pieces:
    if isinstance(piece,tuple):splat_all(piece[1],48)
    else:write_all(piece)
  else:
   source=bytearray()
   for piece in pieces:
    if isinstance(piece,tuple):
     n=piece[1]
     if n>MAX_USIZE-len(source):raise ModelTrap('integer overflow')
     if n>50-len(source):raise ModelTrap('attempt to unwrap error: WriteFailed')
     source.extend(b'0'*n)
    else:
     if len(piece)>50-len(source):raise ModelTrap('attempt to unwrap error: WriteFailed')
     source.extend(piece)
   source=bytes(source)
   effective=width if present else len(source);padding=max(0,effective-len(source))
   if padding==0:write_all(source)
   elif alignment==0:write_all(source);splat_all(padding)
   elif alignment==1:
    left=padding//2
    if padding==MAX_USIZE:raise ModelTrap('integer overflow')
    right=(padding+1)//2;splat_all(left);write_all(source);splat_all(right)
   else:splat_all(padding);write_all(source)
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

def float_pieces(raw,tag,case,precision):
 bits=BITS[tag];fractional=23 if bits==32 else 52;exponent_bits=bits-fractional-1
 fraction=raw&((1<<fractional)-1);exponent=(raw>>fractional)&((1<<exponent_bits)-1)
 pieces=[b'-'] if raw>>(bits-1) else []
 if exponent==(1<<exponent_bits)-1:
  word=b'nan' if fraction else b'inf';return pieces+[word.upper() if case else word]
 if not exponent and not fraction:
  pieces.append(b'0x0')
  if precision is None:pieces.append(b'.0')
  elif precision:pieces.extend((b'.',('zeros',precision)))
  return pieces+[b'p0']
 digits=(fractional+3)//4
 mantissa=(fraction|(1<<fractional) if exponent else fraction)<<(digits*4-fractional)
 exponent=max(1,exponent)
 if precision is not None and precision<digits:
  step=1<<((digits-precision)*4);q,r=divmod(mantissa,step)
  if 2*r>step or (2*r==step and q%2):q+=1
  mantissa=q*step
  if mantissa>=2<<(4*digits):mantissa//=2;exponent+=1
 text=f'{mantissa:0{digits+1}x}'.encode();text=text.upper() if case else text
 fraction=text[1:].rstrip(b'0')
 pieces.extend((b'0x',text[:1]))
 if (precision is not None and precision>0) or (precision is None and fraction):pieces.append(b'.')
 pieces.append(fraction)
 if precision is not None and precision>len(fraction):pieces.append(('zeros',precision-len(fraction)))
 return pieces+[b'p',str(exponent-((1<<(exponent_bits-1))-1)).encode()]

def states():
 for kind,cap,start in itertools.product(range(3),(0,1,8,50,65),(0,3)):
  begin=initial_end(kind,cap,start,0)
  for prefix in sorted({0,cap-begin}):
   for binding in ((0,) if kind==0 else (0,1,2)):yield kind,cap,start,prefix,binding

def boundaries(tag):
 bits=BITS[tag];f=23 if bits==32 else 52;e=bits-f-1;bias=(1<<(e-1))-1;mask=(1<<f)-1
 values={0,1,mask,1<<f,(1<<f)+1,bias<<f,(bias<<f)+(1<<(f-1)),((1<<e)-2)<<f,(((1<<e)-1)<<f)-1,((1<<e)-1)<<f,(((1<<e)-1)<<f)+1,(((1<<e)-1)<<f)+(1<<(f-1)),((bias+1)<<f)+(1<<(f-2))}
 return sorted(values|{n|(1<<(bits-1)) for n in values})

def candidates():
 rows=[]
 for tag,api,kind,cap in itertools.product(range(4),range(2),range(3),(0,1,8,50)):
  for raw in boundaries(tag):rows.append(('native-and-alias-boundaries',spec(tag=tag,api=api,kind=kind,cap=cap,raw=raw)))
 for tag in (0,1):
  bits=BITS[tag];f=23 if bits==32 else 52;e=bits-f-1
  for exponent,api in itertools.product(range(1<<e),range(2)):
   raw=(exponent<<f)|((exponent*0x9e3779b97f4a7c15)&((1<<f)-1))|((exponent%2)<<(bits-1))
   rows.append(('every-exponent',spec(tag=tag,api=api,kind=exponent%3,cap=50,raw=raw,case=exponent%2)))
 for tag in range(4):
  bits=BITS[tag];f=23 if bits==32 else 52;bias=(1<<(bits-f-2))-1
  for precision in range((f+3)//4):
   shift=f-4*precision
   if shift<=0:continue
   for q,delta,exponent,sign,api in itertools.product(sorted({0,1,3,(1<<(4*precision))-1}),(-1,0,1),(1,bias,2*bias),range(2),range(2)):
    fraction=(q<<shift)+(1<<(shift-1))+delta
    if not 0<=fraction<(1<<f):continue
    raw=(sign<<(bits-1))|(exponent<<f)|fraction
    rows.append(('rounding-ties-and-neighbors',spec(tag=tag,api=api,kind=q%3,cap=50,raw=raw,precision=precision,case=sign)))
 for kind,cap,start,prefix,binding in states():
  for api,index in itertools.product(range(2),(0,3,7,11)):
   tag=index%4;raw=boundaries(tag)[index]
   rows.append(('write-order-and-failure',spec(kind=kind,cap=cap,start=start,prefix=prefix,binding=binding,api=api,raw=raw,tag=tag,width=32,alignment=index%3,precision=None if index%2 else 3)))
 for tag,api,alignment,present,width,precision in itertools.product(range(4),range(2),range(3),range(2),(0,1,24,60),(None,0,1,5,13,40,44,45,46,47,48,49,50,63)):
  f=23 if BITS[tag]==32 else 52;bias=127 if f==23 else 1023
  rows.append(('precision-and-options',spec(tag=tag,api=api,raw=(bias<<f)+(1<<(f-1)),alignment=alignment,present=present,width=width,precision=precision,cap=65,kind=(width+alignment)%3,case=tag%2)))
 for fill,kind,alignment in itertools.product(range(256),range(3),range(3)):
  rows.append(('every-fill-byte',spec(kind=kind,tag=1,raw=0xbffa000000000000,fill=fill,alignment=alignment,width=32,cap=50,precision=3,case=fill%2)))
 for i in range(1024):
  tag=i%4;raw=((i*0x9e3779b97f4a7c15)^0xd6e8feb86659fd93)&((1<<BITS[tag])-1)
  rows.append(('seeded-bits',spec(tag=tag,api=i%2,raw=raw,cap=50,kind=i%3,precision=(None,0,5,13)[i%4],case=(i//4)%2)))
 return rows

def corpus():
 seen=set();result=[]
 for group,data in candidates():
  if data in seen:continue
  seen.add(data)
  try:trap=modeled(data)[1]
  except ModelLimit:continue
  if trap is None:result.append((group,data))
 return result

def controls():
 result=[];seen=set()
 def add(label,data):
  if data in seen:return
  seen.add(data)
  try:trap=modeled(data)[1]
  except ModelLimit:return
  if trap:assert modeled(data)[2]==b''
  result.append((f'{label}-{len(result)}',data,trap[1] if trap else None))
 contexts=((0,0,0,0,0),(0,65,0,3,0),(1,8,0,8,0),(1,8,3,8,1),(2,8,3,8,2))
 for (kind,cap,start,prefix,binding),mode,tag,case in itertools.product(contexts,(0,1,2,4),range(4),range(2)):
  add('mode',spec(kind=kind,cap=cap,start=start,prefix=prefix,binding=binding,mode=mode,tag=tag,case=case,raw=boundaries(tag)[-1],width=MAX_USIZE,precision=MAX_USIZE))
 for (kind,cap,start,prefix,binding),tag,api,precision,index in itertools.product((contexts[0],contexts[1],contexts[4]),(1,2),range(2),(44,45,46,47,48,49,50,MAX_USIZE),(0,1,4,11)):
  add('precision-boundary',spec(kind=kind,cap=cap,start=start,prefix=prefix,binding=binding,tag=tag,api=api,precision=precision,raw=boundaries(tag)[index],width=MAX_USIZE,present=0))
 for (kind,cap,start,prefix,binding),tag,alignment,present in itertools.product(contexts,(0,1),range(3),range(2)):
  add('maximum-width',spec(kind=kind,cap=cap,start=start,prefix=prefix,binding=binding,tag=tag,alignment=alignment,present=present,raw=boundaries(tag)[11],width=MAX_USIZE))
 return result

def snapshot_checks(line,data):
 parts=line.decode().split('~');assert len(parts)==6
 states=[fields(part) for part in parts[:-1]];model,trap,wire=modeled(data);assert trap is None and states==model,'independent float_hex representation/write boundaries/argument state state differs'
 f=list(map(int,data.split('|')[:11]));assert parts[-1]==('-1:'+wire.hex() if f[0] and f[4]==1 else '-3:')

def classify(native,translated,name,data,category,paths):
 if native.returncode==0:
  assert category is None and translated.returncode==0 and native.stdout==translated.stdout and native.stdout and not native.stderr+translated.stderr
  snapshot_checks(native.stdout.strip(),data);return 'return',native.stdout
 for result in (native,translated):
  checked_trap(result,name,category)
  messages=[m.group(1) for line in result.stderr.decode().splitlines() if (m:=re.fullmatch(r'(?:thread \d+ |V )?panic:\s*(.*)',line.strip()))];assert messages==[category]
 states=[p.read_bytes() for p in paths];assert states[0] and states[0]==states[1]
 _,trap,_=modeled(data);assert trap is not None and trap[1]==category and fields(states[0].decode())==trap[2],'float_hex formatting failure state differs'
 return 'trap',category.encode()+b'\0'+states[0]+b'\n'

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source',type=Path);parser.add_argument('zig',type=Path);parser.add_argument('v',type=Path)
    parser.add_argument('--target',default='aarch64-macos.14.0');parser.add_argument('--v-prod',action='store_true');parser.add_argument('--workdir',type=Path);parser.add_argument('--timeout',type=int,default=600)
    args=parser.parse_args()
    if args.timeout<=0:parser.error('--timeout must be positive')
    source=args.source.resolve()/'src';zig=args.zig.resolve();v=args.v.resolve()
    if tree_hash(source)!=PINNED_SOURCE_SHA256 or float_library_hashes(zig)!=FLOAT_LIBRARIES or time_library_hash(zig)!=TIME_LIBRARY_SHA256 or integer_library_hashes(zig)!=INTEGER_LIBRARIES or format_library_hash(zig)!=FORMAT_LIBRARY_SHA256 or io_library_hash(zig)!=IO_LIBRARY_SHA256 or stdlib_hash(zig)!=PINNED_STDLIB_SHA256 or path_library_hashes(zig)!=PATH_LIBRARIES or encoder_library_hashes(zig)!=ENCODER_LIBRARIES:parser.error('Source/compiler library differs from pins')
    repo=Path(__file__).resolve().parent.parent;probe=repo/'zigimg/reference_probes/writer_float_hex';mode='ReleaseSafe' if args.v_prod else 'Debug'
    with work_directory(args.workdir,'witty-writer-float_hex-') as root:
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
        (root/'provenance.json').write_text(json.dumps(dict(float_libraries=FLOAT_LIBRARIES,source_sha256=PINNED_SOURCE_SHA256,stdlib_sha256=PINNED_STDLIB_SHA256,io_library_sha256=IO_LIBRARY_SHA256,format_library_sha256=FORMAT_LIBRARY_SHA256,integer_libraries=INTEGER_LIBRARIES,time_library_sha256=TIME_LIBRARY_SHA256,path_libraries=PATH_LIBRARIES,encoder_libraries=ENCODER_LIBRARIES,versions=versions,target=args.target,zig_mode=mode,v_prod=args.v_prod,implementation_sha256=impl,runner_sha256=runner_hash,fixtures=fixtures,helper_sha256=helpers,shared_fixture_sha256=shared_hash),indent=2)+'\n')
        print(f'Building float_hex-formatting operations: Source {mode}, V {"production" if args.v_prod else "ordinary"}',flush=True)
        proof.run([str(zig),'build-exe','-target',args.target,'-lc','-I',str(root),'-O',mode,'--global-cache-dir',str(root.parent/'zig-global'),'--cache-dir',str(root/'zig-cache'),'-femit-bin='+str(root/'native'),str(root/'reference.zig'),str(root/'fixture_shims.c')],'build-source',env=env,timeout=args.timeout)
        proof.run([str(v),'-enable-globals',*(['-prod'] if args.v_prod else []),'-path',f'{repo}|@vlib|@vmodules','-o',str(root/'translated'),str(root/'main.v')],'build-v',env=env,timeout=args.timeout)
        rows=corpus();path=root/'corpus.txt';path.write_text('\n'.join(data for _,data in rows)+'\n');inputs={'corpus.txt':hashlib.sha256(path.read_bytes()).hexdigest()};(root/'input_sha256.json').write_text(json.dumps(inputs,indent=2)+'\n')
        outputs=[]
        for exe in ('native','translated'):
            result=proof.run([str(root/exe),str(path)],'returning-'+exe,env=env,timeout=args.timeout)
            if result.stderr or len(result.stdout.splitlines())!=len(rows):raise AssertionError('invalid returning output')
            outputs.append(result.stdout.splitlines())
        for i,((group,data),native,translated) in enumerate(zip(rows,*outputs)):
            if native!=translated:raise AssertionError(f'{i}/{group}: float_hex-formatting record differs; see retained proof')
            snapshot_checks(native,data)
        digest=hashlib.sha256(b'\n'.join(outputs[0])).hexdigest()
        if EXPECTED_ROWS is not None and (len(rows)!=EXPECTED_ROWS or digest!=EXPECTED_SHA256):raise AssertionError('returning golden changed')
        returns=hashlib.sha256();states=hashlib.sha256();return_count=0;trap_count=0
        print(f'{len(rows)} returning float_hex-formatting records match; checking failure controls',flush=True)
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
        summary=dict(returning_records=len(rows),primary_calls=len(rows),apis=dict(Counter(int(data.split('|')[6]) for _,data in rows)),returning_groups=dict(Counter(group for group,_ in rows)),output_sha256=digest,return_controls=return_count,control_sha256=returns.hexdigest(),paired_traps=trap_count,state_sha256=states.hexdigest(),zig_mode=mode,v_prod=args.v_prod)
        (root/'summary.json').write_text(json.dumps(summary,indent=2)+'\n');print(json.dumps(summary),flush=True)

if __name__=='__main__':main()
