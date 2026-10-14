"""Compare TIFF palette construction and format-selection bounds and retained state."""
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

EXPECTED_ROWS = 16686
EXPECTED_SHA256 = 'b9dd13a23b6bb0b8919eafd5737ecfb9495ac84dc7964d58335e8961a9c08f9f'
EXPECTED_STATE_SHA256 = '0974206cdeecb306fe4b8719edc3d1d47977c28c71b08f5450a97cee241e84af'
STDLIB_FILES = (*BASE_STDLIB_FILES, 'posix.zig', 'hash_map.zig', 'compress/flate.zig', 'compress/flate/Decompress.zig', 'compress/flate/Token.zig', 'compress/flate/HuffmanEncoder.zig', 'math.zig', 'math/pow.zig', 'math/powi.zig')
PINNED_STDLIB_SHA256 = 'f7d294645f1474fc6c53ea214299928b8b3ae073e20103f97f650fdfb69185d1'


def stdlib_hash(zig):
    digest = hashlib.sha256()
    for name in STDLIB_FILES:
        digest.update(name.encode() + b'\0')
        digest.update((zig.parent / 'lib/std' / name).read_bytes())
    return digest.hexdigest()


BUFFERS = (0,4,8,16,64)
COMPRESSION = (1,2,3,4,5,6,8,32771,32773,32946)
SUPPORTED = (1,2,5,8,32773,32946)
from verify_tiff_enums_reference import directory, short


def palette_data(endian,bits=8,count=None,datatype=3,pattern=0,include_bits=True):
    colors=1<<bits
    if count is None:count=max(6,colors*3)
    tags=[(256,4,1,123),(257,4,1,456)]
    if include_bits:tags.append(short(endian,258,bits))
    tags.append((320,datatype,count,0))
    start=len(directory(endian,tags))
    tags[-1]=(320,datatype,count,0x12345678 if count==1 else start)
    order='<' if endian==0 else '>'
    limit=65535 if datatype==3 else 0xffffffff
    values=[((i*251+17) if pattern==0 else (0x12345678+i*0x01010101))&limit for i in range(count)]
    if datatype not in (3,4):values=[v&65535 for v in values]
    stride='H' if datatype==3 else 'I'
    payload=struct.pack(order+stride*len(values),*values)
    return directory(endian,tags)+payload+b'\x63\x58\x4d'


def palette_spec(capacity,endian,data,reservation=0,reads=2):
    return f'{capacity}|{endian}|1|{reads}|{data.hex()}|{reservation}|0|0'


def format_spec(compression=1,photo=0,bits=(8,),extra=(1,),fill=1,predictor=1,reads=2):
    return f"0|0|4|{reads}||{compression}|{photo}|{(predictor<<16)|fill}|"+','.join(map(str,bits))+'|'+','.join(map(str,extra))


def corpus():
    out=[]
    patterns=((),(1,),(4,),(8,),(16,),(8,8),(8,8,8),(8,8,8,8),(8,8,8,7),(7,8,8,8),(8,)*8)
    for compression,photo,bits,extra,flags in itertools.product(COMPRESSION,(0,1,2,3,4,65535),patterns,((0,),(1,),(2,),(3,),(65535,),()),((1,1),(1,2),(2,1),(65535,65535))):
        if compression in SUPPORTED and ((photo in (0,1,3) and not bits) or (photo==2 and len(bits)==4 and not extra)):continue
        out.append(('format-selection',format_spec(compression,photo,bits,extra,*flags)))
    for endian,datatype,bits,pattern,reservation,capacity in itertools.product((0,1),(3,4),(0,1,2,4,8),(0,1),(0,6,24,200),BUFFERS):
        data=palette_data(endian,bits,datatype=datatype,pattern=pattern)
        out.append(('complete-palettes',palette_spec(capacity,endian,data,reservation)))
    for endian,capacity in itertools.product((0,1),BUFFERS):
        data=palette_data(endian,1)
        end=len(directory(endian,[(256,4,1,123),(257,4,1,456),short(endian,258,1),(320,3,6,0)]))
        for cut in range(end):out.append(('ifd-prefix-before-palette',palette_spec(capacity,endian,data[:cut])))
    return out


def traps():
    out={}
    for endian,datatype,count,reservation,capacity in itertools.product((0,1),(3,4),range(6),(0,200),BUFFERS):
        # Without a bits tag, decodeBitmap resets the depth to one before lookup.
        data=palette_data(endian,1,count,datatype,include_bits=False)
        name=f'palette-short-{endian}-{datatype}-{count}-{reservation}-{capacity}'
        out[name]=(palette_spec(capacity,endian,data,reservation,1),'index out of bounds')
    for compression,photo in itertools.product(SUPPORTED,(0,1,3)):
        name=f'empty-bits-{compression}-{photo}'
        out[name]=(format_spec(compression,photo,(),(),reads=1),'index out of bounds')
    for compression,bits in itertools.product(SUPPORTED,((8,8,8,8),(7,8,8,8),(8,8,8,7))):
        name=f'empty-extra-{compression}-'+','.join(map(str,bits))
        out[name]=(format_spec(compression,2,bits,(),reads=1),'index out of bounds')
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
    probe = repo / 'zigimg/reference_probes/tiff_palette'
    env = dict(os.environ, VEXE=str(v), V_C_ERROR_BUG_REPORT_DISABLED='1')
    with work_directory(args.workdir, 'witty-tiff-palette-') as root:
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
        print(f'Building TIFF palette: Source {mode}, V {"production" if args.v_prod else "ordinary"}', flush=True)
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
                       read_attempts=sum(int(data.split('|')[3]) for _,data in rows), output_sha256=digest,
                       paired_traps=len(traps()), state_sha256=state_digest, zig_mode=mode, v_prod=args.v_prod)
        (root / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
        print(json.dumps(summary), flush=True)


if __name__ == '__main__':
    main()
