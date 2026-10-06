"""Compare public RichText rendering with unchanged pinned Vaxis."""
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
import time

PROBE = Path(__file__).resolve().parent / 'reference_probes/vxfw_rich_text'
REPO = PROBE.parents[2]
sys.path.insert(0, str(PROBE.parent / 'widgets_classic'))
from source_build import VAXIS_SHA256, UUCODE_PACKAGE, module, prepare_uucode, tree_hash


def corpus():
    rows = []
    def add(spans, width, height=4, soft=True, align=0, overflow=0, basis=1,
            method=0, minimum=(0, 0), base=3, callback=0, kind='D'):
        fields = [kind, *minimum, width, height, int(soft), align, overflow, basis,
                  method, base, callback]
        for i, text in enumerate(spans):
            fields.extend((text.hex(), i % 3, (i+1) % 3))
        rows.append('|'.join(map(str, fields)))
    # Exhaust every short combination of the two soft breaks and hard LF.
    for length in range(6):
        for word in itertools.product(b'a b\n\t', repeat=length):
            text = bytes(word)
            index = len(rows)
            for width in (0, 1, 2, 4, -1):
                add([text], width, height=(0, 1, 4, -1)[index % 4],
                    soft=index % 2 == 0, align=index % 3, overflow=index % 2,
                    basis=0 if width >= 0 and index % 2 else 1,
                    method=index % 3, minimum=(index % 3, index % 2), callback=index % 2)
    texts = [b'', b'a', b'Hello, world', b'  a   b  ', b'a\tb', b'\n', b'a\n\nb\n',
             b'\r\n', b'a\r\nb', b'\x00\x01\x1b\x7f', b'\x80', b'\xff',
             b'\xe1\x80a', b'\xf0\x9fab', '界x'.encode(), 'e\u0301 x'.encode(),
             '👩\u200d🚀x'.encode(), '🇺🇳 x'.encode(), '\u200b\u0301x'.encode()]
    for text, width, soft, align, method in itertools.product(texts, (0, 1, 2, 7, -1), range(2), range(3), range(3)):
        add([text], width, soft=bool(soft), align=align, method=method,
            basis=0 if width >= 0 and method == 1 else 1, overflow=align % 2,
            minimum=(align, method), callback=soft)
    spans = [(b'Hello, ', b'World'), (b'a ', b'  b\t', b'c'), (b'e', '\u0301x'.encode()),
             (b'a\n', b'b\n', b'c'), (b'abc', b'', b'def'), (b'\r\n', b'a')]
    for text, width, soft, align, method, overflow in itertools.product(spans, (0, 1, 2, 8, -1), range(2), range(3), range(3), range(2)):
        add(text, width, soft=bool(soft), align=align, method=method, overflow=overflow,
            minimum=(3, 2), base=(align+1) % 4, callback=overflow)
    # Source grapheme slices borrow caller bytes; style values were copied.
    for width, soft, align in itertools.product((0, 1, 2, 8, -1), range(2), range(3)):
        add((b'ab', b' cd'), width, soft=bool(soft), align=align, kind='B')
    for soft, width in itertools.product(range(2), (0, 1, 255, -1)):
        add([b'x'*65535], width, height=1, soft=bool(soft))
        add([b'\n'*65535], width, height=1, soft=bool(soft))
    return rows


def strict_trap(result, label, category):
    texts = [(result.stdout + result.stderr).decode(errors='replace')]
    headers = [match.group(1) for text in texts for line in text.splitlines()
               if (match := re.fullmatch(r'(?:thread \d+ )?(?:V )?panic:\s*(.*)', line))]
    if result.returncode == 0 or result.stdout or any(line.lstrip().startswith('UNEXPECTED') for text in texts for line in text.splitlines()) or not any(value.startswith(category) for value in headers):
        raise AssertionError(f'{label}: missing checked {category}: {texts}')


def ordinary_rejection(result, label, required=None):
    diagnostic = (result.stdout + result.stderr).decode(errors='replace')
    bug = re.search(r'(?im)(?:panic:|segmentation fault|compiler bug|compiler error:|C compilation failed|builder error:|internal compiler|report a bug|please report this)', diagnostic)
    if result.returncode != 1 or bug or not re.search(r'(?m)^.*error:.*$', diagnostic) or (required is not None and required not in diagnostic):
        raise AssertionError(f'{label}: not ordinary rejection: {diagnostic}')


def contracts(root, native_prefix, graph, translated_prefix, env):
    source_prelude = 'const std=@import("std");const vaxis=@import("vaxis");const fw=vaxis.vxfw;const a=std.heap.page_allocator;'
    zctx = '.{.arena=a,.min=.{},.max=.{},.cell_size=.{}}'
    vctx = 'fw.DrawContext{min:fw.Size{},max:fw.MaxSize{},cell_size:fw.Size{}}'
    zfields = {'ctx':zctx, 'text':'&.{}', 'line':'&.{}'}
    vfields = {'ctx':vctx, 'text':'[]vaxis.Cell{}', 'line':'[]vaxis.Cell{}'}
    items = [('segment_text', 'const value:vaxis.Segment=.{ };_ = value;', 'value := vaxis.CellSegment{};_ = value')]
    for missing in ('width','cells'):
        z='.{'+(' .width=0' if missing=='cells' else ' .cells=&.{}')+'}'
        v='fw.RichWrappedLine{'+('width:0' if missing=='cells' else 'cells:[]vaxis.Cell{}')+'}'
        items.append(('line_'+missing, 'const value:fw.RichText.SoftwrapIterator.Line='+z+';_ = value;', 'value := '+v+';_ = value'))
    items.append(('rich_text', 'const value:fw.RichText=.{ };_ = value;', 'value := fw.RichText{};_ = value'))
    for missing in zfields:
        z='.{.arena=std.heap.ArenaAllocator.init(a),'+','.join('.'+k+'='+value for k,value in zfields.items() if k!=missing)+'}'
        v='fw.RichSoftwrapIterator{'+','.join(k+':'+value for k,value in vfields.items() if k!=missing)+'}'
        items.append(('iterator_'+missing, 'const value:fw.RichText.SoftwrapIterator='+z+';_ = value;', 'value := '+v+';_ = value'))
    def compile_case(name, z, v, source_reject, v_reject):
        zp=root/(name+'.zig'); vp=root/(name+'.v')
        zp.write_text(source_prelude+'pub fn main()void{'+z+'}\n')
        vp.write_text('module main\nimport vaxis\nimport vaxis.vxfw as fw\nfn main(){'+v+'}\n')
        commands = [('native', [*native_prefix,*module('root',zp,['vaxis']),*module('vaxis',root/'src/main.zig',['uucode']),*graph,f'-femit-bin={root/(name+"_native")}'], source_reject),
                    ('V', [*translated_prefix,'-o',str(root/(name+'_v')),str(vp)], v_reject)]
        for language, command, rejected in commands:
            result=subprocess.run(command,env=env,capture_output=True)
            (root/(name+'-'+language+'.stderr')).write_bytes(result.stderr)
            if rejected: ordinary_rejection(result,name+' '+language, "not marked 'pub'" if language=='native' and name.startswith('private_') else 'missing struct field' if language=='native' else None)
            elif result.returncode: raise AssertionError(result.stderr.decode(errors='replace'))
            else:
                result=subprocess.run([str(root/(name+('_native' if language=='native' else '_v')))],env=env,capture_output=True,timeout=10)
                if result.returncode or result.stdout or result.stderr: raise AssertionError(f'{name} {language}: consumer failed {result}')
    for name,z,v in items: compile_case(name,z,v,True,True)
    zall='.{.arena=std.heap.ArenaAllocator.init(a),'+','.join('.'+k+'='+value for k,value in zfields.items())+'}'
    vall='fw.RichSoftwrapIterator{'+','.join(k+':'+value for k,value in vfields.items())+'}'
    complete=[('complete_span','const value:fw.RichText.TextSpan=.{.text="a"};std.debug.assert(value.text.len==1 and value.link.uri.len==0);',"value := fw.TextSpan{text:'a'};assert value.text.len==1 && value.link.uri.len==0"),('complete_line','var cells=[_]vaxis.Cell{.{}};const value:fw.RichText.SoftwrapIterator.Line=.{.width=0,.cells=&cells};cells[0].char.width=7;std.debug.assert(value.width==0 and value.cells[0].char.width==7);','mut cells := [vaxis.Cell{}];value := fw.RichWrappedLine{width:0,cells:cells};cells[0].char_.width=7;assert value.width==0 && value.cells[0].char_.width==7'),
              ('complete_rich','const value:fw.RichText=.{.text=&.{}};std.debug.assert(value.softwrap);','value := fw.RichText{text:[]fw.TextSpan{}};assert value.softwrap'),
              ('complete_iterator','var cells=[_]vaxis.Cell{.{}};const value:fw.RichText.SoftwrapIterator=.{.arena=std.heap.ArenaAllocator.init(a),.ctx='+zctx+',.text=&cells,.line=&cells,.index=~@as(usize,0),.hard_index=~@as(usize,0)};cells[0].char.width=7;std.debug.assert(value.index==~@as(usize,0) and value.hard_index==~@as(usize,0) and value.text[0].char.width==7 and value.line[0].char.width==7);','mut cells := [vaxis.Cell{}];value := fw.RichSoftwrapIterator{ctx:'+vctx+',text:cells,line:cells,index:~usize(0),hard_index:~usize(0)};cells[0].char_.width=7;assert value.index==~usize(0) && value.hard_index==~usize(0) && value.text[0].char_.width==7 && value.line[0].char_.width==7')]
    for name,z,v in complete: compile_case(name,z,v,False,False)
    compile_case('alias_span_omission','const value:fw.RichText.TextSpan=.{ };_ = value;','value := fw.TextSpan{};assert value.text.len==0',True,False)
    compile_case('arena_omission','const value:fw.RichText.SoftwrapIterator=.{'+','.join('.'+k+'='+value for k,value in zfields.items())+'};_ = value;','value := '+vall+';_ = value',True,False)
    methods=[('new','_ = fw.RichText.SoftwrapIterator.init(&.{},'+zctx+') catch unreachable;','_ = fw.RichSoftwrapIterator.new([]fw.TextSpan{},'+vctx+')'),
             ('reset','var value:fw.RichText.SoftwrapIterator='+zall+';value.reset();','mut value := '+vall+';value.reset()'),
             ('next_hard_break','var value:fw.RichText.SoftwrapIterator='+zall+';_ = value.nextHardBreak();','mut value := '+vall+';_ = value.next_hard_break()'),
             ('next','var value:fw.RichText.SoftwrapIterator='+zall+';_ = value.next();','mut value := '+vall+';_ = value.next()')]
    for name,z,v in methods: compile_case('private_'+name,z,v,True,False)
    return len(items),len(complete),len(methods)


def compare(args, root):
    source=args.source.resolve()/'src'
    if tree_hash(source)!=VAXIS_SHA256: raise ValueError('pinned source changed')
    shutil.copytree(source,root/'src')
    graph=prepare_uucode(args.zig.resolve(),root,args.uucode.resolve(),'aarch64-macos.14.0')
    mode='ReleaseSafe' if args.v_prod else 'Debug'
    env=dict(os.environ,VEXE=str(args.v.resolve()),V_C_ERROR_BUG_REPORT_DISABLED='1')
    native_prefix=[str(args.zig.resolve()),'build-exe','-O',mode,'-target','aarch64-macos.14.0','-lc']
    translated_prefix=[str(args.v.resolve()),'-enable-globals',*(['-prod'] if args.v_prod else []),'-path',f'{REPO}|@vlib|@vmodules']
    builds=[('native', [*native_prefix,*module('root',PROBE/'reference.zig',['vaxis']),*module('vaxis',root/'src/main.zig',['uucode']),*graph,f'-femit-bin={root/"native"}']),('translated',[*translated_prefix,'-o',str(root/'translated'),str(PROBE/'main.v')])]
    for name,command in builds:
        print('Building '+name+' '+mode,file=sys.stderr,flush=True)
        (root/(name+'-argv.json')).write_text(json.dumps(command))
        subprocess.run(command,env=env,check=True)
    rows=corpus(); data=root/'cases.txt'; data.write_text('\n'.join(rows)+'\n')
    outputs=[]
    for name,_ in builds:
        print(f'Running {name}: {len(rows)} returning records',file=sys.stderr,flush=True)
        start=time.monotonic()
        try:
            result=subprocess.run([str(root/name),str(data)],env=env,capture_output=True,timeout=args.timeout)
        except subprocess.TimeoutExpired as failure:
            (root/(name+'.stdout')).write_bytes(failure.stdout or b'')
            (root/(name+'.stderr')).write_bytes(failure.stderr or b'')
            raise AssertionError(f'{name}: deadline {args.timeout}s after {len((failure.stdout or b"").splitlines())} complete rows') from failure
        (root/(name+'.stdout')).write_bytes(result.stdout); (root/(name+'.stderr')).write_bytes(result.stderr)
        if result.returncode or result.stderr: raise AssertionError(f'{name}: after {len(result.stdout.splitlines())} rows: '+result.stderr.decode(errors='replace'))
        output=result.stdout.splitlines()
        if len(output)!=len(rows): raise AssertionError(f'{name}: {len(output)} of {len(rows)} rows')
        outputs.append(output)
        print(f'{name} completed in {time.monotonic()-start:.2f}s',file=sys.stderr,flush=True)
    for index,(case,expected,actual) in enumerate(zip(rows,*outputs)):
        if expected!=actual: raise AssertionError(f'row {index} {case}: Source={expected!r}, V={actual!r}')
    traps={'trap_parent':'reached unreachable code','trap_cr0':'integer overflow','trap_cr1':'integer overflow','trap_cr_range':'start index 1 is larger than end index 0','trap_line_width':'integer overflow','trap_col':'integer overflow','trap_rows':'integer overflow','trap_nonadvancing':'integer overflow','trap_area':'integer overflow','trap_char_cast':'integer does not fit in destination type','trap_unicode':'integer overflow'}
    for case,category in traps.items():
        for name,_ in builds:
            result=subprocess.run([str(root/name),case],env=env,capture_output=True,timeout=20)
            (root/(name+'-'+case+'.stderr')).write_bytes(result.stderr)
            strict_trap(result,name+' '+case,category if name=='native' else 'Assertion failed' if case=='trap_parent' else 'index out of bounds' if case=='trap_cr_range' else 'integer cast truncated bits' if case=='trap_char_cast' else category)
    result=subprocess.run([str(root/'native'),'oom'],env=env,capture_output=True,timeout=10)
    expected_allocation=b'0|OutOfMemory\n1|OutOfMemory\n'+b''.join(f'{index}|OK|1,3\n'.encode() for index in range(2,8))
    if result.returncode or result.stderr or result.stdout!=expected_allocation: raise AssertionError('source allocator observations failed')
    (root/'source-allocator.stdout').write_bytes(result.stdout)
    omissions,complete,private=contracts(root,native_prefix,graph,translated_prefix,env)
    digest=hashlib.sha256(b'\n'.join(outputs[0])).hexdigest()
    print(f'RichText: {len(rows)} returning records, {len(traps)} strict traps, {omissions} omission pairs, {complete} complete constructors, {private} Source-private/V-public method adapters, 2 measured alias-required/GC-arena constructor adaptations, 8 Source-only allocation observations; SHA256 {digest}')


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source',type=Path);parser.add_argument('zig',type=Path);parser.add_argument('v',type=Path)
    parser.add_argument('--uucode',type=Path,default=Path.home()/'.cache/zig/p'/UUCODE_PACKAGE)
    parser.add_argument('--v-prod',action='store_true');parser.add_argument('--workdir',type=Path)
    parser.add_argument('--contracts-only',action='store_true',help='rerun constructor/privacy checks in an existing retained build')
    parser.add_argument('--timeout',type=int,default=300)
    args=parser.parse_args();resource.setrlimit(resource.RLIMIT_CORE,(0,0))
    if args.contracts_only:
        if not args.workdir: parser.error('--contracts-only requires --workdir')
        root=args.workdir.resolve()
        if tree_hash(root/'src')!=VAXIS_SHA256: raise ValueError('retained source changed')
        native=json.loads((root/'native-argv.json').read_text())
        translated=json.loads((root/'translated-argv.json').read_text())
        prefix=native[:native.index('--dep')]
        graph=native[next(i for i,value in enumerate(native) if value.startswith('-Mvaxis='))+1:-1]
        vp=translated[:translated.index('-o')]
        env=dict(os.environ,VEXE=str(args.v.resolve()),V_C_ERROR_BUG_REPORT_DISABLED='1')
        counts=contracts(root,prefix,graph,vp,env)
        print(f'RichText constructor extension: {counts[0]} omission pairs, {counts[1]} complete constructors, {counts[2]} Source-private/V-public method adapters, 2 alias-required/GC-arena constructor adaptations')
    elif args.workdir: root=args.workdir.resolve();root.mkdir();compare(args,root)
    else:
        with tempfile.TemporaryDirectory(prefix='witty-rich-text-') as directory:compare(args,Path(directory))


if __name__=='__main__':main()
