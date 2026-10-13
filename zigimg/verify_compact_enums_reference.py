"""Compare compact image enum bytes and unchanged Source debug metadata."""
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
from verify_tiff_decode_reference import ProofLog, tree_hash, work_directory, PINNED_SOURCE_SHA256
from verify_matrix_contracts_reference import MATH_HASHES
from verify_simd_reference import ordinary_rejection

ENUMS=(('PostConversionBehavior','c.RgbColorspace.PostConversionBehavior',2),('NetpbmFormat','n.Format',3))
EXPECTED_RETURNS=3584
EXPECTED_SHA256={
 'ordinary':'9009c28f3efdd4db457b134de4c62873ee83534cf7837b3c89a73b3071a49fee',
 'production':'9009c28f3efdd4db457b134de4c62873ee83534cf7837b3c89a73b3071a49fee',
}


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def corpus():
    return [(name,f'{name}-count-{count}-seed-{seed}',f'{kind}|{count}|{seed}')
            for kind,(name,_,_) in enumerate(ENUMS)
            for count,seed in itertools.product((0,1,2,3,7,16,64),range(256))]


def dwarf_enum(text):
    blocks=re.split(r'(?=^0x[0-9a-f]+: DW_TAG_)',text,flags=re.M)
    blocks=[block for block in blocks if block.startswith(tuple('0x'+digit for digit in '0123456789abcdef'))
            and 'DW_TAG_enumeration_type' in block.splitlines()[0]
            and re.search(r'DW_AT_name\s+\("src\.formats\.pam\.TupleType"\)',block)]
    if len(blocks)!=1:raise AssertionError('missing or ambiguous private PAM enum metadata')
    block=blocks[0]
    size=int(re.search(r'DW_AT_byte_size\s+\((0x[0-9a-f]+|[0-9]+)\)',block).group(1),0)
    alignment=int(re.search(r'DW_AT_alignment\s+\(([0-9]+)\)',block).group(1))
    values=[]
    for entry in block.split('DW_TAG_enumerator')[1:]:
        name=re.search(r'DW_AT_name\s+\("([a-z_]+)"\)',entry).group(1)
        value=int(re.search(r'DW_AT_const_value\s+\(([0-9]+)\)',entry).group(1))
        values.append((name,value))
    if values!=[('mono',0),('mono_a',1),('gray',2),('gray_a',3),('rgb',4),('rgb_a',5)]:raise AssertionError('PAM enum names or ordinals changed')
    if size!=1 or alignment!=1:raise AssertionError('PAM enum layout changed')
    return dict(size=size,alignment=alignment,values=values)


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
    source, zig, v = args.source.resolve() / 'src', args.zig.resolve(), args.v.resolve()
    math_dir = zig.parent / 'lib/std/math'
    if (tree_hash(source) != PINNED_SOURCE_SHA256 or stdlib_hash(zig) != PINNED_STDLIB_SHA256
            or any(digest(math_dir / name) != expected for name, expected in MATH_HASHES.items())):
        parser.error('Source or library differs from pins')
    repo = Path(__file__).resolve().parent.parent
    probe = repo / 'zigimg/reference_probes/compact_enums'
    mode = 'production' if args.v_prod else 'ordinary'
    native_mode = 'ReleaseSafe' if args.v_prod else 'Debug'
    with work_directory(args.workdir, 'witty-compact-image-enums-') as root:
        proof = ProofLog(root)
        tmp = root / 'tmp'; tmp.mkdir()
        env = dict(os.environ, VEXE=str(v), V_C_ERROR_BUG_REPORT_DISABLED='1', TMPDIR=str(tmp), VTMP=str(tmp))
        sdk = Path(proof.run(['xcrun', '--show-sdk-path'], 'sdk-path').stdout.decode().strip())
        sdk_math = sdk / 'usr/include/math.h'; sdk_hash = digest(sdk_math)
        shutil.copytree(source, root / 'src')
        fixtures = {}
        for name in ('main.v', 'reference.zig'):
            shutil.copyfile(probe / name, root / name)
            fixtures[name] = digest(probe / name)
        versions = [proof.run([str(exe), 'version'], label, env=env).stdout.decode().strip()
                    for exe, label in ((zig, 'zig-version'), (v, 'v-version'))]
        if versions[0] != '0.15.2' or not re.match(r'^V 0\.5\.2(?: |$)', versions[1]):
            raise AssertionError('unexpected compiler versions')
        implementations, runner_hash = implementation_hashes(repo), digest(Path(__file__))
        (root / 'provenance.json').write_text(json.dumps(dict(source_sha256=PINNED_SOURCE_SHA256,
            stdlib_sha256=PINNED_STDLIB_SHA256, math_sha256=MATH_HASHES, versions=versions,
            target=args.target, zig_mode=native_mode, v_prod=args.v_prod, fixtures=fixtures,
            sdk_math=dict(path=str(sdk_math), sha256=sdk_hash),
            implementation_sha256=implementations, runner_sha256=runner_hash), indent=2) + '\n')
        zbase = [str(zig), 'build-exe', '-target', args.target, '-lc', '-O', native_mode,
                 '--global-cache-dir', str(root / 'zig-global'), '--cache-dir', str(root / 'zig-cache')]
        vbase = [str(v), '-enable-globals', *(['-prod'] if args.v_prod else []), '-path', f'{repo}|@vlib|@vmodules']
        print(f'Building compact enums: Source {native_mode}, V {mode}', flush=True)
        proof.run(zbase + ['-femit-bin=' + str(root / 'native'), str(root / 'reference.zig')], 'build-source', timeout=args.timeout)
        proof.run(vbase + ['-o', str(root / 'translated'), str(root / 'main.v')], 'build-v', env=env, timeout=args.timeout)
        rows = corpus(); file = root / 'corpus.txt'
        file.write_text('\n'.join(row for group, name, row in rows) + '\n')
        inputs = {file.name: digest(file)}; outputs = []
        for exe in ('native', 'translated'):
            result = proof.run([str(root / exe), str(file)], 'corpus-' + exe, timeout=args.timeout, check=False)
            if result.returncode or result.stderr:
                raise AssertionError(f'corpus-{exe} failed; see retained stdout/stderr')
            outputs.append(result.stdout.splitlines())
        if any(len(output) != len(rows) for output in outputs):
            raise AssertionError('corpus counts differ')
        h, groups = hashlib.sha256(), Counter()
        for (group, name, row), native, translated in zip(rows, *outputs):
            if native != translated:
                raise AssertionError(f'{name}: enum byte/view output differs; input {row}')
            h.update(name.encode() + b'\0' + native + b'\n'); groups[group] += 1
        print(f'{len(rows)} compact enums, SHA256 {h.hexdigest()}', flush=True)
        consumers = {}

        def pair(label, zbody, vbody, zmarker=None, vmarker=None):
            paths = [root / (label + '.zig'), root / (label + '.v')]
            paths[0].write_text('const c=@import("src/color.zig");const n=@import("src/formats/netpbm.zig");const pam=@import("src/formats/pam.zig");pub fn main() void {' + zbody + '}\n')
            paths[1].write_text('module main\nimport zigimg as c\nfn main(){\n' + vbody + '\n}\n')
            for path in paths:consumers[path.name] = digest(path)
            for language, command, marker in (
                    ('Source', zbase + ['-fno-emit-bin', str(paths[0])], zmarker),
                    ('V', vbase + ['-check', '-o', str(root / (label + '-checked')), str(paths[1])], vmarker)):
                result = proof.run(command, label + '-' + language, env=env, timeout=args.timeout, check=False)
                diagnostic = (result.stdout + result.stderr).decode(errors='replace')
                errors = [line for line in diagnostic.splitlines() if re.search(r'\berror:', line)]
                if marker is None:
                    if result.returncode or errors:raise AssertionError(f'{label}/{language}: expected acceptance; see retained diagnostics')
                else:
                    ordinary_rejection(result, label + '/' + language)
                    if not any(marker in line for line in errors):raise AssertionError(f'{label}/{language}: missing {marker!r}; see retained diagnostics')
        for name,ztype,count in ENUMS:
            pair(name+'-accepted','var x:'+ztype+'=@enumFromInt(0);x=@enumFromInt(1);_=@intFromEnum(x);',
                 'mut x:=unsafe { c.'+name+'(0) }\nx=unsafe { c.'+name+'(1) }\n_=x')
            pair(name+'-immutable','const x:'+ztype+'=@enumFromInt(0);x=@enumFromInt(1);',
                 'x:=unsafe { c.'+name+'(0) }\nx=unsafe { c.'+name+'(1) }','cannot assign to constant','immutable')
            pair(name+'-wider-carrier','const x:'+ztype+'=@enumFromInt('+str(count)+');_=x;',
                 'x:=unsafe { c.'+name+'('+str(count)+') }\n_=x', 'has no tag with value',
                 'does not represent a value of enum' if args.v_prod else None)
        for name in ('TupleType','Header'):
            pair('private-pam-'+name,'_=pam.'+name+';', '_=c.PamTupleType.mono' if name=='TupleType' else '_=c.PamHeader{width:0,height:0,depth:0,maxval:0,tuple_type:.mono,comments:[]string{}}', "is not marked 'pub'")
        tool_versions={}
        for tool in ('dsymutil','dwarfdump'):
            tool_versions[tool]=proof.run([tool,'--version'],tool+'-version').stdout.decode().strip()
        proof.run(['dsymutil','-o',str(root/'native.dSYM'),str(root/'native')],'source-dsym',timeout=args.timeout)
        metadata_text=proof.run(['dwarfdump','--name=TupleType','--regex','--show-children',str(root/'native.dSYM')],'source-private-enum-metadata',timeout=args.timeout).stdout.decode()
        metadata=dwarf_enum(metadata_text)
        (root/'pam-enum-metadata.json').write_text(json.dumps(metadata,indent=2)+'\n')
        result=proof.run([str(root/'translated'),'pam'],'v-pam-enum',timeout=args.timeout,check=False)
        expected=[f'{metadata["size"]},{metadata["alignment"]}|{name},{value}|{value:02x}'.encode() for name,value in metadata['values']]
        if result.returncode or result.stderr or result.stdout.splitlines()!=expected:raise AssertionError('V PAM enum differs from native metadata')
        (root/'tool_versions.json').write_text(json.dumps(tool_versions,indent=2)+'\n')
        for tool,version in tool_versions.items():
            if proof.run([tool,'--version'],tool+'-version-after').stdout.decode().strip()!=version:
                raise AssertionError('metadata tool version changed')
        (root / 'input_sha256.json').write_text(json.dumps(inputs, indent=2) + '\n')
        (root / 'consumer_sha256.json').write_text(json.dumps(consumers, indent=2) + '\n')
        for name, expected in {**inputs, **consumers}.items():
            if digest(root / name) != expected:raise AssertionError('input or consumer changed')
        if (tree_hash(source) != PINNED_SOURCE_SHA256 or tree_hash(root / 'src') != PINNED_SOURCE_SHA256
                or stdlib_hash(zig) != PINNED_STDLIB_SHA256
                or any(digest(math_dir / name) != expected for name, expected in MATH_HASHES.items())
                or digest(sdk_math) != sdk_hash or implementation_hashes(repo) != implementations
                or digest(Path(__file__)) != runner_hash):raise AssertionError('dependency, implementation or runner changed')
        for name, expected in fixtures.items():
            if any(digest(path) != expected for path in (root / name, probe / name)):raise AssertionError('fixture changed')
        summary = dict(returning_records=len(rows),return_groups=dict(groups),sha256=h.hexdigest(),
                       accepted_enum_pairs=2,immutable_rejection_pairs=2,
                       wider_enum_literal_adaptations=0 if args.v_prod else 2,
                       wider_enum_literal_rejection_pairs=2 if args.v_prod else 0,
                       private_source_rejection_controls=2,pam_metadata_records=6,pam_metadata=metadata)
        (root / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n'); print(json.dumps(summary, indent=2), flush=True)
        if len(rows) != EXPECTED_RETURNS or h.hexdigest() != EXPECTED_SHA256[mode]:raise AssertionError('locked compact enum golden changed')


if __name__ == '__main__':main()
