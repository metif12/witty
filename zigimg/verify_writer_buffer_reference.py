"""Compare borrowed writer capacity, cursor updates, aliases, and retained traps."""
import argparse
from collections import Counter
import hashlib,itertools,json,os,re,shutil
from pathlib import Path
from verify_jpeg_contracts_reference import implementation_hashes
from verify_tiff_decode_reference import ProofLog,tree_hash,work_directory,PINNED_SOURCE_SHA256,checked_trap
from verify_stream_guards_reference import stdlib_hash,PINNED_STDLIB_SHA256
from verify_image_open_reference import PATH_LIBRARIES,path_library_hashes
from verify_image_tty_reference import ENCODER_LIBRARIES,encoder_library_hashes


EXPECTED_ROWS = 18780
EXPECTED_SHA256 = 'ffd1e1efba45cba2338d104b5c38056127462b68fceb276955f8b302a0ed36e4'
EXPECTED_CONTROLS = 0
EXPECTED_CONTROL_SHA256 = 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'
EXPECTED_TRAPS = 308
EXPECTED_STATE_SHA256 = '4d07ca84c311b5dee2c4966301333f4e6778ccccacecea15a6577f15351446d3'
MAX_USIZE=(1<<64)-1

def spec(kind=0,cap=8,start=0,prefix=0,advance=0,undo=0,binding=0,finish=0,mode=1,mask=91):
 return '|'.join(map(str,(kind,cap,start,prefix,advance,undo,binding,finish,mode,mask)))
def initial_end(kind,cap,start,prefix):return (start if kind==0 and start<cap else 0)+prefix

def corpus():
 rows=[]
 for kind,cap,start in itertools.product(range(3),(0,1,8,16),(0,1,7)):
  begin=initial_end(kind,cap,start,0)
  for prefix in sorted({0,min(1,cap-begin),min(4,cap-begin),cap-begin}):
   end=begin+prefix
   for advance in sorted({0,min(1,cap-end),(cap-end)//2,cap-end}):
    for undo in sorted({0,min(1,end+advance),(end+advance)//2,end+advance}):
     for binding in ((0,) if kind==0 else (0,1,2)):
      for finish in ((0,) if binding==2 else (0,1,2)):
       for mode,mask in ((0,0),(1,91),(2,255)):
        rows.append(('buffers',spec(kind,cap,start,prefix,advance,undo,binding,finish,mode,mask)))
 for kind,cap,mode,mask in itertools.product(range(3),(1,8),(1,2),range(256)):
  for prefix in sorted({0,cap-1}):rows.append(('every-byte',spec(kind,cap,prefix=prefix,mode=mode,mask=mask)))
 seen=set();result=[]
 for group,data in rows:
  if data not in seen:seen.add(data);result.append((group,data))
 return result

def controls():
 rows=[];seen=set()
 for kind,cap,start in itertools.product(range(3),(0,1,8),(0,7)):
  begin=initial_end(kind,cap,start,0)
  for prefix in sorted({0,cap-begin}):
   end=begin+prefix;remaining=cap-end
   for binding in ((0,) if kind==0 else (0,1,2)):
    cases=[('capacity',remaining+1,0,'reached unreachable code'),('add-overflow',MAX_USIZE,0,'integer overflow' if end else 'reached unreachable code'),('subtract',0,end+1,'integer overflow'),('after-full',remaining,cap+1,'integer overflow'),('subtract-max',0,MAX_USIZE,'integer overflow')]
    for label,advance,undo,category in cases:
     data=spec(kind,cap,start,prefix,advance,undo,binding)
     if data not in seen:
      seen.add(data);rows.append((f'{label}-{kind}-{cap}-{start}-{prefix}-{binding}',data,category))
 return rows

def fields(part):
 status,metadata,buffer,pending,unused,saved,contents=part.split('|');m=list(map(int,metadata.split(':')));assert len(m)==6
 if saved=='-':borrow=None
 else:
  offset,length,encoded=saved.split(':');borrow=(int(offset),int(length),bytes.fromhex(encoded))
 return status,m,bytes.fromhex(buffer),bytes.fromhex(pending),bytes.fromhex(unused),borrow,bytes.fromhex(contents)

def modeled(data):
 kind,cap,start,prefix,advance,undo,binding,finish,mode,mask=map(int,data.split('|'))
 end=initial_end(kind,cap,start,0);pos=start if kind else 0
 buffer=bytearray((i*17+165)&255 for i in range(cap));buffer[end:end+prefix]=bytes((i*31+7)&255 for i in range(prefix));end+=prefix
 contents=bytearray((i*37+19)&255 for i in range(32)) if kind and not binding else bytearray();saved=None
 def state(status):
  borrow=None if saved is None else (saved,cap-saved,bytes(buffer[saved:]))
  return status,[pos+end,cap-end,end,end,0 if not kind or binding==2 else 1,0 if not kind else (3 if binding==1 else 2)],bytes(buffer),bytes(buffer[:end]),bytes(buffer[end:]),borrow,bytes(contents)
 def change(offset,length):
  if mode and length:buffer[offset+(0 if mode==1 else length-1)]^=mask
 states=[state('setup')];saved=end;states.append(state('borrow'));change(0,cap);states.append(state('caller'));change(saved,cap-saved);states.append(state('saved'))
 if advance>MAX_USIZE-end:return states,('advance','integer overflow')
 if end+advance>cap:return states,('advance','reached unreachable code')
 end+=advance;states.append(state('advance'))
 if undo>end:return states,('undo','integer overflow')
 end-=undo;states.append(state('undo'));change(end,cap-end);states.append(state('unused'))
 # Replaced pipes retain full native comparison; pure buffer phases have this exact model.
 if binding and finish:return states,None
 def output(b):
  nonlocal pos
  if len(contents)<pos+len(b):contents.extend(bytes(pos+len(b)-len(contents)))
  contents[pos:pos+len(b)]=b;pos+=len(b)
 def write(b):
  nonlocal end
  if len(b)<=cap-end:buffer[end:end+len(b)]=b;end+=len(b);return 'ok'
  if not kind:
   n=cap-end;buffer[end:cap]=b[:n];end=cap;return 'WriteFailed'
  if kind==1 and end:output(buffer[:end]);end=0;return write(b)
  output(bytes(buffer[:end])+b);end=0;return 'ok'
 status=write(bytes((209,210))) if finish==1 else 'skip';states.append(state(status))
 status='skip'
 if finish:
  status='ok'
  if kind and end:output(buffer[:end]);end=0
 states.append(state(status));return states,None

def snapshot_checks(line,data):
 f=list(map(int,data.split('|')));kind,cap,start,prefix,advance,undo,binding,finish,mode,mask=f;parts=line.decode().split('~');assert len(parts)==10
 states=[fields(part) for part in parts[:-1]]
 for i,(status,m,buffer,pending,unused,saved,contents) in enumerate(states):
  assert len(buffer)==cap and 0<=m[2]<=cap and m[1]==cap-m[2] and m[3]==m[2] and pending==buffer[:m[2]] and unused==buffer[m[2]:] and m[0]>=m[2]
  assert m[4:]==([0,0] if not kind else ([0,2] if binding==2 else [1,3 if binding==1 else 2]))
  if i==0:assert saved is None
  else:assert saved is not None and 0<=saved[0]<=cap and saved[1]==cap-saved[0] and saved[2]==buffer[saved[0]:]
  assert status in ('setup','borrow','caller','saved','advance','undo','unused','skip','ok','WriteFailed')
  assert not contents if not kind or binding else len(contents)>=32
 model,trap=modeled(data);assert trap is None and states[:len(model)]==model,'independent buffer/alias state differs'
 assert parts[-1].split(':',1)[0]==('-1' if kind and binding==1 else '-3')

def classify(native,translated,name,data,category,paths):
 if native.returncode==0:
  assert translated.returncode==0 and native.stdout==translated.stdout and native.stdout and not native.stderr+translated.stderr
  snapshot_checks(native.stdout.strip(),data);return 'return',native.stdout
 for result in (native,translated):
  checked_trap(result,name,category)
  messages=[m.group(1) for line in result.stderr.decode().splitlines() if (m:=re.fullmatch(r'(?:thread \d+ |V )?panic:\s*(.*)',line.strip()))];assert messages==[category]
 states=[p.read_bytes() for p in paths];assert states[0] and states[0]==states[1]
 before,trap=modeled(data);assert trap is not None and trap[1]==category
 expected=(trap[0],)+before[-1][1:];assert fields(states[0].decode())==expected,'cursor failure mutated its pre-call state'
 return 'trap',category.encode()+b'\0'+states[0]+b'\n'

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source',type=Path);parser.add_argument('zig',type=Path);parser.add_argument('v',type=Path)
    parser.add_argument('--target',default='aarch64-macos.14.0');parser.add_argument('--v-prod',action='store_true');parser.add_argument('--workdir',type=Path);parser.add_argument('--timeout',type=int,default=600)
    args=parser.parse_args()
    if args.timeout<=0:parser.error('--timeout must be positive')
    source=args.source.resolve()/'src';zig=args.zig.resolve();v=args.v.resolve()
    if tree_hash(source)!=PINNED_SOURCE_SHA256 or stdlib_hash(zig)!=PINNED_STDLIB_SHA256 or path_library_hashes(zig)!=PATH_LIBRARIES or encoder_library_hashes(zig)!=ENCODER_LIBRARIES:parser.error('Source/compiler library differs from pins')
    repo=Path(__file__).resolve().parent.parent;probe=repo/'zigimg/reference_probes/writer_buffer';mode='ReleaseSafe' if args.v_prod else 'Debug'
    with work_directory(args.workdir,'witty-writer-buffer-') as root:
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
        print(f'Building writer buffer operations: Source {mode}, V {"production" if args.v_prod else "ordinary"}',flush=True)
        proof.run([str(zig),'build-exe','-target',args.target,'-lc','-I',str(root),'-O',mode,'--global-cache-dir',str(root.parent/'zig-global'),'--cache-dir',str(root/'zig-cache'),'-femit-bin='+str(root/'native'),str(root/'reference.zig'),str(root/'fixture_shims.c')],'build-source',env=env,timeout=args.timeout)
        proof.run([str(v),'-enable-globals',*(['-prod'] if args.v_prod else []),'-path',f'{repo}|@vlib|@vmodules','-o',str(root/'translated'),str(root/'main.v')],'build-v',env=env,timeout=args.timeout)
        rows=corpus();path=root/'corpus.txt';path.write_text('\n'.join(data for _,data in rows)+'\n');inputs={'corpus.txt':hashlib.sha256(path.read_bytes()).hexdigest()};(root/'input_sha256.json').write_text(json.dumps(inputs,indent=2)+'\n')
        outputs=[]
        for exe in ('native','translated'):
            result=proof.run([str(root/exe),str(path)],'returning-'+exe,env=env,timeout=args.timeout)
            if result.stderr or len(result.stdout.splitlines())!=len(rows):raise AssertionError('invalid returning output')
            outputs.append(result.stdout.splitlines())
        for i,((group,data),native,translated) in enumerate(zip(rows,*outputs)):
            if native!=translated:raise AssertionError(f'{i}/{group}: writer buffer record differs; see retained proof')
            snapshot_checks(native,data)
        digest=hashlib.sha256(b'\n'.join(outputs[0])).hexdigest()
        if EXPECTED_ROWS is not None and (len(rows)!=EXPECTED_ROWS or digest!=EXPECTED_SHA256):raise AssertionError('returning golden changed')
        returns=hashlib.sha256();states=hashlib.sha256();return_count=0;trap_count=0
        print(f'{len(rows)} returning writer buffer records match; checking failure controls',flush=True)
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
        summary=dict(returning_records=len(rows),cursor_calls=2*len(rows),borrow_calls=2*len(rows),output_calls=sum(2 if int(data.split("|")[7])==1 else (1 if int(data.split("|")[7])==2 else 0) for _,data in rows),returning_groups=dict(Counter(group for group,_ in rows)),output_sha256=digest,return_controls=return_count,control_sha256=returns.hexdigest(),paired_traps=trap_count,state_sha256=states.hexdigest(),zig_mode=mode,v_prod=args.v_prod)
        (root/'summary.json').write_text(json.dumps(summary,indent=2)+'\n');print(json.dumps(summary),flush=True)

if __name__=='__main__':main()
