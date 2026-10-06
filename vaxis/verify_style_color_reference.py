"""Compare public Vaxis Style/Color with unchanged source and measured carriers."""
import argparse
import hashlib
import itertools
import json
import os
from pathlib import Path
import resource
import shutil
import subprocess
import sys
import tempfile
REPO=Path(__file__).resolve().parent.parent
PROBE=REPO/'vaxis/reference_probes/style_color'
sys.path.insert(0,str(PROBE.parent/'widgets_classic'))
from source_build import VAXIS_SHA256,UUCODE_SHA256,UUCODE_PACKAGE,module,prepare_uucode,tree_hash
from verify_input_parser_reference import ordinary_rejection,strict_trap


def corpus():
    rows=['A','B']
    numbers=sorted({0,1,0xfffffe,0xffffff,0x123456,0xabcdef}|{n<<shift for n,shift in itertools.product(range(256),[0,8,16])}|{(n<<16)|((255-n)<<8)|(n^0x55) for n in range(256)})
    rows += [f'U|{n}' for n in numbers]
    colors=[(0,0)]+[(1,n) for n in range(256)]
    for n in numbers[::7]:colors.append((2,n))
    for left,right in itertools.product(colors,repeat=2):rows.append(f'E|{left[0]}|{left[1]}|{right[0]}|{right[1]}')
    for n in range(256):
        for lane in range(3):
            value=n<<(lane*8)
            rows.append(f'E|2|{value}|2|{value}')
            rows.append(f'E|2|{value}|2|{value ^ (1<<(lane*8))}')
    for bits,underline,seed in itertools.product(range(128),range(6),range(4)):
        selected=[(0,0),(1,seed*61),(2,0x123456^(seed*0x010101)),(2,0xffffff^(seed*0x12345))]
        fg,bg,ul=selected[seed],selected[(seed+1)%4],selected[(seed+2)%4]
        rows.append(f'T|{fg[0]}|{fg[1]}|{bg[0]}|{bg[1]}|{ul[0]}|{ul[1]}|{underline}|{bits}')
    specs=[b'',b'rgb',b'rgb:',b'RGB:aaaa/bbbb/cccc',b'rgb:0012/0034/0056/extra:ignored',b'rgb:zz12/?*34/\x00\xff56',b'rgb:1__2/3__4/5__6']
    pieces=[b'',b'0',b'000',b'0000',b'0012',b'00ff',b'00ZZ',b'zzZZ',b'zz12',b'00_1',b'00+1',b'00000']
    specs += [b'rgb:'+b'/'.join(values) for values in itertools.product(pieces,repeat=3)]
    base=b'rgb:0012/0034/0056'
    for pos,byte in itertools.product(range(len(base)),range(256)):
        specs.append(base[:pos]+bytes([byte])+base[pos+1:])
    for value in [b'rgb:0000/1111/22ff',b'rgb:00ZZ/bad/cccc',b'rgb:00ff/00ZZ/bad',b'rgb:00ZZ/00ff',b'rgb:00ff/00ZZ',b'rgb:zz12/gg34/bb56:tail']:
        for end in range(len(value)+1):specs.append(value[:end])
    rows += ['S|'+spec.hex() for spec in specs]
    return rows


def source_command(native,path,output=None):
    command=[f'-Mroot={path}' if x.startswith('-Mroot=') else x for x in native if not x.startswith('-femit-bin=')]
    return [*command,f'-femit-bin={output}' if output else '-fno-emit-bin']


def contracts(root,native,v_command,environment):
    cases={
        'missing_index':('const v=@import("vaxis");pub fn main() void {const c:v.Cell.Color=.index;_=c;}','module main\nimport vaxis\nfn main(){c:=vaxis.ColorIndex{};println(c.index)}'),
        'missing_rgb':('const v=@import("vaxis");pub fn main() void {const c:v.Cell.Color=.rgb;_=c;}','module main\nimport vaxis\nfn main(){c:=vaxis.ColorRgb{};println(c.rgb)}'),
    }
    for name,(source,translated) in cases.items():
        source_path=root/f'{name}.zig';source_path.write_text(source);v_path=root/f'{name}.v';v_path.write_text(translated)
        for label,argv in [('native',source_command(native,source_path)),('translated',[*v_command,'-check',str(v_path)])]:
            result=subprocess.run(argv,env=environment,capture_output=True);ordinary_rejection(result)
            (root/f'{name}-{label}.log').write_bytes(result.stdout+result.stderr)
    # These are measured adaptations, not paired compiler rejections.
    boundaries={
        'literal_u24':('const v=@import("vaxis");pub fn main() void {_=v.Cell.Color.rgbFromUint(0x1000000);}','module main\nimport vaxis\nfn main(){_=vaxis.color_rgb_from_uint(0x1000000)}','reject','accept'),
        'implicit_u32':('const v=@import("vaxis");extern fn value() u32;pub fn main() void {_=v.Cell.Color.rgbFromUint(value());}','module main\nimport vaxis\nfn main(){n:=u32(1);_=vaxis.color_rgb_from_uint(n)}','reject','accept'),
        'alias_missing_rgb':('const v=@import("vaxis");const Alias=v.Cell.Color;pub fn main() void {const c:Alias=.rgb;_=c;}','module main\nimport vaxis\ntype Alias=vaxis.ColorRgb\nfn main(){c:=Alias{};println(c.rgb)}','reject','accept'),
        'readonly_payload':('const std=@import("std");const v=@import("vaxis");pub fn main() void {var c:v.Cell.Color=.{.rgb=.{1,2,3}};const old=c;c.rgb[0]=9;std.debug.print("{d},{d}\\n",.{c.rgb[0],old.rgb[0]});}','module main\nimport vaxis\nfn main(){mut c:=vaxis.Color(vaxis.ColorRgb{rgb:[u8(1),2,3]!});if mut c is vaxis.ColorRgb {c.rgb[0]=9};println(c)}','accept','reject'),
    }
    for name,(source,translated,native_outcome,v_outcome) in boundaries.items():
        source_path=root/f'{name}.zig';source_path.write_text(source);v_path=root/f'{name}.v';v_path.write_text(translated)
        for label,argv,outcome in [('native',source_command(native,source_path),native_outcome),('translated',[*v_command,'-check',str(v_path)],v_outcome)]:
            result=subprocess.run(argv,env=environment,capture_output=True);(root/f'{name}-{label}.log').write_bytes(result.stdout+result.stderr)
            if outcome=='reject':ordinary_rejection(result)
            elif result.returncode:raise AssertionError(f'{name} {label} ordinary acceptance failed')


def verify(args,root):
    source=args.source.resolve()/'src'
    if tree_hash(source)!=VAXIS_SHA256:raise AssertionError('Vaxis source differs from pinned tree')
    shutil.copytree(source,root/'src');graph=prepare_uucode(args.zig.resolve(),root,args.uucode.resolve())
    for name in ['reference.zig','main.v']:shutil.copy2(PROBE/name,root/name)
    mode='ReleaseSafe' if args.v_prod else 'Debug'
    metadata={'source_sha256':VAXIS_SHA256,'uucode_sha256':UUCODE_SHA256,'source_mode':mode,'v_mode':'production' if args.v_prod else 'ordinary','target':'aarch64-macos.14.0','fixtures':{name:hashlib.sha256((PROBE/name).read_bytes()).hexdigest() for name in ['reference.zig','main.v']}}
    (root/'metadata.json').write_text(json.dumps(metadata,indent=2)+'\n')
    native=[str(args.zig.resolve()),'build-exe','-O',mode,'-target','aarch64-macos.14.0','-lc',*module('root',root/'reference.zig',['vaxis']),*module('vaxis',root/'src/main.zig',['uucode']),*graph,f'-femit-bin={root}/native']
    v_command=[str(args.v.resolve()),*(['-prod'] if args.v_prod else []),'-path',f'{REPO}|@vlib|@vmodules']
    environment=dict(os.environ,VEXE=str(args.v.resolve()),V_C_ERROR_BUG_REPORT_DISABLED='1')
    for label,argv in [('native',native),('translated',[*v_command,'-keepc','-o',str(root/'translated'),str(root/'main.v')])]:
        print(f'Building {label} {mode}',file=sys.stderr,flush=True);(root/f'{label}-argv.json').write_text(json.dumps(argv,indent=2)+'\n')
        result=subprocess.run(argv,env=environment,capture_output=True);(root/f'{label}-build.log').write_bytes(result.stdout+result.stderr)
        if result.returncode:raise AssertionError(result.stderr.decode(errors='replace'))
    rows=corpus();(root/'corpus.txt').write_text('\n'.join(rows)+'\n');outputs=[]
    for label in ['native','translated']:
        print(f'Running {label}: {len(rows)} records',file=sys.stderr,flush=True)
        result=subprocess.run([str(root/label),str(root/'corpus.txt')],capture_output=True,timeout=args.timeout)
        (root/f'{label}.stdout').write_bytes(result.stdout);(root/f'{label}.stderr').write_bytes(result.stderr)
        if result.returncode or result.stderr:raise AssertionError(f'{label} returning producer failed')
        outputs.append(result.stdout.splitlines())
    if any(len(output)!=len(rows) for output in outputs):raise AssertionError([len(rows)]+[len(output) for output in outputs])
    for index,(case,expected,actual) in enumerate(zip(rows,*outputs)):
        if expected!=actual:raise AssertionError(f'row{index} {case}: Source={expected!r}; V={actual!r}')
    for value in [0x1000000,0x1000001,0x80000000,0xffffffff]:
        for label in ['native','translated']:
            result=subprocess.run([str(root/label),'trap',str(value)],capture_output=True,timeout=15)
            (root/f'{label}-range{value}.stdout').write_bytes(result.stdout);(root/f'{label}-range{value}.stderr').write_bytes(result.stderr)
            strict_trap(result,'integer does not fit in destination type')
    observations={}
    for name in ['boxed','layout']:
        observations[name]={}
        for label in ['native','translated']:
            result=subprocess.run([str(root/label),name],capture_output=True,timeout=15)
            (root/f'{label}-{name}.stdout').write_bytes(result.stdout);(root/f'{label}-{name}.stderr').write_bytes(result.stderr)
            if result.returncode or result.stderr:raise AssertionError(f'{label} {name} boundary failed')
            observations[name][label]=result.stdout.decode().strip()
    if observations['boxed']!={'native':'r9,2,3|r1,2,3|r8,5,6|r4,5,6','translated':'r9,2,3|r9,2,3|r8,5,6|r8,5,6'}:raise AssertionError(observations['boxed'])
    if observations['layout']['native']==observations['layout']['translated']:raise AssertionError('recorded layout boundary changed')
    (root/'representation-boundaries.json').write_text(json.dumps(observations,indent=2)+'\n')
    contracts(root,native,v_command,environment)
    if tree_hash(source)!=VAXIS_SHA256 or tree_hash(root/'src')!=VAXIS_SHA256:raise AssertionError('Vaxis tree changed')
    if tree_hash(args.uucode.resolve())!=UUCODE_SHA256 or tree_hash(root/'uucode')!=UUCODE_SHA256:raise AssertionError('uucode tree changed')
    if any(hashlib.sha256((PROBE/name).read_bytes()).hexdigest()!=digest for name,digest in metadata['fixtures'].items()):raise AssertionError('fixture changed')
    digest=hashlib.sha256(b'\n'.join(outputs[0])).hexdigest()
    print(f'Style/Color ({mode}): {len(rows)} returning records, 4 strict range traps, 2 paired payload omissions, 4 measured compiler/API boundaries and 2 boxed-copy observations +1 layout observation; SHA256 {digest}')


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source',type=Path);parser.add_argument('zig',type=Path);parser.add_argument('v',type=Path)
    parser.add_argument('--uucode',type=Path,default=Path.home()/'.cache/zig/p'/UUCODE_PACKAGE)
    parser.add_argument('--v-prod',action='store_true');parser.add_argument('--workdir',type=Path);parser.add_argument('--timeout',type=float,default=180)
    args=parser.parse_args();resource.setrlimit(resource.RLIMIT_CORE,(0,0))
    if args.workdir:args.workdir.mkdir(exist_ok=False,parents=True);verify(args,args.workdir.resolve())
    else:
        with tempfile.TemporaryDirectory(prefix='witty-style-color-') as directory:verify(args,Path(directory))
if __name__=='__main__':main()
