"""Compare public JPEG Frame records, block algorithms and strict failures."""
import argparse
import hashlib
import itertools
import json
import os
from pathlib import Path
import re
import shutil

from verify_jpeg_contracts_reference import stdlib_hash, PINNED_STDLIB_SHA256, implementation_hashes, frame_header, baseline
from verify_tiff_decode_reference import ProofLog, tree_hash, work_directory, PINNED_SOURCE_SHA256
from verify_png_header_reference import checked_trap
from verify_simd_reference import ordinary_rejection

EXPECTED_ROWS = 10697
EXPECTED_SHA256 = '02bea61a685969480894de6596bfd0f16c132107369c1bc4ed2f895d4e2509f0'
EXPECTED_STATE_SHA256 = '73fbe0b116d37d3721a82529cfdf615cd69ecc2308879180a9a953e1d97791ea'


def constructors(proof, root, zbase, vbase, env, timeout):
    zprefix = ('const std=@import("std");const F=@import("src/formats/jpeg/Frame.zig");'
               'const Q=@import("src/formats/jpeg/quantization.zig").Table;'
               'const H=@import("src/formats/jpeg/huffman.zig").Table;'
               'pub fn main() void {')
    vprefix = 'module main\nimport zigimg as p\nfn main(){\n'

    def pair(label, zbody, vbody, zmarker=None, vmarker=None, run=False):
        zpath, vpath = root / (label+'.zig'), root / (label+'.v')
        zpath.write_text(zprefix+zbody+'}\n')
        vpath.write_text(vprefix+vbody+'\n}\n')
        for language, command, marker, exe in (
                ('Source',zbase+['-femit-bin='+str(root/(label+'-source')),str(zpath)],zmarker,root/(label+'-source')),
                ('V',vbase+['-o',str(root/(label+'-v')),str(vpath)],vmarker,root/(label+'-v'))):
            result=proof.run(command,label+'-'+language,env=env,timeout=timeout,check=False)
            diagnostic=(result.stdout+result.stderr).decode(errors='replace')
            errors=[line for line in diagnostic.splitlines() if re.search(r'\berror:',line)]
            if marker is None:
                if result.returncode or errors:raise AssertionError(f'{label}/{language}: expected acceptance\n{diagnostic}')
                if run:
                    control=proof.run([str(exe)],label+'-run-'+language,timeout=timeout)
                    if control.stdout or control.stderr:raise AssertionError('unexpected constructor output')
            else:
                ordinary_rejection(result,label+'/'+language)
                if not any(marker in line for line in errors):
                    raise AssertionError(f'{label}/{language}: missing actual error {marker!r}\n{diagnostic}')

    for label,zkind,vkind,zvalue,vfield,vvalue,size in (
            ('Block','[64]i32','JpegBlock','@splat(0)','values','[64]int{}',64),
            ('Components','[3][64]i32','JpegBlockComponents','.{@splat(0),@splat(0),@splat(0)}','blocks','[3]p.JpegBlock{init:p.JpegBlock{values:[64]int{}}}',3),
            ('QuantizationTables','[4]?Q','JpegQuantizationTables','@splat(null)','values','unsafe{[4]?p.JpegQuantizationTable{init:none}}',4),
            ('HuffmanTables','[4]?H','JpegHuffmanTables','@splat(null)','values','[4]?p.JpegHuffmanTable{init:none}',4)):
        pair('complete-'+label,f'const x:{zkind}={zvalue};_=x;',f'x:=p.{vkind}{{{vfield}:{vvalue}}}\n_=x')
        pair('missing-'+label,f'const x:{zkind}=.{{}};_=x;',f'x:=p.{vkind}{{}}\n_=x',
             f'expected {size} array elements',f'zigimg.{vkind}.{vfield}')
        zmut = 'x[0][0]=1;' if label=='Components' else ('x[0]=null;' if label.endswith('Tables') else 'x[0]=1;')
        vmut = 'x.blocks[0].values[0]=1' if label=='Components' else ('x.values[0]=none' if label.endswith('Tables') else 'x.values[0]=1')
        pair('readonly-'+label,f'const x:{zkind}={zvalue};'+zmut,
             f'x:=p.{vkind}{{{vfield}:{vvalue}}}\n'+vmut,'cannot assign to constant','immutable')

    zsetup='var q:[4]?Q=@splat(null);var dc:[4]?H=@splat(null);var ac:[4]?H=@splat(null);'
    vsetup=('mut q:=p.JpegQuantizationTables{values:unsafe{[4]?p.JpegQuantizationTable{init:none}}}\n'
            'mut dc:=p.JpegHuffmanTables{values:[4]?p.JpegHuffmanTable{init:none}}\n'
            'mut ac:=p.JpegHuffmanTables{values:[4]?p.JpegHuffmanTable{init:none}}\n')
    fields={
        'frame_header':('.{.allocator=std.heap.page_allocator,.sample_precision=8,.width=0,.height=0,.components=&.{}}',
                        'p.JpegFrameHeader{sample_precision:8,width:0,height:0,components:[]p.JpegComponent{}}'),
        'quantization_tables':('&q','&q'), 'dc_huffman_tables':('&dc','&dc'), 'ac_huffman_tables':('&ac','&ac'),
        'block_storage':('&.{}','[]p.JpegBlockComponents{}')}

    def frame(missing=None):
        zfields=','.join('.'+key+'='+values[0] for key,values in fields.items() if key!=missing)
        vfields=','.join(key+':'+values[1] for key,values in fields.items() if key!=missing)
        return (zsetup+'const x:F=.{.allocator=std.heap.page_allocator,.frame_type=.sof0,'+zfields+'};',
                vsetup+'x:=p.JpegFrame{frame_type:0xffc0,'+vfields+'}\n')

    zbody,vbody=frame()
    defaults=('block_width','block_height','block_width_actual','block_height_actual',
              'horizontal_sampling_factor_max','vertical_sampling_factor_max')
    pair('complete-Frame',zbody+'if('+ ' or '.join('x.'+name+'!=0' for name in defaults)+')@panic("defaults");',
         vbody+'if '+' || '.join('x.'+name+'!=0' for name in defaults)+'{panic("defaults")}',run=True)
    for field in fields:
        zbody,vbody=frame(field)
        pair('missing-Frame-'+field,zbody+'_=x;',vbody+'_=x',
             'missing struct field: '+field,'zigimg.JpegFrame.'+field)
    zbody,vbody=frame()
    pair('readonly-Frame',zbody+'x.block_width=1;',vbody+'x.block_width=1','cannot assign to constant','immutable')
    # Source const record bindings still expose mutable pointer pointees.
    pair('const-Frame-borrow',zbody+'x.quantization_tables[0]=null;',
         vbody+'x.quantization_tables.values[0]=none',None,'immutable')
    # The enum carrier remains wider than Source's exhaustive Markers type.
    pair('invalid-marker-carrier',zbody.replace('.frame_type=.sof0','.frame_type=@enumFromInt(65535)')+'_=x;',
         vbody.replace('frame_type:0xffc0','frame_type:65535')+'_=x',"has no tag with value '65535'")


def zero_step_loops(proof, root):
    for op in ('C','D','I'):
        path=root/('zero-step-'+op+'.txt')
        path.write_text(row(op,components=3,x=0)+'\n')
        for exe in ('native','translated'):
            label='zero-step-'+op+'-'+exe
            try:
                proof.run([str(root/exe),str(path)],label,timeout=0.5,check=False)
            except AssertionError:
                if not proof.commands[-1].get('timed_out'):raise
                prefix=f'{len(proof.commands)-1:03d}-{label}'
                if any((root/f'{prefix}.{ext}').read_bytes() for ext in ('stdout','stderr')):
                    raise AssertionError('unexpected output before zero-step timeout')
            else:raise AssertionError('zero-step loop returned')


def row(op, *, components=1, width=8, height=8, blocks=2, x=1, y=1,
        seed=0, bw=1, bh=1, actual=1, ah=1, pixel_count=64, extra=()):
    return '|'.join(map(str, (op, '', components, width, height, blocks, x, y, seed,
                              bw, bh, actual, ah, pixel_count, *extra)))


def corpus():
    rows = []
    dims = (0, 1, 7, 8, 9, 15, 16, 17, 31, 32, 33, 63)
    for marker, width, height, h, v in itertools.product((0xffc0, 0xffc2, 0xffc1), dims, dims, range(1, 5), range(1, 5)):
        rows.append(f'F|{frame_header(width=width,height=height,sampling=h<<4|v).hex()}|{marker}')
    for width, height in ((65528, 0), (0, 65528)):
        for sampling in (0x11, 0x22, 0x34, 0x43, 0x44):
            rows.append(f'F|{frame_header(width=width,height=height,sampling=sampling).hex()}|65472')
    for count in (1, 3):
        data = frame_header(count=count)
        rows.extend(f'F|{data[:n].hex()}|65472' for n in range(len(data)+1))
    for x, y, seed, alias in itertools.product((1, 2, 3, 4, 5, 7, 8, 16), (1, 2, 3, 4, 5, 7, 8, 16), range(8), (0, 1)):
        for v, h in ((0,0),(y-1,x-1)):
            rows.append(row('B',x=x,y=y,seed=seed,pixel_count=v,extra=(h,alias)))
    for x,y,seed in itertools.product(range(1,5),range(1,5),range(8)):
        rows.append(row('C',components=3,width=17,height=17,blocks=16,x=x,y=y,seed=seed,bw=3,bh=3,actual=4,ah=4))
        rows.append(row('A',components=3,width=17,height=17,blocks=16,x=x,y=y,seed=seed,bw=3,bh=3,actual=4,ah=4,pixel_count=289))
    for count,x,y,seed in itertools.product((1,3),range(1,5),range(1,5), (0,1,8,64)):
        for quant in (0,1,7,255):
            rows.append(row('D',components=count,width=17,height=17,blocks=16,x=x,y=y,seed=seed,bw=3,bh=3,actual=4,ah=4,pixel_count=quant))
        rows.append(row('I',components=count,width=17,height=17,blocks=16,x=x,y=y,seed=seed,bw=3,bh=3,actual=4,ah=4,pixel_count=1))
    for width,height,seed in itertools.product((0,1,7,8,9,13,17),(0,1,7,8,9,13,17),range(8)):
        bw,bh=(width+7)//8,(height+7)//8
        for op in ('R','G'):
            rows.append(row(op,width=width,height=height,blocks=(bw+1)*(bh+1),seed=seed,bw=bw,bh=bh,actual=bw+1,ah=bh+1,pixel_count=width*height))
    for value in (0,1,2147483647,2147483648,4294967295):
        rows.append(row('N',bw=value,bh=value,actual=value,ah=value))
    for (width,height),(dc,magnitude) in itertools.product(((0,0),(1,1),(8,8),(17,9)),((0,0),(1,1),(2047,11))):
        rows.append('J|'+baseline(width=width,height=height,dc=dc,magnitude=magnitude).hex())
    return rows


def traps():
    result = {}
    def add(name,data,category): result[name]=(data,category)
    for width,height in ((65529,0),(65535,0),(0,65529),(0,65535)):
        add(f'header-overflow-{width}-{height}',f'F|{frame_header(width=width,height=height).hex()}|65472','integer overflow')
    add('marker','F||65535','invalid enum value')
    for name,x,y,v,h,category in (
            ('x-zero',0,1,0,0,'division by zero'),('y-zero',1,0,0,0,'division by zero'),
            ('x-cast',2147483648,1,0,0,'integer does not fit in destination type'),
            ('offset-overflow',1,1,0,2305843009213693952,'integer overflow'),
            ('offset-cast',1,1,0,268435456,'integer does not fit in destination type'),
            ('mask-overflow',3,1,0,1073741823,'integer overflow'),
            ('mask-bounds',1,1,0,1,'index out of bounds: index 8, len 8'),
            ('row-overflow',1,1,2305843009213693952,0,'integer overflow'),
            ('row-add-overflow',1,1,2305843009213693951,0,'integer overflow'),
            ('row-mul-overflow',1,8,2305843009213693952,0,'integer overflow'),
            ('row-bounds',1,1,1,0,'index out of bounds: index 128, len 64'),
            ('row-short',1,8,8,0,'index out of bounds: index 72, len 64')):
        add(name,row('B',x=x,y=y,pixel_count=v,extra=(h,0)),category)
    for ci in range(3):
        for value,category in ((-1,'integer does not fit in destination type'),(256,'integer does not fit in destination type')):
            add(f'rgb-{ci}-{value}',row('R',pixel_count=64,extra=(ci,1,value)),category)
    add('rgb-short',row('R',pixel_count=1),'index out of bounds: index 1, len 1')
    add('rgb-short-and-negative',row('R',pixel_count=1,extra=(0,1,-1)),'index out of bounds: index 1, len 1')
    add('gray-overflow',row('G',extra=(1,2147483647)),'integer overflow')
    add('gray-short',row('G',pixel_count=1),'index out of bounds: index 1, len 1')
    add('gray-short-and-overflow',row('G',pixel_count=1,extra=(1,2147483647)),'index out of bounds: index 1, len 1')
    add('rgb-block-short',row('R',blocks=0),'index out of bounds: index 0, len 0')
    add('rgb-block-and-pixels-short',row('R',blocks=0,pixel_count=0),'index out of bounds: index 0, len 0')
    add('gray-block-and-pixels-short',row('G',blocks=0,pixel_count=0),'index out of bounds: index 0, len 0')
    add('gray-union',row('U',width=0,height=0,bw=0,bh=0),'access of union field \'grayscale8\' while field \'invalid\' is active')
    add('rgb-union',row('U',components=3,width=0,height=0,bw=0,bh=0),'access of union field \'rgb24\' while field \'invalid\' is active')
    add('component-count',row('U',components=2,width=0,height=0,bw=0,bh=0),'reached unreachable code')
    add('dequant-overflow',row('D',seed=2147483647,pixel_count=255),'integer overflow')
    return result


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source',type=Path);parser.add_argument('zig',type=Path);parser.add_argument('v',type=Path)
    parser.add_argument('--target',default='aarch64-macos.14.0');parser.add_argument('--v-prod',action='store_true')
    parser.add_argument('--workdir',type=Path);parser.add_argument('--timeout',type=int,default=180)
    args=parser.parse_args()
    if args.timeout<=0:parser.error('--timeout must be positive')
    source=args.source.resolve()/'src';zig=args.zig.resolve();v=args.v.resolve()
    if tree_hash(source)!=PINNED_SOURCE_SHA256 or stdlib_hash(zig)!=PINNED_STDLIB_SHA256:parser.error('dependency differs from pins')
    repo=Path(__file__).resolve().parent.parent;probe=repo/'zigimg/reference_probes/jpeg_frame'
    mode='ReleaseSafe' if args.v_prod else 'Debug';env=dict(os.environ,VEXE=str(v),V_C_ERROR_BUG_REPORT_DISABLED='1')
    with work_directory(args.workdir,'witty-jpeg-frame-') as root:
        proof=ProofLog(root);shutil.copytree(source,root/'src')
        fixture_hashes={}
        for name in ('main.v','reference.zig'):
            shutil.copyfile(probe/name,root/name);fixture_hashes[name]=hashlib.sha256((root/name).read_bytes()).hexdigest()
        versions=[proof.run([str(exe),'version'],label,env=env).stdout.decode().strip() for exe,label in ((zig,'zig-version'),(v,'v-version'))]
        if versions[0]!='0.15.2' or not re.match(r'^V 0\.5\.2(?: |$)',versions[1]):raise AssertionError('unexpected compiler versions')
        implementations=implementation_hashes(repo);runner_hash=hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
        (root/'provenance.json').write_text(json.dumps(dict(source_sha256=PINNED_SOURCE_SHA256,stdlib_sha256=PINNED_STDLIB_SHA256,versions=versions,target=args.target,zig_mode=mode,v_prod=args.v_prod,fixtures=fixture_hashes,implementation_sha256=implementations,runner_sha256=runner_hash),indent=2)+'\n')
        zbase=[str(zig),'build-exe','-target',args.target,'-lc','-O',mode,'--global-cache-dir',str(root/'zig-global')]
        vbase=[str(v),'-enable-globals',*(['-prod'] if args.v_prod else []),'-path',f'{repo}|@vlib|@vmodules']
        print(f'Building JPEG Frame: {mode}, V {"production" if args.v_prod else "ordinary"}',flush=True)
        proof.run(zbase+['-femit-bin='+str(root/'native'),str(root/'reference.zig')],'build-source',timeout=args.timeout)
        proof.run(vbase+['-o',str(root/'translated'),str(root/'main.v')],'build-v',env=env,timeout=args.timeout)
        rows=corpus();(root/'corpus.txt').write_text('\n'.join(rows)+'\n')
        outputs=[]
        for exe in ('native','translated'):
            r=proof.run([str(root/exe),str(root/'corpus.txt')],exe,timeout=args.timeout)
            if r.stderr or len(r.stdout.splitlines())!=len(rows):raise AssertionError('invalid returning output')
            outputs.append(r.stdout.splitlines())
        for index,(native,translated) in enumerate(zip(*outputs)):
            if native!=translated:raise AssertionError(f'{index}/{rows[index]}: Source={native!r}, V={translated!r}')
        digest=hashlib.sha256(b'\n'.join(outputs[0])).hexdigest()
        if EXPECTED_ROWS is not None and len(rows)!=EXPECTED_ROWS:raise AssertionError('corpus changed')
        if EXPECTED_SHA256 is not None and digest!=EXPECTED_SHA256:raise AssertionError('returning golden changed')
        print(f'{len(rows)} returning records match; checking strict failures',flush=True)
        states=hashlib.sha256()
        for name,(row_data,category) in traps().items():
            observed=[]
            for exe in ('native','translated'):
                path=root/f'{name}-{exe}.state'
                r=proof.run([str(root/exe),'--trap',str(path),row_data],name+'-'+exe,timeout=args.timeout,check=False)
                checked_trap(r,exe+'/'+name,category)
                if not path.exists():raise AssertionError('missing observer')
                observed.append(path.read_bytes())
            if observed[0]!=observed[1]:raise AssertionError(f'{name}: state differs {observed}')
            states.update(name.encode()+b'\0'+observed[0]+b'\n')
        state_digest=states.hexdigest()
        if EXPECTED_STATE_SHA256 is not None and state_digest!=EXPECTED_STATE_SHA256:raise AssertionError('failure-state golden changed')
        print('Checking constructor controls and inherited zero-step loops',flush=True)
        constructors(proof,root,zbase,vbase,env,args.timeout)
        zero_step_loops(proof,root)
        if tree_hash(source)!=PINNED_SOURCE_SHA256 or tree_hash(root/'src')!=PINNED_SOURCE_SHA256 or stdlib_hash(zig)!=PINNED_STDLIB_SHA256:raise AssertionError('dependency changed')
        if implementation_hashes(repo)!=implementations or hashlib.sha256(Path(__file__).read_bytes()).hexdigest()!=runner_hash:raise AssertionError('implementation or runner changed')
        for name,digest_expected in fixture_hashes.items():
            if any(hashlib.sha256((p/name).read_bytes()).hexdigest()!=digest_expected for p in (root,probe)):raise AssertionError('fixture changed')
        summary=dict(returning_records=len(rows),output_sha256=digest,paired_traps=len(traps()),state_sha256=state_digest,
                     complete_constructor_pairs=5,required_field_pairs=9,readonly_rejection_pairs=5,
                     const_pointer_adaptations=1,enum_carrier_adaptations=1,paired_zero_step_loops=3,zig_mode=mode,v_prod=args.v_prod)
        (root/'summary.json').write_text(json.dumps(summary,indent=2)+'\n');print(json.dumps(summary),flush=True)


if __name__=='__main__':main()
