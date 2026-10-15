"""Compare writer rebase, writable reservations, aliases, and retained failures."""
import argparse
from collections import Counter
import hashlib,itertools,json,os,re,shutil
from pathlib import Path
from verify_jpeg_contracts_reference import implementation_hashes
from verify_tiff_decode_reference import ProofLog,tree_hash,work_directory,PINNED_SOURCE_SHA256,checked_trap
from verify_stream_guards_reference import stdlib_hash,PINNED_STDLIB_SHA256
from verify_image_open_reference import PATH_LIBRARIES,path_library_hashes
from verify_image_tty_reference import ENCODER_LIBRARIES,encoder_library_hashes



EXPECTED_ROWS = 10818
EXPECTED_SHA256 = 'f34b9fbd77dc63c6c68894affbeaadb1855435bc3e13414ad215d31c7f149afb'
EXPECTED_CONTROLS = 318
EXPECTED_CONTROL_SHA256 = 'c87d75747b74c4728d76b6da0af797f1476ce5e717dc571cf10b249cd7184d5c'
EXPECTED_TRAPS = 690
EXPECTED_STATE_SHA256 = '411d6eb7ca06c8222fad9d120e9e42c8b76702a1e30300635f2a5a9303c47cab'
MAX_USIZE=(1<<64)-1

def spec(kind=0,cap=8,start=0,prefix=0,preserve=0,count=0,binding=0,finish=0,method=0,mask=91):
 return '|'.join(map(str,(kind,cap,start,prefix,preserve,count,binding,finish,method,mask)))
def initial_end(kind,cap,start,prefix):return (start if kind==0 and start<cap else 0)+prefix

def fields(part):
 status,metadata,buffer,pending,unused,saved,contents=part.split('|');m=list(map(int,metadata.split(':')));assert len(m)==6
 if saved=='-':borrow=None
 else:
  offset,length,encoded=saved.split(':');borrow=(int(offset),int(length),bytes.fromhex(encoded))
 return status,m,bytes.fromhex(buffer),bytes.fromhex(pending),bytes.fromhex(unused),borrow,bytes.fromhex(contents)

def modeled(data):
 kind,cap,start,prefix,preserve,count,binding,finish,method,mask=map(int,data.split('|'))
 end=initial_end(kind,cap,start,prefix);pos=start if kind else 0;mode=kind;wire=bytearray();saved=None
 buffer=bytearray((i*17+165)&255 for i in range(cap));begin=end-prefix;buffer[begin:end]=bytes((i*31+7)&255 for i in range(prefix))
 contents=bytearray((i*37+19)&255 for i in range(32)) if kind and not binding else bytearray()
 def state(status):
  borrow=None if saved is None else (*saved,bytes(buffer[saved[0]:saved[0]+saved[1]]))
  return status,[pos+end,cap-end,end,end,0 if not kind or binding==2 else 1,0 if not kind else (3 if binding==1 else 2)],bytes(buffer),bytes(buffer[:end]),bytes(buffer[end:]),borrow,bytes(contents)
 def drain():
  nonlocal pos,end,mode
  if not end:return 'ok'
  if mode<0 or binding==2:return 'WriteFailed'
  if binding==1 and mode==1:
   mode=2
   if pos:pos=0;mode=-1;return 'WriteFailed'
   return 'ok'
  if binding==1:wire.extend(buffer[:end])
  else:
   if len(contents)<pos+end:contents.extend(bytes(pos+end-len(contents)))
   contents[pos:pos+end]=buffer[:end]
  pos+=end;end=0;return 'ok'
 states=[state('setup')];keep=preserve if method in (0,2,4) else 0;status='ok'
 while cap-end<count:
  if not kind:status='WriteFailed';break
  length=min(end,keep);head=end-length;end=head
  status=drain()
  if status!='ok':end+=length;break
  buffer[end:end+length]=buffer[head:head+length];end+=length
  category='integer overflow' if keep>cap else ('reached unreachable code' if cap-keep<count else None)
  if category:return states,('operation',category,state('operation')),bytes(wire)
 if status=='ok':
  offset=end
  if method in (3,4):end+=count
  if method in (1,2,3,4):saved=(offset,count if method in (3,4) else cap-offset)
 states.append(state(status))
 if cap:buffer[0]^=mask
 states.append(state('caller'))
 if saved and saved[1]:buffer[saved[0]+saved[1]-1]^=mask
 states.append(state('saved'));status='skip'
 if finish:
  status='ok'
  if kind:
   while end:
    status=drain()
    if status!='ok':break
 states.append(state(status));return states,None,bytes(wire)

def candidates():
 for kind,cap,start in itertools.product(range(3),(0,1,8,16),(0,3)):
  begin=initial_end(kind,cap,start,0)
  for prefix in sorted({0,(cap-begin)//2,cap-begin}):
   end=begin+prefix
   for method in range(6):
    for preserve in (sorted({0,1,end,cap+1,MAX_USIZE}) if method in (0,2,4) else (0,)):
     for count in sorted({0,1,cap-end,cap-end+1,cap+1}):
      for binding in ((0,) if kind==0 else (0,1,2)):
       for finish in ((0,1) if binding==0 else (0,)):
        yield 'reservations',spec(kind,cap,start,prefix,preserve,count,binding,finish,method)

def corpus():
 rows=[];seen=set()
 for group,data in candidates():
  if data not in seen and modeled(data)[1] is None:seen.add(data);rows.append((group,data))
 for kind,method,mask in itertools.product(range(3),range(1,5),range(256)):
  data=spec(kind,8,prefix=6,preserve=2,count=3,finish=1,method=method,mask=mask)
  if data not in seen:seen.add(data);rows.append(('every-byte',data))
 return rows

def controls():
 rows=[];seen=set()
 for kind,cap,start in itertools.product(range(3),(0,8),(0,3)):
  begin=initial_end(kind,cap,start,0)
  for prefix in sorted({0,cap-begin}):
   for method,preserve,count in itertools.product((0,2,4),(0,cap+1,MAX_USIZE),(1,cap+1,MAX_USIZE)):
    for binding in ((0,) if kind==0 else (0,1,2)):
     data=spec(kind,cap,start,prefix,preserve,count,binding,method=method)
     if data not in seen:
      seen.add(data);trap=modeled(data)[1];rows.append((f'boundary-{len(rows)}',data,trap[1] if trap else None))
 return rows

def snapshot_checks(line,data):
 kind,cap,start,prefix,preserve,count,binding,finish,method,mask=map(int,data.split('|'));parts=line.decode().split('~');assert len(parts)==6
 states=[fields(part) for part in parts[:-1]];model,trap,wire=modeled(data)
 assert trap is None and states==model,'independent reservation/drain/alias state differs'
 assert parts[-1]==('-1:'+wire.hex() if kind and binding==1 else '-3:')
 for status,m,buffer,pending,unused,saved,contents in states:
  assert len(buffer)==cap and 0<=m[2]<=cap and m[1]==cap-m[2] and m[3]==m[2] and pending==buffer[:m[2]] and unused==buffer[m[2]:]
  if saved:assert 0<=saved[0]<=cap and saved[1]<=cap-saved[0] and saved[2]==buffer[saved[0]:saved[0]+saved[1]]

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
    if tree_hash(source)!=PINNED_SOURCE_SHA256 or stdlib_hash(zig)!=PINNED_STDLIB_SHA256 or path_library_hashes(zig)!=PATH_LIBRARIES or encoder_library_hashes(zig)!=ENCODER_LIBRARIES:parser.error('Source/compiler library differs from pins')
    repo=Path(__file__).resolve().parent.parent;probe=repo/'zigimg/reference_probes/writer_reserve';mode='ReleaseSafe' if args.v_prod else 'Debug'
    with work_directory(args.workdir,'witty-writer-reserve-') as root:
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
        print(f'Building writer reservation operations: Source {mode}, V {"production" if args.v_prod else "ordinary"}',flush=True)
        proof.run([str(zig),'build-exe','-target',args.target,'-lc','-I',str(root),'-O',mode,'--global-cache-dir',str(root.parent/'zig-global'),'--cache-dir',str(root/'zig-cache'),'-femit-bin='+str(root/'native'),str(root/'reference.zig'),str(root/'fixture_shims.c')],'build-source',env=env,timeout=args.timeout)
        proof.run([str(v),'-enable-globals',*(['-prod'] if args.v_prod else []),'-path',f'{repo}|@vlib|@vmodules','-o',str(root/'translated'),str(root/'main.v')],'build-v',env=env,timeout=args.timeout)
        rows=corpus();path=root/'corpus.txt';path.write_text('\n'.join(data for _,data in rows)+'\n');inputs={'corpus.txt':hashlib.sha256(path.read_bytes()).hexdigest()};(root/'input_sha256.json').write_text(json.dumps(inputs,indent=2)+'\n')
        outputs=[]
        for exe in ('native','translated'):
            result=proof.run([str(root/exe),str(path)],'returning-'+exe,env=env,timeout=args.timeout)
            if result.stderr or len(result.stdout.splitlines())!=len(rows):raise AssertionError('invalid returning output')
            outputs.append(result.stdout.splitlines())
        for i,((group,data),native,translated) in enumerate(zip(rows,*outputs)):
            if native!=translated:raise AssertionError(f'{i}/{group}: writer reservation record differs; see retained proof')
            snapshot_checks(native,data)
        digest=hashlib.sha256(b'\n'.join(outputs[0])).hexdigest()
        if EXPECTED_ROWS is not None and (len(rows)!=EXPECTED_ROWS or digest!=EXPECTED_SHA256):raise AssertionError('returning golden changed')
        returns=hashlib.sha256();states=hashlib.sha256();return_count=0;trap_count=0
        print(f'{len(rows)} returning writer reservation records match; checking failure controls',flush=True)
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
        summary=dict(returning_records=len(rows),reservation_calls=len(rows),methods=dict(Counter(int(data.split("|")[8]) for _,data in rows)),returning_groups=dict(Counter(group for group,_ in rows)),output_sha256=digest,return_controls=return_count,control_sha256=returns.hexdigest(),paired_traps=trap_count,state_sha256=states.hexdigest(),zig_mode=mode,v_prod=args.v_prod)
        (root/'summary.json').write_text(json.dumps(summary,indent=2)+'\n');print(json.dumps(summary),flush=True)

if __name__=='__main__':main()
