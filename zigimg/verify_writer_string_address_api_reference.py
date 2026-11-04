"""Compare direct native string addresses with pinned Zig and an independent writer-state model."""
import argparse
from collections import Counter
import hashlib,itertools,json,os,re,shutil
from pathlib import Path
from verify_format_parser_reference import pins
from verify_simd_reference import ordinary_rejection
from verify_jpeg_contracts_reference import implementation_hashes
from verify_tiff_decode_reference import ProofLog,tree_hash,work_directory,PINNED_SOURCE_SHA256
from verify_writer_address_reference import addresses

EXPECTED_ROWS=5984
EXPECTED_SHA256='3dae8e7c2db63964eba7f98924ef96647db03a5e6ca7f12a64dfc520b841cc99'
EXPECTED_COMPILER_PAIRS=10
EXPECTED_TRAPS=0
EXPECTED_RETURN_CONTROLS=90
EXPECTED_STATE_SHA256='df634ec0f878189c58ed4b07f5ac33f8dbfd93e6f63b37aef3493f08bbe46980'
MAX=(1<<64)-1
TYPE_NAMES=('u8','u16','u32','u64','usize','i8','i16','i32','i64','isize','f32','f64','bool','anyopaque')
def optional_name(tag):return 'u8'
def spec(family=0,fmt=b'vs',kind=0,cap=32,start=0,prefix=0,binding=0,finish=1,value=0x1234,op=0,length=0,width=None,precision=None,depth=0,alignment=2,fill=32):
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

    def composition():
        nonlocal seen
        seen='none' if family>=6 else str(value)+':'+str(length)
        if family>=6:
            padding=max(0,(4 if width is None else width)-4)
            if alignment==0:write_all(b'null');write_all(bytes([fill])*padding)
            elif alignment==1:write_all(bytes([fill])*(padding//2));write_all(b'null');write_all(bytes([fill])*((padding+1)//2))
            else:write_all(bytes([fill])*padding);write_all(b'null')
            return
        write_all(b'u8@')
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
 for route,length in itertools.product(range(6),(0,1,3)):
  for cap in range(25):add('capacities-and-routes',spec(route,length=length,cap=cap))
  for i,raw in enumerate(addresses()):add('address-bits',spec(route,length=length,value=raw,cap=(0,8,32)[i%3]))
 for route in range(6):
  for width,precision,alignment,fill in itertools.product((None,0,MAX),(None,0,MAX),range(3),(0,95,255)):
   add('ignored-options',spec(route,width=width,precision=precision,alignment=alignment,fill=fill,depth=MAX))
 for route in (6,7):
  for width,precision,alignment,fill,cap in itertools.product((None,0,6,12),(None,0,MAX),range(3),(0,95,255),(0,5,32)):
   add('absent-options',spec(route,width=width,precision=precision,alignment=alignment,fill=fill,cap=cap))
 for route,length in ((0,3),(1,0),(2,3),(5,1),(6,0)):
  for kind,cap,start in itertools.product(range(3),(0,1,8,32),(0,3)):
   begin=start if not kind and start<cap else 0
   for prefix,binding,finish in itertools.product(sorted({0,cap-begin}),(0,) if not kind else (0,1,2),(0,1)):
    add('writer-state',spec(route,length=length,kind=kind,cap=cap,start=start,prefix=prefix,binding=binding,finish=finish,width=9,precision=MAX))
 return rows

def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()

def compiler_cases():
 rows=[]
 def ok(n,z,v,out):rows.append((n,z,v,out,out))
 z='const value:[]allowzero const u8=@as([*]allowzero const u8,@ptrFromInt(0x1234))[0..3];'
 v="value:=borrowed(usize(0x1234),3)\n"
 ok('routes',z+'try w.printAddress(value);try w.printAddress(value);try w.printValue("*",.{},value,0);try w.printValue("*",.{},value,0);try w.printValue("?*",.{},@as(?[]allowzero const u8,value),0);try w.printValue("?*",.{},@as(?[]allowzero const u8,value),0);',v+"w.print_address(value)!\nw.print_address(Text(value))!\nw.print_value('*',p.FormatOptions{},value,0)!\nw.print_value('*',p.FormatOptions{},Text(value),0)!\nw.print_value('?*',p.FormatOptions{},?string(value),0)!\nw.print_value('?*',p.FormatOptions{},?Text(Text(value)),0)!",b'u8@1234'*6)
 zo='var backing_data=[4]u8{65,0,255,66};const value:[]const u8=&backing_data;try w.printAddress(value);const expected=try std.fmt.allocPrint(std.heap.page_allocator,"u8@{x}",.{@intFromPtr(value.ptr)});if(!std.mem.eql(u8,w.buffered(),expected))return error.BadAddress;w.end=0;backing_data[0]=90;try w.printAddress(value);if(!std.mem.eql(u8,w.buffered(),expected))return error.BadAddress;w.end=0;try w.writeAll("address-ok");'
 vo="mut bytes:=[u8(65),0,255,66]\nvalue:=unsafe{(&u8(bytes.data)).vstring_with_len(bytes.len)}\nw.print_address(value)!\nrequire(w.buffered().bytestr()=='u8@${usize(value.str):x}')\nw.seek_to(0)!\nbytes[0]=90\nw.print_address(value)!\nrequire(w.buffered().bytestr()=='u8@${usize(value.str):x}')\nw.seek_to(0)!\nw.write_all('address-ok'.bytes())!"
 ok('owned-mutation',zo,vo,b'address-ok')
 ok('print',z+'try w.print("L{[value]*}R",.{.value=value});try w.printAddress(value);',v+"w.print('L{[value]*}R',Args{value})!\nw.print_address(value)!",b'Lu8@1234Ru8@1234')
 ok('empty-owned','const value:[]const u8="";try w.printAddress(value);const expected=try std.fmt.allocPrint(std.heap.page_allocator,"u8@{x}",.{@intFromPtr(value.ptr)});if(!std.mem.eql(u8,w.buffered(),expected))return error.BadAddress;w.end=0;try w.writeAll("address-ok");',"value:=''\nw.print_address(value)!\nrequire(w.buffered().bytestr()=='u8@${usize(value.str):x}')\nw.seek_to(0)!\nw.write_all('address-ok'.bytes())!",b'address-ok')
 rows.append(('invalid-integer','try w.printAddress(@as(u8,7));',"w.print_address(u8(7))!",None,None))
 rows.append(('bare-optional','try w.printAddress(@as(?[]const u8,null));',"w.print_address(?string(none))!",None,None))
 rows.append(('string-pointer','const value:[]const u8="a";try w.printAddress(&value);const expected=try std.fmt.allocPrint(std.heap.page_allocator,"[]const u8@{x}",.{@intFromPtr(&value)});if(!std.mem.eql(u8,w.buffered(),expected))return error.BadAddress;w.end=0;try w.writeAll("address-ok");',"value:='a'\nw.print_address(&value)!",b'address-ok',None))
 rows.append(('runtime-format',z+'const args=try std.process.argsAlloc(std.heap.page_allocator);try w.printValue(args[0],.{},value,0);',v+"format:=if os.args.len>0 {'*'} else {'s'}\nw.print_value(format,p.FormatOptions{},value,0)!",None,b'u8@1234'))
 ok('contents','const value:[]const u8="A\\x00B";try w.printValue("s",.{},value,0);',"value:='A\\x00B'\nw.print_value('s',p.FormatOptions{},value,0)!",b'A\x00B')
 ok('element-regression','try w.printAddress(@as(*allowzero align(1) [2][]const u8,@ptrFromInt(0x1234)));',"value:=unsafe{&Pair(voidptr(usize(0x1234)))}\nw.print_address(value)!",b'[2][]const u8@1234')
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
 for typ,cap in itertools.product(range(6),(0,1,2,3,4,5,6,7,8,9,10,12,16,24,32)):
  data=(b'u8@1234' if typ<3 else b'u8@ffffffffffffffff' if typ==3 else b'__null' if typ==4 else b'_'*(cap+1))
  end=min(cap,len(data));backing=data[:end]+b'\xa5'*(cap-end)
  expected=f'{end}|{backing.hex()}|{backing[:end].hex()}|{backing[end:].hex()}'.encode()
  for lang in ('native','translated'):
   label=f'trap-{typ}-{cap}-{lang}';path=root/(label+'.state')
   result=proof.run([str(root/('trap-'+lang)),str(path),str(cap),str(typ)],label,env=env,timeout=args.timeout,check=False)
   assert result.returncode==0 and result.stdout==(b'ok\n' if cap>=len(data) else b'WriteFailed\n') and not result.stderr,label
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
    repo = Path(__file__).resolve().parent.parent; probe = repo/'zigimg/reference_probes/writer_string_address_api'
    with work_directory(args.workdir, 'witty-writer-string-address-api-') as root:
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
        print(f'{mode}: {len(rows)} modeled pointer-slice address records match', flush=True)
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
