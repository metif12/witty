"""Compare TIFF parsed enum traps and complete initialized public failure state."""
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

EXPECTED_ROWS = 1824
EXPECTED_SHA256 = 'b923196ab9bdec0916a6936a54fb956e2017c7022b3b51e9e5a0d29aaf0cedab'
EXPECTED_STATE_SHA256 = 'b1cbd56b09caa543790322bd7ad063130020c435b8a20eea7a4461e47ac3bd64'
STDLIB_FILES = (*BASE_STDLIB_FILES, 'posix.zig', 'hash_map.zig')
PINNED_STDLIB_SHA256 = '15a518729a305d0712ca280aa5e24bae4a1e605eb01c4866bae980b513e268be'


def stdlib_hash(zig):
    digest = hashlib.sha256()
    for name in STDLIB_FILES:
        digest.update(name.encode() + b'\0')
        digest.update((zig.parent / 'lib/std' / name).read_bytes())
    return digest.hexdigest()


TAG_IDS = (254,256,257,258,259,262,266,269,270,273,274,277,278,279,282,283,284,286,287,292,296,297,305,317,318,319,320,338,339,700,34665,34675)
COMPRESSION = (1,2,3,4,5,6,8,32771,32773,32946)
BUFFERS = (0,4,16,64)


def directory(endian, tags, next_offset=0x12345678):
    order = '<' if endian == 0 else '>'
    return b'\x63' + struct.pack(order+'H',len(tags)) + b''.join(struct.pack(order+'HHII',*tag) for tag in tags) + struct.pack(order+'I',next_offset)


def short(endian,key,value,data_type=3,count=1,other=0xa35c):
    offset = (other<<16)|value if endian == 0 else (value<<16)|other
    return (key,data_type,count,offset)


def spec(capacity,endian,decode,data,reads=1):
    return f'{capacity}|{endian}|{decode}|{reads}|{data.hex()}'


def corpus():
    rows=[]
    def add(group,endian,decode,data,reads=1):
        for capacity in BUFFERS:rows.append((group,spec(capacity,endian,decode,data,reads)))
    for endian in (0,1):
        for tag in TAG_IDS:
            add('known-tag-ids',endian,0,directory(endian,[(tag,3,1,0x12345678)]),2)
        for compression,resolution in itertools.product(COMPRESSION,(1,2,3)):
            tags=[short(endian,259,compression),short(endian,296,resolution),(256,4,1,123),(257,4,1,456),short(endian,258,8)]
            for order in (tags,list(reversed(tags))):
                add('valid-metadata-enums',endian,1,directory(endian,order),2)
        # The inline conversion ignores both data_type and data_count for these enums.
        for data_type,count in itertools.product((0,3,4,5,65535),(0,1,2,65535)):
            add('inline-halfword-conversion',endian,1,directory(endian,[short(endian,259,32773,data_type,count),short(endian,296,2,data_type,count)]),2)
        tags=[(256,4,1,777),short(endian,259,8),(256,4,1,999),short(endian,296,1)]
        for cut in range(len(directory(endian,tags))+1):
            add('valid-ifd-prefixes',endian,1,directory(endian,tags)[:cut],2)
        # Complete unknown/invalid enums trap; every shorter prefix must return first.
        for tags in ([(65535,3,1,0)], [short(endian,259,7)], [short(endian,296,4)]):
            data=directory(endian,tags)
            for cut in range(len(data)):
                add('incomplete-before-enum',endian,1,data[:cut],2)
        for key in (258,338):
            add('unsupported-metadata-count',endian,1,directory(endian,[(key,3,2,0)]),2)
        add('empty-ifd',endian,1,directory(endian,[]),2)
    return rows


def traps():
    cases={}
    unknown=sorted(set([0,1,253,255,260,261,263,265,267,268,271,272,275,276,280,281,285,288,291,293,295,298,304,306,316,319+2,337,340,699,701,32767,32768,34664,34666,34674,34676,65534,65535]))
    invalid_compression=(0,7,9,255,256,32767,32768,32770,32772,32774,32945,32947,65535)
    invalid_resolution=(0,4,255,256,32767,32768,65535)
    for endian in (0,1):
        for key in unknown:
            tags=[(256,4,1,111),(256,4,1,222),(key,3,1,0),(257,4,1,333)]
            cases[f'unknown-{endian}-{key}']=(spec(0,endian,0,directory(endian,tags)),'invalid enum value')
        for capacity,value in itertools.product(BUFFERS,invalid_compression):
            tags=[(256,4,1,111),short(endian,258,8),short(endian,259,value),short(endian,296,2),(257,4,1,333)]
            cases[f'compression-{endian}-{capacity}-{value}']=(spec(capacity,endian,1,directory(endian,tags)),'invalid enum value')
        for capacity,value in itertools.product(BUFFERS,invalid_resolution):
            tags=[(256,4,1,111),short(endian,258,8),short(endian,259,8),short(endian,296,value),(257,4,1,333)]
            cases[f'resolution-{endian}-{capacity}-{value}']=(spec(capacity,endian,1,directory(endian,tags)),'invalid enum value')
        for capacity,index in itertools.product(BUFFERS,(0,1,3)):
            tags=[(256,4,1,111),(256,4,1,222),(257,4,1,333)]
            tags.insert(index,(65535,3,1,0))
            cases[f'unknown-order-{endian}-{capacity}-{index}']=(spec(capacity,endian,1,directory(endian,tags)),'invalid enum value')
        # Both bitmap enum fields invalid: HashMap iteration determines which one fails.
        for capacity,reverse in itertools.product(BUFFERS,(False,True)):
            tags=[short(endian,259,7),short(endian,296,4),(256,4,1,111),short(endian,258,8)]
            if reverse:tags.reverse()
            cases[f'simultaneous-{endian}-{capacity}-{int(reverse)}']=(spec(capacity,endian,1,directory(endian,tags)),'invalid enum value')
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
    probe = repo / 'zigimg/reference_probes/tiff_enums'
    env = dict(os.environ, VEXE=str(v), V_C_ERROR_BUG_REPORT_DISABLED='1')
    with work_directory(args.workdir, 'witty-tiff-enums-') as root:
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
        helpers={name:hashlib.sha256((repo/'zigimg'/name).read_bytes()).hexdigest() for name in ('verify_jpeg_contracts_reference.py','verify_tiff_decode_reference.py')}
        implementations = implementation_hashes(repo)
        runner_hash = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
        (root / 'provenance.json').write_text(json.dumps(dict(
            source_revision='d7b7ab0ba0899643831ef042bd73289510b39906',
            source_sha256=PINNED_SOURCE_SHA256, stdlib_sha256=PINNED_STDLIB_SHA256,
            versions=versions, target=args.target, zig_mode=mode, v_prod=args.v_prod, helper_sha256=helpers,
            fixtures=fixtures, implementation_sha256=implementations, runner_sha256=runner_hash), indent=2) + '\n')
        print(f'Building TIFF enums: Source {mode}, V {"production" if args.v_prod else "ordinary"}', flush=True)
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
