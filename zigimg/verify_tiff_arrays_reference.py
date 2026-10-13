"""Compare TIFF array reads, buffered metadata and complete image decoding."""
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

EXPECTED_ROWS = 18820
EXPECTED_SHA256 = '27985fbc03557dd3db0dc9311e89883f8bdd11bbf340734d76302ee655af5cfa'
EXPECTED_STATE_SHA256 = '95b0fa680a35d1d8516ca1f2e709b637827c42e5adaf86a0f814881782c7f63a'
STDLIB_FILES = (*BASE_STDLIB_FILES, 'posix.zig', 'hash_map.zig', 'compress/flate.zig', 'compress/flate/Decompress.zig', 'compress/flate/Token.zig', 'compress/flate/HuffmanEncoder.zig', 'math.zig', 'math/pow.zig', 'math/powi.zig')
PINNED_STDLIB_SHA256 = 'f7d294645f1474fc6c53ea214299928b8b3ae073e20103f97f650fdfb69185d1'


def stdlib_hash(zig):
    digest = hashlib.sha256()
    for name in STDLIB_FILES:
        digest.update(name.encode() + b'\0')
        digest.update((zig.parent / 'lib/std' / name).read_bytes())
    return digest.hexdigest()


BUFFERS = (0,4,8,16,64)

from verify_tiff_decode_reference import make_tiff
from verify_tiff_enums_reference import directory, short


def spec(capacity,endian,mode,data,reads=2,tag=(3,0,0)):
    return f'{capacity}|{endian}|{mode}|{reads}|{data.hex()}|{tag[0]}|{tag[1]}|{tag[2]}'


def metadata(endian,count=3,bits=8,kind=3):
    order='<' if endian==0 else '>'
    tags=[(256,4,1,17),short(endian,258,bits)]
    if kind==258:
        values=[8]*count;datatype=3
        tags[-1]=(258,3,count,0)
    elif kind==320:
        values=[(i*37)&65535 for i in range((1<<bits)*3)];datatype=3
        tags.append((320,3,len(values),0))
    else:
        values=[i*100+17 for i in range(count)];datatype=kind
        tags.append((273,datatype,count,0));tags.append((279,datatype,count,0))
    start=len(directory(endian,tags))
    tags=[(key,typ,n,start if n!=1 and key in (258,273,279,320) else offset) for key,typ,n,offset in tags]
    payload=struct.pack(order+('H' if datatype==3 else 'I')*len(values),*values)
    return directory(endian,tags)+payload+b'\x63\x58\x4d'


def corpus():
    rows=[]
    def add(group,endian,mode,data,tag=(3,0,0),buffers=BUFFERS,reads=2):
        for capacity in buffers:rows.append((group,spec(capacity,endian,mode,data,reads,tag)))
    for endian,datatype,count,offset in itertools.product((0,1),(3,4),(0,1,2,3,4,8,31,256),(0,1,7)):
        stride=2 if datatype==3 else 4
        raw=bytes((i*37+11)&255 for i in range(count*stride+5))
        for cut in sorted(set([0,1,stride-1,stride,count*stride-1,count*stride,count*stride+3])):
            if cut<0:continue
            add('tag-array-prefixes',endian,2,b'\xa5'*offset+raw[:cut],(datatype,count,offset))
    for endian,datatype,count in itertools.product((0,1),(0,1,2,5,65535),(0,1)):
        add('inline-and-empty-other-types',endian,2,b'\x63\x58\x4d',(datatype,count,0x1234 if count else 1))
    for endian,datatype,count in itertools.product((0,1),(3,4),(2,3,8,31)):
        add('strip-array-metadata',endian,1,metadata(endian,count,kind=datatype))
    for endian,count in itertools.product((0,1),(3,4)):
        add('sample-array-metadata',endian,1,metadata(endian,count,kind=258))
    for endian,bits in itertools.product((0,1),(1,2,4,8)):
        add('palette-array-metadata',endian,1,metadata(endian,bits=bits,kind=320))
    for endian in (0,1):
        data=metadata(endian,3)
        # Prefixes through the complete IFD return errors before reading body arrays.
        tag_end=len(directory(endian,[(256,4,1,17),(258,3,1,8),(273,3,3,0),(279,3,3,0)]))
        for cut in range(tag_end):add('metadata-ifd-prefixes',endian,1,data[:cut])
    for fmt,endian,kind,strip_rows,predictor in itertools.product(range(5),(0,1),(1,5,32773,8,32946),(1,2,8),(1,2)):
        data=make_tiff(fmt,8 if fmt==0 else 3,3,strip_rows,kind,predictor,'little' if endian==0 else 'big')
        # DEFLATE requires a native-word buffer. Smaller buffers intentionally assert.
        buffers=(0,8,16,64) if kind in (8,32946) else BUFFERS
        add('full-image',endian,3,data,buffers=buffers,reads=1)
        for cut in (0,1,2,3,4,5,7,8,9,13):
            add('image-header-prefixes',endian,3,data[:cut],buffers=buffers,reads=1)
    return rows


def traps():
    cases={}
    for endian,datatype,count,capacity in itertools.product((0,1),(0,1,2,5,65535),(2,3),BUFFERS):
        data=b'\x63'+bytes((i*37+11)&255 for i in range(count*4+3))
        name=f'array-type-{endian}-{datatype}-{count}-{capacity}'
        cases[name]=(spec(capacity,endian,2,data,1,(datatype,count,1)),'for loop over objects with non-equal lengths')
    for endian,kind,capacity in itertools.product((0,1),(8,32946),(4,7)):
        data=make_tiff(3,3,3,1,kind,1,'little' if endian==0 else 'big')
        name=f'deflate-capacity-{endian}-{kind}-{capacity}'
        cases[name]=(spec(capacity,endian,3,data,1),'reached unreachable code')
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
    probe = repo / 'zigimg/reference_probes/tiff_arrays'
    env = dict(os.environ, VEXE=str(v), V_C_ERROR_BUG_REPORT_DISABLED='1')
    with work_directory(args.workdir, 'witty-tiff-arrays-') as root:
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
        helpers={name:hashlib.sha256((repo/'zigimg'/name).read_bytes()).hexdigest() for name in ('verify_jpeg_contracts_reference.py','verify_tiff_decode_reference.py','verify_tiff_enums_reference.py')}
        implementations = implementation_hashes(repo)
        runner_hash = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
        (root / 'provenance.json').write_text(json.dumps(dict(
            source_revision='d7b7ab0ba0899643831ef042bd73289510b39906',
            source_sha256=PINNED_SOURCE_SHA256, stdlib_sha256=PINNED_STDLIB_SHA256,
            versions=versions, target=args.target, zig_mode=mode, v_prod=args.v_prod, helper_sha256=helpers,
            fixtures=fixtures, implementation_sha256=implementations, runner_sha256=runner_hash), indent=2) + '\n')
        print(f'Building TIFF arrays: Source {mode}, V {"production" if args.v_prod else "ordinary"}', flush=True)
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
                       read_attempts=sum(int(data.split('|')[3]) for _, data in rows), output_sha256=digest,
                       paired_traps=len(traps()), state_sha256=state_digest, zig_mode=mode, v_prod=args.v_prod)
        (root / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
        print(json.dumps(summary), flush=True)


if __name__ == '__main__':
    main()
