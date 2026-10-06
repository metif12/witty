"""Compare public GraphemeCache storage and checked copies with unchanged Vaxis."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import resource
import shutil
import subprocess
import sys
import tempfile

PROBE = Path(__file__).resolve().parent / 'reference_probes/grapheme_cache'
REPO = PROBE.parents[2]
sys.path.insert(0,str(PROBE.parent/'widgets_classic'))
from source_build import VAXIS_SHA256,UUCODE_PACKAGE,module,prepare_uucode,tree_hash


def corpus():
    rows=[]
    for index in range(8193):
        for length in (0,1,2,15):
            rows.append(f'E|{index}|{length}|{index%256}')
    for index in (0,1,17,8191,8192,8193,65535,2**64-1):
        for length in (0,1,31,4096,8191,8192):
            if index+length < 2**64:
                rows.append(f'E|{index}|{length}|99')
    for index in (0,1,2,17,4096,8191,8192,8193,2**64-1):
        for length in (0,1,2,17,4096,8192):
            if index+length >= 2**64:continue
            destination=0 if index+length>8192 else index
            for start in sorted({0,1,8192-length}):
                if start+length>8192:continue
                if length and start < destination+length and destination < start+length:continue
                rows.append(f'A|{index}|{length}|77|{start}')
    for index in (0,1,17,8190,8191,8192,8193):
        for seed in (0,7,255):
            rows.extend((f'B|{index}|0|{seed}',f'C|{index}|0|{seed}'))
    return rows


def strict_trap(result,label,category):
    diagnostic=(result.stdout+result.stderr).decode(errors='replace')
    headers=[m.group(1) for line in diagnostic.splitlines() if (m:=re.fullmatch(r'(?:thread \d+ )?(?:V )?panic:\s*(.*)',line))]
    if result.returncode==0 or result.stdout or any(line.lstrip().startswith(('UNEXPECTED','OBSERVER ERROR')) for line in diagnostic.splitlines()) or not any(h.startswith(category) for h in headers):
        raise AssertionError(f'{label}: missing checked {category}: {diagnostic}')


def compare(args,root):
    source=args.source.resolve()/'src'
    if tree_hash(source)!=VAXIS_SHA256:raise ValueError('pinned source changed')
    shutil.copytree(source,root/'src')
    graph=prepare_uucode(args.zig.resolve(),root,args.uucode.resolve(),'aarch64-macos.14.0')
    mode='ReleaseSafe' if args.v_prod else 'Debug'
    env=dict(os.environ,VEXE=str(args.v.resolve()),V_C_ERROR_BUG_REPORT_DISABLED='1')
    native=[str(args.zig.resolve()),'build-exe','-O',mode,'-target','aarch64-macos.14.0','-lc']
    translated=[str(args.v.resolve()),'-enable-globals',*(['-prod'] if args.v_prod else []),'-path',f'{REPO}|@vlib|@vmodules']
    def run(name,argv,timeout=240):
        (root/(name+'-argv.json')).write_text(json.dumps(argv))
        result=subprocess.run(argv,env=env,capture_output=True,timeout=timeout)
        (root/(name+'.stdout')).write_bytes(result.stdout);(root/(name+'.stderr')).write_bytes(result.stderr)
        return result
    builds=[('native',[*native,*module('root',PROBE/'reference.zig',['vaxis']),*module('vaxis',root/'src/main.zig',['uucode']),*graph,f'-femit-bin={root/"native"}']),('translated',[*translated,'-o',str(root/'translated'),str(PROBE/'main.v')])]
    for name,command in builds:
        print('Building '+name+' '+mode,file=sys.stderr,flush=True)
        result=run(name+'-build',command)
        if result.returncode:raise AssertionError(name+' build failed: '+(result.stdout+result.stderr).decode(errors='replace'))
    rows=corpus();path=root/'cases.txt';path.write_text('\n'.join(rows)+'\n')
    outputs=[]
    for name,_ in builds:
        print('Running '+name+': '+str(len(rows))+' records',file=sys.stderr,flush=True)
        result=run(name,[str(root/name),str(path)])
        if result.returncode or result.stderr or len(result.stdout.splitlines())!=len(rows):raise AssertionError(name+' returning failure: '+repr(result))
        outputs.append(result.stdout)
    if outputs[0]!=outputs[1]:
        for index,(expected,actual) in enumerate(zip(outputs[0].splitlines(),outputs[1].splitlines())):
            if expected!=actual:raise AssertionError(f'{index} {rows[index]}: Source={expected!r}, V={actual!r}')
        raise AssertionError('returning lengths differ')
    traps={name:('integer overflow' if 'overflow' in name else 'index out of bounds' if 'large' in name else '@memcpy arguments alias') for name in ('trap_overflow1','trap_overflow2','trap_large','trap_large_reset','trap_same','trap_same_end','trap_after','trap_before','trap_reset','trap_full')}
    for case,category in traps.items():
        states=[]
        for name,_ in builds:
            state=root/(name+'-'+case+'.state')
            result=run(name+'-'+case,[str(root/name),case,str(state)],30)
            strict_trap(result,name+' '+case,category)
            if not state.is_file():raise AssertionError(name+' '+case+': missing state observer')
            states.append(state.read_bytes())
        if states[0]!=states[1]:raise AssertionError(case+' panic state differs: '+repr(states))
    # All storage inspected here is explicitly initialized. Source's undefined
    # default bytes are not read: the empty constructor checks idx only.
    constructors=[
        ('default','var value:vaxis.GraphemeCache=.{};std.debug.assert(value.idx==0);const bytes=value.put("abc");std.debug.assert(bytes.len==3 and value.idx==3);','mut value := vaxis.GraphemeCache{}\nif value.idx != 0 {panic("UNEXPECTED")}\nbytes := value.put("abc".bytes())\nif bytes.len != 3 || value.idx != 3 {panic("UNEXPECTED")}'),
        ('state','var value:vaxis.GraphemeCache=.{.buf=@splat(7),.idx=~@as(usize,0)};value.buf[8191]=42;std.debug.assert(value.idx==~@as(usize,0) and value.buf[8191]==42 and @sizeOf(vaxis.GraphemeCache)==8192+@sizeOf(usize));','mut value := vaxis.GraphemeCache{idx:~usize(0)}\nfor i in 0 .. 8192 { value.buf[i] = 7 }\nvalue.buf[8191] = 42\nif value.idx != ~usize(0) || value.buf[8191] != 42 || sizeof(vaxis.GraphemeCache) != 8192+sizeof(usize) {panic("UNEXPECTED")}'),
    ]
    for label,z,v in constructors:
        zp,vp=root/(label+'.zig'),root/(label+'.v')
        zp.write_text('const std=@import("std");const vaxis=@import("vaxis");pub fn main()void{'+z+'}\n')
        vp.write_text('module main\nimport vaxis\nfn main(){'+v.replace('"',"'")+'}\n')
        for name,command in [('native',[*native,*module('root',zp,['vaxis']),*module('vaxis',root/'src/main.zig',['uucode']),*graph,f'-femit-bin={root/(label+"-native")}']),('translated',[*translated,'-o',str(root/(label+'-translated')),str(vp)])]:
            result=run(label+'-'+name+'-build',command)
            if result.returncode:raise AssertionError(result.stderr.decode(errors='replace'))
            result=run(label+'-'+name,[str(root/(label+'-'+name))])
            if result.returncode or result.stdout or result.stderr:raise AssertionError(label+' '+name+' constructor failed')
    digest=hashlib.sha256(outputs[0]).hexdigest()
    print(f'GraphemeCache ({mode}, V {"production" if args.v_prod else "ordinary"}): {len(rows)} returning records, {len(traps)} strict traps with observed state, 2 constructor/public-state pairs; SHA256 {digest}')


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source',type=Path);parser.add_argument('zig',type=Path);parser.add_argument('v',type=Path)
    parser.add_argument('--uucode',type=Path,default=Path.home()/'.cache/zig/p'/UUCODE_PACKAGE)
    parser.add_argument('--v-prod',action='store_true');parser.add_argument('--workdir',type=Path)
    args=parser.parse_args();resource.setrlimit(resource.RLIMIT_CORE,(0,0))
    if args.workdir:
        args.workdir.mkdir(parents=True,exist_ok=False);compare(args,args.workdir.resolve())
    else:
        with tempfile.TemporaryDirectory(prefix='witty-grapheme-cache-') as path:compare(args,Path(path))


if __name__=='__main__':main()
