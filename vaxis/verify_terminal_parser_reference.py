"""Compare unchanged classic Terminal Parser and ANSI public consumers."""
import argparse
import hashlib
import itertools
import os
from pathlib import Path
import resource
import shutil
import subprocess
import sys
import tempfile

REPO = Path(__file__).resolve().parent.parent
PROBE = Path(__file__).resolve().parent / 'reference_probes/terminal/parser'
sys.path.insert(0, str(PROBE.parent.parent / 'widgets_classic'))
from source_build import VAXIS_SHA256, tree_hash

def corpus():
    cases = []
    def parse(data, capacity=-1, pending=-1):
        cases.append(f'P|{data.hex()}|{capacity}|{pending}|{min(len(data)+4, 32)}')
    parse(b'')
    for byte in range(256):
        parse(bytes([byte]))
    for a, b in itertools.product(range(256), repeat=2):
        parse(bytes([a, b]))
    strings = [b'', b'word', b'\x00\x18\x19\x1a\x1f', b'\x1b', b'\x1b\\after', b'\x1bQafter', b'one\x07after', b'\xc2\xa2', b'\xc0\xff', b'\xe2\x82\xac', b'\xf0\x9f\x98\x80']
    sequences = [b'\x1b'+bytes([kind])+text for kind, text in itertools.product([ord(x) for x in 'NOPSX[]^_'], strings)]
    sequences += [b'\x1b[12:3;;? >$!\x00\xffafter', b'\x1b !"#$A', b'abc\x07def\x1b[Aghi', b'\xc2A\xe2\x00\x1b\xf0\xffQx']
    for data in sequences:
        for end in range(len(data)+1):
            parse(data[:end])
    for kind, byte in itertools.product([ord(x) for x in 'PXS^]_['], range(256)):
        parse(b'\x1b'+bytes([kind,byte])+b'\x1b\\\x07A')
    for pending, data in itertools.product(range(256), [b'', b'abc', b'\x00\xffQ']):
        parse(data, pending=pending)
    file_data = sequences + [bytes([byte])+b'AB\x07CD' for byte in range(256)]
    file_data += [b'AB'+bytes([byte])+b'CD\x1b[A' for byte in range(256)]
    file_data += [b'a'*64+b'\xe2\x82\xac\x07'+b'b'*64]
    for data, capacity in itertools.product(file_data, [1,2,3,4,7,16,31,64,128,4096]):
        parse(data, capacity=capacity)
    for data in [b'\x1bAB', b'\x1bA\x1bB', b'\x1b[12m\x1b[34m', b'\x1b]first\x07\x1b]later\x07', b'\x1b_abc\x1b\\\x1b_xyz\x1b\\', b'\x1b !A\x1b#$B']:
        # Each first event's defined storage remains in a preallocated buffer.
        cases.append(f'B|{data.hex()}')
    for params, pm, im, final, capacity in itertools.product([b'',b'1;2:3',b'\x00\xff'],[-1,0,32,63,255],[-1,0,32,63,255],[0,65,109,255],range(23)):
        initial = 'aabb' if capacity >= 2 else ''
        cases.append(f'A|{params.hex()}|{pm}|{im}|{final}|{capacity}|{initial}')
    for final, pm, im in itertools.product(range(256),[-1,63],[-1,32]):
        cases.append(f'A|00ff|{pm}|{im}|{final}|32|')
    params = [b'',b'0',b'00',b'12:34;;5:',b':;',b';:',b'1x;2',b'2:3;4',b'12:::3;;',b'000012;',b'127']
    params += [b'12'+bytes([byte])+b';2' for byte in range(256)]
    operations = ['n,n,n,n,n,n,n', 'h0,n,h1,n,h2,n,h3,n,n', 'h1,h2,h4,n,n,n', 'n,h0,n,h1,n,h7,n']
    for kind, text, index, ops in itertools.product(range(10),params,[0,1,2,5,100],operations):
        cases.append(f'I|{kind}|{text.hex()}|{index}|{ops}')
    limits = [255,65535,32767,4294967295,2147483647,18446744073709551615,9223372036854775807,18446744073709551615,9223372036854775807,65535]
    for kind, limit in enumerate(limits):
        numbers = list(range(128))+[limit-1,limit]
        for number, suffix in itertools.product(numbers,[b'',b';',b':0;;']):
            text=str(number).encode()+suffix
            cases.append(f'I|{kind}|{text.hex()}|0|h1,n,n,n,n')
    return cases

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('zig', type=Path)
    parser.add_argument('v', type=Path)
    parser.add_argument('--target', default='aarch64-macos.14.0')
    parser.add_argument('--v-root', type=Path, default=REPO, help=argparse.SUPPRESS)
    parser.add_argument('--v-prod', action='store_true')
    parser.add_argument('--zig-mode', choices=('Debug','ReleaseSafe'), default='Debug')
    parser.add_argument('--keep', type=Path, help=argparse.SUPPRESS)
    args = parser.parse_args()
    resource.setrlimit(resource.RLIMIT_CORE,(0,0))
    source = args.source.resolve() / 'src'
    if tree_hash(source) != VAXIS_SHA256:
        parser.error('vaxis src differs from recorded local source')
    cases = corpus()
    with tempfile.TemporaryDirectory(prefix='witty-terminal-parser-') as directory:
        root = Path(directory)
        shutil.copytree(source, root/'src')
        shutil.copyfile(PROBE/'reference.zig', root/'src/parser_probe.zig')
        native = [str(args.zig.resolve()),'build-exe','-target',args.target,'-lc','-O',args.zig_mode]
        subprocess.run([*native,str(root/'src/parser_probe.zig'),f'-femit-bin={root / "native"}'],check=True)
        environment = dict(os.environ,VEXE=str(args.v.resolve()),V_C_ERROR_BUG_REPORT_DISABLED='1')
        options = ['-prod'] if args.v_prod else []
        v_command = [str(args.v.resolve()),*options,'-path',f'{args.v_root.resolve()}|{REPO}|@vlib|@vmodules']
        subprocess.run([*v_command,'-o',str(root/'translated'),str(PROBE/'main.v')],env=environment,check=True)
        path = root/'corpus.txt'
        path.write_text('\n'.join(cases)+'\n')
        outputs = []
        for executable in ('native','translated'):
            result = subprocess.run([str(root/executable),str(path),str(root/'data.bin')],capture_output=True,timeout=240)
            if result.returncode:
                raise AssertionError(f'{executable} corpus failed: {result.stderr.decode(errors="replace")}')
            outputs.append(result.stdout.splitlines())
        if any(len(output) != len(cases) for output in outputs):
            raise AssertionError([len(cases)]+[len(x) for x in outputs])
        for index,(case,expected,actual) in enumerate(zip(cases,*outputs)):
            if expected != actual:
                if args.keep: shutil.copytree(root,args.keep,dirs_exist_ok=True)
                raise AssertionError(f'row {index} ({case}): native={expected!r}, V={actual!r}')
        for kind in range(16):
            for executable in ('native','translated'):
                result = subprocess.run([str(root/executable),f'trap{kind}'],capture_output=True,timeout=10)
                text = result.stdout+result.stderr
                if result.returncode==0 or b'UNEXPECTED' in text or b'integer overflow' not in text:
                    raise AssertionError(f'{executable} trap {kind} failed: {text.decode(errors="replace")}')
        for stem in ('i8_unsupported','float_unsupported','bool_unsupported','required_final','required_params','required_bytes'):
            shutil.copyfile(PROBE/f'{stem}.zig',root/'src'/f'{stem}.zig')
            result=subprocess.run([*native,str(root/'src'/f'{stem}.zig'),'-fno-emit-bin'],capture_output=True)
            text=(result.stdout+result.stderr).decode(errors='replace')
            if result.returncode!=1 or 'error:' not in text or 'panic' in text or 'Segmentation' in text:
                raise AssertionError(f'ordinary source rejection {stem} failed: {text}')
            result=subprocess.run([*v_command,'-check',str(PROBE/f'{stem}.v')],env=environment,capture_output=True)
            text=(result.stdout+result.stderr).decode(errors='replace')
            if stem == 'required_bytes':
                # The pinned V compiler drops @required on generic struct fields.
                # Retain an explicit reproducer instead of claiming paired rejection.
                if result.returncode != 0:
                    raise AssertionError(f'pinned generic-field limitation changed: {text}')
            elif result.returncode!=1 or 'error:' not in text or 'C compilation failed' in text or 'V compiler bug' in text:
                raise AssertionError(f'ordinary V rejection {stem} failed: {text}')
        if args.keep: shutil.copytree(root,args.keep,dirs_exist_ok=True)
        print(f'Terminal Parser/ANSI: {len(cases)} returning records, 16 checked traps, 5 paired ordinary compile boundaries, 1 pinned generic required-field limitation, SHA256 '+hashlib.sha256(b'\n'.join(outputs[0])).hexdigest())

if __name__ == '__main__': main()
