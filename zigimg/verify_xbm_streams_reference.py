"""Compare XBM file delimiters, retained caller state and no-op writers."""
import argparse
from collections import Counter
import hashlib
import itertools
import json
import os
from pathlib import Path
import re
import shutil
import subprocess

from verify_jpeg_contracts_reference import implementation_hashes
from verify_tiff_decode_reference import ProofLog, tree_hash, work_directory, PINNED_SOURCE_SHA256, checked_trap

EXPECTED_ROWS = 87419
EXPECTED_SHA256 = '2387acb029df067d85d6dc60f14d55aa2fee2599887769738298879ba0d34b64'
EXPECTED_LOOP_SHA256 = '05322ee600feeba73130d3cfaaef0f8068a620379fd91bd191b86fbae0f3618d'
from verify_tga_decode_reference import stdlib_hash, PINNED_STDLIB_SHA256
from verify_xbm_contracts_reference import FMT_SHA256
from verify_tiff_decode_reference import no_core

READ_BUFFERS = (-1, 0, 1, 7, 11, 12, 13, 16, 24, 32, 64, 128)


def spec(capacity, op=0, start=0, attempts=2, w=17, h=19, data=b''):
    return '|'.join(map(str, (capacity, op, start, attempts, w, h, data.hex())))


def image(w=8, h=1, body=b'{0xff}\n', extra=b''):
    return b'#define w '+str(w).encode()+b'\n#define h '+str(h).encode()+b'\n'+extra+body


def corpus():
    rows = []
    def read(group, data, start=0):
        for cap, op in itertools.product(READ_BUFFERS, (0, 1, 3)):
            if start and cap == 0: continue
            rows.append((group, spec(cap, op, start=start, data=b'x'*start+data)))
    for byte in range(256):
        for w, h in ((1, 1), (7, 3), (8, 1), (9, 2), (17, 3)):
            tokens=b','.join(f'0x{(byte+i*37)&255:02x}'.encode() for i in range((w*h+7)//8+1))
            read('bits-and-refills',image(w,h,b'{'+tokens+b'}\n'))
    samples=(image(),image(body=b'{}\n'),image(body=b'{\n0xff\n};\n'),
             image(body=b'{0xff}\r\n'),image(body=b'{\n0xff\r\n0x55\n}\n'),
             image(body=b'{0xff}\nunterminated'),b'#define w 8\n',
             b'#define w 8\n#define h 1\n',b'not a define\n',b'\n',b'')
    for data in samples:
        for cut, start in itertools.product(range(len(data)+1),(0,3)):
            read('prefix-and-retry',data[:cut],start)
    for length, position in itertools.product(range(0,132),(0,1,2)):
        long=b' '*length+b'\n'
        data=long+image() if position==0 else image(body=long+b'{0xff}\n') if position==1 else image(body=b'{0xff}\n'+long)
        read('line-capacity-boundaries',data)
    for value in (b'',b'8\t',b'+0_8',b'-1',b'4294967296',b'0',b'-0'):
        for extra in (b'',b'#define x 0\n#define y 7\n#define z 8\n',b'#define bad -1\n'):
            read('define-failure-state',b'#define w '+value+b'\n#define h 0\n'+extra+b'{}\n')
    for w,h,count in itertools.product((0,1,7,17),(0,1,3),(0,1,8)):
        read('dimensions-and-data',image(w,h,b'{'+b'0xffff,'*count+b'}\n'))
    for byte in range(256):
        for cap,op in itertools.product(READ_BUFFERS,(2,4)):
            rows.append(('detector-byte',spec(cap,op,attempts=3,data=bytes((byte,))+b'abcdef\n')))
    for data in (b'',b'#define w 8',b' #define w 8\n',b'anything\n',b'\n'):
        for cap,op,start in itertools.product(READ_BUFFERS,(2,4),(0,3)):
            if start and cap==0:continue
            rows.append(('detector-prefix',spec(cap,op,start=start,attempts=3,data=b'x'*start+data)))
    for cap,op,dims in itertools.product((-2,0,1,3,8,16,32),(5,6,7),((0,0),(1,1),(2**32,2**64-1))):
        for start in ((0,) if cap<0 else (0,7)):
            for count in (0,3 if cap==-2 else min(max(cap,0),3)):
                w,h=dims
                rows.append(('noop-writer',spec(cap,op,start=start,attempts=3,w=w,h=h,data=bytes((1,35,69))[:count])))
    return rows


def bounded_loop(proof,root,exe,row,label,env):
    argv=[str(root/exe),'--loop',row,str(root/(label+'.bin'))]
    process=subprocess.Popen(argv,stdout=subprocess.PIPE,stderr=subprocess.PIPE,env=env,preexec_fn=no_core)
    try:
        stdout,stderr=process.communicate(timeout=0.5)
        raise AssertionError(f'{label}: inherited detector loop returned {process.returncode}: {stdout!r}, {stderr!r}')
    except subprocess.TimeoutExpired:
        process.kill();stdout,stderr=process.communicate()
    prefix=f'{len(proof.commands):03d}-{label}'
    proof.commands.append(dict(label=label,argv=argv,cwd=os.getcwd(),timeout=0.5,bounded_loop=True,killed_after_timeout=True,returncode=process.returncode))
    (root/(prefix+'.stdout')).write_bytes(stdout);(root/(prefix+'.stderr')).write_bytes(stderr)
    (root/'commands.json').write_text(json.dumps(proof.commands,indent=2)+'\n')
    if stderr or not stdout.startswith(b'ready|'):raise AssertionError(f'{label}: missing initialized ready state or unexpected stderr')
    return stdout


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
    fmt_path=zig.parent/'lib/std/fmt.zig'
    if tree_hash(source) != PINNED_SOURCE_SHA256 or stdlib_hash(zig) != PINNED_STDLIB_SHA256 or hashlib.sha256(fmt_path.read_bytes()).hexdigest()!=FMT_SHA256:
        parser.error('Source or selected compiler library differs from the pins')
    mode = 'ReleaseSafe' if args.v_prod else 'Debug'
    repo = Path(__file__).resolve().parent.parent
    probe = repo / 'zigimg/reference_probes/xbm_streams'
    env = dict(os.environ, VEXE=str(v), V_C_ERROR_BUG_REPORT_DISABLED='1')
    with work_directory(args.workdir, 'witty-xbm-streams-') as root:
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
        helpers={name:hashlib.sha256((repo/'zigimg'/name).read_bytes()).hexdigest() for name in ('verify_jpeg_contracts_reference.py','verify_tiff_decode_reference.py','verify_tga_decode_reference.py','verify_xbm_contracts_reference.py')}
        implementations = implementation_hashes(repo)
        runner_hash = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
        (root / 'provenance.json').write_text(json.dumps(dict(
            source_revision='d7b7ab0ba0899643831ef042bd73289510b39906',
            source_sha256=PINNED_SOURCE_SHA256, stdlib_sha256=PINNED_STDLIB_SHA256,
            fmt_sha256=FMT_SHA256, versions=versions, target=args.target, zig_mode=mode, v_prod=args.v_prod, helper_sha256=helpers,
            fixtures=fixtures, implementation_sha256=implementations, runner_sha256=runner_hash), indent=2) + '\n')
        print(f'Building XBM streams: Source {mode}, V {"production" if args.v_prod else "ordinary"}', flush=True)
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
        print(f'{len(rows)} returning rows match; checking bounded detector loops', flush=True)
        loops = hashlib.sha256()
        loop_inputs = {}
        for index,(cap,op,start,data) in enumerate(itertools.product((-1,12,64),(2,4),(0,3),(b'#define w 8\n',b'#define\n'))):
            row=spec(cap,op,start=start,attempts=1,data=b'x'*start+data)
            path=root/f'loop-{index}.txt';path.write_text(row+'\n')
            loop_inputs[path.name]=hashlib.sha256(path.read_bytes()).hexdigest()
            observed=[bounded_loop(proof,root,exe,row,f'loop-{index}-{exe}',env) for exe in ('native','translated')]
            if observed[0]!=observed[1]:raise AssertionError('bounded detector ready states differ')
            loops.update(str(index).encode()+b'\0'+observed[0])
        loop_digest=loops.hexdigest()
        if EXPECTED_LOOP_SHA256 is not None and loop_digest!=EXPECTED_LOOP_SHA256:raise AssertionError('loop ready-state golden changed')
        if (tree_hash(source) != PINNED_SOURCE_SHA256 or tree_hash(root / 'src') != PINNED_SOURCE_SHA256
                or stdlib_hash(zig) != PINNED_STDLIB_SHA256 or hashlib.sha256(fmt_path.read_bytes()).hexdigest()!=FMT_SHA256 or implementation_hashes(repo) != implementations
                or hashlib.sha256(Path(__file__).read_bytes()).hexdigest() != runner_hash):
            raise AssertionError('dependency, implementation or runner changed')
        for name, expected in fixtures.items():
            if any(hashlib.sha256((p / name).read_bytes()).hexdigest() != expected for p in (root, probe)):
                raise AssertionError('fixture changed')
        if hashlib.sha256(corpus_path.read_bytes()).hexdigest()!=input_hash:raise AssertionError('input changed')
        for name,expected in loop_inputs.items():
            if hashlib.sha256((root/name).read_bytes()).hexdigest()!=expected:raise AssertionError('loop input changed')
        (root/'input_sha256.json').write_text(json.dumps(dict({'corpus.txt':input_hash},**loop_inputs),indent=2)+'\n')
        for name,expected in helpers.items():
            if hashlib.sha256((repo/'zigimg'/name).read_bytes()).hexdigest()!=expected:raise AssertionError('helper changed')
        summary = dict(returning_records=len(rows), returning_groups=dict(Counter(group for group, _ in rows)),
                       calls=sum(int(data.split('|')[3]) for _,data in rows), output_sha256=digest,
                       paired_bounded_loops=24, loop_ready_sha256=loop_digest, zig_mode=mode, v_prod=args.v_prod)
        (root / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
        print(json.dumps(summary), flush=True)


if __name__ == '__main__':
    main()
