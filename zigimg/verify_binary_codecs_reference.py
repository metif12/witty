"""Compare QOI/Farbfeld file buffering, decoding, encoding and retained state."""
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

EXPECTED_ROWS = 106592
EXPECTED_SHA256 = '7abf69c3eda1b41dd0a66979fe7272843274074faf1f2ceab98e069bd97a268d'
EXPECTED_STATE_SHA256 = '1495d4ae12287494280220e6c8ef80f4dde127b7a8d5fb4161a1ed4707f3fad4'
from verify_tga_decode_reference import stdlib_hash, PINNED_STDLIB_SHA256
from verify_netpbm_contracts_reference import FORMATS

WRITE_BUFFERS=(0,1,2,3,4,8,10,14,16,32,64,128)


def spec(capacity,op=0,kind=0,start=0,attempts=2,w=17,h=19,fmt=3,space=1,pixel=0x410,count=1,pattern=0,option=9,data=b''):
    return '|'.join(map(str,(capacity,op,kind,start,attempts,w,h,fmt,space,pixel,count,pattern,option,data.hex())))


def ff_header(w=1,h=1):return b'farbfeld'+w.to_bytes(4,'big')+h.to_bytes(4,'big')
def qoi_header(w=1,h=1,fmt=4,space=0):return b'qoif'+w.to_bytes(4,'big')+h.to_bytes(4,'big')+bytes((fmt,space))
def buffers(kind):return (-1,8,16,32,64) if kind==0 else (-1,10,16,32,64)


def corpus():
    rows=[]
    def read(group,kind,data):
        for cap,op in itertools.product(buffers(kind),(0,1,5)):
            rows.append((group,spec(cap,op,kind,data=data)))
    for w,h in ((0,0),(0,0xffffffff),(0xffffffff,0),(1,1),(2,1),(1,2),(3,2)):
        body=b''.join(((i*997+19)&65535).to_bytes(2,'big') for i in range(w*h*4))
        data=ff_header(w,h)+body+b'tail'
        read('farbfeld-complete',0,data)
        for cut in range(len(data)+1):read('farbfeld-prefix',0,data[:cut])
    for fmt,space,w in itertools.product((3,4),(0,1),(0,1,2,62,63)):
        packet=b'' if w==0 else b'\xfe\x13\x38\x5d'+(bytes((0xc0+w-2,)) if 1<w<=63 else b'')
        read('qoi-complete-runs',1,qoi_header(w,1,fmt,space)+packet+b'\0'*7+b'\1tail')
    for packet,w in ((b'\xfe\x13\x38\x5d',1),(b'\xff\x13\x38\x5d\x07',1),(bytes((254,10,20,30,127,162,151,255,100,150,200,50,193,9,0)),8)):
        for fmt in (3,4):
            data=qoi_header(w,1,fmt)+packet+b'\0'*7+b'\1tail'
            for cut in range(len(data)+1):read('qoi-prefix',1,data[:cut])
    for byte in range(64,192):
        packet=bytes((byte,151)) if byte>=128 else bytes((byte,))
        read('qoi-diff-luma',1,qoi_header()+packet)
    for byte in range(64):read('qoi-index',1,qoi_header()+bytes((byte,)))
    for byte,count in itertools.product((192,193,252,253),(0,1,2,61,62,63)):
        read('qoi-run-extents',1,qoi_header(count,1)+bytes((byte,)))
    for kind in (0,1):
        data=ff_header()+bytes(8) if kind==0 else qoi_header()+b'\xc0'
        for cap,op in itertools.product(buffers(kind),(0,1,5)):
            rows.append(('discard-prefix',spec(cap,op,kind,start=3,data=b'xyz'+data)))
        for cap,magic in itertools.product(buffers(kind),(b'',b'x',b'farbfeld',b'qoif',b'wrongmagic')):
            rows.append(('repeated-detection',spec(cap,2,kind,attempts=3,data=magic)))
    for kind,cap,op,pixel,dims,count,start,space,option in itertools.product((0,1),WRITE_BUFFERS,(3,4,6),FORMATS,((0,0),(1,1),(2,1)),(0,1,2),(0,7),(0,1),(0,9)):
        if option==0 and space==1:continue
        w,h=dims
        rows.append(('buffered-encoding',spec(cap,op,kind,w=w,h=h,count=count,pixel=pixel,start=start,space=space,option=option)))
    for kind,cap,op,count,pattern in itertools.product((0,1),WRITE_BUFFERS,(3,4,6),(1,2,61,62,63,64,125,126),(0,1,2)):
        for pixel in ((0x410,) if kind==0 else (0x308,0x408)):
            rows.append(('run-boundary-encoding',spec(cap,op,kind,w=count,h=1,count=count,pixel=pixel,pattern=pattern)))
    for cap,op,dims,pixel in itertools.product(WRITE_BUFFERS,(3,4,6),((0xffffffff,0),(0,0xffffffff),(2**32,0),(0,2**64-1)),(0x308,0x408)):
        w,h=dims
        rows.append(('qoi-truncated-dimensions',spec(cap,op,1,w=w,h=h,pixel=pixel,count=1)))
    return rows


def traps():
    out={}
    for kind,cap,op in itertools.product((0,1),(0,1,3),(0,1,2,5)):
        data=ff_header()+bytes(8) if kind==0 else qoi_header()+b'\xc0'
        out[f'small-magic-{kind}-{cap}-{op}']=(spec(cap,op,kind,attempts=1,data=data),'reached unreachable code')
    for cap,op in itertools.product((4,8,9),(0,1,5)):
        out[f'small-qoi-header-{cap}-{op}']=(spec(cap,op,1,attempts=1,data=qoi_header()+b'\xc0'),'reached unreachable code')
    for cap,op,enums in itertools.product((10,16,64),(0,1,5),((0,0),(255,0),(3,2),(4,255),(255,255))):
        fmt,space=enums
        out[f'invalid-qoi-enums-{cap}-{op}-{fmt}-{space}']=(spec(cap,op,1,attempts=1,data=qoi_header(0,0,fmt,space)),'invalid enum value')
    for cap,op,pixel,dims in itertools.product((0,1,8,32,128),(4,6),(0,0x308,0x410),((2**32,1),(1,2**32),(2**64-1,2**64-1))):
        w,h=dims
        out[f'farbfeld-cast-{cap}-{op}-{pixel}-{w}-{h}']=(spec(cap,op,0,attempts=1,pixel=pixel,w=w,h=h),'integer does not fit in destination type')
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
    probe = repo / 'zigimg/reference_probes/binary_codecs'
    env = dict(os.environ, VEXE=str(v), V_C_ERROR_BUG_REPORT_DISABLED='1')
    with work_directory(args.workdir, 'witty-binary-codecs-') as root:
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
        print(f'Building Binary codecs: Source {mode}, V {"production" if args.v_prod else "ordinary"}', flush=True)
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
