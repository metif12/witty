"""Compare unchanged IFF records, decoding, partial output and checked failures."""
import argparse
from collections import Counter
import hashlib
import json
import os
from pathlib import Path
import re
import shutil

from verify_jpeg_contracts_reference import implementation_hashes
from verify_tga_decode_reference import stdlib_hash, PINNED_STDLIB_SHA256
from verify_tiff_decode_reference import (
    ProofLog, tree_hash, work_directory, PINNED_SOURCE_SHA256, checked_trap,
)

EXPECTED_MAIN_SHA256 = '6cc1394883088df0aec445e92cbcb2da901e34d07b5fb11d47d968ecd6bea7ab'
EXPECTED_RETURN_SHA256 = '162b7a0ebf1e170cff5bfbee121a5a425d629dfa67307d8d496033eb1a7907a3'
EXPECTED_STATE_SHA256 = '2a7fb4333d9a2214a69aefd5cd60bd4cc0db24db1b9a134aa2ca913d2a363b0a'
EXPECTED_RETURNS = 68609
EXPECTED_TRAPS = 4449
import struct
MATH_SHA256='65645001357d5f78cbf646485e009a048b828680bb1b47fb3de0fd8617d91af1'
def bmhd(w=7,h=9,planes=1,mask=3,compression=2,length=20,kind=b'BMHD'):
    return kind+struct.pack('>IHHhhBBBBHBBHH',length,w,h,-7,-9,planes,mask,compression,19,513,23,29,31,37)
def image(data,format_name=b'ILBM'):
    return b'FORM\xff\xff\xff\xff'+format_name+data
def chunk(name,length,data=b''):
    return name+struct.pack('>I',length)+data

def corpus():
    rows=[];traps=[];counts=Counter()
    def add(group,data=b'',*,op=0,tag=0,fmt=0,w=7,h=9,planes=1,bits=7,pitch=2,mode=0,palette=4,length=0,start=0,panic=None):
        name=f'{group}-{counts[group]}';counts[group]+=1
        data=b'x'*start+data
        line='|'.join(str(value) for value in (op,tag,fmt,w,h,planes,bits,pitch,mode,palette,length,start,data.hex()))
        (traps if panic else rows).append((group,name,line,panic))
    for tag in (0,1):
        for w in (0,1,32768,65535):
            for h in (0,1,32768,65535):add('dimensions',op=8,tag=tag,w=w,h=h)
    for tag in (0,1):
        for planes in range(256):
            for mode in (0,0x80,0x800,0x880,0xffffffff):
                panic="access of union field 'bmhd' while field 'dgbl' is active" if tag==1 and not mode&0x800 else None
                add('format',op=7,tag=tag,planes=planes,mode=mode,panic=panic)
    for mask in range(4):
        for compression in range(3):
            for planes in (0,1,8,24,255):
                for op in (0,1):
                    for start in (0,3):add('parsed-header',bmhd(planes=planes,mask=mask,compression=compression),op=op,start=start)
    invalids=[(mask,0) for mask in range(4,256)]+[(0,compression) for compression in range(3,256)]+[(mask,compression) for mask,compression in ((4,3),(255,255),(4,255),(255,3))]
    for mask,compression in invalids:
        for op in (0,1,2,11):
            data=bmhd(mask=mask,compression=compression)
            if op in (2,11):data=image(data)
            add('enum',data,op=op,start=3,panic='invalid enum value')
    invalid=bmhd(mask=255,compression=255)
    for op in (0,1,2,11):
        data=image(invalid) if op in (2,11) else invalid
        for cut in range(len(data)):add('enum-prefix',data[:cut],op=op,start=3)
    for kind,length in ((b'BODY',20),(b'BMHD',19),(b'BMHD',21),(b'BMHD',0xffffffff)):
        for op in (0,1,2,11):
            data=bmhd(mask=255,compression=255,length=length,kind=kind)
            if op in (2,11):data=image(data)
            add('header-validation',data,op=op,start=3)
    for fmt in range(5):
        for data in (b'',bmhd(),invalid):
            panic='invalid enum value' if fmt!=3 and data==invalid else None
            add('load-format',data,op=1,fmt=fmt,panic=panic)
    for op in (10,12,13):
        for name in (b'ILBM',b'PBM ',b'ACBM',b'DEEP',b'XXXX'):
            data=image(bmhd(),name)
            for cut in (*range(13),len(data)):
                for start in (0,3):add('magic',data[:cut],op=op,start=start)
        for i in range(4):
            data=bytearray(image(bmhd()));data[i]^=255
            add('bad-magic',bytes(data),op=op)
    for length in range(8):
        for start in (0,3):add('chunk-length',bytes(range(length)),op=9,start=start,panic='reached unreachable code' if length!=4 else None)
    for byte in range(256):add('chunk-borrow',bytes((byte,1,2,3)),op=9,start=3)
    for cut in range(6):
        for start in (0,3):add('camg',b'\x12\x34\x56\x78xy'[:cut],op=3,start=start)
    for length in (0,1,2,3,4,5,6,7,8,9,45,48,49,189,192,193,765,768,769,770,771,780,65535,0xffffffff):
        colors=length//3
        for cut in sorted({0,1,max(0,min(length,771)-1),min(length,771),min(length,771)+3}):
            data=bytes((i*37+19)&255 for i in range(cut))
            panic=(f'index out of bounds: index {colors}, len 256' if colors>256 else 'reached unreachable code' if colors==0 else None)
            for start in (0,3):add('cmap',data,op=4,length=length,start=start,panic=panic)
    for palette in (0,1,4,16,32,64,256):add('ehb',op=5,palette=palette)
    for planes in range(256):
        for bits in range(256):
            panic=None
            if bits>planes:
                if bits-planes+2>255 or bits < bits-planes+2:panic='integer overflow'
                elif planes-2<4:panic='reached unreachable code'
            add('ham-exhaustive',op=6,planes=planes,bits=bits,panic=panic)
    for palette in (0,1,4,16,64,256):
        for bits in (0,1,5,6,8,63,64,65,66,127,128,129,254,255):
            for planes in (0,1,2,5,6,8,64,65,66,127,128,254,255):
                panic=None
                if bits>planes:
                    if bits-planes+2>255 or bits < bits-planes+2:panic='integer overflow'
                    elif planes-2<4:panic='reached unreachable code'
                add('ham-palette',op=6,planes=planes,bits=bits,palette=palette,panic=panic)
    for bits in (0,1,5,8,64,255):add('ham-union',op=6,tag=1,bits=bits,panic="access of union field 'bmhd' while field 'dgbl' is active")
    # Public reads stop before the larger conversion/RLE checks in this scope.
    for w in (0,1,15,16,17,32768,65535):
        for h in (0,1,65535):
            for name in (b'ILBM',b'PBM ',b'ACBM'):
                for op in (2,11):add('public-header',image(bmhd(w,h),name),op=op)
    for length in (0,1,2,771,780,65535,0xffffffff):
        colors=length//3
        panic=f'index out of bounds: index {colors}, len 256' if colors>256 else 'reached unreachable code'
        for op in (2,11):add('public-cmap',image(bmhd())+chunk(b'CMAP',length),op=op,panic=panic)
    for name in (b'ILBM',b'ACBM',b'PBM '):
        for w in (1,2,7,8,15,16,17):
            for h in (1,2):
                for planes in (1,2,8,24):
                    if name==b'PBM ' and ((w+15)//16)*2*h*planes < w*h*(3 if planes==24 else 1):continue # defined public reads only
                    pitch=((w+15)//16)*2
                    raw=bytearray(pitch*h*planes)
                    # Zero padding bits guarantee all conversion accesses are defined.
                    if name==b'PBM ':
                        for i in range(len(raw)):raw[i]=(i*37+19)&255
                    else:
                        for row in range(h):
                            for plane in range(planes):
                                index=plane*pitch*h+row*pitch if name==b'ACBM' else row*pitch*planes+plane*pitch
                                raw[index]=0x80
                    data=image(bmhd(w,h,planes,compression=0),name)+chunk(b'CMAP',12,bytes(range(12)))+chunk(b'BODY',0,bytes(raw))
                    for op in (2,11):add('public-defined-decode',data,op=op)
    return rows,traps


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source',type=Path);parser.add_argument('zig',type=Path);parser.add_argument('v',type=Path)
    parser.add_argument('--target',default='aarch64-macos.14.0');parser.add_argument('--v-prod',action='store_true')
    parser.add_argument('--workdir',type=Path);parser.add_argument('--timeout',type=int,default=180)
    args=parser.parse_args()
    if args.timeout<=0:parser.error('--timeout must be positive')
    source=args.source.resolve()/'src';zig=args.zig.resolve();v=args.v.resolve()
    if tree_hash(source)!=PINNED_SOURCE_SHA256 or stdlib_hash(zig)!=PINNED_STDLIB_SHA256 or hashlib.sha256((zig.parent/'lib/std/math.zig').read_bytes()).hexdigest()!=MATH_SHA256:parser.error('Source or selected library differs from pins')
    repo=Path(__file__).resolve().parent.parent;probe=repo/'zigimg/reference_probes/iff_records'
    mode='ReleaseSafe' if args.v_prod else 'Debug';env=dict(os.environ,VEXE=str(v),V_C_ERROR_BUG_REPORT_DISABLED='1')
    with work_directory(args.workdir,'witty-iff-records-') as root:
        proof=ProofLog(root);shutil.copytree(source,root/'src');fixtures={}
        for name in ('main.v','reference.zig'):
            shutil.copyfile(probe/name,root/name);fixtures[name]=hashlib.sha256((root/name).read_bytes()).hexdigest()
        versions=[proof.run([str(exe),'version'],label,env=env).stdout.decode().strip() for exe,label in ((zig,'zig-version'),(v,'v-version'))]
        if versions[0]!='0.15.2' or not re.match(r'^V 0\.5\.2(?: |$)',versions[1]):raise AssertionError('unexpected compiler versions')
        implementations=implementation_hashes(repo);runner_hash=hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
        (root/'provenance.json').write_text(json.dumps(dict(source_sha256=PINNED_SOURCE_SHA256,stdlib_sha256=PINNED_STDLIB_SHA256,
            math_sha256=MATH_SHA256,versions=versions,target=args.target,zig_mode=mode,v_prod=args.v_prod,fixtures=fixtures,
            implementation_sha256=implementations,runner_sha256=runner_hash),indent=2)+'\n')
        zbase=[str(zig),'build-exe','-target',args.target,'-lc','-O',mode,'--global-cache-dir',str(root/'zig-global')]
        vbase=[str(v),'-enable-globals',*(['-prod'] if args.v_prod else []),'-path',f'{repo}|@vlib|@vmodules']
        print(f'Building IFF contracts: Source {mode}, V {"production" if args.v_prod else "ordinary"}',flush=True)
        proof.run(zbase+['-femit-bin='+str(root/'native'),str(root/'reference.zig')],'build-source',timeout=args.timeout)
        proof.run(vbase+['-o',str(root/'translated'),str(root/'main.v')],'build-v',env=env,timeout=args.timeout)
        outputs=[]
        for exe in ('native','translated'):
            result=proof.run([str(root/exe)],'options-'+exe,timeout=args.timeout)
            if result.stderr:raise AssertionError('unexpected options stderr')
            outputs.append(result.stdout)
        if outputs[0]!=outputs[1] or len(outputs[0].splitlines())!=15:raise AssertionError('records or borrowed header names differ')
        main_digest=hashlib.sha256(outputs[0]).hexdigest()
        boxed=[]
        for exe in ('native','translated'):
            result=proof.run([str(root/exe),'--boxed'],'boxed-'+exe,timeout=args.timeout)
            if result.stderr:raise AssertionError('unexpected boxed diagnostic')
            boxed.append(result.stdout)
        if boxed!=[b'7|9\n',b'9|9\n']:raise AssertionError('boxed payload-copy boundary changed')
        rows,traps=corpus();inputs={};consumer_hashes={}
        file=root/'corpus.txt';file.write_text('\n'.join(row for group,name,row,panic in rows)+'\n')
        inputs[file.name]=hashlib.sha256(file.read_bytes()).hexdigest()
        outputs=[]
        for exe in ('native','translated'):
            result=proof.run([str(root/exe),'--corpus',str(file)],'corpus-'+exe,timeout=args.timeout)
            if result.stderr:raise AssertionError('unexpected corpus stderr')
            outputs.append(result.stdout.splitlines())
        if any(len(output)!=len(rows) for output in outputs):raise AssertionError(f'corpus counts differ: {[len(x) for x in outputs]} expected {len(rows)}')
        returns=hashlib.sha256();states=hashlib.sha256();return_groups=Counter();trap_groups=Counter()
        for (group,name,row,panic),native,translated in zip(rows,*outputs):
            if native!=translated:raise AssertionError(f'{name}: {native!r} != {translated!r}; input {row}')
            returns.update(name.encode()+b'\0'+native+b'\n');return_groups[group]+=1
        print(f'{len(rows)} returning records match; checking {len(traps)} strict failures',flush=True)
        for group,name,row,message in traps:
            path=root/(name+'.txt');path.write_text(row);inputs[path.name]=hashlib.sha256(path.read_bytes()).hexdigest()
            records=[]
            for exe in ('native','translated'):
                path=root/(name+'-'+exe+'.state')
                result=proof.run([str(root/exe),'--case',str(path),row],name+'-'+exe,timeout=args.timeout,check=False)
                checked_trap(result,name+'/'+exe,message)
                messages=[m.group(1) for line in result.stderr.decode().splitlines()
                          if (m:=re.fullmatch(r'(?:thread \d+ |V )?panic:\s*(.*)',line.strip()))]
                if messages!=[message] or not path.exists():raise AssertionError('exact panic or state missing')
                records.append(path.read_bytes())
            if not records[0] or records[0]!=records[1]:raise AssertionError(f'{name}: differing state {records}')
            states.update(name.encode()+b'\0'+message.encode()+b'\0'+records[0]+b'\n');trap_groups[group]+=1
        from verify_simd_reference import ordinary_rejection
        def pair(label,zbody,vbody,zmarker=None,vmarker=None):
            paths=[root/(label+'.zig'),root/(label+'.v')]
            paths[0].write_text('const p=@import("src/formats/iff.zig");pub fn main() void {'+zbody+'}\n')
            paths[1].write_text('module main\nimport zigimg as p\nfn main(){\n'+vbody+'\n}\n')
            for path in paths:consumer_hashes[path.name]=hashlib.sha256(path.read_bytes()).hexdigest()
            for language,command,marker in (
                ('Source',zbase+['-fno-emit-bin',str(paths[0])],zmarker),
                ('V',vbase+['-check','-o',str(root/(label+'-checked')),str(paths[1])],vmarker)):
                result=proof.run(command,label+'-'+language,env=env,timeout=args.timeout,check=False)
                diagnostic=(result.stdout+result.stderr).decode(errors='replace')
                errors=[line for line in diagnostic.splitlines() if re.search(r'\berror:',line)]
                if marker is None:
                    if result.returncode or errors:raise AssertionError(f'{label}/{language}: expected acceptance\n{diagnostic}')
                else:
                    ordinary_rejection(result,label+'/'+language)
                    if not any(marker in line for line in errors):raise AssertionError(f'{label}/{language}: diagnostic missing {marker!r}\n{diagnostic}')
        for typ,vtyp,fields in (
                ('Chunk','IffChunk',{'id':('id','1'),'name':('name','"NAME"')}),
                ('ChunkHeader','IffChunkHeader',{'type':('type_','1'),'length':('length','2')})):
            for missing in (None,*fields):
                zvalues=','.join('.'+key+'='+value for key,(vkey,value) in fields.items() if key!=missing)
                vvalues=','.join(vkey+':'+('"NAME".bytes()' if key=='name' else value) for key,(vkey,value) in fields.items() if key!=missing)
                pair(typ+'-'+str(missing),'const x:p.'+typ+'=.{'+zvalues+'};_=x;',
                     'x:=p.'+vtyp+'{'+vvalues+'}\n_=x',
                     'missing struct field: '+missing if missing else None,
                     vtyp+'.'+fields[missing][0] if missing else None)
        pair('default-records','const x:p.BmhdHeader=.{};const y:p.DgblHeader=.{};const z:p.IFF=.{};_=x;_=y;_=z;',
             'x:=p.BmhdHeader{}\ny:=p.DgblHeader{}\nz:=p.IFF{}\n_=x\n_=y\n_=z')
        pair('const-chunk-name','var bytes=[_]u8{1,2,3,4};var x=p.Chunk.init(&bytes);x.name[0]=7;_=x;',
             'mut bytes:=[u8(1),2,3,4]\nmut x:=p.IffChunk.init(bytes)\nx.name[0]=7\n_=x','cannot assign to constant',None)
        pair('const-header-name','var x:p.ChunkHeader=.{.type=1,.length=2};const bytes=x.name();bytes[0]=7;',
             'mut x:=p.IffChunkHeader{type_:1,length:2}\nmut bytes:=x.name()\nbytes[0]=7\n_=bytes','cannot assign to constant',None)
        (root/'consumer_sha256.json').write_text(json.dumps(consumer_hashes,indent=2)+'\n')
        (root/'input_sha256.json').write_text(json.dumps(inputs,indent=2)+'\n')
        for name,digest in {**consumer_hashes,**inputs}.items():
            if hashlib.sha256((root/name).read_bytes()).hexdigest()!=digest:raise AssertionError('generated input or consumer changed')
        return_digest=returns.hexdigest();state_digest=states.hexdigest()
        if (tree_hash(source)!=PINNED_SOURCE_SHA256 or tree_hash(root/'src')!=PINNED_SOURCE_SHA256
                or stdlib_hash(zig)!=PINNED_STDLIB_SHA256 or hashlib.sha256((zig.parent/'lib/std/math.zig').read_bytes()).hexdigest()!=MATH_SHA256 or implementation_hashes(repo)!=implementations
                or hashlib.sha256(Path(__file__).read_bytes()).hexdigest()!=runner_hash):raise AssertionError('dependency, implementation or runner changed')
        for name,expected in fixtures.items():
            if any(hashlib.sha256((base/name).read_bytes()).hexdigest()!=expected for base in (root,probe)):raise AssertionError('fixture changed')
        summary=dict(main_records=15,main_sha256=main_digest,returning_records=len(rows),return_groups=dict(return_groups),
            return_sha256=return_digest,paired_traps=len(traps),failure_groups=dict(trap_groups),state_sha256=state_digest,
            complete_constructor_pairs=2,required_field_pairs=4,default_record_pairs=1,
            const_slice_adaptations=2,boxed_copy_adaptations=1,zig_mode=mode,v_prod=args.v_prod)
        (root/'summary.json').write_text(json.dumps(summary,indent=2)+'\n');print(json.dumps(summary),flush=True)
        if main_digest!=EXPECTED_MAIN_SHA256 or return_digest!=EXPECTED_RETURN_SHA256 or state_digest!=EXPECTED_STATE_SHA256:
            raise AssertionError('locked golden changed')
        if len(rows)!=EXPECTED_RETURNS or len(traps)!=EXPECTED_TRAPS:raise AssertionError('locked counts changed')


if __name__=='__main__':main()
