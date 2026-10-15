"""Compare public format parser and argument tracker with the locked compiler library."""
import argparse
from collections import Counter
import hashlib,itertools,json,os,random,re,shutil
from pathlib import Path
from verify_jpeg_contracts_reference import implementation_hashes
from verify_tiff_decode_reference import ProofLog,tree_hash,work_directory,PINNED_SOURCE_SHA256,checked_trap
from verify_stream_guards_reference import stdlib_hash,PINNED_STDLIB_SHA256

EXPECTED_ROWS = 40127
EXPECTED_SHA256 = 'a0d015042f05d976b96b1145e5887dde34d69b8c9ccc0cbe58a8981855ca47b5'
EXPECTED_CONTROLS = 57
EXPECTED_CONTROL_SHA256 = '43ed26f0bcf4183f93cd6864a1067cedd436869794c856919576243dd8fe5ff2'
EXPECTED_TRAPS = 56
EXPECTED_STATE_SHA256 = '761a3e280f84db4d7ebca88bd190e12a98e35b53a7cba2c74ba0650c2763d6f7'
IO_LIBRARY_SHA256='09df1114cba703f824337f20489c7df5294db9f07961d4ac46abbbbf9c7ecaef'
def io_library_hash(zig):return hashlib.sha256((zig.parent/'lib/std/Io.zig').read_bytes()).hexdigest()
FORMAT_LIBRARY_SHA256='667eac6285e472b5516ebebf8a6e69959a171be4fb97cac1e56419ffec20d500'
def format_library_hash(zig):return hashlib.sha256((zig.parent/'lib/std/fmt.zig').read_bytes()).hexdigest()
INTEGER_LIBRARIES={'math.zig':'65645001357d5f78cbf646485e009a048b828680bb1b47fb3de0fd8617d91af1','meta.zig':'3cf9b3eb6c6b6f9b101f06f0562a4071c81a5fbc6de63d8197e837e10cedfc40'}
def integer_library_hashes(zig):return {n:hashlib.sha256((zig.parent/'lib/std'/n).read_bytes()).hexdigest() for n in INTEGER_LIBRARIES}
TIME_LIBRARY_SHA256='b8b686d5ecaa81cb25b3234229a85cf0ff99c5bd6153283b272fe586c558d7f1'
def time_library_hash(zig):return hashlib.sha256((zig.parent/'lib/std/time.zig').read_bytes()).hexdigest()

MAX=(1<<64)-1
EXTRA_LIBRARIES={'mem.zig': 'd4b891a60b1bb54e106c56d626dfd575ed39a85b1a09795b9c0a534fc10fd9ca', 'simd.zig': 'cc554020cebe55782b38c18c56a011b61a42f332781e5d0a5b1be3003eddd7a3'}
def library_hashes(zig):
 return {name:hashlib.sha256((zig.parent/'lib/std'/name).read_bytes()).hexdigest() for name in EXTRA_LIBRARIES}
def spec(data=b'',index=0,next_arg=0,used=0,args_len=0,actions='s'):
 return '|'.join((data.hex(),str(index),str(next_arg),str(used),str(args_len),actions))

class Trap(Exception):pass

def modeled(line):
 text,index,next_arg,used,args_len,actions=line.split('|')
 data=bytearray.fromhex(text);index=int(index);next_arg=int(next_arg);used=int(used);args_len=int(args_len)
 result='-';value=None;span=(0,0);step=-1
 def state():
  suffix=result
  if result in ('c','n','a','number','h','b'):suffix+=':'+('-' if value is None else str(value))
  elif result in ('u','named'):suffix+=':'+str(span[0])+':'+str(span[1])+':'+data[span[0]:sum(span)].hex()
  return f'{step}|{index}:{next_arg}:{used}:{args_len}|{data.hex()}|{suffix}'
 def peek(offset):
  if index+offset>MAX:raise Trap('integer overflow')
  return data[index+offset] if index+offset<len(data) else None
 def maybe(byte):
  nonlocal index
  if peek(0)==byte:index+=1;return True
  return False
 def until(byte):
  nonlocal index
  start=index
  found=data.find(byte,start);index=found if found>=0 else len(data)
  if start>index:raise Trap(f'start index {start} is larger than end index {index}')
  return start,index-start
 def number():
  nonlocal index
  n=None
  while (byte:=peek(0)) is not None and 48<=byte<=57:
   v=(0 if n is None else n)*10
   if v>MAX:raise Trap('integer overflow')
   v+=byte-48
   if v>MAX:raise Trap('integer overflow')
   n=v;index+=1
  return n
 output=[state()]
 try:
  for step,action in enumerate(actions.split(',')):
   op,*arg=action.split(':');status='ok'
   if op=='p':value=peek(int(arg[0]));result='c'
   elif op=='c':
    if index>len(data):raise Trap('integer overflow')
    value=data[index] if index<len(data) else None
    if value is not None:index+=1
    result='c'
   elif op=='m':value=int(maybe(int(arg[0])));result='b'
   elif op=='n':value=number();result='n'
   elif op=='u':span=until(int(arg[0]));result='u'
   elif op=='s':
    if maybe(91):
     name=until(93)
     if not maybe(93):status='Expected closing ]'
     else:span=name;result='named'
    else:
     n=number()
     if n is not None:result='number';value=n
     else:result='none'
   elif op=='a':
    if arg[0]=='-':
     n=next_arg
     if next_arg==MAX:raise Trap('integer overflow')
     next_arg+=1
    else:n=int(arg[0])
    if n>=args_len:value=None
    else:
     if n>=32:raise Trap('integer does not fit in destination type')
     used|=1<<n;value=n
    result='a'
   elif op=='h':result='h';value=int(bin(used).count("1")!=args_len)
   elif op=='x':data[int(arg[0])]^=int(arg[1])
   elif op=='w':
    assert int(arg[0])<span[1];data[span[0]+int(arg[0])]^=int(arg[1])
   else:raise AssertionError(op)
   output.append(status+'|'+state())
 except Trap as error:return None,(str(error),state())
 return '~'.join(output).encode(),None

def candidates():
 for byte in range(256):
  for prefix in (b'',b'a',b'00',b'[',b'[]'):
   data=prefix+bytes((byte,))+b']9'
   for index in (0,len(prefix),len(data),len(data)+1):
    for action in ('p:0','p:1','m:'+str(byte),'n','c','s','u:'+str(byte)):
     yield 'every-byte-and-position',spec(data,index=index,actions=action)
 alphabet=b'09[]:a\x00\xff'
 for size in range(5):
  for chars in itertools.product(alphabet,repeat=size):
   yield 'short-grammar',spec(bytes(chars),actions='s,p:0,n,c,s')
 for n in (0,1,9,10,99,100,2**32-1,2**32,MAX//10-1,MAX//10,MAX//10+1,MAX-1,MAX):
  for zeros in (0,1,8):
   for suffix in (b'',b']',b'a',b'\x00',b'9'):
    yield 'decimal-edges',spec(b'0'*zeros+str(n).encode()+suffix,actions='n,p:0,s')
 for name in (b'',b'a',b'name',b'[nested',bytes(range(32)),b'\xff\x00'):
  data=b'['+name+b']tail'
  actions='s'
  if name:actions+=',x:1:91,w:0:37'
  yield 'borrowed-slices',spec(data,actions=actions+',p:0,u:108,x:'+str(len(data)-1)+':255')
 for args_len,next_arg,used in itertools.product((0,1,2,7,31,32,33,MAX),(0,1,30,31,32,33,MAX),(0,1,3,0x80000000,0xffffffff)):
  for idx in ('-', '0','1','30','31','32','33',str(MAX)):
   yield 'argument-state',spec(next_arg=next_arg,used=used,args_len=args_len,actions='h,a:'+idx+',h,a:-,h')
 rng=random.Random(0xf04a7)
 for _ in range(2048):
  data=bytes(rng.choice(alphabet) for _ in range(rng.randrange(1,33)))
  actions=','.join(rng.choice(('s','n','c','p:0','p:3','u:93','m:91','a:-','h','x:0:255')) for _ in range(12))
  yield 'seeded-sequences',spec(data,args_len=32,used=rng.getrandbits(32),actions=actions)

def corpus():
 seen=set();rows=[]
 for group,line in candidates():
  if line in seen:continue
  seen.add(line)
  if modeled(line)[1] is None:rows.append((group,line))
 return rows

def controls():
 rows=[]
 for zeros in (0,1,8):
  for n in (MAX+1,MAX+2,10**20,10**21,10**32):
   for action in ('n','s'):
    rows.append(('decimal-overflow',spec(b'0'*zeros+str(n).encode(),actions=action)))
 for index in (1,2,8,MAX-1,MAX):
  for offset in (1,8,MAX):rows.append(('peek-overflow',spec(index=index,actions='p:'+str(offset))))
 for data in (b'',b'abc'):
  for index in (len(data)+1,MAX):
   for op in ('c','u:93','s','n','m:0'):
    rows.append(('invalid-cursor',spec(data,index=index,actions=op)))
 for args_len in (0,32,33,MAX):
  for n in (31,32,33,MAX):
   for arg in ('-',str(n)):
    rows.append(('argument-edge',spec(next_arg=n,args_len=args_len,actions='a:'+arg)))
 for byte in range(0,256,17):rows.append(('borrowed-error',spec(b'['+bytes((byte,)),actions='s,p:0,c')))
 result=[];seen=set()
 for label,line in rows:
  if line in seen:continue
  seen.add(line);trap=modeled(line)[1];result.append((label+'-'+str(len(result)),line,trap[0] if trap else None))
 return result

def snapshot_checks(output,line):
 expected,trap=modeled(line);assert trap is None and output==expected,'parser/argument/borrowed result state differs'
def classify(native,translated,label,line,category,paths):
 if category is None:
  assert native.returncode==translated.returncode==0 and native.stdout==translated.stdout and not native.stderr+translated.stderr
  snapshot_checks(native.stdout.strip(),line);return 'return',native.stdout
 for result in (native,translated):
  checked_trap(result,label,category)
  messages=[m.group(1) for s in result.stderr.decode().splitlines() if (m:=re.fullmatch(r'(?:thread \d+ |V )?panic:\s*(.*)',s.strip()))]
  assert messages==[category],(label,messages,category)
 states=[p.read_bytes() for p in paths];assert states[0]==states[1]==modeled(line)[1][1].encode(),(label,states,modeled(line))
 return 'trap',category.encode()+b'\0'+states[0]+b'\n'

def pins(source,zig):
 assert tree_hash(source)==PINNED_SOURCE_SHA256 and stdlib_hash(zig)==PINNED_STDLIB_SHA256
 assert library_hashes(zig)==EXTRA_LIBRARIES and integer_library_hashes(zig)==INTEGER_LIBRARIES and io_library_hash(zig)==IO_LIBRARY_SHA256 and format_library_hash(zig)==FORMAT_LIBRARY_SHA256 and time_library_hash(zig)==TIME_LIBRARY_SHA256

def main():
 parser=argparse.ArgumentParser(description=__doc__)
 parser.add_argument('source',type=Path);parser.add_argument('zig',type=Path);parser.add_argument('v',type=Path)
 parser.add_argument('--workdir',type=Path);parser.add_argument('--v-prod',action='store_true');parser.add_argument('--timeout',type=int,default=600)
 args=parser.parse_args();repo=Path(__file__).resolve().parent.parent;source=args.source.resolve()/'src';zig=args.zig.resolve();v=args.v.resolve();pins(source,zig)
 with work_directory(args.workdir,'witty-format-parser-') as root:
  (root/'tmp').mkdir();env=dict(os.environ,TMPDIR=str(root/'tmp'),VTMP=str(root/'tmp'),VEXE=str(v),V_C_ERROR_BUG_REPORT_DISABLED='1')
  log=ProofLog(root);shutil.copytree(source,root/'src');probe=repo/'zigimg/reference_probes/format_parser';fixtures={}
  for name in ('main.v','reference.zig'):
   shutil.copyfile(probe/name,root/name);fixtures[name]=hashlib.sha256((probe/name).read_bytes()).hexdigest()
  impl=implementation_hashes(repo);driver=hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
  helpers={name:hashlib.sha256((repo/'zigimg'/name).read_bytes()).hexdigest() for name in ('verify_jpeg_contracts_reference.py','verify_tiff_decode_reference.py','verify_stream_guards_reference.py')}
  versions=[log.run([str(exe),'version'],label,env=env).stdout.decode().strip() for exe,label in ((zig,'zig-version'),(v,'v-version'))]
  assert versions[0]=='0.15.2' and versions[1].startswith('V 0.5.2')
  mode='ReleaseSafe' if args.v_prod else 'Debug'
  log.run([str(zig),'build-exe','-target','aarch64-macos.14.0','-lc','-O',mode,'--global-cache-dir',str(root.parent/'zig-global'),'--cache-dir',str(root/'zig-cache'),'-femit-bin='+str(root/'native'),str(root/'reference.zig')],'build-source',env=env,timeout=args.timeout)
  log.run([str(v),'-enable-globals',*(['-prod'] if args.v_prod else []),'-path',str(repo)+'|@vlib|@vmodules','-o',str(root/'translated'),str(root/'main.v')],'build-v',env=env,timeout=args.timeout)
  rows=corpus();path=root/'corpus.txt';path.write_text('\n'.join(line for _,line in rows)+'\n');inputs={path.name:hashlib.sha256(path.read_bytes()).hexdigest()}
  outputs=[log.run([str(root/exe),str(path)],'returning-'+exe,env=env,timeout=args.timeout).stdout.splitlines() for exe in ('native','translated')]
  assert len(outputs[0])==len(outputs[1])==len(rows)
  for i,((group,line),a,b) in enumerate(zip(rows,*outputs)):
   assert a==b,(i,group,line,a,b);snapshot_checks(a,line)
  digest=hashlib.sha256(b'\n'.join(outputs[0])).hexdigest()
  if EXPECTED_ROWS is not None:assert len(rows)==EXPECTED_ROWS and digest==EXPECTED_SHA256
  print(str(len(rows))+' returning records match; checking isolated controls',flush=True)
  returns=hashlib.sha256();states=hashlib.sha256();nreturn=ntrap=0
  for label,line,category in controls():
   pair=[];paths=[root/(label+'-'+exe+'.state') for exe in ('native','translated')]
   for exe,path in zip(('native','translated'),paths):pair.append(log.run([str(root/exe),'--trap',str(path),line],label+'-'+exe,env=env,timeout=args.timeout,check=False))
   kind,data=classify(*pair,label,line,category,paths)
   if kind=='return':nreturn+=1;returns.update(label.encode()+b'\0'+data)
   else:ntrap+=1;states.update(label.encode()+b'\0'+data)
  if EXPECTED_CONTROLS is not None:assert nreturn==EXPECTED_CONTROLS and returns.hexdigest()==EXPECTED_CONTROL_SHA256
  if EXPECTED_TRAPS is not None:assert ntrap==EXPECTED_TRAPS and states.hexdigest()==EXPECTED_STATE_SHA256
  pins(source,zig);assert tree_hash(root/'src')==PINNED_SOURCE_SHA256 and implementation_hashes(repo)==impl and hashlib.sha256(Path(__file__).read_bytes()).hexdigest()==driver
  for name,pin in fixtures.items():assert hashlib.sha256((probe/name).read_bytes()).hexdigest()==pin==hashlib.sha256((root/name).read_bytes()).hexdigest()
  for name,pin in helpers.items():assert hashlib.sha256((repo/'zigimg'/name).read_bytes()).hexdigest()==pin
  assert hashlib.sha256((root/'corpus.txt').read_bytes()).hexdigest()==inputs['corpus.txt']
  (root/'provenance.json').write_text(json.dumps(dict(source_sha256=PINNED_SOURCE_SHA256,stdlib_sha256=PINNED_STDLIB_SHA256,extra_libraries=EXTRA_LIBRARIES,integer_libraries=INTEGER_LIBRARIES,io_library_sha256=IO_LIBRARY_SHA256,format_library_sha256=FORMAT_LIBRARY_SHA256,time_library_sha256=TIME_LIBRARY_SHA256,implementation_sha256=impl,runner_sha256=driver,fixtures=fixtures,helpers=helpers,input_sha256=inputs,versions=versions,production=args.v_prod),indent=2)+'\n')
  summary=dict(returning_records=len(rows),returning_groups=dict(Counter(g for g,_ in rows)),output_sha256=digest,return_controls=nreturn,control_sha256=returns.hexdigest(),paired_traps=ntrap,state_sha256=states.hexdigest(),trap_categories=dict(Counter(c for _,_,c in controls() if c)),production=args.v_prod)
  (root/'summary.json').write_text(json.dumps(summary,indent=2)+'\n');print(json.dumps(summary),flush=True)
if __name__=='__main__':main()
