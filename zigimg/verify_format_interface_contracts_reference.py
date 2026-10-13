"""Compare mutable callback records, copied dispatch and exact PNG/TGA option traps."""
import argparse
from collections import Counter
import hashlib
import itertools
import json
import os
from pathlib import Path
import re
import shutil

from verify_jpeg_contracts_reference import implementation_hashes
from verify_tga_decode_reference import stdlib_hash, PINNED_STDLIB_SHA256
from verify_tiff_decode_reference import ProofLog, tree_hash, work_directory, PINNED_SOURCE_SHA256, checked_trap
from verify_simd_reference import ordinary_rejection

FORMATS = 'bmp farbfeld gif iff jpeg pam pbm pcx pgm png ppm qoi ras sgi tga tiff xbm'.split()
EXPECTED_RETURNS = 43200
EXPECTED_TRAPS = 1024
EXPECTED_RETURN_SHA256 = '64ea2c6c5dcf3d0539e780a5acf86c390c3a35cd0c321f61202bec27d59c69dd'
EXPECTED_STATE_SHA256 = 'a5ec291c7761806756669c623761e922bef79b0349f448b0dd7f482f6a8c8c4e'
HISTORICAL_SHA256 = '578f0de4bdaac7c2b67f294de64a2694c069cbb2fde6d2c43ca68494c6ca94eb'


def corpus():
    rows, traps = [], []
    for op, d, r, w, mask, n, capacity, start in itertools.product(
            range(4), range(3), range(3), range(3), range(8), (0, 1, 2, 3, 6), (0, 1, 2, 3, 6), range(2)):
        option = (d * 9 + r * 3 + w + mask + op) % 17
        row = '|'.join(map(str, (op, d, r, w, mask, n, capacity, start, option)))
        rows.append((f'callback-copy-{op}', f'callback-{len(rows)}', row, None))
    for codec, option, profile, capacity, start in itertools.product(
            ('png', 'tga'), range(17), range(4), (0, 1, 7, 64), range(2)):
        if FORMATS[option] == codec:
            continue
        row = '|'.join(map(str, (codec, option, profile, capacity, start)))
        message = f"access of union field '{codec}' while field '{FORMATS[option]}' is active"
        traps.append((codec + '-wrong-option', f'trap-{len(traps)}', row, message))
    return rows, traps


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
    if args.timeout <= 0:
        parser.error('--timeout must be positive')
    source = args.source.resolve() / 'src'
    zig, v = args.zig.resolve(), args.v.resolve()
    if tree_hash(source) != PINNED_SOURCE_SHA256 or stdlib_hash(zig) != PINNED_STDLIB_SHA256:
        parser.error('Source or library differs from pins')
    repo = Path(__file__).resolve().parent.parent
    probe = repo / 'zigimg/reference_probes/format_interface_contracts'
    historical = repo / 'zigimg/reference_probes/format_interface'
    mode = 'ReleaseSafe' if args.v_prod else 'Debug'
    env = dict(os.environ, VEXE=str(v), V_C_ERROR_BUG_REPORT_DISABLED='1')
    with work_directory(args.workdir, 'witty-format-interface-contracts-') as root:
        proof = ProofLog(root)
        shutil.copytree(source, root / 'src')
        fixtures = {}
        for original, name in ((probe / 'main.v', 'main.v'), (probe / 'reference.zig', 'reference.zig'),
                               (historical / 'main.v', 'historical-main.v'),
                               (historical / 'reference.zig', 'historical-reference.zig')):
            shutil.copyfile(original, root / name)
            fixtures[name] = dict(original=str(original.relative_to(repo)), sha256=hashlib.sha256(original.read_bytes()).hexdigest())
        versions = [proof.run([str(exe), 'version'], label, env=env).stdout.decode().strip()
                    for exe, label in ((zig, 'zig-version'), (v, 'v-version'))]
        if versions[0] != '0.15.2' or not re.match(r'^V 0\.5\.2(?: |$)', versions[1]):
            raise AssertionError('unexpected compiler versions')
        implementations = implementation_hashes(repo)
        runner_hash = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
        (root / 'provenance.json').write_text(json.dumps(dict(
            source_sha256=PINNED_SOURCE_SHA256, stdlib_sha256=PINNED_STDLIB_SHA256, versions=versions,
            target=args.target, zig_mode=mode, v_prod=args.v_prod, fixtures=fixtures,
            implementation_sha256=implementations, runner_sha256=runner_hash), indent=2) + '\n')
        zbase = [str(zig), 'build-exe', '-target', args.target, '-lc', '-O', mode,
                 '--global-cache-dir', str(root / 'zig-global')]
        vbase = [str(v), '-enable-globals', *(['-prod'] if args.v_prod else []), '-path', f'{repo}|@vlib|@vmodules']
        print(f'Building interface contracts: Source {mode}, V {"production" if args.v_prod else "ordinary"}', flush=True)
        proof.run(zbase + ['-femit-bin=' + str(root / 'native'), str(root / 'reference.zig')], 'build-source', timeout=args.timeout)
        proof.run(vbase + ['-o', str(root / 'translated'), str(root / 'main.v')], 'build-v', env=env, timeout=args.timeout)
        rows, traps = corpus()
        inputs = {}
        file = root / 'corpus.txt'
        file.write_text('\n'.join(row for group, name, row, message in rows) + '\n')
        inputs[file.name] = hashlib.sha256(file.read_bytes()).hexdigest()
        outputs = []
        for exe in ('native', 'translated'):
            result = proof.run([str(root / exe), '--corpus', str(file)], 'corpus-' + exe, timeout=args.timeout)
            if result.stderr:
                raise AssertionError('unexpected corpus stderr')
            outputs.append(result.stdout.splitlines())
        if any(len(output) != len(rows) for output in outputs):
            raise AssertionError('corpus counts differ')
        returns, states = hashlib.sha256(), hashlib.sha256()
        return_groups, trap_groups, categories = Counter(), Counter(), Counter()
        for (group, name, row, message), native, translated in zip(rows, *outputs):
            if native != translated:
                raise AssertionError(f'{name}: {native!r} != {translated!r}; input {row}')
            returns.update(name.encode() + b'\0' + native + b'\n')
            return_groups[group] += 1
        print(f'{len(rows)} callback records match; checking {len(traps)} exact failures', flush=True)
        for group, name, row, message in traps:
            file = root / (name + '.txt')
            file.write_text(row)
            inputs[file.name] = hashlib.sha256(file.read_bytes()).hexdigest()
            records = []
            for exe in ('native', 'translated'):
                path = root / (name + '-' + exe + '.state')
                result = proof.run([str(root / exe), '--trap', str(path), row], name + '-' + exe,
                                   timeout=args.timeout, check=False)
                checked_trap(result, name + '/' + exe, message)
                messages = [m.group(1) for line in result.stderr.decode().splitlines()
                            if (m := re.fullmatch(r'(?:thread \d+ |V )?panic:\s*(.*)', line.strip()))]
                if messages != [message] or not path.exists():
                    raise AssertionError('exact panic or state missing')
                records.append(path.read_bytes())
            if not records[0] or records[0] != records[1]:
                raise AssertionError(f'{name}: differing state {records}; input {row}')
            states.update(name.encode() + b'\0' + message.encode() + b'\0' + records[0] + b'\n')
            trap_groups[group] += 1
            categories[message] += 1
        (root / 'input_sha256.json').write_text(json.dumps(inputs, indent=2) + '\n')
        consumers = {}

        def pair(label, zbody, vbody, zmarker=None, vmarker=None):
            paths = [root / (label + '.zig'), root / (label + '.v')]
            paths[0].write_text('const F=@import("src/FormatInterface.zig");const codecs=@import("src/formats.zig");pub fn main() void {' + zbody + '}\n')
            paths[1].write_text('module main\nimport zigimg as p\nfn main(){\n' + vbody + '\n}\n')
            for path in paths:
                consumers[path.name] = hashlib.sha256(path.read_bytes()).hexdigest()
            for language, command, marker in (
                    ('Source', zbase + ['-fno-emit-bin', str(paths[0])], zmarker),
                    ('V', vbase + ['-check', '-o', str(root / (label + '-checked')), str(paths[1])], vmarker)):
                result = proof.run(command, label + '-' + language, env=env, timeout=args.timeout, check=False)
                diagnostic = (result.stdout + result.stderr).decode(errors='replace')
                errors = [line for line in diagnostic.splitlines() if re.search(r'\berror:', line)]
                if marker is None:
                    if result.returncode or errors:
                        raise AssertionError(f'{label}/{language}: expected acceptance\n{diagnostic}')
                else:
                    ordinary_rejection(result, label + '/' + language)
                    if not any(marker in line for line in errors):
                        raise AssertionError(f'{label}/{language}: missing {marker!r}\n{diagnostic}')
        zfields = ('formatDetect', 'readImage', 'writeImage')
        vfields = ('format_detect', 'read_image', 'write_image')
        pair('complete-record', 'const x=codecs.png.PNG.formatInterface();const y=F{' + ','.join('.' + f + '=x.' + f for f in zfields) + '};_=y;',
             'x:=p.PNG.format_interface()\ny:=p.FormatInterface{' + ','.join(f + ':x.' + f for f in vfields) + '}\n_=y')
        for zfield, vfield in zip(zfields, vfields):
            pair('missing-' + vfield, 'const x=codecs.png.PNG.formatInterface();const y=F{' + ','.join('.' + f + '=x.' + f for f in zfields if f != zfield) + '};_=y;',
                 'x:=p.PNG.format_interface()\ny:=p.FormatInterface{' + ','.join(f + ':x.' + f for f in vfields if f != vfield) + '}\n_=y',
                 'missing struct field: ' + zfield, f'`zigimg.FormatInterface.{vfield}` must be initialized')
            pair('mutable-' + vfield, f'var x=codecs.png.PNG.formatInterface();x.{zfield}=codecs.tga.TGA.formatInterface().{zfield};_=x.{zfield};',
                 f'mut x:=p.PNG.format_interface()\nx.{vfield}=p.TGA.format_interface().{vfield}\n_=x.{vfield}')
            pair('constant-' + vfield, f'const x=codecs.png.PNG.formatInterface();x.{zfield}=codecs.tga.TGA.formatInterface().{zfield};',
                 f'x:=p.PNG.format_interface()\nx.{vfield}=p.TGA.format_interface().{vfield}',
                 'cannot assign to constant', 'is immutable')
        (root / 'consumer_sha256.json').write_text(json.dumps(consumers, indent=2) + '\n')
        # Unchanged historical writer matrix, now executed in both compiler modes.
        proof.run(zbase + ['-femit-bin=' + str(root / 'historical-native'), str(root / 'historical-reference.zig')], 'historical-build-source', timeout=args.timeout)
        proof.run(vbase + ['-o', str(root / 'historical-translated'), str(root / 'historical-main.v')], 'historical-build-v', env=env, timeout=args.timeout)
        old = [proof.run([str(root / exe)], 'historical-' + exe, timeout=args.timeout).stdout.splitlines()
               for exe in ('historical-native', 'historical-translated')]
        if old[0] != old[1] or len(old[0]) != 49344 or hashlib.sha256(b'\n'.join(old[0])).hexdigest() != HISTORICAL_SHA256:
            raise AssertionError('historical callback matrix changed')
        for name, digest in {**inputs, **consumers}.items():
            if hashlib.sha256((root / name).read_bytes()).hexdigest() != digest:
                raise AssertionError('generated input/consumer changed')
        if (tree_hash(source) != PINNED_SOURCE_SHA256 or tree_hash(root / 'src') != PINNED_SOURCE_SHA256
                or stdlib_hash(zig) != PINNED_STDLIB_SHA256 or implementation_hashes(repo) != implementations
                or hashlib.sha256(Path(__file__).read_bytes()).hexdigest() != runner_hash):
            raise AssertionError('dependency, implementation or runner changed')
        for name, pin in fixtures.items():
            if any(hashlib.sha256(path.read_bytes()).hexdigest() != pin['sha256'] for path in (root / name, repo / pin['original'])):
                raise AssertionError('fixture changed')
        summary = dict(returning_records=len(rows), return_groups=dict(return_groups), return_sha256=returns.hexdigest(),
                       paired_traps=len(traps), failure_groups=dict(trap_groups), panic_categories=dict(categories),
                       state_sha256=states.hexdigest(), complete_constructor_controls=1, required_omission_pairs=3,
                       mutable_field_pairs=3, constant_mutation_rejection_pairs=3, historical_returning_records=49344,
                       historical_sha256=HISTORICAL_SHA256)
        (root / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
        print(json.dumps(summary, indent=2), flush=True)
        if len(rows) != EXPECTED_RETURNS or len(traps) != EXPECTED_TRAPS:
            raise AssertionError('interface counts changed')
        if returns.hexdigest() != EXPECTED_RETURN_SHA256 or states.hexdigest() != EXPECTED_STATE_SHA256:
            raise AssertionError('locked interface golden changed')


if __name__ == '__main__':
    main()
