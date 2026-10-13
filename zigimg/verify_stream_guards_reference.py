"""Compare stream guard diagnostics and retained public state with unchanged Source."""
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

EXPECTED_ROWS = 994
EXPECTED_SHA256 = 'bd6c1a9360e9e336b09180e2f4d8be903e6e90b2841f9c7c2a6b830739b343a0'
EXPECTED_STATE_SHA256 = '7fc070ee211fd87689aa75ed0f462ccbfe160e76a70c41f6059d0ec3cf6b2870'
BUFFERS = (0, 510, 511, 512, 1024)
STDLIB_FILES = (*BASE_STDLIB_FILES, 'posix.zig')
PINNED_STDLIB_SHA256 = 'ed900ae630673721b5aca890da4d432f4f1bfbbb201d5e450861b8111ab9a27d'


def stdlib_hash(zig):
    digest = hashlib.sha256()
    for name in STDLIB_FILES:
        digest.update(name.encode() + b'\0')
        digest.update((zig.parent / 'lib/std' / name).read_bytes())
    return digest.hexdigest()


def row(op,capacity,prefill,consumed,arg,data):return f'{op}|{capacity}|{prefill}|{consumed}|{arg}|{data.hex()}'
def corpus():
    rows=[]
    for length,capacity in itertools.product((0,1,3,8,17,32),(-1,0,1,2,8,31)):
        data=bytes((i*37+19)&255 for i in range(length))
        for consumed in (0,min(1,length),length):
            if capacity>=0 and consumed>capacity:continue
            for request in (0,1,3,8,17):
                if capacity>=0 and request>capacity:continue
                rows.append(('peek',row(0,capacity,0,consumed,request,data)))
            for delta in (-9223372036854775808,-17,-1,0,1,17,9223372036854775807-max(length,capacity)):
                rows.append(('seek',row(2,capacity,0,consumed,delta,data)))
    for length,consumed in itertools.product((0,1,3,8,17,32),(0,1,3)):
        if consumed>length:continue
        data=bytes((i*37+19)&255 for i in range(length))
        for count in (0,length-consumed):rows.append(('toss',row(1,-1,0,consumed,count,data)))
    for capacity,pending in itertools.product((1,2,8,31),(0,1,2,8)):
        if pending>capacity:continue
        data=bytes((i*37+19)&255 for i in range(pending))
        for position in (0,1,9223372036854775807,18446744073709551615-pending):rows.append(('writer-position',row(3,capacity,pending,0,position,data)))
    return rows

def traps():
    cases={}
    for capacity,length in itertools.product((0,1,2,8,31),(0,1,3,17,64)):
        data=bytes((i*37+19)&255 for i in range(length))
        available=min(capacity,length)
        for consumed in sorted({0,available//2,available}):
            for request in (capacity+1,2147483647):
                name=f'capacity-{capacity}-{length}-{consumed}-{request}'
                cases[name]=(row(0,capacity,available,consumed,request,data),'reached unreachable code')
    for length,consumed in itertools.product((0,1,3,8,17,32),(0,1,3)):
        if consumed>length:continue
        data=bytes((i*37+19)&255 for i in range(length))
        for count in (length-consumed+1,2147483647-consumed):cases[f'toss-{length}-{consumed}-{count}']=(row(1,-1,0,consumed,count,data),'reached unreachable code')
    for capacity,prefill,consumed in ((-1,0,1),(-1,0,3),(1,1,1),(8,8,1),(8,8,0),(31,17,0)):
        data=bytes(range(17))
        for adjust in (0,1):
            if consumed==1 and adjust==1:continue
            cases[f'seek-overflow-{capacity}-{prefill}-{consumed}-{adjust}']=(row(2,capacity,prefill,consumed,9223372036854775807-adjust,data),'integer overflow')
    for capacity,pending in itertools.product((1,2,8,31),(1,2,8)):
        if pending>capacity:continue
        for distance in range(min(pending,3)):
            cases[f'writer-overflow-{capacity}-{pending}-{distance}']=(row(3,capacity,pending,0,18446744073709551615-distance,bytes(range(pending))),'integer overflow')
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
    probe = repo / 'zigimg/reference_probes/stream_guards'
    env = dict(os.environ, VEXE=str(v), V_C_ERROR_BUG_REPORT_DISABLED='1')
    with work_directory(args.workdir, 'witty-stream-guards-') as root:
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
        helpers={name:hashlib.sha256((repo/'zigimg'/name).read_bytes()).hexdigest() for name in ('verify_jpeg_contracts_reference.py','verify_tiff_decode_reference.py','verify_streams_reference.py')}
        implementations = implementation_hashes(repo)
        runner_hash = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
        (root / 'provenance.json').write_text(json.dumps(dict(
            source_sha256=PINNED_SOURCE_SHA256, stdlib_sha256=PINNED_STDLIB_SHA256,
            versions=versions, target=args.target, zig_mode=mode, v_prod=args.v_prod, helper_sha256=helpers,
            fixtures=fixtures, implementation_sha256=implementations, runner_sha256=runner_hash), indent=2) + '\n')
        print(f'Building stream guards: Source {mode}, V {"production" if args.v_prod else "ordinary"}', flush=True)
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
