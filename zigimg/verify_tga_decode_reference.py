"""Compare public TGA decoding, buffered RLE, retries and retained state."""
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

EXPECTED_ROWS = 20576
EXPECTED_SHA256 = 'cacb26414a35edad54b8c5a41d39b951a5c50cb48ffc26a9544b5c14e381615c'
EXPECTED_STATE_SHA256 = '62c58cd4c95bfb8d3f1ac53c9d2ba87b8a67be00fd97ef637b5f6c17933079d2'
EXPECTED_VECTOR_SHA256 = 'd9028cc6d0c1cb767a3739f9a4da6a994338cfcf11b752a6c3a6ad5a4a11fc2e'
BUFFERS = (0, 26, 31, 64, 128, 512, 4096)
STDLIB_FILES = (*BASE_STDLIB_FILES, 'posix.zig')
PINNED_STDLIB_SHA256 = 'ed900ae630673721b5aca890da4d432f4f1bfbbb201d5e450861b8111ab9a27d'


def stdlib_hash(zig):
    digest = hashlib.sha256()
    for name in STDLIB_FILES:
        digest.update(name.encode() + b'\0')
        digest.update((zig.parent / 'lib/std' / name).read_bytes())
    return digest.hexdigest()


def image(bpp=1, width=1, height=1, body=b'', compressed=True, top=True, identifier=True,
          attributes=None, kind=None, bits=None):
    header = bytearray(18)
    header[0] = 3 if identifier else 0
    header[2] = kind if kind is not None else (3 if bpp == 1 else 2) | (8 if compressed else 0)
    header[12:16] = struct.pack('<HH', width, height)
    header[16] = bpp * 8 if bits is None else bits
    header[17] = 32 if top else 0
    data = bytes(header) + (b'ID!' if identifier else b'') + body
    footer = bytearray(26)
    if attributes is not None:
        footer[:4] = struct.pack('<I', len(data))
        footer[8:24] = b'TRUEVISION-XFILE'
        footer[24] = ord('.')
        extension = bytearray(495)
        extension[:2] = struct.pack('<H', 495)
        extension[494] = attributes
        data += extension
    return data + footer


def packets(bpp, pattern):
    data = bytearray()
    for packet in range(8):
        pixel = bytes((packet * 17 + channel * 31) & 255 for channel in range(bpp))
        if pattern == 'repeat' or (pattern == 'mixed' and packet % 2):
            data += b'\xff' + pixel
        else:
            count = 32 if pattern == 'mixed' else 128
            data.append(count - 1)
            data += bytes((packet * 17 + p * 3 + channel * 31) & 255
                          for p in range(count) for channel in range(bpp))
    return bytes(data)


def corpus():
    rows = []
    def add(group, data, buffers=BUFFERS, reads=1):
        for capacity in buffers:
            rows.append((group, f'{capacity}|{reads}|{data.hex()}'))
    for bpp, pattern, width, height, top in itertools.product(
            range(1, 5), ('raw', 'repeat', 'mixed'),
            (0, 1, 8, 127, 128, 129, 170, 171, 255, 256, 511, 512, 513), (0, 1, 2), (False, True)):
        add('packets', image(bpp, width, height, packets(bpp, pattern), top=top))
    for bpp, pattern, width in itertools.product(range(1, 5), ('raw', 'repeat', 'mixed'), (1, 129, 513)):
        data = image(bpp, width, 1, packets(bpp, pattern))
        cuts = set(range(32)) | {len(data) - n for n in (0, 1, 2, 25, 26, 27)}
        cuts |= {21 + n for n in (1, 2, 3, 4, 5, 7, 8, 25, 26, 27, 31, 32, 33, 127, 128, 129, 255, 256, 257, 511, 512, 513)}
        for cut in sorted(c for c in cuts if c <= len(data)):
            add('truncation', data[:cut])
    for bpp, compressed, width, top in itertools.product(range(1, 5), (False, True), (1, 3, 129), (False, True)):
        body = packets(bpp, 'mixed') if compressed else bytes(i & 255 for i in range(width * bpp))
        add('retry', image(bpp, width, 1, body, compressed, top, identifier=False), reads=2)
    for bpp, width, top in itertools.product(range(1, 5), (0, 1, 3, 129), (False, True)):
        data = image(bpp, width, 1, bytes(i & 255 for i in range(width * bpp)), compressed=False, top=top)
        add('uncompressed', data)
    for kind, bits, width, body in itertools.product((0, 1, 2, 3, 4, 8, 10, 11, 16, 255),
            (0, 1, 7, 8, 15, 16, 24, 32, 248), (0, 1), (b'', b'\xff\x11' * 8)):
        # Valid indexed headers with map depth zero return Unsupported before
        # exposing palette storage; grayscale ignores the bit-depth field.
        add('format', image(width=width, body=body, kind=kind, bits=bits), buffers=(0, 31, 512))
    for attributes, compressed, kind in itertools.product(range(5), (False, True), (2, 3, 255)):
        data = image(4, 1, 1, b'\x80\x01\x02\x03\x04' if compressed else b'\x01\x02\x03\x04',
                     compressed=compressed, attributes=attributes, kind=kind | (8 if compressed else 0))
        add('extension', data, buffers=(0, 495, 512, 4096), reads=2)
    return rows


def traps():
    cases = {}
    data = image(body=packets(1, 'raw'))
    for capacity in (1, 17, 18, 25):
        cases[f'footer-capacity-{capacity}'] = (f'{capacity}|1|{data.hex()}', 'reached unreachable code', 'reached unreachable code')
    data = image(attributes=3)
    for capacity in (26, 31, 128):
        cases[f'extension-capacity-{capacity}'] = (f'{capacity}|1|{data.hex()}', 'reached unreachable code', 'reached unreachable code')
    for capacity, bits in itertools.product((0, 26, 31, 512), (249, 255)):
        data = image(width=0, body=b'', bits=bits)
        cases[f'pixel-byte-{capacity}-{bits}'] = (f'{capacity}|1|{data.hex()}', 'integer overflow', 'integer overflow')
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
    probe = repo / 'zigimg/reference_probes/tga_decode'
    env = dict(os.environ, VEXE=str(v), V_C_ERROR_BUG_REPORT_DISABLED='1')
    with work_directory(args.workdir, 'witty-tga-decode-') as root:
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
        implementations = implementation_hashes(repo)
        runner_hash = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
        (root / 'provenance.json').write_text(json.dumps(dict(
            source_sha256=PINNED_SOURCE_SHA256, stdlib_sha256=PINNED_STDLIB_SHA256,
            versions=versions, target=args.target, zig_mode=mode, v_prod=args.v_prod,
            fixtures=fixtures, implementation_sha256=implementations, runner_sha256=runner_hash), indent=2) + '\n')
        print(f'Building TGA decode: Source {mode}, V {"production" if args.v_prod else "ordinary"}', flush=True)
        proof.run([str(zig), 'build-exe', '-target', args.target, '-lc', '-O', mode,
                   '--global-cache-dir', str(root / 'zig-global'), '-femit-bin=' + str(root / 'native'),
                   str(root / 'reference.zig')], 'build-source', timeout=args.timeout)
        proof.run([str(v), '-enable-globals', *(['-prod'] if args.v_prod else []), '-path',
                   f'{repo}|@vlib|@vmodules', '-o', str(root / 'translated'), str(root / 'main.v')],
                  'build-v', env=env, timeout=args.timeout)
        rows = corpus()
        path = root / 'corpus.txt'
        path.write_text('\n'.join(data for _, data in rows) + '\n')
        outputs = []
        for exe in ('native', 'translated'):
            r = proof.run([str(root / exe), str(path)], 'returning-' + exe, timeout=args.timeout, check=False)
            if r.returncode or r.stderr or len(r.stdout.splitlines()) != len(rows):
                raise AssertionError(f'{exe}: invalid returning output ({r.returncode}, {len(r.stdout.splitlines())} rows); see raw proof files')
            outputs.append(r.stdout.splitlines())
        for index, (native, translated) in enumerate(zip(*outputs)):
            if native != translated:
                raise AssertionError(f'{index}/{rows[index][0]}: Source={native[:200]!r}, V={translated[:200]!r}; see retained corpus/output')
        digest = hashlib.sha256(b'\n'.join(outputs[0])).hexdigest()
        if EXPECTED_ROWS is not None and len(rows) != EXPECTED_ROWS: raise AssertionError('corpus changed')
        if EXPECTED_SHA256 is not None and digest != EXPECTED_SHA256: raise AssertionError('returning golden changed')
        vectors = []
        for exe in ('native', 'translated'):
            r = proof.run([str(root / exe), '--vectors', str(root / (exe + '-vectors.bin'))],
                          'vectors-' + exe, timeout=args.timeout)
            if r.stderr or len(r.stdout.splitlines()) != 48: raise AssertionError('invalid vector-read observations')
            vectors.append(r.stdout.splitlines())
        if vectors[0] != vectors[1]: raise AssertionError('positional vector-read state differs; see raw proof files')
        vector_digest = hashlib.sha256(b'\n'.join(vectors[0])).hexdigest()
        if EXPECTED_VECTOR_SHA256 is not None and vector_digest != EXPECTED_VECTOR_SHA256: raise AssertionError('vector-read golden changed')
        print(f'{len(rows)} returning rows match; checking failure state', flush=True)
        states = hashlib.sha256()
        for name, (data, zcategory, vcategory) in traps().items():
            observed = []
            for exe, category in (('native', zcategory), ('translated', vcategory)):
                path = root / (name + '-' + exe + '.state')
                r = proof.run([str(root / exe), '--trap', str(path), data], name + '-' + exe,
                              timeout=args.timeout, check=False)
                checked_trap(r, name + '/' + exe, category)
                if not path.exists(): raise AssertionError('missing panic observer')
                observed.append(path.read_bytes())
            if not observed[0] or observed[0] != observed[1]: raise AssertionError(f'{name}: differing states {observed}')
            states.update(name.encode() + b'\0' + observed[0] + b'\n')
        state_digest = states.hexdigest()
        if EXPECTED_STATE_SHA256 is not None and state_digest != EXPECTED_STATE_SHA256: raise AssertionError('failure-state golden changed')
        if (tree_hash(source) != PINNED_SOURCE_SHA256 or tree_hash(root / 'src') != PINNED_SOURCE_SHA256
                or stdlib_hash(zig) != PINNED_STDLIB_SHA256 or implementation_hashes(repo) != implementations
                or hashlib.sha256(Path(__file__).read_bytes()).hexdigest() != runner_hash):
            raise AssertionError('dependency, implementation or runner changed')
        for name, expected in fixtures.items():
            if any(hashlib.sha256((p / name).read_bytes()).hexdigest() != expected for p in (root, probe)):
                raise AssertionError('fixture changed')
        summary = dict(returning_records=len(rows), returning_groups=dict(Counter(group for group, _ in rows)),
                       read_attempts=sum(int(data.split('|')[1]) for _, data in rows), output_sha256=digest,
                       vector_read_records=48, vector_read_sha256=vector_digest,
                       paired_traps=len(traps()), state_sha256=state_digest, zig_mode=mode, v_prod=args.v_prod)
        (root / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
        print(json.dumps(summary), flush=True)


if __name__ == '__main__':
    main()
