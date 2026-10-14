"""Compare PAM file buffering, decoding, partial encoding and retained state."""
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

EXPECTED_ROWS = 38958
EXPECTED_SHA256 = 'fbbcf91a8bf9670108461609b06039bbd00bb41481d4f24b58e85c7e5354c671'
EXPECTED_STATE_SHA256 = '2aad431028fa6420aca4f1515b665731c4fdadfeac9364c799e2ad72ef671ca7'
from verify_tga_decode_reference import stdlib_hash, PINNED_STDLIB_SHA256
from verify_pam_contracts_reference import header, TUPLES, MAPPING, FORMATS

BUFFERS = (-1,3,4,8,16,64,129)
WRITE_BUFFERS = (0,1,2,3,4,8,16,32,64,128)


def spec(capacity,op=0,start=0,attempts=2,pixel=0x108,count=1,w=1,h=1,comments=0,option=5,data=b''):
    return '|'.join(map(str,(capacity,op,start,attempts,pixel,count,w,h,comments,option,data.hex())))


def corpus():
    rows=[]
    def read(group,data):
        for cap,op in itertools.product(BUFFERS,(0,1,5)):
            rows.append((group,spec(cap,op,data=data)))
    for depth,maximum in ((1,1),(2,1),(1,15),(2,255),(3,31),(4,255),(1,256),(2,1000),(3,65535),(4,65535)):
        values=[0,1,maximum//2,maximum]*(depth*3)
        body=b''.join(v.to_bytes(2 if maximum>255 else 1,'little') for v in values[:depth*6])
        data=header(3,2,depth,maximum)+body
        read('complete-raster',data)
        for cut in range(len(data)+1):read('header-raster-prefixes',data[:cut])
        for note in (b'#'+b'x'*257+b'\n',b'\n#one\r\n\t \v\f\n',b'WIDTH 7 ignored\nWIDTH 3\n'):
            read('long-and-comment-lines',header(3,2,depth,maximum,prefix=note)+body)
        for value in (maximum,maximum+1):
            if value<=65535:
                width=2 if maximum>255 else 1
                if value<(1<<(8*width)):read('component-validation',header(1,1,depth,maximum)+value.to_bytes(width,'little')*depth)
    first=header(1,1,3,255)+bytes((1,2,3))
    for second in (first,header(2,1,3,255)+bytes((1,2,3))*2,header(1,1,1,15)+b'\x01',header(1,1,3,65535)+b'\x01\0'*3):
        for ending in (b'',b'x',b'xy',b'xyz',b'P7\n'):
            read('sequences-and-trailing-data',first+second+ending)
    for data in (b'',b'P',b'P7',b'P7\n',b'P7 ',first):
        for cap in BUFFERS:
            rows.append(('repeated-detection',spec(cap,2,attempts=3,data=data)))
    for old,new in ((b'WIDTH 1',b'WIDTH +1'),(b'WIDTH 1',b'WIDTH -0'),(b'WIDTH 1',b'WIDTH 0__1'),(b'MAXVAL 255',b'MAXVAL 65536'),(b'DEPTH 1',b'DEPTH 9'),(b'ENDHDR',b'ENDHDRLONG'),(b'ENDHDR\n',b'ENDHDR'),(b'WIDTH 1',b'WIDTH\t1\r')):
        read('parser-errors', (header()+b'\x01').replace(old,new))
    for name in TUPLES:
        depth=(1,2,1,2,3,4)[TUPLES.index(name)]
        maximum=1 if name.startswith('BLACK') else 255
        for suffix in ('',' ','\r','\t'):
            read('tuple-rest',header(d=depth,maximum=maximum,tuple_name=name+suffix)+b'\x01'*depth)
    for cap,op in itertools.product(BUFFERS,(0,1,5)):
        rows.append(('discard-start',spec(cap,op,start=3,data=b'xyz'+first)))
    for cap,op,pixel,dimensions,comments,option,start in itertools.product(WRITE_BUFFERS,(3,4,6),FORMATS,((0,0),(1,1),(3,2)),(0,1,2),(0,5),(0,7)):
        w,h=dimensions
        if op==3 and option!=5 and pixel in MAPPING:continue
        if pixel==0x102 and w*h:continue
        rows.append(('buffered-encoding',spec(cap,op,start=start,pixel=pixel,count=w*h,w=w,h=h,comments=comments,option=option)))
    return rows


def traps():
    out={}
    for cap,op in itertools.product((0,1,2),(0,1,2,5)):
        out[f'small-reader-{cap}-{op}']=(spec(cap,op,attempts=1,data=header()+b'\x01'),'reached unreachable code')
    for cap,pixel,kind in itertools.product((0,1,4,16,64,128),(0x101,0x102,0x108,0x210,0x308,0x410),('wrong-option','short-pixels')):
        if kind=='short-pixels' and pixel==0x102:continue
        out[f'{kind}-{cap}-{pixel}']=(spec(cap,3,attempts=1,pixel=pixel,count=1,w=2,h=1,comments=2,option=0 if kind=='wrong-option' else 5),"access of union field" if kind=='wrong-option' else 'index out of bounds')
    for cap in (0,1,4,16,64,128):
        out[f'gray2-{cap}']=(spec(cap,3,attempts=1,pixel=0x102,count=1,comments=2),'reached unreachable code')
        out[f'dimension-overflow-{cap}']=(spec(max(cap,3),0,attempts=1,data=header(2**64-1,2)+b'\x01'),'integer overflow')
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
    probe = repo / 'zigimg/reference_probes/pam_streams'
    env = dict(os.environ, VEXE=str(v), V_C_ERROR_BUG_REPORT_DISABLED='1')
    with work_directory(args.workdir, 'witty-pam-streams-') as root:
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
        helpers={name:hashlib.sha256((repo/'zigimg'/name).read_bytes()).hexdigest() for name in ('verify_jpeg_contracts_reference.py','verify_tiff_decode_reference.py','verify_tga_decode_reference.py','verify_pam_contracts_reference.py')}
        implementations = implementation_hashes(repo)
        runner_hash = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
        (root / 'provenance.json').write_text(json.dumps(dict(
            source_revision='d7b7ab0ba0899643831ef042bd73289510b39906',
            source_sha256=PINNED_SOURCE_SHA256, stdlib_sha256=PINNED_STDLIB_SHA256,
            versions=versions, target=args.target, zig_mode=mode, v_prod=args.v_prod, helper_sha256=helpers,
            fixtures=fixtures, implementation_sha256=implementations, runner_sha256=runner_hash), indent=2) + '\n')
        print(f'Building PAM streams: Source {mode}, V {"production" if args.v_prod else "ordinary"}', flush=True)
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
                       calls=sum(int(data.split('|')[3]) for _,data in rows), output_sha256=digest,
                       paired_traps=len(traps()), state_sha256=state_digest, zig_mode=mode, v_prod=args.v_prod)
        (root / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
        print(json.dumps(summary), flush=True)


if __name__ == '__main__':
    main()
