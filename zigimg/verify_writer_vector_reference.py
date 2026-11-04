"""Compare fixed-array lane adaptation of public Writer.printVector with pinned Zig."""
import argparse
from collections import Counter
from functools import lru_cache
import hashlib,itertools,json,os,re,shutil
from pathlib import Path
from verify_format_parser_reference import pins
from verify_simd_reference import ordinary_rejection
from verify_jpeg_contracts_reference import implementation_hashes
from verify_tiff_decode_reference import ProofLog,tree_hash,work_directory,PINNED_SOURCE_SHA256,checked_trap
from verify_writer_value_reference import representation
from verify_float_render_reference import modeled as render_model,spec as render_spec,library_hashes as render_library_hashes,LIBRARIES as RENDER_LIBRARIES,verify_tables
from verify_writer_float_hex_reference import float_pieces,float_library_hashes,FLOAT_LIBRARIES

EXPECTED_ROWS=7048
EXPECTED_SHA256='0dd0cd3406c6ea2e24f15e0e02b6810ee36eb91ac833da51ca5b71799154f32b'
EXPECTED_COMPILER_PAIRS=15
EXPECTED_TRAPS=8
EXPECTED_RETURN_CONTROLS=16
EXPECTED_STATE_SHA256='9d9c88403f6d22fc485dc081642ec4acd0e418a1b1b538314ea608353ec98da3'
MAX=(1<<64)-1
FORMATS={i:(b'',b'any',b'd',b'b',b'o',b'x',b'X') for i in (0,1,5,6)}
FORMATS[2]=(b'',b'any');FORMATS[3]=FORMATS[4]=(b'',b'any',b'd',b'e',b'E',b'x',b'X')
def spec(family=0,fmt=b'd',kind=0,cap=64,start=0,prefix=0,binding=0,finish=1,value=17,length=3,width=None,precision=None,depth=1,alignment=2,fill=32):
 return '|'.join(map(str,(family,fmt.hex(),kind,cap,start,prefix,binding,finish,value&MAX,'','-' if width is None else width,'-' if precision is None else precision,length,depth,alignment,fill)))
def lanes(typ,raw,length):
 if typ in (3,4):
  bits=32 if typ==3 else 64;mask=(1<<bits)-1
  return [0 if i%3==2 else (raw^((1<<(bits-1)) if i%3 else 0))&mask for i in range(length)]
 if typ==2:return [(raw>>i)&1 for i in range(length)]
 return [(raw+i*0x9e3779b97f4a7c15)&(255 if typ==1 else MAX) for i in range(length)]
@lru_cache(maxsize=4096)
def float_text(raw,bits,fmt,precision):
 tag=0 if bits==32 else 1
 if fmt in (b'x',b'X'):
  return b''.join(b'0'*p[1] if isinstance(p,tuple) else p for p in float_pieces(raw,tag,int(fmt==b'X'),precision))
 result,trap=render_model(render_spec(api=int(fmt not in (b'e',b'E')),length=347,offset=0,guard=0,raw=raw,tag=tag,precision=precision))
 assert trap is None
 fields=result.decode().split('~')[1].split('|')
 return b'(float)' if fields[0]=='BufferTooSmall' else bytes.fromhex(fields[3].split(':')[2])

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

    def composition():
        nonlocal seen
        lane_values=lanes(family,value,int(f[12]))
        seen=','.join(str(n) for n in lane_values)
        if depth==0:write_all(b'{ ... }');return
        write_all(b'{ ')
        for i,n in enumerate(lane_values):
            if family in (0,1,5,6):
                base={b'':10,b'any':10,b'd':10,b'b':2,b'o':8,b'x':16,b'X':16}[fmt]
                typ=8 if family in (0,5) else 0 if family==1 else 3
                aligned(representation(typ,n,base,int(fmt==b'X'),width),width,alignment,fill)
            elif family==2:aligned(b'true' if n else b'false',width,alignment,fill)
            else:aligned(float_text(n,32 if family==3 else 64,fmt,precision),width,alignment,fill)
            if i+1<len(lane_values):write_all(b', ')
        write_all(b' }')

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
 raw_for=lambda t:0x3fa00000 if t==3 else 0x3ff4000000000000 if t==4 else 17
 for typ,formats in FORMATS.items():
  raw=raw_for(typ)
  for fmt,cap,depth in itertools.product(formats,range(33),(0,1)):
   add('capacity-and-depth',spec(typ,fmt,value=raw,cap=cap,depth=depth))
  for fmt,width,precision,alignment in itertools.product(formats,(None,0,8),(None,0,2),range(3)):
   add('leaf-options',spec(typ,fmt,value=raw,width=width,precision=precision,alignment=alignment,fill=95,cap=128))
  edges=(0,(1<<64)-1,1<<63) if typ not in (3,4) else ((0,0x7f800000,0x7fc00000) if typ==3 else (0,0x7ff0000000000000,0x7ff8000000000000))
  for fmt,raw,length,depth,cap in itertools.product(formats,edges,(1,3,8),(0,1),(0,256)):
   add('lengths-and-bits',spec(typ,fmt,value=raw,length=length,depth=depth,cap=cap))
 for typ,fmt in ((0,b'd'),(0,b'x'),(1,b'X'),(2,b'any'),(3,b'e'),(4,b'X'),(6,b'b')):
  for kind,cap,start in itertools.product(range(3),(0,1,8,65),(0,3)):
   begin=start if not kind and start<cap else 0
   for prefix,binding,finish in itertools.product(sorted({0,cap-begin}),(0,) if not kind else (0,1,2),(0,1)):
    add('writer-state',spec(typ,fmt,value=raw_for(typ),kind=kind,cap=cap,start=start,prefix=prefix,binding=binding,finish=finish,width=9,precision=2))
 return rows

def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()

def compiler_cases():
 rows=[]
 def ok(name,zb,vb,out):rows.append((name,zb,vb,out,out))
 ztypes=('u8','u16','u32','u64','usize','i8','i16','i32','i64','isize','f32','f64')
 vtypes=tuple('int' if t=='i32' else t for t in ztypes)
 ok('native-widths',''.join(f'try w.printVector("any",.{{}},@as(@Vector(2,{t}),.{{1,2}}),1);' for t in ztypes),
    '\n'.join(f"w.print_vector('any',p.FormatOptions{{}},[{t}(1),2]!,1)!" for t in vtypes),b'{ 1, 2 }'*12)
 ok('characters','try w.printVector("c",.{},@as(@Vector(2,u8),.{65,66}),1);',"w.print_vector('c',p.FormatOptions{},[u8(65),66]!,1)!",b'{ A, B }')
 ok('unicode','try w.printVector("u",.{},@as(@Vector(2,u16),.{937,20013}),1);',"w.print_vector('u',p.FormatOptions{},[u16(937),20013]!,1)!",'{ Ω, 中 }'.encode())
 ok('duration','try w.printVector("D",.{},@as(@Vector(2,i64),.{1,-2}),1);',"w.print_vector('D',p.FormatOptions{},[i64(1),-2]!,1)!",b'{ 1ns, -2ns }')
 ok('bytes','try w.printVector("B",.{},@as(@Vector(2,u64),.{0,1000}),1);',"w.print_vector('B',p.FormatOptions{},[u64(0),1000]!,1)!",b'{ 0B, 1kB }')
 ok('binary-bytes','try w.printVector("Bi",.{},@as(@Vector(2,u64),.{0,1024}),1);',"w.print_vector('Bi',p.FormatOptions{},[u64(0),1024]!,1)!",b'{ 0B, 1KiB }')
 for name,zv,vv in (('scalar','@as(u8,1)','u8(1)'),('slice','@as([]const u8,&.{1,2})','[u8(1),2]'),('record-lanes','@as(@Vector(2,Empty),.{.{},.{}})','[Empty{},Empty{}]!'),('optional-lanes','@as(@Vector(2,?u8),.{null,null})','[?u8(none),none]!')):
  rows.append((name,f'try w.printVector("any",.{{}},{zv},0);',f"w.print_vector('any',p.FormatOptions{{}},{vv},0)!",None,None))
 for name,fmt,zt,vv,error,depth in (('invalid-bool','d','bool','[true,false]!','boolean',1),('invalid-float','b','f32','[f32(1),2]!','float',1),('invalid-cutoff','d','bool','[true,false]!','boolean',0)):
  zb=f'try w.printVector("{fmt}",.{{}},@as(@Vector(2,{zt}),@splat('+('true' if zt=='bool' else '1')+f')),{depth});'
  vb=(f"w.print_vector('{fmt}',p.FormatOptions{{}},{vv},{depth}) or {{require(err.msg()=='unsupported print_value {error} format')\nrequire(w.buffered().bytestr()=='{{ ')\nprint('rejected')\nreturn}}\npanic('unexpected success')") if depth else f"w.print_vector('{fmt}',p.FormatOptions{{}},{vv},0)!"
  rows.append((name,zb,vb,None,b'rejected' if depth else b'{ ... }'))
 rows.append(('runtime-format','const args=try std.process.argsAlloc(std.heap.page_allocator);try w.printVector(args[0],.{},@as(@Vector(2,u8),.{1,2}),1);',"format:=if os.args.len>0 {'d'} else {'any'}\nw.print_vector(format,p.FormatOptions{},[u8(1),2]!,1)!",None,b'{ 1, 2 }'))
 rows.append(('pointer-lanes','var value:u8=1;try w.printVector("*",.{},@as(@Vector(2,*u8),.{&value,&value}),1);std.debug.assert(std.mem.startsWith(u8,w.buffered(),"{ u8@"));w.end=0;',"mut value:=u8(1)\nw.print_vector('*',p.FormatOptions{},[&value,&value]!,1)!\nrequire(w.buffered().bytestr().starts_with('{ u8@'))\nw.seek_to(0)!",b'',b''))
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
 for typ,cap,depth in itertools.product(range(2),(0,1,2,3,7,64),(0,1)):
  data=b'{ ' if depth else b'{ ... }';end=min(cap,len(data));backing=data[:end]+b'\xa5'*(cap-end)
  expected=f'{end}|{backing.hex()}|{backing[:end].hex()}|{backing[end:].hex()}'.encode();trap=depth==1 and cap>=2
  for lang in ('native','translated'):
   label=f'trap-{typ}-{cap}-{depth}-{lang}';path=root/(label+'.state')
   result=proof.run([str(root/('trap-'+lang)),str(path),str(cap),str(typ),str(depth)],label,env=env,timeout=args.timeout,check=False)
   if trap:
    category='attempt to unwrap error: WriteFailed'
    checked_trap(result,label,category)
    messages=[m.group(1) for line in result.stderr.decode().splitlines() if (m:=re.fullmatch(r'(?:thread \d+ |V )?panic:\s*(.*)',line.strip()))]
    assert messages==[category],(label,messages)
   else:assert result.returncode==0 and result.stdout==(b'WriteFailed\n' if cap<len(data) else b'ok\n') and not result.stderr,label
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
    assert render_library_hashes(zig)==RENDER_LIBRARIES and float_library_hashes(zig)==FLOAT_LIBRARIES
    repo = Path(__file__).resolve().parent.parent; probe = repo/'zigimg/reference_probes/writer_vector'
    tables=verify_tables(repo,zig)
    with work_directory(args.workdir, 'witty-writer-vector-') as root:
        tmp = root/'tmp'; tmp.mkdir(); env = dict(os.environ, TMPDIR=str(tmp), VTMP=str(tmp), VEXE=str(v), V_C_ERROR_BUG_REPORT_DISABLED='1')
        proof = ProofLog(root); shutil.copytree(source, root/'src')
        files = ('main.v', 'reference.zig', 'fixture_shims.h', 'fixture_shims.c', 'portable.v', 'controls.v', 'controls.zig', 'trap.v', 'trap.zig')
        for name in files: shutil.copyfile(probe/name, root/name)
        shared = repo/'zigimg/reference_probes/writer_seek/fixture_shims.h'
        (root/'writer_seek').mkdir(); shutil.copyfile(shared, root/'writer_seek/fixture_shims.h')
        versions = [proof.run([str(exe), 'version'], label, env=env).stdout.decode().strip() for exe, label in ((zig, 'zig-version'), (v, 'v-version'))]
        assert versions[0] == '0.15.2' and re.match(r'^V 0\.5\.2(?: |$)', versions[1])
        impl = implementation_hashes(repo)
        helpers = ('verify_format_parser_reference.py', 'verify_jpeg_contracts_reference.py', 'verify_tiff_decode_reference.py', 'verify_stream_guards_reference.py', 'verify_image_open_reference.py', 'verify_image_tty_reference.py', 'verify_simd_reference.py', 'verify_png_foundation_reference.py', 'verify_writer_value_reference.py', 'verify_float_render_reference.py', 'verify_float_decimal_reference.py', 'verify_writer_float_hex_reference.py', 'verify_writer_float_reference.py')
        retained = {str(p.relative_to(repo)): sha(p) for p in [Path(__file__), shared, *(probe/n for n in files), *(repo/'zigimg'/n for n in helpers)]}
        compiler_hashes = {str(exe): sha(exe) for exe in (zig, v)}
        provenance = dict(source_sha256=PINNED_SOURCE_SHA256, implementation_sha256=impl, files=retained, versions=versions, compiler_sha256=compiler_hashes, target=args.target, v_prod=args.v_prod,render_libraries=RENDER_LIBRARIES,float_libraries=FLOAT_LIBRARIES,ryu_tables=tables)
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
        print(f'{mode}: {len(rows)} modeled vector records match', flush=True)
        outcomes=compiler_controls(proof,root,repo,zig,v,args,env)
        traps=trap_controls(proof,root,repo,zig,v,args,env)
        assert len(outcomes)==EXPECTED_COMPILER_PAIRS
        assert traps==dict(paired_traps=EXPECTED_TRAPS,returning_controls=EXPECTED_RETURN_CONTROLS,state_sha256=EXPECTED_STATE_SHA256)
        assert tree_hash(source) == tree_hash(root/'src') == PINNED_SOURCE_SHA256
        pins(source, zig)
        assert render_library_hashes(zig)==RENDER_LIBRARIES and float_library_hashes(zig)==FLOAT_LIBRARIES and verify_tables(repo,zig)==tables
        assert implementation_hashes(repo) == impl and all(sha(repo/p) == pin for p, pin in retained.items()), 'implementation/proof changed'
        assert all(sha(Path(exe)) == pin for exe, pin in compiler_hashes.items()), 'compiler changed'
        assert all(sha(root/n) == retained[str((probe/n).relative_to(repo))] for n in files) and sha(root/'writer_seek/fixture_shims.h') == sha(shared)
        assert not list(root.glob('*.owned*'))
        (root/'input_sha256.json').write_text(json.dumps({'corpus.txt': sha(path)}, indent=2)+'\n')
        summary = dict(returning_records=len(rows), output_sha256=digest, write_failed=sum(b'~WriteFailed|' in line for line in outputs[0]), groups=dict(Counter(group for group, _ in rows)), compiler_outcomes=outcomes, trap_controls=traps, zig_mode=mode, v_prod=args.v_prod)
        (root/'summary.json').write_text(json.dumps(summary, indent=2)+'\n'); print(json.dumps(summary), flush=True)


if __name__ == '__main__':
    main()
