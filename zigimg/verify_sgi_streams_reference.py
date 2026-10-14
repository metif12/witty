"""Compare SGI file RLE, initialized caller output and no-op encoders."""
import argparse
from collections import Counter
import hashlib
import itertools
import json
import os
from pathlib import Path
import re
import shutil
import struct
from verify_jpeg_contracts_reference import implementation_hashes
from verify_tiff_decode_reference import ProofLog, tree_hash, work_directory, PINNED_SOURCE_SHA256, checked_trap
from verify_tga_decode_reference import stdlib_hash, PINNED_STDLIB_SHA256

EXPECTED_ROWS = 16076
EXPECTED_SHA256 = '855353b000ef513a541d58184cb84d2c12ce2cbfab7b55e1e64116b904aa7898'
EXPECTED_CONTROLS = 256
EXPECTED_CONTROL_SHA256 = 'd6adf4149c24c6a2c1fa496203c86a4191d78518b5c6a995a0314ae12c926aaa'
EXPECTED_TRAPS = 888
EXPECTED_STATE_SHA256 = '6a22149758feb854269baddd9f9f88ac66126c7e9a75d2157a789b8b6a4d0cd1'
BUFFERS=(-1,0,1,2,3,4,8,16,32,510,512)

def spec(cap,op=0,data=b'',start=0,attempts=2,bpc=1,w=1,h=1,z=1,out=4):
    return '|'.join(map(str,(cap,op,start,attempts,bpc,w,h,z,out,(b'x'*start+data).hex())))

def tables(packets,offset=None,size=None):
    start=512+len(packets)*8;data=bytearray();offsets=[0]*len(packets)
    for i in reversed(range(len(packets))):offsets[i]=start+len(data);data+=packets[i]
    if offset is not None:offsets[0]=offset
    sizes=[len(p) for p in packets]
    if size is not None:sizes[0]=size
    return b''.join(struct.pack('>I',x) for x in offsets+sizes)+data

def command(n,bpc):return bytes((n,)) if bpc==1 else bytes((127,n))
def word(pattern,bpc):
    return bytes((19 if pattern==0 else 255,)) if bpc==1 else (b'\x12\x34' if pattern==0 else b'\xff\x00')

def corpus():
    rows=[]
    for cap,start,n,out,pattern in itertools.product(BUFFERS,(0,3),(0,1,2,3,7,8,15,16,31,32,63),(0,1,2,3,7,8,16,32),(0,1)):
        data=bytes((i*37+19)&255 if pattern==0 else 255 for i in range(n))
        rows.append(('raw-prefix-retry',spec(cap,1,data,start=start,out=out)))
    for cap,start,bpc,dims,kind,pattern in itertools.product(BUFFERS,(0,3),(0,1,2,3,255),((0,0,0),(0,1,1),(1,1,1),(3,2,3),(7,3,4)),(0,1,2,3),(0,1)):
        w,h,z=dims;step=1 if bpc==1 else 2;value=word(pattern,bpc)
        packet=(command(128+w,bpc)+value*w if kind==0 else command(w,bpc)+value if kind==1 and w else command(0,bpc) if kind==2 else command(128,bpc))+command(0,bpc)
        data=tables([packet]*(h*z))+b'\x63\x58'
        rows.append(('rle-rows-retry',spec(cap,0,data,start=start,bpc=bpc,w=w,h=h,z=z,out=w*h*z*step+7)))
    for cap,start,bpc,dims in itertools.product(BUFFERS,(0,3),(1,2),((1,1,1),(3,2,3))):
        w,h,z=dims;data=tables([command(129,bpc)+word(0,bpc)]*(h*z))
        for cut in range(h*z*8):rows.append(('short-table-retry',spec(cap,0,data[:cut],start=start,bpc=bpc,w=w,h=h,z=z,out=8)))
    for cap,start,op,first in itertools.product((-1,2,3,8,510),(0,3),(2,3),range(256)):
        rows.append(('detector-byte',spec(cap,op,bytes((first,0xda)),start=start)))
    for cap,start,op,data in itertools.product((-1,2,3,8,510),(0,3),(2,3),(b'',b'\x01',b'\x01\xda',b'\x01\xdb',b'\x00\xda')):
        rows.append(('detector-prefix',spec(cap,op,data,start=start)))
    for cap,start,op,attempts in itertools.product((-1,0,1,2,3,4,8,16,32,510),(0,7),(5,6),(0,1,3)):
        # Caller prefix is pending before the no-op encoder and flush follows it.
        rows.append(('no-op-writer',spec(cap,op,b'Z'*32,start=start,attempts=attempts,out=0)))
    return rows

def controls():
    cases=[]
    def add(group,cap,**kw):
        name=f'{group}-{sum(g==group for g,_,_ in cases)}';kw.setdefault('attempts',1)
        cases.append((group,name,spec(cap,**kw)))
    for cap,bpc,pi in itertools.product((-1,0,3,32),(1,2),range(6)):
        packets=[command(0,bpc),command(128,bpc),command(129,bpc)+word(0,bpc),command(130,bpc)+word(0,bpc)+word(1,bpc),command(1,bpc)+word(0,bpc),command(2,bpc)+word(0,bpc)]
        packet=packets[pi]
        for cut,out in itertools.product(range(len(packet)+1),range(5)):
            add('packet-bounds',cap,data=tables([packet[:cut]],size=len(packet)),bpc=bpc,out=out)
    for cap,bpc,offset,size in itertools.product((-1,0,3,32),(1,2),(0,519,520,521,0x80000000,0xffffffff),(0,1,0xffffffff)):
        add('absolute-offset',cap,data=tables([command(0,bpc)],offset,size),bpc=bpc,out=4)
    for cap,dims in itertools.product((-1,0,3,32),((1,8191),(1,8192),(2,4095),(2,4096),(256,256),(65535,65535))):
        h,z=dims;data=tables([b'']*(h*z)) if h*z<=8191 else b''
        add('table-arithmetic',cap,data=data,w=0,h=h,z=z,out=0)
    from verify_sgi_contracts_reference import header
    for cap,cut in itertools.product((0,1,2,3,8,509,510,511,512),(0,1,2,3,510,511,512,513)):
        add('public-header-buffer',cap,op=4,data=(header()+b'\x13')[:cut],out=0)
    for cap,op in itertools.product((0,1),(2,3)):
        add('detector-buffer',cap,op=op,data=b'\x01\xda')
    return cases

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source',type=Path);parser.add_argument('zig',type=Path);parser.add_argument('v',type=Path)
    parser.add_argument('--target',default='aarch64-macos.14.0');parser.add_argument('--v-prod',action='store_true')
    parser.add_argument('--workdir',type=Path);parser.add_argument('--timeout',type=int,default=180)
    args=parser.parse_args()
    if args.timeout<=0:parser.error('--timeout must be positive')
    source=args.source.resolve()/'src';zig=args.zig.resolve();v=args.v.resolve()
    if tree_hash(source)!=PINNED_SOURCE_SHA256 or stdlib_hash(zig)!=PINNED_STDLIB_SHA256:parser.error('Source or compiler library differs from pins')
    repo=Path(__file__).resolve().parent.parent;probe=repo/'zigimg/reference_probes/sgi_streams'
    mode='ReleaseSafe' if args.v_prod else 'Debug'
    with work_directory(args.workdir,'witty-sgi-streams-') as root:
        tmp=root/'tmp';tmp.mkdir();env=dict(os.environ,TMPDIR=str(tmp),VTMP=str(tmp),VEXE=str(v),V_C_ERROR_BUG_REPORT_DISABLED='1')
        proof=ProofLog(root);shutil.copytree(source,root/'src');fixtures={}
        for name in ('main.v','reference.zig'):
            shutil.copyfile(probe/name,root/name);fixtures[name]=hashlib.sha256((root/name).read_bytes()).hexdigest()
        versions=[proof.run([str(exe),'version'],label,env=env).stdout.decode().strip() for exe,label in ((zig,'zig-version'),(v,'v-version'))]
        if versions[0]!='0.15.2' or not re.match(r'^V 0\.5\.2(?: |$)',versions[1]):raise AssertionError('unexpected compiler versions')
        impl=implementation_hashes(repo);runner_hash=hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
        helpers={name:hashlib.sha256((repo/'zigimg'/name).read_bytes()).hexdigest() for name in ('verify_jpeg_contracts_reference.py','verify_tiff_decode_reference.py','verify_tga_decode_reference.py','verify_sgi_contracts_reference.py')}
        (root/'provenance.json').write_text(json.dumps(dict(source_sha256=PINNED_SOURCE_SHA256,stdlib_sha256=PINNED_STDLIB_SHA256,versions=versions,target=args.target,zig_mode=mode,v_prod=args.v_prod,implementation_sha256=impl,runner_sha256=runner_hash,fixtures=fixtures,helper_sha256=helpers),indent=2)+'\n')
        print(f'Building SGI streams: Source {mode}, V {"production" if args.v_prod else "ordinary"}',flush=True)
        proof.run([str(zig),'build-exe','-target',args.target,'-lc','-O',mode,'--global-cache-dir',str(root.parent/'zig-global'),'--cache-dir',str(root/'zig-cache'),'-femit-bin='+str(root/'native'),str(root/'reference.zig')],'build-source',env=env,timeout=args.timeout)
        proof.run([str(v),'-enable-globals',*(['-prod'] if args.v_prod else []),'-path',f'{repo}|@vlib|@vmodules','-o',str(root/'translated'),str(root/'main.v')],'build-v',env=env,timeout=args.timeout)
        rows=corpus();path=root/'corpus.txt';path.write_text('\n'.join(data for _,data in rows)+'\n')
        inputs={'corpus.txt':hashlib.sha256(path.read_bytes()).hexdigest()}
        (root/'input_sha256.json').write_text(json.dumps(inputs,indent=2)+'\n')
        outputs=[]
        for exe in ('native','translated'):
            r=proof.run([str(root/exe),'--corpus',str(path)],'returning-'+exe,env=env,timeout=args.timeout,check=False)
            if r.returncode or r.stderr or len(r.stdout.splitlines())!=len(rows):raise AssertionError(f'{exe}: invalid returning output; see raw proof files')
            outputs.append(r.stdout.splitlines())
        for i,(native,translated) in enumerate(zip(*outputs)):
            if native!=translated:raise AssertionError(f'{i}/{rows[i][0]}: output differs; see raw proof files')
        digest=hashlib.sha256(b'\n'.join(outputs[0])).hexdigest()
        if EXPECTED_ROWS is not None and (len(rows)!=EXPECTED_ROWS or digest!=EXPECTED_SHA256):raise AssertionError('returning golden changed')
        print(f'{len(rows)} returning records match; checking direct RLE bounds and retained file state',flush=True)
        returns=hashlib.sha256();states=hashlib.sha256();return_groups=Counter();trap_groups=Counter()
        for group,name,data in controls():
            records=[]
            for exe in ('native','translated'):
                state=root/(name+'-'+exe+'.state')
                records.append((proof.run([str(root/exe),'--trap',str(state),data],name+'-'+exe,env=env,timeout=args.timeout,check=False),state))
            native,translated=records[0][0],records[1][0]
            if native.returncode==0:
                if native.stderr or translated.returncode or translated.stderr or native.stdout!=translated.stdout or len(native.stdout.splitlines())!=1:raise AssertionError(f'{name}: control return differs')
                returns.update(name.encode()+b'\0'+native.stdout);return_groups[group]+=1
            else:
                messages=[]
                for (result,state),exe in zip(records,('native','translated')):
                    found=[m.group(1) for line in result.stderr.decode().splitlines() if (m:=re.fullmatch(r'(?:thread \d+ |V )?panic:\s*(.*)',line.strip()))]
                    if len(found)!=1 or not re.fullmatch(r'invalid enum value|integer overflow|integer does not fit in destination type|index out of bounds: index \d+, len \d+|start index \d+ is larger than end index \d+|reached unreachable code',found[0]):raise AssertionError(f'{name}/{exe}: unexpected panic {found}')
                    checked_trap(result,name+'/'+exe,found[0]);messages.append(found[0])
                    if not state.exists():raise AssertionError('missing panic observer')
                if messages[0]!=messages[1]:raise AssertionError(f'{name}: exact panic differs: {messages}')
                observed=[state.read_bytes() for _,state in records]
                if not observed[0] or observed[0]!=observed[1]:raise AssertionError(f'{name}: failure state differs')
                states.update(name.encode()+b'\0'+messages[0].encode()+b'\0'+observed[0]+b'\n');trap_groups[group]+=1
        controls_digest=returns.hexdigest();state_digest=states.hexdigest()
        if EXPECTED_CONTROLS is not None and (sum(return_groups.values())!=EXPECTED_CONTROLS or controls_digest!=EXPECTED_CONTROL_SHA256):raise AssertionError('return controls changed')
        if EXPECTED_TRAPS is not None and (sum(trap_groups.values())!=EXPECTED_TRAPS or state_digest!=EXPECTED_STATE_SHA256):raise AssertionError('failure golden changed')
        if tree_hash(source)!=PINNED_SOURCE_SHA256 or tree_hash(root/'src')!=PINNED_SOURCE_SHA256 or stdlib_hash(zig)!=PINNED_STDLIB_SHA256 or implementation_hashes(repo)!=impl or hashlib.sha256(Path(__file__).read_bytes()).hexdigest()!=runner_hash:raise AssertionError('dependency, implementation or runner changed')
        for name,expected in fixtures.items():
            if any(hashlib.sha256((base/name).read_bytes()).hexdigest()!=expected for base in (root,probe)):raise AssertionError('fixture changed')
        for name,expected in inputs.items():
            if hashlib.sha256((root/name).read_bytes()).hexdigest()!=expected:raise AssertionError('input changed')
        for name,expected in helpers.items():
            if hashlib.sha256((repo/'zigimg'/name).read_bytes()).hexdigest()!=expected:raise AssertionError('helper changed')
        summary=dict(returning_records=len(rows),calls=sum(int(data.split('|')[3]) for _,data in rows),returning_groups=dict(Counter(group for group,_ in rows)),output_sha256=digest,return_controls=sum(return_groups.values()),return_control_groups=dict(return_groups),control_sha256=controls_digest,paired_traps=sum(trap_groups.values()),failure_groups=dict(trap_groups),state_sha256=state_digest,zig_mode=mode,v_prod=args.v_prod)
        (root/'summary.json').write_text(json.dumps(summary,indent=2)+'\n');print(json.dumps(summary),flush=True)


if __name__=='__main__':main()
