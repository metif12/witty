"""Compare the public input Parser against the unchanged pinned Vaxis source."""
import argparse
import hashlib
import itertools
import json
import os
from pathlib import Path
import re
import resource
import shutil
import subprocess
import sys
import tempfile

REPO = Path(__file__).resolve().parent.parent
PROBE = REPO / 'vaxis/reference_probes/input_parser'
sys.path.insert(0, str(PROBE.parent / 'widgets_classic'))
from source_build import VAXIS_SHA256, UUCODE_SHA256, UUCODE_PACKAGE, module, prepare_uucode, tree_hash


def corpus():
    rows = []
    def add(data, clipboard=False):
        if data: rows.append(f'P|{data.hex()}|{int(clipboard)}')
    for length in (1, 2):
        for values in itertools.product(range(256), repeat=length): add(bytes(values))
    for text in [b'abc', b'\xc2\xa2', b'\xe2\x82\xac', b'\xf0\x9f\x98\x80', b'e\xcc\x81', b'\xff\xcc\x81', b'\xe1\x80a', b'\xf0\x9fab', b'\xed\xa0\x80', b'\xf0\x80\x80\xaf', b'\xf4\x90\x80\x80']:
        for size in range(1, len(text)+1): add(text[:size])
    for kind in b'OPX^_':
        for byte in range(256):
            text = b'\x1b'+bytes([kind, byte])+b'abc\x1b\\tail'
            for length in (2,3,len(text)-5,len(text)-4,len(text)):
                # APC ending exactly at its first ESC is a source trap.
                value=text[:length]
                if kind == ord('_') and value.endswith(b'\x1b'): continue
                add(value)
    finals=b'ABCDHFPQRS~u'
    params=[b'',b'0',b'1',b'2',b'3',b'8',b'13',b'27',b'97',b'255',b'256',b'65535',b'65536',b'2097151',b'2097152',b'+1',b'-1',b':',b'1:2',b'97:65:98',b'999999999999999999999999']
    for final,param,mods in itertools.product(finals,params,[b'',b';',b';0',b';1',b';2',b';255',b';256',b';2:3',b';2:2',b';2:1',b';2:0',b';2:4']):
        add(b'\x1b['+param+mods+bytes([final]))
    for mask,event in itertools.product(range(256),[b'',b':0',b':1',b':2',b':3',b':4']):
        add(b'\x1b[97;'+str(mask).encode()+event+b'u')
    for cp in [0,1,31,32,65,97,127,128,2047,2048,55295,55296,57343,57344,65535,65536,1114111,1114112,2097151,2097152]:
        add(b'\x1b[97;;'+str(cp).encode()+b'u')
        add(b'\x1b[97;;97:'+str(cp).encode()+b'u')
    for count,cp in itertools.product([0,1,31,32,42,63,64,127,128],[0,97,128,2048,65536]):
        encoded_len=1 if cp<128 else 2 if cp<2048 else 3 if cp<65536 else 4
        if count*encoded_len<=128:
            add(b'\x1b[97;;'+b':'.join([str(cp).encode()]*count)+b'u')
    # Capacity is checked before surrogate rejection, but a too-large codepoint
    # returns its unicode error first, even when all scratch bytes were used.
    add(b'\x1b[97;;'+b'97:'*128+b'1114112u')
    for mask in range(512):
        if mask<256 and mask&0xc3>=192: continue
        for final in b'Mm': add(f'\x1b[<{mask};1;1'.encode()+bytes([final]))
    for position in [b'',b'0',b'1',b'2',b'255',b'65535',b'65536',b'+1',b'-1',b'999999999999']:
        for slot in range(2):
            values=[b'1',b'1'];values[slot]=position
            add(b'\x1b[<0;'+b';'.join(values)+b'M')
    for mask in range(192): add(b'\x1b[M'+bytes([mask+32,33,34]))
    for position in range(32,256):
        add(b'\x1b[M'+bytes([32,position,33]));add(b'\x1b[M'+bytes([32,33,position]))
    for text in [b'\x1b[?c',b'\x1b[1c',b'\x1b[?997;1n',b'\x1b[?997;2n',b'\x1b[?997;n',b'\x1b[?997;3n',b'\x1b[?997n;2',b'\x1b[$1016;1$y',b'\x1b[?2027;1$y',b'\x1b[?2031;2$y',b'\x1b[?2031;4$y',b'\x1b[?2031y;2',b'\x1b[0 q',b'\x1b[ q',b'\x1b[I',b'\x1b[O',b'\x1b[48;4;8;20;40t',b'\x1b[48;4;8t',b'\x1b[200~',b'\x1b[201~']:
        add(text+b'after')
        for length in range(1,len(text)):
            partial=text[:length]
            if partial==b'\x1b[c':continue
            add(partial)
    payloads=[b'',b'YQ==',b'YWI=',b'YWJj',b'YWJjZA==',b'====',b'YQ=',b'YQ',b'YQ===',b'YR==',b'YWF=',b'YWJ-',b'YWJ_',b'YWJj\n',b'YWJj ',b'AA==\x00']
    payloads += [bytes([byte])+b'Q==' for byte in range(256) if byte not in (7,27)]
    for payload,ending in itertools.product(payloads,[b'\x07',b'\x1b\\',b'\x1bQ']): add(b'\x1b]52;c;'+payload+ending+b'after',True)
    for ps in [b'0',b'4',b'10',b'11',b'12',b'52',b'255',b'256',b'+10',b'-1']:
        for spec in [b'rgb:aaaa/bbbb/cccc',b'rgb:0000/1111/22ff',b'rgb:aaff/bbff/ccff/extra',b'rgb:0000/0000/0000:ignored',b'bad',b'rgb:00zz/0000/0000',b'rgb:00ff/0000/short',b'']:
            prefix=b'\x1b]'+ps+b';'+(b'2;' if ps==b'4' else b'')
            for ending in [b'\x07',b'\x1b\\']: add(prefix+spec+ending+b'tail',True)
    for text in [b'\x1b]4;\x07;2;rgb:aaaa/bbbb/cccc',b'\x1b]4;2\x07;rgb:aaaa/bbbb/cccc',b'\x1b]52;x\x07',b'\x1b]52;\x07',b'\x1b]10\x07;rgb:aaaa/bbbb/cccc',b'\x1b]52;c;YQ==\x07\x1b\\']:
        add(text,True)
    for first,next_ in [(b'ab',b'\x1b[97;;120:121u'),(b'\x1b[97;;97:98u',b'\x1b[97;;120:121u'),(b'\x1b[97;2u',b'\x1b[97;;122:55296u'),(b'\x1b[97;;128:129u',b'\x1b[97;;65u')]:
        rows.append(f'B|{first.hex()}|{next_.hex()}')
    return rows


def traps():
    assertion='reached unreachable code'
    bounds=r'index out of bounds.*'
    entries=[('empty',b'',False,assertion,r'Assertion failed: input.len > 0'),('apc',b'\x1b_G\x1b',False,bounds,'index out of bounds'),('da1',b'\x1b[c',False,assertion,'Assertion failed: sequence.len >= 4')]
    for mask in [192,193,194,195]: entries.append((f'enum{mask}',f'\x1b[<{mask};1;1M'.encode(),False,'invalid enum value','invalid enum value'))
    entries.append(('xterm_enum',b'\x1b[M\xe0!!',False,'invalid enum value','invalid enum value'))
    for slot in range(3):
        values=bytearray(b'!!!');values[slot]=31
        entries.append((f'sub{slot}',b'\x1b[M'+values,False,'integer overflow','integer overflow'))
    for payload in [b'YQ==',b'YQ=']:
        entries.append((f'clipboard{len(payload)}',b'\x1b]52;c;'+payload+b'\x07',False,'attempt to use null value','attempt to use null value'))
    entries.append(('clipboard_short',b'\x1b]52;c\x07',True,r'start index .* larger than end index.*','start index is larger than end index'))
    for prefix,cp in [(128,97),(127,128),(126,2048),(125,65536),(127,55296)]:
        entries.append((f'capacity{prefix}_{cp}',b'\x1b[97;;'+b'97:'*prefix+str(cp).encode()+b'u',False,assertion,'Assertion failed: out.len >= length'))
    return entries


def strict_trap(run, category):
    text=(run.stdout+run.stderr).decode(errors='replace')
    headers=[match.group(1) for line in text.splitlines() if (match:=re.fullmatch(r'(?:thread \d+ |V )panic:\s*(.*)',line))]
    if run.returncode==0 or run.stdout or any(line.lstrip().startswith('UNEXPECTED') for line in text.splitlines()) or not any(re.fullmatch(category,header) for header in headers):
        raise AssertionError(f'expected {category} panic header with empty stdout, got {text}')


def ordinary_rejection(result):
    text=(result.stdout+result.stderr).decode(errors='replace')
    if result.returncode != 1 or not re.search(r'\berror:',text) or re.search(r'panic:|Segmentation|Bus error|compiler bug|internal compiler|C compilation failed|C compiler error|builder error|\.tmp\.c:.*error:|LLVM ERROR',text,re.I):
        raise AssertionError(f'not an ordinary compile rejection: {text}')


def contracts(root,native,v_command,environment):
    source_cases={
        'missing_event':'const v=@import("vaxis"); pub fn main() void { const r:v.Parser.Result=.{.n=0};_ = r; }',
        'missing_n':'const v=@import("vaxis"); pub fn main() void { const r:v.Parser.Result=.{.event=null};_ = r; }',
    }
    v_cases={
        'missing_event':'module main\nimport vaxis\nfn main(){r:=vaxis.ParserResult{n:0};println(r.n)}',
        'missing_n':'module main\nimport vaxis\nfn main(){r:=vaxis.ParserResult{event:none};println(r.n)}',
    }
    for name,body in source_cases.items():
        (root/f'{name}.zig').write_text(body)
        argv=[arg if not arg.startswith('-Mroot=') else f'-Mroot={root/name}.zig' for arg in native if not arg.startswith('-femit-bin=')]
        result=subprocess.run([*argv,'-fno-emit-bin'],capture_output=True)
        ordinary_rejection(result);(root/f'{name}-native.log').write_bytes(result.stdout+result.stderr)
        (root/f'{name}.v').write_text(v_cases[name])
        result=subprocess.run([*v_command,'-check',str(root/f'{name}.v')],env=environment,capture_output=True)
        ordinary_rejection(result);(root/f'{name}-translated.log').write_bytes(result.stdout+result.stderr)
    # The pinned V compiler ignores inherited required markers on aliases.
    (root/'alias_result.zig').write_text('const v=@import("vaxis");const Alias=v.Parser.Result;pub fn main() void {const r:Alias=.{};_=r;}')
    argv=[arg if not arg.startswith('-Mroot=') else f'-Mroot={root}/alias_result.zig' for arg in native if not arg.startswith('-femit-bin=')]
    rejection=subprocess.run([*argv,'-fno-emit-bin'],capture_output=True)
    ordinary_rejection(rejection);(root/'alias_result-native.log').write_bytes(rejection.stdout+rejection.stderr)
    (root/'alias_result.v').write_text('module main\nimport vaxis\ntype Alias = vaxis.ParserResult\nfn main(){r:=Alias{};println(r.n)}')
    accepted=subprocess.run([*v_command,'-check',str(root/'alias_result.v')],env=environment,capture_output=True)
    (root/'alias_result-translated.log').write_bytes(accepted.stdout+accepted.stderr)
    if accepted.returncode:raise AssertionError('measured alias required-field limitation changed')
    source='''const std=@import("std");const v=@import("vaxis");pub fn main() !void {var p:v.Parser=.{.buf=@splat(17)};var q=p;p.buf[0]=42;var r:v.Parser.Result=.{.event=null,.n=7};var s=r;r.n=9;s.event=null; q.buf[1]=99;var b:[128]u8=undefined;const text=try std.fmt.bufPrint(&b,"{d}|{d}|{d}|{d}|{d}\\n",.{p.buf[0],q.buf[0],p.buf[1],r.n,s.n});_=try std.posix.write(1,text);}'''
    translated='''module main\nimport vaxis\nfn main(){mut p:=vaxis.Parser{buf:[128]u8{init:17}};mut q:=p;p.buf[0]=42;mut r:=vaxis.ParserResult{event:none,n:7};mut s:=r;r.n=9;s.event=none;q.buf[1]=99;println('${p.buf[0]}|${q.buf[0]}|${p.buf[1]}|${r.n}|${s.n}')}'''
    (root/'complete.zig').write_text(source);(root/'complete.v').write_text(translated)
    argv=[arg if not arg.startswith('-Mroot=') else f'-Mroot={root}/complete.zig' for arg in native if not arg.startswith('-femit-bin=')]
    subprocess.run([*argv,f'-femit-bin={root}/complete-native'],check=True)
    subprocess.run([*v_command,'-o',str(root/'complete-translated'),str(root/'complete.v')],env=environment,check=True)
    expected=subprocess.check_output([str(root/'complete-native')]);actual=subprocess.check_output([str(root/'complete-translated')])
    if expected!=actual or expected!=b'42|17|17|9|7\n':raise AssertionError((expected,actual))


def verify(args,root):
    source=args.source.resolve()/'src'
    if tree_hash(source)!=VAXIS_SHA256:raise ValueError('Vaxis source differs from pinned tree')
    shutil.copytree(source,root/'src')
    graph=prepare_uucode(args.zig.resolve(),root,args.uucode.resolve())
    mode='ReleaseSafe' if args.v_prod else 'Debug'
    fixtures={name:hashlib.sha256((PROBE/name).read_bytes()).hexdigest() for name in ('reference.zig','main.v')}
    (root/'metadata.json').write_text(json.dumps({'source_sha256':VAXIS_SHA256,'uucode_sha256':UUCODE_SHA256,'fixtures':fixtures,'source_mode':mode,'v_mode':'production' if args.v_prod else 'ordinary','target':'aarch64-macos.14.0'},indent=2)+'\n')
    shutil.copy2(PROBE/'reference.zig',root/'reference.zig');shutil.copy2(PROBE/'main.v',root/'main.v')
    native=[str(args.zig.resolve()),'build-exe','-O',mode,'-target','aarch64-macos.14.0','-lc',*module('root',root/'reference.zig',['vaxis']),*module('vaxis',root/'src/main.zig',['uucode']),*graph,f'-femit-bin={root}/native']
    v_command=[str(args.v.resolve()),*(['-prod'] if args.v_prod else []),'-path',f'{REPO}|@vlib|@vmodules']
    environment=dict(os.environ,VEXE=str(args.v.resolve()),V_C_ERROR_BUG_REPORT_DISABLED='1')
    for label,argv in [('native',native),('translated',[*v_command,'-keepc','-o',str(root/'translated'),str(root/'main.v')])]:
        print(f'Building {label} ({mode})',file=sys.stderr,flush=True)
        (root/f'{label}-argv.json').write_text(json.dumps(argv));subprocess.run(argv,env=environment,check=True)
    rows=corpus();(root/'corpus.txt').write_text('\n'.join(rows)+'\n')
    outputs=[]
    for label in ['native','translated']:
        print(f'Running {label}: {len(rows)} cases',file=sys.stderr,flush=True)
        with (root/f'{label}.stdout').open('wb') as out,(root/f'{label}.stderr').open('wb') as err:
            run=subprocess.run([str(root/label),str(root/'corpus.txt')],stdout=out,stderr=err,timeout=args.timeout)
        if run.returncode:raise AssertionError(f'{label} corpus failed, see {root}/{label}.stderr')
        outputs.append((root/f'{label}.stdout').read_bytes().splitlines())
    if any(len(output)!=len(rows) for output in outputs):raise AssertionError([len(rows)]+[len(output) for output in outputs])
    for index,(case,expected,actual) in enumerate(zip(rows,*outputs)):
        if expected!=actual:raise AssertionError(f'row {index} {case}: Source={expected!r}; V={actual!r}')
    for name,data,clipboard,native_category,v_category in traps():
        for label,category in [('native',native_category),('translated',v_category)]:
            run=subprocess.run([str(root/label),'trap',data.hex(),str(int(clipboard))],capture_output=True,timeout=15)
            (root/f'{label}-{name}.stdout').write_bytes(run.stdout);(root/f'{label}-{name}.stderr').write_bytes(run.stderr)
            strict_trap(run,category)
    contracts(root,native,v_command,environment)
    if tree_hash(source)!=VAXIS_SHA256 or tree_hash(root/'src')!=VAXIS_SHA256:raise AssertionError('Source tree changed during comparison')
    if tree_hash(args.uucode.resolve())!=UUCODE_SHA256 or tree_hash(root/'uucode')!=UUCODE_SHA256:raise AssertionError('uucode tree changed during comparison')
    if any(hashlib.sha256((PROBE/name).read_bytes()).hexdigest()!=value for name,value in fixtures.items()):raise AssertionError('fixture changed during comparison')
    digest=hashlib.sha256(b'\n'.join(outputs[0])).hexdigest()
    print(f'Input Parser ({mode}): {len(rows)} returning records, {len(traps())} strict trap pairs, 1 complete mutable-copy constructor, 2 omission pairs and 1 measured alias-marker boundary; SHA256 {digest}')


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source',type=Path);parser.add_argument('zig',type=Path);parser.add_argument('v',type=Path)
    parser.add_argument('--uucode',type=Path,default=Path.home()/'.cache/zig/p'/UUCODE_PACKAGE)
    parser.add_argument('--v-prod',action='store_true');parser.add_argument('--workdir',type=Path);parser.add_argument('--timeout',type=float,default=180)
    args=parser.parse_args();resource.setrlimit(resource.RLIMIT_CORE,(0,0))
    if args.workdir:
        args.workdir.mkdir(parents=True,exist_ok=False);verify(args,args.workdir.resolve())
    else:
        with tempfile.TemporaryDirectory(prefix='witty-input-parser-') as directory:verify(args,Path(directory))
if __name__=='__main__':main()
