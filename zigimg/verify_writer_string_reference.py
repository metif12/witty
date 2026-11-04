"""Compare native V strings mapped to byte slices with pinned Zig and an independent writer-state model."""
import argparse
from collections import Counter
import base64,hashlib,itertools,json,os,re,shutil
from pathlib import Path
from verify_format_parser_reference import pins
from verify_writer_value_slice_reference import VALUE_LIBRARIES,value_library_hashes
from verify_simd_reference import ordinary_rejection
from verify_jpeg_contracts_reference import implementation_hashes
from verify_tiff_decode_reference import ProofLog,tree_hash,work_directory,PINNED_SOURCE_SHA256,checked_trap


EXPECTED_ROWS=15609
EXPECTED_SHA256='516b19e86376b7790895e2124a490ffa40c945b9c86599212081d5a33abd2cab'
EXPECTED_COMPILER_PAIRS=12
EXPECTED_TRAPS=33
EXPECTED_RETURN_CONTROLS=33
EXPECTED_STATE_SHA256='1c8ded5ed05e8f1c0284d4ae7e45274ca6955df39f543f6c5a9aaadd5a71cc26'
MAX=(1<<64)-1
def formats(form):
 if form in (2,3,4,5):return (b'any',b'?any',b'?s',b'?x',b'?X',b'?b64')
 if form==6:return (b'',b'any')
 if form>=7:return (b'any',)
 return (b's',b'x',b'X',b'b64',b'any')

def spec(family=0,fmt=b's',kind=0,cap=64,start=0,prefix=0,binding=0,finish=1,text=b'A',width=None,precision=None,depth=1,alignment=2,fill=32):
 return '|'.join(map(str,(family,fmt.hex(),kind,cap,start,prefix,binding,finish,0,text.hex(),'-' if width is None else width,'-' if precision is None else precision,0,depth,alignment,fill)))

class WriteFailed(Exception):
    pass


def modeled(line):
    f = line.split('|')
    family = int(f[0]); fmt = bytes.fromhex(f[1])
    kind, cap, start, prefix, binding, finish, value = map(int, f[2:9])
    text = bytearray.fromhex(f[9]); width = None if f[10] == "-" else int(f[10]); precision = None if f[11] == '-' else int(f[11]); stop = int(f[12])
    depth, alignment, fill = map(int, f[13:16]); steps=0; seen="-"
    end = (start if not kind and start < cap else 0) + prefix
    pos = start if kind else 0; mode = kind; calls = 0
    buffer = bytearray((i * 17 + 165) & 255 for i in range(cap))
    buffer[end-prefix:end] = bytes((i * 31 + 7) & 255 for i in range(prefix))
    contents = bytearray((i * 37 + 19) & 255 for i in range(32)) if kind and not binding else bytearray()
    wire = bytearray()

    def state(status):
        return '|'.join((status, f'{pos+end}:{cap-end}:{end}:{end}:{int(bool(kind) and binding != 2)}',
                         buffer.hex(), buffer[:end].hex(), buffer[end:].hex(), f'{len(text)}:1:{text.hex()}', contents.hex()))

    def prepare():
        nonlocal mode, pos
        if mode < 0 or binding == 2: raise WriteFailed()
        if binding == 1 and mode == 1:
            mode = 2
            if pos: pos = 0; mode = -1; raise WriteFailed()
            return False
        return True

    def output(data):
        nonlocal pos
        assert pos + len(data) <= 4096
        if binding == 1: wire.extend(data)
        else:
            if len(contents) < pos + len(data): contents.extend(bytes(pos+len(data)-len(contents)))
            contents[pos:pos+len(data)] = data
        pos += len(data)

    def copy(data):
        nonlocal end
        buffer[end:end+len(data)] = data; end += len(data)

    def write_all(data):
        nonlocal end
        index = 0
        while index < len(data):
            left = data[index:]
            if len(left) <= cap-end: copy(left); return
            if not kind: copy(left[:cap-end]); raise WriteFailed()
            if not prepare(): continue
            pending = bytes(buffer[:end])
            emitted = (pending if pending else left) if kind == 1 and not binding else pending + left
            output(emitted); n = len(emitted)
            if n < end: buffer[:end-n] = buffer[n:end]; end -= n
            else: index += n-end; end = 0

    def splat(n, fill):
        nonlocal end
        pattern = bytes([fill])
        while n:
            if n <= cap-end: copy(pattern*n); return
            if not kind: copy(pattern*(cap-end)); raise WriteFailed()
            segments = [bytes(buffer[:end])] if end else []
            if n == 1: segments.append(pattern)
            else:
                capacity = max(64, cap-end); k = min(n, capacity); scratch = pattern*k
                if cap-end >= 64: buffer[end:end+k] = scratch
                segments.append(scratch); remaining = n-k
                while remaining > capacity and len(segments) < 16: segments.append(scratch); remaining -= capacity
                if remaining and len(segments) < 16: segments.append(pattern*remaining)
            if not prepare(): continue
            emitted = segments[0] if kind == 1 and not binding else b''.join(segments)
            output(emitted); count = len(emitted)
            if count < end: buffer[:end-count] = buffer[count:end]; end -= count
            else: n -= count-end; end = 0

    def aligned(data, w, alignment, fill):
        padding = max(0, (len(data) if w is None else w) - len(data))
        if alignment == 0: write_all(data); splat(padding, fill)
        elif alignment == 1: splat(padding//2, fill); write_all(data); splat((padding+1)//2, fill)
        else: splat(padding, fill); write_all(data)

    def byte_string(data,fmt,d):
        if fmt==b's':aligned(bytes(data),width,alignment,fill)
        elif fmt in (b'x',b'X'):
            encoded=bytes(data).hex()
            if fmt==b'X':encoded=encoded.upper()
            for char in encoded:write_all(char.encode())
        elif fmt==b'b64':
            for i in range(0,len(data),3):write_all(base64.b64encode(bytes(data[i:i+3])))
        else:
            assert fmt==b'any'
            if d==0:write_all(b'{ ... }');return
            write_all(b'{ ')
            for i,n in enumerate(data):
                aligned(str(n).encode(),width,alignment,fill)
                if i+1<len(data):write_all(b', ')
            write_all(b' }')

    def composition():
        if family in (3,5):aligned(b'null',width,alignment,fill);return
        if family<6:byte_string(text,fmt.removeprefix(b'?'),depth);return
        if depth==0:write_all(b'.{ ... }' if family==6 else b'{ ... }');return
        if family==6:
            write_all(b'.{');write_all(b' .');write_all(b'text');write_all(b' = ')
            byte_string(text,b'any',depth-1);write_all(b' }')
        else:
            write_all(b'{ ');byte_string(text,b'any',depth-1);write_all(b', ')
            byte_string(b'',b'any',depth-1);write_all(b' }')

    states = [state('ready')]; status = 'ok'
    try: composition()
    except WriteFailed: status = 'WriteFailed'
    states.append(state(status))
    if cap: buffer[0] ^= 0x5a
    if text:text[0]^=0x33
    states.append(state('caller')); status = 'skip'
    if finish:
        status = 'ok'
        if kind and end:
            try:
                if not prepare(): assert prepare()
                output(bytes(buffer[:end])); end = 0
            except WriteFailed: status = 'WriteFailed'
    states.append(state(status))
    return ('~'.join(states) + '~' + ('-1:'+wire.hex() if kind and binding == 1 else '-3:')).encode()


def corpus():
 rows=[];seen=set()
 def add(group,line):
  if line not in seen:seen.add(line);rows.append((group,line))
 samples=(b'',b'A',b'\x00',b'\xff',b'\x00\xffA',b'ABCD',bytes(range(8)),bytes(range(32)),"Ω🙂".encode())
 for form in range(9):
  for fmt,data,depth,cap in itertools.product(formats(form),samples,(0,1,2,MAX),(0,1,2,3,7,16,64)):
   add('carriers-binary-depth-capacity',spec(form,fmt,text=data,depth=depth,cap=cap))
  for fmt in formats(form):
   if fmt in (b'x',b'X',b'b64',b'?x',b'?X',b'?b64') and form not in (3,5):continue
   for width,precision,alignment,fill in itertools.product((None,0,8,24),(None,0,MAX),range(3),(0,95,255)):
    add('options',spec(form,fmt,text=b'\x00\xffA',width=width,precision=precision,alignment=alignment,fill=fill,depth=MAX))
 for data,fmt in itertools.product((bytes([i]) for i in range(256)),(b's',b'x',b'X',b'b64',b'any')):
  add('all-byte-values',spec(text=data,fmt=fmt,cap=64))
 for form,fmt in ((0,b's'),(1,b'x'),(0,b'b64'),(0,b'any'),(2,b'?s'),(3,b'?x'),(4,b'?b64'),(6,b'any'),(7,b'any'),(8,b'any')):
  for kind,cap,start in itertools.product(range(3),(0,1,8,65),(0,3)):
   begin=start if not kind and start<cap else 0
   for prefix,binding,finish in itertools.product(sorted({0,cap-begin}),(0,) if not kind else (0,1,2),(0,1)):
    add('writer-state',spec(form,fmt,text=b'\x00\xffABC',kind=kind,cap=cap,start=start,prefix=prefix,binding=binding,finish=finish,depth=3))
 return rows

def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()

def compiler_cases():
 rows=[]
 def ok(name,z,v,out):rows.append((name,z,v,out,out))
 ok('bytes','const text:[]const u8=&.{0,255,65};try w.printValue("s",.{.width=5,.fill=95},text,0);try w.printValue("X",.{},text,0);try w.printValue("b64",.{},text,0);',"text:=[u8(0),255,65].bytestr()\nw.print_value('s',p.FormatOptions{width:usize(5),fill:`_`},Text(text),0)!\nw.print_value('X',p.FormatOptions{},text,0)!\nw.print_value('b64',p.FormatOptions{},text,0)!",b'__\x00\xffA00FF41AP9B')
 ok('optional-alias','const text:?[]const u8="AB";try w.printValue("?x",.{},text,0);try w.printValue("?s",.{.width=6,.fill=95},@as(?[]const u8,null),0);',"w.print_value('?x',p.FormatOptions{},?Text(Text('AB')),0)!\nw.print_value('?s',p.FormatOptions{width:usize(6),fill:`_`},?Text(none),0)!",b'4142__null')
 ok('record-array','const Record=struct {text:[]const u8};try w.printValue("any",.{},Record{.text="A"},2);try w.printValue("any",.{},[2][]const u8{"A",""},2);',"w.print_value('any',p.FormatOptions{},Record{'A'},2)!\nw.print_value('any',p.FormatOptions{},['A','']!,2)!",b'.{ .text = { 65 } }{ { 65 }, {  } }')
 ok('print','try w.print("{[text]s}/{[text]x}",.{.text=@as([]const u8,"AB")});',"w.print('{[text]s}/{[text]x}',Record{'AB'})!",b'AB/4142')
 z='';v=''
 for i,text in enumerate(('','address')):
  z+=f'const text{i}:[]const u8="{text}";try w.printValue("*",.{{.width=std.math.maxInt(usize),.precision=std.math.maxInt(usize)}},text{i},0);if(!std.mem.eql(u8,w.buffered(),try std.fmt.allocPrint(std.heap.page_allocator,"u8@{{x}}",.{{@intFromPtr(text{i}.ptr)}}))) return error.BadAddress;w.end=0;'
  v+=f"text{i}:='{text}'\nw.print_value('*',p.FormatOptions{{width:~usize(0),precision:~usize(0)}},Text(text{i}),0)!\nrequire(w.buffered().bytestr()=='u8@${{usize(text{i}.str):x}}')\nw.seek_to(0)!\n"
 ok('borrowed-address',z,v,b'')
 ok('optional-address','const text:[]const u8="address";try w.printValue("?*",.{.width=std.math.maxInt(usize)},@as(?[]const u8,text),0);if(!std.mem.eql(u8,w.buffered(),try std.fmt.allocPrint(std.heap.page_allocator,"u8@{x}",.{@intFromPtr(text.ptr)}))) return error.BadAddress;w.end=0;',"text:='address'\nw.print_value('?*',p.FormatOptions{width:~usize(0)},?Text(Text(text)),0)!\nrequire(w.buffered().bytestr()=='u8@${usize(text.str):x}')\nw.seek_to(0)!",b'')
 for name,fmt in (('empty',''),('decimal','d'),('tag','t'),('custom','f')):
  rows.append(('invalid-'+name,f'try w.printValue("{fmt}",.{{}},@as([]const u8,"A"),0);',f"w.print_value('{fmt}',p.FormatOptions{{}},'A',0) or {{require(err.msg()=='unsupported print_value byte-slice format')\nrequire(w.buffered().len==0 && backing==before)\nprint('rejected')\nreturn}}\npanic('unexpected success')",None,b'rejected'))
 rows.append(('optional-default','try w.printValue("?",.{},@as(?[]const u8,"A"),0);',"w.print_value('?',p.FormatOptions{},?string('A'),0) or {require(err.msg()=='unsupported print_value byte-slice format')\nrequire(w.buffered().len==0 && backing==before)\nprint('rejected')\nreturn}\npanic('unexpected success')",None,b'rejected'))
 rows.append(('runtime-format','const args=try std.process.argsAlloc(std.heap.page_allocator);try w.printValue(args[0],.{},@as([]const u8,"AB"),0);',"format:=if os.args.len>0 {'s'} else {'any'}\nw.print_value(format,p.FormatOptions{},'AB',0)!",None,b'AB'))
 return rows

def compiler_controls(proof,root,repo,zig,v,args,env):
 outcomes={};inputs={}
 for name,zb,vb,zo,vo in compiler_cases():
  outcomes[name]={}
  for lang,ext,body,expected in (('native','.zig',zb,zo),('translated','.v',vb,vo)):
   if lang=='native':body+='var out=std.fs.File.stdout().writer(&.{});try out.interface.writeAll(w.buffered());'
   elif not body.endswith("panic('unexpected success')"):body+='\nprint(w.buffered().bytestr())'
   path=root/(name+ext);path.write_text((root/('controls'+ext)).read_text().replace('// BODY',body));inputs[path.name]=sha(path);binary=root/(name+'-'+lang)
   command=([str(zig),'build-exe','-target',args.target,'-lc','-O','ReleaseSafe' if args.v_prod else 'Debug','--global-cache-dir',str(root.parent/'zig-global'),'--cache-dir',str(root/'zig-cache'),'-femit-bin='+str(binary),str(path)] if lang=='native' else [str(v),'-enable-globals',*(['-prod'] if args.v_prod else []),'-path',f'{repo}|@vlib|@vmodules','-o',str(binary),str(path)])
   label=name+'-'+lang;result=proof.run(command,label+'-compile',env=env,timeout=args.timeout,check=False)
   if expected is None:ordinary_rejection(result,label);outcomes[name][lang]='reject'
   else:
    assert result.returncode==0,(name,lang,result.stdout,result.stderr)
    result=proof.run([str(binary)],label+'-run',env=env,timeout=args.timeout)
    assert result.stdout==expected and not result.stderr,(name,lang,result.stdout,result.stderr,expected)
    outcomes[name][lang]='return:'+expected.hex()
 assert all(sha(root/p)==pin for p,pin in inputs.items())
 (root/'compiler-inputs.json').write_text(json.dumps(inputs,indent=2)+'\n');return outcomes

def trap_controls(proof,root,repo,zig,v,args,env):
 proof.run([str(zig),'build-exe','-target',args.target,'-lc','-O','ReleaseSafe' if args.v_prod else 'Debug','--global-cache-dir',str(root.parent/'zig-global'),'--cache-dir',str(root/'zig-cache'),'-femit-bin='+str(root/'trap-native'),str(root/'trap.zig')],'trap-build-source',env=env,timeout=args.timeout)
 proof.run([str(v),'-enable-globals',*(['-prod'] if args.v_prod else []),'-path',f'{repo}|@vlib|@vmodules','-o',str(root/'trap-translated'),str(root/'trap.v')],'trap-build-v',env=env,timeout=args.timeout)
 records=[];traps=0;returns=0
 for typ,cap in itertools.product(range(11),(0,1,2,3,7,32)):
  if typ<5:data=b'';trap=True;category='reached unreachable code'
  else:
   data={5:b'null',6:b'{ 65',7:b'.{ .text = { 65',8:b'A',9:b'.{ .text = { ... } }',10:b'{ ... }'}[typ]
   trap=typ in (6,7) and cap>=len(data);category='integer overflow'
  if typ==8 and cap>=1:end=cap;backing=b'A'+b'_'*(cap-1)
  else:end=min(cap,len(data));backing=data[:end]+b'\xa5'*(cap-end)
  expected=f'{end}|{backing.hex()}|{backing[:end].hex()}|{backing[end:].hex()}'.encode()
  status=b'ok' if typ in (5,9,10) and cap>=len(data) else b'WriteFailed'
  for lang in ('native','translated'):
   label=f'trap-{typ}-{cap}-{lang}';path=root/(label+'.state')
   result=proof.run([str(root/('trap-'+lang)),str(path),str(cap),str(typ)],label,env=env,timeout=args.timeout,check=False)
   if trap:
    checked_trap(result,label,category)
    messages=[m.group(1) for line in result.stderr.decode().splitlines() if (m:=re.fullmatch(r'(?:thread \d+ |V )?panic:\s*(.*)',line.strip()))]
    assert messages==[category],(label,messages)
   else:assert result.returncode==0 and result.stdout==status+b'\n' and not result.stderr,label
   assert path.read_bytes()==expected,(label,path.read_bytes(),expected)
  traps+=trap;returns+=not trap;records.append(f'{typ}:{cap}:'.encode()+expected)

 return dict(paired_traps=traps,returning_controls=returns,state_sha256=hashlib.sha256(b'\n'.join(records)).hexdigest())

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path); parser.add_argument('zig', type=Path); parser.add_argument('v', type=Path)
    parser.add_argument('--target', default='aarch64-macos.14.0'); parser.add_argument('--v-prod', action='store_true')
    parser.add_argument('--workdir', type=Path); parser.add_argument('--timeout', type=int, default=600)
    args = parser.parse_args()
    if args.timeout <= 0: parser.error('--timeout must be positive')
    source = args.source.resolve()/'src'; zig = args.zig.resolve(); v = args.v.resolve()
    pins(source, zig)
    assert value_library_hashes(zig)==VALUE_LIBRARIES
    repo = Path(__file__).resolve().parent.parent; probe = repo/'zigimg/reference_probes/writer_string'
    with work_directory(args.workdir, 'witty-writer-string-') as root:
        tmp = root/'tmp'; tmp.mkdir(); env = dict(os.environ, TMPDIR=str(tmp), VTMP=str(tmp), VEXE=str(v), V_C_ERROR_BUG_REPORT_DISABLED='1')
        proof = ProofLog(root); shutil.copytree(source, root/'src')
        files = ('main.v', 'reference.zig', 'fixture_shims.h', 'fixture_shims.c', 'portable.v', 'controls.v', 'controls.zig', 'trap.v', 'trap.zig')
        for name in files: shutil.copyfile(probe/name, root/name)
        shared = repo/'zigimg/reference_probes/writer_seek/fixture_shims.h'
        (root/'writer_seek').mkdir(); shutil.copyfile(shared, root/'writer_seek/fixture_shims.h')
        versions = [proof.run([str(exe), 'version'], label, env=env).stdout.decode().strip() for exe, label in ((zig, 'zig-version'), (v, 'v-version'))]
        assert versions[0] == '0.15.2' and re.match(r'^V 0\.5\.2(?: |$)', versions[1])
        impl = implementation_hashes(repo)
        helpers = ('verify_format_parser_reference.py', 'verify_jpeg_contracts_reference.py', 'verify_tiff_decode_reference.py', 'verify_stream_guards_reference.py', 'verify_image_open_reference.py', 'verify_image_tty_reference.py', 'verify_simd_reference.py', 'verify_png_foundation_reference.py','verify_writer_value_slice_reference.py','verify_writer_float_reference.py','verify_float_render_reference.py','verify_float_decimal_reference.py')
        retained = {str(p.relative_to(repo)): sha(p) for p in [Path(__file__), shared, *(probe/n for n in files), *(repo/'zigimg'/n for n in helpers)]}
        compiler_hashes = {str(exe): sha(exe) for exe in (zig, v)}
        provenance = dict(source_sha256=PINNED_SOURCE_SHA256, implementation_sha256=impl, files=retained, versions=versions, compiler_sha256=compiler_hashes, target=args.target, v_prod=args.v_prod)
        (root/'provenance.json').write_text(json.dumps(provenance, indent=2)+'\n')
        mode = 'ReleaseSafe' if args.v_prod else 'Debug'
        proof.run([str(zig), 'build-exe', '-target', args.target, '-lc', '-I', str(root), '-O', mode, '--global-cache-dir', str(root.parent/'zig-global'), '--cache-dir', str(root/'zig-cache'), '-femit-bin='+str(root/'native'), str(root/'reference.zig'), str(root/'fixture_shims.c')], 'build-source', env=env, timeout=args.timeout)
        proof.run([str(v), '-enable-globals', *(['-prod'] if args.v_prod else []), '-path', f'{repo}|@vlib|@vmodules', '-o', str(root/'translated'), str(root/'main.v')], 'build-v', env=env, timeout=args.timeout)
        rows = corpus(); path = root/'corpus.txt'; path.write_text('\n'.join(line for _, line in rows)+'\n')
        outputs = []
        for exe in ('native', 'translated'):
            result = proof.run([str(root/exe), str(path)], 'returning-'+exe, env=env, timeout=args.timeout)
            assert not result.stderr and len(result.stdout.splitlines()) == len(rows), 'invalid returning output'
            outputs.append(result.stdout.splitlines())
        for i, ((group, data), native, translated) in enumerate(zip(rows, *outputs)):
            assert native == translated, f'{i}/{group}: native/V print state differs'
            assert native == modeled(data), f'{i}/{group}: independent print/write model differs'
        digest = hashlib.sha256(b'\n'.join(outputs[0])).hexdigest()
        assert len(rows) == EXPECTED_ROWS and digest == EXPECTED_SHA256, 'returning golden changed'
        print(f'{mode}: {len(rows)} modeled string records match', flush=True)
        outcomes=compiler_controls(proof,root,repo,zig,v,args,env)
        traps=trap_controls(proof,root,repo,zig,v,args,env)
        assert len(outcomes)==EXPECTED_COMPILER_PAIRS
        assert traps==dict(paired_traps=EXPECTED_TRAPS,returning_controls=EXPECTED_RETURN_CONTROLS,state_sha256=EXPECTED_STATE_SHA256)
        assert tree_hash(source) == tree_hash(root/'src') == PINNED_SOURCE_SHA256
        pins(source, zig)
        assert value_library_hashes(zig)==VALUE_LIBRARIES
        assert implementation_hashes(repo) == impl and all(sha(repo/p) == pin for p, pin in retained.items()), 'implementation/proof changed'
        assert all(sha(Path(exe)) == pin for exe, pin in compiler_hashes.items()), 'compiler changed'
        assert all(sha(root/n) == retained[str((probe/n).relative_to(repo))] for n in files) and sha(root/'writer_seek/fixture_shims.h') == sha(shared)
        assert not list(root.glob('*.owned*'))
        (root/'input_sha256.json').write_text(json.dumps({'corpus.txt': sha(path)}, indent=2)+'\n')
        summary = dict(returning_records=len(rows), output_sha256=digest, write_failed=sum(b'~WriteFailed|' in line for line in outputs[0]), groups=dict(Counter(group for group, _ in rows)), compiler_outcomes=outcomes, trap_controls=traps, zig_mode=mode, v_prod=args.v_prod)
        (root/'summary.json').write_text(json.dumps(summary, indent=2)+'\n'); print(json.dumps(summary), flush=True)


if __name__ == '__main__':
    main()
