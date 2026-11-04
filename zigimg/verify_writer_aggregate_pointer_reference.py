"""Compare record, enum and sum pointer dereferencing with pinned Zig and an independent writer-state model."""
import argparse
from collections import Counter
import hashlib,itertools,json,os,re,shutil
from pathlib import Path
from verify_format_parser_reference import pins
from verify_simd_reference import ordinary_rejection
from verify_jpeg_contracts_reference import implementation_hashes
from verify_tiff_decode_reference import ProofLog,tree_hash,work_directory,PINNED_SOURCE_SHA256,checked_trap
from verify_writer_value_reference import representation

EXPECTED_ROWS=9414
EXPECTED_SHA256='7ea238f94189833e478e5e9ea8586de17736f8564861659ff6011e06bfb0f24e'
EXPECTED_COMPILER_PAIRS=15
EXPECTED_TRAPS=42
EXPECTED_RETURN_CONTROLS=66
EXPECTED_STATE_SHA256='7f8d848793b8eb99cbfd7945a39c4866b83170ad2d071a8b4d05f5de047f8856'
MAX=(1<<64)-1
def formats(op):return (b'any',b'?',b'?any') if op>=3 else (b'',b'any')
def forms(tag):return (0,3,4) if tag in (2,3) else range(7)
def spec(family=0,fmt=b'any',kind=0,cap=64,start=0,prefix=0,binding=0,finish=1,value=7,op=0,width=None,precision=None,depth=1,alignment=2,fill=32):
 return '|'.join(map(str,(family,fmt.hex(),kind,cap,start,prefix,binding,finish,value&MAX,'','-' if width is None else width,'-' if precision is None else precision,op,depth,alignment,fill)))
def captured(tag,raw):
 rec=f'{raw}:{raw&1}'
 inner='B'+str(int(bool(raw&4))) if raw&2 else 'R'+rec
 return (rec,str(255 if raw&1 else 0),inner,'U'+str(raw) if raw&1 else 'S'+inner,'empty',f'N{raw}:{raw&1}')[tag]

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

    def scalar(n,signed=False):
        aligned(representation(8 if signed else 3,n,10,0,width),width,alignment,fill)
    def record(d,fields):
        if d==0:write_all(b'.{ ... }');return
        write_all(b'.{')
        for i,(name,emit) in enumerate(fields):
            write_all(b' .' if i==0 else b', .');write_all(name);write_all(b' = ');emit(d-1)
        write_all(b' }')
    def union(d,tag,emit):
        if d==0:write_all(b'.{ ... }');return
        write_all(b'.{ .');write_all(tag);write_all(b' = ');emit(d-1);write_all(b' }')
    def rec(d):record(d,[(b'value',lambda _:scalar(value,True)),(b'flag',lambda _:aligned(b'true' if value&1 else b'false',width,alignment,fill))])
    def inner(d):
        if value&2:union(d,b'bool',lambda _:aligned(b'true' if value&4 else b'false',width,alignment,fill))
        else:union(d,b'Record',rec)
    def node(d):record(d,[(b'value',lambda _:scalar(value,True)),(b'next',node if value&1 else lambda _:aligned(b'null',width,alignment,fill))])
    def composition():
        nonlocal seen
        op=int(f[12]);seen=captured(family,value)
        if op in (4,6):aligned(b'null',width,alignment,fill);return
        if family==0:rec(depth)
        elif family==1:write_vectors([b'.',b'high' if value&1 else b'zero'])
        elif family==2:inner(depth)
        elif family==3:
            if value&1:union(depth,b'u64',lambda _:scalar(value))
            else:union(depth,b'Sum',inner)
        elif family==4:record(depth,[])
        else:node(depth)

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
 for tag in range(6):
  for op in forms(tag):
   for fmt,raw,depth,cap in itertools.product(formats(op),(0,7,MAX),(0,1,2,3),(0,1,7,32,96)):
    add('pointees-aliases-presence-depth',spec(tag,fmt,value=raw,op=op,depth=depth,cap=cap))
  for i,raw in enumerate((1,2,3,4,5,6,8,127,128,255,256,32767,32768,(1<<31)-1,1<<31,(1<<63)-1,1<<63)):
   add('active-tags-signed-extrema',spec(tag,value=raw,cap=96,depth=3))
  if tag!=1:
   for width,precision,alignment,fill in itertools.product((None,0,8,24),(None,0,MAX),range(3),(0,95,255)):
    add('options',spec(tag,width=width,precision=precision,alignment=alignment,fill=fill,depth=2,cap=96))
 for tag,op in itertools.product(range(6),(0,3,4)):
  for kind,cap,start in itertools.product(range(3),(0,1,8,65),(0,3)):
   begin=start if not kind and start<cap else 0
   for prefix,binding,finish in itertools.product(sorted({0,cap-begin}),(0,) if not kind else (0,1,2),(0,1)):
    add('writer-state',spec(tag,kind=kind,cap=cap,start=start,prefix=prefix,binding=binding,finish=finish,op=op,depth=3))
 return rows

def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()

def compiler_cases():
 rows=[]
 def ok(name,z,v,out):rows.append((name,z,v,out,out))
 rec='const Record=struct {value:i32};const value:Record=.{.value=7};'
 ok('record',rec+'try w.printValue("any",.{},&value,1);',"value:=Record{7}\nw.print_value('any',p.FormatOptions{},&value,1)!",b'.{ .value = 7 }')
 ok('aliases',rec+'try w.printValue("any",.{},@as(?*const Record,&value),1);',"value:=Alias(Record{7})\nptr:=Pointer(&value)\nw.print_value('any',p.FormatOptions{},?Pointer(ptr),1)!",b'.{ .value = 7 }')
 ok('enum','const E=enum {zero,high};const value:E=.high;try w.printValue("any",.{},&value,0);',"value:=Choice.high\nw.print_value('any',p.FormatOptions{},&value,0)!",b'.high')
 ok('sum',rec+'const S=union(enum){Record:Record,bool:bool};const value2:S=.{.bool=true};_ = value;try w.printValue("any",.{},&value2,1);',"value:=Sum(true)\nw.print_value('any',p.FormatOptions{},&value,1)!",b'.{ .bool = true }')
 ok('optional-none',rec+'_ = value;try w.printValue("any",.{.width=6,.fill=95},@as(?*const Record,null),0);',"w.print_value('any',p.FormatOptions{width:usize(6),fill:`_`},?&Record(none),0)!",b'__null')
 ok('custom','const C=struct{value:i32,pub fn format(self:@This(),writer:*std.Io.Writer) !void {try writer.printInt(self.value,10,.lower,.{});}};const value:C=.{.value=9};try w.printValue("f",.{.width=std.math.maxInt(usize)},&value,0);',"value:=Custom{9}\nw.print_value('f',p.FormatOptions{width:~usize(0)},&value,0)!",b'9')
 custom_source=next(row[1] for row in rows if row[0]=='custom').replace('printValue("f"','printValue("?f"').replace(',&value,0);',',@as(?*const C,&value),0);')
 ok('optional-custom',custom_source,"value:=Custom{9}\nw.print_value('?f',p.FormatOptions{width:~usize(0)},?&Custom(&value),0)!",b'9')
 ok('print',rec+'try w.print("a{any}b",.{&value});',"value:=Record{7}\nw.print('a{any}b',Args{&value})!",b'a.{ .value = 7 }b')
 for fmt in ('d','t','s','x'):
  rows.append(('invalid-'+fmt,rec+f'try w.printValue("{fmt}",.{{}},&value,0);',f"value:=Record{{7}}\nw.print_value('{fmt}',p.FormatOptions{{}},&value,0) or {{require(err.msg()=='unsupported print_value aggregate-pointer format')\nrequire(w.buffered().len==0 && backing==before)\nprint('rejected')\nreturn}}\npanic('unexpected success')",None,b'rejected'))
 rows.append(('runtime-format',rec+'const args=try std.process.argsAlloc(std.heap.page_allocator);try w.printValue(args[0],.{},&value,1);',"value:=Record{7}\nformat:=if os.args.len>0 {'any'} else {''}\nw.print_value(format,p.FormatOptions{},&value,1)!",None,b'.{ .value = 7 }'))
 for name,zvalue,vvalue in (('address','&value','&value'),('optional-address','@as(?*const Record,&value)','?&Record(&value)')):
  expected_prefix='@typeName(@TypeOf(&value))' if name=='optional-address' else '@typeName(Record)'
  rows.append((name,rec+f'try w.printValue("*",.{{}},{zvalue},0);if(!std.mem.startsWith(u8,w.buffered(),{expected_prefix}++"@")) return error.BadAddress;w.end=0;',f"value:=Record{{7}}\nw.print_value('*',p.FormatOptions{{}},{vvalue},0) or {{require(err.msg()=='unsupported print_value aggregate-pointer format')\nrequire(w.buffered().len==0 && backing==before)\nprint('rejected')\nreturn}}\npanic('unexpected success')",b'',b'rejected'))
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
 for typ,cap,depth in itertools.product(range(6),(0,1,2,3,7,32),(0,1,2)):
  if typ in (0,1):data=b'';trap=True
  elif typ==2:data=b'null';trap=False
  elif depth==0:data=b'.{ ... }';trap=False
  else:
   data={3:b'.{ .choice = ',4:b'.{ .Choice = ',5:b'.{ .value = +7'}[typ];trap=cap>=len(data)
  category='integer overflow' if typ==5 else 'reached unreachable code'
  end=min(cap,len(data));backing=data[:end]+b'\xa5'*(cap-end)
  expected=f'{end}|{backing.hex()}|{backing[:end].hex()}|{backing[end:].hex()}'.encode()
  for lang in ('native','translated'):
   label=f'trap-{typ}-{cap}-{depth}-{lang}';path=root/(label+'.state')
   result=proof.run([str(root/('trap-'+lang)),str(path),str(cap),str(typ),str(depth)],label,env=env,timeout=args.timeout,check=False)
   if trap:
    checked_trap(result,label,category)
    messages=[m.group(1) for line in result.stderr.decode().splitlines() if (m:=re.fullmatch(r'(?:thread \d+ |V )?panic:\s*(.*)',line.strip()))]
    assert messages==[category],(label,messages)
   else:assert result.returncode==0 and result.stdout==(b'ok\n' if cap>=len(data) else b'WriteFailed\n') and not result.stderr,label
   assert path.read_bytes()==expected,(label,path.read_bytes(),expected)
  traps+=trap;returns+=not trap;records.append(f'{typ}:{cap}:{depth}:'.encode()+expected)

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
    repo = Path(__file__).resolve().parent.parent; probe = repo/'zigimg/reference_probes/writer_aggregate_pointer'
    with work_directory(args.workdir, 'witty-writer-aggregate-pointer-') as root:
        tmp = root/'tmp'; tmp.mkdir(); env = dict(os.environ, TMPDIR=str(tmp), VTMP=str(tmp), VEXE=str(v), V_C_ERROR_BUG_REPORT_DISABLED='1')
        proof = ProofLog(root); shutil.copytree(source, root/'src')
        files = ('main.v', 'reference.zig', 'fixture_shims.h', 'fixture_shims.c', 'portable.v', 'controls.v', 'controls.zig', 'trap.v', 'trap.zig')
        for name in files: shutil.copyfile(probe/name, root/name)
        shared = repo/'zigimg/reference_probes/writer_seek/fixture_shims.h'
        (root/'writer_seek').mkdir(); shutil.copyfile(shared, root/'writer_seek/fixture_shims.h')
        versions = [proof.run([str(exe), 'version'], label, env=env).stdout.decode().strip() for exe, label in ((zig, 'zig-version'), (v, 'v-version'))]
        assert versions[0] == '0.15.2' and re.match(r'^V 0\.5\.2(?: |$)', versions[1])
        impl = implementation_hashes(repo)
        helpers = ('verify_format_parser_reference.py', 'verify_jpeg_contracts_reference.py', 'verify_tiff_decode_reference.py', 'verify_stream_guards_reference.py', 'verify_image_open_reference.py', 'verify_image_tty_reference.py', 'verify_simd_reference.py', 'verify_png_foundation_reference.py', 'verify_writer_value_reference.py')
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
        print(f'{mode}: {len(rows)} modeled aggregate pointer records match', flush=True)
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
