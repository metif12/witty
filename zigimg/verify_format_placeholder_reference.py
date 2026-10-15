"""Compare placeholder records against unchanged compile-time Source parsing."""
import argparse
from collections import Counter
import hashlib,itertools,json,os,random,re,shutil
from pathlib import Path
from verify_format_parser_reference import pins,EXTRA_LIBRARIES,INTEGER_LIBRARIES,IO_LIBRARY_SHA256,FORMAT_LIBRARY_SHA256,TIME_LIBRARY_SHA256,PINNED_STDLIB_SHA256
from verify_jpeg_contracts_reference import implementation_hashes
from verify_tiff_decode_reference import ProofLog,tree_hash,work_directory,PINNED_SOURCE_SHA256,checked_trap
from verify_simd_reference import ordinary_rejection

EXPECTED_ROWS = 10918
EXPECTED_SHA256 = '8f5fd91c4614457eb85890f7111ebeb87c48c6dff447a497f9f18bc11a63fe46'
EXPECTED_ERRORS = 1983
EXPECTED_ERROR_SHA256 = 'c6e777b0567af3a85f111b04a271bd3cff4f1aacd7aa2abbfb7a2abf3b2a6bd8'
MAX=(1<<64)-1
class ParseError(Exception):pass

def modeled(data):
 position=0
 def specifier():
  nonlocal position
  if data[position:position+1]==b'[':
   start=position+1;end=data.find(b']',start)
   if end<0:raise ParseError(b'Expected closing ]')
   position=end+1;return ('s',data[start:end])
  start=position
  while position<len(data) and 48<=data[position]<=57:position+=1
  if position==start:return ('-',None)
  n=int(data[start:position])
  if n>MAX:raise ParseError(b'overflow')
  return ('n',n)
 try:
  arg=specifier();end=data.find(b':',position)
  if end<0:specifier_arg=data[position:];position=len(data)
  else:specifier_arg=data[position:end];position=end+1
  fill=None;alignment=None
  if position+1<len(data) and data[position+1] in b'<^>':fill=data[position];position+=1
  if position<len(data) and data[position] in b'<^>':alignment=b'<^>'.index(data[position]);position+=1
  if fill is None and alignment is None and data[position:position+1]==b'0':fill=48
  width=specifier()
  if position<len(data):
   byte=data[position];position+=1
   if byte!=46:raise ParseError(b"expected . or }, found '"+bytes((byte,))+b"'")
  precision=specifier()
  if position<len(data):raise ParseError(b"extraneous trailing character '"+data[position:position+1]+b"'")
  return (specifier_arg,32 if fill is None else fill,2 if alignment is None else alignment,arg,width,precision),None
 except ParseError as error:return None,error.args[0]

def encoded(value):
 text,fill,alignment,*specs=value
 return text.hex()+'|'+str(fill)+':'+str(alignment)+'|'+'|'.join('-' if kind=='-' else 'n:'+str(payload) if kind=='n' else 's:'+payload.hex() for kind,payload in specs)
def expected(data):
 value,error=modeled(data);assert error is None
 state=encoded(value)
 return (data.hex()+'|'+state+'~'+bytes(b^0x5a for b in data).hex()+'|'+state).encode()
def candidates():
 alphabet=b'0a:.[<>]'
 for size in range(5):
  for data in itertools.product(alphabet,repeat=size):yield 'short-grammar',bytes(data)
 for byte in range(256):
  for template in (lambda b:b,lambda b:b'x'+b,lambda b:b'x:'+b+b'>5.2',lambda b:b'x:'+b+b'^[]',lambda b:b'['+b+b']x:2.[p]'):
   yield 'every-byte',template(bytes((byte,)))
 for arg,fmt,fill,alignment,width,precision in itertools.product((b'',b'0',b'31',b'[value]'),(b'',b'd',b'any',b'?',b'b64'),(b'',b'0',b'_'),(b'',b'<',b'^',b'>'),(b'',b'0',b'05',b'32',b'[width]'),(b'',b'.',b'.0',b'.3',b'.[precision]')):
  yield 'field-combinations',arg+fmt+b':'+fill+alignment+width+precision
 for n in (0,1,9,10,2**32-1,2**32,MAX//10,MAX-1,MAX):
  for zeros in (0,1,8):
   number=b'0'*zeros+str(n).encode()
   for text in (number+b'd',b'd:'+number,b'd:.[p]',b'd:.'+number,b'['+number+b']'):
    yield 'native-number-edges',text
 rng=random.Random(0x504c4143)
 for _ in range(1024):yield 'seeded-bytes',bytes(rng.randrange(256) for _ in range(rng.randrange(1,25)))

def corpora():
 good=[];bad=[];seen=set()
 for group,data in candidates():
  if data in seen:continue
  seen.add(data);value,error=modeled(data)
  if error is None:good.append((group,data))
  elif error!=b'overflow':bad.append((group,data,error))
 return good,bad

def source_cases(rows):
 literals=[('&.{'+','.join(str(b) for b in data)+'}') for _,data in rows]
 return 'const std=@import("std");\npub const inputs=[_][]const u8{'+','.join(literals)+'};\npub const values=blk:{@setEvalBranchQuota(100000000);var result:[inputs.len]std.fmt.Placeholder=undefined;for(inputs,0..) |input,i| result[i]=std.fmt.Placeholder.parse(input);break :blk result;};\n'

def invalid_cases():
 return [
  ('arg-name',b'[name',b'Expected closing ]'),
  ('width-name',b'd:[width',b'Expected closing ]'),
  ('precision-name',b'd:.[precision',b'Expected closing ]'),
  ('width-character',b'd:a',b"expected . or }, found 'a'"),
  ('width-sign',b'd:-1',b"expected . or }, found '-'"),
  ('precision-character',b'd:.a',b"extraneous trailing character 'a'"),
  ('trailing-dot',b'd:1.2.',b"extraneous trailing character '.'"),
  ('repeated-colon',b'd::',b"expected . or }, found ':'"),
  ('name-before-tail',b'd:[x]z.2',b"expected . or }, found 'z'"),
  ('precision-name-tail',b'd:.[x]z',b"extraneous trailing character 'z'"),
  ('argument-overflow',str(MAX+1).encode(),b'overflow'),
  ('width-overflow',b'd:'+str(MAX+1).encode(),b'overflow'),
  ('precision-overflow',b'd:.'+str(MAX+1).encode(),b'overflow'),
 ]

def main():
 parser=argparse.ArgumentParser(description=__doc__)
 parser.add_argument('source',type=Path);parser.add_argument('zig',type=Path);parser.add_argument('v',type=Path)
 parser.add_argument('--workdir',type=Path);parser.add_argument('--v-prod',action='store_true');parser.add_argument('--timeout',type=int,default=600)
 args=parser.parse_args();repo=Path(__file__).resolve().parent.parent;source=args.source.resolve()/'src';zig=args.zig.resolve();v=args.v.resolve();pins(source,zig)
 with work_directory(args.workdir,'witty-format-placeholder-') as root:
  (root/'tmp').mkdir();env=dict(os.environ,TMPDIR=str(root/'tmp'),VTMP=str(root/'tmp'),VEXE=str(v),V_C_ERROR_BUG_REPORT_DISABLED='1')
  log=ProofLog(root);shutil.copytree(source,root/'src');probe=repo/'zigimg/reference_probes/format_placeholder';fixtures={}
  for name in ('main.v','reference.zig'):
   shutil.copyfile(probe/name,root/name);fixtures[name]=hashlib.sha256((probe/name).read_bytes()).hexdigest()
  impl=implementation_hashes(repo);driver=hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
  helpers={name:hashlib.sha256((repo/'zigimg'/name).read_bytes()).hexdigest() for name in ('verify_format_parser_reference.py','verify_jpeg_contracts_reference.py','verify_tiff_decode_reference.py','verify_stream_guards_reference.py','verify_simd_reference.py')}
  versions=[log.run([str(exe),'version'],label,env=env).stdout.decode().strip() for exe,label in ((zig,'zig-version'),(v,'v-version'))]
  assert versions[0]=='0.15.2' and versions[1].startswith('V 0.5.2')
  mode='ReleaseSafe' if args.v_prod else 'Debug';rows,errors=corpora()
  (root/'cases.zig').write_text(source_cases(rows));path=root/'corpus.txt';path.write_text('\n'.join(data.hex() for _,data in rows)+'\n')
  bad=root/'errors.txt';bad.write_text('\n'.join(data.hex() for _,data,_ in errors)+'\n')
  inputs={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in (root/'cases.zig',path,bad)}
  log.run([str(zig),'build-exe','-target','aarch64-macos.14.0','-lc','-O',mode,'--global-cache-dir',str(root.parent/'zig-global'),'--cache-dir',str(root/'zig-cache'),'-femit-bin='+str(root/'native'),str(root/'reference.zig')],'build-source',env=env,timeout=args.timeout)
  log.run([str(v),'-enable-globals',*(['-prod'] if args.v_prod else []),'-path',str(repo)+'|@vlib|@vmodules','-o',str(root/'translated'),str(root/'main.v')],'build-v',env=env,timeout=args.timeout)
  outputs=[]
  for exe in ('native','translated'):
   result=log.run([str(root/exe),str(path)],'returning-'+exe,env=env,timeout=args.timeout);assert not result.stderr;outputs.append(result.stdout.splitlines())
  assert len(outputs[0])==len(outputs[1])==len(rows)
  for i,((group,data),a,b) in enumerate(zip(rows,*outputs)):assert a==b==expected(data),(i,group,data,a,b,expected(data))
  digest=hashlib.sha256(b'\n'.join(outputs[0])).hexdigest()
  if EXPECTED_ROWS is not None:assert len(rows)==EXPECTED_ROWS and digest==EXPECTED_SHA256
  result=log.run([str(root/'translated'),str(bad)],'runtime-errors',env=env,timeout=args.timeout);assert not result.stderr;lines=result.stdout.splitlines()
  assert lines==[b'error|'+error.hex().encode() for _,_,error in errors]
  error_digest=hashlib.sha256(b'\n'.join(lines)).hexdigest()
  if EXPECTED_ERRORS is not None:assert len(errors)==EXPECTED_ERRORS and error_digest==EXPECTED_ERROR_SHA256
  boundaries={}
  for name,data,error in invalid_cases():
   ztext='const std=@import("std");const value=std.fmt.Placeholder.parse(&.{'+','.join(str(b) for b in data)+'});pub fn main() void {_=&value;}\n'
   zpath=root/(name+'.zig');zpath.write_text(ztext);inputs[zpath.name]=hashlib.sha256(zpath.read_bytes()).hexdigest()
   result=log.run([str(zig),'build-exe','-target','aarch64-macos.14.0','-lc','-O',mode,'--global-cache-dir',str(root.parent/'zig-global'),'--cache-dir',str(root/'zig-cache'),'-femit-bin='+str(root/name),str(zpath)],name+'-compile',env=env,timeout=args.timeout,check=False)
   ordinary_rejection(result,name);assert error in result.stderr,(name,result.stderr)
   path=root/(name+'.txt');path.write_text(data.hex()+'\n');inputs[path.name]=hashlib.sha256(path.read_bytes()).hexdigest()
   result=log.run([str(root/'translated'),str(path)],name+'-runtime',env=env,timeout=args.timeout,check=False)
   if error==b'overflow':checked_trap(result,name,'integer overflow');boundaries[name]='compile-error/runtime-panic'
   else:assert result.returncode==0 and result.stdout==b'error|'+error.hex().encode()+b'\n' and not result.stderr;boundaries[name]='compile-error/runtime-error'
  pins(source,zig);assert tree_hash(root/'src')==PINNED_SOURCE_SHA256 and implementation_hashes(repo)==impl and hashlib.sha256(Path(__file__).read_bytes()).hexdigest()==driver
  for name,pin in fixtures.items():assert hashlib.sha256((probe/name).read_bytes()).hexdigest()==pin==hashlib.sha256((root/name).read_bytes()).hexdigest()
  for name,pin in helpers.items():assert hashlib.sha256((repo/'zigimg'/name).read_bytes()).hexdigest()==pin
  for name,pin in inputs.items():assert hashlib.sha256((root/name).read_bytes()).hexdigest()==pin
  (root/'provenance.json').write_text(json.dumps(dict(source_sha256=PINNED_SOURCE_SHA256,stdlib_sha256=PINNED_STDLIB_SHA256,extra_libraries=EXTRA_LIBRARIES,integer_libraries=INTEGER_LIBRARIES,io_library_sha256=IO_LIBRARY_SHA256,format_library_sha256=FORMAT_LIBRARY_SHA256,time_library_sha256=TIME_LIBRARY_SHA256,implementation_sha256=impl,runner_sha256=driver,fixtures=fixtures,helpers=helpers,input_sha256=inputs,versions=versions,production=args.v_prod),indent=2)+'\n')
  summary=dict(returning_records=len(rows),returning_groups=dict(Counter(g for g,_ in rows)),output_sha256=digest,runtime_errors=len(errors),runtime_error_groups=dict(Counter(g for g,_,_ in errors)),error_sha256=error_digest,boundaries=boundaries,production=args.v_prod)
  (root/'summary.json').write_text(json.dumps(summary,indent=2)+'\n');print(json.dumps(summary),flush=True)
if __name__=='__main__':main()
