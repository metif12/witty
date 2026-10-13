"""Compare unchanged RAS records, palettes, RLE and retained read failures."""
import argparse
from collections import Counter
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import struct

from verify_jpeg_contracts_reference import implementation_hashes
from verify_tga_decode_reference import stdlib_hash, PINNED_STDLIB_SHA256
from verify_tiff_decode_reference import (
    ProofLog, tree_hash, work_directory, PINNED_SOURCE_SHA256, checked_trap,
)

EXPECTED_MAIN_SHA256 = '5eb7d5959e413859877b0343cb222f90f2555ccf0a80176cb7612508328f0583'
EXPECTED_RETURN_SHA256 = '9844e90533766c19eb07668ba6d0f3b9ad46947360dcb233e561161a1d53d493'
EXPECTED_STATE_SHA256 = '960db8d79a310328d870cefb371f62730d47fc48a4f74ecd8bf09b291afb41c8'
EXPECTED_DEBUG_SHA256 = 'e6dc540b17c9a8383a48e25b22e44b27b0ce638a73c1fc64e10a9422992f9c96'
EXPECTED_MAIN = 2585
EXPECTED_RETURNS = 40320
EXPECTED_TRAPS = 576
KINDS=(0,1,2,3,4,5,65535)

def header(w=1,h=1,d=8,kind=0,map=0,length=0):
    return b'\x59\xa6\x6a\x95'+struct.pack('>7I',w,h,d,0xffffffff,kind,map,length)
def line(data=b'',op=0,kind=0,map=0,length=0,capacity=0,start=0):
    return '|'.join(str(value) for value in (op,kind,map,length,capacity,start,(b'x'*start+data).hex()))
def row_bytes(w,d):
    if d==1:
        n=(w+7)//8
        return n+(n&1)
    return w*max(1,d//8)
def encode(data,kind):
    return data.replace(b'\x80',b'\x80\0') if kind==2 else data

def corpus():
    rows=[];traps=[]
    def add(group,name,data=b'',op=0,kind=0,map=0,length=0,capacity=0,start=0,panic=None):
        case=(group,name,line(data,op,kind,map,length,capacity,start))
        (traps if panic else rows).append((*case,panic) if panic else case)
    for flag in range(256):
        for cut in (0,1):
            for cap in (0,1,2):add('rle-flag',f'flag-{flag}-{cut}-{cap}',bytes((flag,))[:cut],2,2,capacity=cap)
    for count in range(256):
        for value in (0,128):
            packet=bytes((128,count,value))
            for cut in range(4):
                for cap in (0,1,2,3,255,256,257):add('rle-run',f'run-{count}-{value}-{cut}-{cap}',packet[:cut],2,2,capacity=cap)
    for kind in KINDS:
        for cut in range(4):
            for cap in (0,1,2,3,4,255,256,257):add('raw-dispatch',f'raw-{kind}-{cut}-{cap}',bytes((1,128,2))[:cut],2,kind,capacity=cap)
    for map in (0,1,2):
        for length in (*range(10),765,768,769,770):
            full=bytes((i*37+19)&255 for i in range(length+3))
            for cut in sorted({0,1,max(0,length-1),length,length+3}):add('palette',f'palette-{map}-{length}-{cut}',full[:cut],1,map=map,length=length,start=3)
    for d in (0,1,2,8,16,24,32):
        for kind in KINDS:
            for w in (0,1,2,3,7,8,9,15,16,17):
                for h in (0,1,2):
                    for map,length in ((0,0),(0,6),(1,0),(1,1),(1,2),(1,6),(2,0),(2,6)):
                        raw=bytes((i*37+19)&255 for i in range(row_bytes(w,d)*h))
                        pal=bytes((i*29+7)&255 for i in range(length)) if map==1 else b''
                        data=header(w,h,d,kind,map,length)+pal+encode(raw,kind)+b'\x63\x58'
                        panic=None
                        if d==1 and length>0 and map!=2 and kind in (0,1,2,3) and w*h>len(raw):
                            panic=f'index out of bounds: index {w*h}, len {len(raw)}'
                        # Image entry uses the default zero-length palette; its
                        # undefined header/backing storage are never observed.
                        for op in (0,3):add('read-matrix',f'read-{d}-{kind}-{w}-{h}-{map}-{length}-{op}',data,op,panic=panic)
    for d in (1,8,24,32):
        for kind in (0,2):
            raw=bytes((i*37+19)&255 for i in range(row_bytes(3,d)*2))
            data=header(3,2,d,kind,1,6)+bytes(range(6))+encode(raw,kind)
            for cut in range(len(data)):
                for op in (0,3):add('read-prefix',f'prefix-{d}-{kind}-{cut}-{op}',data[:cut],op,start=3)
    for w,h in ((0,0xffffffff),(0xffffffff,0)):
        for d in (1,8,24,32):
            for op in (0,3):add('wide-zero',f'wide-{w}-{h}-{d}-{op}',header(w,h,d),op)
    for pos in range(4):
        data=bytearray(header());data[pos]^=255
        for op in (0,3):add('magic',f'magic-{pos}-{op}',bytes(data),op)
    for mi,data in enumerate((b'',b'\x59\xa6\x6a\x95',b'nope',b'\x59\xa6\x6a\x95x')):
        for cut in range(len(data)+1):add('detect',f'detect-{mi}-{cut}',data[:cut],4,start=3)
    for cut in range(32):
        for op in (0,3):add('short-invalid',f'short-invalid-{cut}-{op}',header(kind=0xffffffff,map=0xffffffff)[:cut],op)
    for length in (771,772,773,780,65535,0xffffffff):
        colors=length//3;panic=f'index out of bounds: index {colors}, len 256'
        for map in (0,1,2):
            for start in (0,3):add('palette-bound',f'pal-bound-{length}-{map}-{start}',op=1,map=map,length=length,start=start,panic=panic if map==1 else None)
        for d in (1,8,24,32,16):
            for op in (0,3):add('read-palette-bound',f'read-pal-bound-{length}-{d}-{op}',header(d=d,map=1,length=length),op,panic=panic if d!=16 else None)
    for kind,map in [(kind,0) for kind in (6,7,127,255,256,65534,65536,0x80000000,0xffffffff)]+[(0,map) for map in (3,4,127,255,256,0x80000000,0xffffffff)]+[(0xffffffff,0xffffffff)]:
        for op in (0,3):
            for start in (0,3):add('enum',f'enum-{kind}-{map}-{op}-{start}',header(w=0xffffffff,h=0xffffffff,kind=kind,map=map),op,start=start,panic='invalid enum value')
    return rows,traps

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('zig', type=Path)
    parser.add_argument('v', type=Path)
    parser.add_argument('--target', default='aarch64-macos.14.0')
    parser.add_argument('--v-prod', action='store_true')
    parser.add_argument('--workdir', type=Path)
    parser.add_argument('--timeout', type=int, default=180)
    args = parser.parse_args()
    if args.timeout <= 0:
        parser.error('--timeout must be positive')
    source = args.source.resolve() / 'src'
    zig = args.zig.resolve()
    v = args.v.resolve()
    if tree_hash(source) != PINNED_SOURCE_SHA256 or stdlib_hash(zig) != PINNED_STDLIB_SHA256:
        parser.error('Source or selected library differs from pins')
    repo = Path(__file__).resolve().parent.parent
    probe = repo / 'zigimg/reference_probes/ras_contracts'
    mode = 'ReleaseSafe' if args.v_prod else 'Debug'
    env = dict(os.environ, VEXE=str(v), V_C_ERROR_BUG_REPORT_DISABLED='1')
    with work_directory(args.workdir, 'witty-ras-contracts-') as root:
        proof = ProofLog(root)
        shutil.copytree(source, root / 'src')
        fixtures = {}
        for name in ('main.v', 'reference.zig'):
            shutil.copyfile(probe / name, root / name)
            fixtures[name] = hashlib.sha256((root / name).read_bytes()).hexdigest()
        versions = [proof.run([str(exe), 'version'], label, env=env).stdout.decode().strip()
                    for exe, label in ((zig, 'zig-version'), (v, 'v-version'))]
        if versions[0] != '0.15.2' or not re.match(r'^V 0\.5\.2(?: |$)', versions[1]):
            raise AssertionError('unexpected compiler versions')
        implementations = implementation_hashes(repo)
        runner_hash = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
        (root / 'provenance.json').write_text(json.dumps(dict(
            source_sha256=PINNED_SOURCE_SHA256, stdlib_sha256=PINNED_STDLIB_SHA256,
            versions=versions, target=args.target, zig_mode=mode, v_prod=args.v_prod,
            fixtures=fixtures, implementation_sha256=implementations, runner_sha256=runner_hash,
        ), indent=2) + '\n')
        zbase = [str(zig), 'build-exe', '-target', args.target, '-lc', '-O', mode,
                 '--global-cache-dir', str(root / 'zig-global')]
        vbase = [str(v), '-enable-globals', *(['-prod'] if args.v_prod else []),
                 '-path', f'{repo}|@vlib|@vmodules']
        print(f'Building RAS contracts: Source {mode}, V {"production" if args.v_prod else "ordinary"}', flush=True)
        proof.run(zbase + ['-femit-bin=' + str(root / 'native'), str(root / 'reference.zig')],
                  'build-source', timeout=args.timeout)
        proof.run(vbase + ['-o', str(root / 'translated'), str(root / 'main.v')],
                  'build-v', env=env, timeout=args.timeout)
        outputs = []
        for exe in ('native', 'translated'):
            result = proof.run([str(root / exe)], 'records-' + exe, timeout=args.timeout)
            if result.stderr:
                raise AssertionError('unexpected records stderr')
            outputs.append(result.stdout)
        if outputs[0] != outputs[1] or len(outputs[0].splitlines()) != EXPECTED_MAIN:
            raise AssertionError('header/write records differ')
        main_digest = hashlib.sha256(b'\n'.join(outputs[0].splitlines())).hexdigest()
        if main_digest != EXPECTED_MAIN_SHA256:
            raise AssertionError('main golden changed: ' + main_digest)
        returns = hashlib.sha256()
        states = hashlib.sha256()
        return_groups = Counter()
        trap_groups = Counter()
        inputs = {}
        debug=[]
        for exe in ('native','translated'):
            result=proof.run([str(root/exe),'--debug'],'debug-'+exe,timeout=args.timeout)
            if result.stdout:raise AssertionError('unexpected debug stdout')
            debug.append(result.stderr)
        if debug[0]!=debug[1] or len(debug[0].splitlines())!=105:raise AssertionError('debug records differ')
        debug_digest=hashlib.sha256(debug[0]).hexdigest()
        if debug_digest!=EXPECTED_DEBUG_SHA256:raise AssertionError('debug golden changed')
        rows,traps=corpus()
        file=root/'corpus.txt'
        file.write_text('\n'.join(row for group,name,row in rows)+'\n')
        inputs[file.name]=hashlib.sha256(file.read_bytes()).hexdigest()
        outputs=[]
        for exe in ('native','translated'):
            result=proof.run([str(root/exe),'--corpus',str(file)],'corpus-'+exe,timeout=args.timeout)
            if result.stderr:raise AssertionError('unexpected corpus stderr')
            outputs.append(result.stdout.splitlines())
        if any(len(output)!=len(rows) for output in outputs):raise AssertionError('corpus count differs')
        for (group,name,line),native,translated in zip(rows,*outputs):
            if native!=translated:raise AssertionError(f'{name}: {native!r} != {translated!r}')
            returns.update(name.encode()+b'\0'+native+b'\n');return_groups[group]+=1
        def compare(group,name,arguments,message=None):
            records=[]
            for exe in ('native','translated'):
                path=root/(name+'-'+exe+'.state')
                command=[str(root/exe)]+[str(path) if arg is None else str(arg) for arg in arguments]
                records.append((proof.run(command,name+'-'+exe,timeout=args.timeout,check=False),path))
            if message is not None:
                for (result,path),exe in zip(records,('native','translated')):
                    checked_trap(result,name+'/'+exe,message)
                    messages=[m.group(1) for line in result.stderr.decode().splitlines()
                              if (m:=re.fullmatch(r'(?:thread \d+ |V )?panic:\s*(.*)',line.strip()))]
                    if messages != [message] or not path.exists():raise AssertionError('exact panic or state missing')
                snapshots=[path.read_bytes() for result,path in records]
                if not snapshots[0] or snapshots[0]!=snapshots[1]:raise AssertionError(f'{name}: state differs {snapshots}')
                states.update(name.encode()+b'\0'+message.encode()+b'\0'+snapshots[0]+b'\n')
                trap_groups[group]+=1
            else:
                native,translated=[record[0] for record in records]
                if (native.returncode or translated.returncode or native.stderr or translated.stderr
                        or native.stdout!=translated.stdout or len(native.stdout.splitlines())!=1):
                    raise AssertionError(f'{name}: returns differ {native.stdout!r} {translated.stdout!r}')
                returns.update(name.encode()+b'\0'+native.stdout);return_groups[group]+=1
        for group,name,row,message in traps:
            inputs[name+'.txt']=hashlib.sha256(row.encode()).hexdigest()
            (root/(name+'.txt')).write_text(row)
            compare(group,name,['--case',None,row],message)

        from verify_simd_reference import ordinary_rejection
        consumer_hashes={}
        def pair(label,zbody,vbody,zmarker=None,vmarker=None):
            paths=[root/(label+'.zig'),root/(label+'.v')]
            paths[0].write_text('const p=@import("src/formats/ras.zig");pub fn main() void {'+zbody+'}\n')
            paths[1].write_text('module main\nimport zigimg as p\nfn main(){\n'+vbody+'\n}\n')
            for path in paths:consumer_hashes[path.name]=hashlib.sha256(path.read_bytes()).hexdigest()
            for language,command,marker in (
                ('Source',zbase+['-fno-emit-bin',str(paths[0])],zmarker),
                ('V',vbase+['-check','-o',str(root/(label+'-checked')),str(paths[1])],vmarker)):
                result=proof.run(command,label+'-'+language,env=env,timeout=args.timeout,check=False)
                diagnostic=(result.stdout+result.stderr).decode(errors='replace')
                errors=[line for line in diagnostic.splitlines() if re.search(r'\berror:',line)]
                if marker is None:
                    if result.returncode or errors:raise AssertionError(f'{label}/{language}: expected acceptance\n{diagnostic}')
                else:
                    ordinary_rejection(result,label+'/'+language)
                    if not any(marker in line for line in errors):raise AssertionError(f'{label}/{language}: diagnostic missing {marker!r}\n{diagnostic}')
        fields={'width':('width','1'),'height':('height','2'),'depth':('depth','8'),'length':('length','0'),'type':('type_','.old'),'color_map_type':('color_map_type','.no_color_map'),'color_map_length':('color_map_length','0')}
        for missing in (None,*fields):
            zfields=','.join('.'+key+'='+value for key,(vkey,value) in fields.items() if key!=missing)
            vfields=','.join(vkey+':'+value for key,(vkey,value) in fields.items() if key!=missing)
            pair('Header-'+str(missing),'const Header=@TypeOf((p.RAS{}).header);const x:Header=.{'+zfields+'};_=x;',
                 'x:=p.RasHeader{'+vfields+'}\n_=x',
                 'missing struct field: '+missing if missing else None,
                 'RasHeader.'+fields[missing][0] if missing else None)
        pair('default-codec','const x:p.RAS=.{};_=x;','x:=p.RAS{}\n_=x')
        (root/'consumer_sha256.json').write_text(json.dumps(consumer_hashes,indent=2)+'\n')
        for name,digest in consumer_hashes.items():
            if hashlib.sha256((root/name).read_bytes()).hexdigest()!=digest:raise AssertionError('consumer changed')
        (root / 'input_sha256.json').write_text(json.dumps(inputs, indent=2) + '\n')
        for name, digest in inputs.items():
            if hashlib.sha256((root / name).read_bytes()).hexdigest() != digest:
                raise AssertionError('input changed')
        return_digest = returns.hexdigest()
        state_digest = states.hexdigest()
        if sum(return_groups.values()) != EXPECTED_RETURNS or sum(trap_groups.values()) != EXPECTED_TRAPS:
            raise AssertionError('return or trap count changed')
        if return_digest != EXPECTED_RETURN_SHA256:
            raise AssertionError('return golden changed')
        if state_digest != EXPECTED_STATE_SHA256:
            raise AssertionError('state golden changed')
        if (tree_hash(source) != PINNED_SOURCE_SHA256 or tree_hash(root / 'src') != PINNED_SOURCE_SHA256
                or stdlib_hash(zig) != PINNED_STDLIB_SHA256 or implementation_hashes(repo) != implementations
                or hashlib.sha256(Path(__file__).read_bytes()).hexdigest() != runner_hash):
            raise AssertionError('dependency, implementation or runner changed')
        for name, expected in fixtures.items():
            if any(hashlib.sha256((base / name).read_bytes()).hexdigest() != expected for base in (root, probe)):
                raise AssertionError('fixture changed')
        summary = dict(main_records=EXPECTED_MAIN, main_sha256=main_digest,
                       returning_records=sum(return_groups.values()), return_groups=dict(return_groups),
                       return_sha256=return_digest, paired_traps=sum(trap_groups.values()),
                       failure_groups=dict(trap_groups), state_sha256=state_digest, complete_constructor_pairs=1, required_field_pairs=7, default_codec_pairs=1, debug_records=21, debug_sha256=debug_digest,
                       zig_mode=mode, v_prod=args.v_prod)
        (root / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
        print(json.dumps(summary), flush=True)


if __name__ == '__main__':
    main()
