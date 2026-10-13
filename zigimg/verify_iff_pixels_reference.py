"""Compare unchanged IFF pixel decoding, chunk traversal, palette state and checked failures."""
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
from verify_iff_records_reference import MATH_SHA256

EXPECTED_RETURNS = 18248
EXPECTED_TRAPS = 1561
EXPECTED_RETURN_SHA256 = '72ba805b4d37c4c51ba1f75703c63a514cdb1cef621227beac12a209047e450b'
EXPECTED_STATE_SHA256 = '848258baaaf14b0ec8c50981c29e19c2a7af845961039f077db65da397e0fdb5'
EXPECTED_UNDEFINED = {
    'successful partial PackBits exposes private uninitialized planes': 37,
    'default EHB backing has uninitialized base colors': 37,
}
UNION = "access of union field 'bmhd' while field 'dgbl' is active"


class CheckedFailure(Exception):
    pass


class ReturningError(Exception):
    pass


class UndefinedCase(Exception):
    pass


class Model:
    """Only partition defined fixtures; compiled Source supplies all parity output."""
    def __init__(self, data, op, tag, fmt, w, h, planes, bits, pitch, mode, palette, comp, start):
        self.data, self.pos = data, start
        self.tag, self.fmt, self.w, self.h, self.planes = tag, fmt, w, h, planes
        self.bits, self.pitch, self.mode, self.palette, self.comp = bits, pitch, mode, palette, comp
        self.defined_palette = 256
        if op == 3:
            self.bits = self.mode = self.palette = self.defined_palette = 0

    def take(self, n):
        if self.pos + n > len(self.data):
            raise ReturningError('EndOfStream')
        result = self.data[self.pos:self.pos+n]; self.pos += n
        return result

    def word(self):
        return int.from_bytes(self.take(2),'big')

    def index(self, index, length):
        if index >= length:
            raise CheckedFailure(f'index out of bounds: index {index}, len {length}')

    def read(self):
        magic = self.take(12)
        if magic[:4] != b'FORM' or magic[8:] not in (b'ILBM',b'PBM ',b'ACBM'):
            raise ReturningError('InvalidData')
        self.fmt = (b'ILBM',b'PBM ',b'ACBM').index(magic[8:])
        chunk = self.take(8)
        if chunk[:4] != b'BMHD' or int.from_bytes(chunk[4:],'big') != 20:
            raise ReturningError('InvalidData')
        header = self.take(20)
        if header[9] > 3 or header[10] > 2:
            raise CheckedFailure('invalid enum value')
        self.tag = 0
        self.w,self.h = struct.unpack('>HH',header[:4])
        self.planes,self.comp = header[8],header[10]
        self.pitch = ((self.w+15)//16)*2
        self.chunks()

    def chunks(self):
        while True:
            chunk = self.take(8); name = chunk[:4]; length = int.from_bytes(chunk[4:],'big')
            if name in (b'BODY',b'ABIT'):
                self.pixel(length); return
            if name == b'CAMG':
                self.mode = int.from_bytes(self.take(4),'big')
            elif name == b'CMAP':
                count = length//3
                if count > 256:
                    raise CheckedFailure(f'index out of bounds: index {count}, len 256')
                self.palette = count
                for i in range(count):
                    self.take(3); self.defined_palette = max(self.defined_palette,i+1)
                if count == 0:
                    raise CheckedFailure('reached unreachable code')
                self.bits = (count-1).bit_length()
            else:
                if self.pos + length >= len(self.data):
                    raise ReturningError('Unseekable')
                self.pos += length
            if self.pos >= len(self.data)-1:
                raise ReturningError('Unsupported')

    def pixel(self, length):
        if self.pitch == 0:
            raise CheckedFailure('reached unreachable code')
        if self.tag:
            raise CheckedFailure(UNION)
        rgb = bool(self.mode & 0x800) or self.planes == 24
        if not rgb and self.planes > 8:
            raise ReturningError('Unsupported')
        size = self.pitch*self.h*self.planes
        if size > 100000:
            raise UndefinedCase('allocation extent outside fixture scope')
        raw = bytearray(size); defined = bytearray(size)
        if self.comp == 1 and self.fmt != 2:
            if length == 0:
                raise CheckedFailure('integer overflow')
            output = consumed = 0
            while consumed < length-1:
                control = self.take(1)[0]; consumed += 1
                if control < 128:
                    for _ in range(control+1):
                        if consumed >= length: break
                        self.index(output,size)
                        raw[output] = self.take(1)[0]; defined[output] = 1
                        output += 1; consumed += 1
                    if consumed >= length: break
                elif control > 128:
                    if consumed >= length: break
                    value = self.take(1)[0]; consumed += 1
                    for _ in range(257-control):
                        self.index(output,size)
                        raw[output] = value; defined[output] = 1; output += 1
        elif self.comp == 2:
            defined[:] = b'\x01'*size
            for p in range(self.planes):
                self.take(8); count = self.word()
                if count < 2: raise CheckedFailure('integer overflow')
                commands = self.take(count-2); ci = x = y = 0
                while x < self.pitch:
                    self.index(ci,len(commands)); command = commands[ci]
                    if command >= 128: command -= 256
                    repeat = 0
                    if command in (0,1):
                        count = self.word()
                        if command == 1: repeat = self.word()
                    elif command < 0: count = -command
                    else: count = command; repeat = self.word()
                    while count and x < self.pitch:
                        offset = p*self.h*self.pitch + x + y*self.pitch
                        self.index(offset,size)
                        raw[offset] = repeat>>8 if command>=1 else self.take(1)[0]
                        self.index(offset+1,size)
                        raw[offset+1] = repeat&255 if command>=1 else self.take(1)[0]
                        y += 1
                        if y >= self.h: y=0; x+=2
                        count -= 1
                    ci += 1
        else:
            raw[:] = self.take(size); defined[:] = b'\x01'*size
        if self.fmt == 0 and self.comp != 2 and self.h and self.planes and self.pitch*self.planes>65535:
            raise CheckedFailure('integer overflow')
        if not all(defined):
            raise UndefinedCase('successful partial PackBits exposes private uninitialized planes')
        chunky = bytearray(self.w*self.h*(3 if self.planes==24 else 1))
        pixel_size = max(1,self.planes//8)
        if self.fmt == 1:
            if len(chunky)>len(raw):
                raise CheckedFailure(f'index out of bounds: index {len(chunky)}, len {len(raw)}')
            chunky[:] = raw[:len(chunky)]
        else:
            pairs = ((y,p) for y in range(self.h) for p in range(self.planes)) if self.fmt == 0 else ((y,p) for p in range(self.planes) for y in range(self.h))
            for y,p in pairs:
                base = self.pitch*self.planes*y+p*self.pitch if self.fmt==0 and self.comp!=2 else p*self.h*self.pitch+y*self.pitch
                for i in range(self.pitch):
                    self.index(base+i,len(raw)); value = raw[base+i]
                    for b in range(8):
                        if value & (1<<(7-b)):
                            offset = (y*self.w+i*8+b)*pixel_size+p//8
                            self.index(offset,len(chunky)); chunky[offset] |= 1<<(p%8)
        if self.mode & 0x80 and self.palette<64:
            if self.defined_palette < 32:
                raise UndefinedCase('default EHB backing has uninitialized base colors')
            self.palette = 64; self.defined_palette = max(64,self.defined_palette)
        elif self.mode & 0x800 and self.bits>self.planes:
            reduction = self.bits-self.planes+2
            if reduction>255 or self.bits<reduction:
                raise CheckedFailure('integer overflow')
            self.bits -= reduction
            if self.bits<4: raise CheckedFailure('reached unreachable code')
            self.palette >>= self.bits&63
        if rgb:
            if self.bits>8: raise CheckedFailure('integer overflow')
            for row in range(self.h):
                for col in range(self.w):
                    index = (self.w*row+col)*pixel_size; self.index(index,len(chunky))
                    if self.planes == 24:
                        self.index(index+1,len(chunky)); self.index(index+2,len(chunky))
                    elif chunky[index] >= self.palette:
                        if not self.mode&0x800: raise CheckedFailure('reached unreachable code')
                        if self.palette&255 == 0: raise CheckedFailure('division by zero')


def classify(data, *, op, tag, fmt, w, h, planes, bits, pitch, mode, palette, comp, start, length):
    model = Model(data,op,tag,fmt,w,h,planes,bits,pitch,mode,palette,comp,start)
    try:
        if op == 0: model.pixel(length)
        elif op == 1: model.chunks()
        else: model.read()
    except CheckedFailure as error:
        return str(error)
    except ReturningError:
        pass
    return None


def chunk(name,data=b'',length=None):
    return name+struct.pack('>I',len(data) if length is None else length)+data


def form(data,w,h,planes,comp=0,fmt=0,mask=3):
    header = struct.pack('>HHhhBBBBHBBHH',w,h,-7,-9,planes,mask,comp,19,513,23,29,31,37)
    return b'FORM\xff\xff\xff\xff'+(b'ILBM',b'PBM ',b'ACBM')[fmt]+chunk(b'BMHD',header)+data


def raw_pixels(values,w,h,planes,pitch,vertical=False,fmt=0):
    raw = bytearray(pitch*h*planes)
    if fmt == 1:
        # PBM skips conversion and copies the allocated chunky extent.
        raw[:min(len(raw),len(values))] = bytes(values[:len(raw)])
        return bytes(raw)
    channels = 3 if planes==24 else 1
    for row in range(h):
        for plane in range(planes):
            base = plane*pitch*h+row*pitch if vertical else row*pitch*planes+plane*pitch
            for col in range(w):
                shift = plane%8
                channel = plane//8
                value = values[(row*w+col)*channels+channel] if channel<channels else 0
                if value & (1<<shift): raw[base+col//8] |= 1<<(7-col%8)
    return bytes(raw)


def compress(raw,comp,pitch,h,planes,fmt=0):
    if comp==1 and fmt!=2:
        return b''.join(bytes((len(raw[i:i+128])-1,))+raw[i:i+128] for i in range(0,len(raw),128)) if raw else b'\x80'
    if comp==2:
        chunks=[]
        for plane in range(planes):
            words=b''.join(raw[plane*pitch*h+y*pitch+x:plane*pitch*h+y*pitch+x+2] for x in range(0,pitch,2) for y in range(h))
            count=len(words)//2
            commands=bytes(((-count)&255,)) if 1<=count<=128 else b'\x00'
            payload=words if 1<=count<=128 else struct.pack('>H',count)+words
            chunks.append(chunk(b'VDAT',struct.pack('>H',len(commands)+2)+commands+payload,0xffffffff))
        return b''.join(chunks)
    return raw


def corpus():
    rows,traps,counts,excluded=[],[],Counter(),Counter()
    def add(group,data=b'',*,op=0,tag=0,fmt=0,w=1,h=1,planes=8,bits=4,pitch=2,mode=0,palette=4,comp=0,start=0,length=0,kind=37):
        data=b'x'*start+data
        try: message=classify(data,op=op,tag=tag,fmt=fmt,w=w,h=h,planes=planes,bits=bits,pitch=pitch,mode=mode,palette=palette,comp=comp,start=start,length=length)
        except UndefinedCase as error:
            excluded[str(error)]+=1; return
        name=f'{group}-{counts[group]}'; counts[group]+=1
        line='|'.join(map(str,(op,tag,fmt,w,h,planes,bits,pitch,mode,palette,length,start,data.hex(),comp,kind)))
        (traps if message else rows).append((group,name,line,message))
    for planes in (6,8):
        for bits in range(planes+1):
            for palette in (1,4,16,64,256):
                for value in range(1<<planes):
                    add('ham-index-domain',raw_pixels([value],1,1,planes,2),planes=planes,bits=bits,palette=palette,mode=0x800)
    for bits in range(256):
        add('rgb-pad-domain',planes=24,bits=bits,w=0,h=0,palette=0)
    for planes in (0,1,2,5,6,8,11,16,24,255):
        for bits in (0,1,3,4,5,6,7,8,9,16,24,25,63,64,65,255):
            for palette in (0,1,16,64,256):
                for mode in (0x800,0x880):
                    add('ham-reduction-order',bytes(planes*2),planes=planes,bits=bits,palette=palette,mode=mode)
    for planes,bits in ((6,4),(8,6)):
        for palette in (1,4,16,64,256):
            for seed in range(32):
                control=1<<bits; limit=control-1
                values=[1,control|(seed&limit),2*control|((seed*3)&limit),3*control|((seed*5)&limit),control|((seed*7)&limit),1,2*control|((seed*11)&limit),3*control|((seed*13)&limit)]
                for fmt in (0,2):
                    add('ham-row-reset',raw_pixels(values,4,2,planes,2,vertical=fmt==2),w=4,h=2,planes=planes,bits=bits,palette=palette,mode=0x800,fmt=fmt)
    for fmt in range(5):
        for comp in range(3):
            for mode in (0,0x80,0x800,0x880,0xffffffff):
                for planes in (0,1,6,8,9,16,24,32):
                    values=[1,2,3,4,5,6] if planes==24 else [1,2]
                    raw=raw_pixels(values,2,1,planes,2,vertical=fmt!=0 or comp==2,fmt=fmt)
                    data=compress(raw,comp,2,1,planes,fmt)
                    add('direct-dispatch',data,fmt=fmt,comp=comp,w=2,planes=planes,mode=mode,palette=32,length=len(data))
    for palette in (0,1,4,16,32,63,64,65,256):
        for mode in (0,0x80,0x800,0x880):
            for value in (0,1,15,31,32,63,64,255):
                add('ehb-ham-priority',raw_pixels([value],1,1,8,2),palette=palette,mode=mode,bits=8)
    for planes in (1,6,8,24):
        for fmt in range(3):
            for comp in range(3):
                for w,h in ((1,1),(4,2),(16,1),(17,2)):
                    pitch=((w+15)//16)*2
                    channels=3 if planes==24 else 1
                    values=[(i*37+19)&((1<<min(8,planes))-1) for i in range(w*h*channels)]
                    raw=raw_pixels(values,w,h,planes,pitch,vertical=fmt!=0 or comp==2,fmt=fmt)
                    data=compress(raw,comp,pitch,h,planes,fmt)
                    cmap=chunk(b'CMAP',bytes((i*37+19)&255 for i in range(96)))
                    body=chunk(b'ABIT' if fmt==2 else b'BODY',data,len(data) if comp==1 else 0xffffffff)
                    for op in (1,2,3):
                        packet=cmap+body if op==1 else form(cmap+body,w,h,planes,comp,fmt)
                        add('public-decode',packet,op=op,fmt=fmt,comp=comp,w=w,h=h,planes=planes,pitch=pitch,length=len(data))
                    for cut in sorted({0,1,len(data)//2,max(0,len(data)-1),len(data)}):
                        add('body-prefix',data[:cut],fmt=fmt,comp=comp,w=w,h=h,planes=planes,pitch=pitch,length=len(data))
    for op in (0,1):
        for tag in (0,1):
            for mode in (0,0x800):
                for planes in (1,9,24,255):
                    for pitch in (0,2):
                        data=b'bad' if op==0 else chunk(b'BODY',b'bad',0)
                        add('failure-precedence',data,op=op,tag=tag,mode=mode,planes=planes,pitch=pitch)
    for planes in (6,8,24):
        for palette in (16,32,64,256):
            for mode in (0x80,0x800,0x880):
                for fmt in (0,2):
                    for comp in (0,1,2):
                        bits=(palette-1).bit_length(); control=1<<(bits&7)
                        values=[1,control+3,2*control+5,3*control+7,control+11,1,2*control+13,3*control+15]
                        if planes==24: values=[(i*37+19)&255 for i in range(24)]
                        values=[value&((1<<min(8,planes))-1) for value in values]
                        raw=raw_pixels(values,4,2,planes,2,vertical=fmt==2 or comp==2)
                        data=compress(raw,comp,2,2,planes,fmt)
                        packet=chunk(b'CMAP',bytes((i*37+19)&255 for i in range(palette*3)))+chunk(b'CAMG',struct.pack('>I',mode),0)+chunk(b'BODY',data,len(data) if comp==1 else 0)
                        for op in (1,2,3):
                            add('public-ham-ehb',packet if op==1 else form(packet,4,2,planes,comp,fmt),op=op,fmt=fmt,comp=comp,w=4,h=2,planes=planes)
    for kind in (0,0xffffffff,int.from_bytes(b'BODY','big'),int.from_bytes(b'ABIT','big')):
        for length in (0,1,2,16,0xffffffff):
            add('raw-chunk-controls',bytes(16),planes=8,kind=kind,length=length)
    for command in (0,1,127,128,129,255):
        for length in (0,1,2,3,4,129,130):
            for data in (b'',bytes((command,)),bytes((command,19)),bytes((command,19,37))):
                add('packbits-boundary',data,planes=1,comp=1,length=length)
    # Full initialization and exact bounds order for compressed overrun paths.
    for comp in (1,2):
        for data in ((b'\x02\x12\x34\x56',b'\xfd\x12') if comp==1 else (chunk(b'VDAT',b'\x00\x03\xff\x12\x34',0),chunk(b'VDAT',b'\x00\x01',0))):
            for pitch in (1,2):
                for op in (0,1,2,3):
                    packet=data if op==0 else chunk(b'BODY',data,len(data))
                    if op>=2: packet=form(packet,1,1,1,comp)
                    add('compressed-failure',packet,op=op,planes=1,comp=comp,pitch=pitch,length=len(data))
    for name in (b'JUNK',b'BMHD',b'CAMG',b'CMAP'):
        for length in (0,1,2,3,4,7,8,9,12,771,0xffffffff):
            for trailing in (b'',b'x',b'xy',b'abcdefgh'):
                packet=chunk(name,b'\x00\x00\x08\x00'+trailing,length)
                for op in (1,2,3):
                    add('chunk-controls',packet if op==1 else form(packet,1,1,8),op=op)
    raw=bytes(16); body=chunk(b'BODY',raw,0)
    for prefix in (b'',chunk(b'JUNK',b'X',1),chunk(b'JUNK',b'X\x00',1),chunk(b'CAMG',b'\x00\x00\x08\x00',0),chunk(b'CMAP',bytes(12),13),chunk(b'CMAP',bytes(12)+b'X',13),chunk(b'CMAP',bytes(12))+chunk(b'CMAP',bytes(3))):
        for op in (1,2,3):
            packet=prefix+body
            if op>=2: packet=form(packet,1,1,8)
            for cut in sorted({0,7,8,len(packet)-1,len(packet)}):
                add('chunk-prefix-order',packet[:cut],op=op,planes=8)
    for op in range(4):
        for mode in (0,0x800):
            for cut in (0,1,8,15,16):
                packet=raw[:cut] if op==0 else chunk(b'CAMG',struct.pack('>I',mode))+chunk(b'CMAP',bytes(12))+chunk(b'BODY',raw[:cut],0)
                if op>=2: packet=form(packet,1,1,8)
                add('initial-cursor',packet,op=op,mode=mode,planes=8,start=3)
    # Make the undefined private-buffer boundary explicit and excluded.
    add('undefined-packbits',b'\x80',planes=8,comp=1,length=1)
    add('undefined-default-ehb',form(chunk(b'CAMG',b'\x00\x00\x00\x80')+body,1,1,8),op=3)
    return rows,traps,excluded

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source',type=Path); parser.add_argument('zig',type=Path); parser.add_argument('v',type=Path)
    parser.add_argument('--target',default='aarch64-macos.14.0'); parser.add_argument('--v-prod',action='store_true')
    parser.add_argument('--workdir',type=Path); parser.add_argument('--timeout',type=int,default=180)
    args = parser.parse_args()
    if args.timeout <= 0: parser.error('--timeout must be positive')
    source = args.source.resolve()/'src'; zig = args.zig.resolve(); v = args.v.resolve()
    if tree_hash(source)!=PINNED_SOURCE_SHA256 or stdlib_hash(zig)!=PINNED_STDLIB_SHA256 or hashlib.sha256((zig.parent/'lib/std/math.zig').read_bytes()).hexdigest()!=MATH_SHA256:
        parser.error('Source or selected library differs from pins')
    repo = Path(__file__).resolve().parent.parent; probe = repo/'zigimg/reference_probes/iff_pixels'
    mode = 'ReleaseSafe' if args.v_prod else 'Debug'; env = dict(os.environ,VEXE=str(v),V_C_ERROR_BUG_REPORT_DISABLED='1')
    with work_directory(args.workdir,'witty-iff-pixels-') as root:
        proof = ProofLog(root); shutil.copytree(source,root/'src'); fixtures = {}
        for name in ('main.v','reference.zig'):
            shutil.copyfile(probe/name,root/name); fixtures[name] = hashlib.sha256((root/name).read_bytes()).hexdigest()
        versions = [proof.run([str(exe),'version'],label,env=env).stdout.decode().strip() for exe,label in ((zig,'zig-version'),(v,'v-version'))]
        if versions[0]!='0.15.2' or not re.match(r'^V 0\.5\.2(?: |$)',versions[1]): raise AssertionError('unexpected compiler versions')
        implementations = implementation_hashes(repo); runner_hash = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
        (root/'provenance.json').write_text(json.dumps(dict(source_sha256=PINNED_SOURCE_SHA256,stdlib_sha256=PINNED_STDLIB_SHA256,
            math_sha256=MATH_SHA256,
            versions=versions,target=args.target,zig_mode=mode,v_prod=args.v_prod,fixtures=fixtures,
            implementation_sha256=implementations,runner_sha256=runner_hash),indent=2)+'\n')
        zbase = [str(zig),'build-exe','-target',args.target,'-lc','-O',mode,'--global-cache-dir',str(root/'zig-global')]
        vbase = [str(v),'-enable-globals',*(['-prod'] if args.v_prod else []),'-path',f'{repo}|@vlib|@vmodules']
        print(f'Building IFF pixels: Source {mode}, V {"production" if args.v_prod else "ordinary"}',flush=True)
        proof.run(zbase+['-femit-bin='+str(root/'native'),str(root/'reference.zig')],'build-source',timeout=args.timeout)
        proof.run(vbase+['-o',str(root/'translated'),str(root/'main.v')],'build-v',env=env,timeout=args.timeout)
        rows, traps, excluded = corpus(); inputs = {}
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
        if tree_hash(source)!=PINNED_SOURCE_SHA256 or tree_hash(root/'src')!=PINNED_SOURCE_SHA256 or stdlib_hash(zig)!=PINNED_STDLIB_SHA256 or hashlib.sha256((zig.parent/'lib/std/math.zig').read_bytes()).hexdigest()!=MATH_SHA256 or implementation_hashes(repo)!=implementations or hashlib.sha256(Path(__file__).read_bytes()).hexdigest()!=runner_hash:
            raise AssertionError('dependency, implementation or runner changed')
        for name,expected in fixtures.items():
            if any(hashlib.sha256((base/name).read_bytes()).hexdigest()!=expected for base in (root,probe)): raise AssertionError('fixture changed')
        summary = dict(returning_records=len(rows),return_groups=dict(return_groups),return_sha256=returns.hexdigest(),paired_traps=len(traps),failure_groups=dict(trap_groups),state_sha256=states.hexdigest(),excluded_undefined=dict(excluded))
        (root/'summary.json').write_text(json.dumps(summary,indent=2)+'\n'); print(json.dumps(summary,indent=2),flush=True)
        if len(rows)!=EXPECTED_RETURNS or len(traps)!=EXPECTED_TRAPS or returns.hexdigest()!=EXPECTED_RETURN_SHA256 or states.hexdigest()!=EXPECTED_STATE_SHA256 or dict(excluded)!=EXPECTED_UNDEFINED:
            raise AssertionError('locked IFF pixels golden changed')


if __name__ == '__main__':
    main()
