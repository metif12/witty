"""Compare slice-of-fixed-array Writer value addresses with pinned Zig and an independent writer-state model."""
import argparse
from collections import Counter
import hashlib,itertools,json,os,re,shutil
from pathlib import Path
from verify_format_parser_reference import pins
from verify_simd_reference import ordinary_rejection
from verify_jpeg_contracts_reference import implementation_hashes
from verify_tiff_decode_reference import ProofLog,tree_hash,work_directory,PINNED_SOURCE_SHA256
from verify_writer_address_reference import addresses

EXPECTED_ROWS=37551
EXPECTED_SHA256='88b5d86c2fb938f3e4c80dcfa956c006cf5e565c7251e4ea1a5777fbbea0a9db'
EXPECTED_COMPILER_PAIRS=20
EXPECTED_TRAPS=0
EXPECTED_RETURN_CONTROLS=135
EXPECTED_STATE_SHA256='c994569308e1a37cae4c084cdfce0dfec82e74da26ac0acbdde9d3913b8627dc'
MAX=(1<<64)-1
TYPE_NAMES=('u8','u16','u32','u64','usize','i8','i16','i32','i64','isize','f32','f64','bool')
def array_name(tag,op):return ('[2][3]' if op==2 else '[1]' if op==3 else '[3]')+TYPE_NAMES[tag]
def spec(family=0,fmt=None,kind=0,cap=32,start=0,prefix=0,binding=0,finish=1,value=0x1234,op=0,length=0,width=None,precision=None,depth=0,alignment=2,fill=32):
 fmt=(b'?*' if op>=5 else b'*') if fmt is None else fmt
 return '|'.join(map(str,(family,fmt.hex(),kind,cap,start,prefix,binding,finish,value&MAX,length,'-' if width is None else width,'-' if precision is None else precision,op,depth,alignment,fill)))

class WriteFailed(Exception):
    pass


def modeled(line):
    f = line.split('|')
    family = int(f[0]); fmt = bytes.fromhex(f[1])
    kind, cap, start, prefix, binding, finish, value = map(int, f[2:9])
    length = int(f[9]); width = None if f[10] == "-" else int(f[10]); precision = None if f[11] == '-' else int(f[11]); stop = int(f[12])
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
        op=int(f[12]);seen=str(value)+':'+str(length)
        if op in (6,8):aligned(b'null',width,alignment,fill);return
        write_all((array_name(family,op)+'@').encode())
        write_all(format(value,'x').encode())

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
 for tag,op in itertools.product(range(13),range(9)):
  for length in (0,3):
   for cap in range(25):add('capacities-and-carriers',spec(tag,op=op,length=length,cap=cap))
   for i,raw in enumerate(addresses() if op in (0,2,5,7) else (0,1,MAX)):
    add('address-bits-and-presence',spec(tag,op=op,length=length,value=raw,cap=(0,8,32)[i%3],depth=(0,1,MAX)[i%3]))
  for width,precision,alignment,fill in itertools.product((None,0,8,24) if op in (6,8) else (None,0,MAX),(None,0,MAX),range(3),(0,95,255)):
   add('options-and-null-alignment',spec(tag,op=op,width=width,precision=precision,alignment=alignment,fill=fill,depth=MAX))
 for tag,op,length in ((0,0,0),(7,1,3),(12,2,0),(10,4,0),(11,5,3),(6,6,1),(0,8,0)):
  for kind,cap,start in itertools.product(range(3),(0,1,8,65),(0,3)):
   begin=start if not kind and start<cap else 0
   for prefix,binding,finish in itertools.product(sorted({0,cap-begin}),(0,) if not kind else (0,1,2),(0,1)):
    add('writer-state',spec(tag,op=op,length=length,kind=kind,cap=cap,start=start,prefix=prefix,binding=binding,finish=finish,width=8 if op in (6,8) else MAX,precision=MAX,fill=95,depth=0))
 return rows

def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()

def compiler_cases():
 rows=[]
 def ok(name,z,v,out):rows.append((name,z,v,out,out))
 ztypes=TYPE_NAMES;vtypes=tuple('int' if t=='i32' else t for t in ztypes)
 ok('native-slices',''.join(f'const value{i}:[]allowzero align(1) [3]{t}=@as([*]allowzero align(1) [3]{t},@ptrFromInt(0x1234))[0..3];try w.printValue("*",.{{.width=std.math.maxInt(usize),.precision=std.math.maxInt(usize)}},value{i},0);' for i,t in enumerate(ztypes)),
  '\n'.join(f"zero{i}:=[3]{t}{{}}\nw.print_value('*',p.FormatOptions{{width:~usize(0),precision:~usize(0)}},borrowed(zero{i},usize(0x1234),3),0)!" for i,t in enumerate(vtypes)),''.join('[3]'+t+'@1234' for t in ztypes).encode())
 zb='const value:[]allowzero align(1) [3]u8=@as([*]allowzero align(1) [3]u8,@ptrFromInt(0x1234))[0..0];'
 vb='zero:=Bytes{}\nview:=borrowed(zero,usize(0x1234),0)\n'
 ok('whole-slice-alias',zb+'try w.printValue("*",.{},value,0);',vb+"w.print_value('*',p.FormatOptions{},Views(view),0)!",b'[3]u8@1234')
 ok('nested','const value:[]allowzero align(1) [2][3]i32=@as([*]allowzero align(1) [2][3]i32,@ptrFromInt(0))[0..3];try w.printValue("*",.{},value,0);',"zero:=[[int(0),0,0]!,[int(0),0,0]!]!\nw.print_value('*',p.FormatOptions{},borrowed(zero,usize(0),3),0)!",b'[2][3]i32@0')
 ok('owned','var values:[2][3]u8=.{.{0,1,2},.{3,4,5}};const view:[][3]u8=&values;try w.printValue("*",.{},view,0);const expected=try std.fmt.allocPrint(std.heap.page_allocator,"[3]u8@{x}",.{@intFromPtr(view.ptr)});if(!std.mem.eql(u8,w.buffered(),expected))return error.BadAddress;w.end=0;try w.writeAll("address-ok");',"values:=[[u8(0),1,2]!,[u8(3),4,5]!]\nw.print_value('*',p.FormatOptions{},values,0)!\nrequire(w.buffered().bytestr()=='[3]u8@${usize(values.data):x}')\nw.seek_to(0)!\nw.write_all('address-ok'.bytes())!",b'address-ok')
 ok('empty-zero','const value:[]allowzero align(1) [3]u8=@as([*]allowzero align(1) [3]u8,@ptrFromInt(0))[0..0];try w.printValue("*",.{},value,0);',"zero:=Bytes{}\nw.print_value('*',p.FormatOptions{},borrowed(zero,usize(0),0),0)!",b'[3]u8@0')
 ok('print',zb+'try w.print("a{[value]*}b",.{.value=value});',vb+"w.print('a{[value]*}b',Args{view})!",b'a[3]u8@1234b')
 ok('optional-present',zb+'try w.printValue("?*",.{.width=std.math.maxInt(usize),.precision=std.math.maxInt(usize)},@as(?[]allowzero align(1) [3]u8,value),0);',vb+"alias_view:=Views(view)\nw.print_value('?*',p.FormatOptions{width:~usize(0),precision:~usize(0)},?Views(alias_view),0)!",b'[3]u8@1234')
 ok('optional-none','try w.printValue("?*",.{.width=8,.alignment=.center,.fill=95},@as(?[]allowzero align(1) [3]u8,null),0);',"w.print_value('?*',p.FormatOptions{width:usize(8),alignment:.center,fill:`_`},?[]Bytes(none),0)!",b'__null__')
 ok('optional-print','try w.print("{[value]?*:_^8}",.{.value=@as(?[]allowzero align(1) [3]u8,null)});',"w.print('{[value]?*:_^8}',MaybeArgs{?Views(none)})!",b'__null__')
 reject=" or {require(backing==before && w.buffered().len==0)\nprint('rejected')\nreturn}\npanic('unexpected success')"
 rows.append(('invalid-decimal',zb+'try w.printValue("d",.{},value,0);',vb+"w.print_value('d',p.FormatOptions{},view,0)"+reject,None,b'rejected'))
 for name,zb1,vb1 in (
  ('record','const R=struct{value:i32};var items:[1][1]R=.{.{.{.value=7}}};const value:[][1]R=&items;',"value:=[[Record{7}]!]\n"),
  ('optional-elements','var items:[1][2]?i32=.{.{7,null}};const value:[][2]?i32=&items;',"value:=[[?int(7),?int(none)]!]\n")):
  zv='const expected=try std.fmt.allocPrint(std.heap.page_allocator,"{s}@{x}",.{@typeName(@typeInfo(@TypeOf(value)).pointer.child),@intFromPtr(value.ptr)});if(!std.mem.eql(u8,w.buffered(),expected))return error.BadAddress;w.end=0;try w.writeAll("address-ok");'
  rows.append((name,zb1+'try w.printValue("*",.{},value,0);'+zv,vb1+"w.print_value('*',p.FormatOptions{},value,0)"+reject,b'address-ok',b'rejected'))
 rows.append(('option-scalar-slice','var items:[2]?i32=.{7,null};const value:[]?i32=&items;try w.printValue("*",.{},value,0);const expected=try std.fmt.allocPrint(std.heap.page_allocator,"?i32@{x}",.{@intFromPtr(value.ptr)});if(!std.mem.eql(u8,w.buffered(),expected))return error.BadAddress;w.end=0;try w.writeAll("address-ok");',"value:=[?int(7),?int(none)]\nw.print_value('*',p.FormatOptions{},value,0)"+reject,b'address-ok',b'rejected'))
 rows.append(('fixed-array-value','try w.printValue("*",.{},[1][3]u8{.{0,1,2}},0);',"value:=[[u8(0),1,2]!]!\nw.print_value('*',p.FormatOptions{},value,0)"+reject,None,b'rejected'))
 rows.append(('bare-optional','try w.printValue("*",.{},@as(?[]allowzero align(1) [3]u8,null),0);',"w.print_value('*',p.FormatOptions{},?[]Bytes(none),0)"+reject,None,b'rejected'))
 rows.append(('runtime-format',zb+'const args=try std.process.argsAlloc(std.heap.page_allocator);try w.printValue(args[0],.{},value,0);',vb+"format:=if os.args.len>0 {'*'} else {'any'}\nw.print_value(format,p.FormatOptions{},view,0)!",None,b'[3]u8@1234'))
 ok('optional-zero-data','const value:[]allowzero align(1) [3]u8=@as([*]allowzero align(1) [3]u8,@ptrFromInt(0))[0..0];try w.printValue("?*",.{},@as(?[]allowzero align(1) [3]u8,value),0);',"zero:=Bytes{}\nview:=borrowed(zero,usize(0),0)\nw.print_value('?*',p.FormatOptions{},?[]Bytes(view),0)!",b'[3]u8@0')
 ok('optional-return',zb+'try w.printValue("?*",.{},@as(?[]allowzero align(1) [3]u8,value),0);',"w.print_value('?*',p.FormatOptions{},native_optional(),0)!",b'[3]u8@1234')
 ok('optional-nested','const value:[]allowzero align(1) [2][3]i32=@as([*]allowzero align(1) [2][3]i32,@ptrFromInt(1))[0..0];try w.printValue("?*",.{},@as(?[]allowzero align(1) [2][3]i32,value),0);',"zero:=Nested{}\nview:=borrowed(zero,usize(1),0)\nw.print_value('?*',p.FormatOptions{},?[]Nested(view),0)!",b'[2][3]i32@1')
 ok('direct-api-agreement',zb+'try w.printAddress(value);try w.writeByte(124);try w.printValue("*",.{},value,0);',vb+"w.print_address(view)!\nw.write_byte(`|`)!\nw.print_value('*',p.FormatOptions{},view,0)!",b'[3]u8@1234|[3]u8@1234')
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
 records=[];returns=0
 for typ,cap in itertools.product(range(9),(0,1,2,3,4,5,6,7,8,9,10,12,16,24,32)):
  if typ in (5,6,7):
   backing=(b'null'[:cap]+b'_'*max(0,cap-4)) if typ==5 else b'_'*cap;end=cap
  else:
   data={0:b'[3]u8@1234',1:b'[2][3]i32@0',2:b'[1]f64@ffffffffffffffff',3:b'[3]u8@1234',4:b'__null__',8:b'\0'*4+b'null'}[typ]
   end=min(cap,len(data));backing=data[:end]+b'\xa5'*(cap-end)
  expected=f'{end}|{backing.hex()}|{backing[:end].hex()}|{backing[end:].hex()}'.encode()
  for lang in ('native','translated'):
   label=f'trap-{typ}-{cap}-{lang}';path=root/(label+'.state')
   result=proof.run([str(root/('trap-'+lang)),str(path),str(cap),str(typ)],label,env=env,timeout=args.timeout,check=False)
   assert result.returncode==0 and result.stdout==(b'WriteFailed\n' if typ in (5,6,7) or cap<len(data) else b'ok\n') and not result.stderr,label
   assert path.read_bytes()==expected,(label,path.read_bytes(),expected)
  returns+=1;records.append(f'{typ}:{cap}:'.encode()+expected)
 return dict(paired_traps=0,returning_controls=returns,state_sha256=hashlib.sha256(b'\n'.join(records)).hexdigest())

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path); parser.add_argument('zig', type=Path); parser.add_argument('v', type=Path)
    parser.add_argument('--target', default='aarch64-macos.14.0'); parser.add_argument('--v-prod', action='store_true')
    parser.add_argument('--workdir', type=Path); parser.add_argument('--timeout', type=int, default=600)
    args = parser.parse_args()
    if args.timeout <= 0: parser.error('--timeout must be positive')
    source = args.source.resolve()/'src'; zig = args.zig.resolve(); v = args.v.resolve()
    pins(source, zig)
    repo = Path(__file__).resolve().parent.parent; probe = repo/'zigimg/reference_probes/writer_slice_array_address'
    with work_directory(args.workdir, 'witty-writer-slice-array-address-') as root:
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
        print(f'{mode}: {len(rows)} modeled slice-array address records match', flush=True)
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
