"""Compare writer seek caches, retained input and descriptor replacement."""
import argparse
from collections import Counter
import hashlib,itertools,json,os,re,shutil
from pathlib import Path
from verify_jpeg_contracts_reference import implementation_hashes
from verify_tiff_decode_reference import ProofLog,tree_hash,work_directory,PINNED_SOURCE_SHA256,checked_trap
from verify_stream_guards_reference import stdlib_hash,PINNED_STDLIB_SHA256
from verify_image_open_reference import PATH_LIBRARIES,path_library_hashes
from verify_image_tty_reference import ENCODER_LIBRARIES,encoder_library_hashes

EXPECTED_ROWS = 6912
EXPECTED_SHA256 = 'd699081654bf91d58ed1b37d948405fc432272988d3e3bef8c01202ff3bc277a'
EXPECTED_CONTROLS = 196
EXPECTED_CONTROL_SHA256 = '15eabc88c22536fbf718742ae2fd76bb2e61afcd3f0ebb351413dc40b752689b'
EXPECTED_TRAPS = 60
EXPECTED_STATE_SHA256 = '37687c2f4d80e44ec97553c62627a60667b3e48ef1017963da213a196785dbd7'

def spec(api=0,streaming=0,cap=0,pos=0,length=1,first=0,second=7,binding=0,invalid=0):
    return '|'.join(map(str,(api,streaming,cap,pos,length,first,second,binding,invalid)))

def corpus():
    return [('pipe' if binding==0 else 'regular-before' if binding==1 else 'regular-after',spec(api,streaming,cap,pos,length,first,second,binding))
            for api,streaming,cap,pos,length,first,second,binding in itertools.product((0,1),(0,1),(0,1,8,32),(0,1,7),(0,1,7,33),(0,1,7,32),(0,1,7),(0,1,2))]

def controls():
    rows=[]
    for api,streaming,cap,pos,first,invalid in itertools.product((0,1),(0,1),(0,1,8),(0,1),(0,7),(1,2)):
        for length in sorted({0,1,cap+1}):
            data=spec(api,streaming,cap,pos,length,first,7,0,invalid)
            rows.append((f'closed-{api}-{streaming}-{cap}-{pos}-{length}-{first}-{invalid}',data))
    return rows

def snapshot_checks(line,data):
    f=list(map(int,data.split('|')));parts=line.decode().split('~')
    if len(parts)!=9:raise AssertionError('missing writer snapshots')
    states=[parts[0],*(part.split('|',1)[1] for part in parts[1:8])]
    for i,state in enumerate(states):
        fields=state.split('|');metadata=fields[0].split(':')
        invalid=(f[8]==1 and i>=2) or (f[8]==2 and i>=4)
        rebound=invalid or (f[7]==1 and i>=2) or (f[7]==2 and i>=4)
        if len(fields)!=4 or len(metadata)!=3 or metadata[1:]!=[str(1-int(invalid)),str(3-int(rebound))]:raise AssertionError('writer ownership differs')
        if len(bytes.fromhex(fields[1]))!=f[2] or len(bytes.fromhex(fields[2]))>f[2]:raise AssertionError('writer buffer differs')
        if bool(fields[3])!=bool(rebound and not invalid):raise AssertionError('regular-file observer differs')
    if states[0].split('|')[0]!=f'{f[3]}:1:3' or parts[8].split(':',1)[0]!='-1':raise AssertionError('writer initial state or pipe drain differs')

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source',type=Path);parser.add_argument('zig',type=Path);parser.add_argument('v',type=Path)
    parser.add_argument('--target',default='aarch64-macos.14.0');parser.add_argument('--v-prod',action='store_true');parser.add_argument('--workdir',type=Path);parser.add_argument('--timeout',type=int,default=600)
    args=parser.parse_args()
    if args.timeout<=0:parser.error('--timeout must be positive')
    source=args.source.resolve()/'src';zig=args.zig.resolve();v=args.v.resolve()
    if tree_hash(source)!=PINNED_SOURCE_SHA256 or stdlib_hash(zig)!=PINNED_STDLIB_SHA256 or path_library_hashes(zig)!=PATH_LIBRARIES or encoder_library_hashes(zig)!=ENCODER_LIBRARIES:parser.error('Source/compiler library differs from pins')
    repo=Path(__file__).resolve().parent.parent;probe=repo/'zigimg/reference_probes/writer_seek';mode='ReleaseSafe' if args.v_prod else 'Debug'
    with work_directory(args.workdir,'witty-stream-discard-') as root:
        tmp=root/'tmp';tmp.mkdir();env=dict(os.environ,TMPDIR=str(tmp),VTMP=str(tmp),VEXE=str(v),V_C_ERROR_BUG_REPORT_DISABLED='1')
        proof=ProofLog(root);shutil.copytree(source,root/'src');fixtures={}
        for name in ('main.v','reference.zig','fixture_shims.h','fixture_shims.c'):
            shutil.copyfile(probe/name,root/name);fixtures[name]=hashlib.sha256((root/name).read_bytes()).hexdigest()
        versions=[proof.run([str(exe),'version'],label,env=env).stdout.decode().strip() for exe,label in ((zig,'zig-version'),(v,'v-version'))]
        if versions[0]!='0.15.2' or not re.match(r'^V 0\.5\.2(?: |$)',versions[1]):raise AssertionError('compiler versions differ')
        impl=implementation_hashes(repo);runner_hash=hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
        helpers={name:hashlib.sha256((repo/'zigimg'/name).read_bytes()).hexdigest() for name in ('verify_jpeg_contracts_reference.py','verify_tiff_decode_reference.py','verify_stream_guards_reference.py','verify_image_open_reference.py','verify_image_tty_reference.py')}
        (root/'provenance.json').write_text(json.dumps(dict(source_sha256=PINNED_SOURCE_SHA256,stdlib_sha256=PINNED_STDLIB_SHA256,path_libraries=PATH_LIBRARIES,encoder_libraries=ENCODER_LIBRARIES,versions=versions,target=args.target,zig_mode=mode,v_prod=args.v_prod,implementation_sha256=impl,runner_sha256=runner_hash,fixtures=fixtures,helper_sha256=helpers),indent=2)+'\n')
        print(f'Building writer seeks: Source {mode}, V {"production" if args.v_prod else "ordinary"}',flush=True)
        proof.run([str(zig),'build-exe','-target',args.target,'-lc','-I',str(root),'-O',mode,'--global-cache-dir',str(root.parent/'zig-global'),'--cache-dir',str(root/'zig-cache'),'-femit-bin='+str(root/'native'),str(root/'reference.zig'),str(root/'fixture_shims.c')],'build-source',env=env,timeout=args.timeout)
        proof.run([str(v),'-enable-globals',*(['-prod'] if args.v_prod else []),'-path',f'{repo}|@vlib|@vmodules','-o',str(root/'translated'),str(root/'main.v')],'build-v',env=env,timeout=args.timeout)
        rows=corpus();path=root/'corpus.txt';path.write_text('\n'.join(data for _,data in rows)+'\n');inputs={'corpus.txt':hashlib.sha256(path.read_bytes()).hexdigest()};(root/'input_sha256.json').write_text(json.dumps(inputs,indent=2)+'\n')
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
        print(f'{len(rows)} returning writer seek records match; checking closed descriptors',flush=True)
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
                    checked_trap(result,name+'/'+exe,'reached unreachable code')
                    messages=[m.group(1) for line in result.stderr.decode().splitlines() if (m:=re.fullmatch(r'(?:thread \d+ |V )?panic:\s*(.*)',line.strip()))]
                    if messages!=['reached unreachable code'] or not path.exists():raise AssertionError('unexpected seek panic or missing observer')
                    observed.append(path.read_bytes())
                if not observed[0] or observed[0]!=observed[1] or observed[0].split(b'|')[0].split(b':')[-2:]!=[b'0',b'2']:raise AssertionError(name+': seek panic state differs')
                states.update(name.encode()+b'\0reached unreachable code\0'+observed[0]+b'\n');trap_count+=1
        if EXPECTED_CONTROLS is not None and (return_count!=EXPECTED_CONTROLS or returns.hexdigest()!=EXPECTED_CONTROL_SHA256):raise AssertionError('closed return golden changed')
        if EXPECTED_TRAPS is not None and (trap_count!=EXPECTED_TRAPS or states.hexdigest()!=EXPECTED_STATE_SHA256):raise AssertionError('closed panic golden changed')
        if tree_hash(source)!=PINNED_SOURCE_SHA256 or tree_hash(root/'src')!=PINNED_SOURCE_SHA256 or stdlib_hash(zig)!=PINNED_STDLIB_SHA256 or path_library_hashes(zig)!=PATH_LIBRARIES or encoder_library_hashes(zig)!=ENCODER_LIBRARIES or implementation_hashes(repo)!=impl or hashlib.sha256(Path(__file__).read_bytes()).hexdigest()!=runner_hash:raise AssertionError('dependency/implementation/runner changed')
        for name,pin in fixtures.items():
            if any(hashlib.sha256((base/name).read_bytes()).hexdigest()!=pin for base in (root,probe)):raise AssertionError('fixture changed')
        for name,pin in inputs.items():
            if hashlib.sha256((root/name).read_bytes()).hexdigest()!=pin:raise AssertionError('input changed')
        for name,pin in helpers.items():
            if hashlib.sha256((repo/'zigimg'/name).read_bytes()).hexdigest()!=pin:raise AssertionError('helper changed')
        if list(root.glob('*.owned*')):raise AssertionError('owned paths survived')
        summary=dict(returning_records=len(rows),operations=5*len(rows),returning_groups=dict(Counter(group for group,_ in rows)),output_sha256=digest,return_controls=return_count,control_sha256=returns.hexdigest(),paired_traps=trap_count,state_sha256=states.hexdigest(),zig_mode=mode,v_prod=args.v_prod)
        (root/'summary.json').write_text(json.dumps(summary,indent=2)+'\n');print(json.dumps(summary),flush=True)

if __name__=='__main__':main()
