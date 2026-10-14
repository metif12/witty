"""Compare delimiter discard counts, bounded scans, EOF and retained state."""
import argparse
from collections import Counter
import hashlib,itertools,json,os,re,shutil
from pathlib import Path
from verify_jpeg_contracts_reference import implementation_hashes
from verify_tiff_decode_reference import ProofLog,tree_hash,work_directory,PINNED_SOURCE_SHA256,checked_trap
from verify_stream_guards_reference import stdlib_hash,PINNED_STDLIB_SHA256
from verify_image_open_reference import PATH_LIBRARIES,path_library_hashes
from verify_image_tty_reference import ENCODER_LIBRARIES,encoder_library_hashes

EXPECTED_SIMPLE_ROWS = 43932
EXPECTED_SIMPLE_SHA256 = '4872caee7f98f0efa3b85dba01bd3fda3554168a5b84c5b3ce3767eddb2f40d7'
EXPECTED_ROWS = 29292
EXPECTED_SHA256 = 'c632666b0a2f9a886d3e02beb7138135ffc2766a9dc502a20173a0c4cffc859b'
EXPECTED_CONTROLS = 1444
EXPECTED_CONTROL_SHA256 = 'b35f6109eaae70e8c1c2edfcbc9934380d13748c94a20c947ceeaf0dc2066928'
EXPECTED_TRAPS = 16
EXPECTED_STATE_SHA256 = '56df6f9d04465d0a390565032b5bdc4c2eef27d8aca8555c29b93579f1b205ff'

def spec(api=0,cap=8,pos=0,consumed=1,delimiter=255,seed=32,closed=0,refill=0,delta=0,prime=0,drain=0,limit=(1<<64)-1):
    return '|'.join(map(str,(api,cap,pos,consumed,delimiter,seed,closed,refill,delta,prime,drain,limit)))

def markers(cap,pos,consumed):
    return sorted({0,10,19,255,((pos+consumed)*37+19)&255,((pos+cap-1)*37+19)&255,((pos+cap)*31+7)&255,((pos+2*cap-1)*31+7)&255})

def base_corpus():
    rows=[]
    for api,cap,pos in itertools.product((0,1),(1,8,32),(0,1,7)):
        for consumed in sorted({0,1,cap-1,cap}):
            for delimiter,seed in itertools.product(markers(cap,pos,consumed),sorted({cap,pos+2*cap+3})):
                for closed in (0,1):
                    for refill in ((0,64) if not closed else (0,)):
                        for delta in (-1,0,1):
                            rows.append(('prefilled',spec(api,cap,pos,consumed,delimiter,seed,closed,refill,delta)))
    for api,cap,pos,consumed_selector,drain in itertools.product((0,1),(8,32),(0,1,7),(0,1),(0,1)):
        consumed=1 if consumed_selector==0 else cap-1;seed=cap-consumed
        for delimiter in sorted({0,255,((pos+cap-1)*37+19)&255,((pos+consumed)*37+19)&255}):
            for closed in (0,1):
                for refill in ((0,64) if not closed else (0,)):
                    for delta in (-1,0,1):
                        rows.append(('failed-consumed' if drain else 'failed-pending',spec(api,cap,pos,consumed,delimiter,seed,closed,refill,delta,1,drain)))
    for api,delimiter in itertools.product((0,1),range(256)):
        rows.append(('every-delimiter',spec(api=api,delimiter=delimiter)))
    return rows

def base_controls():
    rows=[]
    for api,cap,pos,closed,delta in itertools.product((0,1),(8,32),(0,1,7),(0,1),(-1,0,1)):
        for consumed in (1,cap-1):
            pending=cap-consumed
            for seed in sorted({0,pending-1,pending,pos+cap-1}):
                data=spec(api,cap,pos,consumed,0,seed,closed,64 if not closed else 0,delta)
                rows.append((f'position-{api}-{cap}-{pos}-{consumed}-{seed}-{closed}-{delta}',data))
    return rows

def expand(data):
    f=list(map(int,data.split('|')))
    if f[0]==0:
        f[0]=0;yield '|'.join(map(str,f))
        f[0]=2
        for limit in sorted({0,1,f[1]+1,(1<<64)-1}):
            f[11]=limit;yield '|'.join(map(str,f))
    else:yield data

def corpus():
    return [(group,row) for group,data in base_corpus() for row in expand(data)]

def controls():
    return [(name+'-limit-'+row.split('|')[11]+'-api-'+row.split('|')[0],row) for name,data in base_controls() for row in expand(data)]

def snapshot_checks(line,data):
    f=list(map(int,data.split('|')));parts=line.decode().split('~')
    if len(parts)!=7:raise AssertionError('missing delimiter discard snapshots')
    states=[parts[0],*(part.split('|',1)[1] for part in parts[1:6])]
    for i,state in enumerate(states):
        fields=state.split('|');metadata=fields[0].split(':')
        if len(fields)!=4 or len(metadata)!=4 or metadata[2:]!=['1',str(2 if i==0 else 3-f[6])]:raise AssertionError('delimiter ownership differs')
        if len(bytes.fromhex(fields[1]))!=f[1] or len(bytes.fromhex(fields[2])) not in (0,8) or len(bytes.fromhex(fields[3]))>f[1]:raise AssertionError('initialized delimiter spans differ')
    if states[0].split('|')[0]!=f'{f[2]+f[3]}:2048:1:2':raise AssertionError('initial delimiter position or size differs')
    if parts[6].split(':',1)[0]!=('0' if f[6] else '-1'):raise AssertionError('delimiter pipe drain differs')

def limits(api,length,cap):
    return ((1<<64)-1,) if api<2 else sorted({0,1,max(0,length-1),length,length+1,cap,cap+1,(1<<64)-1})

def simple_corpus():
    rows=[]
    for kind,api,cap,length in itertools.product((0,1,2),(0,1,2),(1,2,8,32),(0,1,7,8,9,31,32,33,64)):
        data=bytes((i*37+19)&255 for i in range(length))
        for start in sorted({0,1,length//2,length}):
            for delimiter,delta,limit in itertools.product(sorted({0,19,255,*data[-1:]}),(-1,0,1),limits(api,length,cap)):
                rows.append('|'.join(map(str,(kind,api,cap,start,delimiter,delta)))+'|'+data.hex()+'|'+str(limit))
    for kind,api,cap in itertools.product((0,1,2),(0,1,2),(1,2,8,32)):
        for data in (b'',b'\n',b'\n\n\n',b'a\n\nb\n',b'last',b'a\nlast',b'a\n\n'):
            for limit in limits(api,len(data),cap):
                rows.append(f'{kind}|{api}|{cap}|0|10|0|'+data.hex()+'|'+str(limit))
    for kind,api,delimiter in itertools.product((0,1,2),(0,1,2),range(256)):
        rows.append(f'{kind}|{api}|8|0|{delimiter}|0|'+bytes(range(16)).hex()+'|17')
    return rows

def capacity_controls():
    rows=[]
    for kind,api,data in itertools.product((1,2),(0,1,2),(b'',b'a\nlast')):
        for limit in ((0,1,7) if api==2 else (7,)):
            rows.append((f'capacity-{kind}-{api}-{len(data)}-{limit}',f'{kind}|{api}|0|0|10|0|'+data.hex()+'|'+str(limit)))
    return rows

def simple_checks(line,data):
    f=data.split('|');kind,api,cap,start,delimiter,delta=map(int,f[:6]);payload=bytes.fromhex(f[6]);parts=line.decode().split('~')
    if len(parts)!=6 or parts[-1]!='':raise AssertionError('missing simple snapshots')
    for part in parts[:-1]:
        status,pos,buffer,output,pending=part.split('|')
        if len(bytes.fromhex(buffer))!=(len(payload) if kind==0 else cap):raise AssertionError('simple caller span differs')
        if len(bytes.fromhex(pending))>(len(payload) if kind==0 else cap):raise AssertionError('simple pending span differs')
        if int(pos.split(':')[0])>len(payload) or len(bytes.fromhex(output)) not in (0,8):raise AssertionError('invalid position or count')


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source',type=Path);parser.add_argument('zig',type=Path);parser.add_argument('v',type=Path)
    parser.add_argument('--target',default='aarch64-macos.14.0');parser.add_argument('--v-prod',action='store_true');parser.add_argument('--workdir',type=Path);parser.add_argument('--timeout',type=int,default=600)
    args=parser.parse_args()
    if args.timeout<=0:parser.error('--timeout must be positive')
    source=args.source.resolve()/'src';zig=args.zig.resolve();v=args.v.resolve()
    if tree_hash(source)!=PINNED_SOURCE_SHA256 or stdlib_hash(zig)!=PINNED_STDLIB_SHA256 or path_library_hashes(zig)!=PATH_LIBRARIES or encoder_library_hashes(zig)!=ENCODER_LIBRARIES:parser.error('Source/compiler library differs from pins')
    repo=Path(__file__).resolve().parent.parent;probe=repo/'zigimg/reference_probes/delimiter_discard';mode='ReleaseSafe' if args.v_prod else 'Debug'
    with work_directory(args.workdir,'witty-delimiter-discard-') as root:
        tmp=root/'tmp';tmp.mkdir();env=dict(os.environ,TMPDIR=str(tmp),VTMP=str(tmp),VEXE=str(v),V_C_ERROR_BUG_REPORT_DISABLED='1')
        proof=ProofLog(root);shutil.copytree(source,root/'src');fixtures={}
        for name in ('main.v','reference.zig','fixture_shims.h','fixture_shims.c'):
            origin=probe/name
            shutil.copyfile(origin,root/name);fixtures[name]=hashlib.sha256((root/name).read_bytes()).hexdigest()
        shared_hash={}
        for directory in ('reader_delimiter','reader_exclusive'):
            shared=root/directory;shared.mkdir();shutil.copyfile(repo/'zigimg/reference_probes'/directory/'fixture_shims.h',shared/'fixture_shims.h')
            shared_hash[directory]=hashlib.sha256((shared/'fixture_shims.h').read_bytes()).hexdigest()
        versions=[proof.run([str(exe),'version'],label,env=env).stdout.decode().strip() for exe,label in ((zig,'zig-version'),(v,'v-version'))]
        if versions[0]!='0.15.2' or not re.match(r'^V 0\.5\.2(?: |$)',versions[1]):raise AssertionError('compiler versions differ')
        impl=implementation_hashes(repo);runner_hash=hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
        helpers={name:hashlib.sha256((repo/'zigimg'/name).read_bytes()).hexdigest() for name in ('verify_jpeg_contracts_reference.py','verify_tiff_decode_reference.py','verify_stream_guards_reference.py','verify_image_open_reference.py','verify_image_tty_reference.py')}
        (root/'provenance.json').write_text(json.dumps(dict(source_sha256=PINNED_SOURCE_SHA256,stdlib_sha256=PINNED_STDLIB_SHA256,path_libraries=PATH_LIBRARIES,encoder_libraries=ENCODER_LIBRARIES,versions=versions,target=args.target,zig_mode=mode,v_prod=args.v_prod,implementation_sha256=impl,runner_sha256=runner_hash,fixtures=fixtures,helper_sha256=helpers,shared_fixture_sha256=shared_hash),indent=2)+'\n')
        print(f'Building delimiter discards: Source {mode}, V {"production" if args.v_prod else "ordinary"}',flush=True)
        proof.run([str(zig),'build-exe','-target',args.target,'-lc','-I',str(root),'-O',mode,'--global-cache-dir',str(root.parent/'zig-global'),'--cache-dir',str(root/'zig-cache'),'-femit-bin='+str(root/'native'),str(root/'reference.zig'),str(root/'fixture_shims.c')],'build-source',env=env,timeout=args.timeout)
        proof.run([str(v),'-enable-globals',*(['-prod'] if args.v_prod else []),'-path',f'{repo}|@vlib|@vmodules','-o',str(root/'translated'),str(root/'main.v')],'build-v',env=env,timeout=args.timeout)
        simple_rows=simple_corpus();simple_path=root/'simple.txt';simple_path.write_text('\n'.join(simple_rows)+'\n');simple_outputs=[]
        for exe in ('native','translated'):
            result=proof.run([str(root/exe),'--simple',str(simple_path)],'simple-'+exe,env=env,timeout=args.timeout)
            if result.stderr or len(result.stdout.splitlines())!=len(simple_rows):raise AssertionError('invalid simple output')
            simple_outputs.append(result.stdout.splitlines())
        for i,(data,native,translated) in enumerate(zip(simple_rows,*simple_outputs)):
            if native!=translated:raise AssertionError(f'{i}: simple record differs; see retained proof')
            simple_checks(native,data)
        simple_digest=hashlib.sha256(b'\n'.join(simple_outputs[0])).hexdigest()
        if EXPECTED_SIMPLE_ROWS is not None and (len(simple_rows)!=EXPECTED_SIMPLE_ROWS or simple_digest!=EXPECTED_SIMPLE_SHA256):raise AssertionError('simple golden changed')
        rows=corpus();path=root/'corpus.txt';path.write_text('\n'.join(data for _,data in rows)+'\n');inputs={'simple.txt':hashlib.sha256(simple_path.read_bytes()).hexdigest(),'corpus.txt':hashlib.sha256(path.read_bytes()).hexdigest()};(root/'input_sha256.json').write_text(json.dumps(inputs,indent=2)+'\n')
        outputs=[]
        for exe in ('native','translated'):
            result=proof.run([str(root/exe),str(path)],'returning-'+exe,env=env,timeout=args.timeout)
            if result.stderr or len(result.stdout.splitlines())!=len(rows):raise AssertionError('invalid returning transition output')
            outputs.append(result.stdout.splitlines())
        for i,((group,data),native,translated) in enumerate(zip(rows,*outputs)):
            if native!=translated:raise AssertionError(f'{i}/{group}: transition record differs; see retained proof')
            snapshot_checks(native,data)
        digest=hashlib.sha256(b'\n'.join(outputs[0])).hexdigest()
        if EXPECTED_ROWS is not None and (len(rows)!=EXPECTED_ROWS or digest!=EXPECTED_SHA256):raise AssertionError('returning golden changed')
        returns=hashlib.sha256();states=hashlib.sha256();return_count=0;trap_count=0
        print(f'{len(rows)} returning delimiter discard records match; checking retained position controls',flush=True)
        for name,data in controls()+capacity_controls():
            pair=[]
            for exe in ('native','translated'):
                path=root/(name+'-'+exe+'.state')
                pair.append((proof.run([str(root/exe),'--simple-trap' if name.startswith('capacity-') else '--trap',str(path),data],name+'-'+exe,env=env,timeout=args.timeout,check=False),path))
            native,translated=pair[0][0],pair[1][0]
            if native.returncode==0:
                if native.stderr or translated.returncode or translated.stderr or native.stdout!=translated.stdout or len(native.stdout.splitlines())!=1:raise AssertionError(name+': closed-descriptor return differs')
                (simple_checks if name.startswith('capacity-') else snapshot_checks)(native.stdout.strip(),data);returns.update(name.encode()+b'\0'+native.stdout);return_count+=1
            else:
                observed=[]
                for (result,path),exe in zip(pair,('native','translated')):
                    category='reached unreachable code' if name.startswith('capacity-') else 'integer overflow'
                    checked_trap(result,name+'/'+exe,category)
                    messages=[m.group(1) for line in result.stderr.decode().splitlines() if (m:=re.fullmatch(r'(?:thread \d+ |V )?panic:\s*(.*)',line.strip()))]
                    if messages!=[category] or not path.exists():raise AssertionError('unexpected seek panic or missing observer')
                    observed.append(path.read_bytes())
                if not observed[0] or observed[0]!=observed[1] or observed[0].split(b'|')[1].split(b':')[-2:]!=[b'1',str(2 if name.startswith('capacity-') else 3-int(data.split('|')[6])).encode()]:raise AssertionError(name+': seek panic state differs')
                states.update(name.encode()+b'\0'+category.encode()+b'\0'+observed[0]+b'\n');trap_count+=1
        if EXPECTED_CONTROLS is not None and (return_count!=EXPECTED_CONTROLS or returns.hexdigest()!=EXPECTED_CONTROL_SHA256):raise AssertionError('closed return golden changed')
        if EXPECTED_TRAPS is not None and (trap_count!=EXPECTED_TRAPS or states.hexdigest()!=EXPECTED_STATE_SHA256):raise AssertionError('closed panic golden changed')
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
        summary=dict(simple_records=len(simple_rows),simple_operations=4*len(simple_rows),simple_sha256=simple_digest,returning_records=len(rows),operations=3*len(rows),returning_groups=dict(Counter(group for group,_ in rows)),output_sha256=digest,return_controls=return_count,control_sha256=returns.hexdigest(),paired_traps=trap_count,state_sha256=states.hexdigest(),zig_mode=mode,v_prod=args.v_prod)
        (root/'summary.json').write_text(json.dumps(summary,indent=2)+'\n');print(json.dumps(summary),flush=True)

if __name__=='__main__':main()
