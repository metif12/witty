"""Compare unchanged IFF planar/ByteRun2 output, checked failures and borrowed state."""
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
from verify_tiff_decode_reference import ProofLog, tree_hash, work_directory, PINNED_SOURCE_SHA256, checked_trap

EXPECTED_RETURNS = 31017
EXPECTED_TRAPS = 1225
EXPECTED_RETURN_SHA256 = '74895e84f384182b4ddeb7f3ee1a6f615fca7b9319b129744bae26d114b2925b'
EXPECTED_STATE_SHA256 = 'da83479790fc43626a5326117ebad8ea0defbafe86d853389c32fb1188bc0328'
UNION = "access of union field 'bmhd' while field 'dgbl' is active"


class CheckedFailure(Exception):
    pass


def classify(op, tag, fmt, w, h, planes, comp, pitch, start, source, output, backing, so, do):
    """Partition fixtures; unchanged compiled Source remains the output oracle."""
    if tag:
        return UNION
    if backing is None:
        src, dst = bytearray(source), bytearray(output)
    else:
        storage = bytearray(backing)
        src = memoryview(storage)[so:so + len(source)]
        dst = memoryview(storage)[do:do + len(output)]
    def index(i, length):
        if i >= length:
            raise CheckedFailure(f'index out of bounds: index {i}, len {length}')
    try:
        if op == 0:
            if fmt == 1:
                if len(dst) > len(src):
                    raise CheckedFailure(f'index out of bounds: index {len(dst)}, len {len(src)}')
                if backing is not None and len(dst) and so < do + len(dst) and do < so + len(dst):
                    raise CheckedFailure('@memcpy arguments alias')
                return None
            dst[:] = bytes(len(dst))
            size = max(1, planes // 8)
            pairs = ((y, p) for y in range(h) for p in range(planes)) if fmt == 0 else ((y, p) for p in range(planes) for y in range(h))
            for y, p in pairs:
                if fmt == 0 and comp != 2:
                    if pitch * planes > 65535:
                        raise CheckedFailure('integer overflow')
                    base = pitch * planes * y + p * pitch
                else:
                    base = p * h * pitch + y * pitch
                for i in range(pitch):
                    index(base + i, len(src))
                    bits = src[base + i]
                    for b in range(8):
                        if bits & (1 << (7 - b)):
                            offset = (y * w + i * 8 + b) * size + p // 8
                            index(offset, len(dst))
                            dst[offset] |= 1 << (p % 8)
            return None
        dst[:] = bytes(len(dst))
        pos = start
        def take(n):
            nonlocal pos
            if pos + n > len(src):
                raise EOFError
            result = bytes(src[pos:pos + n]); pos += n
            return result
        def word():
            return int.from_bytes(take(2), 'big')
        for p in range(planes):
            take(8)
            count = word()
            if count < 2:
                raise CheckedFailure('integer overflow')
            commands = take(count - 2)
            x = y = ci = 0
            while x < pitch:
                index(ci, len(commands))
                command = commands[ci]
                if command >= 128:
                    command -= 256
                repeat = 0
                if command in (0, 1):
                    count = word()
                    if command == 1:
                        repeat = word()
                elif command < 0:
                    count = -command
                else:
                    count = command; repeat = word()
                while count and x < pitch:
                    offset = p * h * pitch + x + y * pitch
                    index(offset, len(dst))
                    dst[offset] = repeat >> 8 if command >= 1 else take(1)[0]
                    index(offset + 1, len(dst))
                    dst[offset + 1] = repeat & 255 if command >= 1 else take(1)[0]
                    y += 1
                    if y >= h:
                        y = 0; x += 2
                    count -= 1
                ci += 1
    except CheckedFailure as error:
        return str(error)
    except EOFError:
        return None
    return None


def vdat(commands, data=b'', count=None):
    return b'VDAT\xff\xff\xff\xff' + struct.pack('>H', len(commands) + 2 if count is None else count) + commands + data


def corpus():
    rows, traps, counts = [], [], Counter()
    def add(group, source=b'', output=b'\xa5' * 32, *, op=0, tag=0, fmt=0, w=16, h=1, planes=1, comp=0, pitch=2, start=0, backing=None, so=0, do=0):
        name = f'{group}-{counts[group]}'; counts[group] += 1
        message = classify(op, tag, fmt, w, h, planes, comp, pitch, start, source, output, backing, so, do)
        line = '|'.join(map(str, (op, tag, fmt, w, h, planes, comp, pitch, start, source.hex(), output.hex(), '-' if backing is None else backing.hex(), so, do)))
        (traps if message else rows).append((group, name, line, message))
    # Every byte pattern, all format branches and all legal compression tags.
    for fmt in range(5):
        for comp in range(3):
            for planes in (0, 1, 2, 8, 16, 24, 32):
                for byte in range(256):
                    source = bytes((byte, byte ^ 255)) * (planes * 2)
                    size = max(1, planes // 8)
                    if fmt == 1:
                        source = bytes((byte, byte ^ 255)) * (16 * size)
                    add('planar-byte', source, b'\xa5' * (32 * size), fmt=fmt, comp=comp, planes=planes, h=2)
    # Sparse wide-plane controls include the entire u8 plane domain.
    for planes in range(256):
        for fmt in (0, 2):
            for comp in (0, 2):
                add('plane-domain', b'\x81\x01' * planes, b'\x5a' * (16 * max(1, planes // 8)), fmt=fmt, comp=comp, planes=planes)
    # Distinct bytes in each row/plane distinguish interleaved and vertical layouts.
    for fmt in range(5):
        for comp in range(3):
            for planes in (1,2,3,8,9,15,16,17,23,24,25,31,32,64,255):
                for w,h,pitch in ((16,1,2),(32,3,4)):
                    for seed in (0,1,19,255):
                        dest = w*h*max(1,planes//8)+1
                        length = max(pitch*h*planes,dest if fmt==1 else 0)
                        source = bytes((i*37+(i//pitch)*17+seed)&255 for i in range(length))
                        add('planar-layout', source, b'\xa5'*dest, fmt=fmt, comp=comp, w=w, h=h, pitch=pitch, planes=planes)
    for fmt in range(5):
        for comp in range(3):
            for w, h, planes, pitch, source, dest in (
                (0,0,255,65535,b'',0),(65535,0,255,65535,b'',1),
                (0,2,0,65535,b'',0),(0,2,1,0,b'',3),
                (0,1,1,2,b'\x80\x00',0),(1,1,1,2,b'\x01\x00',1),
                (7,2,1,2,b'\x01\x00\x00\x00',14),
                (8,1,1,2,b'\x00\x80',8),(16,1,1,2,b'\xff',16),
                (16,2,2,2,b'\xff'*5,32),(16,1,24,2,b'\xff'*48,47),
                (16,1,2,32768,b'',1),(16,1,255,65535,b'',1),
                (65535,65535,255,65535,b'\x00',1),
                (65535,65535,255,65535,b'\x80',0)):
                add('planar-bounds', source, b'\xa5' * dest, fmt=fmt, comp=comp, w=w, h=h, planes=planes, pitch=pitch)
    # Tall headers still fail on the first missing row in a short source.
    for fmt, comp in ((0,2),(2,0),(3,2),(4,0)):
        add('tall-short-source', b'\x00', b'\xa5', fmt=fmt, comp=comp, w=0, h=65535, planes=2, pitch=1)
    for fmt in range(5):
        for comp in (0,2):
            for source_len, dest_len, so, do in ((8,8,0,0),(8,4,0,0),(8,4,0,2),(8,4,2,0),(8,4,0,4),(8,4,0,8),(4,8,0,2),(0,0,0,0),(8,0,0,3)):
                backing = bytes((i*37+19)&255 for i in range(20))
                add('planar-alias', bytes(source_len), bytes(dest_len), fmt=fmt, comp=comp, w=8, h=1, pitch=1, backing=backing, so=so, do=do)
    for op in (0,1):
        for fmt in range(5):
            add('wrong-header', b'abc', b'\xa5'*3, op=op, tag=1, fmt=fmt)
    # All 256 signed commands, with zero/odd/even pitch and zero/multirow heights.
    for command in range(256):
        for h, pitch in ((0,0),(0,2),(1,1),(1,2),(2,2),(2,4)):
            signed = command if command < 128 else command - 256
            payload = (struct.pack('>H', 7) if command in (0,1) else b'')
            payload += b'\x12\x34' if signed > 0 else bytes((i*37+19)&255 for i in range(256))
            if command == 1: payload += b'\x56\x78'
            add('rle-command', b'xxx'+vdat(bytes((command,)), payload), b'\xa5'*32, op=1, h=h, pitch=pitch, start=3)
    for command in (0,1):
        for count in (0,1,2,3,65535):
            payload = struct.pack('>H',count) + (b'\x12\x34' if command==1 else bytes(range(16)))
            data = vdat(bytes((command,255)), payload + b'\x56\x78')
            for cut in range(len(data)+1):
                add('rle-prefix', data[:cut], b'\xa5'*8, op=1, h=2, pitch=4)
    for count in (0,1,2,3,4,65535):
        data = vdat(b'\xff', b'\x12\x34', count=count)
        for cut in (0,1,7,8,9,10,len(data)):
            add('rle-count', data[:cut], b'\xa5'*4, op=1)
    for command, payload in ((255,b'\x12\x34'),(0,b'\x00\x01\x12\x34'),(2,b'\x12\x34'),(1,b'\x00\x01\x12\x34')):
        data = vdat(bytes((command,)), payload)
        for output_len in range(5):
            for cut in range(10,len(data)+1):
                add('rle-write-order', data[:cut], b'\xa5'*output_len, op=1)
    for h, pitch, planes in ((0,0,0),(0,2,0),(0,2,2),(1,2,2),(2,2,3),(2,4,2),(1,3,2)):
        plane = vdat(b'\x04',b'\x12\x34')
        data = plane*planes + b'ignored'
        for cut in sorted({0,len(data)//2,len(data),max(0,len(data)-8)}):
            add('rle-planes', data[:cut], b'\xa5'*32, op=1, h=h, pitch=pitch, planes=planes)
    for commands in (bytes((0,1,255,2,128,127)),bytes((255,)*12),bytes((1,)*12),bytes((0,)*12),bytes((2,3,255,254))):
        payload = bytearray()
        for command in commands:
            signed = command if command<128 else command-256
            count = 0 if command==0 else 1 if command==1 else abs(signed)
            if command in (0,1): payload += struct.pack('>H',count)
            if signed>0: payload += b'\x12\x34'
            else: payload += bytes((i*37+19)&255 for i in range(count*2))
        for h in (0,1,2,3):
            for pitch in (0,1,2,3,4,6):
                for extra in (0,1):
                    add('rle-command-sequences', vdat(commands,bytes(payload))+b'tail', b'\xa5'*(pitch*max(1,h)+extra), op=1, h=h, pitch=pitch)
    for source_len, output_len, so, do in ((16,2,0,0),(16,2,0,10),(16,2,0,13),(16,2,0,18),(16,4,0,8)):
        backing = vdat(b'\xff',b'\x12\x34') + bytes(range(16))
        add('rle-alias', bytes(source_len), bytes(output_len), op=1, backing=backing, so=so, do=do)
    return rows, traps


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source',type=Path); parser.add_argument('zig',type=Path); parser.add_argument('v',type=Path)
    parser.add_argument('--target',default='aarch64-macos.14.0'); parser.add_argument('--v-prod',action='store_true')
    parser.add_argument('--workdir',type=Path); parser.add_argument('--timeout',type=int,default=180)
    args = parser.parse_args()
    if args.timeout <= 0: parser.error('--timeout must be positive')
    source = args.source.resolve()/'src'; zig = args.zig.resolve(); v = args.v.resolve()
    if tree_hash(source)!=PINNED_SOURCE_SHA256 or stdlib_hash(zig)!=PINNED_STDLIB_SHA256:
        parser.error('Source or selected library differs from pins')
    repo = Path(__file__).resolve().parent.parent; probe = repo/'zigimg/reference_probes/iff_planar'
    mode = 'ReleaseSafe' if args.v_prod else 'Debug'; env = dict(os.environ,VEXE=str(v),V_C_ERROR_BUG_REPORT_DISABLED='1')
    with work_directory(args.workdir,'witty-iff-planar-') as root:
        proof = ProofLog(root); shutil.copytree(source,root/'src'); fixtures = {}
        for name in ('main.v','reference.zig'):
            shutil.copyfile(probe/name,root/name); fixtures[name] = hashlib.sha256((root/name).read_bytes()).hexdigest()
        versions = [proof.run([str(exe),'version'],label,env=env).stdout.decode().strip() for exe,label in ((zig,'zig-version'),(v,'v-version'))]
        if versions[0]!='0.15.2' or not re.match(r'^V 0\.5\.2(?: |$)',versions[1]): raise AssertionError('unexpected compiler versions')
        implementations = implementation_hashes(repo); runner_hash = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
        (root/'provenance.json').write_text(json.dumps(dict(source_sha256=PINNED_SOURCE_SHA256,stdlib_sha256=PINNED_STDLIB_SHA256,
            versions=versions,target=args.target,zig_mode=mode,v_prod=args.v_prod,fixtures=fixtures,
            implementation_sha256=implementations,runner_sha256=runner_hash),indent=2)+'\n')
        zbase = [str(zig),'build-exe','-target',args.target,'-lc','-O',mode,'--global-cache-dir',str(root/'zig-global')]
        vbase = [str(v),'-enable-globals',*(['-prod'] if args.v_prod else []),'-path',f'{repo}|@vlib|@vmodules']
        print(f'Building IFF planar: Source {mode}, V {"production" if args.v_prod else "ordinary"}',flush=True)
        proof.run(zbase+['-femit-bin='+str(root/'native'),str(root/'reference.zig')],'build-source',timeout=args.timeout)
        proof.run(vbase+['-o',str(root/'translated'),str(root/'main.v')],'build-v',env=env,timeout=args.timeout)
        rows, traps = corpus(); inputs = {}
        file = root/'corpus.txt'; file.write_text('\n'.join(row for group,name,row,message in rows)+'\n')
        inputs[file.name] = hashlib.sha256(file.read_bytes()).hexdigest()
        outputs = []
        for exe in ('native','translated'):
            result = proof.run([str(root/exe),'--corpus',str(file)],'corpus-'+exe,timeout=args.timeout)
            if result.stderr: raise AssertionError('unexpected corpus stderr')
            outputs.append(result.stdout.splitlines())
        if any(len(output)!=len(rows) for output in outputs): raise AssertionError('corpus counts differ')
        returns = hashlib.sha256(); states = hashlib.sha256(); return_groups = Counter(); trap_groups = Counter()
        for (group,name,row,message),native,translated in zip(rows,*outputs):
            if native!=translated: raise AssertionError(f'{name}: {native!r} != {translated!r}; input {row}')
            returns.update(name.encode()+b'\0'+native+b'\n'); return_groups[group]+=1
        print(f'{len(rows)} returning records match; checking {len(traps)} strict failures',flush=True)
        for group,name,row,message in traps:
            file = root/(name+'.txt'); file.write_text(row); inputs[file.name] = hashlib.sha256(file.read_bytes()).hexdigest()
            records = []
            for exe in ('native','translated'):
                path = root/(name+'-'+exe+'.state')
                result = proof.run([str(root/exe),'--case',str(path),row],name+'-'+exe,timeout=args.timeout,check=False)
                checked_trap(result,name+'/'+exe,message)
                messages = [m.group(1) for line in result.stderr.decode().splitlines() if (m:=re.fullmatch(r'(?:thread \d+ |V )?panic:\s*(.*)',line.strip()))]
                if messages!=[message] or not path.exists(): raise AssertionError('exact panic or state missing')
                records.append(path.read_bytes())
            if not records[0] or records[0]!=records[1]: raise AssertionError(f'{name}: differing state {records}; input {row}')
            states.update(name.encode()+b'\0'+message.encode()+b'\0'+records[0]+b'\n'); trap_groups[group]+=1
        (root/'input_sha256.json').write_text(json.dumps(inputs,indent=2)+'\n')
        for name,digest in inputs.items():
            if hashlib.sha256((root/name).read_bytes()).hexdigest()!=digest: raise AssertionError('generated input changed')
        if tree_hash(source)!=PINNED_SOURCE_SHA256 or tree_hash(root/'src')!=PINNED_SOURCE_SHA256 or stdlib_hash(zig)!=PINNED_STDLIB_SHA256 or implementation_hashes(repo)!=implementations or hashlib.sha256(Path(__file__).read_bytes()).hexdigest()!=runner_hash:
            raise AssertionError('dependency, implementation or runner changed')
        for name,expected in fixtures.items():
            if any(hashlib.sha256((base/name).read_bytes()).hexdigest()!=expected for base in (root,probe)): raise AssertionError('fixture changed')
        summary = dict(returning_records=len(rows),return_groups=dict(return_groups),return_sha256=returns.hexdigest(),paired_traps=len(traps),failure_groups=dict(trap_groups),state_sha256=states.hexdigest())
        (root/'summary.json').write_text(json.dumps(summary,indent=2)+'\n'); print(json.dumps(summary,indent=2),flush=True)
        if len(rows)!=EXPECTED_RETURNS or len(traps)!=EXPECTED_TRAPS or returns.hexdigest()!=EXPECTED_RETURN_SHA256 or states.hexdigest()!=EXPECTED_STATE_SHA256:
            raise AssertionError('locked IFF planar golden changed')


if __name__ == '__main__':
    main()
