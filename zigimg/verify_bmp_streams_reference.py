"""Compare BMP file buffering, complete/partial decoding, encoding and retained state."""
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

EXPECTED_ROWS = 28826
EXPECTED_SHA256 = 'e66348bd94ed11482b88a9abc8ad371e80ff29b60487793ba2aee6f68abfadc4'
EXPECTED_STATE_SHA256 = '4226d2b1d73e7da2d286f02ed7be91e64cfaede2dbd6b3652327d8a8c76b5b78'
from verify_tga_decode_reference import stdlib_hash, PINNED_STDLIB_SHA256
from verify_bmp_contracts_reference import header, BGR24, BGRA32, GRAY8

WRITE_BUFFERS=(-1,0,1,3,4,8,13,14,40,108,122,124,128,256)


def spec(cap,op=0,kind=108,w=1,h=1,fmt=BGR24,count=1,pattern=0,start=0,attempts=2,data=b''):
    return '|'.join(str(value) for value in (cap,op,kind,w,h,fmt,count,pattern,start,attempts,data.hex()))


def read_buffers(kind):return (-1,kind,128,256)


def corpus():
    rows=[]
    def read(group,data,kind=108,op=0,start=0):
        for cap in read_buffers(kind):rows.append((group,spec(cap,op,kind,start=start,data=b'x'*start+data)))
    for kind,bits,w,h,pattern,op in itertools.product((108,124),(24,32),(0,1,2,3,8,17),(0,1,2,3),(0,1,2),(0,1,2)):
        raw=bytes((i*37+19)&255 if pattern==0 else 0 if pattern==1 else 255 for i in range(w*h*(bits//8)))
        read('complete-decoding',header(kind,w,h,bits)+raw+b'tail',kind,op)
    for kind,bits,op,start in itertools.product((108,124),(24,32),(0,1,2),(0,3)):
        data=header(kind,1,2,bits)+bytes(range(2*(bits//8)))
        for cut in range(len(data)+1):read('decode-prefix-retry',data[:cut],kind,op,start)
    for kind,op,size in itertools.product((108,124),(0,1,2),(0,1,39,41,107,109,123,125,0xffffffff)):
        import struct
        read('unknown-header-size',struct.pack('<2s4I',b'BM',1,2,3,size),kind,op)
    for kind,op in itertools.product((40,108,124),(0,1,2)):
        for bits,compression,magic in ((16,0,b'BM'),(24,3,b'BM'),(32,0,b'BM'),(24,0,b'XY')):
            read('validation-before-arithmetic',header(kind,2147483647,2,bits,compression,magic),kind,op)
    for kind,dims in itertools.product((108,124),((-1,-1),(-2,-1),(-3,0),(0,-3))):
        w,h=dims;read('negative-direct-metadata',header(kind,w,h),kind,0)
    for byte,op in itertools.product(range(256),(3,4)):
        for cap in (-1,2,8,128):rows.append(('detector-byte',spec(cap,op,data=bytes((byte,77)))))
    for data,op,start in itertools.product((b'',b'B',b'BM',b'XY'),(3,4),(0,3)):
        for cap in (-1,2,8,128):rows.append(('detector-prefix',spec(cap,op,start=start,data=b'x'*start+data)))
    for cap,op,kind,fmt,dims,pattern,start in itertools.product(WRITE_BUFFERS,(5,6,7),(40,108,124),(BGR24,BGRA32,GRAY8),((0,0),(1,1),(2,1),(1,2),(3,2),(0,3),(3,0)),(0,1,2),(0,7)):
        if op!=5 and kind!=108:continue
        w,h=dims
        rows.append(('buffered-encoding',spec(cap,op,kind,w,h,fmt,w*h,pattern,start)))
    for cap,op,kind,fmt,dims in itertools.product(WRITE_BUFFERS,(5,6,7),(40,108,124),(BGR24,BGRA32,GRAY8),((-2147483648,1),(-1,2),(1,-2),(-1,-2),(2147483647,0))):
        if op!=5 and (kind!=108 or min(dims)<0):continue
        w,h=dims;rows.append(('signed-and-zero-encoding',spec(cap,op,kind,w,h,fmt,count=0)))
    for cap,op,fmt,dims in itertools.product(WRITE_BUFFERS,(6,7),(BGR24,BGRA32,GRAY8),((2**64-1,2),(2**32,0),(0,2**64-1))):
        if fmt!=GRAY8:continue
        w,h=dims;rows.append(('unsupported-before-size',spec(cap,op,w=w,h=h,fmt=fmt,count=0)))
    return rows


def traps():
    cases={}
    for cap,op in itertools.product((0,1,13),(0,1,2)):
        cases[f'small-file-header-{cap}-{op}']=(spec(cap,op,attempts=1,data=header()),'reached unreachable code')
    for cap,op in itertools.product((0,1),(3,4)):
        cases[f'small-detector-{cap}-{op}']=(spec(cap,op,attempts=1,data=b'BM'),'reached unreachable code')
    for kind,op in itertools.product((108,124),(0,1,2)):
        for cap in ((14,40,107) if kind==108 else (14,40,108,123)):
            cases[f'small-info-header-{cap}-{op}-{kind}']=(spec(cap,op,attempts=1,data=header(kind)),'reached unreachable code')
        for w,h,message in ((46341,46341,'integer overflow'),(-1,1,'integer does not fit in destination type'),(0,-2147483648,'integer overflow')):
            cases[f'read-arithmetic-{kind}-{op}-{w}-{h}']=(spec(kind,op,attempts=1,data=header(kind,w,h)) ,message)
        if op!=0:
            cases[f'read-negative-cast-{kind}-{op}']=(spec(kind,op,attempts=1,data=header(kind,-1,-1)),'integer does not fit in destination type')
    for cap,op,kind,fmt in itertools.product((0,1,8,14,128,256),(5,6,7),(108,124),(BGR24,BGRA32)):
        if op!=5 and kind!=108:continue
        cases[f'short-pixels-{cap}-{op}-{kind}-{fmt}']=(spec(cap,op,kind,w=2,h=1,fmt=fmt,count=1,attempts=1),'index out of bounds')
        if op==5:cases[f'minimum-height-{cap}-{kind}-{fmt}']=(spec(cap,op,kind,w=0,h=-2147483648,fmt=fmt,count=0,attempts=1),'integer overflow')
    for cap,op,fmt,dims in itertools.product((0,1,8,128,256),(6,7),(BGR24,BGRA32),((2**64-1,2),(2147483648,0),(2**32,1))):
        w,h=dims;message='integer overflow' if w==2**64-1 else 'integer does not fit in destination type'
        cases[f'image-size-{cap}-{op}-{fmt}-{w}-{h}']=(spec(cap,op,w=w,h=h,fmt=fmt,count=0,attempts=1),message)
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
    probe = repo / 'zigimg/reference_probes/bmp_streams'
    env = dict(os.environ, VEXE=str(v), V_C_ERROR_BUG_REPORT_DISABLED='1')
    with work_directory(args.workdir, 'witty-bmp-streams-') as root:
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
        helpers={name:hashlib.sha256((repo/'zigimg'/name).read_bytes()).hexdigest() for name in ('verify_jpeg_contracts_reference.py','verify_tiff_decode_reference.py','verify_tga_decode_reference.py','verify_bmp_contracts_reference.py')}
        implementations = implementation_hashes(repo)
        runner_hash = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
        (root / 'provenance.json').write_text(json.dumps(dict(
            source_revision='d7b7ab0ba0899643831ef042bd73289510b39906',
            source_sha256=PINNED_SOURCE_SHA256, stdlib_sha256=PINNED_STDLIB_SHA256,
            versions=versions, target=args.target, zig_mode=mode, v_prod=args.v_prod, helper_sha256=helpers,
            fixtures=fixtures, implementation_sha256=implementations, runner_sha256=runner_hash), indent=2) + '\n')
        print(f'Building BMP streams: Source {mode}, V {"production" if args.v_prod else "ordinary"}', flush=True)
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
                       calls=sum(int(data.split('|')[9]) for _,data in rows), output_sha256=digest,
                       paired_traps=len(traps()), state_sha256=state_digest, zig_mode=mode, v_prod=args.v_prod)
        (root / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
        print(json.dumps(summary), flush=True)


if __name__ == '__main__':
    main()
