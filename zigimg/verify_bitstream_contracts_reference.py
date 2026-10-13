"""Compare native scalar bit streams and exact retained failures with unchanged Source."""
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

EXPECTED_RETURNS = 136889
EXPECTED_TRAPS = 1064
EXPECTED_RETURN_SHA256 = 'bf6c23faab2083f34c10fb5dbfc8c5422e967f13cb0d31f3c7e505d516c18108'
EXPECTED_STATE_SHA256 = '211259eb01a70a32820bfdd8b016c1c9056e97102ab9dda787acc2b130627a66'
WIDTHS = [8,16,32,64,8,16,32,64,64,64,32,64] * 2
CAST = 'integer does not fit in destination type'
OVERFLOW = 'integer overflow'


class CheckedFailure(Exception):
    pass


class ReturningError(Exception):
    pass


class Model:
    def __init__(self,endian,width,kind,bits,count,capacity,data,start):
        self.big=endian%2==1;self.width=width;self.kind=kind;self.bits=bits;self.count=count
        self.capacity=capacity;self.data=list(data);self.pos=start;self.mask=(1<<width)-1
    def take(self):
        if self.pos==len(self.data):raise EOFError
        value=self.data[self.pos];self.pos+=1;return value
    def put(self,value):
        if self.pos==self.capacity:raise ReturningError
        self.pos+=1
    def byte_mask(self,num):
        if num>8:raise CheckedFailure(f'index out of bounds: index {num}, len 9')
        return (1<<num)-1
    def remove(self,num):
        if num==8:self.count=0;return self.bits
        keep=self.count-num
        if keep<0:raise CheckedFailure(OVERFLOW)
        if self.big:
            if keep>=8:raise CheckedFailure(CAST)
            value=self.bits>>keep;self.bits&=self.byte_mask(keep)
        else:
            value=self.bits&self.byte_mask(num)
            if num>=8:raise CheckedFailure(CAST)
            self.bits>>=num
        self.count=keep;return value
    def read(self,num):
        if num<=self.count:return self.remove(num),num
        count=self.count;value=self.remove(count)
        for _ in range((num-count)//8):
            try:byte=self.take()
            except EOFError:return value,count
            if self.big:value=((value<<8)|byte)&self.mask
            else:
                if count>=self.width:raise CheckedFailure(CAST)
                value=(value|(byte<<count))&self.mask
            count+=8
        left=num-count
        if left==0:return value,count
        try:byte=self.take()
        except EOFError:return value,count
        keep=8-left
        if self.big:
            if left>=self.width:raise CheckedFailure(CAST)
            value=((value<<left)|(byte>>keep))&self.mask;self.bits=byte&self.byte_mask(keep)
        else:
            if count>=self.width:raise CheckedFailure(CAST)
            value=(value|((byte&self.byte_mask(left))<<count))&self.mask;self.bits=byte>>left
        self.count=keep;return value,num
    def add(self,value,num):
        if num==8:self.bits=value
        elif self.big:
            if num>=8:raise CheckedFailure(CAST)
            self.bits=(self.bits<<num)&255;self.bits|=value&self.byte_mask(num)
        else:
            if self.count>=8:raise CheckedFailure(CAST)
            self.bits|=(value<<self.count)&255
        if self.count+num>=16:raise CheckedFailure(OVERFLOW)
        self.count+=num
    def flush(self):
        if self.count==0:return
        if self.big:
            if self.count>8:raise CheckedFailure(OVERFLOW)
            self.bits=(self.bits<<(8-self.count))&255
        self.put(self.bits);self.bits=0;self.count=0
    def write(self,num,value):
        value&=self.mask;count=num
        if self.count>0:
            if self.count>8:raise CheckedFailure(OVERFLOW)
            free=8-self.count
            if num<free:self.add(value&255,num);return
            if num==free:self.add(value&255,num);self.flush();return
            if self.big:
                if count-free>=self.width:raise CheckedFailure(CAST)
                self.add((value>>(count-free))&255,free)
            else:
                self.add(value&255,free)
                if free>=self.width:raise CheckedFailure(CAST)
                value>>=free
            count-=free;self.flush()
        for _ in range(count//8):
            if self.big:
                if count-8>=self.width:raise CheckedFailure(CAST)
                self.put((value>>(count-8))&255)
            else:
                self.put(value&255);value=0 if self.width==8 else value>>8
            count-=8
        self.add(value&255,count)
    def action(self,action):
        if action=='a':self.bits=0;self.count=0;return
        if action=='m':
            if self.data:self.data[0]^=85
            return
        if action[0]=='s':self.pos=int(action[1:]);return
        if action=='f':self.flush();return
        if action[0]=='c':
            copied=Model(int(self.big),self.width,self.kind,self.bits,self.count,self.capacity,self.data,self.pos)
            try:
                if self.kind:copied.write(*map(int,action[1:].split(':')))
                else:copied.read(int(action[1:]))
            finally:self.pos=copied.pos
            return
        if self.kind:self.write(*map(int,action[1:].split(':')))
        else:
            value,count=self.read(int(action[1:]))
            if action[0]=='n' and count<int(action[1:]):raise ReturningError


def classify(endian,typ,kind,bits,count,capacity,data,start,actions):
    model=Model(endian,WIDTHS[typ],kind,bits,count,capacity,data,start)
    try:
        for action in actions.split(','):
            try:model.action(action)
            except ReturningError:pass
    except CheckedFailure as failure:return str(failure)
    return None


def corpus():
    rows,traps,groups=[],[],Counter()
    trap_controls=set()
    def add(group,*,endian=0,typ=0,kind=0,bits=0,count=0,capacity=16,data=b'\xab\xcd\xef\x01\x23\x45\x67\x89\xff',start=0,actions='r8'):
        message=classify(endian,typ,kind,bits,count,capacity,data,start,actions)
        # Source computes with the same unsigned carrier for all scalar types
        # of a given width. Keep one strict control per identical operation;
        # returning records still instantiate every native/alias specialization.
        if message:
            control=(group,endian%2,WIDTHS[typ],kind,bits,count,capacity,data,start,actions)
            if control in trap_controls:return
            trap_controls.add(control)
        name=f'{group}-{groups[group]}';groups[group]+=1
        line='|'.join(map(str,(endian,typ,kind,bits,count,capacity,data.hex(),start,actions)))
        (traps if message else rows).append((group,name,line,message))
    # Dense defined byte/buffer domain. These short reads/writes never exceed
    # a native scalar's width, and both errors and all buffer bytes are observed.
    for endian in (0,1):
        for bits in range(256):
            for count in range(8):
                for num in (0,1,3,7,8):
                    for op in ('t','r','n'):
                        add('reader-byte-domain',endian=endian,bits=bits,count=count,data=bytes((bits,bits^255)),actions=f'{op}{num}')
                    for capacity in (0,1,2):
                        add('writer-byte-domain',endian=endian,kind=1,bits=bits,count=count,capacity=capacity,actions=f'w{num}:{bits^255},f')
    # All native scalar and real V alias specializations, public u4 counts,
    # partial EOF, width/cast boundaries and full u16 requests.
    for typ,width in enumerate(WIDTHS):
        for endian in (0,1):
            for count in (0,1,7,8,9,15):
                for num in sorted({0,1,7,8,width-1,width,width+1,2*width,65535}):
                    for length in (0,1,9):
                        add('scalar-reader-widths',endian=endian,typ=typ,count=count,bits=0xa5,data=bytes([0xff])*length,actions=f'r{num}')
                    for capacity in (0,1,9):
                        add('scalar-writer-widths',endian=endian,typ=typ,kind=1,count=count,bits=0xa5,capacity=capacity,actions=f'w{num}:{(1<<width)-1}')
    # Directly cover every representable invalid buffered count, mask and
    # subtraction position independently of backing data/output capacity.
    for endian in (0,1):
        for count in range(16):
            for num in (0,1,7,8,9,15,16):
                add('reader-count-order',endian=endian,count=count,bits=0xab,actions=f'r{num}')
                add('writer-count-order',endian=endian,kind=1,count=count,bits=0xab,actions=f'w{num}:171')
            for capacity in (0,1):
                add('writer-flush-order',endian=endian,kind=1,count=count,bits=0xab,capacity=capacity,actions='f,f')
            add('reader-align',endian=endian,count=count,bits=0xff,actions='a,r8')
    # Copied scalar state with a shared live stream, seeking without aligning,
    # retrying failed writes/flushes and borrowed caller input mutation.
    for typ,width in enumerate(WIDTHS):
        for endian in range(4):
            for length in (0,1,2,9):
                for actions in ('r1,c3,r4,a,s0,m,t8,n8',f'r{width},s0,n{width},a,t0', 'n7,n7,a,r8,s0,t8'):
                    add('reader-continuation',endian=endian,typ=typ,data=bytes([0xab])*length,actions=actions)
            for capacity in (0,1,2,9):
                for actions in (f'w1:1,c3:5,w4:15,f,s0,w{width}:{(1<<width)-1},f','w7:127,f,f,w1:1,w7:127,f', 'w1:1,w0:255,w7:0,f'):
                    add('writer-continuation',endian=endian,typ=typ,kind=1,capacity=capacity,actions=actions)
            patterns=[0,1,(1<<width)-1,1<<(width-1),(1<<(width-1))-1]
            if typ%12==10:patterns += [0x7f800000,0xff800000,0x7fc00000,0x7f800001,0x80000000]
            if typ%12==11:patterns += [0x7ff0000000000000,0xfff0000000000000,0x7ff8000000000000,0x7ff0000000000001,0x8000000000000000]
            for pattern in patterns:
                data=pattern.to_bytes(width//8,'big' if endian%2 else 'little')
                add('scalar-reinterpretation',endian=endian,typ=typ,data=data,actions=f'r{width}')
                add('scalar-reinterpretation',endian=endian,typ=typ,kind=1,actions=f'w{width}:{pattern},f')
            for start in (0,1,3):
                add('initial-cursors',endian=endian,typ=typ,start=start,actions='r1,a,r8')
                add('initial-cursors',endian=endian,typ=typ,kind=1,start=start,actions='w1:1,f')
    return rows,traps


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source',type=Path);parser.add_argument('zig',type=Path);parser.add_argument('v',type=Path)
    parser.add_argument('--target',default='aarch64-macos.14.0');parser.add_argument('--v-prod',action='store_true')
    parser.add_argument('--workdir',type=Path);parser.add_argument('--timeout',type=int,default=180)
    args=parser.parse_args()
    if args.timeout<=0:parser.error('--timeout must be positive')
    source=args.source.resolve()/'src';zig=args.zig.resolve();v=args.v.resolve()
    if tree_hash(source)!=PINNED_SOURCE_SHA256 or stdlib_hash(zig)!=PINNED_STDLIB_SHA256:parser.error('Source or library differs from pins')
    repo=Path(__file__).resolve().parent.parent;probe=repo/'zigimg/reference_probes/bitstream_contracts'
    mode='ReleaseSafe' if args.v_prod else 'Debug';env=dict(os.environ,VEXE=str(v),V_C_ERROR_BUG_REPORT_DISABLED='1')
    with work_directory(args.workdir,'witty-bitstream-contracts-') as root:
        proof=ProofLog(root);shutil.copytree(source,root/'src');fixtures={}
        for name in ('main.v','reference.zig'):
            shutil.copyfile(probe/name,root/name);fixtures[name]=hashlib.sha256((root/name).read_bytes()).hexdigest()
        versions=[proof.run([str(exe),'version'],label,env=env).stdout.decode().strip() for exe,label in ((zig,'zig-version'),(v,'v-version'))]
        if versions[0]!='0.15.2' or not re.match(r'^V 0\.5\.2(?: |$)',versions[1]):raise AssertionError('unexpected compiler versions')
        implementations=implementation_hashes(repo);runner_hash=hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
        (root/'provenance.json').write_text(json.dumps(dict(source_sha256=PINNED_SOURCE_SHA256,stdlib_sha256=PINNED_STDLIB_SHA256,versions=versions,target=args.target,zig_mode=mode,v_prod=args.v_prod,fixtures=fixtures,implementation_sha256=implementations,runner_sha256=runner_hash),indent=2)+'\n')
        zbase=[str(zig),'build-exe','-target',args.target,'-lc','-O',mode,'--global-cache-dir',str(root/'zig-global')]
        vbase=[str(v),'-enable-globals',*(['-prod'] if args.v_prod else []),'-path',f'{repo}|@vlib|@vmodules']
        print(f'Building bit-stream contracts: Source {mode}, V {"production" if args.v_prod else "ordinary"}',flush=True)
        proof.run(zbase+['-femit-bin='+str(root/'native'),str(root/'reference.zig')],'build-source',timeout=args.timeout)
        proof.run(vbase+['-o',str(root/'translated'),str(root/'main.v')],'build-v',env=env,timeout=args.timeout)
        rows,traps=corpus();inputs={};file=root/'corpus.txt';file.write_text('\n'.join(row for group,name,row,message in rows)+'\n')
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
            paths[0].write_text('const std=@import("std");const p=@import("src/io.zig");pub fn main() void {var data:[8]u8=@splat(0);var input=p.ReadStream.initMemory(&data);var output=p.WriteStream.initMemory(&data);_= &input;_= &output;'+zbody+'}\n')
            paths[1].write_text('module main\nimport zigimg as p\ntype AliasBig=p.BigEndian\nfn main(){\nmut data:=[]u8{len:8}\nmut input:=p.ReadStream.init_memory(data)\nmut output:=p.WriteStream.init_memory(mut data)\n_= &input\n_= &output\n'+vbody+'\n}\n')
            for path in paths:consumers[path.name]=hashlib.sha256(path.read_bytes()).hexdigest()
            for language,command,marker in (('Source',zbase+['-fno-emit-bin',str(paths[0])],zmarker),('V',vbase+['-check','-o',str(root/(label+'-checked')),str(paths[1])],vmarker)):
                result=proof.run(command,label+'-'+language,env=env,timeout=args.timeout,check=False);diagnostic=(result.stdout+result.stderr).decode(errors='replace')
                errors=[line for line in diagnostic.splitlines() if re.search(r'\berror:',line)]
                if marker is None:
                    if result.returncode or errors:raise AssertionError(f'{label}/{language}: expected acceptance\n{diagnostic}')
                else:
                    ordinary_rejection(result,label+'/'+language)
                    if not any(marker in line for line in errors):raise AssertionError(f'{label}/{language}: missing {marker!r}\n{diagnostic}')
        for record,field in (('Reader','reader'),('Writer','writer')):
            pair('complete-'+field,'const x=p.Bit'+record+'(.big){.'+field+'='+('input.reader()' if field=='reader' else 'output.writer()')+'};_=x;',
                 'x:=p.Bit'+record+'[p.BigEndian]{'+field+':'+field.replace('reader','input.reader()').replace('writer','output.writer()')+'}\n_=x')
            for tag in ('p.BigEndian','AliasBig'):
                pair('missing-'+field+('-alias' if tag=='AliasBig' else ''),'const x=p.Bit'+record+'(.big){};_=x;',
                     'x:=p.Bit'+record+'['+tag+']{}\n_=x','missing struct field: '+field,None)
            pair('wide-count-'+field,'const x=p.Bit'+record+'(.big){.'+field+'='+('input.reader()' if field=='reader' else 'output.writer()')+',.count=16};_=x;',
                 'x:=p.Bit'+record+'[p.BigEndian]{'+field+':'+('input.reader()' if field=='reader' else 'output.writer()')+',count:16}\n_=x',"cannot represent integer value '16'",None)
        (root/'consumer_sha256.json').write_text(json.dumps(consumers,indent=2)+'\n')
        for name,digest in {**inputs,**consumers}.items():
            if hashlib.sha256((root/name).read_bytes()).hexdigest()!=digest:raise AssertionError('generated input/consumer changed')
        if tree_hash(source)!=PINNED_SOURCE_SHA256 or tree_hash(root/'src')!=PINNED_SOURCE_SHA256 or stdlib_hash(zig)!=PINNED_STDLIB_SHA256 or implementation_hashes(repo)!=implementations or hashlib.sha256(Path(__file__).read_bytes()).hexdigest()!=runner_hash:raise AssertionError('dependency, implementation or runner changed')
        for name,digest in fixtures.items():
            if any(hashlib.sha256((base/name).read_bytes()).hexdigest()!=digest for base in (root,probe)):raise AssertionError('fixture changed')
        summary=dict(returning_records=len(rows),return_groups=dict(return_groups),return_sha256=returns.hexdigest(),paired_traps=len(traps),failure_groups=dict(trap_groups),panic_categories=dict(categories),state_sha256=states.hexdigest(),complete_constructor_controls=2,compiler_adaptations=6)
        (root/'summary.json').write_text(json.dumps(summary,indent=2)+'\n');print(json.dumps(summary,indent=2),flush=True)
        if len(rows)!=EXPECTED_RETURNS or len(traps)!=EXPECTED_TRAPS or returns.hexdigest()!=EXPECTED_RETURN_SHA256 or states.hexdigest()!=EXPECTED_STATE_SHA256:raise AssertionError('locked bit-stream golden changed')


if __name__=='__main__':main()
