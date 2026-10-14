"""Compare Netpbm file buffering, decoding, partial encoding and retained state."""
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

EXPECTED_ROWS = 55434
EXPECTED_SHA256 = 'aa52cfee6576b47ea915f11eb30023bddf503f837691f99970121c7a5691d375'
EXPECTED_STATE_SHA256 = '0d71dc9e305c4e35bb05fc8be37e5c72b467749b2549350ce308545fcca7ef81'
from verify_tga_decode_reference import stdlib_hash, PINNED_STDLIB_SHA256
from verify_netpbm_contracts_reference import FORMATS

BUFFERS = (-1,2,3,4,8,16,64)
WRITE_BUFFERS = (0,1,2,3,4,8,16,32,64,128)


def spec(capacity,op=0,codec=0,start=0,attempts=2,fmt=1,binary=0,w=7,h=9,maximum=123,pixel=0x108,count=1,option=8,data=b''):
    return '|'.join(map(str,(capacity,op,codec,start,attempts,fmt,binary,w,h,maximum,pixel,count,option,data.hex())))


def header(magic,w=1,h=1,maximum=255):
    return f'P{magic} {w} {h} '.encode()+(b'' if magic in (1,4) else f'{maximum} '.encode())


def corpus():
    rows=[]
    def read(group,data,*,start=0):
        for cap,codec,op in itertools.product(BUFFERS,range(3),(0,1,5)):
            rows.append((group,spec(cap,op,codec,start=start,data=data)))
    for magic,w,h,maximum in itertools.product(range(1,7),(0,1,7,8,9),(0,1,2),(1,255,256,1000)):
        if magic in (1,4) and maximum!=1:continue
        channels=3 if magic in (3,6) else 1
        values=[(i*37+19)&65535 for i in range(w*h*channels)]
        if magic==1:body=bytes(ord('0')+(i&1) for i in range(w*h))
        elif magic in (2,3):body=b' '.join(str(v).encode() for v in values)+b' '
        elif magic==4:body=bytes((i*37+19)&255 for i in range(((w+7)//8)*h))
        elif maximum>255:body=b''.join(v.to_bytes(2,'big') for v in values)
        else:body=bytes(v&255 for v in values)
        read('raster-shapes',header(magic,w,h,maximum)+body+b'TAIL')
    for magic in range(1,7):
        body=(b'0 1 2 3 4 5 ' if magic<=3 else bytes(range(18)))
        data=header(magic,3,2,1000)+body
        for cut in range(len(data)+1):read('header-raster-prefixes',data[:cut])
        read('long-comment',f'P{magic} '.encode()+b'#'+b'x'*257+b'\n3 2 '+(b'' if magic in (1,4) else b'1000 ')+body)
        read('discard-prefix',b'xyz'+data,start=3)
    for token in (b'1#abc\n2',b'+0_1',b'-0',b'-1',b'1__2',b'_1',b'0000000000000000',b'00000000000000000',b'123',b'123#unterminated'):
        read('number-comments-and-limits',header(3,1,1,255)+token+b' 2 3 ')
    for magic in (5,6):
        for ending in (b'\r\n',b'\n',b' '):
            read('binary-delimiter',header(magic)[:-1]+ending+bytes((1,2,3,4)))
    for cap,codec,data in itertools.product(BUFFERS,range(3),(b'',b'P',b'P1',b'P6',b'PX',b'X1')):
        rows.append(('repeated-detection',spec(cap,2,codec,attempts=3,data=data)))
    for cap,codec,op,pixel,binary,dimensions,start in itertools.product(WRITE_BUFFERS,range(3),(3,4,6),FORMATS,(0,1),((0,0),(1,1),(9,2)),(0,7)):
        w,h=dimensions;count=w*h
        rows.append(('buffered-encoding',spec(cap,op,codec,fmt=codec,binary=binary,w=w,h=h,maximum=1000,pixel=pixel,count=count,option=(6,8,10)[codec],start=start)))
    for cap,codec,fmt,binary in itertools.product(WRITE_BUFFERS,range(3),range(3),(0,1)):
        rows.append(('direct-format-rejection',spec(cap,3,codec,fmt=fmt,binary=binary,pixel=0x308,count=1,w=1,h=1)))
    for cap,codec,op,option,binary in itertools.product(WRITE_BUFFERS,range(3),(4,6),(0,6,8,10),(0,1)):
        pixel=(0x101,0x108,0x308)[codec]
        rows.append(('registry-options',spec(cap,op,codec,pixel=pixel,count=1,w=1,h=1,option=option,binary=binary)))
    return rows


def traps():
    out={}
    for cap,codec,op in itertools.product((0,1),range(3),(0,1,2,5)):
        out[f'small-reader-{cap}-{codec}-{op}']=(spec(cap,op,codec,attempts=1,data=header(1)+b'0'),'reached unreachable code')
    for cap,codec,magic,op in itertools.product((2,4,16,64),range(3),(3,5,6),(0,1,5)):
        body=b'1 2 3 ' if magic==3 else bytes((1,2,3))
        out[f'zero-divisor-{cap}-{codec}-{magic}-{op}']=(spec(cap,op,codec,attempts=1,data=header(magic,1,1,0)+body),'division by zero')
    for cap,codec,op in itertools.product((2,16,64),range(3),(0,1,5)):
        out[f'dimension-overflow-{cap}-{codec}-{op}']=(spec(cap,op,codec,attempts=1,data=header(2,9999999999999999,9999999999999999)),'integer overflow')
    for cap,op,dimensions,count in itertools.product((0,1,2,4,8,16,64),(3,4,6),((9,2),(0,2)),(0,1,9,10)):
        w,h=dimensions
        if w==0:continue
        out[f'pbm-short-row-{cap}-{op}-{count}']=(spec(cap,op,0,attempts=1,fmt=0,binary=1,w=w,h=h,maximum=1,pixel=0x101,count=count,option=6),'index out of bounds')
    return out


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
    probe = repo / 'zigimg/reference_probes/netpbm_streams'
    env = dict(os.environ, VEXE=str(v), V_C_ERROR_BUG_REPORT_DISABLED='1')
    with work_directory(args.workdir, 'witty-netpbm-streams-') as root:
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
        helpers={name:hashlib.sha256((repo/'zigimg'/name).read_bytes()).hexdigest() for name in ('verify_jpeg_contracts_reference.py','verify_tiff_decode_reference.py','verify_tga_decode_reference.py','verify_netpbm_contracts_reference.py')}
        implementations = implementation_hashes(repo)
        runner_hash = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
        (root / 'provenance.json').write_text(json.dumps(dict(
            source_revision='d7b7ab0ba0899643831ef042bd73289510b39906',
            source_sha256=PINNED_SOURCE_SHA256, stdlib_sha256=PINNED_STDLIB_SHA256,
            versions=versions, target=args.target, zig_mode=mode, v_prod=args.v_prod, helper_sha256=helpers,
            fixtures=fixtures, implementation_sha256=implementations, runner_sha256=runner_hash), indent=2) + '\n')
        print(f'Building Netpbm streams: Source {mode}, V {"production" if args.v_prod else "ordinary"}', flush=True)
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
                       calls=sum(int(data.split('|')[4]) for _,data in rows), output_sha256=digest,
                       paired_traps=len(traps()), state_sha256=state_digest, zig_mode=mode, v_prod=args.v_prod)
        (root / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
        print(json.dumps(summary), flush=True)


if __name__ == '__main__':
    main()
