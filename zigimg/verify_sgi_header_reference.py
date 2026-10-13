"""Compare SGI parsed-header validation, buffered decoding and exact retained failures."""
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

EXPECTED_ROWS = 13480
EXPECTED_SHA256 = '7cc1b4dea92da390d91a189476efabbfbae527584ffab6f7e27a6dad8f231e5e'
EXPECTED_STATE_SHA256 = 'b04edf68a65629c73690152f3d022603dc28f2198ee9da27cf2cb51f625a6312'
BUFFERS = (0, 510, 511, 512, 1024)
STDLIB_FILES = (*BASE_STDLIB_FILES, 'posix.zig')
PINNED_STDLIB_SHA256 = 'ed900ae630673721b5aca890da4d432f4f1bfbbb201d5e450861b8111ab9a27d'


def stdlib_hash(zig):
    digest = hashlib.sha256()
    for name in STDLIB_FILES:
        digest.update(name.encode() + b'\0')
        digest.update((zig.parent / 'lib/std' / name).read_bytes())
    return digest.hexdigest()


from verify_sgi_contracts_reference import header, tables


def image(w=3,h=2,z=3,bpc=1,dim=3,compression=0,pattern=0,repeat=False):
    raw=bytes((i*37+pattern*71+19)&255 for i in range(w*h*z*bpc))
    if not compression:return header(w,h,z,bpc,dim)+raw+b'\x63\x58'
    packets=[]
    for row in range(h*z):
        chunk=raw[row*w*bpc:(row+1)*w*bpc]
        if repeat:chunk=chunk[:bpc]*w
        command=bytes([w if repeat else 128+w]) if bpc==1 else bytes([127,w if repeat else 128+w])
        term=b'\x00' if bpc==1 else b'\x7f\x00'
        packets.append(command+(chunk[:bpc] if repeat else chunk)+term)
    return header(w,h,z,bpc,dim,1)+tables(packets)+b'\x63\x58'


def invalid_headers():
    cases={}
    for value in range(2,256):cases[f'compression-{value}']=header(compression=value)
    dimensions=sorted(set([0,*range(4,256),256,257,258,259,260,511,512,513,767,768,769,1024,32767,32768,65534,65535]))
    for value in dimensions:cases[f'dimension-{value}']=header(dimension=value)
    formats=sorted(set([*range(4,256),*(1<<bit for bit in range(2,32)),255,256,257,511,512,65535,65536,0x7fffffff,0xfffffffe,0xffffffff]))
    for value in formats:cases[f'pixel-format-{value}']=header(pixel_format=value)
    return cases


def corpus():
    rows=[]
    def add(group,data,buffers=BUFFERS,reads=1):
        for capacity in buffers:rows.append((group,f'{capacity}|{reads}|{data.hex()}'))
    layouts=((2,1,1),(2,1,2),(3,3,1),(3,4,1),(3,3,2),(3,4,2))
    for (dim,z,bpc),w,h,pattern,compression in itertools.product(layouts,(0,1,3,7,17,63),(0,1,2,3),(0,1,2),(0,1)):
        add('defined-decode',image(w,h,z,bpc,dim,compression,pattern))
    for (dim,z,bpc),w,h in itertools.product(layouts,(1,3,17,63),(1,2)):
        add('repeated-rle',image(w,h,z,bpc,dim,1,repeat=True))
    for compression,dimension,pixel_format,bpc in itertools.product((0,1),(1,2,3),(0,1,2,3),(1,2,255)):
        add('valid-enum-dispatch',header(0,0,3,bpc,dimension,compression,pixel_format))
    # Incomplete headers cannot trigger validation, even when an invalid field
    # is already present in their buffered prefix. Retry the retained stream.
    for data in (header(compression=255),header(dimension=65535),header(pixel_format=0xffffffff)):
        for cut in (0,1,2,3,4,5,6,24,104,105,106,107,108,255,509,510,511):
            add('incomplete-invalid-header',data[:cut],reads=2)
    for bad_magic in (b'xx',b'\x01\x00'):
        add('wrong-magic-before-enums',bad_magic+header(compression=255,dimension=65535,pixel_format=0xffffffff)[2:],reads=2)
    for data in (image(3,2),image(3,2,4,2,3)):
        for cut in range(len(data)+1):add('raw-prefixes-retry',data[:cut],reads=2)
    # RLE success prefixes would leave pixels undefined, so keep only short
    # header/table prefixes or complete packets and trailing bytes.
    data=image(3,2,3,1,3,1)
    table_end=512+2*3*8
    for cut in (*range(table_end),len(data)-2,len(data)-1,len(data)):
        add('rle-prefixes-retry',data[:cut],reads=2)
    return rows


def traps():
    cases={}
    for name,data in invalid_headers().items():cases[name+'-memory']=(f'0|1|{data.hex()}','invalid enum value')
    for capacity,field,value in itertools.product((510,511,512,1024),('compression','dimension','pixel_format'),(0,2,4,255,256,0xffffffff)):
        valid= value in (0,1) if field=='compression' else value in (1,2,3) if field=='dimension' else value<=3
        if valid or field=='compression' and value>255 or field=='dimension' and value>65535:continue
        data=header(**{field:value});cases[f'file-{field}-{value}-{capacity}']=(f'{capacity}|1|{data.hex()}','invalid enum value')
    for compression,dimension,pixel_format,capacity in itertools.product((2,255),(0,4,65535),(4,256,0xffffffff),BUFFERS):
        data=header(0,0,65535,255,dimension,compression,pixel_format)
        cases[f'simultaneous-{compression}-{dimension}-{pixel_format}-{capacity}']=(f'{capacity}|1|{data.hex()}','invalid enum value')
    # Invalid parsed fields precede unsupported dispatch, multiplication and EOF.
    for name,data in (
        ('compression-before-unsupported',header(dimension=1,pixel_format=1,compression=255)),
        ('dimension-before-unsupported',header(dimension=0,pixel_format=1)),
        ('format-before-product',header(0,0,65535,255,pixel_format=4)),
        ('compression-before-tables',header(1,8192,1,1,compression=255)),
        ('dimension-before-body',header(dimension=65535)),
    ):
        for capacity in BUFFERS:cases[f'{name}-{capacity}']=(f'{capacity}|1|{data.hex()}','invalid enum value')
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
    probe = repo / 'zigimg/reference_probes/sgi_header'
    env = dict(os.environ, VEXE=str(v), V_C_ERROR_BUG_REPORT_DISABLED='1')
    with work_directory(args.workdir, 'witty-sgi-header-') as root:
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
        helpers={name:hashlib.sha256((repo/'zigimg'/name).read_bytes()).hexdigest() for name in ('verify_jpeg_contracts_reference.py','verify_tiff_decode_reference.py','verify_sgi_contracts_reference.py')}
        implementations = implementation_hashes(repo)
        runner_hash = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
        (root / 'provenance.json').write_text(json.dumps(dict(
            source_sha256=PINNED_SOURCE_SHA256, stdlib_sha256=PINNED_STDLIB_SHA256,
            versions=versions, target=args.target, zig_mode=mode, v_prod=args.v_prod, helper_sha256=helpers,
            fixtures=fixtures, implementation_sha256=implementations, runner_sha256=runner_hash), indent=2) + '\n')
        print(f'Building SGI header: Source {mode}, V {"production" if args.v_prod else "ordinary"}', flush=True)
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
