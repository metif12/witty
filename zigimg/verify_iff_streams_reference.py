"""Compare IFF file traversal, palette/body prefixes and initialized ByteRun2 output."""
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

EXPECTED_ROWS = 44982
EXPECTED_SHA256 = '22ab2116317663553204d1ed60cf4c4c289f354f871b3e08308b848262ede051'
EXPECTED_CONTROLS = 3844
EXPECTED_CONTROL_SHA256 = 'c317076d4a2abcbe3d15d80c17312c2c23369817337bf97af1ee9145aa9a5f48'
EXPECTED_TRAPS = 463
EXPECTED_STATE_SHA256 = 'f4c04686c03679405c437dca8df0000d07116b6260d2d13bee36b178d354c1b9'
EXPECTED_LOOPS = 20
EXPECTED_READY_SHA256 = '894536978d1560d94b90e3ce5360d6c6a08415fa050b71807aa8174ee84ffad3'
from verify_iff_pixels_reference import chunk, form, raw_pixels, compress
from verify_iff_records_reference import MATH_SHA256
BUFFERS = (-1,20,21,32,64,128,512)

def spec(cap,op=2,data=b'',fmt=0,w=1,h=1,planes=8,comp=0,bits=4,pitch=2,mode=0,palette=4,length=0,start=0,attempts=2,output=0):
    return '|'.join(map(str,(op,0,fmt,w,h,planes,bits,pitch,mode,palette,length,start,(b'x'*start+data).hex(),comp,37,cap,attempts,output)))

def image(w=1,h=1,planes=8,comp=0,fmt=0,pattern=0):
    pitch=((w+15)//16)*2
    count=w*h*(3 if planes==24 else 1)
    values=[((i*37+19)&255 if pattern==0 else 0 if pattern==1 else 255) & ((1<<planes)-1) for i in range(count)]
    raw=raw_pixels(values,w,h,planes,pitch,comp==2 or fmt==2,fmt)
    body=compress(raw,comp,pitch,h,planes,fmt)
    cmap=bytes((i*37+19)&255 for i in range(96))
    return form(chunk(b'CMAP',cmap)+chunk(b'BODY',body),w,h,planes,comp,fmt),body

def corpus():
    rows=[]
    for cap,op,fmt,w,h,planes,comp,pattern in itertools.product(BUFFERS,(2,3,4),range(3),(1,3,16,17),(1,2),(1,4,8,24),range(3),range(3)):
        if fmt==1 and planes<8:continue
        data,_=image(w,h,planes,comp,fmt,pattern)
        rows.append(('complete-decoding',spec(cap,op,data,fmt,w,h,planes,comp)))
    for cap,op,comp,start in itertools.product(BUFFERS,(2,3,4),range(3),(0,3)):
        data,_=image(comp=comp)
        for cut in range(len(data)+1):
            if cap>=0 and comp==2 and 152<=cut<256 and (cut-152)%13<8:continue
            rows.append(('prefix-retry',spec(cap,op,data[:cut],comp=comp,start=start)))
    for cap,op,first in itertools.product((-1,12,20,32,128),(5,6,7,8),range(256)):
        rows.append(('detector-byte',spec(cap,op,bytes((first,))+b'ORM'+bytes(4)+b'ILBM')))
    for cap,op,data,start in itertools.product((-1,12,20,32,128),(5,6,7,8),(b'',b'FORM',b'FORM'+bytes(4)+b'PBM ',b'FORM'+bytes(4)+b'DEEP'),(0,3)):
        rows.append(('detector-prefix',spec(cap,op,data,start=start)))
    for cap,length,cut,start in itertools.product((-1,3,4,8,20,32,128),(3,4,5,6,7,12,13,48,49),(0,1,2,3,4,5,6,7,11,12,47,48,49),(0,3)):
        data=bytes((i*37+19)&255 for i in range(cut))
        rows.append(('palette-prefix-retry',spec(cap,9,data,length=length,start=start)))
    for cap,cut,start in itertools.product((-1,4,8,20,128),range(9),(0,3)):
        rows.append(('viewport-prefix-retry',spec(cap,10,bytes(range(cut)),start=start)))
    # Direct body decoding has no private chunk traversal and fully written output.
    for cap,fmt,comp,start in itertools.product(BUFFERS,range(3),range(3),(0,3)):
        _,body=image(w=3,h=2,planes=8,comp=comp,fmt=fmt)
        rows.append(('direct-body',spec(cap,0,body,fmt,w=3,h=2,comp=comp,length=len(body),start=start,attempts=1 if cap>=0 and comp==2 else 2)))
    # Unknown chunk controls execute individually: file seekBy can change their path.
    return rows

def controls():
    cases=[]
    def add(group,data,**kw):
        name=f'{group}-{sum(g==group for g,_,_ in cases)}'
        cases.append((group,name,spec(data=data,attempts=1,**kw)))
    base,_=image()
    prefix=base[:144] # FORM/BMHD followed by a complete 32-color CMAP.
    body=base[144:]
    for cap,op,length,actual,start in itertools.product(BUFFERS,(1,2,3,4),(0,1,3,4,7,8,12,16,31,32,63,128,0xffffffff),(0,1,3,8,16),(0,3)):
        if op==1:
            data=chunk(b'CMAP',bytes(96))+chunk(b'JUNK',b'j'*actual,length)+body
        else:
            data=prefix+chunk(b'JUNK',b'j'*actual,length)+body
        add('unknown-chunk-seek',data,cap=cap,op=op,start=start)
    for cap,op in itertools.product((0,1,7,8,11,12,19),(2,3,4,5,6,7,8)):
        add('small-header-buffer',base,cap=cap,op=op)
    for cap,op,field,value in itertools.product((-1,20,32),(2,3,4),(29,30),(4,255)):
        data=bytearray(base);data[field]=value
        add('parsed-enum',bytes(data),cap=cap,op=op)
    for cap,op,planes,comp in itertools.product(BUFFERS,(2,3,4),(1,8,24),range(3)):
        add('zero-pitch',form(chunk(b'BODY',bytes(8)),0,1,planes,comp),cap=cap,op=op)
    for cap,length in itertools.product((-1,0,1,2,3,20),(0,1,2,768,769,771,0xffffffff)):
        add('palette-boundary',bytes(768),cap=cap,op=9,length=length)
    for cap,command,cut,output in itertools.product((-1,0,1,2,3,8,20),(b'\xff',b'\x01',b'\x00'),(0,1,2,3),(0,1,2,4)):
        data=bytes(8)+b'\x00\x03'+command+bytes((0x12,0x34,0x56))[:cut]
        add('byterun2-output',data,cap=cap,op=11,planes=1,pitch=2,output=output)
    for cap,count in itertools.product((-1,0,1,2,20),(0,1,2)):
        add('byterun2-command-length',bytes(8)+count.to_bytes(2,'big'),cap=cap,op=11,planes=1,pitch=2,output=2)
    return cases

def loops():
    cases=[]
    data,_=image(comp=2)
    for cap,op,cut in itertools.product((20,128),(2,3,4),(152,159)):
        cases.append((f'public-discard-{cap}-{op}-{cut}',spec(cap,op,data[:cut],comp=2,attempts=1)))
    for cap,op,cut in itertools.product((20,128),(0,11),(0,7)):
        cases.append((f'direct-discard-{cap}-{op}-{cut}',spec(cap,op,bytes(cut),comp=2,planes=1,attempts=1,output=2)))
    return cases


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source',type=Path);parser.add_argument('zig',type=Path);parser.add_argument('v',type=Path)
    parser.add_argument('--target',default='aarch64-macos.14.0');parser.add_argument('--v-prod',action='store_true')
    parser.add_argument('--workdir',type=Path);parser.add_argument('--timeout',type=int,default=180)
    args=parser.parse_args()
    if args.timeout<=0:parser.error('--timeout must be positive')
    source=args.source.resolve()/'src';zig=args.zig.resolve();v=args.v.resolve()
    if tree_hash(source)!=PINNED_SOURCE_SHA256 or stdlib_hash(zig)!=PINNED_STDLIB_SHA256 or hashlib.sha256((zig.parent/'lib/std/math.zig').read_bytes()).hexdigest()!=MATH_SHA256:parser.error('Source or compiler library differs from pins')
    repo=Path(__file__).resolve().parent.parent;probe=repo/'zigimg/reference_probes/iff_streams'
    mode='ReleaseSafe' if args.v_prod else 'Debug'
    with work_directory(args.workdir,'witty-pcx-streams-') as root:
        tmp=root/'tmp';tmp.mkdir();env=dict(os.environ,TMPDIR=str(tmp),VTMP=str(tmp),VEXE=str(v),V_C_ERROR_BUG_REPORT_DISABLED='1')
        proof=ProofLog(root);shutil.copytree(source,root/'src');fixtures={}
        for name in ('main.v','reference.zig'):
            shutil.copyfile(probe/name,root/name);fixtures[name]=hashlib.sha256((root/name).read_bytes()).hexdigest()
        versions=[proof.run([str(exe),'version'],label,env=env).stdout.decode().strip() for exe,label in ((zig,'zig-version'),(v,'v-version'))]
        if versions[0]!='0.15.2' or not re.match(r'^V 0\.5\.2(?: |$)',versions[1]):raise AssertionError('unexpected compiler versions')
        impl=implementation_hashes(repo);runner_hash=hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
        helpers={name:hashlib.sha256((repo/'zigimg'/name).read_bytes()).hexdigest() for name in ('verify_jpeg_contracts_reference.py','verify_tiff_decode_reference.py','verify_tga_decode_reference.py','verify_iff_pixels_reference.py','verify_iff_records_reference.py')}
        (root/'provenance.json').write_text(json.dumps(dict(source_sha256=PINNED_SOURCE_SHA256,stdlib_sha256=PINNED_STDLIB_SHA256,math_sha256=MATH_SHA256,versions=versions,target=args.target,zig_mode=mode,v_prod=args.v_prod,implementation_sha256=impl,runner_sha256=runner_hash,fixtures=fixtures,helper_sha256=helpers),indent=2)+'\n')
        print(f'Building IFF streams: Source {mode}, V {"production" if args.v_prod else "ordinary"}',flush=True)
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
        print(f'{len(rows)} returning records match; checking buffered traversal and direct output',flush=True)
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
                    if len(found)!=1 or not re.fullmatch(r'integer overflow|index out of bounds: index \d+, len \d+|reached unreachable code|invalid enum value|division by zero',found[0]):raise AssertionError(f'{name}/{exe}: unexpected panic {found}')
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
        if len(loops())!=EXPECTED_LOOPS or ready_hash.hexdigest()!=EXPECTED_READY_SHA256:raise AssertionError('loop entry golden changed')
        if tree_hash(source)!=PINNED_SOURCE_SHA256 or tree_hash(root/'src')!=PINNED_SOURCE_SHA256 or stdlib_hash(zig)!=PINNED_STDLIB_SHA256 or hashlib.sha256((zig.parent/'lib/std/math.zig').read_bytes()).hexdigest()!=MATH_SHA256 or implementation_hashes(repo)!=impl or hashlib.sha256(Path(__file__).read_bytes()).hexdigest()!=runner_hash:raise AssertionError('dependency, implementation or runner changed')
        for name,expected in fixtures.items():
            if any(hashlib.sha256((base/name).read_bytes()).hexdigest()!=expected for base in (root,probe)):raise AssertionError('fixture changed')
        for name,expected in inputs.items():
            if hashlib.sha256((root/name).read_bytes()).hexdigest()!=expected:raise AssertionError('input changed')
        for name,expected in helpers.items():
            if hashlib.sha256((repo/'zigimg'/name).read_bytes()).hexdigest()!=expected:raise AssertionError('helper changed')
        summary=dict(returning_records=len(rows),calls=sum(int(data.split('|')[16]) for _,data in rows),returning_groups=dict(Counter(group for group,_ in rows)),output_sha256=digest,return_controls=sum(return_groups.values()),return_control_groups=dict(return_groups),control_sha256=controls_digest,paired_traps=sum(trap_groups.values()),failure_groups=dict(trap_groups),state_sha256=state_digest,paired_loops=len(loops()),ready_sha256=ready_hash.hexdigest(),excluded_loop_prefixes=2304,zig_mode=mode,v_prod=args.v_prod)
        (root/'summary.json').write_text(json.dumps(summary,indent=2)+'\n');print(json.dumps(summary),flush=True)


if __name__=='__main__':main()
