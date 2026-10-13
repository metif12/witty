"""Compare unchanged QOI records, factories, compression and parsed-header failures."""
import argparse
from collections import Counter
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import struct

from verify_jpeg_contracts_reference import implementation_hashes
from verify_tga_decode_reference import stdlib_hash, PINNED_STDLIB_SHA256
from verify_tiff_decode_reference import (
    ProofLog, tree_hash, work_directory, PINNED_SOURCE_SHA256, checked_trap,
)

EXPECTED_MAIN_SHA256 = '8f25ed18baa760e49e30af9e067589232b0b0c4e9a85ed20c0a91351015ace36'
EXPECTED_RETURN_SHA256 = 'defd0517da4d75e5e2c29738aef5727c6a952721b330828c13f865d909dccf0e'
EXPECTED_STATE_SHA256 = '22a915f9007f737de8becde6d090e21e29d5ecc3541a5f145b303c0754e642e2'
EXPECTED_MAIN = 64807
EXPECTED_RETURNS = 133753
EXPECTED_TRAPS = 677

def header(width, height, fmt=4, space=0):
    return b'qoif' + struct.pack('>II', width, height) + bytes((fmt, space))

def corpus():
    cases=[]
    def add(name,data,entries=(0,1),start=0):
        for entry in entries:cases.append((name+'-'+str(entry),f'{entry}|{start}|{(b"x"*start+data).hex()}'))
    for fmt in (3,4):
        for seed in (0,1):
            prefix=b'' if seed==0 else bytes((255,255,128,1,7))
            for first in range(128,192):
                for second in range(256):
                    add(f'luma-{fmt}-{seed}-{first}-{second}',header(1+seed,1,fmt,seed)+prefix+bytes((first,second)))
            for byte in range(64,128):
                add(f'diff-{fmt}-{seed}-{byte}',header(1+seed,1,fmt,seed)+prefix+bytes((byte,)))
        for index in range(64):add(f'index-{fmt}-{index}',header(1,1,fmt)+bytes((index,)))
        for byte in range(192,254):
            for count in (0,1,2,61,62,63):add(f'run-{fmt}-{byte}-{count}',header(count,1,fmt)+bytes((byte,)))
        packets=[b'',bytes((254,10,20,30)),bytes((255,10,20,30,7)),bytes((254,10,20,30,127,162,151,255,100,150,200,50,193,9,0))]
        for pi,packet in enumerate(packets):
            data=header(8 if pi==3 else 1,1,fmt)+packet
            for cut in range(len(data)+1):add(f'prefix-{fmt}-{pi}-{cut}',data[:cut],start=3)
            add(f'trailing-{fmt}-{pi}',data+b'\0'*7+b'\1garbage')
        for width,height in ((0,0),(0,0xffffffff),(0xffffffff,0)):
            add(f'zero-{fmt}-{width}-{height}',header(width,height,fmt,1)+b'ignored')
    for pos in range(4):
        data=bytearray(header(0,0));data[pos]^=255
        add(f'wrong-magic-{pos}',bytes(data))
    for mi,magic in enumerate((b'qoif',b'qoif!',b'nope',b'qOif')):
        for cut in range(len(magic)+1):add(f'detect-{mi}-{cut}',magic[:cut],entries=(2,),start=3)
    # Incomplete headers reject before either enum validation.
    for cut in range(14):add(f'short-invalid-{cut}',header(0,0,255,255)[:cut])
    return cases

def controls():
    cases=[]
    for fmt in range(256):cases.append(('format',f'format-{fmt}',header(0,0,fmt,0),0,0))
    for space in range(256):cases.append(('colorspace',f'colorspace-{space}',header(0,0,3,space),0,0))
    for fmt in (0,1,2,5,127,128,254,255):
        for space in (2,3,127,128,254,255):
            for width,height in ((0,0),(1,1),(0xffffffff,0xffffffff)):
                cases.append(('both-enums',f'both-{fmt}-{space}-{width}-{height}',header(width,height,fmt,space),0,0))
    for fmt,space in ((0,0),(255,0),(3,2),(4,255),(255,255)):
        for entry in (0,1):
            for start in (0,3):cases.append(('entry-cursor',f'entry-{fmt}-{space}-{entry}-{start}',b'x'*start+header(0,0,fmt,space),entry,start))
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
    if args.timeout <= 0:
        parser.error('--timeout must be positive')
    source = args.source.resolve() / 'src'
    zig = args.zig.resolve()
    v = args.v.resolve()
    if tree_hash(source) != PINNED_SOURCE_SHA256 or stdlib_hash(zig) != PINNED_STDLIB_SHA256:
        parser.error('Source or selected library differs from pins')
    repo = Path(__file__).resolve().parent.parent
    probe = repo / 'zigimg/reference_probes/qoi_contracts'
    mode = 'ReleaseSafe' if args.v_prod else 'Debug'
    env = dict(os.environ, VEXE=str(v), V_C_ERROR_BUG_REPORT_DISABLED='1')
    with work_directory(args.workdir, 'witty-qoi-contracts-') as root:
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
            fixtures=fixtures, implementation_sha256=implementations, runner_sha256=runner_hash,
        ), indent=2) + '\n')
        zbase = [str(zig), 'build-exe', '-target', args.target, '-lc', '-O', mode,
                 '--global-cache-dir', str(root / 'zig-global')]
        vbase = [str(v), '-enable-globals', *(['-prod'] if args.v_prod else []),
                 '-path', f'{repo}|@vlib|@vmodules']
        print(f'Building QOI contracts: Source {mode}, V {"production" if args.v_prod else "ordinary"}', flush=True)
        proof.run(zbase + ['-femit-bin=' + str(root / 'native'), str(root / 'reference.zig')],
                  'build-source', timeout=args.timeout)
        proof.run(vbase + ['-o', str(root / 'translated'), str(root / 'main.v')],
                  'build-v', env=env, timeout=args.timeout)
        outputs = []
        for exe in ('native', 'translated'):
            result = proof.run([str(root / exe)], 'records-' + exe, timeout=args.timeout)
            if result.stderr:
                raise AssertionError('unexpected records stderr')
            outputs.append(result.stdout)
        if outputs[0] != outputs[1] or len(outputs[0].splitlines()) != EXPECTED_MAIN:
            raise AssertionError('header/write records differ')
        main_digest = hashlib.sha256(b'\n'.join(outputs[0].splitlines())).hexdigest()
        if main_digest != EXPECTED_MAIN_SHA256:
            raise AssertionError('main golden changed: ' + main_digest)
        returns = hashlib.sha256()
        states = hashlib.sha256()
        return_groups = Counter()
        trap_groups = Counter()
        inputs = {}
        rows=corpus()
        file=root/'corpus.txt'
        file.write_text('\n'.join(row for name,row in rows)+'\n')
        inputs[file.name]=hashlib.sha256(file.read_bytes()).hexdigest()
        outputs=[]
        for exe in ('native','translated'):
            result=proof.run([str(root/exe),'--corpus',str(file)],'corpus-'+exe,timeout=args.timeout)
            if result.stderr:raise AssertionError('unexpected corpus stderr')
            outputs.append(result.stdout.splitlines())
        if any(len(output)!=len(rows) for output in outputs):raise AssertionError('corpus count differs')
        for (name,line),native,translated in zip(rows,*outputs):
            if native!=translated:raise AssertionError(f'{name}: {native!r} != {translated!r}')
            returns.update(name.encode()+b'\0'+native+b'\n')
        return_groups['decoder-corpus']=len(rows)
        def compare(group,name,arguments,message=None):
            records=[]
            for exe in ('native','translated'):
                path=root/(name+'-'+exe+'.state')
                command=[str(root/exe)]+[str(path) if arg is None else str(arg) for arg in arguments]
                records.append((proof.run(command,name+'-'+exe,timeout=args.timeout,check=False),path))
            if message is not None:
                for (result,path),exe in zip(records,('native','translated')):
                    checked_trap(result,name+'/'+exe,message)
                    messages=[m.group(1) for line in result.stderr.decode().splitlines()
                              if (m:=re.fullmatch(r'(?:thread \d+ |V )?panic:\s*(.*)',line.strip()))]
                    if messages != [message] or not path.exists():raise AssertionError('exact panic or state missing')
                snapshots=[path.read_bytes() for result,path in records]
                if not snapshots[0] or snapshots[0]!=snapshots[1]:raise AssertionError(f'{name}: state differs {snapshots}')
                states.update(name.encode()+b'\0'+message.encode()+b'\0'+snapshots[0]+b'\n')
                trap_groups[group]+=1
            else:
                native,translated=[record[0] for record in records]
                if (native.returncode or translated.returncode or native.stderr or translated.stderr
                        or native.stdout!=translated.stdout or len(native.stdout.splitlines())!=1):
                    raise AssertionError(f'{name}: returns differ {native.stdout!r} {translated.stdout!r}')
                returns.update(name.encode()+b'\0'+native.stdout);return_groups[group]+=1
        for group,name,data,entry,start in controls():
            file=root/(name+'.qoi');file.write_bytes(data);inputs[file.name]=hashlib.sha256(data).hexdigest()
            message='invalid enum value' if data[start+12] not in (3,4) or data[start+13] not in (0,1) else None
            compare(group,name,['--read',None,entry,start,file],message)
        for kind in ('int','color','rgb48','pointer','bool'):
            compare('factory','factory-'+kind,['--from',None,kind],'reached unreachable code')

        from verify_simd_reference import ordinary_rejection
        consumer_hashes={}
        def pair(label,zbody,vbody,zmarker=None,vmarker=None):
            paths=[root/(label+'.zig'),root/(label+'.v')]
            paths[0].write_text('const p=@import("src/formats/qoi.zig");pub fn main() void {'+zbody+'}\n')
            paths[1].write_text('module main\nimport zigimg as p\nfn main(){\n'+vbody+'\n}\n')
            for path in paths:consumer_hashes[path.name]=hashlib.sha256(path.read_bytes()).hexdigest()
            for language,command,marker in (
                ('Source',zbase+['-fno-emit-bin',str(paths[0])],zmarker),
                ('V',vbase+['-check','-o',str(root/(label+'-checked')),str(paths[1])],vmarker)):
                result=proof.run(command,label+'-'+language,env=env,timeout=args.timeout,check=False)
                diagnostic=(result.stdout+result.stderr).decode(errors='replace')
                errors=[line for line in diagnostic.splitlines() if re.search(r'\berror:',line)]
                if marker is None:
                    if result.returncode or errors:raise AssertionError(f'{label}/{language}: expected acceptance\n{diagnostic}')
                else:
                    ordinary_rejection(result,label+'/'+language)
                    if not any(marker in line for line in errors):raise AssertionError(f'{label}/{language}: diagnostic missing {marker!r}\n{diagnostic}')
        for kind,vkind,fields in (
            ('QoiColor','QoiColor',{'r':'1','g':'2','b':'3'}),
            ('Header','QoiHeader',{'width':'1','height':'2','format':'.rgb','colorspace':'.srgb'})):
            for missing in (None,*fields):
                zfields=','.join('.'+key+'='+value for key,value in fields.items() if key!=missing)
                vfields=','.join(key+':'+value for key,value in fields.items() if key!=missing)
                pair(kind+'-'+str(missing),'const x:p.'+kind+'=.{'+zfields+'};_=x;',
                     'x:=p.'+vkind+'{'+vfields+'}\n_=x',
                     'missing struct field: '+missing if missing else None,
                     vkind+'.'+missing if missing else None)
        pair('default-codec','const x:p.QOI=.{};_=x;','x:=p.QOI{}\n_=x')
        pair('mutable-options','var x:p.QOI.EncoderOptions=.{};x.colorspace=.linear;',
             'mut x:=p.QoiEncoderOptions{}\nx.colorspace=.linear')
        pair('readonly-options','const x:p.QOI.EncoderOptions=.{};x.colorspace=.linear;',
             'x:=p.QoiEncoderOptions{}\nx.colorspace=.linear','cannot assign to constant','immutable')
        (root/'consumer_sha256.json').write_text(json.dumps(consumer_hashes,indent=2)+'\n')
        for name,digest in consumer_hashes.items():
            if hashlib.sha256((root/name).read_bytes()).hexdigest()!=digest:raise AssertionError('consumer changed')
        (root / 'input_sha256.json').write_text(json.dumps(inputs, indent=2) + '\n')
        for name, digest in inputs.items():
            if hashlib.sha256((root / name).read_bytes()).hexdigest() != digest:
                raise AssertionError('input changed')
        return_digest = returns.hexdigest()
        state_digest = states.hexdigest()
        if sum(return_groups.values()) != EXPECTED_RETURNS or sum(trap_groups.values()) != EXPECTED_TRAPS:
            raise AssertionError('return or trap count changed')
        if return_digest != EXPECTED_RETURN_SHA256:
            raise AssertionError('return golden changed')
        if state_digest != EXPECTED_STATE_SHA256:
            raise AssertionError('state golden changed')
        if (tree_hash(source) != PINNED_SOURCE_SHA256 or tree_hash(root / 'src') != PINNED_SOURCE_SHA256
                or stdlib_hash(zig) != PINNED_STDLIB_SHA256 or implementation_hashes(repo) != implementations
                or hashlib.sha256(Path(__file__).read_bytes()).hexdigest() != runner_hash):
            raise AssertionError('dependency, implementation or runner changed')
        for name, expected in fixtures.items():
            if any(hashlib.sha256((base / name).read_bytes()).hexdigest() != expected for base in (root, probe)):
                raise AssertionError('fixture changed')
        summary = dict(main_records=EXPECTED_MAIN, main_sha256=main_digest,
                       returning_records=sum(return_groups.values()), return_groups=dict(return_groups),
                       return_sha256=return_digest, paired_traps=sum(trap_groups.values()),
                       failure_groups=dict(trap_groups), state_sha256=state_digest, complete_constructor_pairs=2, required_field_pairs=7, default_codec_pairs=1, mutable_option_pairs=1, readonly_option_pairs=1,
                       zig_mode=mode, v_prod=args.v_prod)
        (root / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
        print(json.dumps(summary), flush=True)


if __name__ == '__main__':
    main()
