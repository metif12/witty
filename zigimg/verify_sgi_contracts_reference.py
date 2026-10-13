"""Compare unchanged SGI public decoding and initialized failure state."""
import argparse
from collections import Counter
import hashlib,json,os,re,shutil,struct
from pathlib import Path
from verify_jpeg_contracts_reference import implementation_hashes
from verify_tga_decode_reference import stdlib_hash,PINNED_STDLIB_SHA256
from verify_tiff_decode_reference import ProofLog,tree_hash,work_directory,PINNED_SOURCE_SHA256,checked_trap
EXPECTED_MAIN_SHA256='5d61def8690c6c1546c829ce329e011797d9aa47f8a68f66cd20eedd89eae9cd'
EXPECTED_RETURN_SHA256='4cc111e3180b24ed9a7eb7601251324feb34c4ecde170b703759e0ced25ea41c'
EXPECTED_STATE_SHA256='3e8a57024951a8948a64b350aaa3859a88338ece93378485fa104b4dfc0e0dd9'
EXPECTED_RETURNS=409
EXPECTED_TRAPS=636

def header(w=1,h=1,z=1,bpc=1,dimension=2,compression=0,pixel_format=0):
    data=bytearray(512);data[:2]=b'\x01\xda'
    struct.pack_into('>BB4H3I',data,2,compression,bpc,dimension,w,h,z,123,456,789)
    data[24]=88;struct.pack_into('>I',data,104,pixel_format);data[-1]=77
    return bytes(data)
def tables(packets,offset=None,size=None):
    start=512+len(packets)*8;data=bytearray();offsets=[0]*len(packets)
    for i in reversed(range(len(packets))):offsets[i]=start+len(data);data+=packets[i]
    if offset is not None:offsets[0]=offset
    sizes=[len(p) for p in packets]
    if size is not None:sizes[0]=size
    return b''.join(struct.pack('>I',x) for x in offsets+sizes)+data

def corpus():
    cases=[]
    def add(group,name,data,args):cases.append((group,name,data,args))
    for bpc in (0,1,2,3,255):
        step=1 if bpc==1 else 2
        def command(n):return bytes((n,)) if step==1 else bytes((127,n))
        words=[b'\x2a',b'\x7f'] if step==1 else [b'\x12\x34',b'\x56\x78']
        packets=[command(0),command(128),command(129)+words[0],command(130)+b''.join(words),command(1)+words[0],command(2)+words[0]]
        for pi,packet in enumerate(packets):
            for cut in range(len(packet)+1):
                for capacity in range(5):
                    add('rle-packet',f'packet-{bpc}-{pi}-{cut}-{capacity}',tables([packet[:cut]],size=len(packet)),['--decode',bpc,1,1,1,capacity])
        for offset in (0,511,519,520,521,0x80000000,0xffffffff):
            for size in (0,1,0xffffffff):
                add('rle-offset',f'offset-{bpc}-{offset}-{size}',tables([command(0)],offset,size),['--decode',bpc,1,1,1,4])
        for h,z in ((0,0),(0,65535),(1,0),(1,1),(2,3),(3,4)):
            for w in (0,1,2):
                packet=command(128+w)+words[0]*w+command(0)
                add('rle-rows',f'rows-{bpc}-{w}-{h}-{z}',tables([packet]*(h*z))+b'\x63\x58',['--decode',bpc,w,h,z,128])
    for cut in range(8):add('short-table',f'short-table-{cut}',tables([b'\x00'])[:cut],['--decode',1,1,1,1,4])
    for h,z in ((1,8191),(1,8192),(2,4095),(2,4096),(256,256),(65535,65535)):
        data=tables([b'']*(h*z)) if h*z<=8191 else b''
        add('table-arithmetic',f'table-{h}-{z}',data,['--decode',1,0,h,z,0])
    for dim,z,bpc in ((2,1,1),(2,1,2),(3,3,1),(3,4,1),(3,3,2),(3,4,2),(3,3,3),(3,4,3)):
        for w in (0,1,2,3):
            for h in (0,1,2):
                raw=bytes((i*37+19)&255 for i in range(w*h*z*bpc))
                data=header(w,h,z,bpc,dim)+raw+b'\x63\x58'
                add('read-raw',f'raw-{dim}-{z}-{bpc}-{w}-{h}',data,['--read'])
                if bpc not in (1,2):continue
                rows=[]
                for row in range(h*z):
                    chunk=raw[row*w*bpc:(row+1)*w*bpc]
                    cmd=bytes((128+w,)) if bpc==1 else bytes((127,128+w))
                    term=b'\x00' if bpc==1 else b'\x7f\x00'
                    rows.append(cmd+chunk+term)
                add('read-rle',f'encoded-{dim}-{z}-{bpc}-{w}-{h}',header(w,h,z,bpc,dim,1)+tables(rows)+b'\x63\x58',['--read'])
    baseline=header(1,2,3,1,3)+bytes(range(6))
    for cut in (0,1,2,3,4,24,104,511,512,513,517):add('read-short',f'read-short-{cut}',baseline[:cut],['--read'])
    for bpc,z in ((2,32768),(255,65535),(1,65535)):
        add('pixel-arithmetic',f'pixel-product-{bpc}-{z}',header(0,0,z,bpc),['--read'])
        add('read-order',f'unsupported-before-product-{bpc}-{z}',header(0,0,z,bpc,pixel_format=1),['--read'])
    for dimension,z in ((2,0),(3,3),(3,4)):
        for h in (1,2):add('read-zero-channel',f'zero-channel-{dimension}-{z}-{h}',header(1,h,z,0,dimension),['--read'])
    return cases

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path); parser.add_argument('zig', type=Path); parser.add_argument('v', type=Path)
    parser.add_argument('--target', default='aarch64-macos.14.0'); parser.add_argument('--v-prod', action='store_true')
    parser.add_argument('--workdir', type=Path); parser.add_argument('--timeout', type=int, default=180)
    args = parser.parse_args()
    if args.timeout <= 0: parser.error('--timeout must be positive')
    source = args.source.resolve() / 'src'; zig = args.zig.resolve(); v = args.v.resolve()
    if tree_hash(source) != PINNED_SOURCE_SHA256 or stdlib_hash(zig) != PINNED_STDLIB_SHA256:
        parser.error('Source or selected library differs from pins')
    repo = Path(__file__).resolve().parent.parent; probe = repo / 'zigimg/reference_probes/sgi_contracts'
    mode = 'ReleaseSafe' if args.v_prod else 'Debug'
    env = dict(os.environ, VEXE=str(v), V_C_ERROR_BUG_REPORT_DISABLED='1')
    with work_directory(args.workdir, 'witty-bmp-contracts-') as root:
        proof = ProofLog(root); shutil.copytree(source, root / 'src'); fixtures = {}
        for name in ('main.v', 'reference.zig'):
            shutil.copyfile(probe / name, root / name)
            fixtures[name] = hashlib.sha256((root / name).read_bytes()).hexdigest()
        versions = [proof.run([str(exe), 'version'], label, env=env).stdout.decode().strip()
                    for exe, label in ((zig, 'zig-version'), (v, 'v-version'))]
        if versions[0] != '0.15.2' or not re.match(r'^V 0\.5\.2(?: |$)', versions[1]):
            raise AssertionError('unexpected compiler versions')
        implementations = implementation_hashes(repo); runner_hash = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
        (root / 'provenance.json').write_text(json.dumps(dict(source_sha256=PINNED_SOURCE_SHA256, stdlib_sha256=PINNED_STDLIB_SHA256,
            versions=versions, target=args.target, zig_mode=mode, v_prod=args.v_prod, fixtures=fixtures,
            implementation_sha256=implementations, runner_sha256=runner_hash), indent=2) + '\n')
        zbase = [str(zig), 'build-exe', '-target', args.target, '-lc', '-O', mode, '--global-cache-dir', str(root / 'zig-global')]
        vbase = [str(v), '-enable-globals', *(['-prod'] if args.v_prod else []), '-path', f'{repo}|@vlib|@vmodules']
        print(f'Building SGI contracts: Source {mode}, V {"production" if args.v_prod else "ordinary"}', flush=True)
        proof.run(zbase + ['-femit-bin=' + str(root / 'native'), str(root / 'reference.zig')], 'build-source', timeout=args.timeout)
        proof.run(vbase + ['-o', str(root / 'translated'), str(root / 'main.v')], 'build-v', env=env, timeout=args.timeout)
        outputs=[]
        for exe in ('native','translated'):
            result=proof.run([str(root/exe)],'records-'+exe,timeout=args.timeout)
            if result.stderr:raise AssertionError('unexpected records stderr')
            outputs.append(result.stdout)
        if outputs[0]!=outputs[1] or len(outputs[0].splitlines())!=386:raise AssertionError('header/dimension/format records differ')
        main_digest=hashlib.sha256(b'\n'.join(outputs[0].splitlines())).hexdigest()
        if main_digest!=EXPECTED_MAIN_SHA256:raise AssertionError('main golden changed')
        returns=hashlib.sha256();states=hashlib.sha256();return_groups=Counter();trap_groups=Counter()
        inputs={}
        for group,name,data,arguments in corpus():
            file=root/(name+'.sgi');file.write_bytes(data)
            inputs[file.name]=hashlib.sha256(data).hexdigest()
            records=[]
            for exe in ('native','translated'):
                path=root/(name+'-'+exe+'.state')
                command=[str(root/exe),arguments[0],str(path),*map(str,arguments[1:]),str(file)]
                records.append((proof.run(command,name+'-'+exe,timeout=args.timeout,check=False),path))
            native,translated=records[0][0],records[1][0]
            if native.returncode==0:
                if native.stderr or translated.returncode or translated.stderr or native.stdout!=translated.stdout or len(native.stdout.splitlines())!=1:
                    raise AssertionError(f'{name}: returns differ {native.stdout!r} {translated.stdout!r} {translated.stderr!r}')
                returns.update(name.encode()+b'\0'+native.stdout);return_groups[group]+=1
            else:
                messages=[m.group(1) for line in native.stderr.decode().splitlines() if (m:=re.fullmatch(r'(?:thread \d+ )?panic:\s*(.*)',line.strip()))]
                if len(messages)!=1 or not re.fullmatch(r'integer overflow|index out of bounds: index \d+, len \d+',messages[0]):
                    raise AssertionError(f'{name}: unclassified Source failure {native.stderr!r}')
                for (result,path),exe in zip(records,('native','translated')):
                    checked_trap(result,name+'/'+exe,messages[0])
                    if not path.exists():raise AssertionError('missing state')
                snapshots=[path.read_bytes() for result,path in records]
                if not snapshots[0] or snapshots[0]!=snapshots[1]:raise AssertionError(f'{name}: state differs {snapshots}')
                states.update(name.encode()+b'\0'+messages[0].encode()+b'\0'+snapshots[0]+b'\n');trap_groups[group]+=1
        (root/'input_sha256.json').write_text(json.dumps(inputs,indent=2)+'\n')
        for name,digest in inputs.items():
            if hashlib.sha256((root/name).read_bytes()).hexdigest()!=digest:raise AssertionError('input changed')
        return_digest=returns.hexdigest();state_digest=states.hexdigest()
        if sum(return_groups.values())!=EXPECTED_RETURNS:raise AssertionError('return count changed')
        if sum(trap_groups.values())!=EXPECTED_TRAPS:raise AssertionError('trap count changed')
        if return_digest!=EXPECTED_RETURN_SHA256:raise AssertionError('return golden changed')
        if state_digest!=EXPECTED_STATE_SHA256:raise AssertionError('state golden changed')
        if (tree_hash(source) != PINNED_SOURCE_SHA256 or tree_hash(root / 'src') != PINNED_SOURCE_SHA256
                or stdlib_hash(zig) != PINNED_STDLIB_SHA256 or implementation_hashes(repo) != implementations
                or hashlib.sha256(Path(__file__).read_bytes()).hexdigest() != runner_hash): raise AssertionError('dependency, implementation or runner changed')
        for name, expected in fixtures.items():
            if any(hashlib.sha256((base / name).read_bytes()).hexdigest() != expected for base in (root, probe)): raise AssertionError('fixture changed')
        summary=dict(main_records=386,main_sha256=main_digest,returning_records=sum(return_groups.values()),return_groups=dict(return_groups),
            return_sha256=return_digest,paired_traps=sum(trap_groups.values()),failure_groups=dict(trap_groups),state_sha256=state_digest,zig_mode=mode,v_prod=args.v_prod)
        (root/'summary.json').write_text(json.dumps(summary,indent=2)+'\n');print(json.dumps(summary),flush=True)
if __name__=='__main__':main()
