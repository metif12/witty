"""Compare default/any scalar pointer values with pinned Zig and an independent writer-state model."""
import argparse
from collections import Counter
import hashlib,itertools,json,os,re,shutil
from pathlib import Path
from verify_format_parser_reference import pins
from verify_simd_reference import ordinary_rejection
from verify_jpeg_contracts_reference import implementation_hashes
from verify_tiff_decode_reference import ProofLog,tree_hash,work_directory,PINNED_SOURCE_SHA256,checked_trap
from verify_writer_address_reference import addresses

EXPECTED_ROWS=9013
EXPECTED_SHA256='288fe58d061b18e0488e22fb2b404378c848d492089525a0c4ab1da29ea8a86e'
EXPECTED_COMPILER_PAIRS=11
EXPECTED_TRAPS=10
EXPECTED_RETURN_CONTROLS=38
EXPECTED_STATE_SHA256='3a93d8a526b3c2315d268a7970ca85406258fead26650350b7a18f951f0e3f67'
MAX=(1<<64)-1
TYPE_NAMES=('u8','u16','u32','u64','usize','i8','i16','i32','i64','isize','f32','f64','bool','anyopaque')
def formats(op):return (b'any',b'?',b'?any') if op in (3,4,5,6) else (b'',b'any')
def spec(family=0,fmt=b'any',kind=0,cap=32,start=0,prefix=0,binding=0,finish=1,value=0x1234,op=0,width=None,precision=None,depth=0,alignment=2,fill=32):
 value=0 if op in (4,6) else max(1,value&MAX) if op in (3,5) else value&MAX
 return '|'.join(map(str,(family,fmt.hex(),kind,cap,start,prefix,binding,finish,value,'','-' if width is None else width,'-' if precision is None else precision,op,depth,alignment,fill)))

class WriteFailed(Exception):
    pass


def modeled(line):
    f = line.split('|')
    family = int(f[0]); fmt = bytes.fromhex(f[1])
    kind, cap, start, prefix, binding, finish, value = map(int, f[2:9])
    text = bytes.fromhex(f[9]); width = None if f[10] == "-" else int(f[10]); precision = None if f[11] == '-' else int(f[11]); stop = int(f[12])
    depth, alignment, fill = map(int, f[13:16]); steps=0; seen="-"
    end = (start if not kind and start < cap else 0) + prefix
    pos = start if kind else 0; mode = kind; calls = 0
    buffer = bytearray((i * 17 + 165) & 255 for i in range(cap))
    buffer[end-prefix:end] = bytes((i * 31 + 7) & 255 for i in range(prefix))
    contents = bytearray((i * 37 + 19) & 255 for i in range(32)) if kind and not binding else bytearray()
    wire = bytearray()

    def state(status):
        return '|'.join((status, f'{pos+end}:{cap-end}:{end}:{end}:{int(bool(kind) and binding != 2)}',
                         buffer.hex(), buffer[:end].hex(), buffer[end:].hex(), seen, contents.hex()))

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

    def write_vectors(vectors):
        nonlocal end
        remaining=list(vectors)
        while remaining:
            joined=b''.join(remaining)
            if len(joined)<=cap-end:copy(joined);return
            if not kind:copy(joined[:cap-end]);raise WriteFailed()
            if not prepare():continue
            segments=([bytes(buffer[:end])] if end else [])+[v for v in remaining if v]
            emitted=segments[0] if kind==1 and not binding else b''.join(segments)
            output(emitted);count=len(emitted)
            if count<end:buffer[:end-count]=buffer[count:end];end-=count;continue
            count-=end;end=0
            while remaining and count>=len(remaining[0]):count-=len(remaining.pop(0))
            if remaining and count:remaining[0]=remaining[0][count:]

    def composition():
        nonlocal seen
        op=int(f[12]);seen=str(0 if op in (4,6) else value)
        if op in (4,6):aligned(b'null',width,alignment,fill);return
        name=TYPE_NAMES[family].encode()
        write_vectors([name,b'@'])
        aligned(format(value,'x').encode(),width,alignment,fill)

    states = [state('ready')]; status = 'ok'
    try: composition()
    except WriteFailed: status = 'WriteFailed'
    states.append(state(status))
    if cap: buffer[0] ^= 0x5a
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
 for tag in range(14):
  for op in ((0,) if tag==13 else (0,3,4)):
   for fmt,cap in itertools.product(formats(op),range(25)):
    add('capacities',spec(tag,fmt,op=op,cap=cap,width=8,fill=95,alignment=tag%3))
  if tag<13:
   for op in (1,2,5,6):
    for fmt,raw,cap in itertools.product(formats(op),(0,1,MAX),(0,8,32)):
     add('aliases',spec(tag,fmt,op=op,value=raw,cap=cap))
  for i,raw in enumerate(addresses()):
   add('address-bits',spec(tag,value=raw,cap=(0,8,32)[i%3],depth=(0,1,MAX)[i%3]))
  for width,precision,alignment,fill in itertools.product((None,0,8,24),(None,0,MAX),range(3),(0,95,255)):
   add('options',spec(tag,width=width,precision=precision,alignment=alignment,fill=fill,depth=MAX))
 for tag,op in ((0,0),(7,0),(12,0),(13,0),(0,3),(7,5),(0,4)):
  for kind,cap,start in itertools.product(range(3),(0,1,8,65),(0,3)):
   begin=start if not kind and start<cap else 0
   for prefix,binding,finish in itertools.product(sorted({0,cap-begin}),(0,) if not kind else (0,1,2),(0,1)):
    add('writer-state',spec(tag,kind=kind,cap=cap,start=start,prefix=prefix,binding=binding,finish=finish,op=op,width=9,precision=MAX))
 return rows

def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()

def compiler_cases():
 rows=[]
 def ok(name,z,v,out):rows.append((name,z,v,out,out))
 ztypes=TYPE_NAMES[:13];vtypes=tuple('int' if t=='i32' else t for t in ztypes)
 ok('padded','try w.printValue("any",.{.width=6,.fill=95,.alignment=.left},@as(*allowzero u8,@ptrFromInt(0x1234)),0);',"w.print_value('any',p.FormatOptions{width:usize(6),fill:`_`,alignment:.left},unsafe {&u8(usize(0x1234))},0)!",b'u8@1234__')
 ok('widths',''.join(f'try w.printValue("any",.{{}},@as(*allowzero align(1) {t},@ptrFromInt(0x1234)),0);' for t in ztypes),
    '\n'.join(f"w.print_value('any',p.FormatOptions{{}},unsafe {{&{t}(usize(0x1234))}},0)!" for t in vtypes),''.join(t+'@1234' for t in ztypes).encode())
 zb='';vb='';out=b''
 for i,t in enumerate(ztypes):
  zb+=f'try w.printValue("any",.{{}},@as(?*{t},@ptrFromInt(0x1000)),0);try w.printValue("*",.{{.width=std.math.maxInt(usize)}},@as(?*{t},@ptrFromInt(0x1000)),0);'
  vb+=f"ptr{i}:=Pointer{i}(unsafe {{&Word{i}(voidptr(usize(0x1000)))}})\nw.print_value('any',p.FormatOptions{{}},?Pointer{i}(ptr{i}),0)!\nw.print_value('*',p.FormatOptions{{width:~usize(0)}},?Pointer{i}(ptr{i}),0)!\n"
  out+=(t+'@1000|*'+t+'@1000').replace('|','').encode()
 ok('optional-aliases',zb,vb,out)
 ok('optional-empty','try w.printValue("?",.{},@as(?*u8,@ptrFromInt(0x1000)),0);try w.printValue("any",.{.width=6,.fill=95},@as(?*u8,null),0);',"w.print_value('?',p.FormatOptions{},?&u8(unsafe {&u8(usize(0x1000))}),0)!\nw.print_value('any',p.FormatOptions{width:usize(6),fill:`_`},?&u8(none),0)!",b'u8@1000__null')
 ok('opaque','try w.printValue("",.{.width=4,.fill=48},@as(*allowzero anyopaque,@ptrFromInt(0x12)),0);',"w.print_value('',p.FormatOptions{width:usize(4),fill:`0`},voidptr(usize(0x12)),0)!",b'anyopaque@0012')
 ok('print','try w.print("a{any}b",.{@as(*allowzero u8,@ptrFromInt(0x1234))});',"w.print('a{any}b',Args{unsafe {&u8(usize(0x1234))}})!",b'au8@1234b')
 for fmt in ('d','s','x','f'):
  vb=f"w.print_value('{fmt}',p.FormatOptions{{}},unsafe {{&u8(usize(0x1000))}},0) or {{require(err.msg()=='unsupported print_value pointer format')\nrequire(backing==before && w.buffered().len==0)\nprint('rejected')\nreturn}}\npanic('unexpected success')"
  rows.append(('invalid-'+fmt,f'try w.printValue("{fmt}",.{{}},@as(*allowzero u8,@ptrFromInt(0x1000)),0);',vb,None,b'rejected'))
 rows.append(('runtime-format','const args=try std.process.argsAlloc(std.heap.page_allocator);try w.printValue(args[0],.{},@as(*allowzero u8,@ptrFromInt(0x1000)),0);',"format:=if os.args.len>0 {'any'} else {''}\nw.print_value(format,p.FormatOptions{},unsafe {&u8(usize(0x1000))},0)!",None,b'u8@1000'))
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
 for typ,cap in itertools.product(range(6),(0,1,2,3,4,5,8,32)):
  data=b'null' if typ==4 else b'anyopaque@12' if typ==2 else b'u8@12'
  trap=typ<4 and cap>=len(data)
  backing=(data[:cap] if cap<len(data) else data+b'_'*(cap-len(data))) if typ==4 else data[:cap]+b'\xa5'*max(0,cap-len(data))
  end=cap if typ==4 else min(cap,len(data))
  expected=f'{end}|{backing.hex()}|{backing[:end].hex()}|{backing[end:].hex()}'.encode()
  for lang in ('native','translated'):
   label=f'trap-{typ}-{cap}-{lang}';path=root/(label+'.state')
   result=proof.run([str(root/('trap-'+lang)),str(path),str(cap),str(typ)],label,env=env,timeout=args.timeout,check=False)
   if trap:
    checked_trap(result,label,'integer overflow')
    messages=[m.group(1) for line in result.stderr.decode().splitlines() if (m:=re.fullmatch(r'(?:thread \d+ |V )?panic:\s*(.*)',line.strip()))]
    assert messages==['integer overflow'],(label,messages)
   else:assert result.returncode==0 and result.stdout==(b'ok\n' if typ==5 and cap>=len(data) else b'WriteFailed\n') and not result.stderr,label
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
    repo = Path(__file__).resolve().parent.parent; probe = repo/'zigimg/reference_probes/writer_pointer_value'
    with work_directory(args.workdir, 'witty-writer-pointer-value-') as root:
        tmp = root/'tmp'; tmp.mkdir(); env = dict(os.environ, TMPDIR=str(tmp), VTMP=str(tmp), VEXE=str(v), V_C_ERROR_BUG_REPORT_DISABLED='1')
        proof = ProofLog(root); shutil.copytree(source, root/'src')
        files = ('main.v', 'reference.zig', 'fixture_shims.h', 'fixture_shims.c', 'portable.v', 'controls.v', 'controls.zig', 'trap.v', 'trap.zig')
        for name in files: shutil.copyfile(probe/name, root/name)
        shared = repo/'zigimg/reference_probes/writer_seek/fixture_shims.h'
        (root/'writer_seek').mkdir(); shutil.copyfile(shared, root/'writer_seek/fixture_shims.h')
        versions = [proof.run([str(exe), 'version'], label, env=env).stdout.decode().strip() for exe, label in ((zig, 'zig-version'), (v, 'v-version'))]
        assert versions[0] == '0.15.2' and re.match(r'^V 0\.5\.2(?: |$)', versions[1])
        impl = implementation_hashes(repo)
        helpers = ('verify_format_parser_reference.py', 'verify_jpeg_contracts_reference.py', 'verify_tiff_decode_reference.py', 'verify_stream_guards_reference.py', 'verify_image_open_reference.py', 'verify_image_tty_reference.py', 'verify_simd_reference.py', 'verify_png_foundation_reference.py', 'verify_writer_address_reference.py')
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
        print(f'{mode}: {len(rows)} modeled pointer records match', flush=True)
        outcomes=compiler_controls(proof,root,repo,zig,v,args,env)
        traps=trap_controls(proof,root,repo,zig,v,args,env)
        assert len(outcomes)==EXPECTED_COMPILER_PAIRS
        assert traps==dict(paired_traps=EXPECTED_TRAPS,returning_controls=EXPECTED_RETURN_CONTROLS,state_sha256=EXPECTED_STATE_SHA256)
        assert tree_hash(source) == tree_hash(root/'src') == PINNED_SOURCE_SHA256
        pins(source, zig)
        assert implementation_hashes(repo) == impl and all(sha(repo/p) == pin for p, pin in retained.items()), 'implementation/proof changed'
        assert all(sha(Path(exe)) == pin for exe, pin in compiler_hashes.items()), 'compiler changed'
        assert all(sha(root/n) == retained[str((probe/n).relative_to(repo))] for n in files) and sha(root/'writer_seek/fixture_shims.h') == sha(shared)
        assert not list(root.glob('*.owned*'))
        (root/'input_sha256.json').write_text(json.dumps({'corpus.txt': sha(path)}, indent=2)+'\n')
        summary = dict(returning_records=len(rows), output_sha256=digest, write_failed=sum(b'~WriteFailed|' in line for line in outputs[0]), groups=dict(Counter(group for group, _ in rows)), compiler_outcomes=outcomes, trap_controls=traps, zig_mode=mode, v_prod=args.v_prod)
        (root/'summary.json').write_text(json.dumps(summary, indent=2)+'\n'); print(json.dumps(summary), flush=True)


if __name__ == '__main__':
    main()
