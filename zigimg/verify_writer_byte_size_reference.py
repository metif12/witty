"""Compare byte-size formatting, units, fractions, padding and exact failure state."""
import argparse
from collections import Counter
import hashlib,itertools,json,os,re,shutil
from pathlib import Path
from verify_jpeg_contracts_reference import implementation_hashes
from verify_tiff_decode_reference import ProofLog,tree_hash,work_directory,PINNED_SOURCE_SHA256,checked_trap
from verify_stream_guards_reference import stdlib_hash,PINNED_STDLIB_SHA256
from verify_image_open_reference import PATH_LIBRARIES,path_library_hashes
from verify_image_tty_reference import ENCODER_LIBRARIES,encoder_library_hashes





EXPECTED_ROWS = 26852
EXPECTED_SHA256 = '695d9fd9a35408f76d5c3596e20117380d1a7d6afe701ccf815e0794800888e3'
EXPECTED_CONTROLS = 529
EXPECTED_CONTROL_SHA256 = '656d59be5013bf4529d54f2c87f90aa0845940cd4944f4b2c8e8a9b8a3990e0b'
EXPECTED_TRAPS = 188
EXPECTED_STATE_SHA256 = '761bb009c1af43804015165e29134a4916b887b29206fb9cf576a043f668eb4d'
IO_LIBRARY_SHA256='09df1114cba703f824337f20489c7df5294db9f07961d4ac46abbbbf9c7ecaef'
def io_library_hash(zig):return hashlib.sha256((zig.parent/'lib/std/Io.zig').read_bytes()).hexdigest()
FORMAT_LIBRARY_SHA256='667eac6285e472b5516ebebf8a6e69959a171be4fb97cac1e56419ffec20d500'
def format_library_hash(zig):return hashlib.sha256((zig.parent/'lib/std/fmt.zig').read_bytes()).hexdigest()
INTEGER_LIBRARIES={'math.zig':'65645001357d5f78cbf646485e009a048b828680bb1b47fb3de0fd8617d91af1','meta.zig':'3cf9b3eb6c6b6f9b101f06f0562a4071c81a5fbc6de63d8197e837e10cedfc40'}
def integer_library_hashes(zig):return {n:hashlib.sha256((zig.parent/'lib/std'/n).read_bytes()).hexdigest() for n in INTEGER_LIBRARIES}
TIME_LIBRARY_SHA256='b8b686d5ecaa81cb25b3234229a85cf0ff99c5bd6153283b272fe586c558d7f1'
def time_library_hash(zig):return hashlib.sha256((zig.parent/'lib/std/time.zig').read_bytes()).hexdigest()
MATH_LIBRARIES={'math/isfinite.zig': 'a68292f5d9110c879fd619fbbe888b2b66739b9f49d7eb1692f27d13120d12c9', 'math/log2.zig': 'ac08bfa3bcbab581e26c8cbdb71505bb1734e9d0500610abd518f8704aa0c1ed', 'math/pow.zig': '5df36194e30a115dac017fbfff11eacc5ed7b44fe9e39404afe9c3bd30829591', 'math/modf.zig': '339b1dd9b92e0df04e9b0d57929f5390f032627dbd7af8699009322573439cdc', 'math/frexp.zig': '2a9cf896243de2e7bf46513614eae704626b6a4898c54abc047df66759739080', 'math/scalbn.zig': '188cbd1b9c418a5bb2f5a699b0569b7caad57237c89b3b3fc94cf284e9a816bc', 'math/ldexp.zig': '2c3c54f8e10fb9ebaae5443832bbc4ad3d87ff35a50e109b71c0d8844feaeeaa', 'math/copysign.zig': 'ecbf663d488010fd3c51dec7cfb9666afc4c73f5e35796d18f1f5d6848d327c1', 'math/float.zig': '89498b527221904e328326ab55b8c0755977ac4104e2c3e814e3b0c4c73356d3', 'math/isnan.zig': '9dee284f974e89bcfc81fd90d45c496663fce6c2567e636aa8ca26598b74524e', 'math/isinf.zig': '9252e2a7668feb48b0d87ff5b5e40a904a62e61838eb187a979f2f390612b004', 'math/signbit.zig': '7d9fdef881d5e3dec3462602542a2d25a20b1b638c55b7514f2e08a0a631a9e2', 'fmt/float.zig': 'c660e0ba8697da2d832ecf0cd90ab39aceac7f0ac5c1173d139ce0b66392be12'}
def math_library_hashes(zig):return {n:hashlib.sha256((zig.parent/'lib/std'/n).read_bytes()).hexdigest() for n in MATH_LIBRARIES}
MAX_USIZE=(1<<64)-1
def spec(kind=0,cap=8,start=0,prefix=0,binding=0,finish=1,api=0,fill=91,alignment=0,width=0,present=1,precision=None,value=0,units=0):
 return '|'.join(map(str,(kind,cap,start,prefix,binding,finish,api,fill,alignment,width,present,'-' if precision is None else precision,value,units)))
def initial_end(kind,cap,start,prefix):return (start if kind==0 and start<cap else 0)+prefix

def fields(part):
 status,metadata,buffer,pending,unused,inputs,contents=part.split('|');m=list(map(int,metadata.split(':')));assert len(m)==6
 payload,headers,options=inputs.split('#');spans=tuple(tuple(map(int,h.split(','))) for h in headers.split(';')) if headers else ()
 opts=tuple(None if v=='-' else int(v) for v in options.split(':'));assert len(opts)==5
 return status,m,bytes.fromhex(buffer),bytes.fromhex(pending),bytes.fromhex(unused),(bytes.fromhex(payload),spans,opts),bytes.fromhex(contents)

class ModelTrap(Exception):pass
class WriteFailed(Exception):pass
class ModelLimit(Exception):pass

def modeled(data):
 f=data.split('|');kind,cap,start,prefix,binding,finish,api,fill,alignment,width,present=map(int,f[:11]);precision=None if f[11]=='-' else int(f[11]);raw,units=map(int,f[12:])
 end=initial_end(kind,cap,start,prefix);pos=start if kind else 0;mode=kind;wire=bytearray();calls=0
 buffer=bytearray((i*17+165)&255 for i in range(cap));begin=end-prefix;buffer[begin:end]=bytes((i*31+7)&255 for i in range(prefix))
 payload=raw.to_bytes(8,'little');spans=((0,8),);opts=(precision,width if present else None,alignment,fill,units)
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
 states=[state('setup'),state('ready')];status='ok'
 try:
  source=byte_size_text(raw,units,precision)
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

from functools import lru_cache
from fractions import Fraction
import verify_float_render_reference as rendering

def rounded_binary64(n,d=1):
 # Exact positive rational -> nearest/even binary64, without host float arithmetic.
 e=n.bit_length()-d.bit_length()
 if (n < d<<e) if e>=0 else (n<<-e < d):e-=1
 shift=52-e
 numerator=n<<shift if shift>=0 else n
 denominator=d if shift>=0 else d<<-shift
 q,r=divmod(numerator,denominator)
 if 2*r>denominator or (2*r==denominator and q%2):q+=1
 if q==1<<53:q>>=1;e+=1
 assert (1<<52)<=q<(1<<53) and -1022<=e<=1023
 return ((e+1023)<<52)|(q- (1<<52))
def exact_binary64(raw):
 e=(raw>>52)-1023-52;n=(1<<52)|(raw&((1<<52)-1))
 return Fraction(n<<e) if e>=0 else Fraction(n,1<<-e)

def scaled_bits(value,units):
 magnitude=(value.bit_length()-1)//(9 if units==0 else 10)
 rounded=exact_binary64(rounded_binary64(value));scale=(1000 if units==0 else 1024)**magnitude
 return magnitude,rounded_binary64(rounded.numerator,rounded.denominator*scale)

@lru_cache(maxsize=None)
def byte_size_text(value,units,precision):
 if value==0:return b'0B'
 magnitude,raw=scaled_bits(value,units)
 if magnitude==0:return str(value).encode()+b'B'
 result,trap=rendering.modeled(rendering.spec(api=1,length=56,offset=0,guard=0,raw=raw,precision=precision))
 if trap:raise ModelTrap(trap[0])
 row=result.decode().split('~')[1].split('|')
 if row[0]=='BufferTooSmall':raise ModelTrap('attempt to unwrap error: BufferTooSmall')
 text=bytes.fromhex(row[3].split(':')[2])
 suffix=(b'kB',b'MB',b'GB',b'TB',b'PB',b'EB',b'ZB')[magnitude-1] if units==0 else (b'KiB',b'MiB',b'GiB',b'TiB',b'PiB',b'EiB')[magnitude-1]
 if len(suffix)>56-len(text):raise ModelTrap(f'index out of bounds: index {len(text)+len(suffix)}, len 56')
 return text+suffix

def states():
 for kind,cap,start in itertools.product(range(3),(0,1,8,56,65),(0,3)):
  begin=initial_end(kind,cap,start,0)
  for prefix in sorted({0,cap-begin}):
   for binding in ((0,) if kind==0 else (0,1,2)):yield kind,cap,start,prefix,binding

def boundaries():
 values={0,1,42,511,512,999,1000,1023,1024,1025,MAX_USIZE}
 for n in range(64):
  for delta in (-1,0,1):values.add((1<<n)+delta)
 for base in (1000,1024):
  for n in range(1,8):
   for delta in (-1,0,1):values.add(base**n+delta)
 # Around every u64 -> f64 halfway point at representative significands/exponents.
 for e in range(53,65):
  step=1<<(e-53)
  for q,delta in itertools.product((1<<52,(1<<52)+1,(1<<53)-1),(-1,0,1)):
   values.add(q*step+step//2+delta)
 return sorted(n for n in values if 0<=n<=MAX_USIZE)

def candidates():
 rows=[]
 for units,kind,cap in itertools.product(range(2),range(3),(0,1,8,56)):
  for value in boundaries():rows.append(('magnitude-and-rounding-edges',spec(units=units,kind=kind,cap=cap,value=value)))
 for value,units,p in itertools.product(range(0,1050),range(2),(None,0,2)):
  rows.append(('small-values-and-first-unit',spec(value=value,units=units,precision=p,cap=65,kind=value%3)))
 for kind,cap,start,prefix,binding in states():
  for units,value,alignment in itertools.product(range(2),(0,511,512,1024,63*1024*1024,MAX_USIZE),range(3)):
   rows.append(('write-order-and-failure',spec(kind=kind,cap=cap,start=start,prefix=prefix,binding=binding,units=units,value=value,width=32,alignment=alignment,precision=2)))
 for units,value,p,width,present,alignment in itertools.product(range(2),(0,42,511,512,1024,1048576,MAX_USIZE),(None,0,1,2,16,45,48,49,50,51,52,53,54,55,MAX_USIZE),(0,24),range(2),range(3)):
  rows.append(('precision-options-and-private-buffer',spec(units=units,value=value,precision=p,width=width,present=present,alignment=alignment,cap=65,kind=(alignment+value)%3)))
 for fill,kind,alignment,units in itertools.product(range(256),range(3),range(3),range(2)):
  rows.append(('every-fill-byte',spec(units=units,value=66060288,fill=fill,kind=kind,alignment=alignment,width=32,precision=2,cap=56)))
 for i,units in itertools.product(range(1024),range(2)):
  value=((i*0x9e3779b97f4a7c15)^0xd6e8feb86659fd93)&MAX_USIZE
  rows.append(('seeded-u64-values',spec(units=units,value=value,precision=(None,0,2,16)[i%4],cap=(0,8,56,65)[i%4],kind=i%3)))
 return rows

def corpus():
 rows=[];seen=set()
 for group,data in candidates():
  if data in seen:continue
  seen.add(data)
  try:trap=modeled(data)[1]
  except ModelLimit:continue
  if trap is None:rows.append((group,data))
 return rows

def controls():
 rows=[];seen=set()
 def add(label,data):
  if data in seen:return
  seen.add(data)
  try:trap=modeled(data)[1]
  except ModelLimit:return
  if trap:assert modeled(data)[2]==b''
  rows.append((label+'-'+str(len(rows)),data,trap[1] if trap else None))
 contexts=((0,0,0,0,0),(0,65,0,3,0),(1,8,0,8,0),(1,8,3,8,1),(2,8,3,8,2))
 for context,units,value,p in itertools.product(contexts,range(2),(0,511,512,1024,MAX_USIZE),(48,49,50,51,52,53,54,55,MAX_USIZE-8,MAX_USIZE-1,MAX_USIZE)):
  kind,cap,start,prefix,binding=context
  add('precision-boundary',spec(kind=kind,cap=cap,start=start,prefix=prefix,binding=binding,units=units,value=value,precision=p))
 for context,units,value,alignment,present in itertools.product(contexts,range(2),(0,512,MAX_USIZE),range(3),range(2)):
  kind,cap,start,prefix,binding=context
  add('maximum-width',spec(kind=kind,cap=cap,start=start,prefix=prefix,binding=binding,units=units,value=value,alignment=alignment,present=present,width=MAX_USIZE))
 return rows

def snapshot_checks(line,data):
 parts=line.decode().split('~');assert len(parts)==6
 states=[fields(part) for part in parts[:-1]];model,trap,wire=modeled(data);assert trap is None and states==model,'independent byte-size representation/write boundaries/argument state state differs'
 f=list(map(int,data.split('|')[:11]));assert parts[-1]==('-1:'+wire.hex() if f[0] and f[4]==1 else '-3:')

def classify(native,translated,name,data,category,paths):
 if native.returncode==0:
  assert category is None and translated.returncode==0 and native.stdout==translated.stdout and native.stdout and not native.stderr+translated.stderr
  snapshot_checks(native.stdout.strip(),data);return 'return',native.stdout
 for result in (native,translated):
  checked_trap(result,name,category)
  messages=[m.group(1) for line in result.stderr.decode().splitlines() if (m:=re.fullmatch(r'(?:thread \d+ |V )?panic:\s*(.*)',line.strip()))];assert messages==[category]
 states=[p.read_bytes() for p in paths];assert states[0] and states[0]==states[1]
 _,trap,_=modeled(data);assert trap is not None and trap[1]==category and fields(states[0].decode())==trap[2],'byte-size formatting failure state differs'
 return 'trap',category.encode()+b'\0'+states[0]+b'\n'

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source',type=Path);parser.add_argument('zig',type=Path);parser.add_argument('v',type=Path)
    parser.add_argument('--target',default='aarch64-macos.14.0');parser.add_argument('--v-prod',action='store_true');parser.add_argument('--workdir',type=Path);parser.add_argument('--timeout',type=int,default=600)
    args=parser.parse_args()
    if args.timeout<=0:parser.error('--timeout must be positive')
    source=args.source.resolve()/'src';zig=args.zig.resolve();v=args.v.resolve()
    if math_library_hashes(zig)!=MATH_LIBRARIES or tree_hash(source)!=PINNED_SOURCE_SHA256 or time_library_hash(zig)!=TIME_LIBRARY_SHA256 or integer_library_hashes(zig)!=INTEGER_LIBRARIES or format_library_hash(zig)!=FORMAT_LIBRARY_SHA256 or io_library_hash(zig)!=IO_LIBRARY_SHA256 or stdlib_hash(zig)!=PINNED_STDLIB_SHA256 or path_library_hashes(zig)!=PATH_LIBRARIES or encoder_library_hashes(zig)!=ENCODER_LIBRARIES:parser.error('Source/compiler library differs from pins')
    repo=Path(__file__).resolve().parent.parent;probe=repo/'zigimg/reference_probes/writer_byte_size';mode='ReleaseSafe' if args.v_prod else 'Debug'
    with work_directory(args.workdir,'witty-writer-byte-size-') as root:
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
        helpers={name:hashlib.sha256((repo/'zigimg'/name).read_bytes()).hexdigest() for name in ('verify_float_render_reference.py','verify_float_decimal_reference.py','verify_writer_float_hex_reference.py','verify_jpeg_contracts_reference.py','verify_tiff_decode_reference.py','verify_stream_guards_reference.py','verify_image_open_reference.py','verify_image_tty_reference.py')}
        (root/'provenance.json').write_text(json.dumps(dict(math_libraries=MATH_LIBRARIES,source_sha256=PINNED_SOURCE_SHA256,stdlib_sha256=PINNED_STDLIB_SHA256,io_library_sha256=IO_LIBRARY_SHA256,format_library_sha256=FORMAT_LIBRARY_SHA256,integer_libraries=INTEGER_LIBRARIES,time_library_sha256=TIME_LIBRARY_SHA256,path_libraries=PATH_LIBRARIES,encoder_libraries=ENCODER_LIBRARIES,versions=versions,target=args.target,zig_mode=mode,v_prod=args.v_prod,implementation_sha256=impl,runner_sha256=runner_hash,fixtures=fixtures,helper_sha256=helpers,shared_fixture_sha256=shared_hash),indent=2)+'\n')
        print(f'Building byte-size-formatting operations: Source {mode}, V {"production" if args.v_prod else "ordinary"}',flush=True)
        proof.run([str(zig),'build-exe','-target',args.target,'-lc','-I',str(root),'-O',mode,'--global-cache-dir',str(root.parent/'zig-global'),'--cache-dir',str(root/'zig-cache'),'-femit-bin='+str(root/'native'),str(root/'reference.zig'),str(root/'fixture_shims.c')],'build-source',env=env,timeout=args.timeout)
        proof.run([str(v),'-enable-globals',*(['-prod'] if args.v_prod else []),'-path',f'{repo}|@vlib|@vmodules','-o',str(root/'translated'),str(root/'main.v')],'build-v',env=env,timeout=args.timeout)
        rows=corpus();path=root/'corpus.txt';path.write_text('\n'.join(data for _,data in rows)+'\n');inputs={'corpus.txt':hashlib.sha256(path.read_bytes()).hexdigest()};(root/'input_sha256.json').write_text(json.dumps(inputs,indent=2)+'\n')
        outputs=[]
        for exe in ('native','translated'):
            result=proof.run([str(root/exe),str(path)],'returning-'+exe,env=env,timeout=args.timeout)
            if result.stderr or len(result.stdout.splitlines())!=len(rows):raise AssertionError('invalid returning output')
            outputs.append(result.stdout.splitlines())
        for i,((group,data),native,translated) in enumerate(zip(rows,*outputs)):
            if native!=translated:raise AssertionError(f'{i}/{group}: byte-size-formatting record differs; see retained proof')
            snapshot_checks(native,data)
        digest=hashlib.sha256(b'\n'.join(outputs[0])).hexdigest()
        if EXPECTED_ROWS is not None and (len(rows)!=EXPECTED_ROWS or digest!=EXPECTED_SHA256):raise AssertionError('returning golden changed')
        returns=hashlib.sha256();states=hashlib.sha256();return_count=0;trap_count=0
        print(f'{len(rows)} returning byte-size-formatting records match; checking failure controls',flush=True)
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
        if math_library_hashes(zig)!=MATH_LIBRARIES or tree_hash(source)!=PINNED_SOURCE_SHA256 or tree_hash(root/'src')!=PINNED_SOURCE_SHA256 or time_library_hash(zig)!=TIME_LIBRARY_SHA256 or integer_library_hashes(zig)!=INTEGER_LIBRARIES or format_library_hash(zig)!=FORMAT_LIBRARY_SHA256 or io_library_hash(zig)!=IO_LIBRARY_SHA256 or stdlib_hash(zig)!=PINNED_STDLIB_SHA256 or path_library_hashes(zig)!=PATH_LIBRARIES or encoder_library_hashes(zig)!=ENCODER_LIBRARIES or implementation_hashes(repo)!=impl or hashlib.sha256(Path(__file__).read_bytes()).hexdigest()!=runner_hash:raise AssertionError('dependency/implementation/runner changed')
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
