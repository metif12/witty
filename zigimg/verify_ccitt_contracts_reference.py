"""Compare CCITT records, lookups, decoding and retained failures with unchanged Source."""
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
from verify_tiff_decode_reference import ProofLog, tree_hash, work_directory, PINNED_SOURCE_SHA256, checked_trap
from verify_simd_reference import ordinary_rejection
from verify_bitstream_contracts_reference import Model, ReturningError

EXPECTED_RETURNS = 243904
EXPECTED_TRAPS = 2476
EXPECTED_RETURN_SHA256 = 'b8944f0d9d04f1546416591d8afb61138d85f0022fb2312c72e6d6d855aba394'
EXPECTED_STATE_SHA256 = '2ee32767c8af907f13cb06609c1a4d24102f4c17193aa22236ebe764e6b8cc46'
CAST = 'integer does not fit in destination type'
OVERFLOW = 'integer overflow'

class CheckedFailure(Exception):
    pass


def code_tables(source):
    text=(source/'compressions/ccitt.zig').read_text()
    names=('white_terminating_codes','black_terminating_codes','white_make_up_codes','black_make_up_codes','additional_make_up_codes')
    tables=[]
    for name in names:
        block=re.search(r'pub const '+name+r' = \[_\]Code\{(.*?)\n\};',text,re.S).group(1)
        records=[(int(run),int(code[2:],2),int(length)) for run,code,length in re.findall(r'\.run_length = (\d+), \.code = (0b[01]+), \.code_length = (\d+)',block)]
        tables.append(records)
    if sum(map(len,tables))!=195:raise AssertionError('unexpected table extent')
    return tables


def lookup(tables,color,reverse,code,length,op):
    if code>8191:raise CheckedFailure(CAST)
    if op!=1:
        for run,value,width in [*tables[4],*tables[2 if color else 3]]:
            if (value,width)==(code,length):return run,reverse
    if op!=0:
        for run,value,width in tables[0 if color else 1]:
            if (value,width)==(code,length):return run,True
    return None,reverse


def classify(tables,op,width,rows,white,color,reverse,code,length,capacity,segments,start,wstart):
    if op in (4,5,7):return None
    if white>1:return CAST
    if op==6:return None
    if op!=3:
        return CAST if code>8191 else None
    output_position=wstart
    try:
        for index,data in enumerate(segments):
            reader=Model(1,8,0,0,0,capacity,data,start if index==0 else 0)
            writer=Model(1,8,1,0,0,capacity,b'',output_position)
            code_length=code_value=decoded_bits=0
            try:
                for _ in range(rows):
                    remaining=width
                    while remaining>0 and code_length<14:
                        value,_=reader.read(1)
                        code_value=((code_value<<1)|value)&8191;code_length+=1
                        run,reverse=lookup(tables,color,reverse,code_value,code_length,2)
                        if run is not None:
                            if remaining<run:raise CheckedFailure(OVERFLOW)
                            remaining-=run
                            if decoded_bits+code_length>65535:raise CheckedFailure(OVERFLOW)
                            decoded_bits+=code_length
                            for _ in range(run):writer.write(1,white if color else white^1)
                            code_value=code_length=0
                            if reverse:color^=1;reverse=False
                    remainder=decoded_bits%8
                    if remainder:
                        padding,_=reader.read(8-remainder)
                        if padding>1:raise CheckedFailure(CAST)
                    if remaining:raise ReturningError
            except ReturningError:pass
            output_position=writer.pos
    except CheckedFailure as failure:return str(failure)
    return None


def pack(codes):
    text=''.join(f'{code:0{length}b}' for code,length in codes)
    text+='0'*(-len(text)%8)
    return bytes(int(text[i:i+8],2) for i in range(0,len(text),8))


def corpus(source):
    tables=code_tables(source);rows_out,traps,counts=[],[],Counter()
    def add(group,*,op=3,width=8,rows=1,white=1,color=1,reverse=False,code=0,length=0,capacity=16,data=b'',segments=None,start=0,wstart=0):
        segments=[data] if segments is None else segments
        segments=[b'x'*start+segments[0],*segments[1:]]
        message=classify(tables,op,width,rows,white,color,reverse,code,length,capacity,segments,start,wstart)
        name=f'{group}-{counts[group]}';counts[group]+=1
        line='|'.join(map(str,(op,width,rows,white,color,int(reverse),code,length,capacity,','.join(s.hex() for s in segments),start,wstart)))
        (traps if message else rows_out).append((group,name,line,message))
    add('tables',op=5)
    for color in (0,1):
        for code in range(8192):
            for length in (0,4,8,12,13,14,255):
                add('lookup-code-domain',op=2,color=color,code=code,length=length,capacity=0)
    unique=sorted({(code,length) for table in tables for run,code,length in table})
    for color in (0,1):
        for code,actual_length in unique:
            for length in range(256):
                add('lookup-length-domain',op=2,color=color,code=code,length=length,capacity=0)
            for reverse in (False,True):
                for op in (0,1,2):
                    for length in sorted({0,actual_length-1,actual_length,actual_length+1,14,255}):
                        add('lookup-method-state',op=op,color=color,reverse=reverse,code=code,length=length,capacity=0)
        for reverse in (False,True):
            for op in (0,1,2):
                for code in (8191,8192,16383,65535):
                    add('lookup-narrow-casts',op=op,color=color,reverse=reverse,code=code,length=13,capacity=0)
    for byte in range(256):
        for data in (bytes((byte,)),bytes((byte,byte^255))):
            for color in (0,1):
                for white in (0,1):
                    for reverse in (False,True):
                        for capacity in (0,1,8):
                            add('decoder-byte-domain',width=65535,data=data,color=color,white=white,reverse=reverse,capacity=capacity)
    for color in (0,1):
        for table in (tables[0 if color else 1],tables[2 if color else 3],tables[4]):
            for run,code,length in table:
                data=pack([(code,length)])
                for width in sorted({0,run,max(0,run-1),run+1}):
                    for capacity in sorted({0,run//8,(run+7)//8}):
                        for white in (0,1):
                            add('decoder-table-runs',data=data,width=width,color=color,white=white,capacity=capacity)
    sequences=[(8,1,b'\x98'),(8,1,b'\x35\x14'),(8,1,b'\xb6'),(7,1,b'\xf0'),(15,1,b'\xd4'),(65,1,b'\xd8\xe0'),(64,1,b'\xd9\xa8'),(8,2,b'\x98\x14'),(8,3,b'\x98\x14\x13')]
    for width,count,data in sequences:
        for white in (0,1):
            for color in (0,1):
                for reverse in (False,True):
                    for length in range(len(data)+1):
                        for capacity in (0,1,2,8,16):
                            add('decoder-prefix-rows',data=data[:length],width=width,rows=count,white=white,color=color,reverse=reverse,capacity=capacity)
    for byte in range(256):
        for white in (0,1):
            for capacity in (0,1):
                add('padding-byte-domain',data=bytes((byte,)),width=8,white=white,capacity=capacity)
    for color in (0,1):
        for reverse in (False,True):
            for white in (0,1):
                for capacity in (0,1,2,8):
                    for segments in ([b'\x98',b'',b'\x14'],[b'\x35',b'\x14',b'\x98'],[b'\xb6',b'\x98',b'\x14']):
                        add('decoder-continuation',segments=segments,color=color,reverse=reverse,white=white,capacity=capacity)
    for white in range(256):add('factory-byte-domain',op=6,white=white,capacity=0)
    for width in (0,1,8,65535,(1<<64)-1):
        for rows in (0,1,3,(1<<64)-1):
            for white in (0,1):
                add('factory-dimensions',op=6,width=width,rows=rows,white=white)
                for color in (0,1):
                    for reverse in (False,True):add('decoder-scalar-copies',op=7,width=width,rows=rows,white=white,color=color,reverse=reverse)
    for run in (0,1,63,64,256,2560,65535):
        for code in (0,1,8191,8192,65535):
            for length in (0,1,13,14,255):add('code-record-copies',op=4,width=code,code=run,length=length)
    for width in (0,1,8,(1<<64)-1):
        for rows in (0,1,2):
            if width==(1<<64)-1 and rows>0:continue
            for color in (0,1):
                for white in (0,1):
                    for capacity in (0,1):add('zero-and-maximal-dimensions',width=width,rows=rows,color=color,white=white,capacity=capacity)
    for start in (0,3):
        for wstart in (0,1,7):add('initial-cursors',data=b'\x98',start=start,wstart=wstart,capacity=8)
    # Alternating zero-pixel terminating codes eventually overflow decoded_bits.
    # Output is fully initialized; no private scratch or partial scalar storage
    # is exposed to construct the boundary.
    for color in (0,1):
        codes=[(0x35,8),(0x37,10)] if color else [(0x37,10),(0x35,8)]
        for count in (7280,7281,7282):
            data=pack((codes*(count//2+1))[:count])
            add('decoded-bit-overflow',data=data,width=1,color=color,capacity=0)
    return rows_out,traps

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source',type=Path);parser.add_argument('zig',type=Path);parser.add_argument('v',type=Path)
    parser.add_argument('--target',default='aarch64-macos.14.0');parser.add_argument('--v-prod',action='store_true')
    parser.add_argument('--workdir',type=Path);parser.add_argument('--timeout',type=int,default=180)
    args=parser.parse_args()
    if args.timeout<=0:parser.error('--timeout must be positive')
    source=args.source.resolve()/'src';zig=args.zig.resolve();v=args.v.resolve()
    if tree_hash(source)!=PINNED_SOURCE_SHA256 or stdlib_hash(zig)!=PINNED_STDLIB_SHA256:parser.error('Source or library differs from pins')
    repo=Path(__file__).resolve().parent.parent;probe=repo/'zigimg/reference_probes/ccitt_contracts'
    mode='ReleaseSafe' if args.v_prod else 'Debug';env=dict(os.environ,VEXE=str(v),V_C_ERROR_BUG_REPORT_DISABLED='1')
    with work_directory(args.workdir,'witty-ccitt-contracts-') as root:
        proof=ProofLog(root);shutil.copytree(source,root/'src');fixtures={}
        for name in ('main.v','reference.zig'):
            shutil.copyfile(probe/name,root/name);fixtures[name]=hashlib.sha256((root/name).read_bytes()).hexdigest()
        versions=[proof.run([str(exe),'version'],label,env=env).stdout.decode().strip() for exe,label in ((zig,'zig-version'),(v,'v-version'))]
        if versions[0]!='0.15.2' or not re.match(r'^V 0\.5\.2(?: |$)',versions[1]):raise AssertionError('unexpected compiler versions')
        implementations=implementation_hashes(repo);runner_hash=hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
        (root/'provenance.json').write_text(json.dumps(dict(source_sha256=PINNED_SOURCE_SHA256,stdlib_sha256=PINNED_STDLIB_SHA256,versions=versions,target=args.target,zig_mode=mode,v_prod=args.v_prod,fixtures=fixtures,implementation_sha256=implementations,runner_sha256=runner_hash),indent=2)+'\n')
        zbase=[str(zig),'build-exe','-target',args.target,'-lc','-O',mode,'--global-cache-dir',str(root/'zig-global')]
        vbase=[str(v),'-enable-globals',*(['-prod'] if args.v_prod else []),'-path',f'{repo}|@vlib|@vmodules']
        print(f'Building CCITT contracts: Source {mode}, V {"production" if args.v_prod else "ordinary"}',flush=True)
        proof.run(zbase+['-femit-bin='+str(root/'native'),str(root/'reference.zig')],'build-source',timeout=args.timeout)
        proof.run(vbase+['-o',str(root/'translated'),str(root/'main.v')],'build-v',env=env,timeout=args.timeout)
        rows,traps=corpus(source);inputs={};file=root/'corpus.txt';file.write_text('\n'.join(row for group,name,row,message in rows)+'\n')
        inputs[file.name]=hashlib.sha256(file.read_bytes()).hexdigest();outputs=[]
        for exe in ('native','translated'):
            result=proof.run([str(root/exe),'--corpus',str(file)],'corpus-'+exe,timeout=args.timeout,check=False)
            if result.returncode:raise AssertionError(f'corpus-{exe}: failed {result.returncode}; retained stderr: '+result.stderr.decode(errors='replace'))
            if result.stderr:raise AssertionError('unexpected corpus stderr')
            outputs.append(result.stdout.splitlines())
        if any(len(output)!=len(rows) for output in outputs):raise AssertionError('corpus counts differ')
        returns=hashlib.sha256();states=hashlib.sha256();return_groups=Counter();trap_groups=Counter();categories=Counter()
        for (group,name,row,message),native,translated in zip(rows,*outputs):
            if native!=translated:raise AssertionError(f'{name}: {native!r} != {translated!r}; input {row}')
            returns.update(name.encode()+b'\0'+native+b'\n');return_groups[group]+=1
        print(f'{len(rows)} returning records match; checking {len(traps)} strict failures',flush=True)
        for group,name,row,message in traps:
            file=root/(name+'.txt');file.write_text(row);inputs[file.name]=hashlib.sha256(file.read_bytes()).hexdigest();records=[]
            for exe in ('native','translated'):
                path=root/(name+'-'+exe+'.state');result=proof.run([str(root/exe),'--case',str(path),row],name+'-'+exe,timeout=args.timeout,check=False)
                checked_trap(result,name+'/'+exe,message)
                messages=[m.group(1) for line in result.stderr.decode().splitlines() if (m:=re.fullmatch(r'(?:thread \d+ |V )?panic:\s*(.*)',line.strip()))]
                if messages!=[message] or not path.exists():raise AssertionError('exact panic or state missing')
                records.append(path.read_bytes())
            if not records[0] or records[0]!=records[1]:raise AssertionError(f'{name}: differing state {records}; input {row}')
            states.update(name.encode()+b'\0'+message.encode()+b'\0'+records[0]+b'\n');trap_groups[group]+=1;categories[message]+=1
        (root/'input_sha256.json').write_text(json.dumps(inputs,indent=2)+'\n')
        consumers={}
        def pair(label,zbody,vbody,zmarker=None,vmarker=None):
            paths=[root/(label+'.zig'),root/(label+'.v')]
            paths[0].write_text('const p=@import("src/compressions/ccitt.zig");const Code=@TypeOf(p.white_terminating_codes[0]);pub fn main() void {'+zbody+'}\n')
            paths[1].write_text('module main\nimport zigimg as p\nfn main(){\n'+vbody+'\n}\n')
            for path in paths:consumers[path.name]=hashlib.sha256(path.read_bytes()).hexdigest()
            for language,command,marker in (('Source',zbase+['-fno-emit-bin',str(paths[0])],zmarker),('V',vbase+['-check','-o',str(root/(label+'-checked')),str(paths[1])],vmarker)):
                result=proof.run(command,label+'-'+language,env=env,timeout=args.timeout,check=False);diagnostic=(result.stdout+result.stderr).decode(errors='replace')
                errors=[line for line in diagnostic.splitlines() if re.search(r'\berror:',line)]
                if marker is None:
                    if result.returncode or errors:raise AssertionError(f'{label}/{language}: expected acceptance\n{diagnostic}')
                else:
                    ordinary_rejection(result,label+'/'+language)
                    if not any(marker in line for line in errors):raise AssertionError(f'{label}/{language}: missing {marker!r}\n{diagnostic}')
        pair('complete-code','var x=Code{.run_length=1,.code=2,.code_length=3};x.code=7;if(x.code!=7) unreachable;',
             'mut x:=p.CcittCode{run_length:1,code:2,code_length:3}\nx.code=7\n_=x')
        pair('default-decoder','const x=p.Decoder{};_=x;','x:=p.CcittDecoder{}\n_=x')
        pair('readonly-code-table','p.white_terminating_codes[0].run_length=7;',
             'p.ccitt_white_terminating_codes[0].run_length=7',
             'cannot assign to constant','cannot modify constant')
        for omitted in ('run_length','code','code_length'):
            fields=[field for field in ('run_length','code','code_length') if field!=omitted]
            pair('missing-'+omitted,'const x=Code{'+','.join('.'+field+'=1' for field in fields)+'};_=x;',
                 'x:=p.CcittCode{'+','.join(field+':1' for field in fields)+'}\n_=x',
                 'missing struct field: '+omitted,"`zigimg.CcittCode."+omitted+"` must be initialized")
        for method in ('get_make_up_code','get_terminating_code','get_run_length'):
            pair('wide-'+method,'var x=p.Decoder{};_=x.'+method+'(8192,13);',
                 'mut x:=p.CcittDecoder{}\n_=x.'+method+'(8192,13)',"cannot represent integer value '8192'",None)
        pair('wide-factory-white','const x=p.Decoder.init(0,0,2) catch unreachable;_=x;',
             'x:=p.CcittDecoder.init(0,0,2) or {panic(err)}\n_=x',"cannot represent integer value '2'",None)
        pair('wide-white-field','const x=p.Decoder{.white_value=2};_=x;',
             'x:=p.CcittDecoder{white_value:2}\n_=x',"cannot represent integer value '2'",None)
        (root/'consumer_sha256.json').write_text(json.dumps(consumers,indent=2)+'\n')
        for name,digest in {**inputs,**consumers}.items():
            if hashlib.sha256((root/name).read_bytes()).hexdigest()!=digest:raise AssertionError('generated input/consumer changed')
        if tree_hash(source)!=PINNED_SOURCE_SHA256 or tree_hash(root/'src')!=PINNED_SOURCE_SHA256 or stdlib_hash(zig)!=PINNED_STDLIB_SHA256 or implementation_hashes(repo)!=implementations or hashlib.sha256(Path(__file__).read_bytes()).hexdigest()!=runner_hash:raise AssertionError('dependency, implementation or runner changed')
        for name,digest in fixtures.items():
            if any(hashlib.sha256((base/name).read_bytes()).hexdigest()!=digest for base in (root,probe)):raise AssertionError('fixture changed')
        summary=dict(returning_records=len(rows),return_groups=dict(return_groups),return_sha256=returns.hexdigest(),paired_traps=len(traps),failure_groups=dict(trap_groups),panic_categories=dict(categories),state_sha256=states.hexdigest(),complete_constructor_controls=2,required_omission_pairs=3,readonly_table_pairs=1,compiler_adaptations=5)
        (root/'summary.json').write_text(json.dumps(summary,indent=2)+'\n');print(json.dumps(summary,indent=2),flush=True)
        if len(rows)!=EXPECTED_RETURNS or len(traps)!=EXPECTED_TRAPS or returns.hexdigest()!=EXPECTED_RETURN_SHA256 or states.hexdigest()!=EXPECTED_STATE_SHA256:raise AssertionError('locked CCITT golden changed')


if __name__=='__main__':main()
