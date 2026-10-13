"""Compare public generic grayscale factories with unchanged Source."""
import argparse
from collections import Counter
import hashlib
import itertools
import json
import os
from pathlib import Path
import random
import re
import shutil

from verify_jpeg_contracts_reference import implementation_hashes
from verify_tga_decode_reference import stdlib_hash, PINNED_STDLIB_SHA256
from verify_tiff_decode_reference import ProofLog, tree_hash, work_directory, PINNED_SOURCE_SHA256
from verify_matrix_contracts_reference import MATH_HASHES
from verify_simd_reference import ordinary_rejection

TYPES = (('u8',8),('u16',16),('u32',32),('u64',64),('usize',64),
         ('f32',32),('f64',64),('AliasU32',32),('AliasF32',32))
SIGNED = (('i8','i8'),('i16','i16'),('i32','int'),('i64','i64'),('isize','isize'))
FLOAT_BOUNDARIES = (0, 0x80000000, 1, 0x80000001, 0x007fffff, 0x00800000,
                    0x3f7fffff, 0x3f800000, 0x3f800001, 0xbf800000, 0x7f7fffff,
                    0xff7fffff, 0x7f800000, 0xff800000, 0x7fc00000, 0x7fc01234,
                    0xffc05678, 0x7f800001, 0xff800001, 0x40000000)
EXPECTED_RETURNS = 25740
EXPECTED_SHA256 = {
 'ordinary':'65e24bc45804982251cc4a6fea67f6feb4f3501ad47c75aa33bcd51018c7aefa',
 'production':'65e24bc45804982251cc4a6fea67f6feb4f3501ad47c75aa33bcd51018c7aefa',
}
EXPECTED_SIGNED_SHA256 = '19d4071100765fcc1c8fd06207ca2f2ed8e328dc2543f322c0552a8aebe8e490'
EXPECTED_DEFAULT_DIFFERENCE_SHA256 = '21c2fe5cc65150c9b49d96cf387ddd1348d0e7ae27a81cc7368c4f2165ee27b0'


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def corpus():
    rows=[];rng=random.Random(0xd7b7ab0b)
    doubles=(0,0x8000000000000000,1,0x8000000000000001,0x000fffffffffffff,
             0x0010000000000000,0x3fefffffffffffff,0x3ff0000000000000,0x3ff0000000000001,
             0xbff0000000000000,0x7fefffffffffffff,0xffefffffffffffff,
             0x7ff0000000000000,0xfff0000000000000,0x7ff8000000000000,
             0x7ff8000000001234,0xfff8000000005678,0x7ff0000000000001,0xfff0000000000001)
    for kind,(name,width) in enumerate(TYPES):
        limit=(1<<width)-1
        boundaries=(doubles if name=='f64' else FLOAT_BOUNDARIES) if name in ('f32','f64','AliasF32') else tuple(sorted({0,1,limit,limit-1,limit//2,limit//2+1,*[value for value in (127,128,255,256,32767,32768,65535,65536,0xffffffff,0x100000000) if value<=limit]}))
        for alpha in (0,1):
            for form,operation,field in itertools.product(range(2) if alpha else (0,),range(4),range(2) if alpha else (0,)):
                group=f'{name}-alpha-{alpha}-form-{form}-operation-{operation}'
                for index,value in enumerate(boundaries):
                    values=(value,boundaries[(index+3)%len(boundaries)],boundaries[(index+7)%len(boundaries)])
                    rows.append((group,f'{group}-field-{field}-boundary-{index}','|'.join(map(str,(kind,alpha,form,operation,field,*values)))))
                for index in range(128):
                    values=[rng.getrandbits(width) for _ in range(3)]
                    rows.append((group,f'{group}-field-{field}-random-{index}','|'.join(map(str,(kind,alpha,form,operation,field,*values)))))
    return rows

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
    probe = repo / 'zigimg/reference_probes/grayscale_generic'
    mode = 'production' if args.v_prod else 'ordinary'
    native_mode = 'ReleaseSafe' if args.v_prod else 'Debug'
    with work_directory(args.workdir, 'witty-grayscale-generic-') as root:
        proof = ProofLog(root)
        tmp = root / 'tmp'; tmp.mkdir()
        env = dict(os.environ, VEXE=str(v), V_C_ERROR_BUG_REPORT_DISABLED='1', TMPDIR=str(tmp), VTMP=str(tmp))
        sdk = Path(proof.run(['xcrun', '--show-sdk-path'], 'sdk-path').stdout.decode().strip())
        sdk_math = sdk / 'usr/include/math.h'; sdk_hash = digest(sdk_math)
        shutil.copytree(source, root / 'src')
        fixtures = {}
        for name in ('main.v', 'reference.zig', 'signed_main.v', 'signed_reference.zig'):
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
        vbase = [str(v), *(['-prod'] if args.v_prod else []), '-path', f'{repo}|@vlib|@vmodules']
        print(f'Building generic grayscale records: Source {native_mode}, V {mode}', flush=True)
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
                raise AssertionError(f'{name}: record/conversion output differs; input {row}')
            h.update(name.encode() + b'\0' + native + b'\n'); groups[group] += 1
        print(f'{len(rows)} generic grayscale records, SHA256 {h.hexdigest()}', flush=True)
        consumers = {}

        def pair(label, zbody, vbody, zmarker=None, vmarker=None):
            paths = [root / (label + '.zig'), root / (label + '.v')]
            paths[0].write_text('const c=@import("src/color.zig");const AliasU32=u32;const AliasF32=f32;pub fn main() void {' + zbody + '}\n')
            paths[1].write_text('module main\nimport zigimg as c\ntype AliasU32=u32\ntype AliasF32=f32\nfn main(){\n' + vbody + '\n}\n')
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
        for name,width in TYPES:
            for alpha in (False,True):
                factory='GrayscaleAlpha' if alpha else 'Grayscale'
                label=factory+'-'+name
                zinit='c.'+factory+'('+name+'){.value=0}'
                vinit='c.GrayscaleAlpha.init('+name+'(0))' if alpha else 'c.Grayscale['+name+']{value:0}'
                fields=('value','alpha') if alpha else ('value',)
                pair(label+'-accepted','var x='+zinit+';'+''.join('x.'+f+'=1;' for f in fields)+'_=x.value;',
                     'mut x:='+vinit+'\n'+'\n'.join('x.'+f+'='+name+'(1)' for f in fields)+'\n_=x.value')
                pair(label+'-omission-adaptation','const x=c.'+factory+'('+name+'){};_=x;',
                     'x:=c.'+factory+'['+name+']{}\n_=x','missing struct field: value')
                for field in fields:
                    pair(label+'-immutable-'+field,'const x='+zinit+';x.'+field+'=1;',
                         'x:='+vinit+'\nx.'+field+'='+name+'(1)','cannot assign to constant','immutable')
        for zn,vn in SIGNED:
            for alpha in (False,True):
                factory='GrayscaleAlpha' if alpha else 'Grayscale'
                zinit='c.'+factory+'('+zn+'){.value=-1}'
                vinit='c.GrayscaleAlpha.init('+vn+'(-1))' if alpha else 'c.Grayscale['+vn+']{value:-1}'
                pair(factory+'-'+zn+'-construction','const x='+zinit+';_=x.value;', 'x:='+vinit+'\n_=x.value')
                pair(factory+'-'+zn+'-conversion-rejection','const x='+zinit+';_=x.toColorf32();',
                     'x:='+vinit+'\n_=c.'+factory+'.to_colorf32(x)','only works with unsigned integer types','ScaleValue requires')
        for zn,vn,zvalue,vvalue in (('bool','bool','false','false'),('[]const u8','string','"x"','"x"')):
            pair('unsupported-'+vn,'const x=c.Grayscale('+zn+'){.value='+zvalue+'};_=x.toColorf32();',
                 'x:=c.Grayscale['+vn+']{value:'+vvalue+'}\n_=c.Grayscale.to_colorf32(x)', 'only works with numeric types','ScaleValue requires')
        for name,typ,alpha in (('Grayscale8','u8',False),('Grayscale16','u16',False),('Grayscalef32','f32',False),('Grayscale8Alpha','u8',True),('Grayscale16Alpha','u16',True),('Grayscalef32Alpha','f32',True)):
            factory='GrayscaleAlpha' if alpha else 'Grayscale'
            zinit='c.'+factory+'('+typ+'){.value=0}'
            vinit='c.GrayscaleAlpha.init('+typ+'(0))' if alpha else 'c.Grayscale['+typ+']{value:0}'
            pair(name+'-identity-adaptation','const x:c.'+name+'='+zinit+';_=x.value;',
                 'x:='+vinit+'\nmut y:=c.'+name+'{value:0}\ny=x\n_=y.value',None,'cannot assign')
        proof.run(zbase+['-femit-bin='+str(root/'signed-native'),str(root/'signed_reference.zig')],'build-signed-source',timeout=args.timeout)
        proof.run(vbase+['-o',str(root/'signed-translated'),str(root/'signed_main.v')],'build-signed-v',env=env,timeout=args.timeout)
        signed=[]
        for exe in ('signed-native','signed-translated'):
            result=proof.run([str(root/exe)],exe,timeout=args.timeout,check=False)
            if result.returncode or result.stderr:raise AssertionError(exe+' failed; see retained diagnostics')
            signed.append(result.stdout.splitlines())
        if signed[0]!=signed[1] or len(signed[0])!=5:raise AssertionError('signed constructor records differ')
        signed_hash=hashlib.sha256(b'\n'.join(signed[0])).hexdigest()
        omissions=[]
        for exe in ('native','translated'):
            result=proof.run([str(root/exe),'omitted'],'omitted-alpha-'+exe,timeout=args.timeout,check=False)
            if result.returncode or result.stderr:raise AssertionError('omitted-alpha-'+exe+' failed')
            omissions.append(result.stdout.splitlines())
        if any(len(records)!=9 for records in omissions):raise AssertionError('omitted alpha counts differ')
        differences=[];omitted_hash=hashlib.sha256()
        for (name,_),native,translated in zip(TYPES,*omissions):
            if native==translated or translated!=b'0,0,0,0,0,0,' or native.split(b',')[-2]!=b'1065353216':raise AssertionError('omitted alpha adaptation changed')
            differences.append(dict(type=name,source=native.decode(),v=translated.decode()))
            omitted_hash.update(name.encode()+b'\0'+native+b'\0'+translated+b'\n')
        (root/'omitted-alpha-differences.json').write_text(json.dumps(differences,indent=2)+'\n')
        print('Signed constructor SHA256 '+signed_hash+'; omitted-alpha difference SHA256 '+omitted_hash.hexdigest(),flush=True)
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
        summary = dict(returning_records=len(rows), return_groups=dict(groups), sha256=h.hexdigest(),
                       accepted_record_pairs=18, generic_omission_adaptations=18, immutable_rejection_pairs=27,
                       signed_constructor_pairs=10, conversion_rejection_pairs=12, builtin_identity_adaptations=6,
                       static_conversion_call_adapter=True, alpha_default_constructor_adapter=True,
                       signed_constructor_records=5, signed_sha256=signed_hash,
                       default_alpha_literal_adaptations=9, default_alpha_difference_sha256=omitted_hash.hexdigest())
        (root / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n'); print(json.dumps(summary, indent=2), flush=True)
        if (len(rows) != EXPECTED_RETURNS or h.hexdigest() != EXPECTED_SHA256[mode]
                or signed_hash != EXPECTED_SIGNED_SHA256
                or omitted_hash.hexdigest() != EXPECTED_DEFAULT_DIFFERENCE_SHA256):
            raise AssertionError('locked generic grayscale golden changed')


if __name__ == '__main__':main()
