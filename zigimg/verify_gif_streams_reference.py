"""Compare GIF buffered metadata, graphic parsing and initialized retained state."""
import argparse
from collections import Counter
import hashlib
import itertools
import json
import os
from pathlib import Path
import re
import shutil
from verify_jpeg_contracts_reference import implementation_hashes
from verify_tiff_decode_reference import ProofLog, tree_hash, work_directory, PINNED_SOURCE_SHA256, checked_trap
from verify_tga_decode_reference import stdlib_hash, PINNED_STDLIB_SHA256

EXPECTED_ROWS = 13316
EXPECTED_SHA256 = '7d610f7bca4e240506ab9fe2662014f8c90ccd154b54b078fb017464a0940469'
EXPECTED_CONTROLS = 2634
EXPECTED_CONTROL_SHA256 = '1ffece9b8732ef1e307735ac2b4aad0bcfbabb02ea2085d9bb021cfa7d0592a5'
EXPECTED_TRAPS = 738
EXPECTED_STATE_SHA256 = '2d97ecf1c18da35bd3e87addcebda9a98545986b6838d9118d2bcde927dd53a5'
EXPECTED_LOOPS = 12
EXPECTED_READY_SHA256 = 'b0ef0ce9fde8e40f35c018c36c095c1aa8ed5d03b58bbb7e80a1b7f237a892c9'
import struct
BUFFERS=(-1,13,14,16,32,128)

def spec(cap,op=0,data=b'',start=0,attempts=2,loop=False):
    return '|'.join(map(str,(cap,op,start,attempts,int(loop),(b'x'*start+data).hex())))

def header(size=0,w=1,h=1,flags=128,bg=0):
    return b'GIF89a'+struct.pack('<HHBBB',w,h,flags|size,bg,77)

def colors(size=0):return bytes((i*37+19)&255 for i in range(3*(1<<(size+1))))

def blocks(data,split=255):
    return b''.join(bytes((len(data[i:i+split]),))+data[i:i+split] for i in range(0,len(data),split))+b'\x00'

def app(data=b'\x01\x07\x00',identity=b'NETSCAPE2.0',declared=11):
    return b'\x21\xff'+bytes((declared,))+identity+blocks(data)

def graphic(flags=0,delay=0,transparent=0,declared=4,terminator=0):
    return bytes((0x21,0xf9,declared,flags))+struct.pack('<H',delay)+bytes((transparent,terminator))

def image(w=1,h=1,flags=0,local=b''):
    # Only complete one-pixel streams or zero extents enter rendering coverage.
    return b'\x2c'+struct.pack('<HHHHB',0,0,w,h,flags)+(local+b'\x02\x02\x4c\x01\x00' if w and h else b'')

def corpus():
    rows=[]
    for cap,op,size,dims in itertools.product(BUFFERS,range(3),range(8),((0,0),(1,1),(3,2),(7,1),(16,2))):
        w,h=dims;rows.append(('complete-header-palette',spec(cap,op,header(size,w,h)+colors(size)+b'\x3b')))
    for cap,op,first in itertools.product((-1,6,13,32,128),(3,4),range(256)):
        rows.append(('detector-byte',spec(cap,op,bytes((first,))+b'IF89a')))
    for cap,op,data,start in itertools.product((-1,6,13,32,128),(3,4),(b'',b'GIF',b'GIF87a',b'GIF89a',b'GIF90a'),(0,3)):
        rows.append(('detector-prefix',spec(cap,op,data,start=start)))
    prefix=header()+colors()
    for cap,op,size,split,pattern in itertools.product(BUFFERS,range(3),(0,1,2,3,7,31,63,64,127,128,255,256),(1,7,255),(0,1)):
        data=bytes((i*37+19)&255 if pattern==0 else 255 for i in range(size))
        rows.append(('comment-subblocks',spec(cap,op,prefix+b'\x21\xfe'+blocks(data,split)+b'\x3b')))
    examples=(prefix+b'\x3b',prefix+b'\x21\xfe'+blocks(b'abcdefgh')+b'\x3b',prefix+b'\x21\xfe'+blocks(bytes(range(31)),7)+b'\x3b')
    for cap,op,data,start in itertools.product(BUFFERS,range(3),examples,(0,3)):
        for cut in range(len(data)+1):rows.append(('header-comment-prefix-retry',spec(cap,op,data[:cut],start=start)))
    for cap,op,kind in itertools.product(BUFFERS,range(3),range(256)):
        if kind in (1,0xf9,0xfe,0xff):continue
        rows.append(('unknown-extension',spec(cap,op,prefix+bytes((0x21,kind,1,2,3,0,0x3b)))))
    return rows

def controls():
    cases=[]
    prefix=header()+colors()
    def add(group,cap,op,data,loop=False):
        name=f'{group}-{sum(g==group for g,_,_ in cases)}'
        cases.append((group,name,spec(cap,op,data,attempts=1,loop=loop)))
    for cap,op,identity,n,declared in itertools.product(BUFFERS,range(3),(b'NETSCAPE2.0',b'ANIMEXTS1.0',b'UNKNOWN!XYZ'),(0,1,2,3,4,7),(0,11,255)):
        add('application-data',cap,op,prefix+app(bytes(range(n)),identity,declared)+b'\x3b',loop=True)
    application=prefix+app()+b'\x3b'
    for cap,op,cut in itertools.product(BUFFERS,range(3),range(len(application)+1)):
        add('application-prefix',cap,op,application[:cut],loop=True)
    for cap,op,flags,declared in itertools.product(BUFFERS,range(3),(0,1,4,9,13,28,255),(0,4,255)):
        add('graphic-control',cap,op,prefix+graphic(flags,37,1,declared,0xee)+b'\x3b')
    for cap,op,cut in itertools.product(BUFFERS,range(3),range(9)):
        add('graphic-prefix',cap,op,(prefix+graphic()+b'\x3b')[:len(prefix)+cut])
    for cap,op,dims,flags in itertools.product(BUFFERS,range(3),((0,1),(1,0),(0,0)),(0,64,128,135,199)):
        add('zero-image',cap,op,prefix+image(*dims,flags=flags)+b'\x3b')
    for cap,op,flags,transparent in itertools.product(BUFFERS,range(3),(0,1,4,9,13,28,255),(0,1,3,255)):
        add('complete-one-pixel',cap,op,prefix+graphic(flags,37,transparent)+image()+b'\x3b')
    for cap,op,size,subsize in itertools.product(BUFFERS,range(3),(0,1,12),(0,1,3,255)):
        data=prefix+bytes((0x21,1,size))+b'A'*size+bytes((subsize,))+b'B'*subsize+b'\x00\x3b'
        add('plain-text-complete',cap,op,data)
    for cap,op in itertools.product((0,1,5,6,8,12),(0,1,2,3,4)):
        add('small-buffer',cap,op,prefix+b'\x3b')
    for cap,size,bg in itertools.product(BUFFERS,(1,2,3,7),(2,3,4,15,255)):
        add('direct-background-cast',cap,0,header(size,flags=0,bg=bg)+b'\x3b')
    return cases

def loops():
    prefix=header()+colors()
    return [(f'plain-discard-{cap}-{op}-{stage}',spec(cap,op,prefix+(b'\x21\x01\x0c' if stage==0 else b'\x21\x01\x00\x03'),attempts=1)) for cap,op,stage in itertools.product((13,32),(0,1,2),(0,1))]


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source',type=Path);parser.add_argument('zig',type=Path);parser.add_argument('v',type=Path)
    parser.add_argument('--target',default='aarch64-macos.14.0');parser.add_argument('--v-prod',action='store_true')
    parser.add_argument('--workdir',type=Path);parser.add_argument('--timeout',type=int,default=180)
    args=parser.parse_args()
    if args.timeout<=0:parser.error('--timeout must be positive')
    source=args.source.resolve()/'src';zig=args.zig.resolve();v=args.v.resolve()
    if tree_hash(source)!=PINNED_SOURCE_SHA256 or stdlib_hash(zig)!=PINNED_STDLIB_SHA256:parser.error('Source or compiler library differs from pins')
    repo=Path(__file__).resolve().parent.parent;probe=repo/'zigimg/reference_probes/gif_streams'
    mode='ReleaseSafe' if args.v_prod else 'Debug'
    with work_directory(args.workdir,'witty-gif-streams-') as root:
        tmp=root/'tmp';tmp.mkdir();env=dict(os.environ,TMPDIR=str(tmp),VTMP=str(tmp),VEXE=str(v),V_C_ERROR_BUG_REPORT_DISABLED='1')
        proof=ProofLog(root);shutil.copytree(source,root/'src');fixtures={}
        for name in ('main.v','reference.zig'):
            shutil.copyfile(probe/name,root/name);fixtures[name]=hashlib.sha256((root/name).read_bytes()).hexdigest()
        versions=[proof.run([str(exe),'version'],label,env=env).stdout.decode().strip() for exe,label in ((zig,'zig-version'),(v,'v-version'))]
        if versions[0]!='0.15.2' or not re.match(r'^V 0\.5\.2(?: |$)',versions[1]):raise AssertionError('unexpected compiler versions')
        impl=implementation_hashes(repo);runner_hash=hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
        helpers={name:hashlib.sha256((repo/'zigimg'/name).read_bytes()).hexdigest() for name in ('verify_jpeg_contracts_reference.py','verify_tiff_decode_reference.py','verify_tga_decode_reference.py','verify_gif_records_reference.py')}
        (root/'provenance.json').write_text(json.dumps(dict(source_sha256=PINNED_SOURCE_SHA256,stdlib_sha256=PINNED_STDLIB_SHA256,versions=versions,target=args.target,zig_mode=mode,v_prod=args.v_prod,implementation_sha256=impl,runner_sha256=runner_hash,fixtures=fixtures,helper_sha256=helpers),indent=2)+'\n')
        print(f'Building GIF streams: Source {mode}, V {"production" if args.v_prod else "ordinary"}',flush=True)
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
        print(f'{len(rows)} returning records match; checking buffered extension and graphic state',flush=True)
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
                    if len(found)!=1 or not re.fullmatch(r'integer overflow|integer does not fit in destination type|index out of bounds: index \d+, len \d+|start index \d+ is larger than end index \d+|reached unreachable code',found[0]):raise AssertionError(f'{name}/{exe}: unexpected panic {found}')
                    checked_trap(result,name+'/'+exe,found[0]);messages.append(found[0])
                    if not state.exists():raise AssertionError('missing panic observer')
                if messages[0]!=messages[1]:raise AssertionError(f'{name}: exact panic differs: {messages}')
                observed=[state.read_bytes() for _,state in records]
                if not observed[0] or observed[0]!=observed[1]:raise AssertionError(f'{name}: failure state differs')
                states.update(name.encode()+b'\0'+messages[0].encode()+b'\0'+observed[0]+b'\n');trap_groups[group]+=1
        controls_digest=returns.hexdigest();state_digest=states.hexdigest()
        if EXPECTED_CONTROLS is not None and (sum(return_groups.values())!=EXPECTED_CONTROLS or controls_digest!=EXPECTED_CONTROL_SHA256):raise AssertionError('return controls changed')
        if EXPECTED_TRAPS is not None and (sum(trap_groups.values())!=EXPECTED_TRAPS or state_digest!=EXPECTED_STATE_SHA256):raise AssertionError('failure golden changed')
        ready_hash=hashlib.sha256()
        for name,data in loops():
            observed=[]
            for exe in ('native','translated'):
                path=root/(name+'-'+exe+'.state')
                try:
                    proof.run([str(root/exe),'--loop',str(path),data],name+'-'+exe,env=env,timeout=0.5,check=False)
                except AssertionError:
                    if not proof.commands[-1].get('timed_out'):raise
                else:raise AssertionError('expected inherited discard loop')
                record=proof.commands[-1];index=len(proof.commands)-1;label=record['label']
                if (root/f'{index:03d}-{label}.stdout').read_bytes() or (root/f'{index:03d}-{label}.stderr').read_bytes():raise AssertionError('unexpected loop output')
                ready=Path(str(path)+'.ready')
                if not ready.exists():raise AssertionError('loop entry was not reached')
                observed.append(ready.read_bytes())
            if not observed[0] or observed[0]!=observed[1]:raise AssertionError('loop entry state differs')
            ready_hash.update(name.encode()+b'\0'+observed[0]+b'\n')
        if EXPECTED_LOOPS is not None and (len(loops())!=EXPECTED_LOOPS or ready_hash.hexdigest()!=EXPECTED_READY_SHA256):raise AssertionError('loop entry golden changed')
        if tree_hash(source)!=PINNED_SOURCE_SHA256 or tree_hash(root/'src')!=PINNED_SOURCE_SHA256 or stdlib_hash(zig)!=PINNED_STDLIB_SHA256 or implementation_hashes(repo)!=impl or hashlib.sha256(Path(__file__).read_bytes()).hexdigest()!=runner_hash:raise AssertionError('dependency, implementation or runner changed')
        for name,expected in fixtures.items():
            if any(hashlib.sha256((base/name).read_bytes()).hexdigest()!=expected for base in (root,probe)):raise AssertionError('fixture changed')
        for name,expected in inputs.items():
            if hashlib.sha256((root/name).read_bytes()).hexdigest()!=expected:raise AssertionError('input changed')
        for name,expected in helpers.items():
            if hashlib.sha256((repo/'zigimg'/name).read_bytes()).hexdigest()!=expected:raise AssertionError('helper changed')
        summary=dict(returning_records=len(rows),calls=sum(int(data.split('|')[3]) for _,data in rows),returning_groups=dict(Counter(group for group,_ in rows)),output_sha256=digest,return_controls=sum(return_groups.values()),return_control_groups=dict(return_groups),control_sha256=controls_digest,paired_traps=sum(trap_groups.values()),failure_groups=dict(trap_groups),state_sha256=state_digest,paired_loops=len(loops()),ready_sha256=ready_hash.hexdigest(),zig_mode=mode,v_prod=args.v_prod)
        (root/'summary.json').write_text(json.dumps(summary,indent=2)+'\n');print(json.dumps(summary),flush=True)


if __name__=='__main__':main()
