"""Compare packed RGB bit streams and retained failures with unchanged Source.

The model only partitions inputs. Compiled pinned Source supplies the oracle.
"""
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
from verify_tiff_decode_reference import ProofLog, tree_hash, work_directory, PINNED_SOURCE_SHA256, checked_trap
from verify_simd_reference import ordinary_rejection
import verify_bitstream_contracts_reference as model

TYPES = (('Rgb332', 8), ('Rgb555', 15), ('Rgb565', 16), ('Bgr555', 15)) * 2
EXPECTED_RETURNS = 273066
EXPECTED_TRAPS = 567
EXPECTED_RETURN_SHA256 = 'd39aa4c766ca640e07beda5a21f1ea596762ea6761fd085d1951eba159eafd98'
EXPECTED_STATE_SHA256 = '4f357b8f6c9d5c4f42e145368dbf10de2ec446c0ed0f44ff9f55b1d585d8c6f5'
SHIFT = 'shift amount is greater than the type size'


def file_digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


class PackedModel(model.Model):
    def shift(self, amount):
        if self.width == 15:
            if amount > 15:
                raise model.CheckedFailure(model.CAST)
            if amount == 15:
                raise model.CheckedFailure(SHIFT)
        elif amount >= self.width:
            raise model.CheckedFailure(model.CAST)

    def read(self, num):
        if num <= self.count:
            return self.remove(num), num
        count = self.count
        value = self.remove(count)
        for _ in range((num - count) // 8):
            try:
                byte = self.take()
            except EOFError:
                return value, count
            if self.big:
                value = ((value << 8) | byte) & self.mask
            else:
                self.shift(count)
                value = (value | (byte << count)) & self.mask
            count += 8
        left = num - count
        if left == 0:
            return value, count
        try:
            byte = self.take()
        except EOFError:
            return value, count
        keep = 8 - left
        if self.big:
            self.shift(left)
            value = ((value << left) | (byte >> keep)) & self.mask
            self.bits = byte & self.byte_mask(keep)
        else:
            self.shift(count)
            value = (value | ((byte & self.byte_mask(left)) << count)) & self.mask
            self.bits = byte >> left
        self.count = keep
        return value, num

    def write(self, num, value):
        value &= self.mask
        count = num
        if self.count > 0:
            if self.count > 8:
                raise model.CheckedFailure(model.OVERFLOW)
            free = 8 - self.count
            if num < free:
                self.add(value & 255, num)
                return
            if num == free:
                self.add(value & 255, num)
                self.flush()
                return
            if self.big:
                self.shift(count - free)
                self.add((value >> (count - free)) & 255, free)
            else:
                self.add(value & 255, free)
                self.shift(free)
                value >>= free
            count -= free
            self.flush()
        for _ in range(count // 8):
            if self.big:
                self.shift(count - 8)
                self.put((value >> (count - 8)) & 255)
            else:
                self.put(value & 255)
                value = 0 if self.width == 8 else value >> 8
            count -= 8
        self.add(value & 255, count)

    def action(self, action):
        if action[0] == 'c':
            copied = PackedModel(int(self.big), self.width, self.kind, self.bits,
                                 self.count, self.capacity, self.data, self.pos)
            try:
                if self.kind:
                    copied.write(*map(int, action[1:].split(':')))
                else:
                    copied.read(int(action[1:]))
            finally:
                self.pos = copied.pos
            return
        return super().action(action)


def corpus():
    rows, traps, groups = [], [], Counter()
    trap_controls = set()

    def add(group, *, endian=0, typ=26, kind=0, bits=0, count=0,
            capacity=4, data=b'\xab\xcd\xef\x01', start=0, actions='r8'):
        width = TYPES[typ - 26][1]
        check = PackedModel(endian, width, kind, bits, count, capacity, data, start)
        message = None
        try:
            for action in actions.split(','):
                try:
                    check.action(action)
                except model.ReturningError:
                    pass
        except model.CheckedFailure as failure:
            message = str(failure)
        if message:
            control = (endian % 2, width, kind, bits, count, capacity, data, start, actions)
            if control in trap_controls:
                return
            trap_controls.add(control)
        name = f'{group}-{groups[group]}'
        groups[group] += 1
        line = '|'.join(map(str, (endian, typ, kind, bits, count, capacity,
                                  data.hex(), start, actions)))
        (traps if message else rows).append((group, name, line, message))

    # Every logical packed value is read and written. Alternate native orders
    # within each dense domain; separate boundary/alias matrices cover both.
    for index, (name, width) in enumerate(TYPES[:4]):
        for value in range(1 << width):
            endian = value % 2
            size = (width + 7) // 8
            data = value.to_bytes(size, 'big' if endian else 'little')
            add('packed-word-domain', endian=endian, typ=26 + index,
                data=data, actions=f'r{size * 8}')
            add('packed-word-domain', endian=endian, typ=26 + index, kind=1,
                actions=f'w{size * 8}:{value},f')
    for endian, typ, byte, operation, num in itertools.product(
            range(4), range(26, 34), (0, 1, 0x55, 0x80, 0xff),
            ('r', 't', 'n', 'c'), (0, 1, 7, 8, 15, 16, 17)):
        add('packed-read-boundaries', endian=endian, typ=typ,
            data=bytes((byte, byte ^ 255)), actions=f'{operation}{num}')
    for endian, typ, count, bits, num in itertools.product(
            (0, 1), range(26, 30), (0, 1, 7, 8, 15), (0, 1, 0x80, 0xff),
            (0, 1, 7, 8, 15, 16, 17)):
        add('packed-buffered-reads', endian=endian, typ=typ, bits=bits, count=count,
            data=b'\xff\xff\xff', actions=f'r{num}')
    for endian, typ, count, num, capacity in itertools.product(
            (0, 1), range(26, 30), (0, 1, 7, 8),
            (0, 1, 7, 8, 9, 15, 16, 17, 22, 23, 24, 25, 31), (0, 1, 4)):
        add('packed-writer-boundaries', endian=endian, typ=typ, kind=1,
            bits=0xab, count=count, capacity=capacity,
            actions=f'w{num}:65535,f,f')
    for endian, typ, length in itertools.product(range(4), range(26, 34), (0, 1, 2, 3)):
        add('packed-continuation', endian=endian, typ=typ, data=b'\xab' * length,
            actions='c1,r1,t1,n1,a,r8')
        add('packed-borrowed-input', endian=endian, typ=typ, data=b'\xab' * length,
            actions='r1,a,m,s0,r8')
        add('packed-writer-copies', endian=endian, typ=typ, kind=1,
            capacity=length, actions='w1:1,c1:1,w7:127,f,w8:255,f')
    rng = random.Random(0xd7b7ab0b)
    for endian, typ in itertools.product(range(4), range(26, 34)):
        width = TYPES[typ - 26][1]
        for _ in range(64):
            value = rng.getrandbits(16)
            add('packed-random-reader', endian=endian, typ=typ,
                data=bytes(rng.getrandbits(8) for _ in range(4)),
                actions=f'r1,c{width - 1},a,t{width},n1')
            add('packed-random-writer', endian=endian, typ=typ, kind=1,
                capacity=6, actions=f'w{width}:{value},c1:1,f,w1:1,f')
    return rows, traps


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source',type=Path);parser.add_argument('zig',type=Path);parser.add_argument('v',type=Path)
    parser.add_argument('--target',default='aarch64-macos.14.0');parser.add_argument('--v-prod',action='store_true')
    parser.add_argument('--workdir',type=Path);parser.add_argument('--timeout',type=int,default=300)
    args=parser.parse_args()
    if args.timeout<=0:parser.error('--timeout must be positive')
    source=args.source.resolve()/'src';zig=args.zig.resolve();v=args.v.resolve()
    if tree_hash(source)!=PINNED_SOURCE_SHA256 or stdlib_hash(zig)!=PINNED_STDLIB_SHA256:parser.error('Source or library differs from pins')
    repo=Path(__file__).resolve().parent.parent;probe=repo/'zigimg/reference_probes/bitstream_contracts'
    mode='ReleaseSafe' if args.v_prod else 'Debug';env=dict(os.environ,VEXE=str(v),V_C_ERROR_BUG_REPORT_DISABLED='1')
    with work_directory(args.workdir,'witty-bitstream-packed-') as root:
        proof=ProofLog(root);tmp=root/'tmp';tmp.mkdir();env.update(TMPDIR=str(tmp),VTMP=str(tmp));shutil.copytree(source,root/'src');fixtures={}
        for name in ('main.v','reference.zig'):
            shutil.copyfile(probe/name,root/name);fixtures[name]=hashlib.sha256((root/name).read_bytes()).hexdigest()
        versions=[proof.run([str(exe),'version'],label,env=env).stdout.decode().strip() for exe,label in ((zig,'zig-version'),(v,'v-version'))]
        if versions[0]!='0.15.2' or not re.match(r'^V 0\.5\.2(?: |$)',versions[1]):raise AssertionError('unexpected compiler versions')
        model_hash=file_digest(Path(model.__file__));implementations=implementation_hashes(repo);runner_hash=hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
        (root/'provenance.json').write_text(json.dumps(dict(source_sha256=PINNED_SOURCE_SHA256,stdlib_sha256=PINNED_STDLIB_SHA256,versions=versions,target=args.target,zig_mode=mode,v_prod=args.v_prod,fixtures=fixtures,model_sha256=model_hash,implementation_sha256=implementations,runner_sha256=runner_hash),indent=2)+'\n')
        zbase=[str(zig),'build-exe','-target',args.target,'-lc','-O',mode,'--global-cache-dir',str(root/'zig-global'),'--cache-dir',str(root/'zig-cache')]
        vbase=[str(v),'-enable-globals',*(['-prod'] if args.v_prod else []),'-path',f'{repo}|@vlib|@vmodules']
        print(f'Building packed color bit streams: Source {mode}, V {"production" if args.v_prod else "ordinary"}',flush=True)
        proof.run(zbase+['-femit-bin='+str(root/'native'),str(root/'reference.zig')],'build-source',timeout=args.timeout)
        proof.run(vbase+['-o',str(root/'translated'),str(root/'main.v')],'build-v',env=env,timeout=args.timeout)
        rows,traps=corpus();inputs={};file=root/'corpus.txt';file.write_text('\n'.join(row for group,name,row,message in rows)+'\n')
        inputs[file.name]=hashlib.sha256(file.read_bytes()).hexdigest();outputs=[]
        for exe in ('native','translated'):
            result=proof.run([str(root/exe),'--corpus',str(file)],'corpus-'+exe,timeout=args.timeout,check=False)
            if result.returncode:raise AssertionError(f'corpus-{exe} failed; see retained diagnostics')
            if result.stderr:raise AssertionError('unexpected corpus stderr')
            outputs.append(result.stdout.splitlines())
        if any(len(output)!=len(rows) for output in outputs):raise AssertionError('corpus counts differ')
        returns=hashlib.sha256();states=hashlib.sha256();return_groups=Counter();trap_groups=Counter();categories=Counter()
        for (group,name,row,message),native,translated in zip(rows,*outputs):
            if native!=translated:raise AssertionError(f'{name}: {native!r} != {translated!r}; input {row}')
            returns.update(name.encode()+b'\0'+native+b'\n');return_groups[group]+=1
        print(f'{len(rows)} returning records match; checking {len(traps)} strict failures',flush=True)
        for group,name,row,message in traps:
            file=root/(name+'.txt');file.write_text(row);inputs[file.name]=hashlib.sha256(file.read_bytes()).hexdigest();records=[]
            for exe in ('native','translated'):
                path=root/(name+'-'+exe+'.state');result=proof.run([str(root/exe),'--case',str(path),row],name+'-'+exe,timeout=args.timeout,check=False)
                checked_trap(result,name+'/'+exe,message)
                messages=[m.group(1) for line in result.stderr.decode().splitlines() if (m:=re.fullmatch(r'(?:thread \d+ |V )?panic:\s*(.*)',line.strip()))]
                if messages!=[message] or not path.exists():raise AssertionError('exact panic or state missing')
                records.append(path.read_bytes())
            if not records[0] or records[0]!=records[1]:raise AssertionError(f'{name}: differing state {records}; input {row}')
            states.update(name.encode()+b'\0'+message.encode()+b'\0'+records[0]+b'\n');trap_groups[group]+=1;categories[message]+=1
        (root/'input_sha256.json').write_text(json.dumps(inputs,indent=2)+'\n')
        consumers={}
        def pair(label,zbody,vbody,zmarker=None,vmarker=None):
            paths=[root/(label+'.zig'),root/(label+'.v')]
            paths[0].write_text('const std=@import("std");const p=@import("src/io.zig");const color=@import("src/color.zig");pub fn main() void {var data:[8]u8=@splat(0);var input=p.ReadStream.initMemory(&data);var output=p.WriteStream.initMemory(&data);_= &input;_= &output;'+zbody+'}\n')
            paths[1].write_text('module main\nimport zigimg as p\ntype AliasBig=p.BigEndian\ntype AliasRgb332=p.Rgb332\ntype AliasRgb555=p.Rgb555\ntype AliasRgb565=p.Rgb565\ntype AliasBgr555=p.Bgr555\nfn main(){\nmut data:=[]u8{len:8}\nmut input:=p.ReadStream.init_memory(data)\nmut output:=p.WriteStream.init_memory(mut data)\n_= &input\n_= &output\n'+vbody+'\n}\n')
            for path in paths:consumers[path.name]=hashlib.sha256(path.read_bytes()).hexdigest()
            for language,command,marker in (('Source',zbase+['-fno-emit-bin',str(paths[0])],zmarker),('V',vbase+['-check','-o',str(root/(label+'-checked')),str(paths[1])],vmarker)):
                result=proof.run(command,label+'-'+language,env=env,timeout=args.timeout,check=False);diagnostic=(result.stdout+result.stderr).decode(errors='replace')
                errors=[line for line in diagnostic.splitlines() if re.search(r'\berror:',line)]
                if marker is None:
                    if result.returncode or errors:raise AssertionError(f'{label}/{language}: expected acceptance\n{diagnostic}')
                else:
                    ordinary_rejection(result,label+'/'+language)
                    if not any(marker in line for line in errors):raise AssertionError(f'{label}/{language}: missing {marker!r}\n{diagnostic}')
        for marker,ztag in (('p.BigEndian','.big'),('p.LittleEndian','.little'),('AliasBig','.big')):
            for name, width in TYPES[:4]:
                for typ in ('p.'+name,'Alias'+name):
                    tag=marker.split('.')[-1]+'-'+typ.split('.')[-1]
                    pair('read-'+tag,'var bits=p.BitReader('+ztag+'){.reader=input.reader()};_=bits.readBitsNoEof(color.'+name+','+str(width)+') catch color.'+name+'{};',
                         'mut bits:=p.BitReader['+marker+']{reader:input.reader()}\n_=bits.read_bits_no_eof['+marker+','+typ+']('+str(width)+') or {'+typ+'{}}')
                    pair('write-'+tag,'var bits=p.BitWriter('+ztag+'){.writer=output.writer()};bits.writeBits(color.'+name+'{},'+str(width)+') catch {};',
                         'mut bits:=p.BitWriter['+marker+']{writer:output.writer()}\nbits.write_bits['+marker+','+typ+']('+typ+'{},'+str(width)+') or {}')
        (root/'consumer_sha256.json').write_text(json.dumps(consumers,indent=2)+'\n')
        for name,digest in {**inputs,**consumers}.items():
            if hashlib.sha256((root/name).read_bytes()).hexdigest()!=digest:raise AssertionError('generated input/consumer changed')
        if tree_hash(source)!=PINNED_SOURCE_SHA256 or tree_hash(root/'src')!=PINNED_SOURCE_SHA256 or stdlib_hash(zig)!=PINNED_STDLIB_SHA256 or implementation_hashes(repo)!=implementations or file_digest(Path(model.__file__))!=model_hash or hashlib.sha256(Path(__file__).read_bytes()).hexdigest()!=runner_hash:raise AssertionError('dependency, implementation or runner changed')
        for name,digest in fixtures.items():
            if any(hashlib.sha256((base/name).read_bytes()).hexdigest()!=digest for base in (root,probe)):raise AssertionError('fixture changed')
        summary=dict(returning_records=len(rows),return_groups=dict(return_groups),return_sha256=returns.hexdigest(),paired_traps=len(traps),failure_groups=dict(trap_groups),panic_categories=dict(categories),state_sha256=states.hexdigest(),accepted_packed_consumer_pairs=48)
        (root/'summary.json').write_text(json.dumps(summary,indent=2)+'\n');print(json.dumps(summary,indent=2),flush=True)
        if (len(rows)!=EXPECTED_RETURNS or len(traps)!=EXPECTED_TRAPS or returns.hexdigest()!=EXPECTED_RETURN_SHA256 or states.hexdigest()!=EXPECTED_STATE_SHA256):raise AssertionError('locked packed color bit-stream golden changed')


if __name__=='__main__':main()
