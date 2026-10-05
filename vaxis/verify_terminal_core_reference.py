"""Compare classic Terminal's runnable controls/draw/input and lifecycle boundaries."""
import argparse
import hashlib
import itertools
import os
from pathlib import Path
import re
import resource
import shutil
import subprocess
import sys
import tempfile

REPO = Path(__file__).resolve().parent.parent
PROBE = Path(__file__).resolve().parent / 'reference_probes/terminal/core'
sys.path.insert(0, str(PROBE.parent.parent / 'widgets_classic'))
from source_build import VAXIS_SHA256, UUCODE_SHA256, tree_hash, prepare_uucode

def corpus():
    cases=[]
    for width in [1,4,8,9,16,20,32]:
        tabs=list(range(0,width,8))
        for col,left,origin in itertools.product(range(width), sorted(set([0,min(1,width-1),width-1])),range(2)):
            cases.append(f'C|{width}|{col}|{left}|{origin}|c|0|0')
            for count in [0,1,2,4,17]:
                cases.append(f'C|{width}|{col}|{left}|{origin}|t|{count}|0')
                index=next((i for i,stop in enumerate(tabs) if stop>col),len(tabs)-1)
                index=max(index-max(count-1,0),0)
                final=max(tabs[index],left) if origin else tabs[index]
                if final>=col:
                    cases.append(f'C|{width}|{col}|{left}|{origin}|b|{count}|0')
            for mode,value in itertools.product([0,6,7,25,1049,2026,65535],range(2)):
                cases.append(f'C|{width}|{col}|{left}|{origin}|m|{mode}|{value}')
    for width,height,sync,cursor,lock,ww,hh in itertools.product([4,7],[2,3],range(2),range(2),range(2),[2,4,8],[1,2,4]):
        cases.append(f'D|{width}|{height}|{height}|{sync}|{cursor}|{lock}|{ww}|{hh}')
    for capacity,prefix,code,mods in itertools.product([0,1,2,3,8,16],['','ab'],[97,13,0xe012], [0,1,2,4,6]):
        cases.append(f'U|{capacity}|{prefix}|{code}|{mods}')
    cases += [f'N|{name}' for name in ['terminal','pty','null','dead']]
    return cases

def run(command,**kw):
    result=subprocess.run(command,stdout=subprocess.PIPE,stderr=subprocess.PIPE,**kw)
    if result.returncode:
        raise AssertionError(f'command failed: {command}\n{result.stderr.decode(errors="replace")}')
    return result

# Automatic V array bounds and the explicit translated guard report the same
# source category. Matching the panic message itself excludes backtrace literals.
TRAP_MESSAGES = {
    'tall': {'native': ('index out of bounds',),
             'translated': ('index out of bounds', 'array.get: index out of range')},
    'back': {'native': ('integer overflow',), 'translated': ('integer overflow',)},
    'tabs': {'native': ('integer overflow',), 'translated': ('integer overflow',)},
    'zero': {'native': ('integer overflow',), 'translated': ('integer overflow',)},
    'kitty': {'native': ('reached unreachable code',),
              'translated': ('reached unreachable code',)},
}
COMPILER_FAILURE_MARKERS = (
    'segmentation fault', 'segfault', 'bus error', 'illegal instruction',
    'panic:', 'compiler panic', 'assertion failed', 'internal compiler error',
    'compiler bug', 'please report this bug', 'c compilation failed',
    'c compilation error',
    'c error found', 'c compiler error', 'c backend failure',
    'failed in the c backend', 'linker command failed', 'undefined reference',
)

def diagnostics(result):
    # A stream boundary is a line boundary even if stdout lacked a final newline.
    return '\n'.join((stream or b'').decode(errors='replace')
                     for stream in (result.stdout, result.stderr))

def unexpected_result(text):
    return any(line.lstrip().startswith('UNEXPECTED') for line in text.splitlines())

def checked_trap(result, name, executable):
    text = diagnostics(result)
    messages = [match.group(1) for line in text.splitlines()
                if (match := re.match(r'^(?:thread \d+ |V )?panic:\s*(.*)$', line.strip()))]
    expected = TRAP_MESSAGES[name][executable]
    if (result.returncode == 0 or unexpected_result(text)
            or not any(message.startswith(category)
                       for message in messages for category in expected)):
        raise AssertionError(f'{executable} {name} expected checked trap '
                             f'{expected}: {result.returncode}\n{text}')

def ordinary_rejection(result, label):
    text = diagnostics(result)
    if (result.returncode <= 0 or 'error:' not in text or unexpected_result(text)
            or any(marker in text.lower() for marker in COMPILER_FAILURE_MARKERS)):
        raise AssertionError(f'{label} expected ordinary rejection: '
                             f'{result.returncode}\n{text}')

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source',type=Path);parser.add_argument('uucode',type=Path)
    parser.add_argument('zig',type=Path);parser.add_argument('v',type=Path)
    parser.add_argument('--v-root',type=Path,default=REPO,help=argparse.SUPPRESS)
    parser.add_argument('--v-prod',action='store_true');parser.add_argument('--zig-mode',choices=['Debug','ReleaseSafe'],default='Debug')
    parser.add_argument('--registry-only',action='store_true',help=argparse.SUPPRESS)
    parser.add_argument('--contracts-only',action='store_true',help=argparse.SUPPRESS)
    parser.add_argument('--keep',type=Path,help=argparse.SUPPRESS)
    args=parser.parse_args();resource.setrlimit(resource.RLIMIT_CORE,(0,0))
    source=args.source.resolve()/'src';uucode=args.uucode.resolve()
    if tree_hash(source)!=VAXIS_SHA256:parser.error('Vaxis source differs from pinned tree')
    if tree_hash(uucode)!=UUCODE_SHA256:parser.error('uucode source differs from pinned tree')
    with tempfile.TemporaryDirectory(prefix='witty-terminal-core-') as temp:
        root=Path(temp);shutil.copytree(source,root/'src');shutil.copyfile(PROBE/'reference.zig',root/'src/core_probe.zig')
        deps=prepare_uucode(args.zig.resolve(),root,uucode,target='aarch64-macos.14.0')
        source_args=[str(args.zig.resolve()),'build-exe','-target','aarch64-macos.14.0','-lc','-O',args.zig_mode,'--dep','uucode']
        environment=dict(os.environ,VEXE=str(args.v.resolve()),V_C_ERROR_BUG_REPORT_DISABLED='1')
        v_args=[str(args.v.resolve()),*(['-prod'] if args.v_prod else []),'-path',f'{args.v_root.resolve()}|{REPO}|@vlib|@vmodules']
        missing=0
        for fixture in ([] if args.registry_only else sorted((PROBE/'contracts').glob('*.zig'))):
            copied=root/'src'/fixture.name;shutil.copyfile(fixture,copied)
            native_result=subprocess.run([*source_args,f'-Mroot={copied}',*deps,'-fno-emit-bin'],capture_output=True)
            v_result=subprocess.run([*v_args,'-check',str(fixture.with_suffix('.v'))],capture_output=True,env=environment)
            if '_missing_' in fixture.stem:
                ordinary_rejection(native_result,fixture.name)
                ordinary_rejection(v_result,fixture.with_suffix('.v').name)
                missing+=1
            elif native_result.returncode or v_result.returncode:
                raise AssertionError(f'complete ctor rejected {fixture}: {native_result.stderr!r} / {v_result.stderr!r}')
        if args.contracts_only:
            print(f'{missing} required-field rejection pairs and 3 complete constructor pairs pass')
            return
        run([*source_args,f'-Mroot={root/"src/core_probe.zig"}',*deps,f'-femit-bin={root/"native"}'])
        environment=dict(os.environ,VEXE=str(args.v.resolve()),V_C_ERROR_BUG_REPORT_DISABLED='1')
        v_args=[str(args.v.resolve()),*(['-prod'] if args.v_prod else []),'-path',f'{args.v_root.resolve()}|{REPO}|@vlib|@vmodules']
        run([*v_args,'-o',str(root/'translated'),str(PROBE/'main.v')],env=environment)
        if args.registry_only:
            expected=run([str(root/'native'),'registry']).stdout
            actual=run([str(root/'translated'),'registry']).stdout
            if expected!=actual or expected!=b'2|2|1|1|1\n2|1|0|1|1\n2|0|0|0|1\n':
                raise AssertionError(f'copied registry header mismatch {expected!r} / {actual!r}')
            print('3 native registry count records match; sha256='+hashlib.sha256(expected).hexdigest())
            return
        cases=corpus();path=root/'corpus.txt';path.write_text('\n'.join(cases)+'\n')
        outputs=[]
        for executable in ['native','translated']:
            result=run([str(root/executable),str(path),str(root/'data.bin')],timeout=180)
            outputs.append(result.stdout.splitlines())
        if any(len(output)!=len(cases) for output in outputs):raise AssertionError([len(cases)]+[len(x) for x in outputs])
        for index,(case,expected,actual) in enumerate(zip(cases,*outputs)):
            if expected!=actual:raise AssertionError(f'row {index}: {case}\nsource={expected!r}\nV={actual!r}')
        for name in ['tall','back','tabs','zero','kitty']:
            for executable in ['native','translated']:
                result=subprocess.run([str(root/executable),'trap:'+name],capture_output=True,timeout=15)
                checked_trap(result, name, executable)
        # The pure consumers above run on macOS. Reachable lifecycle source methods
        # separately compile for its default libc-disabled Linux configuration.
        operations={
          'pty_init':'_=try P.init();',
          'pty_size':'const p:P=undefined;try p.setSize(.{.rows=2,.cols=4,.x_pixel=0,.y_pixel=0});',
          'command_spawn':'var c:C=undefined;try c.spawn(std.heap.page_allocator);',
          'terminal_init':'var env=std.process.EnvMap.init(std.heap.page_allocator);var bytes:[8]u8=undefined;_=try T.init(std.heap.page_allocator,&.{"true"},&env,.{},&bytes);',
          'terminal_spawn':'var t:T=undefined;try t.spawn();',
          'terminal_resize':'var t:T=undefined;try t.resize(.{.rows=2,.cols=4,.x_pixel=0,.y_pixel=0});',
        }
        for name,body in operations.items():
            fixture=root/'src'/f'{name}.zig';fixture.write_text('const std=@import("std");const T=@import("widgets/terminal/Terminal.zig");const P=@import("widgets/terminal/Pty.zig");const C=@import("widgets/terminal/Command.zig");pub fn main()!void{'+body+'}')
            result=subprocess.run([*source_args,f'-Mroot={fixture}',*deps,'-fno-emit-bin'],capture_output=True)
            ordinary_rejection(result,'macOS '+name)
            linux=[str(args.zig.resolve()),'build-exe','-target','aarch64-linux-gnu','-O',args.zig_mode,'--dep','uucode',f'-Mroot={fixture}',*deps,'-fno-emit-bin']
            run(linux)
        run([*v_args,'-os','linux','-check',str(PROBE/'lifecycle_linux.v')],env=environment)
        for fixture in PROBE.glob('unavailable_*.v'):
            result=subprocess.run([*v_args,'-check',str(fixture)],capture_output=True,env=environment)
            ordinary_rejection(result,fixture.name)
        digest=hashlib.sha256(b'\n'.join(outputs[0])+b'\n').hexdigest()
        print(f'{len(cases)} returning records, 5 checked traps, 6 macOS rejections and Linux lifecycle compile pairs, {missing} required-field rejection pairs; sha256={digest}')
        if args.keep:
            if args.keep.exists():shutil.rmtree(args.keep)
            shutil.copytree(root,args.keep)
if __name__=='__main__':main()
