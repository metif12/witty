"""Compare pinned std.Io.Limit values, optional results, and borrowed slices."""
import argparse
from collections import Counter
import hashlib,itertools,json,os,re,shutil
from pathlib import Path
from verify_jpeg_contracts_reference import implementation_hashes
from verify_tiff_decode_reference import ProofLog,tree_hash,work_directory,PINNED_SOURCE_SHA256,checked_trap
from verify_stream_guards_reference import stdlib_hash,PINNED_STDLIB_SHA256
from verify_image_open_reference import PATH_LIBRARIES,path_library_hashes
from verify_image_tty_reference import ENCODER_LIBRARIES,encoder_library_hashes





EXPECTED_ROWS = 20100
EXPECTED_SHA256 = 'f556ae2116c0ffc169394c708a70fff51249c91de8a13346bb42cb8f471a188d'
EXPECTED_CONTROLS = 240
EXPECTED_CONTROL_SHA256 = '98eaf99b9a6ff428299c6502d5fc523e86d64c7c12fd898c1dddb8103a0fce29'
EXPECTED_TRAPS = 240
EXPECTED_STATE_SHA256 = 'fa31f245894f7498bc54a8032884eb468efeb09e7ec2c76d042dbad2f54db07c'
IO_LIBRARY_SHA256 = '09df1114cba703f824337f20489c7df5294db9f07961d4ac46abbbbf9c7ecaef'
def io_library_hash(zig):return hashlib.sha256((zig.parent/'lib/std/Io.zig').read_bytes()).hexdigest()
MAX_USIZE=(1<<64)-1
PROFILES=((),((0,0),),((0,3),(6,0),(1,7)),((0,255),(32,32),(255,1)),((0,1),)*33)
VALUES=(0,1,2,3,7,8,9,63,64,65,255,256,(1<<31)-1,1<<31,(1<<32)-1,1<<32,(1<<63)-1,1<<63,MAX_USIZE-1,MAX_USIZE)
def spec(a=0,b=0,n=0,length=8,profile=2,mask=91,force=0):return '|'.join(map(str,(a,b,n,length,profile,mask,force)))
def modeled(data):
 a,b,n,length,profile,mask,force=map(int,data.split('|'));spans=PROFILES[profile]
 payload=bytes((i*23+mask)&255 for i in range(256));buffer=bytearray((i*17+165)&255 for i in range(length))
 scalar='|'.join(map(str,(a,b,n,min(n,MAX_USIZE),min(a,b),min(a,b),min(a,n),sum(count for _,count in spans),'none' if a==MAX_USIZE else a,'none' if a!=MAX_USIZE and b>a else (MAX_USIZE if a==MAX_USIZE else a-b),'true' if a else 'false',0,MAX_USIZE)))
 def state():return scalar+'|'+buffer.hex()+'|'+payload.hex()+'#'+';'.join(f'{o},{count}' for o,count in spans)
 initial=state();has_one=bool(length or force)
 if has_one and not length:return None,('reached unreachable code',('slice1|'+initial).encode())
 width=min(a,length);one=min(min(a+1,MAX_USIZE),length)
 def view(size):return f'{size}:0:'+buffer[:size].hex()
 def snapshot(status):return status+'|'+view(width)+';'+view(width)+';'+(view(one) if has_one else '-')+'|'+state()
 records=['setup|'+initial,snapshot('views')]
 if length:buffer[0]^=mask
 records.append(snapshot('caller'))
 if width:buffer[width-1]^=0x33
 if one and has_one:buffer[one-1]^=0x55
 records.append(snapshot('borrow'))
 return '~'.join(records).encode(),None

def corpus():
 rows=[];seen=set()
 for a,b,n,length,profile in itertools.product(VALUES,(0,1,3,8,64,MAX_USIZE),(0,1,255,1<<32,MAX_USIZE),(0,1,8,17,64),range(len(PROFILES))):rows.append(('values-slices',spec(a,b,n,length,profile)))
 for a,length,mask in itertools.product((0,1,7,8,MAX_USIZE),(0,1,8,64),range(256)):rows.append(('every-byte',spec(a,MAX_USIZE,MAX_USIZE,length,2,mask)))
 result=[]
 for group,data in rows:
  if data not in seen:seen.add(data);result.append((group,data))
 return result

def controls():
 rows=[]
 for a,b,n,profile in itertools.product((0,1,7,8,(1<<31)-1,1<<31,(1<<32)-1,1<<32,MAX_USIZE-1,MAX_USIZE),(0,1,8,MAX_USIZE),(0,1,MAX_USIZE),(0,3)):
  for force in (0,1):
   data=spec(a,b,n,0,profile,force=force);trap=modeled(data)[1]
   rows.append((f'boundary-{len(rows)}',data,trap[0] if trap else None))
 return rows

def snapshot_checks(line,data):
 expected,trap=modeled(data);assert trap is None and line==expected,'independent Limit/value/alias state differs'

def classify(native,translated,name,data,category,paths):
 if native.returncode==0:
  assert category is None and translated.returncode==0 and native.stdout==translated.stdout and native.stdout and not native.stderr+translated.stderr
  snapshot_checks(native.stdout.strip(),data);return 'return',native.stdout
 for result in (native,translated):
  checked_trap(result,name,category)
  messages=[m.group(1) for line in result.stderr.decode().splitlines() if (m:=re.fullmatch(r'(?:thread \d+ |V )?panic:\s*(.*)',line.strip()))];assert messages==[category]
 states=[p.read_bytes() for p in paths];assert states[0] and states[0]==states[1]
 _,trap=modeled(data);assert trap is not None and trap[0]==category and states[0]==trap[1],'Limit assertion state differs'
 return 'trap',category.encode()+b'\0'+states[0]+b'\n'

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source',type=Path);parser.add_argument('zig',type=Path);parser.add_argument('v',type=Path)
    parser.add_argument('--target',default='aarch64-macos.14.0');parser.add_argument('--v-prod',action='store_true');parser.add_argument('--workdir',type=Path);parser.add_argument('--timeout',type=int,default=600)
    args=parser.parse_args()
    if args.timeout<=0:parser.error('--timeout must be positive')
    source=args.source.resolve()/'src';zig=args.zig.resolve();v=args.v.resolve()
    if io_library_hash(zig)!=IO_LIBRARY_SHA256 or tree_hash(source)!=PINNED_SOURCE_SHA256 or stdlib_hash(zig)!=PINNED_STDLIB_SHA256 or path_library_hashes(zig)!=PATH_LIBRARIES or encoder_library_hashes(zig)!=ENCODER_LIBRARIES:parser.error('Source/compiler library differs from pins')
    repo=Path(__file__).resolve().parent.parent;probe=repo/'zigimg/reference_probes/io_limit';mode='ReleaseSafe' if args.v_prod else 'Debug'
    with work_directory(args.workdir,'witty-io-limit-') as root:
        tmp=root/'tmp';tmp.mkdir();env=dict(os.environ,TMPDIR=str(tmp),VTMP=str(tmp),VEXE=str(v),V_C_ERROR_BUG_REPORT_DISABLED='1')
        proof=ProofLog(root);shutil.copytree(source,root/'src');fixtures={}
        for name in ('main.v','reference.zig'):
            shutil.copyfile(probe/name,root/name);fixtures[name]=hashlib.sha256((root/name).read_bytes()).hexdigest()
        versions=[proof.run([str(exe),'version'],label,env=env).stdout.decode().strip() for exe,label in ((zig,'zig-version'),(v,'v-version'))]
        if versions[0]!='0.15.2' or not re.match(r'^V 0\.5\.2(?: |$)',versions[1]):raise AssertionError('compiler versions differ')
        impl=implementation_hashes(repo);runner_hash=hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
        helpers={name:hashlib.sha256((repo/'zigimg'/name).read_bytes()).hexdigest() for name in ('verify_jpeg_contracts_reference.py','verify_tiff_decode_reference.py','verify_stream_guards_reference.py','verify_image_open_reference.py','verify_image_tty_reference.py')}
        (root/'provenance.json').write_text(json.dumps(dict(io_library_sha256=IO_LIBRARY_SHA256,source_sha256=PINNED_SOURCE_SHA256,stdlib_sha256=PINNED_STDLIB_SHA256,path_libraries=PATH_LIBRARIES,encoder_libraries=ENCODER_LIBRARIES,versions=versions,target=args.target,zig_mode=mode,v_prod=args.v_prod,implementation_sha256=impl,runner_sha256=runner_hash,fixtures=fixtures,helper_sha256=helpers),indent=2)+'\n')
        print(f'Building IO limit operations: Source {mode}, V {"production" if args.v_prod else "ordinary"}',flush=True)
        proof.run([str(zig),'build-exe','-target',args.target,'-lc','-I',str(root),'-O',mode,'--global-cache-dir',str(root.parent/'zig-global'),'--cache-dir',str(root/'zig-cache'),'-femit-bin='+str(root/'native'),str(root/'reference.zig')],'build-source',env=env,timeout=args.timeout)
        proof.run([str(v),'-enable-globals',*(['-prod'] if args.v_prod else []),'-path',f'{repo}|@vlib|@vmodules','-o',str(root/'translated'),str(root/'main.v')],'build-v',env=env,timeout=args.timeout)
        rows=corpus();path=root/'corpus.txt';path.write_text('\n'.join(data for _,data in rows)+'\n');inputs={'corpus.txt':hashlib.sha256(path.read_bytes()).hexdigest()};(root/'input_sha256.json').write_text(json.dumps(inputs,indent=2)+'\n')
        outputs=[]
        for exe in ('native','translated'):
            result=proof.run([str(root/exe),str(path)],'returning-'+exe,env=env,timeout=args.timeout)
            if result.stderr or len(result.stdout.splitlines())!=len(rows):raise AssertionError('invalid returning output')
            outputs.append(result.stdout.splitlines())
        for i,((group,data),native,translated) in enumerate(zip(rows,*outputs)):
            if native!=translated:raise AssertionError(f'{i}/{group}: IO limit record differs; see retained proof')
            snapshot_checks(native,data)
        digest=hashlib.sha256(b'\n'.join(outputs[0])).hexdigest()
        if EXPECTED_ROWS is not None and (len(rows)!=EXPECTED_ROWS or digest!=EXPECTED_SHA256):raise AssertionError('returning golden changed')
        returns=hashlib.sha256();states=hashlib.sha256();return_count=0;trap_count=0
        print(f'{len(rows)} returning IO limit records match; checking failure controls',flush=True)
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
        if io_library_hash(zig)!=IO_LIBRARY_SHA256 or tree_hash(source)!=PINNED_SOURCE_SHA256 or tree_hash(root/'src')!=PINNED_SOURCE_SHA256 or stdlib_hash(zig)!=PINNED_STDLIB_SHA256 or path_library_hashes(zig)!=PATH_LIBRARIES or encoder_library_hashes(zig)!=ENCODER_LIBRARIES or implementation_hashes(repo)!=impl or hashlib.sha256(Path(__file__).read_bytes()).hexdigest()!=runner_hash:raise AssertionError('dependency/implementation/runner changed')
        for name,pin in fixtures.items():
            if any(hashlib.sha256((base/name).read_bytes()).hexdigest()!=pin for base in (root,probe)):raise AssertionError('fixture changed')
        for name,pin in inputs.items():
            if hashlib.sha256((root/name).read_bytes()).hexdigest()!=pin:raise AssertionError('input changed')
        for name,pin in helpers.items():
            if hashlib.sha256((repo/'zigimg'/name).read_bytes()).hexdigest()!=pin:raise AssertionError('helper changed')
        summary=dict(returning_records=len(rows),primary_calls=len(rows),returning_groups=dict(Counter(group for group,_ in rows)),output_sha256=digest,return_controls=return_count,control_sha256=returns.hexdigest(),paired_traps=trap_count,state_sha256=states.hexdigest(),zig_mode=mode,v_prod=args.v_prod)
        (root/'summary.json').write_text(json.dumps(summary,indent=2)+'\n');print(json.dumps(summary),flush=True)

if __name__=='__main__':main()
