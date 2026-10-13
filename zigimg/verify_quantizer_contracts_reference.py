"""Compare quantizer inline roots, palette contexts and exact mutation failures."""
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

EXPECTED_RETURNS = 4594
EXPECTED_TRAPS = 1134
EXPECTED_RETURN_SHA256 = '5a383dd64249c960f2d3698bc7a6fefc693daba1f196c3b462aab7c9594332ab'
EXPECTED_STATE_SHA256 = 'b69ded40574ad13007fb9d03ff10b0f6ac7a43334fb207ffad0d249e7fe593dc'
CAST='integer does not fit in destination type'
OVERFLOW='integer overflow'
MAX=(1<<32)-1

class CheckedFailure(Exception):pass

class Node:
    def __init__(self,r=0,g=0,b=0,ref=0,index=0):
        self.rgb=[r,g,b];self.ref=ref;self.index=index;self.children=[None]*8;self.next=None
    def color(self):
        if not self.ref:raise CheckedFailure('division by zero')
        values=[x//self.ref for x in self.rgb]
        if max(values)>255:raise CheckedFailure(CAST)
        return values
    def count(self):
        return 1 if self.ref else sum(c.count() for c in self.children if c is not None)
    def remove(self):
        removed=0
        for i,c in enumerate(self.children):
            if c is not None:
                self.rgb=[(a+b)&MAX for a,b in zip(self.rgb,c.rgb)]
                self.ref=(self.ref+c.ref)&MAX;removed+=1;self.children[i]=None
        return removed-1
    def find(self,level,color):
        if self.ref:return self.index
        if level<0 or level>=8:raise CheckedFailure(CAST)
        mask=128>>level
        index=sum(bit for value,bit in zip(color,(4,2,1)) if value&mask)
        child=self.children[index]
        if child is None:child=next((c for c in self.children if c is not None),None)
        return child.find(level+1,color) if child is not None else None
    def palette(self,ctx):
        if self.ref:
            if ctx['index']>=ctx['budget']:return
            if ctx['index']>=ctx['capacity']:raise CheckedFailure(f"index out of bounds: index {ctx['index']}, len {ctx['capacity']}")
            self.color();self.index=ctx['index'];ctx['index']+=1
        for child in self.children:
            if child is not None:child.palette(ctx)


def classify(op,level,r,g,b,ref,index,budget,cursor,capacity,graph,color):
    root=Node(r,g,b,ref,index);a1=Node(2,10,20,1,5);a2=Node(3,20,30,1,7);a3=Node(4,30,40,1,9);a4=Node()
    levels=[None]*8;levels[0]=root;levels[2]=a2;a2.next=a3
    if graph==1:root.children[0]=a1
    if graph==2:root.children[0]=a1;root.children[7]=a2
    if graph==3:root.children[0]=a4;a4.children[0]=a1;a4.children[7]=a2
    if graph==4:root.children[0]=a1;root.children[7]=a1
    if graph in (5,6):
        root.children[0]=a4;levels[7]=a4
        if graph==6:a1.ref=a2.ref=0;a4.children[0]=a1;a4.children[7]=a2
    ctx=dict(index=cursor,budget=budget,capacity=capacity)
    try:
        if op==0:root.color()
        elif op==1:
            if level<8:
                if level<0:raise CheckedFailure(CAST)
                raise AssertionError('allocation controls belong to the historical matrix')
            for i,value in enumerate(color):
                if root.rgb[i]+value>MAX:raise CheckedFailure(OVERFLOW)
                root.rgb[i]+=value
            if root.ref==MAX:raise CheckedFailure(OVERFLOW)
            root.ref+=1
        elif op in (2,3):
            if op==3 and level>=7:return None
            if level<0:raise CheckedFailure(CAST)
            if level>=8:raise CheckedFailure(f'index out of bounds: index {level}, len 8')
        elif op==4:root.remove()
        elif op==5:root.palette(ctx)
        elif op==6:root.find(level,color)
        elif op==7:
            leaves=root.count()
            for depth in range(7,0,-1):
                node=levels[depth]
                while node is not None:
                    removed=node.remove()
                    if removed<0:raise CheckedFailure(CAST)
                    if removed>leaves:raise CheckedFailure(OVERFLOW)
                    leaves-=removed
                    if leaves<=budget:break
                    node=node.next
                if leaves<=budget:break
            root.palette(dict(index=0,budget=budget,capacity=capacity))
    except CheckedFailure as failure:return str(failure)
    return None


def corpus():
    rows,traps,counts=[],[],Counter()
    def add(group,*,op=0,level=0,r=10,g=20,b=30,ref=1,index=0,budget=8,cursor=0,capacity=8,graph=0,color=(1,2,3)):
        message=classify(op,level,r,g,b,ref,index,budget,cursor,capacity,graph,color)
        name=f'{group}-{counts[group]}';counts[group]+=1
        line='|'.join(map(str,(op,level,r,g,b,ref,index,budget,cursor,capacity,graph,':'.join(map(str,color)))))
        (traps if message else rows).append((group,name,line,message))
    for byte in range(256):
        for ref in (1,2,3,255):
            add('average-byte-domain',r=byte,g=byte^255,b=(byte*17)&255,ref=ref)
    for ref in (0,1,2,255,MAX):
        for value in (0,1,254,255,256,257,510,511,512,MAX):
            for channel in range(3):
                rgb=[0,0,0];rgb[channel]=value
                add('average-boundaries',r=rgb[0],g=rgb[1],b=rgb[2],ref=ref)
    for level in (-2147483648,-1,8,9,100,2147483647):
        for value in (0,MAX-2,MAX-1,MAX):
            for channel in range(3):
                rgb=[1,2,3];rgb[channel]=value
                for color in ((0,0,0),(1,2,3),(255,255,255)):
                    for ref in (0,MAX-1,MAX):
                        add('add-order',op=1,level=level,r=rgb[0],g=rgb[1],b=rgb[2],ref=ref,color=color)
    for level in (-2147483648,-1,0,1,2,6,7,8,9,2147483647):
        for graph in range(7):
            add('level-registration',op=2,level=level,graph=graph)
            add('node-reset-order',op=3,level=level,graph=graph)
    for graph in range(7):
        for ref in (0,1,MAX):
            for value in (0,1,MAX):
                add('wrapping-removal',op=4,graph=graph,r=value,g=value,b=value,ref=ref)
                for level in (-1,0,1,6,7,8,100):
                    for color in ((0,0,0),(128,0,128),(255,255,255)):
                        add('palette-index',op=6,graph=graph,r=value,g=value,b=value,ref=ref,level=level,color=color)
    for op in (5,7):
        for graph in range(7):
            for ref in (0,1):
                for budget in (0,1,2,4,MAX):
                    for capacity in (0,1,2,4):
                        for cursor in ((0,1,MAX) if op==5 else (0,)):
                            add('palette-mutation',op=op,graph=graph,ref=ref,budget=budget,cursor=cursor,capacity=capacity)
    for op in (8,9,10,11):
        for graph in range(7):
            for ref in (0,1,MAX):
                for value in (0,1,255,256,MAX):
                    for capacity in (0,1,8):
                        add('records-and-copies',op=op,graph=graph,r=value,g=value^MAX,b=(value*17)&MAX,ref=ref,index=value,budget=value,cursor=value,capacity=capacity)
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
    repo=Path(__file__).resolve().parent.parent;probe=repo/'zigimg/reference_probes/quantizer_contracts'
    mode='ReleaseSafe' if args.v_prod else 'Debug';env=dict(os.environ,VEXE=str(v),V_C_ERROR_BUG_REPORT_DISABLED='1')
    with work_directory(args.workdir,'witty-quantizer-contracts-') as root:
        proof=ProofLog(root);shutil.copytree(source,root/'src');fixtures={}
        for name in ('main.v','reference.zig'):
            shutil.copyfile(probe/name,root/name);fixtures[name]=hashlib.sha256((root/name).read_bytes()).hexdigest()
        versions=[proof.run([str(exe),'version'],label,env=env).stdout.decode().strip() for exe,label in ((zig,'zig-version'),(v,'v-version'))]
        if versions[0]!='0.15.2' or not re.match(r'^V 0\.5\.2(?: |$)',versions[1]):raise AssertionError('unexpected compiler versions')
        implementations=implementation_hashes(repo);runner_hash=hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
        (root/'provenance.json').write_text(json.dumps(dict(source_sha256=PINNED_SOURCE_SHA256,stdlib_sha256=PINNED_STDLIB_SHA256,versions=versions,target=args.target,zig_mode=mode,v_prod=args.v_prod,fixtures=fixtures,implementation_sha256=implementations,runner_sha256=runner_hash),indent=2)+'\n')
        zbase=[str(zig),'build-exe','-target',args.target,'-lc','-O',mode,'--global-cache-dir',str(root/'zig-global')]
        vbase=[str(v),'-enable-globals',*(['-prod'] if args.v_prod else []),'-path',f'{repo}|@vlib|@vmodules']
        print(f'Building quantizer contracts: Source {mode}, V {"production" if args.v_prod else "ordinary"}',flush=True)
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
            paths[0].write_text('const std=@import("std");const p=@import("src/OctTreeQuantizer.zig");const color=@import("src/color.zig");const Node=@TypeOf(@as(p,undefined).root_node);const Context=@typeInfo(@typeInfo(@TypeOf(Node.makePalette)).@"fn".params[1].type.?).pointer.child;pub fn main() void {'+zbody+'}\n')
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
        pair('complete-context','const x=Context{.palette=&.{}};_=x;',
             'x:=p.OctTreePaletteContext{palette:[]p.Rgba32{}}\n_=x')
        pair('missing-palette','const x=Context{};_=x;',
             'x:=p.OctTreePaletteContext{}\n_=x','missing struct field: palette','`zigimg.OctTreePaletteContext.palette` must be initialized')
        pair('inline-root','const x=p{.area_allocator=std.heap.ArenaAllocator.init(std.heap.page_allocator),.root_node=Node{.red=7}};_=x;',
             'x:=p.OctTreeQuantizer{root_node:p.OctTreeNode{red:7}}\n_=x')
        pair('allocator-adaptation','const x=p{};_=x;',
             'x:=p.OctTreeQuantizer{}\n_=x','missing struct field: area_allocator',None)
        (root/'consumer_sha256.json').write_text(json.dumps(consumers,indent=2)+'\n')
        for name,digest in {**inputs,**consumers}.items():
            if hashlib.sha256((root/name).read_bytes()).hexdigest()!=digest:raise AssertionError('generated input/consumer changed')
        if tree_hash(source)!=PINNED_SOURCE_SHA256 or tree_hash(root/'src')!=PINNED_SOURCE_SHA256 or stdlib_hash(zig)!=PINNED_STDLIB_SHA256 or implementation_hashes(repo)!=implementations or hashlib.sha256(Path(__file__).read_bytes()).hexdigest()!=runner_hash:raise AssertionError('dependency, implementation or runner changed')
        for name,digest in fixtures.items():
            if any(hashlib.sha256((base/name).read_bytes()).hexdigest()!=digest for base in (root,probe)):raise AssertionError('fixture changed')
        summary=dict(returning_records=len(rows),return_groups=dict(return_groups),return_sha256=returns.hexdigest(),paired_traps=len(traps),failure_groups=dict(trap_groups),panic_categories=dict(categories),state_sha256=states.hexdigest(),complete_constructor_controls=2,required_omission_pairs=1,compiler_adaptations=1)
        (root/'summary.json').write_text(json.dumps(summary,indent=2)+'\n');print(json.dumps(summary,indent=2),flush=True)
        if len(rows)!=EXPECTED_RETURNS or len(traps)!=EXPECTED_TRAPS or returns.hexdigest()!=EXPECTED_RETURN_SHA256 or states.hexdigest()!=EXPECTED_STATE_SHA256:raise AssertionError('locked quantizer golden changed')


if __name__=='__main__':main()
