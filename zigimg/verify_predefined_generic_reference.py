"""Compare predefined built-in/custom colors, value copies and immutable constants."""
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

TYPES = ('Rgb24','Rgba32','Bgr24','Bgra32','Rgb48','Rgba64','Colorf32',
         'Rgb332','Rgb555','Bgr555','Rgb565','Encoded','Swizzled','Snapshot','Marked','RgbAlias','FloatAlias')
EXPECTED_RETURNS = 4352
EXPECTED_SHA256 = '6978b2a5f30c126670686d36fb0ebac319823591d12fb008e34bc0a6d3d0c11c'

def digest(path): return hashlib.sha256(path.read_bytes()).hexdigest()

def corpus():
    return [(name,f'{name}-color-{color}-replacement-{replacement}-operation-{operation}',
             '|'.join(map(str,(kind,color,replacement,operation))))
            for kind,name in enumerate(TYPES)
            for color,replacement,operation in itertools.product(range(8),range(8),range(4))]

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
    repo=Path(__file__).resolve().parent.parent;probe=repo/'zigimg/reference_probes/predefined_generic'
    mode='ReleaseSafe' if args.v_prod else 'Debug'
    with work_directory(args.workdir,'witty-predefined-generic-') as root:
        proof=ProofLog(root);tmp=root/'tmp';tmp.mkdir()
        env=dict(os.environ,VEXE=str(v),V_C_ERROR_BUG_REPORT_DISABLED='1',TMPDIR=str(tmp),VTMP=str(tmp))
        sdk=Path(proof.run(['xcrun','--show-sdk-path'],'sdk-path').stdout.decode().strip())
        sdk_math=sdk/'usr/include/math.h';sdk_hash=digest(sdk_math)
        shutil.copytree(source,root/'src');fixtures={}
        for name in ('main.v','custom.v','reference.zig','custom.zig'):
            shutil.copyfile(probe/name,root/name);fixtures[name]=digest(probe/name)
        versions=[proof.run([str(exe),'version'],label,env=env).stdout.decode().strip()
                  for exe,label in ((zig,'zig-version'),(v,'v-version'))]
        if versions[0]!='0.15.2' or not re.match(r'^V 0\.5\.2(?: |$)',versions[1]):raise AssertionError('compiler version changed')
        implementations,runner_hash=implementation_hashes(repo),digest(Path(__file__))
        (root/'provenance.json').write_text(json.dumps(dict(source_sha256=PINNED_SOURCE_SHA256,
            stdlib_sha256=PINNED_STDLIB_SHA256,math_sha256=MATH_HASHES,versions=versions,
            sdk_math=dict(path=str(sdk_math),sha256=sdk_hash),target=args.target,zig_mode=mode,v_prod=args.v_prod,
            fixtures=fixtures,implementation_sha256=implementations,runner_sha256=runner_hash),indent=2)+'\n')
        zbase=[str(zig),'build-exe','-target',args.target,'-lc','-O',mode,
               '--global-cache-dir',str(root/'zig-global'),'--cache-dir',str(root/'zig-cache')]
        vbase=[str(v),'-enable-globals',*(['-prod'] if args.v_prod else []),'-path',f'{repo}|@vlib|@vmodules']
        print(f'Building predefined factories: Source {mode}, V production={args.v_prod}',flush=True)
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
            if a!=b:raise AssertionError(f'{name}: predefined/copy output differs; input {row}')
            h.update(name.encode()+b'\0'+a+b'\n')
        print(f'{len(rows)} returning records, SHA256 {h.hexdigest()}',flush=True)
        vcustom=(root/'custom.v').read_text()
        zprefix='const c=@import("src/color.zig");const pc=@import("src/predefined_colors.zig");const custom=@import("custom.zig");const RgbAlias=c.Rgb24;const FloatAlias=c.Colorf32;'
        def pair(label,zbody,vbody,zmarker=None,vmarker=None,zextra='',vextra=''):
            zp,vp=root/(label+'.zig'),root/(label+'.v')
            zp.write_text(zprefix+zextra+'pub fn main() void {'+zbody+'}\n')
            vp.write_text(vcustom+'\n'+vextra+'\nfn main(){\n'+vbody+'\n}\n')
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
            return zp,vp
        for name in TYPES:
            ztype=('custom.' if name in TYPES[11:15] else '' if name in TYPES[15:] else 'c.')+name
            vtype=('p.' if name in TYPES[:11] else '')+name
            zfield='channel_bits[0]' if name=='Snapshot' else 'bits' if name=='Encoded' else 'tag' if name=='Marked' else 'r'
            vfield='raw' if name in TYPES[7:11] else zfield
            pair(name+'-copy','var x=pc.Colors('+ztype+').Red;x=pc.Colors('+ztype+').Green;_=&x;',
                 'mut x:=p.predefined_colors['+vtype+']().red\nx=p.predefined_colors['+vtype+']().green\n_=x')
            pair(name+'-readonly','pc.Colors('+ztype+').Red.'+zfield+'=0;',
                 'mut x:=p.predefined_colors['+vtype+']()\nx.red.'+vfield+'=0','cannot assign to constant','immutable')
        pair('missing-factory','_=pc.Colors(Missing).Red;','_=p.predefined_colors[Missing]()',
             "has no member named 'from'",'unknown function',
             zextra='const Missing=struct{tag:u8};',vextra='pub struct Missing{tag u8}\n')
        pair('wrong-factory','_=pc.Colors(Wrong).Red;','_=p.predefined_colors[Wrong]()',
             'expected type','cannot use',
             zextra='const Wrong=struct{tag:u8,pub const from=struct{pub fn color(v:c.Colorf32) u8{_=v;return 1;}};};',
             vextra='pub struct Wrong{tag u8}\npub fn Wrong.from_color(v p.Colorf32) u8{_=v\nreturn 1}\n')
        zp,vp=pair('runtime-factory','_=pc.Colors(Runtime).Red;',
             'a:=p.predefined_colors[Runtime]()\nb:=p.predefined_colors[Runtime]()\nprintln("${calls}|${a.red.tag}|${a.yellow.tag}|${b.red.tag}|${b.yellow.tag}")',
             'unable to evaluate comptime expression',None,
             zextra='var calls:u32=0;const Runtime=struct{tag:u32,pub const from=struct{pub fn color(v:c.Colorf32) Runtime{_=v;calls+=1;return .{.tag=calls};}};};',
             vextra='__global(calls=u32(0))\npub struct Runtime{tag u32}\npub fn Runtime.from_color(v p.Colorf32) Runtime{_=v\ncalls++\nreturn Runtime{tag:calls}}\n')
        proof.run(vbase+['-o',str(root/'runtime-factory'),str(vp)],'build-runtime-factory-v',env=env,timeout=args.timeout)
        result=proof.run([str(root/'runtime-factory')],'runtime-factory-v',timeout=args.timeout)
        if result.stderr or result.stdout!=b'16|1|8|9|16\n':raise AssertionError('runtime factory adaptation changed')
        (root/'input_sha256.json').write_text(json.dumps(inputs,indent=2)+'\n')
        (root/'consumer_sha256.json').write_text(json.dumps(consumers,indent=2)+'\n')
        for name,expected in {**inputs,**consumers}.items():
            if digest(root/name)!=expected:raise AssertionError('input/consumer changed')
        if (tree_hash(source)!=PINNED_SOURCE_SHA256 or tree_hash(root/'src')!=PINNED_SOURCE_SHA256
                or stdlib_hash(zig)!=PINNED_STDLIB_SHA256 or implementation_hashes(repo)!=implementations
                or digest(Path(__file__))!=runner_hash or digest(sdk_math)!=sdk_hash
                or any(digest(math_dir/name)!=expected for name,expected in MATH_HASHES.items())):
            raise AssertionError('dependency, implementation or runner changed')
        for name,expected in fixtures.items():
            if any(digest(path)!=expected for path in (root/name,probe/name)):raise AssertionError('fixture changed')
        summary=dict(returning_records=len(rows),groups=dict(Counter(group for group,_,_ in rows)),sha256=h.hexdigest(),
            accepted_copy_pairs=17,readonly_constant_pairs=17,unsupported_factory_pairs=2,
            runtime_factory_adaptations=1,runtime_factory_stdout=result.stdout.decode(),zig_mode=mode,v_prod=args.v_prod)
        (root/'summary.json').write_text(json.dumps(summary,indent=2)+'\n');print(json.dumps(summary,indent=2),flush=True)
        if len(rows)!=EXPECTED_RETURNS or h.hexdigest()!=EXPECTED_SHA256:raise AssertionError('locked golden changed')

if __name__=='__main__':main()
