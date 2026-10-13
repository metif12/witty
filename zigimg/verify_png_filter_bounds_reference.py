"""Compare PNG filtering bounds, failure order and retained caller output with unchanged Source."""
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

EXPECTED_ROWS = 12076
EXPECTED_SHA256 = 'c1c523a2bf3693e10088e1476b6d31841d1eb0e855bc78106445e925c99177e3'
EXPECTED_STATE_SHA256 = 'b710976b02b6955cfb609aa85612ab3696bb2270629092d9cb42b980a1aa3126'
BUFFERS = (0, 510, 511, 512, 1024)
STDLIB_FILES = (*BASE_STDLIB_FILES, 'posix.zig')
PINNED_STDLIB_SHA256 = 'ed900ae630673721b5aca890da4d432f4f1bfbbb201d5e450861b8111ab9a27d'


def stdlib_hash(zig):
    digest = hashlib.sha256()
    for name in STDLIB_FILES:
        digest.update(name.encode() + b'\0')
        digest.update((zig.parent / 'lib/std' / name).read_bytes())
    return digest.hexdigest()


FORMATS=((1,3),(2,3),(4,3),(8,3),(1,0),(2,0),(4,0),(8,0),(16,0),(8,4),(16,4),(8,2),(16,2),(8,6),(16,6),(16,3))
CHANNELS={0:1,2:3,3:1,4:2,6:4}
def row(slot,width,height,count,depth,color,seed,choice,capacity):return '|'.join(map(str,(slot,width,height,count,depth,color,seed,choice,capacity)))
def corpus():
    rows=[]
    for slot,(depth,color) in enumerate(FORMATS):
        for width,height,seed,choice in itertools.product((0,1,2,3,9),(0,1,2),(0,1),(0,1,2,3,4,5)):
            length=height*(1+(width*depth*CHANNELS[color]+7)//8)
            for capacity in sorted({0,1,max(0,length-1),length,length+3}):
                rows.append(('matched-rows',row(slot,width,height,width*height,depth,color,seed,choice,capacity)))
    for slot,width,height,choice in itertools.product((8,10,12,14,15),(2,4,8),(1,2),(0,5)):
        # Matching word rows can have shorter destinations, including zero.
        source_channels=1 if slot in (8,15) else 2 if slot==10 else 3 if slot==12 else 4
        for multiplier in (0,1,source_channels):
            rows.append(('shorter-word-destination',row(slot,width,height,width*height,8*multiplier,0,1,choice,128)))
    for slot,(depth,color) in enumerate(FORMATS):
        rows.append(('zero-height-try-all',row(slot,9,0,0,depth,color,0,6,0)))
    # The output fails on a completed row before the later short pixel range.
    for slot,(depth,color) in enumerate(FORMATS):
        for width,choice in itertools.product((1,3,9),(0,5)):
            prefix=1+(width*depth*CHANNELS[color]+7)//8
            for capacity in (0,prefix-1):rows.append(('write-error-before-next-row',row(slot,width,2,width*2-1,depth,color,1,choice,capacity)))
    return rows

def traps():
    cases={}
    for slot,(depth,color) in enumerate(FORMATS):
        for width,height,choice in itertools.product((1,3,9),(1,2,3),(0,5,6)):
            if choice==6 and height>1:continue
            prefix=(height-1)*(1+(width*depth*CHANNELS[color]+7)//8)
            for capacity in (prefix,prefix+5):
                name=f'pixel-range-{slot}-{width}-{height}-{choice}-{capacity}'
                count=width*height-1
                cases[name]=(row(slot,width,height,count,depth,color,1,choice,capacity),f'index out of bounds: index {width*height}, len {count}')
    for slot,width,choice,capacity in itertools.product((0,1,2,4,5,6),(1,3,9),(0,5,6),(0,1,8)):
        cases[f'packed-empty-{slot}-{width}-{choice}-{capacity}']=(row(slot,width,1,width,0,0,1,choice,capacity),'index out of bounds: index 0, len 0')
    for slot,width,choice,capacity in itertools.product((8,10,12,15),(1,2,3),(0,5,6),(0,1,8)):
        length=width*(2 if slot==10 else 3 if slot==12 else 1)
        cases[f'word-short-{slot}-{width}-{choice}-{capacity}']=(row(slot,width,1,width,16,6,1,choice,capacity),f'index out of bounds: index {length}, len {length}')
    for slot,width,choice in itertools.product((8,10,12,14,15),(1,3),(0,6)):
        cases[f'odd-word-destination-{slot}-{width}-{choice}']=(row(slot,width,1,width,8,0,1,choice,0),'exact division produced remainder')
    for slot,(depth,color) in enumerate(FORMATS):
        if depth==8:
            other=6 if color!=6 else 0
            cases[f'byte-length-{slot}']=(row(slot,1,1,1,8,other,1,6,0),'source and destination arguments have non-equal lengths')
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
    probe = repo / 'zigimg/reference_probes/png_filter_bounds'
    env = dict(os.environ, VEXE=str(v), V_C_ERROR_BUG_REPORT_DISABLED='1')
    with work_directory(args.workdir, 'witty-png-filter-bounds-') as root:
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
        helpers={name:hashlib.sha256((repo/'zigimg'/name).read_bytes()).hexdigest() for name in ('verify_jpeg_contracts_reference.py','verify_tiff_decode_reference.py','verify_png_filtering_reference.py')}
        implementations = implementation_hashes(repo)
        runner_hash = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
        (root / 'provenance.json').write_text(json.dumps(dict(
            source_sha256=PINNED_SOURCE_SHA256, stdlib_sha256=PINNED_STDLIB_SHA256,
            versions=versions, target=args.target, zig_mode=mode, v_prod=args.v_prod, helper_sha256=helpers,
            fixtures=fixtures, implementation_sha256=implementations, runner_sha256=runner_hash), indent=2) + '\n')
        print(f'Building PNG filter bounds: Source {mode}, V {"production" if args.v_prod else "ordinary"}', flush=True)
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
                        output_sha256=digest,
                       paired_traps=len(traps()), state_sha256=state_digest, zig_mode=mode, v_prod=args.v_prod)
        (root / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
        print(json.dumps(summary), flush=True)


if __name__ == '__main__':
    main()
