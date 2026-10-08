"""Compare the pinned direct PNG chunk writer in ordinary and production builds."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import zlib

from verify_png_foundation_reference import PINNED_SOURCE_SHA256, PINNED_FLATE_SHA256
from verify_png_filtering_reference import strict_panic, stdlib_hash, checked_helpers_hash, PINNED_HELPERS_SHA256
from verify_tiff_decode_reference import ProofLog, tree_hash, work_directory
from verify_simd_reference import ordinary_rejection

REPO = Path(__file__).resolve().parent.parent
PROBE = REPO / 'zigimg/reference_probes/png_chunk_writer'
EXPECTED_SHA256 = '934ba176552e9370b30073ea1f648fab7dcb4ca85424296097b173f4d298115e'
EXPECTED_EXTENSION_ROWS = 28
EXPECTED_EXTENSION_SHA256 = '4632f854f9f77422d2de7a764c23a1a4fd81ff8223c310bcfb53f8032841e317'


def corpus():
    cases = []
    for size in (0, 1, 4, 16, 16384):
        data = bytes((i*37+11) & 255 for i in range(size+3))
        sequences = [[], [b""], [b"a"], [data[:size]], [data[:size+1]],
                     [data[:size], b"x"], [data[:1], data[:size], data],
                     [data[:size//2], data[:size//2+1], data, b""],
                     [data[:size], b"", data[:size], data[:size]],
                     [b"a", b"bc", b"def", b"ghij", data]]
        capacities = sorted(set(range(25)) | {max(0,size+offset) for offset in (0,1,4,7,8,11,12,13,24,100)} | {size*3+100})
        for index, writes in enumerate(sequences):
            for capacity in capacities:
                for maximum in (0, 1, 3, size+1):
                    operations = ",".join(["W"+data.hex() for data in writes]+["F", "F"])
                    cases.append((f"size{size}-sequence{index}-capacity{capacity}-max{maximum}", f"{size}|{capacity}|{maximum}|{operations}"))
    return cases



def verify(args, root):
    source = args.source.resolve() / 'src'
    zig = args.zig.resolve()
    if (tree_hash(source) != PINNED_SOURCE_SHA256 or stdlib_hash(zig) != PINNED_FLATE_SHA256 or
            checked_helpers_hash(zig) != PINNED_HELPERS_SHA256):
        raise AssertionError('dependency differs from pinned source/compiler')
    shutil.copytree(source, root / 'src')
    fixtures = {}
    for name in ('reference.zig', 'main.v'):
        shutil.copyfile(PROBE / name, root / name)
        fixtures[name] = hashlib.sha256((PROBE / name).read_bytes()).hexdigest()
    mode = args.zig_mode or ('ReleaseSafe' if args.v_prod else 'Debug')
    (root / 'provenance.json').write_text(json.dumps({
        'source_sha256': PINNED_SOURCE_SHA256, 'stdlib_sha256': PINNED_FLATE_SHA256,
        'checked_helpers_sha256': PINNED_HELPERS_SHA256,
        'zig_mode': mode, 'v_prod': args.v_prod, 'target': args.target, 'fixtures': fixtures,
    }, indent=2) + '\n')
    proof = ProofLog(root)
    base = [str(zig), 'build-exe', '-target', args.target, '-lc', '-O', mode,
            '--global-cache-dir', str(root / 'zig-global')]
    proof.run(base + ['-femit-bin=' + str(root / 'native'), str(root / 'reference.zig')], 'build-source')
    v_base = [str(args.v.resolve()), *(['-prod'] if args.v_prod else []), '-path', f'{REPO}|@vlib|@vmodules']
    environment = dict(os.environ, VEXE=str(args.v.resolve()), V_C_ERROR_BUG_REPORT_DISABLED='1')
    proof.run(v_base + ['-o', str(root / 'translated'), str(root / 'main.v')], 'build-v', env=environment)
    cases = corpus()
    if len(cases) != 5960: raise AssertionError('historical corpus changed')
    path = root / 'corpus.txt'
    path.write_text('\n'.join(case[1] for case in cases) + '\n')
    outputs = []
    for executable in ('native', 'translated'):
        result = proof.run([str(root / executable), str(path)], 'returning-' + executable, timeout=args.timeout)
        if result.stderr: raise AssertionError(executable + ': returning stderr')
        outputs.append(result.stdout.splitlines())
    if any(len(rows) != len(cases) for rows in outputs): raise AssertionError('returning row count')
    for (label, _), native, translated in zip(cases, *outputs):
        if native != translated: raise AssertionError(f'{label}: {native!r} != {translated!r}')
    digest = hashlib.sha256(b'\n'.join(outputs[0])).hexdigest()
    if digest != EXPECTED_SHA256: raise AssertionError('historical hash changed: ' + digest)
    extensions = [(name, 64) for name in ('empty', 'empty_full', 'adjacent', 'copy')]
    extensions += [('corrupt_error', capacity) for capacity in range(8)]
    extensions += [('overlap_error', capacity) for capacity in range(16)]
    if len(extensions) != EXPECTED_EXTENSION_ROWS: raise AssertionError('extension corpus changed')
    extension_outputs = []
    for name, capacity in extensions:
        result_rows = []
        for executable in ('native', 'translated'):
            result = proof.run([str(root / executable), '--case', name, str(capacity)], f'returning-{executable}-{name}-{capacity}')
            if result.stderr: raise AssertionError('returning extension stderr')
            result_rows.append(result.stdout)
        if result_rows[0] != result_rows[1]: raise AssertionError((name, capacity, result_rows))
        extension_outputs.append(result_rows[0].rstrip(b'\n'))
    crc = zlib.crc32(b'IDAT' + bytes((1, 2, 3, 4)))
    traps = {
        'overflow': ('integer overflow', ()),
        'bounds': ('index out of bounds', ('TRACE int 5', 'TRACE bytes 4')),
        'max_flush': ('index out of bounds', ('TRACE int 4294967295', 'TRACE bytes 4')),
        'same': ('@memcpy arguments alias', ()),
        'overlap': ('@memcpy arguments alias', ()),
        'overlap_flush': ('@memcpy arguments alias', ('TRACE int 4', 'TRACE bytes 4', 'TRACE bytes 4', f'TRACE int {crc}')),
    }
    for name, (category, trace) in traps.items():
        for executable in ('native', 'translated'):
            label = f'trap-{executable}-{name}'
            result = proof.run([str(root / executable), '--case', name, '64'], label, check=False, timeout=15)
            strict_panic(result, label, category, trace)
    for name, category in (('bad_id', 'PNG chunk id must be 4 characters'),
                           ('bad_slice', 'PNG chunk slice storage must have zero capacity')):
        result = proof.run([str(root / 'translated'), '--case', name, '64'], 'v-adapter-' + name, check=False, timeout=15)
        strict_panic(result, name, category)
    # Verify original compiler failures without replacing the dependency bodies.
    failures = {
        'legacy-writer': ('const S=struct{pub const Error=error{WriteFailed};}; pub fn main() void { _=@sizeOf(@import("src/formats/png/chunk_writer.zig").ChunkWriter(4,S).Writer); }', "type 'type' not a function"),
        'zlib-compressor': ('pub fn main() void { _=@sizeOf(@import("src/formats/png/zlib_compressor.zig").ZlibCompressor(@import("std").Io.Writer)); }', "no member named 'Compressor'"),
        'invalid-id': ('const cw=@import("src/formats/png/chunk_writer.zig");const S=struct{pub const Error=error{WriteFailed};}; pub fn main() void { _=cw.chunkWriter(S{},"abc"); }', 'PNG chunk id must be 4 characters'),
    }
    for name, (content, marker) in failures.items():
        consumer = root / (name + '.zig')
        consumer.write_text(content + '\n')
        result = proof.run(base + ['-fno-emit-bin', str(consumer)], 'source-boundary-' + name, check=False)
        ordinary_rejection(result, name)
        if marker.encode() not in result.stdout + result.stderr: raise AssertionError('wrong compiler boundary: ' + name)
    if (tree_hash(source) != PINNED_SOURCE_SHA256 or tree_hash(root / 'src') != PINNED_SOURCE_SHA256 or
            stdlib_hash(zig) != PINNED_FLATE_SHA256 or
            checked_helpers_hash(zig) != PINNED_HELPERS_SHA256 or
            any(hashlib.sha256((PROBE / name).read_bytes()).hexdigest() != digest for name, digest in fixtures.items())):
        raise AssertionError('dependency/fixture changed during comparison')
    extension_digest = hashlib.sha256(b'\n'.join(extension_outputs)).hexdigest()
    if extension_digest != EXPECTED_EXTENSION_SHA256: raise AssertionError('extension output hash changed: ' + extension_digest)
    summary = {'returning': len(cases), 'sha256': digest, 'extensions': len(extensions),
               'extension_sha256': extension_digest, 'strict_trap_pairs': len(traps),
               'v_adapter_traps': 2, 'unsupported_source_helpers': 2, 'source_id_rejection': 1,
               'zig_mode': mode, 'v_prod': args.v_prod}
    (root / 'result.json').write_text(json.dumps(summary, indent=2) + '\n')
    print(f'PNG chunk writer {mode}: {len(cases)} historical records, SHA256 {digest}; '
          f'{len(extensions)} returning extensions, SHA256 {extension_digest}; '
          f'{len(traps)} strict trap pairs, 2 V adapter traps, 2 unchanged-source unsupported helpers and 1 source ID rejection', flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('zig', type=Path)
    parser.add_argument('v', type=Path)
    parser.add_argument('--target', default='aarch64-macos.14.0')
    parser.add_argument('--v-prod', action='store_true')
    parser.add_argument('--zig-mode', choices=('Debug', 'ReleaseSafe'))
    parser.add_argument('--workdir', type=Path)
    parser.add_argument('--timeout', type=float, default=180)
    args = parser.parse_args()
    with work_directory(args.workdir, 'witty-png-chunk-') as root: verify(args, root)


if __name__ == '__main__': main()
