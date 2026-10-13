"""Compare unchanged LZW constructor/decoder state, narrow arithmetic and partial input."""
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

EXPECTED_RETURNS = 22016
EXPECTED_TRAPS = 3772
EXPECTED_RETURN_SHA256 = 'ed8bb6c09434dfe1e443322d20f2995deee8a18ebfb2fd35af8568866ca18f36'
EXPECTED_STATE_SHA256 = '0fe9b3c86c939dbbf71d079c9f9800ea2c779f3c03960e196e68f99506b60fd7'


class CheckedFailure(Exception):
    pass


class ReturningError(Exception):
    pass


class Bits:
    def __init__(self,data,endian):
        self.data,self.endian,self.pos,self.bits,self.count=data,endian,0,0,0
    def take(self):
        if self.pos==len(self.data):raise EOFError
        value=self.data[self.pos];self.pos+=1;return value
    def remove(self,n):
        keep=self.count-n
        if self.endian:
            value=self.bits>>keep;self.bits&=(1<<keep)-1
        else:
            value=self.bits&((1<<n)-1);self.bits>>=n
        self.count=keep;return value
    def read(self,n):
        if n<=self.count:return self.remove(n),n
        count=self.count;value=self.remove(count)
        for _ in range((n-count)//8):
            try: byte=self.take()
            except EOFError:return value,count
            if self.endian:value=((value<<8)|byte)&8191
            else:
                if count>15:raise CheckedFailure('integer does not fit in destination type')
                if count>=13:raise CheckedFailure('shift amount is greater than the type size')
                value=(value|(byte<<count))&8191
            count+=8
        left=n-count
        if left==0:return value,count
        try:byte=self.take()
        except EOFError:return value,count
        keep=8-left
        if self.endian:
            value=((value<<left)|(byte>>keep))&8191;self.bits=byte&((1<<keep)-1)
        else:
            if count>15:raise CheckedFailure('integer does not fit in destination type')
            if count>=13:raise CheckedFailure('shift amount is greater than the type size')
            value=(value|((byte&((1<<left)-1))<<count))&8191;self.bits=byte>>left
        self.count=keep;return value,n


def classify(endian,initial,early,cs,next_code,previous,remaining,remaining_bits,reset_initial,edit,capacity,segments,op,start,wstart):
    try:
        if initial>15:raise CheckedFailure('integer does not fit in destination type')
        if initial>=13:raise CheckedFailure('shift amount is greater than the type size')
        roots=1<<initial;dictionary={i:bytes((i&255,)) for i in range(roots)}
        clear=roots;end=roots+1
        cs=initial if cs==-1 else cs
        next_code=roots+2 if next_code==-1 else next_code
        previous=None if previous==-1 else previous
        remaining=None if remaining==-1 else remaining
        remaining_bits=0 if remaining_bits==-1 else remaining_bits
        initial=initial if reset_initial==-1 else reset_initial
        if edit==1:dictionary[0]=b''
        if edit==2:dictionary[1]=b''
        if edit==3:dictionary[0]=b'\xf0\x5a'
        if op==0:return None
        written=wstart
        def write(value):
            nonlocal written
            if len(value)>capacity-written:raise ReturningError
            written+=len(value)
        def advance(width):
            nonlocal next_code,cs
            if next_code==8191:raise CheckedFailure('integer overflow')
            next_code+=1
            if cs==255:raise CheckedFailure('integer overflow')
            if cs+1>15:raise CheckedFailure('integer does not fit in destination type')
            if cs+1>=13:raise CheckedFailure('shift amount is greater than the type size')
            maximum=(1<<(cs+1))&8191
            if maximum<early:raise CheckedFailure('integer overflow')
            if next_code==maximum-early and cs+1<12:cs+=1;return width+1
            return width
        for si,data in enumerate(segments):
            reader=Bits(data[start:] if si==0 else data,endian)
            if cs==255:raise CheckedFailure('integer overflow')
            width=cs+1
            if remaining is not None:
                rest,size=reader.read(remaining_bits);code=0
                if size:
                    if not endian:
                        if width<remaining_bits:raise CheckedFailure('integer overflow')
                        if width-remaining_bits>15:raise CheckedFailure('integer does not fit in destination type')
                        if width-remaining_bits>=13:raise CheckedFailure('shift amount is greater than the type size')
                        code=(remaining|(rest<<(width-remaining_bits)))&8191
                    else:
                        if remaining_bits>=13:raise CheckedFailure('shift amount is greater than the type size')
                        code=((remaining<<remaining_bits)|rest)&8191
                remaining=None
            else:code,size=reader.read(width)
            while size:
                if code in dictionary:
                    value=dictionary[code];write(value)
                    if previous in dictionary:
                        if not value:raise CheckedFailure('index out of bounds: index 0, len 0')
                        dictionary[next_code]=dictionary[previous]+value[:1];width=advance(width)
                elif code==clear:
                    dictionary.clear();cs=initial
                    if initial>15:raise CheckedFailure('integer does not fit in destination type')
                    if initial>=13:raise CheckedFailure('shift amount is greater than the type size')
                    next_code=((1<<initial)&8191)+2
                    dictionary.update({i:bytes((i&255,)) for i in range(1<<initial)})
                    width=cs+1;previous=code
                elif code==end:break
                elif previous in dictionary:
                    value=dictionary[previous]
                    if not value:raise CheckedFailure('index out of bounds: index 0, len 0')
                    new=value+value[:1];dictionary[next_code]=new;write(new);width=advance(width)
                previous=code
                code,size=reader.read(width)
                if size!=width:
                    remaining=code
                    if width-size>15:raise CheckedFailure('integer does not fit in destination type')
                    remaining_bits=width-size;break
    except CheckedFailure as error:return str(error)
    except ReturningError:return None
    return None


def pack(endian,codes):
    if endian:
        text=''.join(f'{code&((1<<width)-1):0{width}b}' for code,width in codes)
        text+='0'*(-len(text)%8)
        return bytes(int(text[i:i+8],2) for i in range(0,len(text),8))
    value=count=0;data=bytearray()
    for code,width in codes:
        value|=(code&((1<<width)-1))<<count;count+=width
        while count>=8:data.append(value&255);value>>=8;count-=8
    if count:data.append(value&255)
    return bytes(data)


def literals(endian,initial,early,count):
    roots=1<<initial;next_code=roots+2;width=initial+1;codes=[(roots,width)]
    for i in range(count):
        codes.append((i%roots,width))
        if i:
            next_code+=1
            if next_code==(1<<width)-early and width<12:width+=1
    codes.append((roots+1,width));return pack(endian,codes)


def corpus():
    rows,traps,counts=[],[],Counter()
    def add(group,data=b'',*,endian=0,initial=2,early=0,cs=-1,next_code=-1,previous=-1,remaining=-1,remaining_bits=-1,reset_initial=-1,edit=0,capacity=8,segments=None,op=1,start=0,wstart=0):
        segments=[data] if segments is None else segments
        segments=[b'x'*start+segments[0],*segments[1:]]
        message=classify(endian,initial,early,cs,next_code,previous,remaining,remaining_bits,reset_initial,edit,capacity,segments,op,start,wstart)
        name=f'{group}-{counts[group]}';counts[group]+=1
        line='|'.join(map(str,(endian,initial,early,cs,next_code,previous,remaining,remaining_bits,reset_initial,edit,capacity,','.join(s.hex() for s in segments),op,start,wstart)))
        (traps if message else rows).append((group,name,line,message))
    for endian in (0,1):
        for initial in range(256):add('constructor-domain',endian=endian,initial=initial,op=0)
        for byte in range(256):
            for early in (0,1,8,255):
                for capacity in (0,1,4):
                    for cut in (0,1,2):add('byte-domain',bytes((byte,byte^255))[:cut],endian=endian,early=early,capacity=capacity)
        for cs in range(256):
            for data in (b'',b'\x00\x00\x00',b'\xff\xff\xff'):
                add('code-size-domain',data,endian=endian,cs=cs,capacity=4)
        for next_code in (0,6,8190,8191):
            for cs in (2,11,12,13,14,15,254,255):
                for previous in (-1,0,1,8191):
                    for early in (0,1,255):
                        for capacity in (0,1,4):
                            add('advance-order',bytes((cs+8)//8),endian=endian,cs=cs,next_code=next_code,previous=previous,early=early,capacity=capacity)
        for remaining in (0,1,8191):
            for rb in range(16):
                for cs in (0,2,8,12,14,15,254):
                    for data in (b'',b'\xff',b'\x00\x00'):
                        add('resume-fields',data,endian=endian,cs=cs,remaining=remaining,remaining_bits=rb)
        for edit in (0,1,2,3):
            for previous in (-1,0,1):
                for capacity in (0,1,4):
                    for code in (0,1,7):
                        add('empty-borrowed-values',pack(endian,[(code,3),(5,3)]),endian=endian,edit=edit,previous=previous,capacity=capacity)
        for initial in (0,1,2,8,12):
            for early in (0,1):
                for count in (0,1,2,3,16,128,512,5120,8190):
                    data=literals(endian,initial,early,count)
                    for capacity in (0,count,max(count+1,1)):
                        add('literal-growth',data,endian=endian,initial=initial,early=early,capacity=capacity)
        sequences=[[(4,3),(0,3),(1,3),(6,3),(5,4)],[(4,3),(1,3),(6,3),(5,3)],[(4,3),(1,3),(7,3),(2,3),(5,3)],[(7,3),(1,3),(5,3)]]
        for sequence in sequences:
            data=pack(endian,sequence)
            for cut in range(len(data)+1):
                for middle in (b'',b'\xff'):
                    for capacity in (0,1,2,8):add('continuation',endian=endian,segments=[data[:cut],middle,data[cut:]],capacity=capacity)
        for override in (0,1,2,12,13,15,16,255):
            add('reset-order',pack(endian,[(4,3)]),endian=endian,reset_initial=override)
        for capacity in (1,2,8):
            for start in (0,3):
                for wstart in (0,capacity-1):
                    add('initial-cursors',b'\x4c\x01',endian=endian,start=start,wstart=wstart,capacity=capacity)
    return rows,traps

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source',type=Path); parser.add_argument('zig',type=Path); parser.add_argument('v',type=Path)
    parser.add_argument('--target',default='aarch64-macos.14.0'); parser.add_argument('--v-prod',action='store_true')
    parser.add_argument('--workdir',type=Path); parser.add_argument('--timeout',type=int,default=180)
    args = parser.parse_args()
    if args.timeout <= 0: parser.error('--timeout must be positive')
    source = args.source.resolve()/'src'; zig = args.zig.resolve(); v = args.v.resolve()
    if tree_hash(source)!=PINNED_SOURCE_SHA256 or stdlib_hash(zig)!=PINNED_STDLIB_SHA256:
        parser.error('Source or selected library differs from pins')
    repo = Path(__file__).resolve().parent.parent; probe = repo/'zigimg/reference_probes/lzw_contracts'
    mode = 'ReleaseSafe' if args.v_prod else 'Debug'; env = dict(os.environ,VEXE=str(v),V_C_ERROR_BUG_REPORT_DISABLED='1')
    with work_directory(args.workdir,'witty-lzw-contracts-') as root:
        proof = ProofLog(root); shutil.copytree(source,root/'src'); fixtures = {}
        for name in ('main.v','reference.zig'):
            shutil.copyfile(probe/name,root/name); fixtures[name] = hashlib.sha256((root/name).read_bytes()).hexdigest()
        versions = [proof.run([str(exe),'version'],label,env=env).stdout.decode().strip() for exe,label in ((zig,'zig-version'),(v,'v-version'))]
        if versions[0]!='0.15.2' or not re.match(r'^V 0\.5\.2(?: |$)',versions[1]): raise AssertionError('unexpected compiler versions')
        implementations = implementation_hashes(repo); runner_hash = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
        (root/'provenance.json').write_text(json.dumps(dict(source_sha256=PINNED_SOURCE_SHA256,stdlib_sha256=PINNED_STDLIB_SHA256,
            versions=versions,target=args.target,zig_mode=mode,v_prod=args.v_prod,fixtures=fixtures,
            implementation_sha256=implementations,runner_sha256=runner_hash),indent=2)+'\n')
        zbase = [str(zig),'build-exe','-target',args.target,'-lc','-O',mode,'--global-cache-dir',str(root/'zig-global')]
        vbase = [str(v),'-enable-globals',*(['-prod'] if args.v_prod else []),'-path',f'{repo}|@vlib|@vmodules']
        print(f'Building LZW contracts: Source {mode}, V {"production" if args.v_prod else "ordinary"}',flush=True)
        proof.run(zbase+['-femit-bin='+str(root/'native'),str(root/'reference.zig')],'build-source',timeout=args.timeout)
        proof.run(vbase+['-o',str(root/'translated'),str(root/'main.v')],'build-v',env=env,timeout=args.timeout)
        rows, traps = corpus(); inputs = {}
        file = root/'corpus.txt'; file.write_text('\n'.join(row for group,name,row,message in rows)+'\n')
        inputs[file.name] = hashlib.sha256(file.read_bytes()).hexdigest()
        outputs = []
        for exe in ('native','translated'):
            result = proof.run([str(root/exe),'--corpus',str(file)],'corpus-'+exe,timeout=args.timeout,check=False)
            if result.returncode:raise AssertionError(f'corpus-{exe}: failed {result.returncode}; retained stderr: '+result.stderr.decode(errors='replace'))
            if result.stderr: raise AssertionError('unexpected corpus stderr')
            outputs.append(result.stdout.splitlines())
        if any(len(output)!=len(rows) for output in outputs): raise AssertionError('corpus counts differ')
        returns = hashlib.sha256(); states = hashlib.sha256(); return_groups = Counter(); trap_groups = Counter()
        for (group,name,row,message),native,translated in zip(rows,*outputs):
            if native!=translated: raise AssertionError(f'{name}: {native!r} != {translated!r}; input {row}')
            returns.update(name.encode()+b'\0'+native+b'\n'); return_groups[group]+=1
        print(f'{len(rows)} returning records match; checking {len(traps)} strict failures',flush=True)
        for group,name,row,message in traps:
            file = root/(name+'.txt'); file.write_text(row); inputs[file.name] = hashlib.sha256(file.read_bytes()).hexdigest()
            records = []
            for exe in ('native','translated'):
                path = root/(name+'-'+exe+'.state')
                result = proof.run([str(root/exe),'--case',str(path),row],name+'-'+exe,timeout=args.timeout,check=False)
                checked_trap(result,name+'/'+exe,message)
                messages = [m.group(1) for line in result.stderr.decode().splitlines() if (m:=re.fullmatch(r'(?:thread \d+ |V )?panic:\s*(.*)',line.strip()))]
                if messages!=[message] or not path.exists(): raise AssertionError('exact panic or state missing')
                records.append(path.read_bytes())
            if not records[0] or records[0]!=records[1]: raise AssertionError(f'{name}: differing state {records}; input {row}')
            states.update(name.encode()+b'\0'+message.encode()+b'\0'+records[0]+b'\n'); trap_groups[group]+=1
        (root/'input_sha256.json').write_text(json.dumps(inputs,indent=2)+'\n')
        from verify_simd_reference import ordinary_rejection
        consumers={}
        def pair(label,zbody,vbody,zmarker=None,vmarker=None):
            paths=[root/(label+'.zig'),root/(label+'.v')]
            paths[0].write_text('const std=@import("std");const p=@import("src/compressions/lzw.zig");const a=std.heap.page_allocator;pub fn main() void {'+zbody+'}\n')
            paths[1].write_text('module main\nimport zigimg as p\nfn main(){\n'+vbody+'\n}\n')
            for path in paths:consumers[path.name]=hashlib.sha256(path.read_bytes()).hexdigest()
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
                    if not any(marker in line for line in errors):raise AssertionError(f'{label}/{language}: missing {marker!r}\n{diagnostic}')
        zfields='.area_allocator=std.heap.ArenaAllocator.init(a),.dictionary=std.AutoArrayHashMap(u13,[]const u8).init(a)'
        vfields='dictionary:map[u16][]u8{}'
        pair('complete-record','const x=p.Decoder(.little){'+zfields+'};_=x;',
             'x:=p.LzwDecoder[p.LittleEndian]{'+vfields+'}\n_=x')
        pair('missing-dictionary','const x=p.Decoder(.little){.area_allocator=std.heap.ArenaAllocator.init(a)};_=x;',
             'x:=p.LzwDecoder[p.LittleEndian]{}\n_=x','missing struct field: dictionary',None)
        pair('allocator-adaptation','const x=p.Decoder(.little){.dictionary=std.AutoArrayHashMap(u13,[]const u8).init(a)};_=x;',
             'x:=p.LzwDecoder[p.LittleEndian]{'+vfields+'}\n_=x','missing struct field: area_allocator',None)
        for field in ('clear_code','end_information_code','next_code','previous_code','remaining_data'):
            marker="expected type '?u13'" if field in ('previous_code','remaining_data') else "cannot represent integer value '8192'"
            pair('wide-'+field,'const x=p.Decoder(.little){'+zfields+',.'+field+'=8192};_=x;',
                 'x:=p.LzwDecoder[p.LittleEndian]{'+vfields+','+field+':8192}\n_=x',marker,None)
        pair('wide-remaining-bits','const x=p.Decoder(.little){'+zfields+',.remaining_bits=16};_=x;',
             'x:=p.LzwDecoder[p.LittleEndian]{'+vfields+',remaining_bits:16}\n_=x',"cannot represent integer value '16'",None)
        pair('readonly-dictionary-value','const x=p.Decoder(.little).init(a,2,0) catch unreachable;x.dictionary.get(0).?[0]=7;',
             'mut x:=p.lzw_decoder_init[p.LittleEndian](2,0) or {panic(err)}\nx.dictionary[0][0]=7','cannot assign to constant',None)
        (root/'consumer_sha256.json').write_text(json.dumps(consumers,indent=2)+'\n')
        for name,digest in consumers.items():
            if hashlib.sha256((root/name).read_bytes()).hexdigest()!=digest:raise AssertionError('generated consumer changed')
        for name,digest in inputs.items():
            if hashlib.sha256((root/name).read_bytes()).hexdigest()!=digest: raise AssertionError('generated input changed')
        if tree_hash(source)!=PINNED_SOURCE_SHA256 or tree_hash(root/'src')!=PINNED_SOURCE_SHA256 or stdlib_hash(zig)!=PINNED_STDLIB_SHA256 or implementation_hashes(repo)!=implementations or hashlib.sha256(Path(__file__).read_bytes()).hexdigest()!=runner_hash:
            raise AssertionError('dependency, implementation or runner changed')
        for name,expected in fixtures.items():
            if any(hashlib.sha256((base/name).read_bytes()).hexdigest()!=expected for base in (root,probe)): raise AssertionError('fixture changed')
        summary = dict(returning_records=len(rows),return_groups=dict(return_groups),return_sha256=returns.hexdigest(),paired_traps=len(traps),failure_groups=dict(trap_groups),state_sha256=states.hexdigest(),complete_constructor_controls=1,compiler_adaptations=9)
        (root/'summary.json').write_text(json.dumps(summary,indent=2)+'\n'); print(json.dumps(summary,indent=2),flush=True)
        if len(rows)!=EXPECTED_RETURNS or len(traps)!=EXPECTED_TRAPS or returns.hexdigest()!=EXPECTED_RETURN_SHA256 or states.hexdigest()!=EXPECTED_STATE_SHA256:
            raise AssertionError('locked LZW contracts golden changed')


if __name__ == '__main__':
    main()
