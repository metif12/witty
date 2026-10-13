"""Compare boolean bit streams and exact retained failures with unchanged Source.

The model only partitions inputs. Compiled pinned Source provides the oracle.
"""
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
from verify_tiff_decode_reference import ProofLog, tree_hash, work_directory, PINNED_SOURCE_SHA256, checked_trap
from verify_simd_reference import ordinary_rejection
import verify_bitstream_contracts_reference as model

EXPECTED_RETURNS = 22849
EXPECTED_TRAPS = 1049
EXPECTED_RETURN_SHA256 = '8621064b96eb5c32c47a381bfb9d81c9807d3bbb670bc296a66d9da69468d838'
EXPECTED_STATE_SHA256 = '96601684c22c4529d17c5181d5a2796a3c118b97778b8f4032302a31f7287413'


def file_digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


class BoolModel(model.Model):
    def read(self, num):
        value, count = super().read(num)
        if value > 1:
            raise model.CheckedFailure(model.CAST)
        return value, count

    def action(self, action):
        if action[0] == 'c':
            copied = BoolModel(int(self.big), self.width, self.kind, self.bits,
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

    def add(group, *, endian=0, typ=24, kind=0, bits=0, count=0,
            capacity=4, data=b'\xab\xcd', start=0, actions='r1'):
        check = BoolModel(endian, 8, kind, bits, count, capacity, data, start)
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
            control = (endian % 2, kind, bits, count, capacity, data, start, actions)
            if control in trap_controls:
                return
            trap_controls.add(control)
        name = f'{group}-{groups[group]}'
        groups[group] += 1
        line = '|'.join(map(str, (endian, typ, kind, bits, count, capacity,
                                  data.hex(), start, actions)))
        (traps if message else rows).append((group, name, line, message))

    for endian, typ, byte, operation, num in itertools.product(
            range(4), (24, 25), range(256), ('r', 't', 'n', 'c'), (0, 1)):
        add('boolean-byte-domain', endian=endian, typ=typ, data=bytes((byte,)),
            actions=f'{operation}{num}')
    for endian, typ, byte, count, num in itertools.product(
            range(4), (24, 25), (0, 1, 0x80, 0xff), range(9), (0, 1)):
        add('buffered-boolean', endian=endian, typ=typ, bits=byte, count=count,
            data=b'', actions=f'r{num},a,t1,n1')
    for endian, num, data, action in itertools.product(
            (0, 1), (2, 3, 7, 8, 9, 15, 16, 17),
            (b'', b'\0', b'\1', b'\x02', b'\x80', b'\xff', b'\xff\0'),
            ('r', 't', 'n', 'c')):
        add('narrow-result-and-shifts', endian=endian, data=data,
            actions=f'{action}{num}')
    for endian, bits, count, num in itertools.product(
            (0, 1), (0, 1, 2, 0x80, 0xff), (1, 2, 7, 8), (0, 1, 2, 7, 8, 9)):
        add('buffered-narrow-result', endian=endian, bits=bits, count=count,
            data=b'', actions=f'r{num}')
    for endian, typ, bits, count, value, capacity, num in itertools.product(
            range(4), (24, 25), (0, 1, 0x80, 0xff), (0, 1, 7, 8),
            (0, 1), (0, 1, 2, 4), (0, 1, 7, 8, 9, 15, 16, 17)):
        add('boolean-writer', endian=endian, typ=typ, kind=1, bits=bits,
            count=count, capacity=capacity, actions=f'w{num}:{value},f,f')
    for endian, typ, data, start in itertools.product(
            range(4), (24, 25), (b'', b'\0', b'\xab\xcd', b'\xff' * 3), (0,)):
        for actions in ('r1,t1,n1,c1,a,r1', 'c1,r1,a,r1', 'r1,a,m,s0,r1',
                        'r1,r1,r1,r1,r1,r1,r1,r1,r1'):
            # Source seeking an empty stream reports a returned error.
            add('boolean-continuation', endian=endian, typ=typ, data=data,
                start=start, actions=actions)
    for endian, typ, value, capacity, start in itertools.product(
            range(4), (24, 25), (0, 1), (1, 2, 4), (0,)):
        for actions in (f'w1:{value},c1:{1-value},w1:{value},f,f',
                        f'w1:{value},f,w1:{1-value},f',
                        ','.join([f'w1:{value}'] * 9) + ',f'):
            add('boolean-writer-continuation', endian=endian, typ=typ, kind=1,
                capacity=capacity, start=start, actions=actions)
    return rows, traps


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source',type=Path);parser.add_argument('zig',type=Path);parser.add_argument('v',type=Path)
    parser.add_argument('--target',default='aarch64-macos.14.0');parser.add_argument('--v-prod',action='store_true')
    parser.add_argument('--workdir',type=Path);parser.add_argument('--timeout',type=int,default=180)
    args=parser.parse_args()
    if args.timeout<=0:parser.error('--timeout must be positive')
    source=args.source.resolve()/'src';zig=args.zig.resolve();v=args.v.resolve()
    if tree_hash(source)!=PINNED_SOURCE_SHA256 or stdlib_hash(zig)!=PINNED_STDLIB_SHA256:parser.error('Source or library differs from pins')
    repo=Path(__file__).resolve().parent.parent;probe=repo/'zigimg/reference_probes/bitstream_contracts'
    mode='ReleaseSafe' if args.v_prod else 'Debug';env=dict(os.environ,VEXE=str(v),V_C_ERROR_BUG_REPORT_DISABLED='1')
    with work_directory(args.workdir,'witty-bitstream-bool-') as root:
        proof=ProofLog(root);tmp=root/'tmp';tmp.mkdir();env.update(TMPDIR=str(tmp),VTMP=str(tmp));shutil.copytree(source,root/'src');fixtures={}
        for name in ('main.v','reference.zig'):
            shutil.copyfile(probe/name,root/name);fixtures[name]=hashlib.sha256((root/name).read_bytes()).hexdigest()
        versions=[proof.run([str(exe),'version'],label,env=env).stdout.decode().strip() for exe,label in ((zig,'zig-version'),(v,'v-version'))]
        if versions[0]!='0.15.2' or not re.match(r'^V 0\.5\.2(?: |$)',versions[1]):raise AssertionError('unexpected compiler versions')
        model_hash=file_digest(Path(model.__file__));implementations=implementation_hashes(repo);runner_hash=hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
        (root/'provenance.json').write_text(json.dumps(dict(source_sha256=PINNED_SOURCE_SHA256,stdlib_sha256=PINNED_STDLIB_SHA256,versions=versions,target=args.target,zig_mode=mode,v_prod=args.v_prod,fixtures=fixtures,model_sha256=model_hash,implementation_sha256=implementations,runner_sha256=runner_hash),indent=2)+'\n')
        zbase=[str(zig),'build-exe','-target',args.target,'-lc','-O',mode,'--global-cache-dir',str(root/'zig-global'),'--cache-dir',str(root/'zig-cache')]
        vbase=[str(v),'-enable-globals',*(['-prod'] if args.v_prod else []),'-path',f'{repo}|@vlib|@vmodules']
        print(f'Building boolean bit streams: Source {mode}, V {"production" if args.v_prod else "ordinary"}',flush=True)
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
            paths[0].write_text('const std=@import("std");const p=@import("src/io.zig");pub fn main() void {var data:[8]u8=@splat(0);var input=p.ReadStream.initMemory(&data);var output=p.WriteStream.initMemory(&data);_= &input;_= &output;'+zbody+'}\n')
            paths[1].write_text('module main\nimport zigimg as p\ntype AliasBig=p.BigEndian\ntype AliasBool=bool\nfn main(){\nmut data:=[]u8{len:8}\nmut input:=p.ReadStream.init_memory(data)\nmut output:=p.WriteStream.init_memory(mut data)\n_= &input\n_= &output\n'+vbody+'\n}\n')
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
            for typ in ('bool','AliasBool'):
                tag=marker.split('.')[-1]+'-'+typ
                pair('read-'+tag,'var bits=p.BitReader('+ztag+'){.reader=input.reader()};_=bits.readBitsNoEof(bool,1) catch false;',
                     'mut bits:=p.BitReader['+marker+']{reader:input.reader()}\n_=bits.read_bits_no_eof['+marker+','+typ+'](1) or {false}')
                pair('write-'+tag,'var bits=p.BitWriter('+ztag+'){.writer=output.writer()};bits.writeBits(true,1) catch {};',
                     'mut bits:=p.BitWriter['+marker+']{writer:output.writer()}\nbits.write_bits['+marker+','+typ+']('+typ+'(true),1) or {}')
        (root/'consumer_sha256.json').write_text(json.dumps(consumers,indent=2)+'\n')
        for name,digest in {**inputs,**consumers}.items():
            if hashlib.sha256((root/name).read_bytes()).hexdigest()!=digest:raise AssertionError('generated input/consumer changed')
        if tree_hash(source)!=PINNED_SOURCE_SHA256 or tree_hash(root/'src')!=PINNED_SOURCE_SHA256 or stdlib_hash(zig)!=PINNED_STDLIB_SHA256 or implementation_hashes(repo)!=implementations or file_digest(Path(model.__file__))!=model_hash or hashlib.sha256(Path(__file__).read_bytes()).hexdigest()!=runner_hash:raise AssertionError('dependency, implementation or runner changed')
        for name,digest in fixtures.items():
            if any(hashlib.sha256((base/name).read_bytes()).hexdigest()!=digest for base in (root,probe)):raise AssertionError('fixture changed')
        summary=dict(returning_records=len(rows),return_groups=dict(return_groups),return_sha256=returns.hexdigest(),paired_traps=len(traps),failure_groups=dict(trap_groups),panic_categories=dict(categories),state_sha256=states.hexdigest(),accepted_boolean_consumer_pairs=12)
        (root/'summary.json').write_text(json.dumps(summary,indent=2)+'\n');print(json.dumps(summary,indent=2),flush=True)
        if (len(rows)!=EXPECTED_RETURNS or len(traps)!=EXPECTED_TRAPS or returns.hexdigest()!=EXPECTED_RETURN_SHA256 or states.hexdigest()!=EXPECTED_STATE_SHA256):raise AssertionError('locked boolean bit-stream golden changed')


if __name__=='__main__':main()
