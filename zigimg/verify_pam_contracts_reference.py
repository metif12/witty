"""Compare unchanged PAM records, decoding, partial output and checked failures."""
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

EXPECTED_MAIN_SHA256 = 'ce4a89a7351dd22af4ec69bfe6cd07b1810e24616ac54ab2bbc842d720b90af1'
EXPECTED_RETURN_SHA256 = '6918abab3af429f8fd98f930b0e70b800f100dd20c0f62571c82c373d373834f'
EXPECTED_STATE_SHA256 = '97974518c141b10b9c5952a4502ff89aa03a00c4e7015c0d91e9f203d5988908'
EXPECTED_RETURNS = 74189
EXPECTED_TRAPS = 1723
from collections import Counter
FORMATS=(0,1,2,4,8,16,0x101,0x102,0x104,0x108,0x110,0x208,0x210,0x303,0x305,0x3305,0x308,0x408,0x1305,0x1308,0x1408,0x310,0x410,0x2420)
TUPLES=('BLACKANDWHITE','BLACKANDWHITE_ALPHA','GRAYSCALE','GRAYSCALE_ALPHA','RGB','RGB_ALPHA')
MAPPING={0x101:(1,1,0,1),0x102:(1,3,2,0),0x104:(1,15,2,1),0x108:(1,255,2,1),0x110:(1,65535,2,2),0x208:(2,255,3,2),0x210:(2,65535,3,4),0x305:(3,31,4,3),0x1305:(3,31,4,3),0x308:(3,255,4,3),0x1308:(3,255,4,3),0x408:(4,255,5,4),0x1408:(4,255,5,4),0x310:(3,65535,4,6),0x410:(4,65535,5,8)}
COMMENTS=((),(b'one',b'two'),(b'',b'x\ny\r','π'.encode()),(b'\xff\0#%{x}',))
TAGS=('bmp','farbfeld','gif','iff','jpeg','pam','pbm','pcx','pgm','png','ppm','qoi','ras','sgi','tga','tiff','xbm')
def header(w=1,h=1,d=1,maximum=255,tuple_name='',prefix=b''):
    return b'P7\n'+prefix+f'WIDTH {w}\nHEIGHT {h}\nDEPTH {d}\nMAXVAL {maximum}\n'.encode()+(f'TUPLTYPE {tuple_name}\n'.encode() if tuple_name else b'')+b'ENDHDR\n'
def write_header(pixel,w,h,comments):
    depth,maximum,tuple_id,size=MAPPING[pixel]
    return header(w,h,depth,maximum,TUPLES[tuple_id],b''.join(b'#'+comment+b'\n' for comment in comments))
def write_trap(op,pixel,count,w,h,capacity,start,option,duration,comments,frame_pixel,frame_count,frames,loop,bits):
    if pixel not in MAPPING:return None
    if op==3 and option!=5:return f"access of union field 'pam' while field '{TAGS[option]}' is active"
    current=list(COMMENTS[comments]) if option==5 else []
    enabled=bool(duration and option==5)
    if op!=3 and frames and enabled:current.append(f'loop count: {loop}'.encode())
    remaining=capacity-start
    sequence=[(pixel,count,current)]
    if op!=3:
        for _ in range(frames):
            extra=[b'duration: 0'] if enabled else []
            # Only invalid-frame cases use duration zero; other durations have
            # valid backing storage and cannot trap, independently of text size.
            if bits and (frame_pixel==0x102 or frame_count<w*h):raise ValueError('invalid classified duration')
            sequence.append((frame_pixel,frame_count,list(COMMENTS[comments]) + extra if option==5 else []))
    for pixel,count,notes in sequence:
        if pixel not in MAPPING:return None
        length=len(write_header(pixel,w,h,notes))
        if remaining<length:return None
        remaining-=length
        if w*h==0:continue
        if pixel==0x102:return 'reached unreachable code'
        size=MAPPING[pixel][3]
        if w*h>count:
            if remaining<count*size:return None
            return f'index out of bounds: index {count}, len {count}'
        if remaining<w*h*size:return None
        remaining-=w*h*size
    return None

def corpus():
    rows=[];traps=[];counts=Counter()
    def add(group,data=b'',*,op=0,pixel=0x108,count=1,w=1,h=1,capacity=0,start=0,option=5,duration=0,comments=0,frame_pixel=0x308,frame_count=1,frames=0,loop=-1,bits=0,panic=None):
        name=f'{group}-{counts[group]}';counts[group]+=1
        if op>=3:
            assert panic is None
            panic=write_trap(op,pixel,count,w,h,capacity,start,option,duration,comments,frame_pixel,frame_count,frames,loop,bits)
        else:data=b'x'*start+data
        line='|'.join(str(value) for value in (op,pixel,count,w,h,capacity,start,option,duration,comments,frame_pixel,frame_count,frames,loop,bits,data.hex()))
        (traps if panic else rows).append((group,name,line,panic))
    def read(group,data,panic=None):
        for op in (0,1):
            for start in (0,3):add(group,data,op=op,start=start,panic=panic)
    for d in range(6):
        for maximum in (0,1,15,255,256,65535):
            for tuple_name in ('',*TUPLES,'UNKNOWN'):
                for w,h in ((0,0),(0,1),(1,0),(1,1),(2,1),(1,2)):
                    values=[0,1]*max(1,w*h*d)
                    body=b''.join(value.to_bytes(2 if maximum>255 else 1,'little') for value in values)
                    read('tuple-header-shapes',header(w,h,d,maximum,tuple_name)+body[:w*h*d*(2 if maximum>255 else 1)]+b'xy')
    for d in (1,2,3,4):
        for maximum in (1,2,15,254,255,256,1000,65535):
            for value in range(256):
                body=value.to_bytes(2 if maximum>255 else 1,'little')*d
                read('component-values',header(d=d,maximum=maximum)+body)
    for maximum in (256,257,1000,32767,65534,65535):
        for value in (0,1,255,256,257,999,1000,32767,65534,65535):
            for d in (1,2,3,4):read('wide-components',header(d=d,maximum=maximum)+value.to_bytes(2,'little')*d)
    for d,maximum in ((1,1),(2,1),(1,255),(2,255),(3,255),(4,255),(1,65535),(2,65535),(3,65535),(4,65535)):
        body=(b'\x01\0' if maximum>255 else b'\x01')*(d*2)
        data=header(2,1,d,maximum)+body+b'xy'
        for cut in range(len(data)+1):read('prefixes',data[:cut])
    base=header(1,1,3,255)+b'\x01\x02\x03'
    for second in (header(1,1,3,15)+b'\x01\x02\x03',header(2,1,3,255)+b'\x01'*6,header(1,2,3,255)+b'\x01'*6,header(1,1,1,255)+b'\x01',header(1,1,3,65535)+b'\x01\0'*3):
        for ending in (b'',b'x',b'xy',b'xyz',b'P7\n'):
            read('sequences',base+second+ending)
    for data in (b'',b'P',b'P7',b'P7\n',b'P7 ',b'P7 332',b'x7\n',base+b'x',base+b'xy',base+b'xyz'):
        read('magic-controls',data)
    text=header()+b'\x01'
    for old,new in ((b'WIDTH 1',b'WIDTH +1'),(b'WIDTH 1',b'WIDTH -0'),(b'WIDTH 1',b'WIDTH 0__1'),(b'WIDTH 1',b'WIDTH 1_'),(b'WIDTH 1',b'WIDTH _1'),(b'WIDTH 1',b'WIDTH 18446744073709551616'),(b'MAXVAL 255',b'MAXVAL 65536'),(b'DEPTH 1',b'DEPTH 9'),(b'WIDTH 1',b'WIDTH 2 ignored\nWIDTH 1'),(b'WIDTH 1',b'width 1'),(b'WIDTH 1',b'WIDTH\t1\r'),(b'WIDTH 1',b'\t WIDTH \v1\f'),(b'ENDHDR',b'ENDHDR ignored'),(b'ENDHDR',b'ENDHDRLONG'),(b'ENDHDR',b'')):
        read('parser-controls',text.replace(old,new))
    for tuple_name in TUPLES:
        depth=(1,2,1,2,3,4)[TUPLES.index(tuple_name)]
        maximum=1 if tuple_name.startswith('BLACK') else 255
        for ending in ('',' ','\r','\t'):
            read('tuple-rest',header(d=depth,maximum=maximum,tuple_name=tuple_name+ending)+b'\x01'*depth)
    for w,h in ((2**64-1,2),(2,2**64-1),(4294967296,4294967296)):
        for d,maximum in ((1,1),(2,1),(1,255),(2,255),(3,255),(4,255),(1,65535),(2,65535),(3,65535),(4,65535)):
            read('read-pixel-overflow',header(w,h,d,maximum),'integer overflow')
        for fields in ((0,255,''),(1,0,''),(1,255,'UNKNOWN')):
            read('read-before-overflow',header(w,h,*fields))
    for a in range(256):
        for tail in (b'7\n',b'7 ',b'0\n',b'\0\0'):
            for start in (0,3):add('detect',bytes((a,))+tail,op=2,start=start)
    for data in (b'',b'P',b'P7',b'P7\ntail'):
        add('detect-short',data,op=2)
    capacities=(0,1,2,3,4,8,31,32,63,64,65,66,67,68,69,70,71,72,73,74,75,76,77,78,79,80,95,96,127,128,255)
    for op in (3,4,5):
        for pixel in FORMATS:
            for w,h in ((0,0),(0,3),(1,0),(1,1),(2,1),(1,2)):
                for capacity in capacities:
                    add('write-matrix',op=op,pixel=pixel,count=w*h,w=w,h=h,capacity=capacity)
    for op in (3,4,5):
        for option in range(17):
            for pixel in FORMATS:
                for w,h,count in ((0,0,0),(1,1,1)):
                    for capacity in (0,255):
                        add('write-options',op=op,option=option,pixel=pixel,w=w,h=h,count=count,capacity=capacity)
    for op in (3,4,5):
        for pixel in MAPPING:
            for count,w,h in ((0,1,1),(1,2,1),(1,1,2),(2,3,1),(1,2**64-1,1),(1,1,2**64-1),(1,2**64-1,2**64-1),(0,2**64-1,0)):
                for capacity in (0,255):
                    add('write-wide-bounds',op=op,pixel=pixel,count=count,w=w,h=h,capacity=capacity,start=0)
    duration_words=(0,0x80000000,0x3e000000,0x40000000,0x3dcccccd,1,0x7f7fffff,0x7f800000,0xff800000,0x7fc00000,0xffc00000)
    for op in (4,5):
        for frames in (0,1,2):
            for variant in range(4):
                for flag in (0,1):
                    for loop in (-2147483648,-1,0,7,2147483647):
                        for bits in duration_words:
                            for capacity in (0,80,255,1024):
                                add('animation-duration',op=op,pixel=0x308,w=1,h=1,count=1,capacity=capacity,start=0,option=5,duration=flag,comments=variant,frame_pixel=0x108,frame_count=1,frames=frames,loop=loop,bits=bits)
    for op in (4,5):
        for frame_pixel in FORMATS:
            for frame_count in (0,1):
                for option in (0,5):
                    for capacity in (0,64,80,128,255):
                        add('animation-failure-order',op=op,pixel=0x308,w=1,h=1,count=1,capacity=capacity,option=option,duration=1,comments=1,frame_pixel=frame_pixel,frame_count=frame_count,frames=2,bits=0)
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
    repo=Path(__file__).resolve().parent.parent;probe=repo/'zigimg/reference_probes/pam_contracts'
    mode='ReleaseSafe' if args.v_prod else 'Debug';env=dict(os.environ,VEXE=str(v),V_C_ERROR_BUG_REPORT_DISABLED='1')
    with work_directory(args.workdir,'witty-pam-contracts-') as root:
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
        print(f'Building PAM contracts: Source {mode}, V {"production" if args.v_prod else "ordinary"}',flush=True)
        proof.run(zbase+['-femit-bin='+str(root/'native'),str(root/'reference.zig')],'build-source',timeout=args.timeout)
        proof.run(vbase+['-o',str(root/'translated'),str(root/'main.v')],'build-v',env=env,timeout=args.timeout)
        outputs=[]
        for exe in ('native','translated'):
            result=proof.run([str(root/exe)],'options-'+exe,timeout=args.timeout)
            if result.stderr:raise AssertionError('unexpected options stderr')
            outputs.append(result.stdout)
        if outputs[0]!=outputs[1] or len(outputs[0].splitlines())!=3:raise AssertionError('option copies/mutation differ')
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
            paths[0].write_text('const p=@import("src/formats/pam.zig");pub fn main() void {'+zbody+'}\n')
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
        pair('default-options','const x:p.PAM.EncoderOptions=.{};_=x;', 'x:=p.PamEncoderOptions{}\n_=x')
        pair('mutable-options','var x:p.PAM.EncoderOptions=.{};x.comments=&.{"changed"};x.add_duration_as_comment=true;_=x.comments;',
             "mut x:=p.PamEncoderOptions{}\nx.comments=['changed']\nx.add_duration_as_comment=true\n_=x")
        for field,value,vvalue in (('comments','&.{"changed"}',"['changed']"),('add_duration_as_comment','true','true')):
            pair('const-'+field,'const x:p.PAM.EncoderOptions=.{};x.'+field+'='+value+';',
                 'x:=p.PamEncoderOptions{}\nx.'+field+'='+vvalue+'\n_=x', 'cannot assign to constant','immutable')
        pair('constant-comment-element','var x:p.PAM.EncoderOptions=.{.comments=&.{"one"}};x.comments[0]="two";_=x.comments;',
             "mut x:=p.PamEncoderOptions{comments:['one']}\nx.comments[0]='two'\n_=x",'cannot assign to constant',None)
        # Header and TupleType are private in unchanged Source. Record its
        # visibility rejection, and V-only constructor enforcement separately.
        path=root/'private-header.zig'
        path.write_text('const p=@import("src/formats/pam.zig");pub fn main() void {const x:p.Header=undefined;_=x;}\n')
        consumer_hashes[path.name]=hashlib.sha256(path.read_bytes()).hexdigest()
        result=proof.run(zbase+['-fno-emit-bin',str(path)],'private-header-Source',env=env,timeout=args.timeout,check=False)
        ordinary_rejection(result,'private-header-Source')
        if "'Header' is not marked 'pub'" not in (result.stdout+result.stderr).decode():raise AssertionError('private Source header became accessible')
        fields={'width':'1','height':'2','depth':'1','maxval':'255','tuple_type':'.gray','comments':'[]'}
        for missing in (None,*fields):
            path=root/('Header-'+str(missing)+'.v')
            values=','.join(key+':'+value for key,value in fields.items() if key!=missing)
            path.write_text('module main\nimport zigimg as p\nfn main(){x:=p.PamHeader{'+values+'}\n_=x}\n')
            consumer_hashes[path.name]=hashlib.sha256(path.read_bytes()).hexdigest()
            result=proof.run(vbase+['-check','-o',str(root/('Header-'+str(missing)+'-checked')),str(path)],'Header-'+str(missing)+'-V',env=env,timeout=args.timeout,check=False)
            if missing is None:
                if result.returncode:raise AssertionError('complete V header rejected')
            else:
                ordinary_rejection(result,'Header-'+str(missing)+'-V')
                errors=[line for line in (result.stdout+result.stderr).decode().splitlines() if re.search(r'\berror:',line)]
                if not any('PamHeader.'+missing in line for line in errors):raise AssertionError('wrong required V field diagnostic')
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
        summary=dict(main_records=3,main_sha256=main_digest,returning_records=len(rows),return_groups=dict(return_groups),
            return_sha256=return_digest,paired_traps=len(traps),failure_groups=dict(trap_groups),state_sha256=state_digest,
            default_options_pairs=1,mutable_options_pairs=1,
            const_options_pairs=2,const_comment_adaptations=1,private_header_controls=1,v_header_acceptances=1,v_required_fields=6,zig_mode=mode,v_prod=args.v_prod)
        (root/'summary.json').write_text(json.dumps(summary,indent=2)+'\n');print(json.dumps(summary),flush=True)
        if main_digest!=EXPECTED_MAIN_SHA256 or return_digest!=EXPECTED_RETURN_SHA256 or state_digest!=EXPECTED_STATE_SHA256:
            raise AssertionError('locked golden changed')
        if len(rows)!=EXPECTED_RETURNS or len(traps)!=EXPECTED_TRAPS:raise AssertionError('locked counts changed')


if __name__=='__main__':main()
