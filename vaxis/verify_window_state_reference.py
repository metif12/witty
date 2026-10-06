"""Compare unchanged public Window scroll and mouse hit-testing behavior."""
import argparse
import hashlib
import itertools
import os
from pathlib import Path
import random
import resource
import shutil
import subprocess
import sys
import tempfile

PROBE = Path(__file__).resolve().parent / 'reference_probes/window_state'
sys.path.insert(0, str(PROBE.parent / 'widgets_classic'))
from source_build import VAXIS_SHA256, UUCODE_PACKAGE, module, prepare_uucode, tree_hash
sys.path.insert(0, str(PROBE.parents[1]))
from verify_vxfw_surface_reference import checked_trap


def scroll(sw, sh, length, width, height, x, y, px, py, count):
    return '|'.join(map(str, ('S', sw, sh, length, width, height, x, y, px, py, count)))


def mouse(width, height, x, y, col=0, row=0, present=1, button=0, kind=0, dx=0, dy=0):
    return '|'.join(map(str, ('M', 0, 0, 0, width, height, x, y, 65535, -65536,
                              present, col, row, dx, dy, button, kind)))


def returning_scroll(sw, sh, length, width, height, x, y, px, py, count):
    if count > height:
        return True
    for row in range(max(y, 0), height-count):
        values = (row*sw, row*sw+max(x,0), row*sw+max(x,0)+width,
                  row+count, (row+count)*sw, (row+count)*sw+max(x,0),
                  (row+count)*sw+max(x,0)+width)
        if max(values) > 65535 or values[2] > length or values[6] > length:
            return False
        if width and count*sw < width:
            return False  # Isolated @memcpy alias observations, not returning cases.
    offset = height-count
    if not -65536 <= y+offset <= 65535 or not -65536 <= py+offset <= 65535:
        return False
    if not -65536 <= x+width <= 65535:
        return False
    if x+width < 0:
        return True
    return -65536 <= y+height <= 65535


def corpus():
    rows = []
    for sw, sh, width, height, x, y, px, py, count in itertools.product(
            range(5), range(5), range(6), range(5), (-2,0,1), (-2,0,1), (0,-2), (0,-2), range(6)):
        values = (sw,sh,sw*sh,width,height,x,y,px,py,count)
        if returning_scroll(*values):
            rows.append(scroll(*values))
    rng = random.Random(0x5343524F4C4C)
    dims = (0,1,2,255,256,32768,65535)
    offsets = (-65536,-32768,-1,0,1,32768,65535)
    for _ in range(2048):
        values = (rng.choice(dims),rng.choice(dims),rng.randrange(17),
                  rng.choice(dims),rng.choice(dims),rng.choice(offsets),rng.choice(offsets),
                  rng.choice(offsets),rng.choice(offsets),rng.choice(dims))
        if returning_scroll(*values):
            rows.append(scroll(*values))
    for sw, sh, count in ((255,255,1),(256,255,1),(257,255,1),(65535,1,1)):
        rows.append(scroll(sw,sh,sw*sh,sw,sh,0,0,0,0,count))
    for width, height, x, y, col, row, present in itertools.product(
            range(5),range(5),(-3,-1,0,1,3),(-3,-1,0,1,3),range(6),range(6),(0,1)):
        index = len(rows)
        rows.append(mouse(width,height,x,y,col,row,present,
                          (0,1,2,3,64,65,66,67,128,129,130,131)[index%12],index%4,index%65536,65535-index%65536))
    for _ in range(2048):
        width,height = rng.choice(dims),rng.choice(dims)
        x,y = rng.choice(offsets),rng.choice(offsets)
        col,row = rng.choice(dims),rng.choice(dims)
        present = rng.randrange(2)
        if present and col >= x:
            if not -65536 <= x+width <= 65535:
                continue
            if col < x+width and row >= y and not -65536 <= y+height <= 65535:
                continue
        rows.append(mouse(width,height,x,y,col,row,present))
    rows.extend((mouse(1,1,65535,65535,present=0),mouse(1,1,65535,65535,col=0),
                 mouse(1,1,0,65535,row=0),mouse(1,1,0,65535,col=1)))
    return rows


TRAPS = {
    'dst_product': (scroll(256,0,0,0,300,0,256,0,0,1), 'integer overflow'),
    'dst_start': (scroll(65535,0,0,0,3,1,1,0,0,1), 'integer overflow'),
    'dst_end': (scroll(65535,0,0,1,3,0,1,0,0,1), 'integer overflow'),
    'src_product': (scroll(65535,0,0,0,3,0,1,0,0,1), 'integer overflow'),
    'src_start': (scroll(65535,0,0,0,2,1,0,0,0,1), 'integer overflow'),
    'src_end': (scroll(65535,0,0,1,2,0,0,0,0,1), 'integer overflow'),
    'dst_slice': (scroll(2,3,0,1,3,0,0,0,0,1), 'slice'),
    'src_slice': (scroll(2,3,1,1,3,0,0,0,0,1), 'slice'),
    'child_y': (scroll(0,0,0,0,1,0,65535,0,0,0), 'integer overflow'),
    'child_parent_y': (scroll(0,0,0,0,1,0,1,0,65535,0), 'integer overflow'),
    'clear_x': (scroll(0,0,0,1,0,65535,0,0,0,0), 'integer overflow'),
    'clear_y': (scroll(0,0,0,0,1,0,65535,0,0,1), 'integer overflow'),
    'same_copy': (scroll(2,3,6,2,3,0,0,0,0,0), '@memcpy arguments alias'),
    'overlapping_copy': (scroll(2,3,8,3,3,0,0,0,0,1), '@memcpy arguments alias'),
    'mouse_x': (mouse(1,0,65535,0,col=65535), 'integer overflow'),
    'mouse_y': (mouse(1,1,0,65535,row=65535), 'integer overflow'),
}


def verify(args, root):
    source = args.source.resolve() / 'src'
    if tree_hash(source) != VAXIS_SHA256:
        raise ValueError('pinned Vaxis source changed')
    shutil.copytree(source, root/'src')
    env = dict(os.environ, VEXE=str(args.v.resolve()), V_C_ERROR_BUG_REPORT_DISABLED='1')
    graph = prepare_uucode(args.zig.resolve(), root, args.uucode.resolve())
    mode = 'ReleaseSafe' if args.v_prod else 'Debug'
    native = [str(args.zig.resolve()), 'build-exe','-O',mode,'-target','aarch64-macos.14.0','-lc',
              *module('root',PROBE/'reference.zig',['vaxis']), *module('vaxis',root/'src/main.zig',['uucode']),
              *graph,f'-femit-bin={root/"native"}']
    translated = [str(args.v.resolve()), *(['-prod'] if args.v_prod else []),'-path',
                  str(PROBE.parents[2])+'|@vlib|@vmodules','-o',str(root/'translated'),str(PROBE/'main.v')]
    for name, command in (('native',native),('translated',translated)):
        print('Building '+name+' '+mode, file=sys.stderr,flush=True)
        subprocess.run(command,env=env,check=True)
    rows = corpus()
    path = root/'cases.txt'
    path.write_text('\n'.join(rows)+'\n')
    outputs = []
    for name in ('native','translated'):
        print(f'Running {name}: {len(rows)} rows',file=sys.stderr,flush=True)
        result = subprocess.run([str(root/name),str(path)],env=env,capture_output=True,timeout=120)
        (root/(name+'.stdout')).write_bytes(result.stdout)
        (root/(name+'.stderr')).write_bytes(result.stderr)
        if result.returncode or result.stderr:
            raise AssertionError(f'{name} failed at {len(result.stdout.splitlines())}: '+result.stderr.decode(errors='replace'))
        values = result.stdout.splitlines()
        if len(values) != len(rows):
            raise AssertionError(f'{name} returned {len(values)} of {len(rows)}')
        outputs.append(values)
    for i,(case,expected,actual) in enumerate(zip(rows,*outputs)):
        if expected != actual:
            raise AssertionError(f'row {i} ({case}): Source={expected!r}; V={actual!r}')
    for label,(case,category) in TRAPS.items():
        path = root/(label+'.txt'); path.write_text(case+'\n')
        for name in ('native','translated'):
            result = subprocess.run([str(root/name),str(path)],env=env,capture_output=True,timeout=15)
            (root/(name+'-'+label+'.stderr')).write_bytes(result.stderr)
            expected = ('index out of bounds' if name=='translated' else 'index out of bounds') if category=='slice' else category
            checked_trap(result,label,expected,name)
    print(f'Window state: {len(rows)} records, {len(TRAPS)} strict trap pairs; SHA256 '+hashlib.sha256(b'\n'.join(outputs[0])).hexdigest())


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('source','zig','v'):
        parser.add_argument(name,type=Path)
    parser.add_argument('--uucode',type=Path,default=Path.home()/'.cache/zig/p'/UUCODE_PACKAGE)
    parser.add_argument('--v-prod',action='store_true')
    parser.add_argument('--workdir',type=Path)
    args = parser.parse_args()
    resource.setrlimit(resource.RLIMIT_CORE,(0,0))
    if args.workdir:
        root = args.workdir.resolve();root.mkdir();verify(args,root)
    else:
        with tempfile.TemporaryDirectory(prefix='witty-window-state-') as directory:
            verify(args,Path(directory))


if __name__ == '__main__':
    main()
