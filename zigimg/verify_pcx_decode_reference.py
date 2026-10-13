"""Compare PCX memory/file decoding, padded RGB bounds and exact retained failures."""
import argparse
from collections import Counter
import hashlib
import itertools
import json
import os
from pathlib import Path
import re
import shutil
import struct

from verify_jpeg_contracts_reference import implementation_hashes, STDLIB_FILES as BASE_STDLIB_FILES
from verify_tiff_decode_reference import ProofLog, tree_hash, work_directory, PINNED_SOURCE_SHA256, checked_trap

EXPECTED_ROWS = 21480
EXPECTED_SHA256 = 'c5140357c6cdcd568260ef8f8def66a7b596de669070d3e98f2e8f2046d346cb'
EXPECTED_STATE_SHA256 = 'fbcc36d2d1b2bfd331bdde3f4280c1055fa9bea02ee9aa6b9ac2fc13f5214f7d'
BUFFERS = (0, 128, 129, 131, 257, 1024)
STDLIB_FILES = (*BASE_STDLIB_FILES, 'posix.zig')
PINNED_STDLIB_SHA256 = 'ed900ae630673721b5aca890da4d432f4f1bfbbb201d5e450861b8111ab9a27d'


def stdlib_hash(zig):
    digest = hashlib.sha256()
    for name in STDLIB_FILES:
        digest.update(name.encode() + b'\0')
        digest.update((zig.parent / 'lib/std' / name).read_bytes())
    return digest.hexdigest()


from verify_pcx_contracts_reference import header, encoded


def image(width=3, height=2, bpp=8, planes=1, stride=None, pattern=0, compression=1, padding=0):
    if stride is None:
        stride = (width+7)//8 if bpp == 1 else (width+1)//2 if bpp == 4 else width
    base = (width+7)//8 if bpp == 1 else (width+1)//2 if bpp == 4 else width
    raw = bytearray()
    for y in range(height):
        for plane in range(planes):
            raw += bytes(((i*31+y*47+plane*61+pattern*73)%255)+1 for i in range(base))
            raw += bytes([padding])*(stride-base)
    data = header(width,height,bpp,planes,stride,compression=compression)+encoded(raw)
    if bpp == 8 and planes == 1:
        data += b'\x0c'+bytes((i*17+pattern*29)&255 for i in range(768))
    return data


def corpus():
    rows=[]
    def add(group,data,buffers=BUFFERS,reads=1):
        for capacity in buffers:rows.append((group,f'{capacity}|{reads}|{data.hex()}'))
    for bpp,width,height,extra,pattern,compression in itertools.product((1,4,8),(1,2,3,7,8,9,16,17,31,32,63,64),(1,2,3),(0,1,4),(0,1,2),(0,1)):
        base=(width+7)//8 if bpp==1 else (width+1)//2 if bpp==4 else width
        add('indexed-shapes',image(width,height,bpp,stride=base+extra,pattern=pattern,compression=compression,padding=87))
    for width,height,extra,pattern,compression in itertools.product((1,2,3,4,7,8,9,16,17),(1,2,3),(0,1),(0,1,2),(0,1)):
        add('rgb-planes-padding',image(width,height,planes=3,stride=width+extra,pattern=pattern,compression=compression))
    # Runs span rows and padding; finish rejects the one remaining decoded byte.
    for bpp,width,height,stride,value,compression in itertools.product((1,4),(1,3,8),(1,2,3),(4,21),(1,63,192,255),(0,1)):
        required=stride*height
        for surplus in (0,1):
            raw=bytearray(b'\xc0\xc0');remaining=required+surplus
            while remaining:
                count=min(63,remaining);raw += bytes([192+count,value]);remaining-=count
            add('runs-cross-rows-finish',header(width,height,bpp,1,stride,compression=compression)+raw)
    # Retry every prefix of defined indexed and padded planar fixtures.
    for data in (image(9,2,bpp=1,stride=4),image(5,2,bpp=4,stride=4),image(3,2),image(3,2,planes=3,stride=4)):
        for cut in range(len(data)+1):
            # A fully decoded indexed8 body with total size below 769 traps
            # before seeking its palette; check those cases in isolated processes.
            if data[3] == 8 and data[65] == 1 and len(data)-769 <= cut < 769:continue
            add('prefixes-retry',data[:cut],reads=2)
    for fields in ({'id':7},{'version':6},{'planes':4},{'planes':2},{'bpp':2},{'bpp':4,'planes':3}):
        add('header-rejection',header(xmin=1,xmax=0,**fields),reads=2)
    # The VGA palette is sought from EOF, including before the pixel body.
    for size in (769,770,897,898,1024,2048):
        for marker in (0,12,255):
            data=bytearray(header(bpp=8)+b'\x01'+bytes(size-129))
            data[size-769]=marker
            add('vga-end-seek',bytes(data),reads=2)
    # EOF must win before a nonzero padding byte can reach its invalid destination.
    for width,component in itertools.product((1,3,7),(0,1,2)):
        raw=bytearray()
        for c in range(3):raw += bytes([17]) * width + b'\x00'
        cut=component*(width+1)+width
        add('rgb-eof-before-index',header(width,1,8,3,width+1)+encoded(raw[:cut]),reads=2)
    return rows


def traps():
    cases={}
    for width,height,component,value,capacity in itertools.product((1,3,4,7),(1,2),(0,1,2),(17,193),(0,128,257,1024)):
        raw=bytearray()
        for y in range(height):
            for c in range(3):raw += bytes([17])*width+b'\x00'
        raw[(height-1)*3*(width+1)+component*(width+1)+width]=value
        name=f'rgb-padding-{width}-{height}-{component}-{value}-{capacity}'
        data=header(width,height,8,3,width+1)+encoded(raw)
        cases[name]=(f'{capacity}|1|{data.hex()}',f'index out of bounds: index {width*height}, len {width*height}')
    data=image(3,2)
    for size,capacity in itertools.product((len(data)-769,256,768),(0,128,257,1024)):
        cases[f'vga-underflow-{size}-{capacity}']=(f'{capacity}|1|{data[:size].hex()}','integer overflow')
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
    probe = repo / 'zigimg/reference_probes/pcx_decode'
    env = dict(os.environ, VEXE=str(v), V_C_ERROR_BUG_REPORT_DISABLED='1')
    with work_directory(args.workdir, 'witty-pcx-decode-') as root:
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
        helpers={name:hashlib.sha256((repo/'zigimg'/name).read_bytes()).hexdigest() for name in ('verify_jpeg_contracts_reference.py','verify_tiff_decode_reference.py','verify_pcx_contracts_reference.py')}
        implementations = implementation_hashes(repo)
        runner_hash = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
        (root / 'provenance.json').write_text(json.dumps(dict(
            source_sha256=PINNED_SOURCE_SHA256, stdlib_sha256=PINNED_STDLIB_SHA256,
            versions=versions, target=args.target, zig_mode=mode, v_prod=args.v_prod, helper_sha256=helpers,
            fixtures=fixtures, implementation_sha256=implementations, runner_sha256=runner_hash), indent=2) + '\n')
        print(f'Building PCX decode: Source {mode}, V {"production" if args.v_prod else "ordinary"}', flush=True)
        proof.run([str(zig), 'build-exe', '-target', args.target, '-lc', '-O', mode,
                   '--global-cache-dir', str(root / 'zig-global'), '--cache-dir', str(root/'zig-cache'), '-femit-bin=' + str(root / 'native'),
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
            for exe in ('native','translated'):
                path = root / (name + '-' + exe + '.state')
                r = proof.run([str(root / exe), '--trap', str(path), data], name + '-' + exe,
                              env=env, timeout=args.timeout, check=False)
                checked_trap(r, name + '/' + exe, category)
                messages=[match.group(1) for line in r.stderr.decode().splitlines() if (match:=re.fullmatch(r'(?:thread \d+ |V )?panic:\s*(.*)',line.strip()))]
                if messages != [category]:raise AssertionError(f'{name}/{exe}: exact panic differs: {messages}')
                if not path.exists(): raise AssertionError('missing panic observer')
                observed.append(path.read_bytes())
            if not observed[0] or observed[0] != observed[1]: raise AssertionError(f'{name}: differing states {observed}')
            states.update(name.encode() + b'\0' + category.encode() + b'\0' + observed[0] + b'\n')
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
                       read_attempts=sum(int(data.split('|')[1]) for _, data in rows), output_sha256=digest,
                       paired_traps=len(traps()), state_sha256=state_digest, zig_mode=mode, v_prod=args.v_prod)
        (root / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
        print(json.dumps(summary), flush=True)


if __name__ == '__main__':
    main()
