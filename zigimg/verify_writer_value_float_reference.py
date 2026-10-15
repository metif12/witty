"""Compare f32/f64 printValue format dispatch and exact retained writer failures."""
import argparse
from collections import Counter
import hashlib,itertools,json,os,re,shutil
from pathlib import Path
import verify_writer_float_reference as decimal
import verify_writer_float_hex_reference as hexadecimal
from verify_writer_float_reference import (FLOAT_LIBRARIES,float_library_hashes,TIME_LIBRARY_SHA256,time_library_hash,INTEGER_LIBRARIES,integer_library_hashes,FORMAT_LIBRARY_SHA256,format_library_hash,IO_LIBRARY_SHA256,io_library_hash,MAX_USIZE,BITS,fields)
from verify_jpeg_contracts_reference import implementation_hashes
from verify_tiff_decode_reference import ProofLog,tree_hash,work_directory,PINNED_SOURCE_SHA256,checked_trap
from verify_stream_guards_reference import stdlib_hash,PINNED_STDLIB_SHA256
from verify_image_open_reference import PATH_LIBRARIES,path_library_hashes
from verify_image_tty_reference import ENCODER_LIBRARIES,encoder_library_hashes

EXPECTED_ROWS = 34661
EXPECTED_SHA256 = '9b1be2318fe7eaecb3cb3bfd15be586a88ee6706ba3001660808812bf52bc609'
EXPECTED_CONTROLS = 999
EXPECTED_CONTROL_SHA256 = 'b242db94e195b810ec1280bed4661a74357720c752b6b00f95f7de3b0dcce6c6'
EXPECTED_TRAPS = 505
EXPECTED_STATE_SHA256 = 'acf103a3ab3f7bd38253490c4deaad6473f23057ea3028b968573e50b7cdfa7e'
ModelLimit=(decimal.ModelLimit,hexadecimal.ModelLimit)

def spec(kind=0,cap=8,start=0,prefix=0,binding=0,finish=1,format=0,fill=91,alignment=0,width=0,present=1,precision=None,raw=0,tag=1,depth=0):
 return '|'.join(map(str,(kind,cap,start,prefix,binding,finish,format,fill,alignment,width,present,'-' if precision is None else precision,raw&((1<<BITS[tag])-1),tag,depth)))

def modeled(data):
 f=data.split('|');format=int(f[6]);depth=int(f[14]);assert 0<=format<=6
 case=int(format in (4,6));mode=0 if format<=2 else 4 if format<=4 else 3
 old='|'.join(f[:6]+['1']+f[7:14]+[str(case),str(mode)])
 states,trap,wire=(decimal if format<=4 else hexadecimal).modeled(old)
 def mapped(state):
  result=list(state);payload,spans,opts=result[5];result[5]=(payload,spans,opts[:5]+(format,depth));return tuple(result)
 return [mapped(state) for state in states],None if trap is None else (trap[0],trap[1],mapped(trap[2])),wire

def remap(data,format,depth):
 f=data.split('|');return '|'.join(f[:6]+[str(format)]+f[7:14]+[str(depth)])

def candidates():
 rows=[]
 for i,(group,data) in enumerate(decimal.candidates()):
  f=data.split('|');mode=int(f[15]);assert mode in (0,4)
  for format in ((i%3,) if mode==0 else (3,4)):
   rows.append(('decimal-'+group,remap(data,format,(0,1,MAX_USIZE)[i%3])))
 for i,(group,data) in enumerate(hexadecimal.candidates()):
  f=data.split('|')
  if f[6]!='1' or f[15]!='3':continue
  rows.append(('hex-'+group,remap(data,5+int(f[14]),(0,1,MAX_USIZE)[i%3])))
 for tag,format,depth,cap in itertools.product(range(4),range(7),(0,1,MAX_USIZE),(0,65)):
  for raw in decimal.boundaries(tag):
   rows.append(('all-formats-aliases-depth',spec(tag=tag,format=format,depth=depth,cap=cap,kind=(tag+format)%3,raw=raw)))
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
 for i,(label,data,_) in enumerate(decimal.controls()):
  mode=int(data.split('|')[15])
  if mode not in (0,4):continue
  for format in ((0,1,2) if mode==0 else (3,4)):
   add('decimal-'+label,remap(data,format,(0,1,MAX_USIZE)[i%3]))
 for i,(label,data,_) in enumerate(hexadecimal.controls()):
  f=data.split('|')
  if f[6]!='1' or f[15]!='3':continue
  for format in (5,6):add('hex-'+label,remap(data,format,(0,1,MAX_USIZE)[i%3]))
 return result

def snapshot_checks(line,data):
 parts=line.decode().split('~');assert len(parts)==6
 states=[fields(part) for part in parts[:-1]];model,trap,wire=modeled(data)
 assert trap is None and states==model,'independent value float dispatch/rendering/writer state differs'
 f=list(map(int,data.split('|')[:11]));assert parts[-1]==('-1:'+wire.hex() if f[0] and f[4]==1 else '-3:')

def classify(native,translated,name,data,category,paths):
 if native.returncode==0:
  assert category is None and translated.returncode==0 and native.stdout==translated.stdout and native.stdout and not native.stderr+translated.stderr
  snapshot_checks(native.stdout.strip(),data);return 'return',native.stdout
 for result in (native,translated):
  checked_trap(result,name,category)
  messages=[m.group(1) for line in result.stderr.decode().splitlines() if (m:=re.fullmatch(r'(?:thread \d+ |V )?panic:\s*(.*)',line.strip()))];assert messages==[category]
 states=[p.read_bytes() for p in paths];assert states[0] and states[0]==states[1]
 _,trap,_=modeled(data);assert trap is not None and trap[1]==category and fields(states[0].decode())==trap[2],'value float dispatch retained failure state differs'
 return 'trap',category.encode()+b'\0'+states[0]+b'\n'

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source',type=Path);parser.add_argument('zig',type=Path);parser.add_argument('v',type=Path)
    parser.add_argument('--target',default='aarch64-macos.14.0');parser.add_argument('--v-prod',action='store_true');parser.add_argument('--workdir',type=Path);parser.add_argument('--timeout',type=int,default=600)
    args=parser.parse_args()
    if args.timeout<=0:parser.error('--timeout must be positive')
    source=args.source.resolve()/'src';zig=args.zig.resolve();v=args.v.resolve()
    if tree_hash(source)!=PINNED_SOURCE_SHA256 or float_library_hashes(zig)!=FLOAT_LIBRARIES or time_library_hash(zig)!=TIME_LIBRARY_SHA256 or integer_library_hashes(zig)!=INTEGER_LIBRARIES or format_library_hash(zig)!=FORMAT_LIBRARY_SHA256 or io_library_hash(zig)!=IO_LIBRARY_SHA256 or stdlib_hash(zig)!=PINNED_STDLIB_SHA256 or path_library_hashes(zig)!=PATH_LIBRARIES or encoder_library_hashes(zig)!=ENCODER_LIBRARIES:parser.error('Source/compiler library differs from pins')
    repo=Path(__file__).resolve().parent.parent;probe=repo/'zigimg/reference_probes/writer_value_float';mode='ReleaseSafe' if args.v_prod else 'Debug'
    with work_directory(args.workdir,'witty-writer-value-float-') as root:
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
        helpers={name:hashlib.sha256((repo/'zigimg'/name).read_bytes()).hexdigest() for name in ('verify_writer_float_reference.py','verify_float_decimal_reference.py','verify_float_render_reference.py','verify_writer_float_hex_reference.py','verify_jpeg_contracts_reference.py','verify_tiff_decode_reference.py','verify_stream_guards_reference.py','verify_image_open_reference.py','verify_image_tty_reference.py')}
        (root/'provenance.json').write_text(json.dumps(dict(float_libraries=FLOAT_LIBRARIES,source_sha256=PINNED_SOURCE_SHA256,stdlib_sha256=PINNED_STDLIB_SHA256,io_library_sha256=IO_LIBRARY_SHA256,format_library_sha256=FORMAT_LIBRARY_SHA256,integer_libraries=INTEGER_LIBRARIES,time_library_sha256=TIME_LIBRARY_SHA256,path_libraries=PATH_LIBRARIES,encoder_libraries=ENCODER_LIBRARIES,versions=versions,target=args.target,zig_mode=mode,v_prod=args.v_prod,implementation_sha256=impl,runner_sha256=runner_hash,fixtures=fixtures,helper_sha256=helpers,shared_fixture_sha256=shared_hash),indent=2)+'\n')
        print(f'Building float value-dispatch operations: Source {mode}, V {"production" if args.v_prod else "ordinary"}',flush=True)
        proof.run([str(zig),'build-exe','-target',args.target,'-lc','-I',str(root),'-O',mode,'--global-cache-dir',str(root.parent/'zig-global'),'--cache-dir',str(root/'zig-cache'),'-femit-bin='+str(root/'native'),str(root/'reference.zig'),str(root/'fixture_shims.c')],'build-source',env=env,timeout=args.timeout)
        proof.run([str(v),'-enable-globals',*(['-prod'] if args.v_prod else []),'-path',f'{repo}|@vlib|@vmodules','-o',str(root/'translated'),str(root/'main.v')],'build-v',env=env,timeout=args.timeout)
        rows=corpus();path=root/'corpus.txt';path.write_text('\n'.join(data for _,data in rows)+'\n');inputs={'corpus.txt':hashlib.sha256(path.read_bytes()).hexdigest()};(root/'input_sha256.json').write_text(json.dumps(inputs,indent=2)+'\n')
        outputs=[]
        for exe in ('native','translated'):
            result=proof.run([str(root/exe),str(path)],'returning-'+exe,env=env,timeout=args.timeout)
            if result.stderr or len(result.stdout.splitlines())!=len(rows):raise AssertionError('invalid returning output')
            outputs.append(result.stdout.splitlines())
        for i,((group,data),native,translated) in enumerate(zip(rows,*outputs)):
            if native!=translated:raise AssertionError(f'{i}/{group}: float value-dispatch record differs; see retained proof')
            snapshot_checks(native,data)
        digest=hashlib.sha256(b'\n'.join(outputs[0])).hexdigest()
        if EXPECTED_ROWS is not None and (len(rows)!=EXPECTED_ROWS or digest!=EXPECTED_SHA256):raise AssertionError('returning golden changed')
        returns=hashlib.sha256();states=hashlib.sha256();return_count=0;trap_count=0
        print(f'{len(rows)} returning float value-dispatch records match; checking failure controls',flush=True)
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
        if tree_hash(source)!=PINNED_SOURCE_SHA256 or tree_hash(root/'src')!=PINNED_SOURCE_SHA256 or float_library_hashes(zig)!=FLOAT_LIBRARIES or time_library_hash(zig)!=TIME_LIBRARY_SHA256 or integer_library_hashes(zig)!=INTEGER_LIBRARIES or format_library_hash(zig)!=FORMAT_LIBRARY_SHA256 or io_library_hash(zig)!=IO_LIBRARY_SHA256 or stdlib_hash(zig)!=PINNED_STDLIB_SHA256 or path_library_hashes(zig)!=PATH_LIBRARIES or encoder_library_hashes(zig)!=ENCODER_LIBRARIES or implementation_hashes(repo)!=impl or hashlib.sha256(Path(__file__).read_bytes()).hexdigest()!=runner_hash:raise AssertionError('dependency/implementation/runner changed')
        for name,pin in fixtures.items():
            if any(hashlib.sha256((base/name).read_bytes()).hexdigest()!=pin for base in (root,probe)):raise AssertionError('fixture changed')
        for name,pin in inputs.items():
            if hashlib.sha256((root/name).read_bytes()).hexdigest()!=pin:raise AssertionError('input changed')
        for name,pin in helpers.items():
            if hashlib.sha256((repo/'zigimg'/name).read_bytes()).hexdigest()!=pin:raise AssertionError('helper changed')
        for directory,pin in shared_hash.items():
            if any(hashlib.sha256(p.read_bytes()).hexdigest()!=pin for p in (root/directory/'fixture_shims.h',repo/'zigimg/reference_probes'/directory/'fixture_shims.h')):raise AssertionError('shared fixture changed')
        if list(root.glob('*.owned*')):raise AssertionError('owned paths survived')
        summary=dict(returning_records=len(rows),primary_calls=len(rows),formats=dict(Counter(int(data.split('|')[6]) for _,data in rows)),types=dict(Counter(int(data.split('|')[13]) for _,data in rows)),returning_groups=dict(Counter(group for group,_ in rows)),output_sha256=digest,return_controls=return_count,control_sha256=returns.hexdigest(),paired_traps=trap_count,state_sha256=states.hexdigest(),zig_mode=mode,v_prod=args.v_prod)
        (root/'summary.json').write_text(json.dumps(summary,indent=2)+'\n');print(json.dumps(summary),flush=True)

if __name__=='__main__':main()
