"""Compare signed/unsigned LEB128 writes, buffering, and pre-write negative traps."""
import argparse
from collections import Counter
import hashlib,itertools,json,os,re,shutil
from pathlib import Path
from verify_jpeg_contracts_reference import implementation_hashes
from verify_tiff_decode_reference import ProofLog,tree_hash,work_directory,PINNED_SOURCE_SHA256,checked_trap
from verify_stream_guards_reference import stdlib_hash,PINNED_STDLIB_SHA256
from verify_image_open_reference import PATH_LIBRARIES,path_library_hashes
from verify_image_tty_reference import ENCODER_LIBRARIES,encoder_library_hashes

EXPECTED_ROWS = 24072
EXPECTED_SHA256 = 'a1336a859f9a6a5f0320c187b0fd83492efe76ad8c796b7fc6e5a719995bb784'
EXPECTED_CONTROLS = 0
EXPECTED_CONTROL_SHA256 = 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'
EXPECTED_TRAPS = 840
EXPECTED_STATE_SHA256 = '04447613b0255c370ff3ff2cb68aeb35249788fe2e8456becf77c68ae1414d2a'


BITS=(8,16,32,64,64,8,16,32,64,64)*2
NEGATIVE_PANIC='integer does not fit in destination type'
def signed(tag):return tag%10>=5
def value_of(tag,raw):
 bits=BITS[tag];n=raw&((1<<bits)-1)
 return n-(1<<bits) if signed(tag) and n>>(bits-1) else n
def encoding(tag,op,raw):
 n=value_of(tag,raw)
 if op==1 and n<0:return None
 signed_encoding=op==2 or (op==0 and signed(tag))
 count=max(1,(((n if n>=0 else ~n).bit_length()+(1 if signed_encoding else 0))+6)//7)
 return bytes(((n>>(7*i))&127)|(128 if i+1<count else 0) for i in range(count))
def spec(kind=0,cap=8,start=0,prefix=b'',tag=0,op=0,value=0,replacement=0,seek=0):
 raw=value&((1<<BITS[tag])-1)
 return f'{kind}|{cap}|{start}|{prefix.hex()}|{tag}|{op}|{raw}|{replacement}|{seek}'
def corpus():
 rows=[]
 for tag,op,kind,cap,prefix in itertools.product(range(20),range(3),range(3),(0,1,8,16),(b'',b'\xab')):
  bits=BITS[tag];maximum=(1<<(bits-int(signed(tag))))-1
  values={0,1,63,64,127,128,maximum}
  if signed(tag):values|={-1,-64,-65,-(1<<(bits-1))}
  for value in sorted(values):
   if not -(1<<(bits-1))<=value<=maximum or (not signed(tag) and value<0) or (op==1 and value<0):continue
   rows.append(('basic',spec(kind,cap,prefix=prefix,tag=tag,op=op,value=value)))
 for tag,op,kind,raw in itertools.product((0,5,10,15),range(3),range(3),range(256)):
  if op==1 and value_of(tag,raw)<0:continue
  rows.append(('every-byte',spec(kind,8,tag=tag,op=op,value=raw)))
 for tag,op,kind in itertools.product(range(20),range(3),range(3)):
  bits=BITS[tag];minimum=-(1<<(bits-1)) if signed(tag) else 0;maximum=(1<<(bits-int(signed(tag))))-1
  values=set()
  for shift in range(6,bits,7):
   for n in ((1<<shift)-1,1<<shift,(1<<shift)+1,-(1<<shift)-1,-(1<<shift),-(1<<shift)+1):
    if minimum<=n<=maximum and not (op==1 and n<0):values.add(n)
  for value in sorted(values):rows.append(('groups-of-seven',spec(kind,8,start=1,prefix=b'\xab\xcd',tag=tag,op=op,value=value,seek=2)))
 for tag,op,kind,cap,start,prefix in itertools.product((0,3,5,8,10,13,15,18),range(3),(1,2),(0,1,8),(0,1),(b'',b'\xab\xcd')):
  value=-65 if signed(tag) and op!=1 else (1<<(BITS[tag]-int(signed(tag))))-1
  rows.append(('replacement',spec(kind,cap,start,prefix,tag,op,value,1,7)))
 seen=set();result=[]
 for group,data in rows:
  if data not in seen:seen.add(data);result.append((group,data))
 return result
def controls():
 rows=[]
 for tag,kind,cap,prefix,replacement in itertools.product((5,6,7,8,9,15,16,17,18,19),range(3),(0,1,8),(b'',b'\xab'),(0,1,2)):
  if kind==0 and replacement:continue
  for value in sorted({-1,-(1<<(BITS[tag]-1))}):
   name=f'negative-{tag}-{kind}-{cap}-{len(prefix)}-{replacement}-{value}'
   rows.append((name,spec(kind,cap,prefix=prefix,tag=tag,op=1,value=value,replacement=replacement),NEGATIVE_PANIC))
 return rows

def fields(part,panic=False):
 status,metadata,buffer,pending,contents=part.split('|');m=list(map(int,metadata.split(':')))
 assert len(m)==3
 return status,m,bytes.fromhex(buffer),bytes.fromhex(pending),bytes.fromhex(contents)

def modeled(data):
 f=data.split('|');kind,cap,start=map(int,f[:3]);prefix=bytes.fromhex(f[3]);tag,op,raw,replacement,seek=map(int,f[4:]);assert replacement==0
 encoded=encoding(tag,op,raw);assert encoded is not None
 buffer=bytearray([165]*cap);contents=bytearray((i*37+19)&255 for i in range(32)) if kind else bytearray();end=pos=0
 def state(status):return status,[pos+end,1 if kind else 0,2 if kind else 0],bytes(buffer),bytes(buffer[:end]),bytes(contents)
 def output(b):
  nonlocal pos
  if len(contents)<pos+len(b):contents.extend(bytes(pos+len(b)-len(contents)))
  contents[pos:pos+len(b)]=b;pos+=len(b)
 def flush():
  nonlocal end
  if kind and end:output(buffer[:end]);end=0
  return 'ok'
 def seek_to(n):
  nonlocal pos,end
  if not kind:
   if n>=cap:return 'Unseekable'
   end=n;return 'ok'
  flush();end=0;pos=n;return 'ok'
 def write(b):
  nonlocal end
  if len(b)<=cap-end:buffer[end:end+len(b)]=b;end+=len(b);return 'ok'
  if not kind:
   n=cap-end;buffer[end:cap]=b[:n];end=cap;return 'WriteFailed'
  if kind==1 and end:output(buffer[:end]);end=0;return write(b)
  output(bytes(buffer[:end])+b);end=0;return 'ok'
 states=[state(seek_to(start)),state(write(prefix))]
 for attempt in range(3):
  states.append(state(write(encoded)))
  states.append(state(seek_to(seek) if attempt==0 else flush()))
 return states

def snapshot_checks(line,data):
 f=data.split('|');kind,cap,start=map(int,f[:3]);replacement=int(f[7]);parts=line.decode().split('~');assert len(parts)==9
 states=[fields(part) for part in parts[:-1]]
 for i,(status,m,buffer,pending,contents) in enumerate(states):
  assert status in ('ok','Unseekable','WriteFailed','Unexpected') and len(buffer)==cap and len(pending)<=cap and pending==buffer[:len(pending)]
  assert m[0]>=len(pending)
  assert m[1:]==([0,0] if kind==0 else ([0,2] if replacement==2 and i>0 else [1,3 if replacement==1 and i>0 else 2]))
  assert not contents if not kind or replacement and i>0 else len(contents)>=32
 if not replacement:assert states==modeled(data),'independent writer values/progress differ'
 assert parts[-1].split(':',1)[0]==('-1' if kind and replacement==1 else '-3')

def classify(native,translated,name,data,category,paths):
 if native.returncode==0:
  assert translated.returncode==0 and native.stdout==translated.stdout and native.stdout and not native.stderr+translated.stderr
  snapshot_checks(native.stdout.strip(),data);return 'return',native.stdout
 for result in (native,translated):
  checked_trap(result,name,category)
  messages=[m.group(1) for line in result.stderr.decode().splitlines() if (m:=re.fullmatch(r'(?:thread \d+ |V )?panic:\s*(.*)',line.strip()))]
  assert messages==[category]
 states=[p.read_bytes() for p in paths];assert states[0] and states[0]==states[1]
 status,m,buffer,pending,contents=fields(states[0].decode());f=data.split('|');kind,cap,start=map(int,f[:3]);replacement=int(f[7]);assert status=='calling' and len(buffer)==cap and pending==buffer[:len(pending)]
 assert m[1:]==([0,0] if not kind else ([0,2] if replacement==2 else [1,3 if replacement==1 else 2]))
 assert len(pending)<=cap and m[0]>=len(pending)
 # Independently reconstruct the entire pre-call prefix state; the cast must precede IO.
 expected_data='|'.join(f[:4]+[f[4],'0','0','0',f[8]])
 expected=modeled(expected_data)[1]
 assert (m[0],buffer,pending)==(expected[1][0],expected[2],expected[3])
 assert contents==(expected[4] if not replacement else b'')
 return 'trap',category.encode()+b'\0'+states[0]+b'\n'

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source',type=Path);parser.add_argument('zig',type=Path);parser.add_argument('v',type=Path)
    parser.add_argument('--target',default='aarch64-macos.14.0');parser.add_argument('--v-prod',action='store_true');parser.add_argument('--workdir',type=Path);parser.add_argument('--timeout',type=int,default=600)
    args=parser.parse_args()
    if args.timeout<=0:parser.error('--timeout must be positive')
    source=args.source.resolve()/'src';zig=args.zig.resolve();v=args.v.resolve()
    if tree_hash(source)!=PINNED_SOURCE_SHA256 or stdlib_hash(zig)!=PINNED_STDLIB_SHA256 or path_library_hashes(zig)!=PATH_LIBRARIES or encoder_library_hashes(zig)!=ENCODER_LIBRARIES:parser.error('Source/compiler library differs from pins')
    repo=Path(__file__).resolve().parent.parent;probe=repo/'zigimg/reference_probes/writer_leb128';mode='ReleaseSafe' if args.v_prod else 'Debug'
    with work_directory(args.workdir,'witty-writer-leb128-') as root:
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
        print(f'Building LEB128 writes: Source {mode}, V {"production" if args.v_prod else "ordinary"}',flush=True)
        proof.run([str(zig),'build-exe','-target',args.target,'-lc','-I',str(root),'-O',mode,'--global-cache-dir',str(root.parent/'zig-global'),'--cache-dir',str(root/'zig-cache'),'-femit-bin='+str(root/'native'),str(root/'reference.zig'),str(root/'fixture_shims.c')],'build-source',env=env,timeout=args.timeout)
        proof.run([str(v),'-enable-globals',*(['-prod'] if args.v_prod else []),'-path',f'{repo}|@vlib|@vmodules','-o',str(root/'translated'),str(root/'main.v')],'build-v',env=env,timeout=args.timeout)
        rows=corpus();path=root/'corpus.txt';path.write_text('\n'.join(data for _,data in rows)+'\n');inputs={'corpus.txt':hashlib.sha256(path.read_bytes()).hexdigest()};(root/'input_sha256.json').write_text(json.dumps(inputs,indent=2)+'\n')
        outputs=[]
        for exe in ('native','translated'):
            result=proof.run([str(root/exe),str(path)],'returning-'+exe,env=env,timeout=args.timeout)
            if result.stderr or len(result.stdout.splitlines())!=len(rows):raise AssertionError('invalid returning output')
            outputs.append(result.stdout.splitlines())
        for i,((group,data),native,translated) in enumerate(zip(rows,*outputs)):
            if native!=translated:raise AssertionError(f'{i}/{group}: LEB128 writer record differs; see retained proof')
            snapshot_checks(native,data)
        digest=hashlib.sha256(b'\n'.join(outputs[0])).hexdigest()
        if EXPECTED_ROWS is not None and (len(rows)!=EXPECTED_ROWS or digest!=EXPECTED_SHA256):raise AssertionError('returning golden changed')
        returns=hashlib.sha256();states=hashlib.sha256();return_count=0;trap_count=0
        print(f'{len(rows)} returning LEB128 write records match; checking failure controls',flush=True)
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
        summary=dict(returning_records=len(rows),write_calls=3*len(rows),primary_calls=6*len(rows),returning_groups=dict(Counter(group for group,_ in rows)),output_sha256=digest,return_controls=return_count,control_sha256=returns.hexdigest(),paired_traps=trap_count,state_sha256=states.hexdigest(),zig_mode=mode,v_prod=args.v_prod)
        (root/'summary.json').write_text(json.dumps(summary,indent=2)+'\n');print(json.dumps(summary),flush=True)

if __name__=='__main__':main()
