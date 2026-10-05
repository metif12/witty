"""Compare fixture-exposed unchanged private Terminal.run with a V module test."""
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

REPO=Path(__file__).resolve().parent.parent
PROBE=Path(__file__).resolve().parent/'reference_probes/terminal/private_run'
sys.path.insert(0,str(PROBE.parent.parent/'widgets_classic'))
from source_build import VAXIS_SHA256,UUCODE_PACKAGE,prepare_uucode,tree_hash,module

WRAPPER=b'\n// Fixture-only exposure; all original Terminal statements remain unchanged.\npub fn audit_run(self: *Terminal) !void { return self.run(); }\n'

def case(data,w=12,h=4,col=0,row=1,modes=6,dirty=0,last=b'ab',quit=0):
    return '|'.join(map(str,(data.hex(),w,h,col,row,modes,dirty,last.hex(),quit)))

def corpus():
    cases=[]
    def add(data,**kw): cases.append(case(data,**kw))
    for data,modes,dirty,quit in itertools.product([b'',b'A',b'\x07',b'\x1b[2;3H'],[0,1,6,7,14,15],[0,1],[0,1]):
        add(data,modes=modes,dirty=dirty,quit=quit)
    for byte in range(32):add(bytes([byte]))
    for text,col,row in itertools.product([b'ab',b'ab\rZ',b'a\nb\tc',b'\xe2\x82\xac',b'\xf0\x9f\x98\x80',b'e\xcc\x81',b'\xe2\x9d\xa4\xef\xb8\x8f',b'\xc0\xff',b'\xc2A',b'\xe2AB',b'\xf0ABC',b'\x80',b'\xe2\x82'],[0,5,11],[0,1,3]):
        add(text,col=col,row=row)
    for suffix in [b'B',b'D',b'E',b'H',b'M',b' !A',b'NQ',b'OQ',b'Pskip\x1bQ',b'Xskip\x1bQ',b'^skip\x1bQ',b'_ignored\x1b\\']:
        add(b'\x1b'+suffix)
    for final,param,col,row in itertools.product('AkBCD jEFG`HfIJKLM PSTXa bcdeg'.replace(' ',''),[b'',b'0',b'1',b'2',b'3'],[0,5],[0,1,3]):
        # insertLine's saturated row decrement never progresses when adjusted_n=0.
        if final=='L' and row==3 and param!=b'0':continue
        add(b'\x1b['+param+final.encode(),col=col,row=row)
    for param in [b'',b'0',b'1',b'2',b'3']:add(b'\x1b['+param+b'Z',col=0)
    for final in range(0x40,256):add(b'\x1b[0'+bytes([final]))
    for param,marker,intermediate,final in itertools.product([b'',b'0',b'1',b'5',b'6',b'2026'],[b'',b'?',b'>',b'='],[b'',b'$',b' '],[b'c',b'n',b'p',b'q',b'r']):
        if final==b'q' and intermediate==b' ' and param==b'2026':continue
        add(b'\x1b['+marker+param+intermediate+final)
    for shape in range(7):add(b'\x1b['+str(shape).encode()+b' q')
    for params in [b'',b'0',b'1;2;3;4',b'4:2',b'22;23;24;25;27;28;29',b'31;44',b'38;5;7',b'48;2;1;2;3',b'58:2::12:34:56']:
        add(b'\x1b['+params+b'mA')
    for mode,final,marker in itertools.product([0,4,7,25,1049,2026],[b'h',b'l'],[b'',b'?']):
        add(b'\x1b['+marker+str(mode).encode()+final+b'Q')
    for params in [b'',b'0',b'1;3',b'2;4',b'3;2']:
        for origin in [0,1]:add(b'\x1b['+params+b'r',modes=6+origin,col=5,row=2)
    for data in [b'\x1bH\x1bH\x1b[0g',b'\x1b[3g\x1b[?5W',b'\x1b[5W',b'\x1b[>5W',b'\x1b[?4W',b'\x1b[1049hA\x1b[1049lB']:
        add(data,col=5)
    for last,n in itertools.product([b'',b'ab',b'\x80',b'\xc2A',b'\xe2\x82\xac'],[0,1,2]):
        add(b'\x1b['+str(n).encode()+b'b',last=last)
    osc=[b'',b'0',b'0;',b'0;one',b'00;two',b'0_0;three',b'+0;ignored',b'256;ignored',b'7;',b'7;file://host/path',b'7;file://host/a%20b%00c',b'7;file://host/%gg',b'7;file://host/%_1',b'7;file://host/%1_',b'7;garbage',b'8;ignored']
    for data,ending in itertools.product(osc,[b'\x07',b'\x1b\\',b'\x1bQ',b'\x1b',b'']):add(b'\x1b]'+data+ending)
    for data in [b'\x1b]0;one\x07\x1b]0;two\x07',b'\x1b]0;first\x07\x1b]0;longer\x07',b'\x1b]7;file://host/one\x07\x1b]7;file://host/two\x07',b'\x1b[2;3H\x1b]0;a\x07\x1b[5n\x1b]7;file://host/a%20b\x07\x07']:
        add(data)
    return cases

def traps():
    return {
        'u16_add':case(b'\x1b[65536A'),
        'u8_add':case(b'\x1b[256K'),
        'shape':case(b'\x1b[7 q'),
        'pct_one':case(b'\x1b]7;file://host/%\x07'),
        'pct_two':case(b'\x1b]7;file://host/%a\x07'),
        'backtab':case(b'\x1b[2Z',col=5),
        'erase_index':case(b'\x1b[65535X'),
        'relative':case(b'\x1b[a',col=65535),
        'position_reply':case(b'\x1b[6n',row=65535),
        'print_start':case(b'\xc0\xff\xcc\x81'),
    }

def checked_trap(result, expected):
    text=result.stdout+result.stderr
    unexpected=any(line.startswith(b'UNEXPECTED:') for line in text.splitlines())
    messages=[match.group(1) for line in result.stderr.splitlines()
              if (match:=re.fullmatch(rb'(?:thread [0-9]+ )?(?:V )?panic:\s*(.*)',line))]
    return result.returncode!=0 and not result.stdout and not unexpected and any(message.startswith(expected) for message in messages)

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source',type=Path);parser.add_argument('zig',type=Path);parser.add_argument('v',type=Path)
    parser.add_argument('--uucode',type=Path,default=Path.home()/'.cache/zig/p'/UUCODE_PACKAGE)
    parser.add_argument('--v-root',type=Path,default=REPO,help=argparse.SUPPRESS)
    parser.add_argument('--v-prod',action='store_true');parser.add_argument('--zig-mode',choices=['Debug','ReleaseSafe'],default='Debug')
    parser.add_argument('--keep',type=Path,help=argparse.SUPPRESS)
    args=parser.parse_args();resource.setrlimit(resource.RLIMIT_CORE,(0,0));source=args.source.resolve()/'src'
    if tree_hash(source)!=VAXIS_SHA256:parser.error('vaxis source differs from pinned tree')
    with tempfile.TemporaryDirectory(prefix='witty-terminal-private-run-') as folder:
        root=Path(folder);shutil.copytree(source,root/'src');path=Path('widgets/terminal/Terminal.zig');original=(source/path).read_bytes()
        target=root/'src'/path;target.write_bytes(original+WRAPPER)
        if target.read_bytes()!=original+WRAPPER or target.read_bytes()[:len(original)]!=original:raise AssertionError('original Terminal body changed')
        for entry in source.rglob('*'):
            if entry.is_file() and entry.relative_to(source)!=path and entry.read_bytes()!=(root/'src'/entry.relative_to(source)).read_bytes():raise AssertionError('original dependency body changed')
        (root/'prefix.json').write_text(json.dumps({'source_tree_sha256':VAXIS_SHA256,'terminal_original_size':len(original),'terminal_original_sha256':hashlib.sha256(original).hexdigest(),'appended_fixture':WRAPPER.decode()},indent=2))
        shutil.copyfile(PROBE/'reference.zig',root/'src/private_probe.zig');graph=prepare_uucode(args.zig.resolve(),root,args.uucode.resolve())
        subprocess.run([str(args.zig.resolve()),'build-exe','-target','aarch64-macos.14.0','-lc','-O',args.zig_mode,*module('root',root/'src/private_probe.zig',['uucode']),*graph,f'-femit-bin={root/"native"}'],check=True)
        snapshot=root/'translated_src';snapshot.mkdir();shutil.copyfile(REPO/'v.mod',snapshot/'v.mod')
        for name in ('vaxis','zigimg','unicode','buildcfg'):
            location=args.v_root/name if (args.v_root/name).exists() else REPO/name
            shutil.copytree(location,snapshot/name)
        shutil.copytree(REPO/'build_assets/unicode',snapshot/'build_assets/unicode')
        shutil.copyfile(PROBE/'probe.v',snapshot/'vaxis/private_run_reference_test.v')
        environment=dict(os.environ,VEXE=str(args.v.resolve()),V_C_ERROR_BUG_REPORT_DISABLED='1',WITTY_TERMINAL_PRIVATE_CORPUS='')
        subprocess.run([str(args.v.resolve()),*(['-prod'] if args.v_prod else []),'-keepc','-path',f'{snapshot}|{REPO}|@vlib|@vmodules','-o',str(root/'translated'),str(snapshot/'vaxis/private_run_reference_test.v')],env=environment,check=True)
        cases=corpus();corpus_path=root/'corpus.txt';corpus_path.write_text('\n'.join(cases)+'\n');outputs=[]
        for name in ('native','translated'):
            result=subprocess.run([str(root/name),str(corpus_path),str(root/'input.bin'),str(root/'reply.bin')],env=dict(environment,WITTY_TERMINAL_PRIVATE_CORPUS=str(corpus_path)),capture_output=True,timeout=120)
            if result.returncode:
                if args.keep:shutil.copytree(root,args.keep,dirs_exist_ok=True)
                raise AssertionError(f'{name} returning corpus failed: {result.stderr.decode(errors="replace")}')
            outputs.append(result.stdout.splitlines())
        if any(len(output)!=len(cases) for output in outputs):raise AssertionError([len(cases)]+[len(x) for x in outputs])
        for i,(case_input,expected,actual) in enumerate(zip(cases,*outputs)):
            if expected!=actual:
                if args.keep:shutil.copytree(root,args.keep,dirs_exist_ok=True)
                raise AssertionError(f'row {i} ({case_input}): source={expected!r}\nV={actual!r}')
        for name,record in traps().items():
            trap_path=root/f'trap-{name}.txt';trap_path.write_text(record+'\n')
            for executable in ('native','translated'):
                result=subprocess.run([str(root/executable),str(trap_path),str(root/'input.bin'),str(root/'reply.bin')],env=dict(environment,WITTY_TERMINAL_PRIVATE_CORPUS=str(trap_path)),capture_output=True,timeout=10)
                text=result.stdout+result.stderr
                expected=b'invalid enum value' if name=='shape' else b'index out of bounds' if name in ('pct_one','pct_two','erase_index') else b'integer overflow'
                if not checked_trap(result,expected):
                    if args.keep:shutil.copytree(root,args.keep,dirs_exist_ok=True)
                    raise AssertionError(f'{executable} trap {name} failed: {result.returncode}, {text.decode(errors="replace")}')
        hang_path=root/'hang-insert.txt';hang_path.write_text(case(b'\x1b[L',row=3)+'\n')
        for executable in ('native','translated'):
            try:
                result=subprocess.run([str(root/executable),str(hang_path),str(root/'input.bin'),str(root/'reply.bin')],env=dict(environment,WITTY_TERMINAL_PRIVATE_CORPUS=str(hang_path)),capture_output=True,timeout=1)
            except subprocess.TimeoutExpired as timeout:
                if timeout.stdout or timeout.stderr:
                    raise AssertionError(f'{executable} inherited insert loop emitted output')
            else:
                raise AssertionError(f'{executable} inherited insert loop returned: {result.returncode}')
        access=root/'src/access_unsupported.zig';shutil.copyfile(PROBE/'access_unsupported.zig',access)
        result=subprocess.run([str(args.zig.resolve()),'build-exe','-target','aarch64-macos.14.0','-lc','-O',args.zig_mode,*module('root',access,['uucode']),*graph,'-fno-emit-bin'],capture_output=True)
        text=(result.stdout+result.stderr).decode(errors='replace')
        if result.returncode!=1 or "'run' is not marked 'pub'" not in text or 'compiler panic' in text.lower():raise AssertionError(f'ordinary private source boundary failed: {text}')
        result=subprocess.run([str(args.v.resolve()),*(['-prod'] if args.v_prod else []),'-path',f'{snapshot}|{REPO}|@vlib|@vmodules','-check',str(PROBE/'access_unsupported.v')],capture_output=True,env=environment)
        text=(result.stdout+result.stderr).decode(errors='replace')
        if result.returncode!=1 or 'Terminal.run' not in text or 'is private' not in text or 'C compilation failed' in text:raise AssertionError(f'ordinary private V boundary failed: {text}')
        if args.keep:shutil.copytree(root,args.keep,dirs_exist_ok=True)
        print(f'Fixture-only private Terminal.run: {len(cases)} records, {len(traps())} isolated checked traps, 1 inherited loop timeout pair, 1 paired ordinary private-access boundary, SHA256 '+hashlib.sha256(b'\n'.join(outputs[0])).hexdigest())

if __name__=='__main__':main()
