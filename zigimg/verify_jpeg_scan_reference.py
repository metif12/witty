"""Compare public JPEG Scan records, parsing and checked MCU traversal."""
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

from verify_jpeg_contracts_reference import (
    implementation_hashes, PINNED_STDLIB_SHA256, stdlib_hash,
)
from verify_png_header_reference import checked_trap
from verify_simd_reference import ordinary_rejection
from verify_tiff_decode_reference import (
    PINNED_SOURCE_SHA256, ProofLog, tree_hash, work_directory,
)

EXPECTED_ROWS = 76400
EXPECTED_SHA256 = '22ff0ced5a3fb14f5f80f8ff99e012a7f2bb78d38b34e92baf202990342408c8'
EXPECTED_STATE_SHA256 = '26a190953880f66299ebb8834f75b8ad3603c881efa5285386a06543b17fd46e'


def header(ids=(1,), selector=0, start=0, end=63, approximation=0, size=None):
    return (struct.pack('>HB', size if size is not None else 2 * len(ids) + 6, len(ids))
            + b''.join(bytes((value, selector)) for value in ids)
            + bytes((start, end, approximation)))


def row(op, data, *, marker=0xffc0, ids=(1,), tables=255, x=1, y=1,
        width=1, height=1, actual=4, blocks=16, restart=0, sampling=0x11,
        value=0, dc=0, ac=0):
    return '|'.join(map(str, (op, data.hex(), marker, ','.join(map(str, ids)), tables,
                              x, y, width, height, actual, blocks, restart, sampling,
                              value, dc, ac)))


def corpus():
    rows = [row('C', bytes((component, selector)))
            for component, selector in itertools.product(range(256), repeat=2)]
    rows += [row('C', b''), *(row('C', bytes((value,))) for value in (0, 1, 127, 255))]
    windows = ((0, 0), (0, 63), (1, 63), (3, 3), (63, 63), (64, 64), (1, 0))
    for count, marker, (start, end), approximation, slot in itertools.product(
            range(1, 5), (0xffc0, 0xffc1, 0xffc2), windows, (0, 15, 16, 255), range(4)):
        for ids, wanted, mask in (((1,), 1, 0), ((1,), 7, 0),
                                  ((), 7, 1 << slot), ((), 7, 1 << (slot + 4)),
                                  ((1,), 1, 255)):
            rows.append(row('I', header((wanted,) * count, slot * 17, start, end, approximation),
                            marker=marker, ids=ids, tables=mask))
    for count in (0, 5, 255):
        rows.append(row('I', struct.pack('>HB', 6, count)))
    for count in range(1, 5):
        data = header((1,) * count)
        rows += [row('I', data[:cut]) for cut in range(len(data) + 1)]
    # Earlier validation errors retain priority over the late segment assertion.
    for size, start, end in itertools.product((0, 1, 7, 65535), (1, 64, 255), (0, 63)):
        rows.append(row('I', header(start=start, end=end, size=size)))
    for count, value in itertools.product(range(1, 5), range(256)):
        rows.append(row('R', header((1,) * count), value=value))

    # Every coefficient lane is initialized; no progressive undefined storage is observed.
    spectra = ((0, 63, 0, 0xffc0), (0, 0, 0, 0xffc2), (0, 0, 15, 0xffc2),
               (0, 0, 16, 0xffc2), (0, 0, 31, 0xffc2), (1, 63, 0, 0xffc2),
               (1, 63, 3, 0xffc2), (1, 63, 16, 0xffc2), (1, 63, 19, 0xffc2),
               (0, 63, 0, 0xffc1))
    payloads = (b'', b'\0', b'\0' * 3, b'\0' * 16, b'\0' * 128,
                b'\xff\0' * 32, b'\xff\xd0\0' * 32, b'\xff\xd9')
    for (start, end, approximation, marker), ids, (width, height), factor, payload in itertools.product(
            spectra, ((1,), (2,), (1, 2, 3)), ((0, 0), (1, 1), (3, 3)), range(1, 5), payloads):
        rows.append(row('P', header(ids, 0, start, end, approximation) + payload,
                        marker=marker, ids=ids, width=width, height=height,
                        x=factor, y=factor, sampling=factor * 17))
    for dc, ac, restart, factor in itertools.product((0, 1, 3, 11, 12), (0, 11), (0, 1, 3, 65535), range(1, 5)):
        rows.append(row('P', header((2,)) + b'\0' * 128, ids=(2,), dc=dc, ac=ac,
                        width=3, height=3, restart=restart, x=factor, y=factor, sampling=factor * 17))
    return rows


def traps():
    result = {}
    for selector in range(4, 16):
        result[f'selector-{selector}'] = (row('I', header(selector=selector << 4)),
                                        f'index out of bounds: index {selector}, len 4')
    for size in (0, 1, 7, 9, 65535):
        result[f'length-{size}'] = (row('I', header(size=size)), 'reached unreachable code')
    for marker in (0xffc0, 0xffc1, 0xffc2):
        result[f'block-before-fill-{marker}'] = (
            row('P', header(end=0 if marker == 0xffc2 else 63) + b'\0' * 8,
                marker=marker, blocks=0), 'index out of bounds: index 0, len 0')
    result['component-before-fill'] = (
        row('P', header((4,)) + b'\0' * 8, ids=(1, 2, 3, 4)),
        'index out of bounds: index 3, len 3')
    for name, x, y, restart in (('restart-y-overflow', 1, 1 << 63, 2),
                                ('restart-x-overflow', 1 << 63, 1, 2),
                                ('restart-zero-x', 0, 1, 1), ('restart-zero-y', 1, 0, 1)):
        result[name] = (row('P', header((2,)) + b'\0' * 8, ids=(2,),
                            x=x, y=y, restart=restart),
                        'division by zero' if x == 0 or y == 0 else 'integer overflow')
    for tables, name in ((0, 'missing-dc'), (1, 'missing-ac')):
        result[name] = (row('P', header() + b'\0' * 8, tables=tables), 'attempt to use null value')
    return result


def constructors(proof, root, zbase, vbase, env, timeout):
    zprefix = ('const std=@import("std");const S=@import("src/formats/jpeg/Scan.zig");'
               'const F=@import("src/formats/jpeg/Frame.zig");'
               'const Q=@import("src/formats/jpeg/quantization.zig").Table;'
               'const H=@import("src/formats/jpeg/huffman.zig");'
               'const io=@import("src/io.zig");const a=std.heap.page_allocator;'
               'pub fn main() void {var stream=io.ReadStream.initMemory(&.{});'
               'var q:[4]?Q=@splat(null);var dc:[4]?H.Table=@splat(null);var ac:[4]?H.Table=@splat(null);'
               'var f:F=.{.allocator=a,.frame_header=.{.allocator=a,.sample_precision=8,.width=0,.height=0,.components=&.{}},'
               '.quantization_tables=&q,.dc_huffman_tables=&dc,.ac_huffman_tables=&ac,.block_storage=&.{},.frame_type=.sof0};')
    vprefix = ('module main\nimport zigimg as p\nfn main(){\n'
               'mut stream:=p.ReadStream.init_memory([]u8{})\nmut jpeg:=p.JPEG.init()\n'
               'mut f:=p.JpegFrame{frame_header:p.JpegFrameHeader{sample_precision:8,width:0,height:0,components:[]p.JpegComponent{}},'
               'quantization_tables:&jpeg.quantization_tables,dc_huffman_tables:&jpeg.dc_huffman_tables,'
               'ac_huffman_tables:&jpeg.ac_huffman_tables,block_storage:[]p.JpegBlockComponents{},frame_type:0xffc0}\n')

    def pair(label, zbody, vbody, zmarker=None, vmarker=None):
        zp, vp = root / (label + '.zig'), root / (label + '.v')
        zp.write_text(zprefix + zbody + '_=&f;_=&stream;}\n')
        vp.write_text(vprefix + vbody + '\n_=f\n_=stream\n}\n')
        for language, command, marker in (
                ('Source', zbase + ['-fno-emit-bin', str(zp)], zmarker),
                ('V', vbase + ['-check', str(vp)], vmarker)):
            r = proof.run(command, label + '-' + language, env=env, timeout=timeout, check=False)
            diagnostic = (r.stdout + r.stderr).decode(errors='replace')
            errors = [line for line in diagnostic.splitlines() if re.search(r'\berror:', line)]
            if marker is None:
                if r.returncode or errors:
                    raise AssertionError(f'{label}/{language}: expected acceptance\n{diagnostic}')
            else:
                ordinary_rejection(r, label + '/' + language)
                if not any(marker in line for line in errors):
                    raise AssertionError(f'{label}/{language}: missing actual error {marker!r}\n{diagnostic}')

    records = (
        ('Spec', 'S.ScanComponentSpec', 'JpegScanComponentSpec', {
            'component_id': ('1', '1'), 'dc_table_selector': ('0', '0'), 'ac_table_selector': ('0', '0')}),
        ('Scan', 'S', 'JpegScan', {
            'frame': ('&f', '&f'), 'reader': ('H.Reader.init(&stream)', 'p.JpegHuffmanReader.init(mut stream)'),
            'components': ('@splat(null)', '[4]?p.JpegScanComponentSpec{init:none}'),
            'component_count': ('1', '1'), 'start_of_spectral_selection': ('0', '0'),
            'end_of_spectral_selection': ('63', '63'), 'approximation_high': ('0', '0'),
            'approximation_low': ('0', '0'), 'prediction_values': ('@splat(0)', '[3]int{}')}))

    def body(zkind, vkind, fields, missing=None, mutable=False):
        zfields = ','.join('.' + k + '=' + val[0] for k, val in fields.items() if k != missing)
        vfields = ','.join(k + ':' + val[1] for k, val in fields.items() if k != missing)
        return (('var' if mutable else 'const') + ' x:' + zkind + '=.{' + zfields + '};',
                ('mut ' if mutable else '') + 'x:=p.' + vkind + '{' + vfields + '}\n')

    for label, zkind, vkind, fields in records:
        z, v = body(zkind, vkind, fields)
        pair('complete-' + label, z + '_=x;', v + '_=x')
        for missing in fields:
            z, v = body(zkind, vkind, fields, missing)
            pair('missing-' + label + '-' + missing, z + '_=x;', v + '_=x',
                 'missing struct field: ' + missing, 'zigimg.' + vkind + '.' + missing)
        name = 'component_id' if label == 'Spec' else 'component_count'
        z, v = body(zkind, vkind, fields)
        pair('readonly-' + label, z + f'x.{name}=2;', v + f'x.{name}=2',
             'cannot assign to constant', 'immutable')
        for name in (('dc_table_selector', 'ac_table_selector') if label == 'Spec'
                     else ('approximation_high', 'approximation_low')):
            wide = dict(fields, **{name: ('16', '16')})
            z, v = body(zkind, vkind, wide)
            pair('wide-' + label + '-' + name, z + '_=x;', v + '_=x',
                 "type 'u4' cannot represent integer value '16'")
    _, zkind, vkind, fields = records[1]
    z, v = body(zkind, vkind, fields, mutable=True)
    pair('frame-const-pointee', z + 'x.frame.block_width=1;', v + 'x.frame.block_width=1',
         'cannot assign to constant')


def loops(proof, root):
    for name, x, y in (('x', 0, 1), ('y', 1, 0)):
        path = root / ('zero-step-' + name + '.txt')
        path.write_text(row('P', header((2,)), ids=(2,), x=x, y=y, sampling=0) + '\n')
        for exe in ('native', 'translated'):
            label = 'zero-step-' + name + '-' + exe
            try:
                proof.run([str(root / exe), str(path)], label, timeout=0.5, check=False)
            except AssertionError:
                if not proof.commands[-1].get('timed_out'):
                    raise
                prefix = f'{len(proof.commands) - 1:03d}-{label}'
                if any((root / f'{prefix}.{ext}').read_bytes() for ext in ('stdout', 'stderr')):
                    raise AssertionError('output before loop timeout')
            else:
                raise AssertionError('zero-step loop returned')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('zig', type=Path)
    parser.add_argument('v', type=Path)
    parser.add_argument('--workdir', type=Path)
    parser.add_argument('--target', default='aarch64-macos.14.0')
    parser.add_argument('--v-prod', action='store_true')
    parser.add_argument('--timeout', type=int, default=180)
    args = parser.parse_args()
    if args.timeout <= 0:
        parser.error('--timeout must be positive')
    source, zig, v = args.source.resolve() / 'src', args.zig.resolve(), args.v.resolve()
    if tree_hash(source) != PINNED_SOURCE_SHA256 or stdlib_hash(zig) != PINNED_STDLIB_SHA256:
        parser.error('Source or compiler library differs from pins')
    repo = Path(__file__).resolve().parent.parent
    probe = repo / 'zigimg/reference_probes/jpeg_scan'
    env = dict(os.environ, VEXE=str(v), V_C_ERROR_BUG_REPORT_DISABLED='1')
    mode = 'ReleaseSafe' if args.v_prod else 'Debug'
    with work_directory(args.workdir, 'witty-jpeg-scan-') as root:
        proof = ProofLog(root)
        shutil.copytree(source, root / 'src')
        fixtures = {}
        for name in ('main.v', 'reference.zig'):
            shutil.copyfile(probe / name, root / name)
            fixtures[name] = hashlib.sha256((probe / name).read_bytes()).hexdigest()
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
        zbase = [str(zig), 'build-exe', '-target', args.target, '-lc', '-O', mode,
                 '--global-cache-dir', str(root / 'zig-global')]
        vbase = [str(v), '-enable-globals', *(['-prod'] if args.v_prod else []),
                 '-path', f'{repo}|@vlib|@vmodules']
        print(f'Building Scan: Source {mode}, V {"production" if args.v_prod else "ordinary"}', flush=True)
        proof.run(zbase + ['-femit-bin=' + str(root / 'native'), str(root / 'reference.zig')], 'build-source', timeout=args.timeout)
        proof.run(vbase + ['-o', str(root / 'translated'), str(root / 'main.v')], 'build-v', env=env, timeout=args.timeout)
        rows = corpus()
        (root / 'corpus.txt').write_text('\n'.join(rows) + '\n')
        outputs = []
        for exe in ('native', 'translated'):
            r = proof.run([str(root / exe), str(root / 'corpus.txt')], exe, timeout=args.timeout)
            if r.stderr or len(r.stdout.splitlines()) != len(rows):
                raise AssertionError('invalid returning output')
            outputs.append(r.stdout.splitlines())
        for index, (native, translated) in enumerate(zip(*outputs)):
            if native != translated:
                raise AssertionError(f'{index}/{rows[index]}: Source={native!r}, V={translated!r}')
        digest = hashlib.sha256(b'\n'.join(outputs[0])).hexdigest()
        if EXPECTED_ROWS is not None and len(rows) != EXPECTED_ROWS:
            raise AssertionError('corpus changed')
        if EXPECTED_SHA256 is not None and digest != EXPECTED_SHA256:
            raise AssertionError('returning golden changed')
        print(f'{len(rows)} returning records match; checking strict failures', flush=True)
        states = hashlib.sha256()
        for name, (data, category) in traps().items():
            observed = []
            for exe in ('native', 'translated'):
                path = root / (name + '-' + exe + '.state')
                r = proof.run([str(root / exe), '--trap', str(path), data], name + '-' + exe,
                              timeout=args.timeout, check=False)
                checked_trap(r, name + '/' + exe, category)
                if not path.exists():
                    raise AssertionError('missing observer')
                observed.append(path.read_bytes())
            if observed[0] != observed[1]:
                raise AssertionError(f'{name}: differing states {observed}')
            states.update(name.encode() + b'\0' + observed[0] + b'\n')
        state_digest = states.hexdigest()
        if EXPECTED_STATE_SHA256 is not None and state_digest != EXPECTED_STATE_SHA256:
            raise AssertionError('failure-state golden changed')
        print('Checking required records, typing adaptations and zero-step loops', flush=True)
        constructors(proof, root, zbase, vbase, env, args.timeout)
        loops(proof, root)
        if (tree_hash(source) != PINNED_SOURCE_SHA256 or tree_hash(root / 'src') != PINNED_SOURCE_SHA256
                or stdlib_hash(zig) != PINNED_STDLIB_SHA256):
            raise AssertionError('dependency changed')
        if (implementation_hashes(repo) != implementations
                or hashlib.sha256(Path(__file__).read_bytes()).hexdigest() != runner_hash):
            raise AssertionError('implementation or runner changed')
        for name, expected in fixtures.items():
            if any(hashlib.sha256((p / name).read_bytes()).hexdigest() != expected for p in (root, probe)):
                raise AssertionError('fixture changed')
        summary = dict(returning_records=len(rows), returning_groups=dict(Counter(line.split('|')[0] for line in rows)),
                       output_sha256=digest, paired_traps=len(traps()), state_sha256=state_digest,
                       complete_constructor_pairs=2, required_field_pairs=12, readonly_rejection_pairs=2,
                       wider_carrier_adaptations=4, const_pointer_adaptations=1, paired_zero_step_loops=2,
                       zig_mode=mode, v_prod=args.v_prod)
        (root / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
        print(json.dumps(summary), flush=True)


if __name__ == '__main__':
    main()
