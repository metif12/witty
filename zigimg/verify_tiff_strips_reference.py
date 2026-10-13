"""Compare TIFF strip bounds, checked failures and initialized caller pixels."""
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

EXPECTED_ROWS = 3260
EXPECTED_SHA256 = '8a6553fe35a72b05568327affd1f3d47a6daf6eb21e77f5c2d424d2900a89b69'
EXPECTED_STATE_SHA256 = '30a332c0c8eae15fb682a521ebe56eab10b1cfbd13457d02008247b4d289833c'
STDLIB_FILES = (*BASE_STDLIB_FILES, 'posix.zig', 'hash_map.zig', 'compress/flate.zig', 'compress/flate/Decompress.zig', 'compress/flate/Token.zig', 'compress/flate/HuffmanEncoder.zig', 'math.zig', 'math/pow.zig', 'math/powi.zig')
PINNED_STDLIB_SHA256 = 'f7d294645f1474fc6c53ea214299928b8b3ae073e20103f97f650fdfb69185d1'


def stdlib_hash(zig):
    digest = hashlib.sha256()
    for name in STDLIB_FILES:
        digest.update(name.encode() + b'\0')
        digest.update((zig.parent / 'lib/std' / name).read_bytes())
    return digest.hexdigest()


BUFFERS = (0,4,8,16,64)
from verify_tiff_decode_reference import compressed


def spec(capacity=0,slot=1,width=3,height=2,rows=1,dest=None,palette=256,colors=2,photo=1,predictor=1,components=None,kind=1,bits=None,offsets=None,counts=None,data=None):
    if bits is None:bits=((1,),(8,),(8,),(8,8,8),(8,8,8,8),(16,))[slot]
    if components is None:components=len(bits)
    if dest is None:dest=width*height
    if data is None:
        raw=bytearray(b'\x63');off=[];cnt=[]
        row_bytes=width//8 if sum(bits[:components])==1 else width*(sum(bits[:components])//8)
        for start in range(0,height,rows):
            block=bytes((i*37+start*19+slot*13)&255 for i in range(min(rows,height-start)*row_bytes))
            packet=compressed(block,kind) if kind in (1,5,32773,8,32946) else block
            off.append(len(raw));cnt.append(len(packet) if kind==32773 else 0);raw+=packet+b'\x63\x58\x4d'
        data=bytes(raw)
        if offsets is None:offsets=off
        if counts is None:counts=cnt
    def values(v):return v if isinstance(v,str) else ','.join(map(str,v or ()))
    args=(capacity,slot,width,height,rows,dest,palette,colors,photo,predictor,components,kind)
    return '|'.join(map(str,args))+f'|{values(bits)}|{values(offsets)}|{values(counts)}|{data.hex()}'


def corpus():
    out=[]
    def add(group,buffers=BUFFERS,**kw):
        for capacity in buffers:out.append((group,spec(capacity=capacity,**kw)))
    for slot,h,rows,kind,predictor in itertools.product(range(6),(1,3),(1,2,8),(1,5,32773,8,32946),(1,2,65535)):
        width=8 if slot==0 else 3
        buffers=(0,8,16,64) if kind in (8,32946) else BUFFERS
        add('complete-strips',buffers,slot=slot,width=width,height=h,rows=rows,kind=kind,predictor=predictor)
    for slot,width,dest,kind,predictor in itertools.product(range(5),(1,3),(1,2),(1,32773,5),(1,2)):
        if slot==0:width*=8
        add('first-strip-clipping',slot=slot,width=width,height=1,rows=1,dest=dest,kind=kind,predictor=predictor)
    for slot,width,rows,predictor in itertools.product((3,4),(1,2),(1,2),(1,2)):
        width*=3 if slot==3 else 4
        add('initialized-holes',slot=slot,width=width,height=3,rows=rows,bits=(8,),components=1,predictor=predictor)
    for slot in range(6):
        add('zero-byte-strips',slot=slot,width=0,height=3,rows=2,colors=0)
    for slot in range(6):
        add('unsupported-row-before-array-index',slot=slot,bits=(4,),components=1,offsets=(),counts=())
        add('unsupported-compression-after-seek',slot=slot,kind=6)
        add('invalid-memory-seek',buffers=(0,),slot=slot,offsets=(0xffffffff,0xffffffff))
    return out


def traps():
    out={}
    def add(name,category='index out of bounds',buffers=BUFFERS,**kw):
        for capacity in buffers:out[name+f'-{capacity}']=(spec(capacity=capacity,**kw),category)
    for name,kw in (
        ('missing-counts',{'counts':'N'}),('missing-offsets',{'offsets':'N'}),('missing-both',{'counts':'N','offsets':'N'}),
        ('counts-before-empty-height',{'counts':'N','height':0,'data':b'\x63','offsets':()}),
        ('offsets-before-row-samples',{'offsets':'N','components':2,'bits':(8,)}),
    ):add(name,'attempt to use null value',**kw)
    for height,rows,category,name in ((0xffffffff,1,'integer overflow','sum-overflow'),(0,0,'integer overflow','sum-underflow'),(1,0,'division by zero','zero-rows'),(0,1,'division by zero','empty-height')):
        add(name,category,height=height,rows=rows,dest=6,data=b'\x63',counts='N' if rows==0 or height==0xffffffff else (),offsets=())
    add('strip-byte-product','integer overflow',width=0xffffffff,height=0x7fffffff,rows=0x7fffffff,bits=(65535,)*8,components=8,dest=0,data=b'\x63',counts=(0,),offsets=(0,))
    for n in range(4):add(f'row-samples-{n}',bits=(8,)*n,components=n+1,data=b'\x63',offsets=(),counts=())
    for slot,height in itertools.product(range(5),(2,3)):
        width=8 if slot==0 else 3
        for n in range(height):
            base=spec(slot=slot,width=width,height=height);fields=base.split('|')
            offsets=tuple(map(int,fields[13].split(',')));counts=tuple(map(int,fields[14].split(',')))
            add(f'counts-{slot}-{height}-{n}',slot=slot,width=width,height=height,counts=counts[:n])
            add(f'offsets-{slot}-{height}-{n}',slot=slot,width=width,height=height,offsets=offsets[:n])
    for colors,palette in ((1,0),(2,0),(2,1),(4,3),(256,255)):
        add(f'palette-{colors}-{palette}',slot=2,colors=colors,palette=palette,dest=0)
    for slot,kind,later in itertools.product(range(5),(1,5,32773),(False,True)):
        width=8 if slot==0 else 3
        add(f'destination-{slot}-{kind}-{int(later)}',slot=slot,width=width,height=2 if later else 1,dest=width if later else 0,kind=kind)
    for slot,width,predictor,empty in itertools.product((3,4),(1,2,4,5),(1,2),(False,True)):
        channels=3 if slot==3 else 4
        if width%channels==0:continue
        add(f'channels-{slot}-{width}-{predictor}-{int(empty)}',slot=slot,width=width,height=1,bits=(8,),components=1,predictor=predictor,dest=0 if empty else width)
    for slot,predictor in itertools.product((3,4),(1,2)):
        # First strip has one complete color; the last strip has one byte.
        add(f'last-strip-channels-{slot}-{predictor}',slot=slot,width=1,height=(3 if slot==3 else 4)+1,rows=3 if slot==3 else 4,bits=(8,),components=1,predictor=predictor)
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
    probe = repo / 'zigimg/reference_probes/tiff_strips'
    env = dict(os.environ, VEXE=str(v), V_C_ERROR_BUG_REPORT_DISABLED='1')
    with work_directory(args.workdir, 'witty-tiff-strips-') as root:
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
        helpers={name:hashlib.sha256((repo/'zigimg'/name).read_bytes()).hexdigest() for name in ('verify_jpeg_contracts_reference.py','verify_tiff_decode_reference.py','verify_tiff_arrays_reference.py')}
        implementations = implementation_hashes(repo)
        runner_hash = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
        (root / 'provenance.json').write_text(json.dumps(dict(
            source_revision='d7b7ab0ba0899643831ef042bd73289510b39906',
            source_sha256=PINNED_SOURCE_SHA256, stdlib_sha256=PINNED_STDLIB_SHA256,
            versions=versions, target=args.target, zig_mode=mode, v_prod=args.v_prod, helper_sha256=helpers,
            fixtures=fixtures, implementation_sha256=implementations, runner_sha256=runner_hash), indent=2) + '\n')
        print(f'Building TIFF strips: Source {mode}, V {"production" if args.v_prod else "ordinary"}', flush=True)
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
                    if category!='index out of bounds' and native_message!=category:raise AssertionError('unexpected Source panic')
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
                       read_attempts=len(rows), output_sha256=digest,
                       paired_traps=len(traps()), state_sha256=state_digest, zig_mode=mode, v_prod=args.v_prod)
        (root / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
        print(json.dumps(summary), flush=True)


if __name__ == '__main__':
    main()
