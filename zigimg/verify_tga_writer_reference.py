"""Compare TGA positional encoding, retained buffers and short pixel failures."""
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

ENCODER_LIBRARIES = {'simd.zig': 'cc554020cebe55782b38c18c56a011b61a42f332781e5d0a5b1be3003eddd7a3', 'math.zig': '65645001357d5f78cbf646485e009a048b828680bb1b47fb3de0fd8617d91af1'}

def encoder_library_hashes(zig):
    return {name: hashlib.sha256((zig.parent/'lib/std'/name).read_bytes()).hexdigest() for name in ENCODER_LIBRARIES}

EXPECTED_ROWS = 25624
EXPECTED_SHA256 = 'd251c2eb846597f3d5ca26fb0cac1c6a2b3bf1cdb9ee971f22aa515b9307bac7'
EXPECTED_CONTROLS = 1060
EXPECTED_CONTROL_SHA256 = 'c5b49c5e66bb284b516f647dd7993986bd909e41c4df551e60c6b50eb0b7b410'
EXPECTED_TRAPS = 1278
EXPECTED_STATE_SHA256 = '63a9bfc5ca634b68d5d10a8648bb6a6d1022554599f8571c2c79ae311aee4f37'
FORMATS=(0x108,8,0x305,0x1308,0x1408,0x308,0x408)
ALL_FORMATS=(0,1,2,4,8,16,0x101,0x102,0x104,0x108,0x110,0x208,0x210,0x303,0x305,0x3305,0x308,0x408,0x1305,0x1308,0x1408,0x310,0x410,0x2420)
BUFFERS=(-4097,0,1,3,8,32,128)

def spec(cap,op=0,w=1,h=1,fmt=0x108,count=None,pattern=0,palette=4,start=0,attempts=2,rle=True,top=True,depth=24,id_len=3,meta=1,direct=0):
    if count is None:count=w*h
    return '|'.join(map(str,(cap,op,w,h,fmt,count,pattern,palette,start,attempts,int(rle),int(top),depth,id_len,meta,direct)))

def corpus():
    rows=[]
    for cap,op,fmt,dims,pattern,rle,top,start in itertools.product(BUFFERS,range(3),FORMATS,((0,0),(1,1),(3,2),(17,2),(129,1)),range(4),(False,True),(False,True),(0,7)):
        rows.append(('buffered-encoding',spec(cap,op,*dims,fmt,pattern=pattern,rle=rle,top=top,start=start)))
    for cap,op,fmt in itertools.product((-1,-19,-514,-522,-1025,-4097,0,1,8,512),range(3),ALL_FORMATS):
        rows.append(('storage-dispatch',spec(cap,op,w=0,h=0,fmt=fmt,count=0)))
    for cap,op,id_len,meta,depth in itertools.product((-4097,0,1,8,128),(1,2),(0,1,255,256,257),(0,1,2,3,4),(0,16,24,32)):
        rows.append(('option-validation',spec(cap,op,w=0,h=0,count=0,id_len=id_len,meta=meta,depth=depth)))
    for cap,op,count,rle,top in itertools.product((-4097,0,3,32),range(3),(0,1,17,127,128,129,255),(False,True),(False,True)):
        # Whole raw top-to-bottom slices include extra pixels even with zero extents.
        rows.append(('whole-slice-and-zero-extents',spec(cap,op,w=0,h=0,fmt=0x1308,count=count,rle=rle,top=top)))
    for cap,op,dims in itertools.product((-1,-19,-4097,0,1,128),(1,2),((65536,0),(0,65536),(2**64-1,1),(1,2**64-1))):
        rows.append(('wide-image-rejection',spec(cap,op,*dims,count=0)))
    return rows

def controls():
    cases=[]
    def add(group,cap,**kw):
        name=f'{group}-{sum(g==group for g,_,_ in cases)}';kw.setdefault('attempts',1)
        cases.append((group,name,spec(cap,**kw)))
    for cap,op,fmt,shape,rle,top in itertools.product((-1,-19,-4097,0,1,8,128),range(3),FORMATS,((1,1,0),(3,2,4),(17,2,18)),(False,True),(False,True)):
        w,h,count=shape;add('short-storage',cap,op=op,w=w,h=h,fmt=fmt,count=count,rle=rle,top=top,pattern=2)
    for cap,palette,depth,direct in itertools.product((-1,-19,-4097,0,1,8,128),(0,1,4),(0,15,16,24,32),(1,2)):
        add('palette-bounds',cap,fmt=8,palette=palette,depth=depth,direct=direct)
    for cap,fmt,rle,top in itertools.product((-1,-19,-4097,0,1,8,128),FORMATS,(False,True),(False,True)):
        add('id-mismatch',cap,fmt=fmt,id_len=0,direct=3,rle=rle,top=top)
    for cap,op,fmt,rle in itertools.product((-4097,0,3,128),range(3),FORMATS,(False,True)):
        add('wide-row-geometry',cap,op=op,w=65535,h=65535,fmt=fmt,count=0,rle=rle,top=False)
    return cases

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source',type=Path);parser.add_argument('zig',type=Path);parser.add_argument('v',type=Path)
    parser.add_argument('--target',default='aarch64-macos.14.0');parser.add_argument('--v-prod',action='store_true')
    parser.add_argument('--workdir',type=Path);parser.add_argument('--timeout',type=int,default=180)
    args=parser.parse_args()
    if args.timeout<=0:parser.error('--timeout must be positive')
    source=args.source.resolve()/'src';zig=args.zig.resolve();v=args.v.resolve()
    if tree_hash(source)!=PINNED_SOURCE_SHA256 or stdlib_hash(zig)!=PINNED_STDLIB_SHA256 or encoder_library_hashes(zig)!=ENCODER_LIBRARIES:parser.error('Source or compiler library differs from pins')
    repo=Path(__file__).resolve().parent.parent;probe=repo/'zigimg/reference_probes/tga_writer'
    mode='ReleaseSafe' if args.v_prod else 'Debug'
    with work_directory(args.workdir,'witty-pcx-streams-') as root:
        tmp=root/'tmp';tmp.mkdir();env=dict(os.environ,TMPDIR=str(tmp),VTMP=str(tmp),VEXE=str(v),V_C_ERROR_BUG_REPORT_DISABLED='1')
        proof=ProofLog(root);shutil.copytree(source,root/'src');fixtures={}
        for name in ('main.v','reference.zig'):
            shutil.copyfile(probe/name,root/name);fixtures[name]=hashlib.sha256((root/name).read_bytes()).hexdigest()
        versions=[proof.run([str(exe),'version'],label,env=env).stdout.decode().strip() for exe,label in ((zig,'zig-version'),(v,'v-version'))]
        if versions[0]!='0.15.2' or not re.match(r'^V 0\.5\.2(?: |$)',versions[1]):raise AssertionError('unexpected compiler versions')
        impl=implementation_hashes(repo);runner_hash=hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
        helpers={name:hashlib.sha256((repo/'zigimg'/name).read_bytes()).hexdigest() for name in ('verify_jpeg_contracts_reference.py','verify_tiff_decode_reference.py','verify_tga_decode_reference.py')}
        (root/'provenance.json').write_text(json.dumps(dict(source_sha256=PINNED_SOURCE_SHA256,stdlib_sha256=PINNED_STDLIB_SHA256,encoder_libraries=ENCODER_LIBRARIES,versions=versions,target=args.target,zig_mode=mode,v_prod=args.v_prod,implementation_sha256=impl,runner_sha256=runner_hash,fixtures=fixtures,helper_sha256=helpers),indent=2)+'\n')
        print(f'Building TGA streams: Source {mode}, V {"production" if args.v_prod else "ordinary"}',flush=True)
        proof.run([str(zig),'build-exe','-target',args.target,'-lc','-O',mode,'--global-cache-dir',str(root.parent/'zig-global'),'--cache-dir',str(root/'zig-cache'),'-femit-bin='+str(root/'native'),str(root/'reference.zig')],'build-source',env=env,timeout=args.timeout)
        proof.run([str(v),'-enable-globals',*(['-prod'] if args.v_prod else []),'-path',f'{repo}|@vlib|@vmodules','-o',str(root/'translated'),str(root/'main.v')],'build-v',env=env,timeout=args.timeout)
        rows=corpus();path=root/'corpus.txt';path.write_text('\n'.join(data for _,data in rows)+'\n')
        inputs={'corpus.txt':hashlib.sha256(path.read_bytes()).hexdigest()}
        (root/'input_sha256.json').write_text(json.dumps(inputs,indent=2)+'\n')
        outputs=[]
        for exe in ('native','translated'):
            r=proof.run([str(root/exe),str(path)],'returning-'+exe,env=env,timeout=args.timeout,check=False)
            if r.returncode or r.stderr or len(r.stdout.splitlines())!=len(rows):raise AssertionError(f'{exe}: invalid returning output; see raw proof files')
            outputs.append(r.stdout.splitlines())
        for i,(native,translated) in enumerate(zip(*outputs)):
            if native!=translated:raise AssertionError(f'{i}/{rows[i][0]}: output differs; see raw proof files')
        digest=hashlib.sha256(b'\n'.join(outputs[0])).hexdigest()
        if EXPECTED_ROWS is not None and (len(rows)!=EXPECTED_ROWS or digest!=EXPECTED_SHA256):raise AssertionError('returning golden changed')
        print(f'{len(rows)} returning records match; checking short storage and arithmetic',flush=True)
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
                    if len(found)!=1 or not re.fullmatch(r'integer overflow|index out of bounds: index \d+, len \d+',found[0]):raise AssertionError(f'{name}/{exe}: unexpected panic {found}')
                    checked_trap(result,name+'/'+exe,found[0]);messages.append(found[0])
                    if not state.exists():raise AssertionError('missing panic observer')
                if messages[0]!=messages[1]:raise AssertionError(f'{name}: exact panic differs: {messages}')
                observed=[state.read_bytes() for _,state in records]
                if not observed[0] or observed[0]!=observed[1]:raise AssertionError(f'{name}: failure state differs')
                states.update(name.encode()+b'\0'+messages[0].encode()+b'\0'+observed[0]+b'\n');trap_groups[group]+=1
        controls_digest=returns.hexdigest();state_digest=states.hexdigest()
        if EXPECTED_CONTROLS is not None and (sum(return_groups.values())!=EXPECTED_CONTROLS or controls_digest!=EXPECTED_CONTROL_SHA256):raise AssertionError('return controls changed')
        if EXPECTED_TRAPS is not None and (sum(trap_groups.values())!=EXPECTED_TRAPS or state_digest!=EXPECTED_STATE_SHA256):raise AssertionError('failure golden changed')
        if tree_hash(source)!=PINNED_SOURCE_SHA256 or tree_hash(root/'src')!=PINNED_SOURCE_SHA256 or stdlib_hash(zig)!=PINNED_STDLIB_SHA256 or encoder_library_hashes(zig)!=ENCODER_LIBRARIES or implementation_hashes(repo)!=impl or hashlib.sha256(Path(__file__).read_bytes()).hexdigest()!=runner_hash:raise AssertionError('dependency, implementation or runner changed')
        for name,expected in fixtures.items():
            if any(hashlib.sha256((base/name).read_bytes()).hexdigest()!=expected for base in (root,probe)):raise AssertionError('fixture changed')
        for name,expected in inputs.items():
            if hashlib.sha256((root/name).read_bytes()).hexdigest()!=expected:raise AssertionError('input changed')
        for name,expected in helpers.items():
            if hashlib.sha256((repo/'zigimg'/name).read_bytes()).hexdigest()!=expected:raise AssertionError('helper changed')
        summary=dict(returning_records=len(rows),calls=sum(int(data.split('|')[9]) for _,data in rows),returning_groups=dict(Counter(group for group,_ in rows)),output_sha256=digest,return_controls=sum(return_groups.values()),return_control_groups=dict(return_groups),control_sha256=controls_digest,paired_traps=sum(trap_groups.values()),failure_groups=dict(trap_groups),state_sha256=state_digest,zig_mode=mode,v_prod=args.v_prod)
        (root/'summary.json').write_text(json.dumps(summary,indent=2)+'\n');print(json.dumps(summary),flush=True)


if __name__=='__main__':main()
