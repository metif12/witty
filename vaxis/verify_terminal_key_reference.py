"""Compare unchanged Terminal key encoding, partial writes, releases and traps."""
import argparse
import hashlib
import itertools
import os
from pathlib import Path
import resource
import shutil
import subprocess
import sys
import tempfile
PROBE=Path(__file__).resolve().parent/'reference_probes/terminal/key'
sys.path.insert(0,str(PROBE.parent.parent/'widgets_classic'))
from source_build import VAXIS_SHA256,UUCODE_PACKAGE,module,prepare_uucode,tree_hash
def corpus():
    cases=[]
    def add(cp,mods,press,flags,text,capacity,initial=''):
        cases.append('|'.join(map(str,(cp,mods,int(press),flags,text,capacity,initial))))
    for cp,mods in itertools.product(list(range(128))+list(range(57348,57428))+[128,955,0x10ffff,0x1fffff],range(256)):
        add(cp,mods,True,0,'-',16)
    for cp,mods,capacity in itertools.product([0,27,97,106,122,127,57348,57350,57364,57368,57414,0x1fffff],range(8),range(11)):
        for initial in ('','aabb' if capacity>=2 else ''):
            add(cp,mods,True,0,'-',capacity,initial)
    for cp,mods,text,capacity in itertools.product([0,97,57350,0x1fffff],range(8),['','61','00','00ff','cebb','1b5b31'],range(8)):
        add(cp,mods,True,0,text,capacity)
    for cp,mods,flags,text in itertools.product([0,97,57350,0x1fffff],[0,7,255],range(32),['-','','00ff']):
        add(cp,mods,False,flags,text,2,'aabb')
    return cases
def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('source',type=Path);parser.add_argument('zig',type=Path);parser.add_argument('v',type=Path)
    parser.add_argument('--uucode',type=Path,default=Path.home()/'.cache/zig/p'/UUCODE_PACKAGE);parser.add_argument('--target',default='aarch64-macos.14.0');parser.add_argument('--v-prod',action='store_true');parser.add_argument('--zig-mode',choices=('Debug','ReleaseSafe'),default='Debug');parser.add_argument('--keep',type=Path,help=argparse.SUPPRESS)
    args=parser.parse_args();resource.setrlimit(resource.RLIMIT_CORE,(0,0));source=args.source.resolve()/'src'
    if tree_hash(source)!=VAXIS_SHA256:parser.error('vaxis src differs from recorded local source')
    cases=corpus()
    with tempfile.TemporaryDirectory(prefix='witty-terminal-key-') as folder:
        root=Path(folder);shutil.copytree(source,root/'src');graph=prepare_uucode(args.zig.resolve(),root,args.uucode.resolve(),args.target)
        # Enter the copied package as a consumer; every dependency body stays unchanged.
        probe=root/'src/key_probe.zig';shutil.copyfile(PROBE/'reference.zig',probe)
        subprocess.run([str(args.zig.resolve()),'build-exe','-target',args.target,'-lc','-O',args.zig_mode,*module('root',probe,['uucode']),*graph,f'-femit-bin={root / "native"}'],check=True)
        options=['-prod'] if args.v_prod else [];environment=dict(os.environ,VEXE=str(args.v.resolve()),V_C_ERROR_BUG_REPORT_DISABLED='1')
        subprocess.run([str(args.v.resolve()),*options,'-o',str(root/'translated'),str(PROBE/'main.v')],env=environment,check=True)
        path=root/'corpus.txt';path.write_text('\n'.join(cases)+'\n');outputs=[]
        for executable in ('native','translated'):
            result=subprocess.run([str(root/executable),str(path)],capture_output=True,timeout=120)
            if result.returncode:raise AssertionError(f'{executable} corpus failed: {result.stderr.decode(errors="replace")}')
            outputs.append(result.stdout.splitlines())
        if any(len(output)!=len(cases) for output in outputs):raise AssertionError([len(cases)]+[len(x) for x in outputs])
        for index,(case,expected,actual) in enumerate(zip(cases,*outputs)):
            if expected!=actual:raise AssertionError(f'row {index} ({case}): native={expected!r}, V={actual!r}')
        for flags in range(1,32):
            for executable in ('native','translated'):
                result=subprocess.run([str(root/executable),f'trap{flags}'],capture_output=True,timeout=10);text=result.stdout+result.stderr
                if result.returncode==0 or b'UNEXPECTED' in text or b'reached unreachable code' not in text:raise AssertionError(f'{executable} Kitty flags {flags} did not preserve checked unreachable: {text.decode(errors="replace")}')
        if args.keep:shutil.copytree(root,args.keep,dirs_exist_ok=True)
        print(f'Terminal key: {len(cases)} returning cases, 31 Kitty traps, SHA256 '+hashlib.sha256(b'\n'.join(outputs[0])).hexdigest())
if __name__=='__main__':main()
