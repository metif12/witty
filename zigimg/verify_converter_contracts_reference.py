"""Compare production converter guards, SIMD tails and retained image state."""
import argparse
from collections import Counter
import hashlib
import json
import os
from pathlib import Path
import re
import shutil

from verify_jpeg_contracts_reference import implementation_hashes
from verify_tga_decode_reference import stdlib_hash, PINNED_STDLIB_SHA256
from verify_tiff_decode_reference import ProofLog, tree_hash, work_directory, PINNED_SOURCE_SHA256, checked_trap

EXPECTED_ROWS = 2207
EXPECTED_SHA256 = '4d268d80305ae604a4677384bdb4e952b31656e4f72db0a593afad442c5a12c4'
EXPECTED_STATE_SHA256 = '43494aae16df032ee5d9f187007f83cbc3c51ca2659806802b1473175f823292'
FLOAT = 0x2420
DESTINATIONS = (0x408,0x1408)
BAD_BITS = (0xbf800000,0x40000000,0x7f800000,0xff800000)
METHODS = ('--direct','--image','--no-free')


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source',type=Path)
    parser.add_argument('zig',type=Path)
    parser.add_argument('v',type=Path)
    parser.add_argument('--target',default='aarch64-macos.14.0')
    parser.add_argument('--v-prod',action='store_true')
    parser.add_argument('--workdir',type=Path)
    parser.add_argument('--timeout',type=int,default=180)
    args=parser.parse_args()
    if args.timeout<=0:parser.error('--timeout must be positive')
    source=args.source.resolve()/'src';zig=args.zig.resolve();v=args.v.resolve()
    if tree_hash(source)!=PINNED_SOURCE_SHA256 or stdlib_hash(zig)!=PINNED_STDLIB_SHA256:
        parser.error('Source or selected compiler library differs from the pins')
    repo=Path(__file__).resolve().parent.parent
    probe=repo/'zigimg/reference_probes/converter_contracts'
    mode='ReleaseSafe' if args.v_prod else 'Debug'
    env=dict(os.environ,VEXE=str(v),V_C_ERROR_BUG_REPORT_DISABLED='1')
    with work_directory(args.workdir,'witty-converter-contracts-') as root:
        proof=ProofLog(root);shutil.copytree(source,root/'src')
        fixtures={}
        for name in ('main.v','reference.zig'):
            shutil.copyfile(probe/name,root/name)
            fixtures[name]=hashlib.sha256((root/name).read_bytes()).hexdigest()
        versions=[proof.run([str(exe),'version'],label,env=env).stdout.decode().strip()
                  for exe,label in ((zig,'zig-version'),(v,'v-version'))]
        if versions[0]!='0.15.2' or not re.match(r'^V 0\.5\.2(?: |$)',versions[1]):raise AssertionError('unexpected compiler versions')
        implementations=implementation_hashes(repo)
        runner_hash=hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
        historic=['verify_converter_reference.zig','pixel_format_converter_test.v']
        historic_hashes={name:hashlib.sha256((repo/'zigimg'/name).read_bytes()).hexdigest() for name in historic}
        (root/'provenance.json').write_text(json.dumps(dict(source_sha256=PINNED_SOURCE_SHA256,
            stdlib_sha256=PINNED_STDLIB_SHA256,versions=versions,target=args.target,zig_mode=mode,v_prod=args.v_prod,
            fixtures=fixtures,implementation_sha256=implementations,runner_sha256=runner_hash,
            historical_fixture_sha256=historic_hashes),indent=2)+'\n')
        zbase=[str(zig),'build-exe','-target',args.target,'-lc','-O',mode,'--global-cache-dir',str(root/'zig-global')]
        vbase=[str(v),'-enable-globals',*(['-prod'] if args.v_prod else [])]
        print(f'Building converter contracts: Source {mode}, V {"production" if args.v_prod else "ordinary"}',flush=True)
        proof.run(zbase+['-femit-bin='+str(root/'native'),str(root/'reference.zig')],'build-source',timeout=args.timeout)
        proof.run(vbase+['-path',f'{repo}|@vlib|@vmodules','-o',str(root/'translated'),str(root/'main.v')],
                  'build-v',env=env,timeout=args.timeout)
        outputs=[]
        for exe in ('native','translated'):
            result=proof.run([str(root/exe)],'returning-'+exe,timeout=args.timeout)
            if result.stderr:raise AssertionError('unexpected returning stderr')
            outputs.append(result.stdout.splitlines())
        if len(outputs[0])!=len(outputs[1]):raise AssertionError(f'row counts differ: {[len(x) for x in outputs]}')
        for index,(native,translated) in enumerate(zip(*outputs)):
            if native!=translated:raise AssertionError(f'{index}: Source={native!r}, V={translated!r}')
        if len(outputs[0])!=EXPECTED_ROWS:raise AssertionError(f'expected {EXPECTED_ROWS}, got {len(outputs[0])}')
        digest=hashlib.sha256(b'\n'.join(outputs[0])).hexdigest()
        if digest!=EXPECTED_SHA256:raise AssertionError('returning golden changed')
        groups=Counter(row[:1].decode() for row in outputs[0])
        print(f'{EXPECTED_ROWS} returning rows match; checking strict failure state',flush=True)
        states=hashlib.sha256();traps=Counter()
        def trap(group,name,arguments,zcategory,vcategory=None):
            observed=[]
            for exe,category in (('native',zcategory),('translated',vcategory or zcategory)):
                path=root/(name+'-'+exe+'.state')
                result=proof.run([str(root/exe),arguments[0],str(path),*map(str,arguments[1:])],
                                 name+'-'+exe,timeout=args.timeout,check=False)
                checked_trap(result,name+'/'+exe,category)
                if not path.exists():raise AssertionError('missing panic observer')
                observed.append(path.read_bytes())
            if not observed[0] or observed[0]!=observed[1]:raise AssertionError(f'{name}: states differ {observed}')
            states.update(name.encode()+b'\0'+observed[0]+b'\n');traps[group]+=1
        for method in METHODS:
            for dest in DESTINATIONS:
                for count in (0,1,4,5):
                    for offset in (1,2,3):
                        trap('alignment',f'alignment-{method[2:]}-{dest}-{count}-{offset}',
                             [method,FLOAT,dest,count,offset,'borrowed'],'incorrect alignment')
                trap('allocated-empty',f'empty-float-{method[2:]}-{dest}',[method,FLOAT,dest,0,0,'owned'],'incorrect alignment')
            for src in DESTINATIONS:
                trap('allocated-empty',f'empty-byte-{method[2:]}-{src}',[method,src,FLOAT,0,0,'owned'],'incorrect alignment')
            for dest in (0x305,0x3305,0x308,0x408,0x1308,0x1408,0x310,0x410,FLOAT):
                for count in (0,4):
                    trap('union',f'union-{method[2:]}-{dest}-{count}',[method,0x1305,dest,count,0,'owned'],
                         "access of union field 'rgb555' while field 'bgr555' is active",
                         'access of union field rgb555 while field bgr555 is active')
            for bits in (1,2,4,8,16):
                for dest in DESTINATIONS:
                    trap('palette',f'palette-{method[2:]}-{bits}-{dest}',[method,bits,dest,4,0,'owned'],
                         'index out of bounds: index 1, len 1')
        for method in METHODS:
            counts=(4,5,8,9) if method=='--direct' else (5,)
            for count in counts:
                positions=(0,count//4*4-1) if method=='--direct' else (3,)
                for bits in BAD_BITS:
                    for channel in range(4):
                        for pixel in positions:
                            for dest in DESTINATIONS:
                                trap('float-cast',f'float-{method[2:]}-{dest}-{count}-{bits}-{pixel}-{channel}',
                                     [method,FLOAT,dest,count,0,'owned',pixel,channel,bits],
                                     'integer part of floating point value out of bounds')
        state_digest=states.hexdigest()
        if state_digest!=EXPECTED_STATE_SHA256:raise AssertionError('failure-state golden changed')
        print(f'{sum(traps.values())} strict state pairs match; checking historical computed hashes',flush=True)
        # Reuse the existing assertions unchanged on Source, and print the existing
        # V test's computed hashes so production verification does not depend on asserts.
        shutil.copyfile(repo/'zigimg/verify_converter_reference.zig',root/'historical.zig')
        proof.run(zbase+['-femit-bin='+str(root/'historical-native'),str(root/'historical.zig')],
                  'build-historical-source',timeout=args.timeout)
        result=proof.run([str(root/'historical-native')],'historical-source',timeout=args.timeout)
        if result.stdout or not all(marker in result.stderr for marker in (
                b'converter matrix: 18432 cases, e9de0fd7efd93e19',b'converter precision: 6066176 pixels, 9014fb50e8722857')):
            raise AssertionError('historical Source hashes missing')
        copied=root/'zigimg';copied.mkdir()
        for path in (repo/'zigimg').iterdir():
            if path.suffix=='.h' or (path.suffix=='.v' and not path.name.endswith('_test.v')):shutil.copyfile(path,copied/path.name)
        shutil.copyfile(repo/'v.mod',root/'v.mod')
        text=(repo/'zigimg/pixel_format_converter_test.v').read_text()
        start=text.index('fn test_converter_source_alpha_and_simd_tail()')
        end=text.index('fn test_converter_native_precision()')
        text=text[:start]+text[end:text.index('fn test_converter_image_replacement_and_same_format()')]
        text=text.replace('assert cases == 18432',"println('BASELINE|matrix|${cases}|${hash.value:016x}')")
        text=text.replace('assert pixels_checked == 6066176',"println('BASELINE|precision|${pixels_checked}|${hash.value:016x}')")
        generated=copied/'historical_test.v';generated.write_text(text)
        generated_hash=hashlib.sha256(generated.read_bytes()).hexdigest()
        result=proof.run(vbase+['-path',f'{repo}|@vlib|@vmodules','-o',str(root/'historical-v'),str(generated)],'historical-v',env=env,timeout=args.timeout)
        expected=[b'BASELINE|matrix|18432|e9de0fd7efd93e19',b'BASELINE|precision|6066176|9014fb50e8722857']
        if result.stdout.splitlines()!=expected:raise AssertionError('historical V computed hashes differ: '+repr(result.stdout))
        if (tree_hash(source)!=PINNED_SOURCE_SHA256 or tree_hash(root/'src')!=PINNED_SOURCE_SHA256
                or stdlib_hash(zig)!=PINNED_STDLIB_SHA256 or implementation_hashes(repo)!=implementations
                or implementation_hashes(root)!=implementations
                or hashlib.sha256(Path(__file__).read_bytes()).hexdigest()!=runner_hash):
            raise AssertionError('dependency, implementation or runner changed')
        for name,expected_hash in fixtures.items():
            if any(hashlib.sha256((base/name).read_bytes()).hexdigest()!=expected_hash for base in (root,probe)):raise AssertionError('fixture changed')
        for name,expected_hash in historic_hashes.items():
            if hashlib.sha256((repo/'zigimg'/name).read_bytes()).hexdigest()!=expected_hash:raise AssertionError('historical fixture changed')
        if hashlib.sha256(generated.read_bytes()).hexdigest()!=generated_hash:raise AssertionError('generated fixture changed')
        summary=dict(returning_records=EXPECTED_ROWS,groups=dict(groups),output_sha256=digest,
                     paired_traps=sum(traps.values()),failure_groups=dict(traps),state_sha256=state_digest,
                     historical_matrix_slots=18432,matrix_fnv='e9de0fd7efd93e19',precision_pixels=6066176,
                     precision_fnv='9014fb50e8722857',generated_fixture_sha256=generated_hash,zig_mode=mode,v_prod=args.v_prod)
        (root/'summary.json').write_text(json.dumps(summary,indent=2)+'\n');print(json.dumps(summary),flush=True)


if __name__=='__main__':main()
