"""Compare unchanged Netpbm records, decoding, partial output and checked failures."""
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

EXPECTED_MAIN_SHA256 = '91d67440ca5ce2fee2309c9b5ca5e2a28b6ac2aa5ff927010127c0a911e10b73'
EXPECTED_RETURN_SHA256 = '4118a6e16700c47662af2df6322aaf95bc166def639588c2f87410785b4a9da9'
EXPECTED_STATE_SHA256 = '03232409ef93ef7c3ff22f197b43c67876c19dd9d0b1cb0ac22fc140e0a0aa09'
EXPECTED_RETURNS = 137226
EXPECTED_TRAPS = 969
FORMATS = (0, 0x101, 0x102, 0x104, 0x108, 0x110, 1, 2, 4, 8, 16,
           0x208, 0x210, 0x303, 0x305, 0x3305, 0x308, 0x408,
           0x1305, 0x1308, 0x1408, 0x310, 0x410, 0x2420)


def corpus():
    rows, traps = [], []
    counts = Counter()
    def add(group, data=b'', *, codec=0, op=0, fmt=1, binary=0, w=7, h=9,
            maximum=123, pixel=0x108, count=0, capacity=0, start=0, option=6, panic=None):
        name = f'{group}-{counts[group]}'
        counts[group] += 1
        if op not in (3, 4, 5):
            data = b'x' * start + data
        line = '|'.join(str(value) for value in
                        (codec, op, fmt, binary, w, h, maximum, pixel, count,
                         capacity, start, option, data.hex()))
        (traps if panic else rows).append((group, name, line, panic))
    def read(group, data, panic=None):
        for codec in range(3):
            for op in (0, 1):
                for start in (0, 3):
                    add(group, data, codec=codec, op=op, start=start, panic=panic)
    def header(magic, w=1, h=1, maximum=255):
        return f'P{magic} {w} {h} ' .encode() + (b'' if magic in (1,4) else f'{maximum} '.encode())

    for codec in range(3):
        for fmt in range(3):
            for binary in (0, 1):
                for w,h in ((0,0),(1,2),(2**32,2**31),(2**64-1,2**64-1)):
                    for maximum in (0,1,255,256,65535,2**64-1):
                        add('header-copy-format', codec=codec, op=6, fmt=fmt,
                            binary=binary, w=w, h=h, maximum=maximum)
    for magic in range(1,7):
        for w in (0,1,2,3,7,8,9):
            for h in (0,1,2):
                for maximum in ((1,) if magic in (1,4) else (0,1,15,255,256,1000,65535)):
                    components = 3 if magic in (3,6) else 1
                    values = [(i*37+19)&65535 for i in range(w*h*components)]
                    if magic == 1: body = bytes(ord('0') + (i&1) for i in range(w*h))
                    elif magic in (2,3): body = b' '.join(str(value).encode() for value in values)+b' '
                    elif magic == 4: body = bytes((i*37+19)&255 for i in range(((w+7)//8)*h))
                    elif maximum > 255: body = b''.join(value.to_bytes(2,'big') for value in values)
                    else: body = bytes(value&255 for value in values)
                    # ASCII RGB reads all three values before dividing; binary
                    # RGB/gray8 divide after their first successfully read byte.
                    panic = 'division by zero' if maximum==0 and w*h>0 and magic in (3,5,6) else None
                    read('read-shapes', header(magic,w,h,maximum)+body+b'TAIL', panic)
    for magic in (5,6):
        for maximum in (1,2,15,254,255,256,1000,65535,9999999999999999):
            for value in range(256):
                one = value.to_bytes(2,'big') if maximum>255 else bytes((value,))
                read('binary-values',header(magic,maximum=maximum)+one*(3 if magic==6 else 1)+b'TAIL')
    tokens = (b'0',b'1',b'255',b'256',b'65535',b'65536',b'9999999999999999',
              b'+0_1',b'-0',b'-00',b'-1',b'1__2',b'_1',b'1_',b'+',b'-',b'',
              b'0000000000000000',b'00000000000000000',b'0x10',b'1#abc\n2',b'1#abc\r2')
    for magic in (2,3):
        for maximum in (0,1,255,256,65535):
            for token in tokens:
                body = token+b' 2 3 ' if magic==3 else token+b' '
                valid = token in (b'0',b'1',b'255',b'256',b'65535',b'65536',b'9999999999999999',b'+0_1',b'-0',b'-00',b'1__2',b'0000000000000000',b'1#abc\n2',b'1#abc\r2')
                panic = 'division by zero' if magic==3 and maximum==0 and valid else None
                read('ascii-values',header(magic,maximum=maximum)+body,panic)
    bases = [header(m,3,2,1000)+ (b'0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 ' if m<=3 else bytes(range(36))) for m in range(1,7)]
    bases += [b'P3 1 1 0 1 2 3 ',b'P6 1 1 0 \x01\x02\x03',b'P5 1 1 0 \x01']
    for index,data in enumerate(bases):
        for cut in range(len(data)+1):
            panic = 'division by zero' if index>=6 and cut==len(data) else None
            # P6/P5 divide on the first byte, so extra bytes do not defer failure.
            if index==7 and cut>=len(header(6,maximum=0))+1: panic='division by zero'
            read('prefixes',data[:cut],panic)
    for magic in range(1,7):
        for w,h in ((0,0),(0,3),(9999999999999999,0)):
            read('wide-zero',header(magic,w,h,0)+b' ')
    for magic in range(1,7):
        for w,h in ((4294967296,4294967296),(9999999999999999,1845),
                    (1845,9999999999999999),(9999999999999999,9999999999999999)):
            read('pixel-overflow',header(magic,w,h,0),'integer overflow')
    for data in (b'',b'P',b'P0 ',b'P7 ',b'p1 ',b'xx ',b'P2 -1 1 0 ',
                 b'P2 00000000000000000 1 0 ',b'P3 1 1 255 # no end',
                 b'P1 3 1 0#x',b'P4 1 1\r\n\xff',b'P2 +0_1\t1\r255\n9 ',
                 b'P2 1\v1 255 9 ',b'P2 1\f1 255 9 ',b'P2 1 1 0 9 ',
                 b'P3 1 1 0 1 bad 3 ',b'P3 1 1 0 1 2 bad '):
        read('parser-controls',data)
    for a in range(256):
        for b in (ord('1'),ord('2'),ord('3'),ord('4'),ord('5'),ord('6'),0,255):
            for codec in range(3): add('detect-bytes',bytes((a,b)),codec=codec,op=2,start=3)
    for data in (b'',b'P',b'P1tail'):
        for codec in range(3): add('detect-short',data,codec=codec,op=2)
    capacities=(0,1,2,3,4,8,20,21,22,24,25,26,27,28,29,30,31,32,33,34,40,64,128)
    for codec in range(3):
        for op in (3,4,5):
            for pixel in FORMATS:
                for w,h in ((0,0),(0,3),(1,0),(1,1),(3,2),(9,2)):
                    for binary in (0,1):
                        for capacity in capacities:
                            add('write-matrix',codec=codec,op=op,fmt=codec,binary=binary,
                                w=w,h=h,maximum=65535,pixel=pixel,count=w*h,capacity=capacity)
    for codec in range(3):
        for op in (4,5):
            for option in range(17):
                for pixel in (0x101,0x108,0x110,0x308,0x408):
                    for binary in (0,1):
                        add('write-options',codec=codec,op=op,binary=binary,w=1,h=1,
                            pixel=pixel,count=1,capacity=128,start=3,option=option)
    for codec in range(3):
        for fmt in range(3):
            for maximum in (0,1,255,256,65535,2**64-1):
                for pixel in (0x101,0x108,0x110,0x308):
                    for binary in (0,1):
                        add('write-direct-controls',codec=codec,op=3,fmt=fmt,binary=binary,
                            w=1,h=1,maximum=maximum,pixel=pixel,count=1,capacity=128,start=3)
    for op in (3,4,5):
        for count,w,h in ((0,1,1),(1,2,1),(2,3,1),(3,2,2),(1,1,2),
                          (0,2**64-1,1),(1,2**64-1,2)):
            # Entire first/second row must be available before its bits are written.
            end = w if count<w else 2*w
            message = f'index out of bounds: index {end}, len {count}'
            add('write-row-bounds',codec=0,op=op,fmt=0,binary=1,w=w,h=h,
                pixel=0x101,count=count,capacity=128,panic=message)
            for capacity in (0,1,25):
                add('write-before-bounds',codec=0,op=op,fmt=0,binary=1,w=w,h=h,
                    pixel=0x101,count=count,capacity=capacity)
        for w,h in ((2**64-1,0),(0,3)):
            add('write-zero-rows',codec=0,op=op,fmt=0,binary=1,w=w,h=h,
                pixel=0x101,count=0,capacity=128)
    for codec in range(3):
        for op in (3,4,5):
            for binary in (0,1):
                for pixel in (0x108,0x110,0x308,0x408):
                    add('write-wide-dimensions',codec=codec,op=op,fmt=codec,binary=binary,
                        w=2**64-1,h=2**64-1,pixel=pixel,count=1,capacity=128)
    return rows,traps


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source',type=Path);parser.add_argument('zig',type=Path);parser.add_argument('v',type=Path)
    parser.add_argument('--target',default='aarch64-macos.14.0');parser.add_argument('--v-prod',action='store_true')
    parser.add_argument('--workdir',type=Path);parser.add_argument('--timeout',type=int,default=180)
    args=parser.parse_args()
    if args.timeout<=0:parser.error('--timeout must be positive')
    source=args.source.resolve()/'src';zig=args.zig.resolve();v=args.v.resolve()
    if tree_hash(source)!=PINNED_SOURCE_SHA256 or stdlib_hash(zig)!=PINNED_STDLIB_SHA256:parser.error('Source or selected library differs from pins')
    repo=Path(__file__).resolve().parent.parent;probe=repo/'zigimg/reference_probes/netpbm_contracts'
    mode='ReleaseSafe' if args.v_prod else 'Debug';env=dict(os.environ,VEXE=str(v),V_C_ERROR_BUG_REPORT_DISABLED='1')
    with work_directory(args.workdir,'witty-netpbm-contracts-') as root:
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
        print(f'Building Netpbm contracts: Source {mode}, V {"production" if args.v_prod else "ordinary"}',flush=True)
        proof.run(zbase+['-femit-bin='+str(root/'native'),str(root/'reference.zig')],'build-source',timeout=args.timeout)
        proof.run(vbase+['-o',str(root/'translated'),str(root/'main.v')],'build-v',env=env,timeout=args.timeout)
        outputs=[]
        for exe in ('native','translated'):
            result=proof.run([str(root/exe)],'options-'+exe,timeout=args.timeout)
            if result.stderr:raise AssertionError('unexpected options stderr')
            outputs.append(result.stdout)
        if outputs[0]!=outputs[1] or outputs[0]!=b'true|true|true|true\nfalse|false|false|false\n':raise AssertionError('option defaults/mutation differ')
        main_digest=hashlib.sha256(outputs[0]).hexdigest()
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
            paths[0].write_text('const p=@import("src/formats/netpbm.zig");pub fn main() void {'+zbody+'}\n')
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
        fields={'format':'.bitmap','binary':'false','width':'1','height':'2','max_value':'255'}
        for missing in (None,*fields):
            zfields=','.join('.'+key+'='+value for key,value in fields.items() if key!=missing)
            vfields=','.join(key+':'+value for key,value in fields.items() if key!=missing)
            pair('Header-'+str(missing),'const x:p.Header=.{'+zfields+'};_=x;',
                 'x:=p.NetpbmHeader{'+vfields+'}\n_=x',
                 'missing struct field: '+missing if missing else None,
                 'NetpbmHeader.'+missing if missing else None)
        for kind in ('PBM','PGM','PPM'):
            pair('default-'+kind,'const x:p.'+kind+'=.{};_=x;','x:=p.'+kind+'{}\n_=x')
        for kind,vkind in (('PBM','Netpbm'),('PBM','Pbm'),('PGM','Pgm'),('PPM','Ppm')):
            pair('mutable-'+vkind,'var x:p.'+kind+'.EncoderOptions=.{};x.binary=false;_=x.binary;',
                 'mut x:=p.'+vkind+'EncoderOptions{}\nx.binary=false\n_=x')
            pair('const-'+vkind,'const x:p.'+kind+'.EncoderOptions=.{};x.binary=false;',
                 'x:=p.'+vkind+'EncoderOptions{}\nx.binary=false\n_=x',
                 'cannot assign to constant','immutable')
        (root/'consumer_sha256.json').write_text(json.dumps(consumer_hashes,indent=2)+'\n')
        (root/'input_sha256.json').write_text(json.dumps(inputs,indent=2)+'\n')
        for name,digest in {**consumer_hashes,**inputs}.items():
            if hashlib.sha256((root/name).read_bytes()).hexdigest()!=digest:raise AssertionError('generated input or consumer changed')
        return_digest=returns.hexdigest();state_digest=states.hexdigest()
        if (tree_hash(source)!=PINNED_SOURCE_SHA256 or tree_hash(root/'src')!=PINNED_SOURCE_SHA256
                or stdlib_hash(zig)!=PINNED_STDLIB_SHA256 or implementation_hashes(repo)!=implementations
                or hashlib.sha256(Path(__file__).read_bytes()).hexdigest()!=runner_hash):raise AssertionError('dependency, implementation or runner changed')
        for name,expected in fixtures.items():
            if any(hashlib.sha256((base/name).read_bytes()).hexdigest()!=expected for base in (root,probe)):raise AssertionError('fixture changed')
        summary=dict(main_records=2,main_sha256=main_digest,returning_records=len(rows),return_groups=dict(return_groups),
            return_sha256=return_digest,paired_traps=len(traps),failure_groups=dict(trap_groups),state_sha256=state_digest,
            complete_constructor_pairs=1,required_field_pairs=5,default_codec_pairs=3,mutable_options_pairs=4,
            const_options_pairs=4,zig_mode=mode,v_prod=args.v_prod)
        (root/'summary.json').write_text(json.dumps(summary,indent=2)+'\n');print(json.dumps(summary),flush=True)
        if main_digest!=EXPECTED_MAIN_SHA256 or return_digest!=EXPECTED_RETURN_SHA256 or state_digest!=EXPECTED_STATE_SHA256:
            raise AssertionError('locked golden changed')
        if len(rows)!=EXPECTED_RETURNS or len(traps)!=EXPECTED_TRAPS:raise AssertionError('locked counts changed')


if __name__=='__main__':main()
