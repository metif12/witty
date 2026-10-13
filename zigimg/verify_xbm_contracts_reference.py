"""Compare unchanged XBM parsing, caller state, pixel ownership and detector loops."""
import argparse
from collections import Counter
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess

from verify_jpeg_contracts_reference import implementation_hashes
from verify_tga_decode_reference import stdlib_hash, PINNED_STDLIB_SHA256
from verify_tiff_decode_reference import ProofLog, tree_hash, work_directory, PINNED_SOURCE_SHA256, no_core

EXPECTED_RETURNS = 15337
EXPECTED_SHA256 = '6544506d5e8c60983270a840d0b278fb9419c4690e7c7d1e8235040527065e0e'
FMT_SHA256 = '667eac6285e472b5516ebebf8a6e69959a171be4fb97cac1e56419ffec20d500'


def image(w=b'8', h=b'1', body=b'{0xff}\n', extra=b''):
    return b'#define width '+w+b'\n#define height '+h+b'\n'+extra+body


def corpus():
    rows,counts=[],Counter()
    def add(group,data=b'',op=0,start=0):
        name=f'{group}-{counts[group]}';counts[group]+=1
        data=b'x'*start+data
        rows.append((group,name,f'{op}|{start}|{data.hex()}'))
    add('records',op=3)
    for byte in range(256):
        for w,h in ((1,1),(4,2),(7,3),(8,1),(9,2),(16,2),(17,3)):
            for uppercase in (False,True):
                tokens=','.join(('0X' if uppercase else '0x')+f'{(byte+i*37)&255:02x}' for i in range((w*h+7)//8+1)).encode()
                for op in (0,1):add('bits',image(str(w).encode(),str(h).encode(),b'{'+tokens+b'}\n'),op)
        for separator in (b',',b' ',b'\t',b'\n',b'{',b'}',b';',b'\r',bytes((byte,))):
            add('token-byte',image(body=b'{0x55'+separator+b'0xaa}\n'))
        for token in (b'0x'+bytes((byte,)),b'0X1'+bytes((byte,))+b'0',b'0x'+bytes((byte,))+b'_1',b'0x1'+bytes((byte,))+b'\x00'):
            for op in (0,1):add('token-lexing',image(body=b'{'+token+b',0xff}\n'),op)
        for token in (b'8'+bytes((byte,)),bytes((byte,))+b'8',b'+0_'+bytes((byte,)),b'-'+bytes((byte,))):
            add('define-byte',image(w=token,h=b'0'))
    for value in (0,1,255,256,257,65535,65536,0x123456,0xffffffff):
        for token in (f'0x{value:x}',f'0X{value:X}',f'0x+{value:x}',f'0x{value:x}_',f'0x_{value:x}'):
            for w in (0,1,8,16,17):
                for op in (0,1):add('word-width',image(str(w).encode(),b'1',b'{'+token.encode()+b',0xff,0x55}\n'),op)
    numbers=(b'',b'0',b'-0',b'+0',b'00',b'1',b'8',b'+0_8',b'_8',b'8_',b'1__2',b'0x8',b'-1',b'4294967295',b'4294967296',b'18446744073709551615',b'1.0',b'8\t',b'8 ',b'8\r',b'8\x00')
    for number in numbers:
        for lead in (b'#define width ',b'#define\twidth\t',b'#defined width ',b'#define ',b' #define width '):
            for ending in (b'\n',b' \r\n',b'\t\n'):
                for op in (0,1):add('define-number',lead+number+ending+b'#define height 0\n{}\n',op)
    for sequence in ((0,0),(0,7),(7,0),(0,0,7,8),(1,2,3,4),(0,0,0,7,8),(1,2,3,4,5),(1,2,3,4,-1)):
        extra=b''.join(b'#define ignored '+str(value).encode()+b'\n' for value in sequence)
        for op in (0,1):add('hotspots',image(extra=extra),op)
    samples=[image(),image(body=b'{}\n'),image(body=b'{\n0xff\n};\n'),image(body=b'{0xff}\r\n'),image(body=b'{\n0xff\r\n0x55\n}\n'),image(body=b'{0xff}\nunterminated'),b'#define width 8\n',b'#define width 8\n#define height 1\n',b'not a define\n',b'\n',b'']
    for packet in samples:
        for cut in range(len(packet)+1):
            for op in (0,1):
                for start in (0,3):add('prefix',packet[:cut],op,start)
    for w,h in ((0,0),(0,4294967295),(4294967295,0),(1,0),(0,1),(3,5),(7,7),(16,17),(31,3)):
        for count in (0,1,2,8,64):
            for op in (0,1):add('dimensions',image(str(w).encode(),str(h).encode(),b'{'+b'0x81,'*count+b'}\n'),op)
    for data in (b'',b'#define width 8',b'\n',b'anything\n',b' #define width 8\n',b'#definE 1\n',b'#defin\n'):
        for start in (0,3):add('detect',data,2,start)
    for byte in range(256):
        add('detect-byte',bytes((byte,))+b'abcdef\n',2)
    return rows


def bounded_loop(proof, root, exe, row, label, env):
    argv=[str(root/exe),'--loop',row]
    process=subprocess.Popen(argv,stdout=subprocess.PIPE,stderr=subprocess.PIPE,env=env,preexec_fn=no_core)
    try:
        stdout,stderr=process.communicate(timeout=0.5)
        raise AssertionError(f'{label}: inherited detector loop returned {process.returncode}: {stdout!r}, {stderr!r}')
    except subprocess.TimeoutExpired:
        process.kill();stdout,stderr=process.communicate()
    prefix=f'{len(proof.commands):03d}-{label}'
    proof.commands.append(dict(label=label,argv=argv,cwd=os.getcwd(),timeout=0.5,bounded_loop=True,killed_after_timeout=True,returncode=process.returncode))
    (root/(prefix+'.stdout')).write_bytes(stdout);(root/(prefix+'.stderr')).write_bytes(stderr)
    (root/'commands.json').write_text(json.dumps(proof.commands,indent=2)+'\n')
    if stderr or not stdout.startswith(b'ready|'):raise AssertionError(f'{label}: missing initialized ready state or unexpected stderr')
    return stdout


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source',type=Path);parser.add_argument('zig',type=Path);parser.add_argument('v',type=Path)
    parser.add_argument('--target',default='aarch64-macos.14.0');parser.add_argument('--v-prod',action='store_true')
    parser.add_argument('--workdir',type=Path);parser.add_argument('--timeout',type=int,default=180)
    args=parser.parse_args()
    if args.timeout<=0:parser.error('--timeout must be positive')
    source=args.source.resolve()/'src';zig=args.zig.resolve();v=args.v.resolve()
    if tree_hash(source)!=PINNED_SOURCE_SHA256 or stdlib_hash(zig)!=PINNED_STDLIB_SHA256 or hashlib.sha256((zig.parent/'lib/std/fmt.zig').read_bytes()).hexdigest()!=FMT_SHA256:parser.error('Source or selected library differs from pins')
    repo=Path(__file__).resolve().parent.parent;probe=repo/'zigimg/reference_probes/xbm_contracts'
    mode='ReleaseSafe' if args.v_prod else 'Debug';env=dict(os.environ,VEXE=str(v),V_C_ERROR_BUG_REPORT_DISABLED='1')
    with work_directory(args.workdir,'witty-xbm-contracts-') as root:
        proof=ProofLog(root);shutil.copytree(source,root/'src');fixtures={}
        for name in ('main.v','reference.zig'):
            shutil.copyfile(probe/name,root/name);fixtures[name]=hashlib.sha256((root/name).read_bytes()).hexdigest()
        versions=[proof.run([str(exe),'version'],label,env=env).stdout.decode().strip() for exe,label in ((zig,'zig-version'),(v,'v-version'))]
        if versions[0]!='0.15.2' or not re.match(r'^V 0\.5\.2(?: |$)',versions[1]):raise AssertionError('unexpected compiler versions')
        implementations=implementation_hashes(repo);runner_hash=hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
        (root/'provenance.json').write_text(json.dumps(dict(source_sha256=PINNED_SOURCE_SHA256,stdlib_sha256=PINNED_STDLIB_SHA256,
            fmt_sha256=FMT_SHA256,
            versions=versions,target=args.target,zig_mode=mode,v_prod=args.v_prod,fixtures=fixtures,implementation_sha256=implementations,runner_sha256=runner_hash),indent=2)+'\n')
        zbase=[str(zig),'build-exe','-target',args.target,'-lc','-O',mode,'--global-cache-dir',str(root/'zig-global')]
        vbase=[str(v),'-enable-globals',*(['-prod'] if args.v_prod else []),'-path',f'{repo}|@vlib|@vmodules']
        print(f'Building XBM: Source {mode}, V {"production" if args.v_prod else "ordinary"}',flush=True)
        proof.run(zbase+['-femit-bin='+str(root/'native'),str(root/'reference.zig')],'build-source',timeout=args.timeout)
        proof.run(vbase+['-o',str(root/'translated'),str(root/'main.v')],'build-v',env=env,timeout=args.timeout)
        rows=corpus();inputs={};file=root/'corpus.txt';file.write_text('\n'.join(row for group,name,row in rows)+'\n')
        inputs[file.name]=hashlib.sha256(file.read_bytes()).hexdigest();outputs=[]
        for exe in ('native','translated'):
            result=proof.run([str(root/exe),'--corpus',str(file)],'corpus-'+exe,timeout=args.timeout)
            if result.stderr:raise AssertionError('unexpected corpus stderr')
            outputs.append(result.stdout.splitlines())
        if any(len(output)!=len(rows) for output in outputs):raise AssertionError('corpus counts differ')
        digest=hashlib.sha256();groups=Counter()
        for (group,name,row),native,translated in zip(rows,*outputs):
            if native!=translated:raise AssertionError(f'{name}: {native!r} != {translated!r}; input {row}')
            digest.update(name.encode()+b'\0'+native+b'\n');groups[group]+=1
        for index,data in enumerate((b'#define w 8\n',b'#defined 1\n',b'#define\n',b'#define a 0\n#define b 0\n')):
            row=f'2|3|{(b"xxx"+data).hex()}';file=root/f'loop-{index}.txt';file.write_text(row);inputs[file.name]=hashlib.sha256(file.read_bytes()).hexdigest()
            ready=[bounded_loop(proof,root,exe,row,f'loop-{index}-{exe}',env) for exe in ('native','translated')]
            if ready[0]!=ready[1]:raise AssertionError('loop ready states differ')
        (root/'input_sha256.json').write_text(json.dumps(inputs,indent=2)+'\n')
        for name,expected in inputs.items():
            if hashlib.sha256((root/name).read_bytes()).hexdigest()!=expected:raise AssertionError('generated input changed')
        if tree_hash(source)!=PINNED_SOURCE_SHA256 or tree_hash(root/'src')!=PINNED_SOURCE_SHA256 or stdlib_hash(zig)!=PINNED_STDLIB_SHA256 or hashlib.sha256((zig.parent/'lib/std/fmt.zig').read_bytes()).hexdigest()!=FMT_SHA256 or implementation_hashes(repo)!=implementations or hashlib.sha256(Path(__file__).read_bytes()).hexdigest()!=runner_hash:raise AssertionError('dependency, implementation or runner changed')
        for name,expected in fixtures.items():
            if any(hashlib.sha256((base/name).read_bytes()).hexdigest()!=expected for base in (root,probe)):raise AssertionError('fixture changed')
        summary=dict(returning_records=len(rows),return_groups=dict(groups),sha256=digest.hexdigest(),paired_bounded_loops=4)
        (root/'summary.json').write_text(json.dumps(summary,indent=2)+'\n');print(json.dumps(summary,indent=2),flush=True)
        if len(rows)!=EXPECTED_RETURNS or digest.hexdigest()!=EXPECTED_SHA256:raise AssertionError('locked XBM golden changed')


if __name__=='__main__':main()
