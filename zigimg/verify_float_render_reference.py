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

EXPECTED_ROWS = 28340
EXPECTED_SHA256 = 'c20232f55f25e1f8389ec824430e05ecda9de8ecc1ba8cf1ec78284ca12387c8'
EXPECTED_CONTROLS = 184
EXPECTED_CONTROL_SHA256 = 'b8d4b40ae6921c25b6fff0292df05e28609f99e5e9d0f05a4e0695f55c84cfc5'
EXPECTED_TRAPS = 146
EXPECTED_STATE_SHA256 = 'a778191c50a02c212278e602f0b821edb57a69ead075fa3089e76a12461fe06d'
MAX_USIZE=(1<<64)-1
LIBRARIES={'fmt/float.zig':'c660e0ba8697da2d832ecf0cd90ab39aceac7f0ac5c1173d139ce0b66392be12','fmt.zig':'667eac6285e472b5516ebebf8a6e69959a171be4fb97cac1e56419ffec20d500','math.zig':'65645001357d5f78cbf646485e009a048b828680bb1b47fb3de0fd8617d91af1','meta.zig':'3cf9b3eb6c6b6f9b101f06f0562a4071c81a5fbc6de63d8197e837e10cedfc40','Io.zig':'09df1114cba703f824337f20489c7df5294db9f07961d4ac46abbbbf9c7ecaef'}
def library_hashes(zig):return {n:hashlib.sha256((zig.parent/'lib/std'/n).read_bytes()).hexdigest() for n in LIBRARIES}
def verify_tables(repo,zig):
 source=(zig.parent/'lib/std/fmt/float.zig').read_text();translated=(repo/'zigimg/float_ryu_tables.v').read_text();counts={}
 for name,size in (('POW5_SPLIT',326),('POW5_INV_SPLIT',342)):
  body=re.search(r'const FLOAT64_'+name+r': \['+str(size)+r'\]\[2\]u64 = \.\{(.*?)\n\};',source,re.S).group(1)
  expected=[int(x) for pair in re.findall(r'\.\{\s*(\d+),\s*(\d+)\s*\}',body) for x in pair]
  body=re.search(r'const float_ryu_'+name.lower()+r' = \[(.*?)\n\]',translated,re.S).group(1)
  actual=[int(x) for x in re.findall(r'\b\d+\b',body.replace('u64',''))]
  assert actual==expected and len(actual)==size*2,'Ryu table differs from original Source'
  counts[name]=size
 return counts

BITS=(32,64,32,64)
from functools import lru_cache
from fractions import Fraction

def spec(api=0,length=347,offset=3,guard=5,raw=0,tag=1,precision=None,mask=91):
 return '|'.join(map(str,(api,offset+length+guard,offset,length,raw&((1<<BITS[tag])-1),tag,'-' if precision is None else precision,mask)))

def power10(e):return Fraction(10**e) if e>=0 else Fraction(1,10**-e)
@lru_cache(maxsize=None)
def conversion(raw,bits):
 f=23 if bits==32 else 52;eb=bits-f-1;bias=(1<<(eb-1))-1
 sign=raw>>(bits-1);fraction=raw&((1<<f)-1);exponent=(raw>>f)&((1<<eb)-1)
 if exponent==(1<<eb)-1:return fraction,(1<<31)-1,sign
 if exponent==0 and fraction==0:return 0,0,sign
 m=fraction if exponent==0 else (1<<f)|fraction
 e2=max(1,exponent)-bias-f-2
 scale=Fraction(2**e2) if e2>=0 else Fraction(1,2**-e2)
 # Legal interval uses the exact pinned lower-endpoint convention, including exponent 1.
 lower=(4*m-1-int(fraction!=0 or exponent==0))*scale
 upper=(4*m+2)*scale;target=4*m*scale;inclusive=m%2==0
 magnitude=len(str(target.numerator))-len(str(target.denominator))
 if target<power10(magnitude):magnitude-=1
 for digits in range(1,18):
  choices=[]
  for e in range(magnitude-digits,magnitude-digits+3):
   unit=power10(e);lo=lower/unit;hi=upper/unit;x=target/unit
   first=-(-lo.numerator//lo.denominator)
   if not inclusive and lo.denominator==1:first+=1
   last=hi.numerator//hi.denominator
   if not inclusive and hi.denominator==1:last-=1
   first=max(first,10**(digits-1));last=min(last,10**digits-1)
   if first>last:continue
   q,rem=divmod(x.numerator,x.denominator)
   nearest=q+int(2*rem>x.denominator or (2*rem==x.denominator and q%2==1))
   n=max(first,min(last,nearest))
   choices.append((abs(n*unit-target),n%2,n,e))
  if choices:
   _,_,n,e=min(choices);return n,e,sign
 raise AssertionError('no shortest decimal in pinned interval')

import verify_float_decimal_reference as decimal

def mapped(data):
 api,cap,offset,extent,raw,tag,p,mask=data.split('|');n,e,sign=conversion(int(raw),BITS[int(tag)])
 return decimal.spec(api=int(api),length=int(extent),offset=int(offset),guard=int(cap)-int(offset)-int(extent),mantissa=n,exponent=e,sign=sign,precision=None if p=='-' else int(p),mask=int(mask))
def modeled(data):
 other=mapped(data);result,trap=decimal.modeled(other)
 old=other.replace('|',',').encode();new=data.replace('|',',').encode()
 return (None if result is None else result.replace(old,new)),(None if trap is None else (trap[0],trap[1].replace(old,new)))

def boundaries(tag):
 from verify_writer_float_hex_reference import boundaries as b
 return b(tag)
def candidates():
 rows=[]
 for tag in range(4):
  for api,raw,p in itertools.product(range(2),boundaries(tag),(None,0,2,16,45,339,340,346,MAX_USIZE)):
   rows.append(('native-alias-specials',spec(api=api,raw=raw,tag=tag,precision=p)))
 for tag in (0,1):
  bits=BITS[tag];f=23 if bits==32 else 52;eb=bits-f-1
  for exponent,variant,api in itertools.product(range(1<<eb),range(4),range(2)):
   fraction=(0,1,(1<<f)-1,(exponent*0x9e3779b97f4a7c15)&((1<<f)-1))[variant]
   raw=(exponent<<f)|fraction|((exponent%2)<<(bits-1))
   rows.append(('every-exponent-significand-edges',spec(api=api,raw=raw,tag=tag)))
 import struct,math
 for bits,pack in ((32,'f'),(64,'d')):
  tag=0 if bits==32 else 1
  for e in range(-45 if bits==32 else -324,39 if bits==32 else 309):
   try:raw=int.from_bytes(struct.pack('>'+pack,10.0**e),'big')
   except (OverflowError,ValueError):continue
   for delta,api in itertools.product((-1,0,1),range(2)):
    if 0<=raw+delta<(1<<bits)-1:rows.append(('powers-of-ten-and-neighbors',spec(api=api,raw=raw+delta,tag=tag)))
 for i in range(2048):
  tag=i%4;raw=((i*0x9e3779b97f4a7c15)^0xd6e8feb86659fd93)&((1<<BITS[tag])-1)
  rows.append(('seeded-bits-and-precision',spec(api=i%2,raw=raw,tag=tag,precision=(None,0,1,6,16,45,63,340)[(i//4)%8],length=(53,55,64,128,347)[i%5])))
 for api,length,tag,raw,p in itertools.product(range(2),range(53,73),(0,1),(0,0x3fc00000,0x3ff8000000000000),(None,0,1,45,46,48,64)):
  rows.append(('buffer-thresholds',spec(api=api,length=length,offset=(length%3)*3,tag=tag,raw=raw,precision=p)))
 for api,mask in itertools.product(range(2),range(256)):
  rows.append(('every-caller-mask',spec(api=api,raw=0xbff9e04189374bc7,precision=3,mask=mask)))
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
 for api,length in itertools.product(range(2),range(53)):
  add('minimum-buffer',spec(api=api,length=length,raw=0xfff0000000000001 if length%2 else 1,precision=MAX_USIZE))
 for api,tag,raw,p in itertools.product(range(2),range(4),(0,1,0x3ff8000000000000,0x7ff0000000000000,0x7ff0000000000001),(0,45,339,340,346,MAX_USIZE-8,MAX_USIZE-1,MAX_USIZE)):
  add('precision-failure-order',spec(api=api,length=53,tag=tag,raw=raw,precision=p))
 return rows

def snapshot_checks(line,data):
 expected,trap=modeled(data);assert trap is None and line==expected,'independent exact interval/rounding/scratch/borrow state differs'

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
    repo=Path(__file__).resolve().parent.parent;verify_tables(repo,zig);probe=repo/'zigimg/reference_probes/float_render';mode='ReleaseSafe' if args.v_prod else 'Debug'
    with work_directory(args.workdir,'witty-float-decimal-') as root:
        tmp=root/'tmp';tmp.mkdir();env=dict(os.environ,TMPDIR=str(tmp),VTMP=str(tmp),VEXE=str(v),V_C_ERROR_BUG_REPORT_DISABLED='1')
        proof=ProofLog(root);shutil.copytree(source,root/'src');fixtures={}
        for name in ('main.v','reference.zig'):
            shutil.copyfile(probe/name,root/name);fixtures[name]=hashlib.sha256((root/name).read_bytes()).hexdigest()
        versions=[proof.run([str(exe),'version'],label,env=env).stdout.decode().strip() for exe,label in ((zig,'zig-version'),(v,'v-version'))]
        if versions[0]!='0.15.2' or not re.match(r'^V 0\.5\.2(?: |$)',versions[1]):raise AssertionError('compiler versions differ')
        impl=implementation_hashes(repo);runner_hash=hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
        helpers={name:hashlib.sha256((repo/'zigimg'/name).read_bytes()).hexdigest() for name in ('verify_float_decimal_reference.py','verify_writer_float_hex_reference.py','verify_jpeg_contracts_reference.py','verify_tiff_decode_reference.py','verify_stream_guards_reference.py','verify_image_open_reference.py','verify_image_tty_reference.py')}
        (root/'provenance.json').write_text(json.dumps(dict(libraries=LIBRARIES,source_sha256=PINNED_SOURCE_SHA256,stdlib_sha256=PINNED_STDLIB_SHA256,path_libraries=PATH_LIBRARIES,encoder_libraries=ENCODER_LIBRARIES,versions=versions,target=args.target,zig_mode=mode,v_prod=args.v_prod,implementation_sha256=impl,runner_sha256=runner_hash,fixtures=fixtures,helper_sha256=helpers),indent=2)+'\n')
        print(f'Building float rendering operations: Source {mode}, V {"production" if args.v_prod else "ordinary"}',flush=True)
        proof.run([str(zig),'build-exe','-target',args.target,'-lc','-I',str(root),'-O',mode,'--global-cache-dir',str(root.parent/'zig-global'),'--cache-dir',str(root/'zig-cache'),'-femit-bin='+str(root/'native'),str(root/'reference.zig')],'build-source',env=env,timeout=args.timeout)
        proof.run([str(v),'-enable-globals',*(['-prod'] if args.v_prod else []),'-path',f'{repo}|@vlib|@vmodules','-o',str(root/'translated'),str(root/'main.v')],'build-v',env=env,timeout=args.timeout)
        rows=corpus();path=root/'corpus.txt';path.write_text('\n'.join(data for _,data in rows)+'\n');inputs={'corpus.txt':hashlib.sha256(path.read_bytes()).hexdigest()};(root/'input_sha256.json').write_text(json.dumps(inputs,indent=2)+'\n')
        outputs=[]
        for exe in ('native','translated'):
            result=proof.run([str(root/exe),str(path)],'returning-'+exe,env=env,timeout=args.timeout)
            if result.stderr or len(result.stdout.splitlines())!=len(rows):raise AssertionError('invalid returning output')
            outputs.append(result.stdout.splitlines())
        for i,((group,data),native,translated) in enumerate(zip(rows,*outputs)):
            if native!=translated:raise AssertionError(f'{i}/{group}: float rendering record differs; see retained proof')
            snapshot_checks(native,data)
        digest=hashlib.sha256(b'\n'.join(outputs[0])).hexdigest()
        if EXPECTED_ROWS is not None and (len(rows)!=EXPECTED_ROWS or digest!=EXPECTED_SHA256):raise AssertionError('returning golden changed')
        returns=hashlib.sha256();states=hashlib.sha256();return_count=0;trap_count=0
        print(f'{len(rows)} returning float rendering records match; checking failure controls',flush=True)
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
        verify_tables(repo,zig)
        summary=dict(table_pairs={'POW5_SPLIT':326,'POW5_INV_SPLIT':342},returning_records=len(rows),primary_calls=len(rows),returning_groups=dict(Counter(group for group,_ in rows)),output_sha256=digest,return_controls=return_count,control_sha256=returns.hexdigest(),paired_traps=trap_count,state_sha256=states.hexdigest(),zig_mode=mode,v_prod=args.v_prod)
        (root/'summary.json').write_text(json.dumps(summary,indent=2)+'\n');print(json.dumps(summary),flush=True)

if __name__=='__main__':main()
