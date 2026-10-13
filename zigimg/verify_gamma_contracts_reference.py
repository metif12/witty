"""Compare gamma parameters, captured factories and transfer method results."""
import argparse
from collections import Counter
import hashlib
import itertools
import json
import os
from pathlib import Path
import re
import shutil
import random
import struct

from verify_jpeg_contracts_reference import implementation_hashes
from verify_tga_decode_reference import stdlib_hash, PINNED_STDLIB_SHA256
from verify_tiff_decode_reference import ProofLog, tree_hash, work_directory, PINNED_SOURCE_SHA256
from verify_matrix_contracts_reference import MATH_HASHES
from verify_simd_reference import ordinary_rejection

FIELDS=('alpha','beta','delta','gamma','transition_point','display_gamma')
EXPECTED_RETURNS=24192
EXPECTED_PARAMETER_SETS=28
EXPECTED_SHA256='75aa55611500c1763b7ae71e7150805173730abdca1db0b85e3fc87cb15c3c86'

def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def bits(value):return struct.unpack('<I',struct.pack('<f',value))[0]
def parameter_cases():
    cases=[('default',(0,0,0,1,0,1)),('srgb',(1.055,0.0031308,12.92,12/5,0.04045,2.2)),
           ('rec709',(1.099,0.004,4.5,20/9,0.018,2.2)),('bt2020',(1.0993,0.004,4.5,20/9,0.0181,2.2)),
           ('prophoto',(1,0.001953125,16,9/5,0.031248,1.8)),('identity',(1,0,1,1,0,1))]
    raw=[(name,tuple(bits(v) for v in values)) for name,values in cases]
    base=tuple(bits(v) for v in (1.5,0.25,3,2,0.75,2.2))
    for field,values in ((0,(0,0x80000000,bits(-1),0x7f800000,0x7fc01234)),
                         (1,(0x7fc05678,)),(2,(0,0x80000000,0x7f800000,0x7fc05678)),
                         (3,(0,0x80000000,bits(-2),bits(0.5),0x7f800000,0x7fc01234)),
                         (4,(0x7fc05678,)),(5,(0,0x80000000,bits(0.5),0x7f800000,0x7fc01234))):
        for value in values:
            p=list(base);p[field]=value;raw.append((f'{FIELDS[field]}-{value}',tuple(p)))
    return raw

def corpus():
    values=[bits(v) for v in (-2,-1,-0.5,-0.0,0,0.0031308,0.004,0.018,0.031248,0.04045,0.25,0.5,0.75,1,2,16)]
    values += [1,0x80000001,0x007fffff,0x00800000,0x3f7fffff,0x3f800001,0x7f7fffff,0x7f800000,0xff800000,0x7fc01234,0x7f800001]
    rng=random.Random(0xd7b7ab0b);values += [rng.getrandbits(32) for _ in range(9)]
    rows=[]
    for kind,(name,_) in enumerate(parameter_cases()):
        for operation,field,index in itertools.product(range(4),range(6),range(len(values))):
            replacement=values[(index+7)%len(values)]
            group=f'{name}-operation-{operation}'
            rows.append((group,f'{group}-field-{field}-input-{index}','|'.join(map(str,(kind,operation,field,replacement,values[index])))))
    return rows

def generators():
    rows=parameter_cases()
    z='pub const raw_params=[_][6]u32{\n'+''.join('    .{'+','.join(map(str,values))+'},\n' for _,values in rows)+'};\n'
    v='module main\nconst raw_params=[\n'+''.join('    [u32('+str(values[0])+'),'+','.join(map(str,values[1:]))+'],\n' for _,values in rows)+']\n'
    return {'cases.zig':z,'cases.v':v}

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source',type=Path);parser.add_argument('zig',type=Path);parser.add_argument('v',type=Path)
    parser.add_argument('--target',default='aarch64-macos.14.0');parser.add_argument('--v-prod',action='store_true')
    parser.add_argument('--workdir',type=Path);parser.add_argument('--timeout',type=int,default=300)
    args=parser.parse_args()
    if args.timeout<=0:parser.error('--timeout must be positive')
    source,zig,v=args.source.resolve()/'src',args.zig.resolve(),args.v.resolve()
    math_dir=zig.parent/'lib/std/math'
    if (tree_hash(source)!=PINNED_SOURCE_SHA256 or stdlib_hash(zig)!=PINNED_STDLIB_SHA256
            or any(digest(math_dir/name)!=expected for name,expected in MATH_HASHES.items())):
        parser.error('Source or library differs from pins')
    repo=Path(__file__).resolve().parent.parent;probe=repo/'zigimg/reference_probes/gamma_contracts'
    mode='ReleaseSafe' if args.v_prod else 'Debug'
    with work_directory(args.workdir,'witty-gamma-contracts-') as root:
        proof=ProofLog(root);tmp=root/'tmp';tmp.mkdir()
        env=dict(os.environ,VEXE=str(v),V_C_ERROR_BUG_REPORT_DISABLED='1',TMPDIR=str(tmp),VTMP=str(tmp))
        sdk=Path(proof.run(['xcrun','--show-sdk-path'],'sdk-path').stdout.decode().strip())
        sdk_math=sdk/'usr/include/math.h';sdk_hash=digest(sdk_math)
        shutil.copytree(source,root/'src');fixtures={}
        for name in ('main.v','reference.zig'):
            shutil.copyfile(probe/name,root/name);fixtures[name]=digest(probe/name)
        generated={}
        for name,contents in generators().items():
            (root/name).write_text(contents);generated[name]=digest(root/name)
        versions=[proof.run([str(exe),'version'],label,env=env).stdout.decode().strip()
                  for exe,label in ((zig,'zig-version'),(v,'v-version'))]
        if versions[0]!='0.15.2' or not re.match(r'^V 0\.5\.2(?: |$)',versions[1]):raise AssertionError('compiler version changed')
        implementations,runner_hash=implementation_hashes(repo),digest(Path(__file__))
        (root/'provenance.json').write_text(json.dumps(dict(source_sha256=PINNED_SOURCE_SHA256,
            stdlib_sha256=PINNED_STDLIB_SHA256,math_sha256=MATH_HASHES,versions=versions,
            sdk_math=dict(path=str(sdk_math),sha256=sdk_hash),target=args.target,zig_mode=mode,v_prod=args.v_prod,
            fixtures=fixtures,generators=generated,implementation_sha256=implementations,runner_sha256=runner_hash),indent=2)+'\n')
        zbase=[str(zig),'build-exe','-target',args.target,'-lc','-O',mode,
               '--global-cache-dir',str(root/'zig-global'),'--cache-dir',str(root/'zig-cache')]
        vbase=[str(v),'-enable-globals',*(['-prod'] if args.v_prod else []),'-path',f'{repo}|@vlib|@vmodules']
        print(f'Building gamma contracts: Source {mode}, V production={args.v_prod}',flush=True)
        proof.run(zbase+['-femit-bin='+str(root/'native'),str(root/'reference.zig')],'build-source',timeout=args.timeout)
        proof.run(vbase+['-o',str(root/'translated'),str(root)],'build-v',env=env,timeout=args.timeout)
        rows=corpus();file=root/'corpus.txt';file.write_text('\n'.join(row for _,_,row in rows)+'\n')
        inputs={file.name:digest(file)};consumers={};outputs=[]
        for exe in ('native','translated'):
            result=proof.run([str(root/exe),str(file)],'corpus-'+exe,timeout=args.timeout,check=False)
            if result.returncode or result.stderr:raise AssertionError('corpus failed; see retained diagnostics')
            outputs.append(result.stdout.splitlines())
        if any(len(output)!=len(rows) for output in outputs):raise AssertionError('corpus counts differ')
        h=hashlib.sha256()
        for (_,name,row),a,b in zip(rows,*outputs):
            if a!=b:raise AssertionError(f'{name}: gamma record/method output differs; input {row}')
            h.update(name.encode()+b'\0'+a+b'\n')
        print(f'{len(rows)} returning records, SHA256 {h.hexdigest()}',flush=True)
        zprefix='const std=@import("std");const c=@import("src/color.zig");'
        def pair(label,zbody,vbody,zmarker=None,vmarker=None):
            zp,vp=root/(label+'.zig'),root/(label+'.v')
            zp.write_text(zprefix+'pub fn main() void {'+zbody+'}\n')
            vp.write_text('module main\nimport zigimg as p\nfn main(){\n'+vbody+'\n}\n')
            for path in (zp,vp):consumers[path.name]=digest(path)
            for language,command,marker in (
                    ('Source',zbase+['-fno-emit-bin',str(zp)],zmarker),
                    ('V',vbase+['-check','-o',str(root/(label+'-checked')),str(vp)],vmarker)):
                result=proof.run(command,label+'-'+language,env=env,timeout=args.timeout,check=False)
                errors=[line for line in (result.stdout+result.stderr).decode(errors='replace').splitlines() if re.search(r'\berror:',line)]
                if marker is None:
                    if result.returncode or errors:raise AssertionError(label+'/'+language+': expected acceptance; see diagnostics')
                else:
                    ordinary_rejection(result,label+'/'+language)
                    if not any(marker in line for line in errors):raise AssertionError(label+'/'+language+': expected diagnostic missing')
        pair('default-parameters','const x=c.GammaFunctionsParameters{};_=x;','x:=p.GammaFunctionsParameters{}\n_=x')
        for field in FIELDS:
            pair('mutable-'+field,'var x=c.GammaFunctionsParameters{};x.'+field+'=2;_=x.'+field+';',
                 'mut x:=p.GammaFunctionsParameters{}\nx.'+field+'=2\n_=x')
            pair('immutable-'+field,'const x=c.GammaFunctionsParameters{};x.'+field+'=2;',
                 'x:=p.GammaFunctionsParameters{}\nx.'+field+'=2','cannot assign to constant','immutable')
        for name,zarg,varg in (('NonLinearGammaTransferFunctions','c.GammaFunctionsParameters{}','parameters:p.GammaFunctionsParameters{}'),('CurveGammaTransferFunctions','0','gamma:0')):
            pair(name+'-complete','_=c.'+name+'('+zarg+');','_=p.'+name+'{'+varg+'}')
            pair(name+'-missing','_=c.'+name+'();','_=p.'+name+'{}','expected 1 argument',name+'.'+('parameters' if name.startswith('Non') else 'gamma'))
        pair('runtime-parameters','var x=c.GammaFunctionsParameters{};std.mem.doNotOptimizeAway(&x);_=c.NonLinearGammaTransferFunctions(x);',
             'mut x:=p.GammaFunctionsParameters{}\nx.gamma=2\n_=p.NonLinearGammaTransferFunctions{parameters:x}','unable to resolve comptime value')
        pair('runtime-curve','var x:f32=2;std.mem.doNotOptimizeAway(&x);_=c.CurveGammaTransferFunctions(x);',
             'mut x:=f32(2)\nx=3\n_=p.CurveGammaTransferFunctions{gamma:x}','unable to resolve comptime value')
        for name,field,value in (('NonLinearGammaTransferFunctions','parameters','p.GammaFunctionsParameters{}'),('CurveGammaTransferFunctions','gamma','f32(2)')):
            vp=root/(name+'-immutable-capture.v')
            vp.write_text('module main\nimport zigimg as p\nfn main(){mut x:=p.'+name+'{'+field+':'+value+'}\nx.'+field+'='+value+'}\n')
            consumers[vp.name]=digest(vp)
            result=proof.run(vbase+['-check',str(vp)],name+'-immutable-capture-V',env=env,timeout=args.timeout,check=False)
            ordinary_rejection(result,name+'-immutable-capture-V')
            if not any('immutable' in line for line in (result.stdout+result.stderr).decode().splitlines() if re.search(r'\berror:',line)):raise AssertionError('capture must be immutable')
        (root/'input_sha256.json').write_text(json.dumps(dict(inputs,**generated),indent=2)+'\n')
        (root/'consumer_sha256.json').write_text(json.dumps(consumers,indent=2)+'\n')
        for name,expected in {**inputs,**generated,**consumers}.items():
            if digest(root/name)!=expected:raise AssertionError('input/consumer changed')
        if (tree_hash(source)!=PINNED_SOURCE_SHA256 or tree_hash(root/'src')!=PINNED_SOURCE_SHA256
                or stdlib_hash(zig)!=PINNED_STDLIB_SHA256 or implementation_hashes(repo)!=implementations
                or digest(Path(__file__))!=runner_hash or digest(sdk_math)!=sdk_hash
                or any(digest(math_dir/name)!=expected for name,expected in MATH_HASHES.items())):
            raise AssertionError('dependency, implementation or runner changed')
        for name,expected in fixtures.items():
            if any(digest(path)!=expected for path in (root/name,probe/name)):raise AssertionError('fixture changed')
        summary=dict(returning_records=len(rows),groups=dict(Counter(group for group,_,_ in rows)),sha256=h.hexdigest(),parameter_sets=len(parameter_cases()),
            default_parameter_pairs=1,mutable_parameter_pairs=6,immutable_parameter_pairs=6,
            accepted_factory_pairs=2,required_argument_pairs=2,runtime_argument_adaptations=2,v_immutable_capture_controls=2,
            arithmetic_nan_payloads_canonicalized=True,zig_mode=mode,v_prod=args.v_prod)
        (root/'summary.json').write_text(json.dumps(summary,indent=2)+'\n');print(json.dumps(summary,indent=2),flush=True)
        if len(rows)!=EXPECTED_RETURNS or len(parameter_cases())!=EXPECTED_PARAMETER_SETS or h.hexdigest()!=EXPECTED_SHA256:raise AssertionError('locked golden changed')

if __name__=='__main__':main()
