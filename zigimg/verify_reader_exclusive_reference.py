"""Compare exclusive delimiter prefixes, EOF tails and retained failed cursors."""
import argparse
from collections import Counter
import hashlib,itertools,json,os,re,shutil
from pathlib import Path
from verify_jpeg_contracts_reference import implementation_hashes
from verify_tiff_decode_reference import ProofLog,tree_hash,work_directory,PINNED_SOURCE_SHA256,checked_trap
from verify_stream_guards_reference import stdlib_hash,PINNED_STDLIB_SHA256
from verify_image_open_reference import PATH_LIBRARIES,path_library_hashes
from verify_image_tty_reference import ENCODER_LIBRARIES,encoder_library_hashes

EXPECTED_SIMPLE_ROWS = 12480
EXPECTED_SIMPLE_SHA256 = '7b289815904dd705da2bb636af9c4e5ab7c4429fee2696425252b78307d2b65a'
EXPECTED_ROWS = 9764
EXPECTED_SHA256 = '02dba5bcc5d4fc386311542b77fcc805f66406939d817b5614694c51693479d7'
EXPECTED_CONTROLS = 264
EXPECTED_CONTROL_SHA256 = 'e953ff96c5268780593e0fe6c4cb318a897ad823e9ce45f3527aa234c80f9b4a'
EXPECTED_TRAPS = 216
EXPECTED_STATE_SHA256 = '87f6fa3b0a377a66c68d279ebaee77ae5448782e91bdfdbf94d73dae93f8a6c0'

def spec(api=0,cap=8,pos=0,consumed=1,delimiter=255,seed=32,closed=0,refill=0,delta=0,prime=0,drain=0):
    return '|'.join(map(str,(api,cap,pos,consumed,delimiter,seed,closed,refill,delta,prime,drain)))

def markers(cap,pos,consumed):
    return sorted({0,10,19,255,((pos+consumed)*37+19)&255,((pos+cap-1)*37+19)&255,((pos+cap)*31+7)&255,((pos+2*cap-1)*31+7)&255})

def corpus():
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

def controls():
    rows=[]
    for api,cap,pos,closed,delta in itertools.product((0,1),(8,32),(0,1,7),(0,1),(-1,0,1)):
        for consumed in (1,cap-1):
            pending=cap-consumed
            for seed in sorted({0,pending-1,pending,pos+cap-1}):
                data=spec(api,cap,pos,consumed,0,seed,closed,64 if not closed else 0,delta)
                rows.append((f'position-{api}-{cap}-{pos}-{consumed}-{seed}-{closed}-{delta}',data))
    return rows

def snapshot_checks(line,data):
    f=list(map(int,data.split('|')));parts=line.decode().split('~')
    if len(parts)!=7:raise AssertionError('missing exclusive delimiter snapshots')
    states=[parts[0],*(part.split('|',1)[1] for part in parts[1:6])]
    for i,state in enumerate(states):
        fields=state.split('|');metadata=fields[0].split(':')
        if len(fields)!=4 or len(metadata)!=4 or metadata[2:]!=['1',str(2 if i==0 else 3-f[6])]:raise AssertionError('delimiter ownership differs')
        if len(bytes.fromhex(fields[1]))!=f[1] or len(bytes.fromhex(fields[2]))>f[1] or len(bytes.fromhex(fields[3]))>f[1]:raise AssertionError('initialized delimiter spans differ')
    if states[0].split('|')[0]!=f'{f[2]+f[3]}:2048:1:2':raise AssertionError('initial delimiter position or size differs')
    if parts[6].split(':',1)[0]!=('0' if f[6] else '-1'):raise AssertionError('delimiter pipe drain differs')

def simple_corpus():
    rows=[]
    for kind,api,cap,length in itertools.product((0,1,2),(0,1),(0,1,8,32),(0,1,7,8,9,31,32,33,64)):
        data=bytes((i*37+19)&255 for i in range(length))
        for start in sorted({0,1,length//2,length}):
            for delimiter in sorted({0,19,255,*data[:1],*data[length//2:length//2+1],*data[-1:]}):
                for delta in (-1,0,1):
                    rows.append('|'.join(map(str,(kind,api,cap,start,delimiter,delta)))+'|'+data.hex())
    for kind,api,delimiter in itertools.product((0,1,2),(0,1),range(256)):
        rows.append(f'{kind}|{api}|8|0|{delimiter}|0|'+bytes(range(16)).hex())
    return rows

def simple_checks(line,data):
    f=data.split('|');kind,api,cap,start,delimiter,delta=map(int,f[:6]);payload=bytes.fromhex(f[6]);parts=line.decode().split('~')
    if len(parts)!=6 or parts[-1]!='':raise AssertionError('missing simple snapshots')
    for part in parts[:-1]:
        status,pos,buffer,output,pending=part.split('|')
        if len(bytes.fromhex(buffer))!=(len(payload) if kind==0 else cap):raise AssertionError('simple caller span differs')
        if len(bytes.fromhex(pending))>(len(payload) if kind==0 else cap):raise AssertionError('simple pending span differs')
        if int(pos.split(':')[0])>len(payload):raise AssertionError('simple position exceeds data')
        if status=='ok' and delimiter in bytes.fromhex(output):raise AssertionError('exclusive output includes delimiter')

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source',type=Path);parser.add_argument('zig',type=Path);parser.add_argument('v',type=Path)
    parser.add_argument('--target',default='aarch64-macos.14.0');parser.add_argument('--v-prod',action='store_true');parser.add_argument('--workdir',type=Path);parser.add_argument('--timeout',type=int,default=600)
    args=parser.parse_args()
    if args.timeout<=0:parser.error('--timeout must be positive')
    source=args.source.resolve()/'src';zig=args.zig.resolve();v=args.v.resolve()
    if tree_hash(source)!=PINNED_SOURCE_SHA256 or stdlib_hash(zig)!=PINNED_STDLIB_SHA256 or path_library_hashes(zig)!=PATH_LIBRARIES or encoder_library_hashes(zig)!=ENCODER_LIBRARIES:parser.error('Source/compiler library differs from pins')
    repo=Path(__file__).resolve().parent.parent;probe=repo/'zigimg/reference_probes/reader_exclusive';mode='ReleaseSafe' if args.v_prod else 'Debug'
    with work_directory(args.workdir,'witty-reader-exclusive-') as root:
        tmp=root/'tmp';tmp.mkdir();env=dict(os.environ,TMPDIR=str(tmp),VTMP=str(tmp),VEXE=str(v),V_C_ERROR_BUG_REPORT_DISABLED='1')
        proof=ProofLog(root);shutil.copytree(source,root/'src');fixtures={}
        for name in ('main.v','reference.zig','fixture_shims.h','fixture_shims.c'):
            origin=probe/name
            shutil.copyfile(origin,root/name);fixtures[name]=hashlib.sha256((root/name).read_bytes()).hexdigest()
        shared=root/'reader_delimiter';shared.mkdir();shutil.copyfile(repo/'zigimg/reference_probes/reader_delimiter/fixture_shims.h',shared/'fixture_shims.h')
        shared_hash=hashlib.sha256((shared/'fixture_shims.h').read_bytes()).hexdigest()
        versions=[proof.run([str(exe),'version'],label,env=env).stdout.decode().strip() for exe,label in ((zig,'zig-version'),(v,'v-version'))]
        if versions[0]!='0.15.2' or not re.match(r'^V 0\.5\.2(?: |$)',versions[1]):raise AssertionError('compiler versions differ')
        impl=implementation_hashes(repo);runner_hash=hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
        helpers={name:hashlib.sha256((repo/'zigimg'/name).read_bytes()).hexdigest() for name in ('verify_jpeg_contracts_reference.py','verify_tiff_decode_reference.py','verify_stream_guards_reference.py','verify_image_open_reference.py','verify_image_tty_reference.py')}
        (root/'provenance.json').write_text(json.dumps(dict(source_sha256=PINNED_SOURCE_SHA256,stdlib_sha256=PINNED_STDLIB_SHA256,path_libraries=PATH_LIBRARIES,encoder_libraries=ENCODER_LIBRARIES,versions=versions,target=args.target,zig_mode=mode,v_prod=args.v_prod,implementation_sha256=impl,runner_sha256=runner_hash,fixtures=fixtures,helper_sha256=helpers,shared_fixture_sha256=shared_hash),indent=2)+'\n')
        print(f'Building exclusive delimiters: Source {mode}, V {"production" if args.v_prod else "ordinary"}',flush=True)
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
        print(f'{len(rows)} returning exclusive delimiter records match; checking retained position controls',flush=True)
        for name,data in controls():
            pair=[]
            for exe in ('native','translated'):
                path=root/(name+'-'+exe+'.state')
                pair.append((proof.run([str(root/exe),'--trap',str(path),data],name+'-'+exe,env=env,timeout=args.timeout,check=False),path))
            native,translated=pair[0][0],pair[1][0]
            if native.returncode==0:
                if native.stderr or translated.returncode or translated.stderr or native.stdout!=translated.stdout or len(native.stdout.splitlines())!=1:raise AssertionError(name+': closed-descriptor return differs')
                snapshot_checks(native.stdout.strip(),data);returns.update(name.encode()+b'\0'+native.stdout);return_count+=1
            else:
                observed=[]
                for (result,path),exe in zip(pair,('native','translated')):
                    checked_trap(result,name+'/'+exe,'integer overflow')
                    messages=[m.group(1) for line in result.stderr.decode().splitlines() if (m:=re.fullmatch(r'(?:thread \d+ |V )?panic:\s*(.*)',line.strip()))]
                    if messages!=['integer overflow'] or not path.exists():raise AssertionError('unexpected seek panic or missing observer')
                    observed.append(path.read_bytes())
                if not observed[0] or observed[0]!=observed[1] or observed[0].split(b'|')[1].split(b':')[-2:]!=[b'1',str(3-int(data.split('|')[6])).encode()]:raise AssertionError(name+': seek panic state differs')
                states.update(name.encode()+b'\0integer overflow\0'+observed[0]+b'\n');trap_count+=1
        if EXPECTED_CONTROLS is not None and (return_count!=EXPECTED_CONTROLS or returns.hexdigest()!=EXPECTED_CONTROL_SHA256):raise AssertionError('closed return golden changed')
        if EXPECTED_TRAPS is not None and (trap_count!=EXPECTED_TRAPS or states.hexdigest()!=EXPECTED_STATE_SHA256):raise AssertionError('closed panic golden changed')
        if tree_hash(source)!=PINNED_SOURCE_SHA256 or tree_hash(root/'src')!=PINNED_SOURCE_SHA256 or stdlib_hash(zig)!=PINNED_STDLIB_SHA256 or path_library_hashes(zig)!=PATH_LIBRARIES or encoder_library_hashes(zig)!=ENCODER_LIBRARIES or implementation_hashes(repo)!=impl or hashlib.sha256(Path(__file__).read_bytes()).hexdigest()!=runner_hash:raise AssertionError('dependency/implementation/runner changed')
        for name,pin in fixtures.items():
            if any(hashlib.sha256((base/name).read_bytes()).hexdigest()!=pin for base in (root,probe)):raise AssertionError('fixture changed')
        for name,pin in inputs.items():
            if hashlib.sha256((root/name).read_bytes()).hexdigest()!=pin:raise AssertionError('input changed')
        for name,pin in helpers.items():
            if hashlib.sha256((repo/'zigimg'/name).read_bytes()).hexdigest()!=pin:raise AssertionError('helper changed')
        if any(hashlib.sha256(p.read_bytes()).hexdigest()!=shared_hash for p in (shared/'fixture_shims.h',repo/'zigimg/reference_probes/reader_delimiter/fixture_shims.h')):raise AssertionError('shared fixture changed')
        if list(root.glob('*.owned*')):raise AssertionError('owned paths survived')
        summary=dict(simple_records=len(simple_rows),simple_operations=4*len(simple_rows),simple_sha256=simple_digest,returning_records=len(rows),operations=3*len(rows),returning_groups=dict(Counter(group for group,_ in rows)),output_sha256=digest,return_controls=return_count,control_sha256=returns.hexdigest(),paired_traps=trap_count,state_sha256=states.hexdigest(),zig_mode=mode,v_prod=args.v_prod)
        (root/'summary.json').write_text(json.dumps(summary,indent=2)+'\n');print(json.dumps(summary),flush=True)

if __name__=='__main__':main()
