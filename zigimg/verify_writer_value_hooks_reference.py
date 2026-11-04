"""Compare struct number/unit formatter hooks with pinned Zig and a writer-state model."""
import argparse
from collections import Counter
import hashlib,itertools,json,os,re,shutil
from pathlib import Path
from verify_format_parser_reference import pins
from verify_simd_reference import ordinary_rejection
from verify_jpeg_contracts_reference import implementation_hashes
from verify_tiff_decode_reference import ProofLog,tree_hash,work_directory,PINNED_SOURCE_SHA256

EXPECTED_ROWS = 6850
EXPECTED_SHA256 = 'e69f15433b3efb0a22f964440b5cea2ef98b558c32a473f70cf66910e67eb1f7'
EXPECTED_COMPILER_PAIRS = 19
MAX=(1<<64)-1
FORMATS=(b'd',b'b',b'o',b'x',b'X',b'e',b'E',b'B',b'Bi',b'D')
def spec(family=0,fmt=b'd',kind=0,cap=32,start=0,prefix=0,binding=0,finish=1,value=-17,text=b'hi\0\xff',width=None,precision=None,stop=0,depth=0,alignment=2,fill=32):
 return '|'.join(map(str,(family,fmt.hex(),kind,cap,start,prefix,binding,finish,value,text.hex(),'-' if width is None else width,'-' if precision is None else precision,stop,depth,alignment,fill)))

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
                         buffer.hex(), buffer[:end].hex(), buffer[end:].hex(), f"{calls}:{steps}:{seen}", contents.hex()))

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
        nonlocal calls, steps, seen
        if family == 3:
            aligned(b'null', width, alignment, fill); return
        if fmt in (b'B', b'Bi'):
            seen = 'B:'+str(int(fmt == b'Bi')); label = b'bytes'
        elif fmt == b'D': seen = 'D'; label = b'duration'
        else:
            modes={b'd':0,b'b':1,b'o':2,b'x':3,b'X':3,b'e':4,b'E':4}
            seen = f'N:{modes[fmt]}:{int(fmt in (b"X",b"E"))}:{"-" if precision is None else precision}:{"-" if width is None else width}:{alignment}:{fill}'
            label = b'number'
        calls += 1
        if stop == 1: raise WriteFailed()
        for index, data in enumerate((label,b'(',str(value).encode(),b':',text,b')'),1):
            write_all(data); steps=index
            if (stop == 2 and index == 1) or (stop == 3 and index == 5): raise WriteFailed()

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
 for fmt,carrier,cap,stop in itertools.product(FORMATS,range(3),range(25),range(4)):
  add('capacity-and-errors',spec(carrier,fmt,cap=cap,stop=stop,width=MAX,precision=MAX,fill=255,depth=MAX))
 for fmt,width,precision,alignment,fill in itertools.product(FORMATS,(None,0,9,MAX),(None,0,3,MAX),range(3),(0,95,255)):
  add('options',spec(fmt=fmt,width=width,precision=precision,alignment=alignment,fill=fill))
 for fmt,kind,cap,start in itertools.product(FORMATS,range(3),(0,1,8,65),(0,3)):
  begin=start if not kind and start<cap else 0
  for prefix,binding,finish in itertools.product(sorted({0,cap-begin}),(0,) if not kind else (0,1,2),(0,1)):
   add('writer-state',spec(fmt=fmt,kind=kind,cap=cap,start=start,prefix=prefix,binding=binding,finish=finish,value=-(1<<63)))
 for fmt,cap,width in itertools.product(FORMATS,range(13),(None,0,9)):
  add('absent-optionals',spec(3,fmt,cap=cap,width=width,precision=MAX,alignment=1,fill=95))
 for fmt,text,value in itertools.product(FORMATS,(b'',bytes(range(256))),(-(1<<63),0,(1<<63)-1)):
  add('binary-and-extrema',spec(fmt=fmt,cap=400,text=text,value=value))
 return rows

def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()

def compiler_cases():
 rows=[]
 def ok(name, zbody, vbody, output):rows.append((name,zbody,vbody,output,output))
 def invalid(name, fmt, zvalue, vvalue, native=None):
  vb=f"w.print_value('{fmt}',p.FormatOptions{{}},{vvalue},0) or {{\nrequire(err.msg()=='unsupported print_value struct format')\nrequire(backing==before && w.buffered().len==0)\nprint('rejected')\nreturn\n}}\npanic('unexpected success')"
  rows.append((name,f'try w.printValue("{fmt}",.{{}},{zvalue},0);',vb,native,b'rejected'))
 ok('number-only','inline for(.{"d","b","o","x","X","e","E"}) |fmt| try w.printValue(fmt,.{},Num{},0);',
    "for format in ['d','b','o','x','X','e','E'] {w.print_value(format,p.FormatOptions{},Num{},0)!}",b'NNNNNNN')
 ok('bytes-only','try w.printValue("B",.{},BytesHook{},0);try w.printValue("Bi",.{},BytesHook{},0);',
    "w.print_value('B',p.FormatOptions{},BytesHook{},0)!\nw.print_value('Bi',p.FormatOptions{},BytesHook{},0)!",b'BB')
 ok('duration-only','try w.printValue("D",.{},DurationHook{},0);',"w.print_value('D',p.FormatOptions{},DurationHook{},0)!",b'D')
 ok('alias','try w.printValue("d",.{},Num{},0);',"w.print_value('d',p.FormatOptions{},NumAlias(Num{}),0)!",b'N')
 ok('optional','try w.printValue("?d",.{},@as(?Num,Num{}),0);',"w.print_value('?d',p.FormatOptions{},?Num(Num{}),0)!",b'N')
 ok('print','try w.print("a{E}b",Args{.value=.{}});',"w.print('a{E}b',Args{Num{}})!",b'aNb')
 ok('any','try w.printValue("any",.{},Num{},0);',"w.print_value('any',p.FormatOptions{},Num{},0)!",b'.{ ... }')
 ok('enum','try w.printValue("d",.{},Named.one,0);',"w.print_value('d',p.FormatOptions{},Named.one,0)!",b'1')
 labels={'d':'number','B':'bytes','Bi':'binary-bytes','D':'duration'}
 for fmt in ('d','B','Bi','D'):invalid('missing-'+labels[fmt],fmt,'Empty{}','Empty{}')
 for fmt in ('d','B','D'):invalid('nonfallible-'+labels[fmt],fmt,'Nonfallible{}','Nonfallible{}',b'')
 for fmt,typ in (('d','WrongNumber'),('B','WrongBytes'),('D','WrongDuration')):invalid('wrong-'+labels[fmt],fmt,typ+'{}',typ+'{}')
 rows.append(('runtime-format','const args=try std.process.argsAlloc(std.heap.page_allocator);try w.printValue(args[0],.{},Num{},0);',
              "format:=if os.args.len>0 {'d'} else {'E'}\nw.print_value(format,p.FormatOptions{},Num{},0)!",None,b'N'))
 return rows

def compiler_controls(proof,root,repo,zig,v,args,env):
 outcomes={};inputs={}
 for name,zbody,vbody,zout,vout in compiler_cases():
  outcomes[name]={}
  for lang,extension,body,expected in (('native','.zig',zbody,zout),('translated','.v',vbody,vout)):
   if lang=='native':body+='var out=std.fs.File.stdout().writer(&.{});try out.interface.writeAll(w.buffered());'
   elif not body.endswith("panic('unexpected success')"):body+='\nprint(w.buffered().bytestr())'
   path=root/(name+extension);path.write_text((root/('controls'+extension)).read_text().replace('// BODY',body));inputs[path.name]=sha(path)
   label=name+'-'+lang;binary=root/label
   command=([str(zig),'build-exe','-target',args.target,'-lc','-O','ReleaseSafe' if args.v_prod else 'Debug','--global-cache-dir',str(root.parent/'zig-global'),'--cache-dir',str(root/'zig-cache'),'-femit-bin='+str(binary),str(path)] if lang=='native' else [str(v),'-enable-globals',*(['-prod'] if args.v_prod else []),'-path',f'{repo}|@vlib|@vmodules','-o',str(binary),str(path)])
   result=proof.run(command,label+'-compile',env=env,timeout=args.timeout,check=False)
   if expected is None:ordinary_rejection(result,label);outcomes[name][lang]='reject'
   else:
    assert result.returncode==0,(name,lang,result.stdout,result.stderr)
    result=proof.run([str(binary)],label+'-run',env=env,timeout=args.timeout)
    assert result.stdout==expected and not result.stderr,(name,lang,result.stdout,result.stderr,expected)
    outcomes[name][lang]='return:'+expected.hex()
 assert all(sha(root/p)==pin for p,pin in inputs.items())
 (root/'compiler-inputs.json').write_text(json.dumps(inputs,indent=2)+'\n')
 return outcomes

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path); parser.add_argument('zig', type=Path); parser.add_argument('v', type=Path)
    parser.add_argument('--target', default='aarch64-macos.14.0'); parser.add_argument('--v-prod', action='store_true')
    parser.add_argument('--workdir', type=Path); parser.add_argument('--timeout', type=int, default=600)
    args = parser.parse_args()
    if args.timeout <= 0: parser.error('--timeout must be positive')
    source = args.source.resolve()/'src'; zig = args.zig.resolve(); v = args.v.resolve()
    pins(source, zig)
    repo = Path(__file__).resolve().parent.parent; probe = repo/'zigimg/reference_probes/writer_value_hooks'
    with work_directory(args.workdir, 'witty-writer-value-hooks-') as root:
        tmp = root/'tmp'; tmp.mkdir(); env = dict(os.environ, TMPDIR=str(tmp), VTMP=str(tmp), VEXE=str(v), V_C_ERROR_BUG_REPORT_DISABLED='1')
        proof = ProofLog(root); shutil.copytree(source, root/'src')
        files = ('main.v', 'reference.zig', 'fixture_shims.h', 'fixture_shims.c', 'portable.v', 'controls.v', 'controls.zig')
        for name in files: shutil.copyfile(probe/name, root/name)
        shared = repo/'zigimg/reference_probes/writer_seek/fixture_shims.h'
        (root/'writer_seek').mkdir(); shutil.copyfile(shared, root/'writer_seek/fixture_shims.h')
        versions = [proof.run([str(exe), 'version'], label, env=env).stdout.decode().strip() for exe, label in ((zig, 'zig-version'), (v, 'v-version'))]
        assert versions[0] == '0.15.2' and re.match(r'^V 0\.5\.2(?: |$)', versions[1])
        impl = implementation_hashes(repo)
        helpers = ('verify_format_parser_reference.py', 'verify_jpeg_contracts_reference.py', 'verify_tiff_decode_reference.py', 'verify_stream_guards_reference.py', 'verify_image_open_reference.py', 'verify_image_tty_reference.py', 'verify_simd_reference.py', 'verify_png_foundation_reference.py')
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
        print(f'{mode}: {len(rows)} modeled hook records match', flush=True)
        outcomes=compiler_controls(proof,root,repo,zig,v,args,env)
        assert len(outcomes)==EXPECTED_COMPILER_PAIRS
        assert tree_hash(source) == tree_hash(root/'src') == PINNED_SOURCE_SHA256
        pins(source, zig)
        assert implementation_hashes(repo) == impl and all(sha(repo/p) == pin for p, pin in retained.items()), 'implementation/proof changed'
        assert all(sha(Path(exe)) == pin for exe, pin in compiler_hashes.items()), 'compiler changed'
        assert all(sha(root/n) == retained[str((probe/n).relative_to(repo))] for n in files) and sha(root/'writer_seek/fixture_shims.h') == sha(shared)
        assert not list(root.glob('*.owned*'))
        (root/'input_sha256.json').write_text(json.dumps({'corpus.txt': sha(path)}, indent=2)+'\n')
        summary = dict(returning_records=len(rows), output_sha256=digest, write_failed=sum(b'~WriteFailed|' in line for line in outputs[0]), groups=dict(Counter(group for group, _ in rows)), compiler_outcomes=outcomes, zig_mode=mode, v_prod=args.v_prod)
        (root/'summary.json').write_text(json.dumps(summary, indent=2)+'\n'); print(json.dumps(summary), flush=True)


if __name__ == '__main__':
    main()
