"""Compare RAS file buffering, planar palettes, RLE and retained decoder state."""
import argparse
from collections import Counter
import hashlib
import itertools
import json
import os
from pathlib import Path
import re
import shutil

from verify_jpeg_contracts_reference import implementation_hashes
from verify_tiff_decode_reference import ProofLog, tree_hash, work_directory, PINNED_SOURCE_SHA256, checked_trap

EXPECTED_ROWS = 112257
EXPECTED_SHA256 = "24e88e917661659d42a811e1ac966007b1ab68e789e96b88991feac2e2b27cc2"
EXPECTED_STATE_SHA256 = "d728a122e314600960d6ffbce39ff896bd24bef7e61f9d8c2c917f7ef55e28a4"
from verify_tga_decode_reference import stdlib_hash, PINNED_STDLIB_SHA256
from verify_ras_contracts_reference import KINDS, header, row_bytes, encode

PUBLIC_BUFFERS=(-1,28,32,64,128)
HELPER_BUFFERS=(-1,0,1,3,4,8,16,28,32,64,128)


def spec(cap,op=0,kind=0,map=0,length=0,output=0,start=0,attempts=2,data=b''):
    return '|'.join(str(value) for value in (cap,op,kind,map,length,output,start,attempts,(b'x'*start+data).hex()))


def raster(w=1,h=1,d=8,kind=0,map=0,length=0):
    raw=bytes((i*37+19)&255 for i in range(row_bytes(w,d)*h))
    colors=bytes((i*71+31)&255 for i in range(length)) if map==1 else b''
    return header(w,h,d,kind,map,length)+colors+encode(raw,kind)+b'tail'


def corpus():
    rows=[]
    def add(group,data,op=0,kind=0,map=0,length=0,output=0,start=0,caps=PUBLIC_BUFFERS):
        for cap in caps:rows.append((group,spec(cap,op,kind,map,length,output,start,data=data)))
    for flag,cut,output in itertools.product(range(256),(0,1),(0,1,2)):
        add('rle-flags',bytes((flag,))[:cut],2,2,output=output,caps=(-1,1,3,8,32))
    for count,value,cut,output in itertools.product(range(256),(0,128),range(4),(0,1,2,3,255,256,257)):
        add('rle-runs',bytes((128,count,value))[:cut],2,2,output=output,caps=(-1,1,3,8,32))
    for kind,cut,output in itertools.product(KINDS,range(5),(0,1,2,3,4,257)):
        add('raw-and-unsupported',bytes((1,128,2,3))[:cut],2,kind,output=output,caps=tuple(cap for cap in HELPER_BUFFERS if not (cap==0 and kind==2 and output>0)))
    for map,length in itertools.product((0,1,2),(*range(10),765,768,769,770)):
        full=bytes((i*37+19)&255 for i in range(length+3))
        for cut in sorted({0,1,length//2,max(0,length-1),length,len(full)}):
            add('planar-palettes',full[:cut],1,map=map,length=length,caps=HELPER_BUFFERS)
    for d,kind,dims,mapping,op in itertools.product((1,8,24,32),KINDS,((0,0),(1,1),(3,2),(7,1),(9,2),(17,1)),((0,0),(1,0),(1,6),(0,6),(2,6)),(0,3,5)):
        w,h=dims;map,length=mapping
        if d==1 and length>0 and map in (0,1) and kind in (0,1,2,3) and w*h>row_bytes(w,d)*h:continue
        add('public-decoding',raster(w,h,d,kind,map,length),op)
    for d,kind,op,start in itertools.product((1,8,24,32),(0,2),(0,3,5),(0,3)):
        data=raster(3,2,d,kind,1,6) if d!=1 else raster(1,2,d,kind,1,6)
        for cut in range(len(data)+1):add('public-prefix-retry',data[:cut],op,start=start)
    for d,op in itertools.product((1,8,24,32),(0,3,5)):
        add('wide-zero-height',header(0xffffffff,0,d),op)
    for depth,map,length,op in itertools.product((0,2,16),(0,1,2),(0,6,771),(0,3,5)):
        add('validation-order',header(d=depth,map=map,length=length),op)
    for byte,op in itertools.product(range(256),(4,6)):
        add('detection-byte',bytes((byte,166,106,149)),op,caps=(-1,4,8,32))
    for data,op,start in itertools.product((b'',b'\x59\xa6\x6a',b'\x59\xa6\x6a\x95',b'nope'),(4,6),(0,3)):
        add('detection-prefix',data,op,start=start,caps=(-1,4,8,32))
    return rows


def traps():
    cases={}
    for cap,op in itertools.product((0,1,3),(0,3,4,5,6)):
        cases[f'small-magic-{cap}-{op}']=(spec(cap,op,attempts=1,data=raster()),'reached unreachable code')
    for cap,op in itertools.product((4,8,16,27),(0,3,5)):
        cases[f'small-header-{cap}-{op}']=(spec(cap,op,attempts=1,data=raster()),'reached unreachable code')
    for cap,op,enums in itertools.product((28,32,64),(0,3,5),((6,0),(0,3),(0xffffffff,0xffffffff))):
        kind,map=enums
        cases[f'enums-{cap}-{op}-{kind}-{map}']=(spec(cap,op,attempts=1,data=header(kind=kind,map=map)),'invalid enum value')
    for length in (771,772,773,65535,0xffffffff):
        for cap in (-1,0,1,32):
            cases[f'direct-palette-{cap}-{length}']=(spec(cap,1,map=1,length=length,attempts=1),'index out of bounds')
        for cap,op,d in itertools.product((28,32,64),(0,3,5),(1,8,24,32)):
            cases[f'public-palette-{cap}-{op}-{d}-{length}']=(spec(cap,op,attempts=1,data=header(d=d,map=1,length=length)),'index out of bounds')
    for cap,op,w,h,kind in itertools.product((28,32,64),(0,3,5),(3,7,17),(1,2),(0,2)):
        cases[f'indexed-bits-{cap}-{op}-{w}-{h}-{kind}']=(spec(cap,op,attempts=1,data=raster(w,h,1,kind,1,6)),'index out of bounds')
    for output in (1,2,3,4,257):
        cases[f'zero-buffer-rle-{output}']=(spec(0,2,kind=2,output=output,attempts=1,data=b'\x80\xff\x07'),'reached unreachable code')
    return cases


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
    if args.timeout <= 0: parser.error('--timeout must be positive')
    source = args.source.resolve() / 'src'
    zig, v = args.zig.resolve(), args.v.resolve()
    if tree_hash(source) != PINNED_SOURCE_SHA256 or stdlib_hash(zig) != PINNED_STDLIB_SHA256:
        parser.error('Source or selected compiler library differs from the pins')
    mode = 'ReleaseSafe' if args.v_prod else 'Debug'
    repo = Path(__file__).resolve().parent.parent
    probe = repo / 'zigimg/reference_probes/ras_streams'
    env = dict(os.environ, VEXE=str(v), V_C_ERROR_BUG_REPORT_DISABLED='1')
    with work_directory(args.workdir, 'witty-ras-streams-') as root:
        tmp=root/'tmp';tmp.mkdir()
        env.update(TMPDIR=str(tmp),VTMP=str(tmp))
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
        helpers={name:hashlib.sha256((repo/'zigimg'/name).read_bytes()).hexdigest() for name in ('verify_jpeg_contracts_reference.py','verify_tiff_decode_reference.py','verify_tga_decode_reference.py','verify_ras_contracts_reference.py')}
        implementations = implementation_hashes(repo)
        runner_hash = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
        (root / 'provenance.json').write_text(json.dumps(dict(
            source_revision='d7b7ab0ba0899643831ef042bd73289510b39906',
            source_sha256=PINNED_SOURCE_SHA256, stdlib_sha256=PINNED_STDLIB_SHA256,
            versions=versions, target=args.target, zig_mode=mode, v_prod=args.v_prod, helper_sha256=helpers,
            fixtures=fixtures, implementation_sha256=implementations, runner_sha256=runner_hash), indent=2) + '\n')
        print(f'Building RAS streams: Source {mode}, V {"production" if args.v_prod else "ordinary"}', flush=True)
        proof.run([str(zig), 'build-exe', '-target', args.target, '-lc', '-O', mode,
                   '--global-cache-dir', str(root.parent / 'zig-global'), '--cache-dir', str(root/'zig-cache'), '-femit-bin=' + str(root / 'native'),
                   str(root / 'reference.zig')], 'build-source', env=env, timeout=args.timeout)
        proof.run([str(v), '-enable-globals', *(['-prod'] if args.v_prod else []), '-path',
                   f'{repo}|@vlib|@vmodules', '-o', str(root / 'translated'), str(root / 'main.v')],
                  'build-v', env=env, timeout=args.timeout)
        rows = corpus()
        corpus_path = root / 'corpus.txt'
        corpus_path.write_text('\n'.join(data for _, data in rows) + '\n')
        input_hash=hashlib.sha256(corpus_path.read_bytes()).hexdigest()
        (root/'input_sha256.json').write_text(json.dumps({'corpus.txt':input_hash},indent=2)+'\n')
        outputs = []
        for exe in ('native', 'translated'):
            r = proof.run([str(root / exe), str(corpus_path)], 'returning-' + exe, env=env, timeout=args.timeout, check=False)
            if r.returncode or r.stderr or len(r.stdout.splitlines()) != len(rows):
                raise AssertionError(f'{exe}: invalid returning output ({r.returncode}, {len(r.stdout.splitlines())} rows); see raw proof files')
            outputs.append(r.stdout.splitlines())
        for index, (native, translated) in enumerate(zip(*outputs)):
            if native != translated:
                raise AssertionError(f'{index}/{rows[index][0]}: Source={native[:200]!r}, V={translated[:200]!r}; see retained corpus/output')
        digest = hashlib.sha256(b'\n'.join(outputs[0])).hexdigest()
        if EXPECTED_ROWS is not None and len(rows) != EXPECTED_ROWS: raise AssertionError('corpus changed')
        if EXPECTED_SHA256 is not None and digest != EXPECTED_SHA256: raise AssertionError('returning golden changed')
        print(f'{len(rows)} returning rows match; checking failure state', flush=True)
        states = hashlib.sha256()
        for name, (data, category) in traps().items():
            observed = []
            native_message = None
            for exe in ('native','translated'):
                path = root / (name + '-' + exe + '.state')
                r = proof.run([str(root / exe), '--trap', str(path), data], name + '-' + exe,
                              env=env, timeout=args.timeout, check=False)
                checked_trap(r, name + '/' + exe, category)
                messages=[match.group(1) for line in r.stderr.decode().splitlines() if (match:=re.fullmatch(r'(?:thread \d+ |V )?panic:\s*(.*)',line.strip()))]
                if len(messages)!=1:raise AssertionError(f'{name}/{exe}: expected sole panic: {messages}')
                if exe=='native':
                    native_message=messages[0]
                    if category=='index out of bounds' and not re.fullmatch(r'index out of bounds: index \d+, len \d+',native_message):raise AssertionError('unexpected Source bounds diagnostic')
                    if category not in ('index out of bounds','access of union field') and native_message!=category:raise AssertionError('unexpected Source panic')
                elif messages!=[native_message]:raise AssertionError(f'{name}/{exe}: exact panic differs: {messages} != {[native_message]}')
                if not path.exists(): raise AssertionError('missing panic observer')
                observed.append(path.read_bytes())
            if not observed[0] or observed[0] != observed[1]: raise AssertionError(f'{name}: differing states {observed}')
            states.update(name.encode() + b'\0' + native_message.encode() + b'\0' + observed[0] + b'\n')
        state_digest = states.hexdigest()
        if EXPECTED_STATE_SHA256 is not None and state_digest != EXPECTED_STATE_SHA256: raise AssertionError('failure-state golden changed')
        if (tree_hash(source) != PINNED_SOURCE_SHA256 or tree_hash(root / 'src') != PINNED_SOURCE_SHA256
                or stdlib_hash(zig) != PINNED_STDLIB_SHA256 or implementation_hashes(repo) != implementations
                or hashlib.sha256(Path(__file__).read_bytes()).hexdigest() != runner_hash):
            raise AssertionError('dependency, implementation or runner changed')
        for name, expected in fixtures.items():
            if any(hashlib.sha256((p / name).read_bytes()).hexdigest() != expected for p in (root, probe)):
                raise AssertionError('fixture changed')
        if hashlib.sha256(corpus_path.read_bytes()).hexdigest()!=input_hash:raise AssertionError('input changed')
        for name,expected in helpers.items():
            if hashlib.sha256((repo/'zigimg'/name).read_bytes()).hexdigest()!=expected:raise AssertionError('helper changed')
        summary = dict(returning_records=len(rows), returning_groups=dict(Counter(group for group, _ in rows)),
                       calls=sum(int(data.split('|')[7]) for _,data in rows), output_sha256=digest,
                       paired_traps=len(traps()), state_sha256=state_digest, zig_mode=mode, v_prod=args.v_prod)
        (root / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
        print(json.dumps(summary), flush=True)


if __name__ == '__main__':
    main()
