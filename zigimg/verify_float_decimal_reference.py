"""Compare decimal-record formatting, borrowed views, scratch bytes and exact traps."""
import argparse
from collections import Counter
import hashlib,itertools,json,os,re,shutil
from pathlib import Path
from verify_jpeg_contracts_reference import implementation_hashes
from verify_tiff_decode_reference import ProofLog,tree_hash,work_directory,PINNED_SOURCE_SHA256,checked_trap
from verify_stream_guards_reference import stdlib_hash,PINNED_STDLIB_SHA256
from verify_image_open_reference import PATH_LIBRARIES,path_library_hashes
from verify_image_tty_reference import ENCODER_LIBRARIES,encoder_library_hashes

EXPECTED_ROWS = 11922
EXPECTED_SHA256 = '406ad01113cd33d0fbc8e666d47e2ee81a41b494dff304a5505c0b43e3c4242c'
EXPECTED_CONTROLS = 502
EXPECTED_CONTROL_SHA256 = 'e5f56f06ea471e70433a8259183a2cb403ae1571907f11ff15710011af524508'
EXPECTED_TRAPS = 480
EXPECTED_STATE_SHA256 = '0f0a5720b6566a040a684b9aad2036dcd3d742077e0872aa9bf4332a1bf83ebc'
MAX_USIZE=(1<<64)-1
LIBRARIES={'fmt/float.zig':'c660e0ba8697da2d832ecf0cd90ab39aceac7f0ac5c1173d139ce0b66392be12','fmt.zig':'667eac6285e472b5516ebebf8a6e69959a171be4fb97cac1e56419ffec20d500','math.zig':'65645001357d5f78cbf646485e009a048b828680bb1b47fb3de0fd8617d91af1','meta.zig':'3cf9b3eb6c6b6f9b101f06f0562a4071c81a5fbc6de63d8197e837e10cedfc40','Io.zig':'09df1114cba703f824337f20489c7df5294db9f07961d4ac46abbbbf9c7ecaef'}
def library_hashes(zig):return {n:hashlib.sha256((zig.parent/'lib/std'/n).read_bytes()).hexdigest() for n in LIBRARIES}
def spec(api=0,length=64,offset=3,guard=5,mantissa=123456,exponent=-3,sign=0,precision=None,mask=91):
 return '|'.join(map(str,(api,offset+length+guard,offset,length,mantissa,exponent,sign,'-' if precision is None else precision,mask)))
class ModelTrap(Exception):pass

def modeled(data):
 text=data.split('|');api,cap,offset,extent,mantissa,exponent,sign=map(int,text[:7]);precision=None if text[7]=='-' else int(text[7]);mask=int(text[8])
 buffer=bytearray((i*17+165)&255 for i in range(cap));original=[mantissa,exponent,sign];copy=original[:];view=None
 def state(status):
  retained='-' if view is None else f'{view}:{offset}:'+buffer[offset:offset+view].hex()
  scalar=lambda n:','.join(map(str,n))
  return status+'|'+data.replace('|',',')+'|'+buffer.hex()+'|'+retained+'|'+scalar(original)+';'+scalar(copy)
 def add(a,b):
  if a+b>MAX_USIZE:raise ModelTrap('integer overflow')
  return a+b
 def i32(n):
  if not -(1<<31)<=n<(1<<31):raise ModelTrap('integer overflow')
  return n
 def length(n):
  if n>=10**17:raise ModelTrap('reached unreachable code')
  return len(str(n))
 def put(base,size,index,byte):
  if index>=size:raise ModelTrap(f'index out of bounds: index {index}, len {size}')
  buffer[offset+base+index]=byte
 def tail(index):
  if index>extent:raise ModelTrap(f'index out of bounds: index {index}, len {extent}')
  return index,extent-index
 def zeros(index,n):
  base,size=tail(index)
  if n>size:raise ModelTrap(f'index out of bounds: index {n}, len {size}')
  buffer[offset+base:offset+base+n]=b'0'*n
 def digits(base,size,n,count):
  # Compute the complete zero-padded decimal text, then model Source's pair store order.
  text=str(n).zfill(count)[-count:] if count else ''
  order=[];i=0
  while i+2<count:order.extend((count-i-1,count-i-2));i+=2
  while i<count:order.append(count-i-1);i+=1
  for j in order:put(base,size,j,ord(text[j]))
  return n//(10**count)
 def rounded(n,e):
  l=length(n)
  if api==0:r=add(1,precision)
  elif e>0:r=add(add(l-1,precision),e)
  else:
   minimum=i32(-e);count=add(precision,l);r=count-minimum if count>minimum else 0
  if r<l:
   dropped=l-(r+1);n//=10**dropped;e=i32(e+dropped)
   if n%10>=5:n=n//10+1;e=i32(e+1)
   # Pinned isPowerOf10 returns true only for zero, which rounding-up cannot produce.
  return n,e
 records=[state('ready')];status='ok'
 try:
  if extent<53:raise ModelTrap('reached unreachable code')
  if exponent==(1<<31)-1:
   word=(b'-' if sign else b'')+(b'nan' if mantissa else b'inf')
   buffer[offset:offset+len(word)]=word;view=len(word)
  else:
   n,e=(rounded(mantissa,exponent) if precision is not None else (mantissa,exponent));l=length(n)
   required=add(8,precision) if api==0 and precision is not None else 0
   if api==1:
    required=add(add(add(2,abs(e)),l),precision or 0) if e>=0 else add(2,max(abs(e)+l,precision or 0))
   if extent<required:status='BufferTooSmall'
   else:
    index=sign
    if sign:put(0,extent,0,45)
    if api==0:
     n=digits(*tail(index+2),n,l-1);put(0,extent,index,48+n%10);put(0,extent,index+1,46)
     index+=2;dp=index;index+=l-1 if l>1 else -1
     if precision is not None:
      index+=l==1
      if precision>l-1:count=precision-(l-1);zeros(index,count);index+=count
      else:index=dp+precision-(precision==0)
     put(0,extent,index,101);index+=1;exp=i32(i32(e+l)-1)
     if exp<0:put(0,extent,index,45);index+=1;exp=i32(-exp)
     el=length(exp);digits(*tail(index),exp,el);index+=el
    else:
     dp_offset=i32(e+l)
     if dp_offset<=0:
      put(0,extent,index,48);put(0,extent,index+1,46);index+=2;dp=index;count=i32(-dp_offset);zeros(index,count);index+=count
      digits(*tail(index),n,l);index+=l
      if precision is not None:
       written=index-dp
       if precision>written:zeros(index,precision-written)
       index=dp+precision-(precision==0)
     elif dp_offset>=l:
      digits(*tail(index),n,l);index+=l;zeros(index,dp_offset-l);index+=dp_offset-l
      if precision:
       put(0,extent,index,46);index+=1;zeros(index,precision);index+=precision
     else:
      n=digits(*tail(index+dp_offset+1),n,l-dp_offset);put(0,extent,index+dp_offset,46);dp=index+dp_offset+1
      digits(*tail(index),n,dp_offset);index+=l+1
      if precision is not None:
       written=l-dp_offset
       if precision>written:zeros(index,precision-written)
       index=dp+precision-(precision==0)
    if index>extent:raise ModelTrap(f'index out of bounds: index {index}, len {extent}')
    view=index
 except ModelTrap as e:return None,(str(e),state('format').encode())
 records.append(state(status))
 if cap:buffer[offset if offset<cap else cap-1]^=mask
 records.append(state('caller'));original[0]^=mask;records.append(state('argument'))
 return '~'.join(records).encode(),None

MANTISSAS=(0,1,5,9,10,15,19,99,100,125,999,1000,1234,12345,123456,9999999999999999,10000000000000000,99999999999999999)
def candidates():
 rows=[]
 for api,n,e,p,sign in itertools.product(range(2),MANTISSAS,(-324,-100,-20,-6,-2,-1,0,1,6,20,308,2147483647),(None,0,1,2,16,45),range(2)):
  rows.append(('records-and-rounding',spec(api=api,mantissa=n,exponent=e,precision=p,sign=sign)))
 for api,length,n,e,p in itertools.product(range(2),range(53,73),(0,9,12345678901234567),(-7,0,9),(0,1,45,46,48,64)):
  rows.append(('buffer-thresholds',spec(api=api,length=length,offset=(length%3)*3,mantissa=n,exponent=e,precision=p,sign=length%2)))
 for api,e,sign in itertools.product(range(2),range(-324,309),range(2)):
  rows.append(('every-binary64-exponent',spec(api=api,length=347,mantissa=1 if e%2 else 12345678901234567,exponent=e,sign=sign,precision=None)))
 for i,api in itertools.product(range(512),range(2)):
  n=((i*0x9e3779b97f4a7c15)^0xd6e8feb86659fd93)%(10**17)
  rows.append(('seeded-mantissas',spec(api=api,length=(53,64,128,347)[i%4],mantissa=n,exponent=i%801-400,precision=(None,0,2,16,45,63)[i%6],sign=i%2)))
 for api,sign,mask in itertools.product(range(2),range(2),range(256)):
  rows.append(('every-caller-mask',spec(api=api,mantissa=123454,exponent=-3,precision=2,sign=sign,mask=mask)))
 for api,n,sign,p in itertools.product(range(2),(0,1,10**17,MAX_USIZE),range(2),(None,0,MAX_USIZE)):
  rows.append(('special-bypass',spec(api=api,mantissa=n,exponent=2147483647,sign=sign,precision=p)))
 return rows

def corpus():
 rows=[];seen=set()
 for group,data in candidates():
  if data in seen:continue
  seen.add(data)
  if modeled(data)[1] is None:rows.append((group,data))
 return rows

def controls():
 rows=[];seen=set()
 def add(label,data):
  if data in seen:return
  seen.add(data);trap=modeled(data)[1];rows.append((label+'-'+str(len(rows)),data,trap[0] if trap else None))
 for api,n,e,p,length in itertools.product(range(2),(0,1,9,99,10**16,10**17-1),(-2147483648,-2147483647,2147483645,2147483646,2147483647),(None,0,1,45,MAX_USIZE-8,MAX_USIZE-1,MAX_USIZE),(53,64)):
  add('integer-boundary',spec(api=api,mantissa=n,exponent=e,precision=p,length=length,sign=n%2))
 for api,length in itertools.product(range(2),range(53)):
  add('minimum-buffer',spec(api=api,length=length,mantissa=MAX_USIZE if length%2 else 0,exponent=2147483647 if length%3 else 0,precision=MAX_USIZE if length%2 else None))
 for api,n,p,e in itertools.product(range(2),(10**17,MAX_USIZE),(None,0,MAX_USIZE),(-1,0,2147483647)):
  add('mantissa-assertion',spec(api=api,mantissa=n,exponent=e,precision=p))
 return rows

def snapshot_checks(line,data):
 expected,trap=modeled(data);assert trap is None and line==expected,'independent decimal rounding/scratch/borrow state differs'

def classify(native,translated,name,data,category,paths):
 if native.returncode==0:
  assert category is None and translated.returncode==0 and native.stdout==translated.stdout and native.stdout and not native.stderr+translated.stderr
  snapshot_checks(native.stdout.strip(),data);return 'return',native.stdout
 for result in (native,translated):
  checked_trap(result,name,category)
  messages=[m.group(1) for line in result.stderr.decode().splitlines() if (m:=re.fullmatch(r'(?:thread \d+ |V )?panic:\s*(.*)',line.strip()))];assert messages==[category]
 states=[p.read_bytes() for p in paths];assert states[0] and states[0]==states[1]
 _,trap=modeled(data);assert trap is not None and trap[0]==category and states[0]==trap[1],'decimal formatting failure state differs'
 return 'trap',category.encode()+b'\0'+states[0]+b'\n'

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source',type=Path);parser.add_argument('zig',type=Path);parser.add_argument('v',type=Path)
    parser.add_argument('--target',default='aarch64-macos.14.0');parser.add_argument('--v-prod',action='store_true');parser.add_argument('--workdir',type=Path);parser.add_argument('--timeout',type=int,default=600)
    args=parser.parse_args()
    if args.timeout<=0:parser.error('--timeout must be positive')
    source=args.source.resolve()/'src';zig=args.zig.resolve();v=args.v.resolve()
    if library_hashes(zig)!=LIBRARIES or tree_hash(source)!=PINNED_SOURCE_SHA256 or stdlib_hash(zig)!=PINNED_STDLIB_SHA256 or path_library_hashes(zig)!=PATH_LIBRARIES or encoder_library_hashes(zig)!=ENCODER_LIBRARIES:parser.error('Source/compiler library differs from pins')
    repo=Path(__file__).resolve().parent.parent;probe=repo/'zigimg/reference_probes/float_decimal';mode='ReleaseSafe' if args.v_prod else 'Debug'
    with work_directory(args.workdir,'witty-float-decimal-') as root:
        tmp=root/'tmp';tmp.mkdir();env=dict(os.environ,TMPDIR=str(tmp),VTMP=str(tmp),VEXE=str(v),V_C_ERROR_BUG_REPORT_DISABLED='1')
        proof=ProofLog(root);shutil.copytree(source,root/'src');fixtures={}
        for name in ('main.v','reference.zig'):
            shutil.copyfile(probe/name,root/name);fixtures[name]=hashlib.sha256((root/name).read_bytes()).hexdigest()
        versions=[proof.run([str(exe),'version'],label,env=env).stdout.decode().strip() for exe,label in ((zig,'zig-version'),(v,'v-version'))]
        if versions[0]!='0.15.2' or not re.match(r'^V 0\.5\.2(?: |$)',versions[1]):raise AssertionError('compiler versions differ')
        impl=implementation_hashes(repo);runner_hash=hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
        helpers={name:hashlib.sha256((repo/'zigimg'/name).read_bytes()).hexdigest() for name in ('verify_jpeg_contracts_reference.py','verify_tiff_decode_reference.py','verify_stream_guards_reference.py','verify_image_open_reference.py','verify_image_tty_reference.py')}
        (root/'provenance.json').write_text(json.dumps(dict(libraries=LIBRARIES,source_sha256=PINNED_SOURCE_SHA256,stdlib_sha256=PINNED_STDLIB_SHA256,path_libraries=PATH_LIBRARIES,encoder_libraries=ENCODER_LIBRARIES,versions=versions,target=args.target,zig_mode=mode,v_prod=args.v_prod,implementation_sha256=impl,runner_sha256=runner_hash,fixtures=fixtures,helper_sha256=helpers),indent=2)+'\n')
        print(f'Building decimal record formatting operations: Source {mode}, V {"production" if args.v_prod else "ordinary"}',flush=True)
        proof.run([str(zig),'build-exe','-target',args.target,'-lc','-I',str(root),'-O',mode,'--global-cache-dir',str(root.parent/'zig-global'),'--cache-dir',str(root/'zig-cache'),'-femit-bin='+str(root/'native'),str(root/'reference.zig')],'build-source',env=env,timeout=args.timeout)
        proof.run([str(v),'-enable-globals',*(['-prod'] if args.v_prod else []),'-path',f'{repo}|@vlib|@vmodules','-o',str(root/'translated'),str(root/'main.v')],'build-v',env=env,timeout=args.timeout)
        rows=corpus();path=root/'corpus.txt';path.write_text('\n'.join(data for _,data in rows)+'\n');inputs={'corpus.txt':hashlib.sha256(path.read_bytes()).hexdigest()};(root/'input_sha256.json').write_text(json.dumps(inputs,indent=2)+'\n')
        outputs=[]
        for exe in ('native','translated'):
            result=proof.run([str(root/exe),str(path)],'returning-'+exe,env=env,timeout=args.timeout)
            if result.stderr or len(result.stdout.splitlines())!=len(rows):raise AssertionError('invalid returning output')
            outputs.append(result.stdout.splitlines())
        for i,((group,data),native,translated) in enumerate(zip(rows,*outputs)):
            if native!=translated:raise AssertionError(f'{i}/{group}: decimal record formatting record differs; see retained proof')
            snapshot_checks(native,data)
        digest=hashlib.sha256(b'\n'.join(outputs[0])).hexdigest()
        if EXPECTED_ROWS is not None and (len(rows)!=EXPECTED_ROWS or digest!=EXPECTED_SHA256):raise AssertionError('returning golden changed')
        returns=hashlib.sha256();states=hashlib.sha256();return_count=0;trap_count=0
        print(f'{len(rows)} returning decimal record formatting records match; checking failure controls',flush=True)
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
        if library_hashes(zig)!=LIBRARIES or tree_hash(source)!=PINNED_SOURCE_SHA256 or tree_hash(root/'src')!=PINNED_SOURCE_SHA256 or stdlib_hash(zig)!=PINNED_STDLIB_SHA256 or path_library_hashes(zig)!=PATH_LIBRARIES or encoder_library_hashes(zig)!=ENCODER_LIBRARIES or implementation_hashes(repo)!=impl or hashlib.sha256(Path(__file__).read_bytes()).hexdigest()!=runner_hash:raise AssertionError('dependency/implementation/runner changed')
        for name,pin in fixtures.items():
            if any(hashlib.sha256((base/name).read_bytes()).hexdigest()!=pin for base in (root,probe)):raise AssertionError('fixture changed')
        for name,pin in inputs.items():
            if hashlib.sha256((root/name).read_bytes()).hexdigest()!=pin:raise AssertionError('input changed')
        for name,pin in helpers.items():
            if hashlib.sha256((repo/'zigimg'/name).read_bytes()).hexdigest()!=pin:raise AssertionError('helper changed')
        summary=dict(returning_records=len(rows),primary_calls=len(rows),returning_groups=dict(Counter(group for group,_ in rows)),output_sha256=digest,return_controls=return_count,control_sha256=returns.hexdigest(),paired_traps=trap_count,state_sha256=states.hexdigest(),zig_mode=mode,v_prod=args.v_prod)
        (root/'summary.json').write_text(json.dumps(summary,indent=2)+'\n');print(json.dumps(summary),flush=True)

if __name__=='__main__':main()
