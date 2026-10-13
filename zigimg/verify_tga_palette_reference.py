"""Compare indexed TGA palette decoding, memory/file buffering and exact retained failures."""
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

EXPECTED_ROWS = 8393
EXPECTED_SHA256 = '9669a76dfbdbf5613f3c2c35663659d248d6219cd166e8339b90d6549cd6a592'
EXPECTED_STATE_SHA256 = '8d1b6eeb5c2f893af80247f9e94137e06efb094d4a2548af25888eaf310d6c26'
BUFFERS = (0, 26, 27, 31, 64, 512, 4096)
STDLIB_FILES = (*BASE_STDLIB_FILES, 'posix.zig')
PINNED_STDLIB_SHA256 = 'ed900ae630673721b5aca890da4d432f4f1bfbbb201d5e450861b8111ab9a27d'


def stdlib_hash(zig):
    digest = hashlib.sha256()
    for name in STDLIB_FILES:
        digest.update(name.encode() + b'\0')
        digest.update((zig.parent / 'lib/std' / name).read_bytes())
    return digest.hexdigest()


def image(depth=24, length=4, first=0, width=3, height=2, compressed=False,
          top=True, palette=None, indices=None, id_bytes=b''):
    header = bytearray(18)
    header[0] = len(id_bytes); header[1] = 1; header[2] = 9 if compressed else 1
    header[3:5] = first.to_bytes(2, 'little'); header[5:7] = length.to_bytes(2, 'little')
    header[7] = depth; header[12:16] = struct.pack('<HH', width, height)
    header[16] = 8; header[17] = 32 if top else 0
    if palette is None:
        if depth in (15, 16):
            palette = b''.join(struct.pack('<H', ((i*7)&31)<<10 | ((i*11)&31)<<5 | ((i*17)&31) | ((i%2)<<15)) for i in range(length))
        else:
            palette = bytes((i*37+19)&255 for i in range(length*3))
    if indices is None:
        values = bytes(i % max(1, length) for i in range(width*height))
        indices = bytes([len(values)-1])+values if compressed and values else values
    return bytes(header) + id_bytes + palette + indices + bytes(26)


def corpus():
    rows = []
    def add(group, data, buffers=BUFFERS, reads=1):
        for capacity in buffers:
            rows.append((group, f'{capacity}|{reads}|{data.hex()}'))
    for depth, length, width, height, compressed, top in itertools.product(
            (15,16,24), (0,1,2,4,16,255,256), (0,1,3), (0,1,2), (False,True), (False,True)):
        add('palette-shapes', image(depth,length,width=width,height=height,compressed=compressed,top=top,id_bytes=b'ID!'))
    for depth, word in itertools.product((15,16), (0,1,31,32,1023,1024,32767,32768,65535)):
        add('word-boundaries', image(depth,1,palette=struct.pack('<H',word),width=1,height=1))
    for value in range(32):
        word=value<<10 | value<<5 | value
        add('all-u5-channel-values', image(16,1,palette=struct.pack('<H',word),width=1,height=1))
    for depth, compressed in itertools.product((15,16,24),(False,True)):
        data=image(depth,4,width=3,height=2,compressed=compressed,id_bytes=b'ID!')
        for cut in range(len(data)+1):
            add('prefixes-retry', data[:cut], reads=2)
    for depth in (0,1,7,8,32,255):
        add('unsupported-depths', image(depth,1,width=1,height=1))
    for depth in (15,16):
        for capacity in BUFFERS:
            for tail in (b'',b'X'):
                data=image(depth,1,first=1,width=0,height=0,id_bytes=b'12345678',palette=b'',indices=b'')[:-26]+tail
                rows.append(('word-eof-before-index',f'{capacity}|2|{data.hex()}'))
    return rows


def traps():
    cases = {}
    for depth, first, length, capacity in itertools.product((15,16,24), (1,2,255), (1,2,4), (0,26,31,64)):
        data=image(depth,length,first,width=0,height=0,id_bytes=b'ID!')
        label=f'index-{depth}-{first}-{length}-{capacity}'
        cases[label]=(f'{capacity}|1|{data.hex()}',f'index out of bounds: index {max(first,length)}, len {length}')
    for capacity in (0,26,31,64):
        data=image(24,1,first=1,width=0,height=0,id_bytes=b'12345678',palette=b'',indices=b'')[:-26]
        cases[f'index-before-eof-{capacity}']=(f'{capacity}|1|{data.hex()}','index out of bounds: index 1, len 1')
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
    probe = repo / 'zigimg/reference_probes/tga_palette'
    env = dict(os.environ, VEXE=str(v), V_C_ERROR_BUG_REPORT_DISABLED='1')
    with work_directory(args.workdir, 'witty-tga-palette-') as root:
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
            source_sha256=PINNED_SOURCE_SHA256, stdlib_sha256=PINNED_STDLIB_SHA256,
            versions=versions, target=args.target, zig_mode=mode, v_prod=args.v_prod, helper_sha256=helpers,
            fixtures=fixtures, implementation_sha256=implementations, runner_sha256=runner_hash), indent=2) + '\n')
        print(f'Building TGA decode: Source {mode}, V {"production" if args.v_prod else "ordinary"}', flush=True)
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
