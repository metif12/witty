"""Compare byte-character and codepoint printValue dispatch and exact retained writer failures."""
import argparse
from collections import Counter
import hashlib,itertools,json,os,re,shutil
from pathlib import Path
import verify_writer_text_reference as text
from verify_writer_text_reference import TEXT_LIBRARIES,text_library_hashes
from verify_writer_float_reference import (FLOAT_LIBRARIES,float_library_hashes,TIME_LIBRARY_SHA256,time_library_hash,INTEGER_LIBRARIES,integer_library_hashes,FORMAT_LIBRARY_SHA256,format_library_hash,IO_LIBRARY_SHA256,io_library_hash,MAX_USIZE,fields)
from verify_jpeg_contracts_reference import implementation_hashes
from verify_tiff_decode_reference import ProofLog,tree_hash,work_directory,PINNED_SOURCE_SHA256,checked_trap
from verify_stream_guards_reference import stdlib_hash,PINNED_STDLIB_SHA256
from verify_image_open_reference import PATH_LIBRARIES,path_library_hashes
from verify_image_tty_reference import ENCODER_LIBRARIES,encoder_library_hashes

EXPECTED_ROWS = 39449
EXPECTED_SHA256 = '06c81d54a106939938cbb5465d8ad1f1cf7aa6bf9ffabcdb03dab7efa00bcb74'
EXPECTED_CONTROLS = 360
EXPECTED_CONTROL_SHA256 = 'b78a3c828e0f7d3c301a60f4b5cd320814a421faa98debe49ad17904c0b6a727'
EXPECTED_TRAPS = 368
EXPECTED_STATE_SHA256 = '31833d2705234a3eae9fe4bf4fa5dd27fc8b198099bc208ad38517cf24b00568'
BITS=(8,16,32,8,16,32)
ModelLimit=text.ModelLimit

def spec(kind=0,cap=8,start=0,prefix=0,binding=0,finish=1,format=0,fill=91,alignment=0,width=0,present=1,precision=None,raw=0,tag=1,depth=0):
 return '|'.join(map(str,(kind,cap,start,prefix,binding,finish,format,fill,alignment,width,present,'-' if precision is None else precision,raw&((1<<BITS[tag])-1),tag,depth)))

initial_end=text.initial_end
ModelTrap=text.ModelTrap
WriteFailed=text.WriteFailed

def modeled(data):
 f=data.split('|');kind,cap,start,prefix,binding,finish,format,fill,alignment,width,present=map(int,f[:11]);precision=None if f[11]=='-' else int(f[11]);raw,tag,depth=map(int,f[12:]);assert format in (0,1) and (format==1 or tag in (0,3))
 end=initial_end(kind,cap,start,prefix);pos=start if kind else 0;mode=kind;wire=bytearray();calls=0
 buffer=bytearray((i*17+165)&255 for i in range(cap));begin=end-prefix;buffer[begin:end]=bytes((i*31+7)&255 for i in range(prefix))
 payload=raw.to_bytes(8,'little');spans=((0,8),);opts=(precision,width if present else None,alignment,fill,tag,format,depth)
 source=bytes([raw]) if format==0 else b''
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
  if format==0:
   if padding==0:write_all(source)
   elif alignment==0:write_all(source);splat_all(padding)
   elif alignment==1:
    left=padding//2
    if padding==MAX_USIZE:raise ModelTrap('integer overflow')
    right=(padding+1)//2;splat_all(left);write_all(source);splat_all(right)
   else:splat_all(padding);write_all(source)
  else:
   if raw>0x1fffff:raise ModelTrap('integer does not fit in destination type')
   c=0xfffd if raw>0x10ffff or 0xd800<=raw<=0xdfff else raw
   write_all(chr(c).encode('utf-8'))
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

def from_text(data,tag,depth):
 f=data.split('|');kind,cap,start,prefix,length,width,binding,finish,api,fill,alignment,present=map(int,f[:12]);precision=None if f[12]=='-' else int(f[12]);raw=fill if api==0 else int(f[13]);assert api in (0,2)
 return spec(kind,cap,start,prefix,binding,finish,int(api==2),fill,alignment,width,present,precision,raw,tag,depth)

def candidates():
 rows=[]
 for i,(group,data) in enumerate(text.corpus()):
  f=data.split('|');api=int(f[8])
  if api not in (0,2):continue
  tag=(0,3)[i%2] if api==0 else (2,5)[i%2]
  rows.append(('helper-'+group,from_text(data,tag,(0,1,MAX_USIZE)[i%3])))
 for raw,tag,kind,alignment,width in itertools.product(range(256),(0,3),range(3),range(3),(0,1,2,5)):
  rows.append(('every-byte-and-padding',spec(raw=raw,tag=tag,kind=kind,alignment=alignment,width=width,format=0,fill=(raw*17+11)%256,depth=(0,1,MAX_USIZE)[raw%3],precision=(None,0,MAX_USIZE)[raw%3])))
 for tag in (1,4):
  for raw in range(0,65536,17):rows.append(('native-u16-samples',spec(raw=raw,tag=tag,format=1,kind=raw%3,cap=4,width=MAX_USIZE,precision=MAX_USIZE,depth=MAX_USIZE)))
 edges=(0,0x7f,0x80,0x7ff,0x800,0xd7ff,0xd800,0xdfff,0xe000,0xffff,0x10000,0x10ffff,0x110000,0x1fffff)
 for tag,depth,kind,cap in itertools.product(range(6),(0,1,MAX_USIZE),range(3),(0,1,2,3,4,8)):
  for raw in edges:
   if raw>=1<<BITS[tag]:continue
   rows.append(('carriers-depth-and-ignored-options',spec(raw=raw,tag=tag,format=1,depth=depth,kind=kind,cap=cap,width=MAX_USIZE,precision=MAX_USIZE,alignment=raw%3,fill=(raw*23+7)%256)))
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
 for i,(label,data,_) in enumerate(text.controls()):
  f=data.split('|');api=int(f[8])
  if api==0:
   for tag in (0,3):add('character-'+label,from_text(data,tag,(0,1,MAX_USIZE)[i%3]))
  elif api==2:
   for tag in (2,5):add('u21-conversion-'+label,from_text(data,tag,(0,1,MAX_USIZE)[i%3]))
 for (kind,cap,start,prefix,binding),tag,raw in itertools.product(text.states(),(2,5),(0x200000,0xffffffff)):
  if cap not in (0,8):continue
  add('u21-before-options',spec(kind=kind,cap=cap,start=start,prefix=prefix,binding=binding,tag=tag,raw=raw,format=1,width=MAX_USIZE,precision=MAX_USIZE,depth=MAX_USIZE,alignment=1))
 return result

def snapshot_checks(line,data):
 parts=line.decode().split('~');assert len(parts)==6
 states=[fields(part) for part in parts[:-1]];model,trap,wire=modeled(data)
 assert trap is None and states==model,'independent value text dispatch/rendering/writer state differs'
 f=list(map(int,data.split('|')[:11]));assert parts[-1]==('-1:'+wire.hex() if f[0] and f[4]==1 else '-3:')

def classify(native,translated,name,data,category,paths):
 if native.returncode==0:
  assert category is None and translated.returncode==0 and native.stdout==translated.stdout and native.stdout and not native.stderr+translated.stderr
  snapshot_checks(native.stdout.strip(),data);return 'return',native.stdout
 for result in (native,translated):
  checked_trap(result,name,category)
  messages=[m.group(1) for line in result.stderr.decode().splitlines() if (m:=re.fullmatch(r'(?:thread \d+ |V )?panic:\s*(.*)',line.strip()))];assert messages==[category]
 states=[p.read_bytes() for p in paths];assert states[0] and states[0]==states[1]
 _,trap,_=modeled(data);assert trap is not None and trap[1]==category and fields(states[0].decode())==trap[2],'value text dispatch retained failure state differs'
 return 'trap',category.encode()+b'\0'+states[0]+b'\n'

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source',type=Path);parser.add_argument('zig',type=Path);parser.add_argument('v',type=Path)
    parser.add_argument('--target',default='aarch64-macos.14.0');parser.add_argument('--v-prod',action='store_true');parser.add_argument('--workdir',type=Path);parser.add_argument('--timeout',type=int,default=600)
    args=parser.parse_args()
    if args.timeout<=0:parser.error('--timeout must be positive')
    source=args.source.resolve()/'src';zig=args.zig.resolve();v=args.v.resolve()
    if text_library_hashes(zig)!=TEXT_LIBRARIES or tree_hash(source)!=PINNED_SOURCE_SHA256 or float_library_hashes(zig)!=FLOAT_LIBRARIES or time_library_hash(zig)!=TIME_LIBRARY_SHA256 or integer_library_hashes(zig)!=INTEGER_LIBRARIES or format_library_hash(zig)!=FORMAT_LIBRARY_SHA256 or io_library_hash(zig)!=IO_LIBRARY_SHA256 or stdlib_hash(zig)!=PINNED_STDLIB_SHA256 or path_library_hashes(zig)!=PATH_LIBRARIES or encoder_library_hashes(zig)!=ENCODER_LIBRARIES:parser.error('Source/compiler library differs from pins')
    repo=Path(__file__).resolve().parent.parent;probe=repo/'zigimg/reference_probes/writer_value_text';mode='ReleaseSafe' if args.v_prod else 'Debug'
    with work_directory(args.workdir,'witty-writer-value-text-') as root:
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
        helpers={name:hashlib.sha256((repo/'zigimg'/name).read_bytes()).hexdigest() for name in ('verify_writer_text_reference.py','verify_writer_float_reference.py','verify_float_decimal_reference.py','verify_float_render_reference.py','verify_writer_float_hex_reference.py','verify_jpeg_contracts_reference.py','verify_tiff_decode_reference.py','verify_stream_guards_reference.py','verify_image_open_reference.py','verify_image_tty_reference.py')}
        (root/'provenance.json').write_text(json.dumps(dict(text_libraries=TEXT_LIBRARIES,float_libraries=FLOAT_LIBRARIES,source_sha256=PINNED_SOURCE_SHA256,stdlib_sha256=PINNED_STDLIB_SHA256,io_library_sha256=IO_LIBRARY_SHA256,format_library_sha256=FORMAT_LIBRARY_SHA256,integer_libraries=INTEGER_LIBRARIES,time_library_sha256=TIME_LIBRARY_SHA256,path_libraries=PATH_LIBRARIES,encoder_libraries=ENCODER_LIBRARIES,versions=versions,target=args.target,zig_mode=mode,v_prod=args.v_prod,implementation_sha256=impl,runner_sha256=runner_hash,fixtures=fixtures,helper_sha256=helpers,shared_fixture_sha256=shared_hash),indent=2)+'\n')
        print(f'Building character/codepoint value-dispatch operations: Source {mode}, V {"production" if args.v_prod else "ordinary"}',flush=True)
        proof.run([str(zig),'build-exe','-target',args.target,'-lc','-I',str(root),'-O',mode,'--global-cache-dir',str(root.parent/'zig-global'),'--cache-dir',str(root/'zig-cache'),'-femit-bin='+str(root/'native'),str(root/'reference.zig'),str(root/'fixture_shims.c')],'build-source',env=env,timeout=args.timeout)
        proof.run([str(v),'-enable-globals',*(['-prod'] if args.v_prod else []),'-path',f'{repo}|@vlib|@vmodules','-o',str(root/'translated'),str(root/'main.v')],'build-v',env=env,timeout=args.timeout)
        rows=corpus();path=root/'corpus.txt';path.write_text('\n'.join(data for _,data in rows)+'\n');inputs={'corpus.txt':hashlib.sha256(path.read_bytes()).hexdigest()};(root/'input_sha256.json').write_text(json.dumps(inputs,indent=2)+'\n')
        outputs=[]
        for exe in ('native','translated'):
            result=proof.run([str(root/exe),str(path)],'returning-'+exe,env=env,timeout=args.timeout)
            if result.stderr or len(result.stdout.splitlines())!=len(rows):raise AssertionError('invalid returning output')
            outputs.append(result.stdout.splitlines())
        for i,((group,data),native,translated) in enumerate(zip(rows,*outputs)):
            if native!=translated:raise AssertionError(f'{i}/{group}: character/codepoint value-dispatch record differs; see retained proof')
            snapshot_checks(native,data)
        digest=hashlib.sha256(b'\n'.join(outputs[0])).hexdigest()
        if EXPECTED_ROWS is not None and (len(rows)!=EXPECTED_ROWS or digest!=EXPECTED_SHA256):raise AssertionError('returning golden changed')
        returns=hashlib.sha256();states=hashlib.sha256();return_count=0;trap_count=0
        print(f'{len(rows)} returning character/codepoint value-dispatch records match; checking failure controls',flush=True)
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
        if text_library_hashes(zig)!=TEXT_LIBRARIES or tree_hash(source)!=PINNED_SOURCE_SHA256 or tree_hash(root/'src')!=PINNED_SOURCE_SHA256 or float_library_hashes(zig)!=FLOAT_LIBRARIES or time_library_hash(zig)!=TIME_LIBRARY_SHA256 or integer_library_hashes(zig)!=INTEGER_LIBRARIES or format_library_hash(zig)!=FORMAT_LIBRARY_SHA256 or io_library_hash(zig)!=IO_LIBRARY_SHA256 or stdlib_hash(zig)!=PINNED_STDLIB_SHA256 or path_library_hashes(zig)!=PATH_LIBRARIES or encoder_library_hashes(zig)!=ENCODER_LIBRARIES or implementation_hashes(repo)!=impl or hashlib.sha256(Path(__file__).read_bytes()).hexdigest()!=runner_hash:raise AssertionError('dependency/implementation/runner changed')
        for name,pin in fixtures.items():
            if any(hashlib.sha256((base/name).read_bytes()).hexdigest()!=pin for base in (root,probe)):raise AssertionError('fixture changed')
        for name,pin in inputs.items():
            if hashlib.sha256((root/name).read_bytes()).hexdigest()!=pin:raise AssertionError('input changed')
        for name,pin in helpers.items():
            if hashlib.sha256((repo/'zigimg'/name).read_bytes()).hexdigest()!=pin:raise AssertionError('helper changed')
        for directory,pin in shared_hash.items():
            if any(hashlib.sha256(p.read_bytes()).hexdigest()!=pin for p in (root/directory/'fixture_shims.h',repo/'zigimg/reference_probes'/directory/'fixture_shims.h')):raise AssertionError('shared fixture changed')
        if list(root.glob('*.owned*')):raise AssertionError('owned paths survived')
        summary=dict(conversion_traps=sum(category is not None and int(data.split('|')[6])==1 for _,data,category in controls()),body_traps=sum(category is not None and int(data.split('|')[6])==0 for _,data,category in controls()),returning_records=len(rows),primary_calls=len(rows),formats=dict(Counter(int(data.split('|')[6]) for _,data in rows)),types=dict(Counter(int(data.split('|')[13]) for _,data in rows)),returning_groups=dict(Counter(group for group,_ in rows)),output_sha256=digest,return_controls=return_count,control_sha256=returns.hexdigest(),paired_traps=trap_count,state_sha256=states.hexdigest(),zig_mode=mode,v_prod=args.v_prod)
        (root/'summary.json').write_text(json.dumps(summary,indent=2)+'\n');print(json.dumps(summary),flush=True)

if __name__=='__main__':main()
