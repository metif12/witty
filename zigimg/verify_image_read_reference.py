"""Compare public read/detect wrappers, borrowed files and retained buffer failures."""
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
import subprocess
from verify_tiff_decode_reference import no_core
from verify_png_foundation_reference import PINNED_FLATE_SHA256, FLATE_SOURCES
from verify_jpeg_contracts_reference import implementation_hashes
from verify_tiff_decode_reference import ProofLog, tree_hash, work_directory, PINNED_SOURCE_SHA256, checked_trap
from verify_tga_decode_reference import stdlib_hash, PINNED_STDLIB_SHA256

ENCODER_LIBRARIES = {'fmt.zig': '667eac6285e472b5516ebebf8a6e69959a171be4fb97cac1e56419ffec20d500', 'simd.zig': 'cc554020cebe55782b38c18c56a011b61a42f332781e5d0a5b1be3003eddd7a3', 'math.zig': '65645001357d5f78cbf646485e009a048b828680bb1b47fb3de0fd8617d91af1'}

def encoder_library_hashes(zig):
    return {name: hashlib.sha256((zig.parent/'lib/std'/name).read_bytes()).hexdigest() for name in ENCODER_LIBRARIES}


def flate_hash(zig):
    digest = hashlib.sha256()
    for name in FLATE_SOURCES:
        digest.update(name.encode() + b'\0')
        digest.update((zig.parent / 'lib/std' / name).read_bytes())
    return digest.hexdigest()

EXPECTED_ROWS = 18040
EXPECTED_SHA256 = '2b0e3abd67907e90dee44af4969652acb1a99a2c8a302a2f1f1848467171eafd'
EXPECTED_CONTROLS = 2182
EXPECTED_CONTROL_SHA256 = 'fe7af7f48f4e178f124528b064f1b332316945b360f44ee2d27ec85764e934ca'
EXPECTED_TRAPS = 948
EXPECTED_STATE_SHA256 = '9c108992c26ef38c818f6b827b98f65668aa1aa704158e7bf6577cf3d4d2ea09'
EXPECTED_LOOPS = 40
EXPECTED_READY_SHA256 = '0f2daf83f99d0dba7096f4d4c933da9d653415d5aa9345df7556964678174477'
GENERATOR_HELPERS = ('verify_bmp_contracts_reference.py', 'verify_gif_streams_reference.py',
    'verify_iff_streams_reference.py', 'verify_iff_pixels_reference.py', 'verify_iff_records_reference.py',
    'verify_pam_contracts_reference.py', 'verify_pcx_decode_reference.py', 'verify_pcx_contracts_reference.py',
    'verify_png_decode_reference.py', 'verify_png_foundation_reference.py', 'verify_png_info_reference.py',
    'verify_sgi_contracts_reference.py', 'verify_ras_contracts_reference.py')


def examples():
    from verify_bmp_contracts_reference import header as bmp
    from verify_gif_streams_reference import header as gif, colors, app, graphic, image as gif_image
    from verify_iff_streams_reference import image as iff
    from verify_pam_contracts_reference import header as pam
    from verify_pcx_decode_reference import image as pcx
    from verify_png_decode_reference import image as png
    from verify_sgi_contracts_reference import header as sgi
    from verify_tga_decode_reference import image as tga
    from verify_tiff_decode_reference import make_tiff
    from verify_ras_contracts_reference import header as ras
    tail = b'                  \n'
    return [
        ('bmp', bmp() + bytes((19,56,93))),
        ('farbfeld', b'farbfeld' + struct.pack('>II4H',1,1,19,56,93,65535)),
        ('gif', gif() + colors() + app() + graphic(delay=37) + gif_image() + b'\x3b'),
        ('iff', iff()[0]),
        ('jpeg', bytes.fromhex(JPEG_HEX)),
        ('pam', pam(d=3) + bytes((19,56,93))),
        ('pbm', b'P1 1 1 1\n' + tail),
        ('pcx', pcx(1,1,planes=3,stride=1)),
        ('pgm', b'P2 1 1 255 19\n' + tail),
        ('png', png(1,1,color=6,depth=8,trns=False)),
        ('ppm', b'P3 1 1 255 19 56 93\n' + tail),
        ('qoi', b'qoif' + struct.pack('>II',1,1) + b'\x04\x00\xff\x13\x38\x5d\x07' + bytes(7) + b'\x01'),
        ('ras', ras(d=24) + bytes((19,56,93))),
        ('sgi', sgi(z=3,dimension=3) + bytes((19,56,93))),
        ('tga', tga(bpp=3,body=bytes((19,56,93)),compressed=False)),
        ('tiff', make_tiff(3,1,1,1,1,1,'little')),
        ('xbm', b'#define w 8\n#define h 1\n{0xff}\n'),
    ]


def spec(cap, op, route, data, attempts=2, defined=False):
    return '|'.join(map(str,(cap,op,route,attempts,int(defined),data.hex())))


def routes(capacities):
    return [(cap,route) for cap,route in itertools.product(capacities,range(4))] + [(0,4),(0,5)]


def corpus():
    rows=[]
    for fmt,data in examples():
        if fmt == 'xbm':continue  # Native public detection peeks the first define forever.
        for cap,route in routes((1024,4096)):
            rows.append(('complete-decoding',spec(cap,1,route,data,defined=True)))
        for cap,route in routes((26,32,64,128,512,1024)):
            rows.append(('complete-detection',spec(cap,0,route,data)))
        for cut in range(min(40,len(data))+1):
            for cap,route in routes((26,32,128)):
                rows.append(('detector-prefixes',spec(cap,0,route,data[:cut])))
            if fmt not in ('gif','tga'):
                for cap,route in routes((1024,4096)):
                    rows.append(('decoder-prefixes',spec(cap,1,route,data[:cut])))
    for first in range(256):
        data=bytes((first,))+b'abcdef012345678901234567890\n'
        for cap,route in routes((26,32,128)):
            rows.append(('registry-first-byte',spec(cap,0,route,data)))
    for data in (b'not an image\n',b'P7\n',b'P1 1 1 1',b'P4 1 1\n\x80',b'P5 1 1 255\n\x13',b'P6 1 1 255\n\x13\x38\x5d', b'#define', b'#define w 8', b' #define w 8\n'):
        for cap,route in routes((26,32,128)):
            for op in range(2):rows.append(('short-signature-order',spec(cap,op,route,data)))
    return rows


def controls():
    cases=[]
    def add(group,cap,op,route,data):cases.append((group,f'control-{len(cases)}',spec(cap,op,route,data,1)))
    for fmt,data in examples():
        if fmt=='xbm':continue
        for cap,op,route in itertools.product((0,1,2,7,8,11,12,18,25,26,32,127,128,510,512),range(2),range(4)):
            add('file-buffer-capacity',cap,op,route,data)
    for fmt,data in examples():
        if fmt not in ('gif','tga'):continue
        for cut in range(len(data)+1):
            for cap,route in routes((1024,4096)):
                add('gif-tga-decoder-prefix',cap,1,route,data[:cut])
    # Palette seek subtraction occurs only after this complete indexed PCX body.
    from verify_pcx_decode_reference import image as pcx
    data=pcx(1,1)
    for cut in (128,129,130,768,769,len(data)-1,len(data)):
        for cap,route in routes((128,1024)):
            add('indexed-palette-order',cap,1,route,data[:cut])
    return cases


def loops():
    cases=[]
    for data in (b'#define w 8\n', examples()[-1][1]):
        for cap,route in routes((32,128)):
            for op in range(2):
                cases.append((f'loop-{len(cases)}',spec(cap,op,route,data,1)))
    return cases


def bounded_loop(proof,root,exe,row,label,env):
    argv=[str(root/exe),'--loop',row,str(root/(label+'.bin'))]
    process=subprocess.Popen(argv,stdout=subprocess.PIPE,stderr=subprocess.PIPE,env=env,preexec_fn=no_core)
    try:
        stdout,stderr=process.communicate(timeout=0.5)
        raise AssertionError(f'{label}: inherited detector loop returned {process.returncode}')
    except subprocess.TimeoutExpired:
        process.kill();stdout,stderr=process.communicate()
    prefix=f'{len(proof.commands):03d}-{label}'
    proof.commands.append(dict(label=label,argv=argv,cwd=os.getcwd(),timeout=0.5,bounded_loop=True,killed_after_timeout=True,returncode=process.returncode))
    (root/(prefix+'.stdout')).write_bytes(stdout);(root/(prefix+'.stderr')).write_bytes(stderr)
    (root/'commands.json').write_text(json.dumps(proof.commands,indent=2)+'\n')
    if stderr or not stdout.startswith(b'ready|') or len(stdout.splitlines())!=1:raise AssertionError(f'{label}: missing initialized ready state')
    return stdout

JPEG_HEX = 'ffd8ffe000104a46494600010100000100010000ffdb0043000302020302020303030304030304050805050404050a070706080c0a0c0c0b0a0b0b0d0e12100d0e110e0b0b1016101113141515150c0f171816141812141514ffc0000b080008000801011100ffc4001f0000010501010101010100000000000000000102030405060708090a0bffc400b5100002010303020403050504040000017d01020300041105122131410613516107227114328191a1082342b1c11552d1f02433627282090a161718191a25262728292a3435363738393a434445464748494a535455565758595a636465666768696a737475767778797a838485868788898a92939495969798999aa2a3a4a5a6a7a8a9aab2b3b4b5b6b7b8b9bac2c3c4c5c6c7c8c9cad2d3d4d5d6d7d8d9dae1e2e3e4e5e6e7e8e9eaf1f2f3f4f5f6f7f8f9faffda0008010100003f002bffd9'

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source',type=Path);parser.add_argument('zig',type=Path);parser.add_argument('v',type=Path)
    parser.add_argument('--target',default='aarch64-macos.14.0');parser.add_argument('--v-prod',action='store_true')
    parser.add_argument('--workdir',type=Path);parser.add_argument('--timeout',type=int,default=180)
    args=parser.parse_args()
    if args.timeout<=0:parser.error('--timeout must be positive')
    source=args.source.resolve()/'src';zig=args.zig.resolve();v=args.v.resolve()
    if tree_hash(source)!=PINNED_SOURCE_SHA256 or stdlib_hash(zig)!=PINNED_STDLIB_SHA256 or encoder_library_hashes(zig)!=ENCODER_LIBRARIES:parser.error('Source or compiler library differs from pins')
    if flate_hash(zig)!=PINNED_FLATE_SHA256:parser.error('DEFLATE dependency differs from pin')
    repo=Path(__file__).resolve().parent.parent;probe=repo/'zigimg/reference_probes/image_read'
    mode='ReleaseSafe' if args.v_prod else 'Debug'
    with work_directory(args.workdir,'witty-image-read-') as root:
        tmp=root/'tmp';tmp.mkdir();env=dict(os.environ,TMPDIR=str(tmp),VTMP=str(tmp),VEXE=str(v),V_C_ERROR_BUG_REPORT_DISABLED='1')
        proof=ProofLog(root);shutil.copytree(source,root/'src');fixtures={}
        for name in ('main.v','reference.zig'):
            shutil.copyfile(probe/name,root/name);fixtures[name]=hashlib.sha256((root/name).read_bytes()).hexdigest()
        versions=[proof.run([str(exe),'version'],label,env=env).stdout.decode().strip() for exe,label in ((zig,'zig-version'),(v,'v-version'))]
        if versions[0]!='0.15.2' or not re.match(r'^V 0\.5\.2(?: |$)',versions[1]):raise AssertionError('unexpected compiler versions')
        impl=implementation_hashes(repo);runner_hash=hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
        helpers={name:hashlib.sha256((repo/'zigimg'/name).read_bytes()).hexdigest() for name in ('verify_jpeg_contracts_reference.py','verify_tiff_decode_reference.py','verify_tga_decode_reference.py',*GENERATOR_HELPERS)}
        (root/'provenance.json').write_text(json.dumps(dict(source_sha256=PINNED_SOURCE_SHA256,stdlib_sha256=PINNED_STDLIB_SHA256,encoder_libraries=ENCODER_LIBRARIES,flate_sha256=PINNED_FLATE_SHA256,versions=versions,target=args.target,zig_mode=mode,v_prod=args.v_prod,implementation_sha256=impl,runner_sha256=runner_hash,fixtures=fixtures,helper_sha256=helpers),indent=2)+'\n')
        print(f'Building image readers: Source {mode}, V {"production" if args.v_prod else "ordinary"}',flush=True)
        proof.run([str(zig),'build-exe','-target',args.target,'-lc','-O',mode,'--global-cache-dir',str(root.parent/'zig-global'),'--cache-dir',str(root/'zig-cache'),'-femit-bin='+str(root/'native'),str(root/'reference.zig')],'build-source',env=env,timeout=args.timeout)
        proof.run([str(v),'-enable-globals',*(['-prod'] if args.v_prod else []),'-path',f'{repo}|@vlib|@vmodules','-o',str(root/'translated'),str(root/'main.v')],'build-v',env=env,timeout=args.timeout)
        rows=corpus();path=root/'corpus.txt';path.write_text('\n'.join(data for _,data in rows)+'\n')
        inputs={'corpus.txt':hashlib.sha256(path.read_bytes()).hexdigest()}
        (root/'input_sha256.json').write_text(json.dumps(inputs,indent=2)+'\n')
        outputs=[]
        for exe in ('native','translated'):
            r=proof.run([str(root/exe),str(path)],'returning-'+exe,env=env,timeout=args.timeout,check=False)
            if r.returncode or r.stderr or len(r.stdout.splitlines())!=len(rows):raise AssertionError(f'{exe}: invalid returning output; see raw proof files')
            outputs.append(r.stdout.splitlines())
        for i,(native,translated) in enumerate(zip(*outputs)):
            if native!=translated:raise AssertionError(f'{i}/{rows[i][0]}: output differs; see raw proof files')
        digest=hashlib.sha256(b'\n'.join(outputs[0])).hexdigest()
        if EXPECTED_ROWS is not None and (len(rows)!=EXPECTED_ROWS or digest!=EXPECTED_SHA256):raise AssertionError('returning golden changed')
        print(f'{len(rows)} returning records match; checking native-classified capacity/palette controls',flush=True)
        returns=hashlib.sha256();states=hashlib.sha256();return_groups=Counter();trap_groups=Counter()
        for group,name,data in controls():
            records=[]
            for exe in ('native','translated'):
                state=root/(name+'-'+exe+'.state')
                records.append((proof.run([str(root/exe),'--trap',str(state),data],name+'-'+exe,env=env,timeout=args.timeout,check=False),state))
            native,translated=records[0][0],records[1][0]
            if native.returncode==0:
                if native.stderr or translated.returncode or translated.stderr or native.stdout!=translated.stdout or len(native.stdout.splitlines())!=1:raise AssertionError(f'{name}: control return differs')
                returns.update(name.encode()+b'\0'+native.stdout);return_groups[group]+=1
            else:
                messages=[]
                for (result,state),exe in zip(records,('native','translated')):
                    found=[m.group(1) for line in result.stderr.decode().splitlines() if (m:=re.fullmatch(r'(?:thread \d+ |V )?panic:\s*(.*)',line.strip()))]
                    if len(found)!=1 or not re.fullmatch(r'reached unreachable code|integer overflow|invalid enum value|index out of bounds: index \d+, len \d+',found[0]):raise AssertionError(f'{name}/{exe}: unexpected panic {found}')
                    checked_trap(result,name+'/'+exe,found[0]);messages.append(found[0])
                    if not state.exists():raise AssertionError('missing panic observer')
                if messages[0]!=messages[1]:raise AssertionError(f'{name}: exact panic differs: {messages}')
                observed=[state.read_bytes() for _,state in records]
                if not observed[0] or observed[0]!=observed[1]:raise AssertionError(f'{name}: failure state differs')
                states.update(name.encode()+b'\0'+messages[0].encode()+b'\0'+observed[0]+b'\n');trap_groups[group]+=1
        ready=hashlib.sha256()
        for name,data in loops():
            output=[bounded_loop(proof,root,exe,data,name+'-'+exe,env) for exe in ('native','translated')]
            if output[0]!=output[1]:raise AssertionError(f'{name}: initial loop state differs')
            ready.update(name.encode()+b'\0'+output[0])
        if EXPECTED_LOOPS is not None and (len(loops())!=EXPECTED_LOOPS or ready.hexdigest()!=EXPECTED_READY_SHA256):raise AssertionError('loop controls changed')
        controls_digest=returns.hexdigest();state_digest=states.hexdigest()
        if EXPECTED_CONTROLS is not None and (sum(return_groups.values())!=EXPECTED_CONTROLS or controls_digest!=EXPECTED_CONTROL_SHA256):raise AssertionError('return controls changed')
        if EXPECTED_TRAPS is not None and (sum(trap_groups.values())!=EXPECTED_TRAPS or state_digest!=EXPECTED_STATE_SHA256):raise AssertionError('failure golden changed')
        if tree_hash(source)!=PINNED_SOURCE_SHA256 or tree_hash(root/'src')!=PINNED_SOURCE_SHA256 or stdlib_hash(zig)!=PINNED_STDLIB_SHA256 or encoder_library_hashes(zig)!=ENCODER_LIBRARIES or flate_hash(zig)!=PINNED_FLATE_SHA256 or implementation_hashes(repo)!=impl or hashlib.sha256(Path(__file__).read_bytes()).hexdigest()!=runner_hash:raise AssertionError('dependency, implementation or runner changed')
        for name,expected in fixtures.items():
            if any(hashlib.sha256((base/name).read_bytes()).hexdigest()!=expected for base in (root,probe)):raise AssertionError('fixture changed')
        for name,expected in inputs.items():
            if hashlib.sha256((root/name).read_bytes()).hexdigest()!=expected:raise AssertionError('input changed')
        for name,expected in helpers.items():
            if hashlib.sha256((repo/'zigimg'/name).read_bytes()).hexdigest()!=expected:raise AssertionError('helper changed')
        summary=dict(returning_records=len(rows),calls=sum(int(data.split('|')[3]) for _,data in rows),returning_groups=dict(Counter(group for group,_ in rows)),output_sha256=digest,return_controls=sum(return_groups.values()),return_control_groups=dict(return_groups),control_sha256=controls_digest,paired_traps=sum(trap_groups.values()),failure_groups=dict(trap_groups),state_sha256=state_digest,paired_loops=len(loops()),ready_sha256=ready.hexdigest(),zig_mode=mode,v_prod=args.v_prod)
        (root/'summary.json').write_text(json.dumps(summary,indent=2)+'\n');print(json.dumps(summary),flush=True)


if __name__=='__main__':main()
