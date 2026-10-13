"""Compare PCX dimensions, memory encoding, decoding and production failure state."""
import argparse
from collections import Counter
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import struct

from verify_jpeg_contracts_reference import implementation_hashes
from verify_tga_decode_reference import stdlib_hash, PINNED_STDLIB_SHA256
from verify_tiff_decode_reference import ProofLog, tree_hash, work_directory, PINNED_SOURCE_SHA256, checked_trap

EXPECTED_ROWS=135551
EXPECTED_SHA256='01a3c968e6dd94bc6b72e306cece9a095d71b27001f6fa88eb4ce6c991c82379'
EXPECTED_READ_SHA256='1ad4b52c6f7c2ecae9ba806bb86019a7182171bce87d3768f94d7cd9111a8633'
EXPECTED_STATE_SHA256='622bc7a90a0f6de57f8e1cf369fdde0fde8aa892685ed79841b91feeb0cc949d'


def header(width=1,height=1,bpp=1,planes=1,stride=1,**fields):
    data=bytearray(128)
    data[:4]=bytes((fields.get('id',10),fields.get('version',5),fields.get('compression',1),bpp))
    struct.pack_into('<6H',data,4,fields.get('xmin',0),fields.get('ymin',0),fields.get('xmax',width-1),fields.get('ymax',height-1),320,200)
    data[16:64]=bytes((i*17+3)&255 for i in range(48))
    data[64]=37;data[65]=planes
    struct.pack_into('<4H',data,66,stride,1,0,0)
    return bytes(data)


def encoded(raw):
    # Include ignored zero-length RLE markers and escaped high bytes.
    return b'\xc0'+b''.join(bytes((0xc1,b)) if b>=192 else bytes((b,)) for b in raw)


def read_cases():
    cases=[]
    def add(name,data):cases.append((name,data))
    for bpp,planes in ((1,1),(4,1),(8,1),(8,3)):
        for width in (1,2,3,4):
            stride=(width+7)//8 if bpp==1 else (width+1)//2 if bpp==4 else width
            for height in (1,2):
                for seed in (0,1,2):
                    for compression in (0,1):
                        raw=bytes((i*31+seed*61)&255 for i in range(stride*planes*height))
                        data=header(width,height,bpp,planes,stride,compression=compression)+encoded(raw)
                        if bpp==8 and planes==1:data+=b'\x0c'+bytes((i*17+seed*29)&255 for i in range(768))
                        add(f'valid-{bpp}-{planes}-{width}-{height}-{seed}-{compression}',data)
    baseline=header(bpp=4)+b'\x12'
    for length in (0,1,3,64,127,128):add('truncated-'+str(length),baseline[:length])
    for name,fields in [('bad-id',{'id':7,'xmax':0,'xmin':1}),('bad-version',{'version':6,'xmax':0,'xmin':1}),
                        ('bad-planes',{'planes':4,'xmax':0,'xmin':1}),('bad-format',{'bpp':2,'xmax':0,'xmin':1})]:
        add(name,header(**fields))
    add('remaining-run',header(bpp=4)+b'\xc2\x12')
    # All pixels are initialized before these palette-marker failures.
    for size in (769,770,897,1024):
        data=header(bpp=8)+b'\x01'
        data+=bytes(size-len(data))
        add('bad-vga-'+str(size),data)
    return cases


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source',type=Path);parser.add_argument('zig',type=Path);parser.add_argument('v',type=Path)
    parser.add_argument('--target',default='aarch64-macos.14.0');parser.add_argument('--v-prod',action='store_true')
    parser.add_argument('--workdir',type=Path);parser.add_argument('--timeout',type=int,default=180)
    args=parser.parse_args()
    if args.timeout<=0:parser.error('--timeout must be positive')
    source=args.source.resolve()/'src';zig=args.zig.resolve();v=args.v.resolve()
    if tree_hash(source)!=PINNED_SOURCE_SHA256 or stdlib_hash(zig)!=PINNED_STDLIB_SHA256:parser.error('Source or selected library differs from pins')
    repo=Path(__file__).resolve().parent.parent;probe=repo/'zigimg/reference_probes/pcx_contracts'
    mode='ReleaseSafe' if args.v_prod else 'Debug';env=dict(os.environ,VEXE=str(v),V_C_ERROR_BUG_REPORT_DISABLED='1')
    with work_directory(args.workdir,'witty-pcx-contracts-') as root:
        proof=ProofLog(root);shutil.copytree(source,root/'src');fixtures={}
        for name in ('main.v','reference.zig'):
            shutil.copyfile(probe/name,root/name);fixtures[name]=hashlib.sha256((root/name).read_bytes()).hexdigest()
        versions=[proof.run([str(exe),'version'],label,env=env).stdout.decode().strip() for exe,label in ((zig,'zig-version'),(v,'v-version'))]
        if versions[0]!='0.15.2' or not re.match(r'^V 0\.5\.2(?: |$)',versions[1]):raise AssertionError('unexpected compiler versions')
        implementations=implementation_hashes(repo);runner_hash=hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
        (root/'provenance.json').write_text(json.dumps(dict(source_sha256=PINNED_SOURCE_SHA256,stdlib_sha256=PINNED_STDLIB_SHA256,
            versions=versions,target=args.target,zig_mode=mode,v_prod=args.v_prod,fixtures=fixtures,
            implementation_sha256=implementations,runner_sha256=runner_hash),indent=2)+'\n')
        zbase=[str(zig),'build-exe','-target',args.target,'-lc','-O',mode,'--global-cache-dir',str(root/'zig-global')]
        vbase=[str(v),'-enable-globals',*(['-prod'] if args.v_prod else []),'-path',f'{repo}|@vlib|@vmodules']
        print(f'Building PCX contracts: Source {mode}, V {"production" if args.v_prod else "ordinary"}',flush=True)
        proof.run(zbase+['-femit-bin='+str(root/'native'),str(root/'reference.zig')],'build-source',timeout=args.timeout)
        proof.run(vbase+['-o',str(root/'translated'),str(root/'main.v')],'build-v',env=env,timeout=args.timeout)
        outputs=[]
        for exe in ('native','translated'):
            result=proof.run([str(root/exe)],'returning-'+exe,timeout=args.timeout)
            if result.stderr:raise AssertionError('unexpected returning stderr')
            outputs.append(result.stdout.splitlines())
        if len(outputs[0])!=len(outputs[1]):raise AssertionError(f'row counts differ: {[len(x) for x in outputs]}')
        for index,(native,translated) in enumerate(zip(*outputs)):
            if native!=translated:raise AssertionError(f'{index}: Source={native!r}, V={translated!r}')
        if len(outputs[0])!=EXPECTED_ROWS:raise AssertionError(f'expected {EXPECTED_ROWS}, got {len(outputs[0])}')
        digest=hashlib.sha256(b'\n'.join(outputs[0])).hexdigest()
        if digest!=EXPECTED_SHA256:raise AssertionError('returning golden changed')
        groups=Counter(row[:1].decode() for row in outputs[0]);reads=hashlib.sha256();read_count=0
        def returning(name,arguments,expected_prefix=None):
            results=[]
            for exe in ('native','translated'):
                result=proof.run([str(root/exe),arguments[0],'-',*map(str,arguments[1:])],name+'-'+exe,timeout=args.timeout)
                if result.stderr or len(result.stdout.splitlines())!=1:raise AssertionError('invalid returning control')
                results.append(result.stdout)
            if results[0]!=results[1]:raise AssertionError(f'{name}: differing return {results}')
            if expected_prefix is not None and not results[0].startswith(expected_prefix):raise AssertionError('wrong control status')
            reads.update(name.encode()+b'\0'+results[0])
        for name,data in read_cases():
            file=root/(name+'.pcx');file.write_bytes(data);returning(name,['--read',file]);read_count+=1
        controls=0
        for width,height in ((0,65536),(65536,0),(65536,65536),(1,1)):
            returning(f'unsupported-{width}-{height}',['--image',256,width,height,0x108],b'Unsupported|0|');controls+=1
        for capacity in (0,127):
            returning(f'write-first-{capacity}',['--direct',capacity,1,1,1,1,0,1,0],b'WriteFailed|');controls+=1
        returning('unsupported-first',['--direct',256,1,1,0x108,1,0,1,0],b'Unsupported|0|');controls+=1
        returning('even-height-bypass',['--direct',256,2,1,8,0,1,1,0],b'ok|');controls+=1
        read_digest=reads.hexdigest()
        if read_digest!=EXPECTED_READ_SHA256:raise AssertionError('read/control golden changed')
        print(f'{EXPECTED_ROWS} main rows and {read_count} decoder cases match; checking strict state',flush=True)
        states=hashlib.sha256();traps=Counter()
        def trap(group,name,arguments):
            observed=[]
            for exe in ('native','translated'):
                path=root/(name+'-'+exe+'.state')
                result=proof.run([str(root/exe),arguments[0],str(path),*map(str,arguments[1:])],name+'-'+exe,timeout=args.timeout,check=False)
                checked_trap(result,name+'/'+exe,'integer overflow')
                if not path.exists():raise AssertionError('missing panic observer')
                observed.append(path.read_bytes())
            if not observed[0] or observed[0]!=observed[1]:raise AssertionError(f'{name}: states differ {observed}')
            states.update(name.encode()+b'\0'+observed[0]+b'\n');traps[group]+=1
        for axis in ('width','height'):
            for low,high in ((1,0),(65535,0),(65535,65534),(0,65535)):
                trap('dimension',f'dimension-{axis}-{low}-{high}',['--dimension',axis,low,high])
        for name,fields in [('x-reverse',{'xmin':1,'xmax':0}),('y-reverse',{'ymin':1,'ymax':0}),
                            ('x-full',{'xmax':65535}),('y-full',{'ymax':65535}),
                            ('both-reverse',{'xmin':1,'xmax':0,'ymin':1,'ymax':0})]:
            file=root/(name+'.pcx');file.write_bytes(header(**fields));trap('read-dimension',name,['--read',file])
        for stride in (21846,32768,65535):
            file=root/(f'stride-{stride}.pcx');file.write_bytes(header(bpp=8,planes=3,stride=stride))
            trap('scanline',f'stride-{stride}',['--read',file])
        for length in (129,130,256,512,768):
            file=root/(f'palette-{length}.pcx');file.write_bytes(header(bpp=8)+b'\x01'+bytes(length-129))
            trap('palette-offset',f'palette-{length}',['--read',file])
        for width,height in ((0,0),(0,1),(1,0),(0,65535),(65535,0)):
            for format in (1,0x108):trap('write-zero',f'zero-{width}-{height}-{format}',['--image',256,width,height,format])
        for format in (8,0x308):trap('write-stride',f'write-stride-{format}',['--image',256,65535,1,format])
        for format in (1,4,8,0x308):
            for axis in ('x','y'):
                if format==8 and axis=='y':
                    bounds=(0,2,1,0) # Odd width evaluates height.
                else:bounds=(1,0,0,0) if axis=='x' else (0,0,1,0)
                trap('direct-after-header',f'direct-{format}-{axis}',['--direct',256,1,1,format,*bounds])
        state_digest=states.hexdigest()
        if state_digest!=EXPECTED_STATE_SHA256:raise AssertionError('failure-state golden changed')
        if (tree_hash(source)!=PINNED_SOURCE_SHA256 or tree_hash(root/'src')!=PINNED_SOURCE_SHA256
                or stdlib_hash(zig)!=PINNED_STDLIB_SHA256 or implementation_hashes(repo)!=implementations
                or hashlib.sha256(Path(__file__).read_bytes()).hexdigest()!=runner_hash):raise AssertionError('dependency, implementation or runner changed')
        for name,expected in fixtures.items():
            if any(hashlib.sha256((base/name).read_bytes()).hexdigest()!=expected for base in (root,probe)):raise AssertionError('fixture changed')
        summary=dict(returning_records=EXPECTED_ROWS,groups=dict(groups),output_sha256=digest,decoder_records=read_count,
            return_controls=controls,read_control_sha256=read_digest,paired_traps=sum(traps.values()),failure_groups=dict(traps),
            state_sha256=state_digest,zig_mode=mode,v_prod=args.v_prod)
        (root/'summary.json').write_text(json.dumps(summary,indent=2)+'\n');print(json.dumps(summary),flush=True)


if __name__=='__main__':main()
