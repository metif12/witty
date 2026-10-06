"""Compare ListView public methods and callback/state ordering with locked source."""
import argparse
import hashlib
import itertools
import os
from pathlib import Path
import random
import re
import resource
import shutil
import subprocess
import sys
import tempfile
import time
PROBE = Path(__file__).resolve().parent / 'reference_probes/vxfw_list_view'
sys.path.insert(0, str(PROBE.parent / 'widgets_classic'))
from source_build import VAXIS_SHA256, UUCODE_PACKAGE, module, prepare_uucode, tree_hash
sys.path.insert(0, str(PROBE.parents[1]))
from verify_vxfw_surface_reference import checked_trap
from verify_unicode_gwidth_reference import ordinary_rejection


def row(mode='D', kind=1, heights=(1, 2, 1), width=-1, holes=0, cursor=0, count=-1,
        top=0, offset=0, pending=0, more=1, want=0, draw=1, wheel=3, action=0,
        vw=6, vh=4, fail=-1, mutation=0):
    return '|'.join(map(str, (mode, kind, ','.join(map(str, heights)), width, holes,
                             cursor, count, top, offset, pending, more, want, draw,
                             wheel, action, vw, vh, fail, mutation)))


def corpus():
    rows = []
    rng = random.Random(0x4c49535456494557)
    for kind, n, action, cursor, count in itertools.product(range(2), range(1, 7), range(14), (0, 1, 5), (-1, 0, 1, 5)):
        if action in (1, 6, 9, 11) and cursor > 0 and count == 0:
            continue
        rows.append(row('E', kind, (1,)*n, cursor=cursor, count=count, action=action,
                        top=rng.randrange(4), offset=rng.randrange(3), pending=rng.randrange(-3, 4),
                        more=rng.randrange(2), want=rng.randrange(2), wheel=rng.choice((0, 1, 3, 255))))
    for action in (0, 1, 2, 3, 4, 7, 13):
        for kind in range(2):
            if action == 0:
                continue
            rows.append(row('E', kind, (), action=action, count=-1))
    for action, pending, wheel, more in itertools.product((3, 4), (-65536, -65535, 0, 65534, 65535), (0, 1), range(2)):
        if (action == 3 and pending-wheel < -65536 or action == 4 and pending+wheel > 65535) and more:
            continue
        # Up's early return uses top/offset rather than has_more.
        if action == 3 and pending-wheel < -65536:
            continue
        rows.append(row('E', action=action, pending=pending, wheel=wheel, more=more, top=1))
    for count in (0, 1, 0xffffffff):
        for action in (0, 1, 2):
            if action == 1 and count == 0:
                continue
            rows.append(row('E', cursor=0xffffffff, count=count, action=action))
    for _ in range(3072):
        n = rng.randrange(1, 8)
        heights = tuple(rng.randrange(0, 7) for _ in range(n))
        cursor = rng.randrange(n)
        top = rng.randrange(cursor+1)
        kind = rng.randrange(2); count = rng.choice((-1, 0, n)); offset = rng.randrange(5)
        pending = rng.randrange(-4, 5); more = rng.randrange(2); want = rng.randrange(2)
        draw = rng.randrange(2); action = rng.randrange(2); vw = rng.randrange(2, 10); vh = rng.randrange(0, 9)
        # Source deinitializes and reuses its ArrayList if the cursored child is
        # at least as tall as the viewport while its bottom is already in view.
        # Keep this undefined-memory TODO branch outside returning parity.
        if want and heights[cursor] >= vh: vh = heights[cursor] + 1
        rows.append(row(kind=kind, heights=heights, cursor=cursor,
                        count=count, top=top, offset=offset, pending=pending, more=more, want=want,
                        draw=draw, action=action, vw=vw, vh=vh, fail=rng.choice((-1, -1, -1, rng.randrange(n)))))
    for heights, draw, vw, vh, action in itertools.product(((), (0,), (1,), (3, 1, 1, 2)), range(2), (0, 1, 2, 6), (0, 1, 4), range(2)):
        rows.append(row(kind=0, heights=heights, draw=draw, vw=vw, vh=vh, action=action))
    for holes, fail, mutation in itertools.product((0, 2, 4, 6), (-1, 0, 1), (0, 1, 2)):
        rows.append(row(holes=holes, fail=fail, mutation=mutation))
    rows.extend((row(draw=0, heights=(5,1), cursor=0, want=1, vh=4),
                 row(draw=0, heights=(1,5), cursor=1, want=1, vh=4),
                 row(draw=0, heights=(65535,), offset=65535, vh=65535),
                 row(draw=0, heights=(65535, 65535), offset=65535, vh=65534, cursor=1, want=1),
                 row(draw=0, heights=(1,), cursor=0xffffffff),
                 row('E', heights=(1,1,1), holes=2, cursor=1, action=0),
                 row('E', heights=(1,1,1), holes=2, cursor=2, action=1)))
    return rows


def traps():
    overflow = {
        'wheel_down': row('E', pending=65535, wheel=1, action=4),
        'wheel_up': row('E', pending=-65536, top=1, wheel=1, action=3),
        'next_max': row('E', cursor=0xffffffff, action=0),
        'next_empty_slice': row('E', kind=0, heights=(), action=0),
        'prev_zero_count': row('E', cursor=1, count=0, action=1),
        'prev_empty_slice': row('E', kind=0, heights=(), cursor=1, action=1),
        'draw_sum': row(offset=65535, pending=1, draw=0),
        'draw_negation': row(offset=-65536, draw=0),
        'draw_accumulate': row(heights=(65535,1), cursor=1, want=1, draw=0),
        'insert_width': row(top=1, pending=-1, vw=1),
        'cursor_width': row(heights=(0,), width=65535, vw=2, vh=0),
        'cursor_area': row(heights=(1000,), width=100, vw=2, vh=1),
        'cursor_underflow': row(heights=(1,1,1), top=1, cursor=0, want=1, draw=0, vh=1),
        'bottom_subtract': row(heights=(65535,65535), offset=65535, cursor=1, want=1, draw=0, vh=16),
        'top_add': row(heights=(1,1), pending=1, mutation=3, draw=0, vh=1),
        'insert_empty_last': row(heights=(), top=1, pending=-1, draw=0),
    }
    result = {name: (case, ('integer overflow',)*2) for name, case in overflow.items()}
    result.update({
        'max_width': (row(vw=-1), ('reached unreachable code', 'Assertion failed')),
        'max_height': (row(vh=-1), ('reached unreachable code', 'Assertion failed')),
        'backfill_top': (row(heights=(), top=2, draw=0), ('reached unreachable code', 'Assertion failed')),
        'cursor_bounds': (row(heights=(1,1), cursor=3, want=1, draw=0, vh=1), ('index out of bounds',)*2),
    })
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path); parser.add_argument('zig', type=Path); parser.add_argument('v', type=Path)
    parser.add_argument('--uucode', type=Path, default=Path.home()/'.cache/zig/p'/UUCODE_PACKAGE)
    parser.add_argument('--target', default='aarch64-macos.14.0'); parser.add_argument('--v-prod', action='store_true')
    parser.add_argument('--zig-mode', choices=('Debug','ReleaseSafe')); parser.add_argument('--v-path', help=argparse.SUPPRESS)
    parser.add_argument('--timeout', type=int, default=120)
    args = parser.parse_args()
    if args.timeout <= 0: parser.error('--timeout must be positive')
    mode = args.zig_mode or ('ReleaseSafe' if args.v_prod else 'Debug')
    resource.setrlimit(resource.RLIMIT_CORE,(0,0))
    source = args.source.resolve()/'src'
    if tree_hash(source) != VAXIS_SHA256: parser.error('source differs from recorded pinned tree')
    env = dict(os.environ,VEXE=str(args.v.resolve()),V_C_ERROR_BUG_REPORT_DISABLED='1')
    with tempfile.TemporaryDirectory(prefix='witty-vxfw-list-') as directory:
        root = Path(directory); shutil.copytree(source,root/'src')
        print('Generating locked Unicode tables',file=sys.stderr,flush=True)
        graph = prepare_uucode(args.zig.resolve(),root,args.uucode.resolve(),args.target)
        print('Building unchanged native '+mode,file=sys.stderr,flush=True)
        def native(path, output):
            return [str(args.zig.resolve()), 'build-exe', '-O', mode, '-target', args.target, '-lc',
                    *module('root', path, ['vaxis']), *module('vaxis', root/'src/main.zig', ['uucode']), *graph, output]
        subprocess.run(native(PROBE/'reference.zig', f'-femit-bin={root/"native"}'), env=env, check=True)
        print('Building V'+(' production' if args.v_prod else ' ordinary'),file=sys.stderr,flush=True)
        options = ['-enable-globals']+(['-prod'] if args.v_prod else [])
        subprocess.run([str(args.v.resolve()),*options,'-path',args.v_path or str(PROBE.parents[2])+'|@vlib|@vmodules',
                        '-o',str(root/'translated'),str(PROBE/'main.v')],env=env,check=True)
        cases=corpus(); path=root/'cases.txt';path.write_text('\n'.join(cases)+'\n');outputs=[]
        for executable in ('native','translated'):
            print(f'Running {executable}: {len(cases)} records',file=sys.stderr,flush=True);started=time.monotonic()
            result=subprocess.run([str(root/executable),str(path)],env=env,capture_output=True,timeout=args.timeout)
            if result.returncode or result.stderr: raise AssertionError(f'{executable} failed after {len(result.stdout.splitlines())} rows ({cases[len(result.stdout.splitlines())]}): '+result.stderr.decode(errors='replace'))
            rows=result.stdout.splitlines()
            if len(rows)!=len(cases):raise AssertionError(f'{executable}: {len(rows)} of {len(cases)}')
            outputs.append(rows);print(f'{executable} completed in {time.monotonic()-started:.2f}s',file=sys.stderr,flush=True)
        for i,(case,expected,actual) in enumerate(zip(cases,*outputs)):
            if expected!=actual:raise AssertionError(f'record {i} ({case}): source={expected!r}, V={actual!r}')
        for label,(case,categories) in traps().items():
            path.write_text(case+'\n')
            for executable,category in zip(('native','translated'),categories):
                result=subprocess.run([str(root/executable),str(path)],env=env,capture_output=True,timeout=15)
                checked_trap(result,label,category,executable)
        for label in ('hang_next','hang_prev'):
            for executable in ('native','translated'):
                try:result=subprocess.run([str(root/executable),label],env=env,capture_output=True,timeout=1)
                except subprocess.TimeoutExpired:continue
                raise AssertionError(f'{executable}: {label} inherited loop returned: '+(result.stdout+result.stderr).decode(errors='replace'))
        # Measure the inherited deinit-then-append TODO without claiming parity for
        # undefined Source storage. V uses managed child storage and returns here.
        path.write_text(row(heights=(0,), want=1, draw=0, vh=0)+'\n')
        for executable in ('native', 'translated'):
            try:
                observed = subprocess.run([str(root/executable), str(path)], env=env, capture_output=True, timeout=10)
            except subprocess.TimeoutExpired:
                if executable == 'translated': raise AssertionError('managed storage adaptation hung')
                print(f'Inherited deinitialized-list branch ({mode}): timeout', file=sys.stderr, flush=True)
                continue
            if executable == 'translated':
                if observed.returncode or observed.stderr or len(observed.stdout.splitlines()) != 1:
                    raise AssertionError('managed storage adaptation did not return: '+(observed.stdout+observed.stderr).decode(errors='replace'))
            else:
                headers = re.findall(r'^(?:thread \d+ )?(?:V )?panic:\s*(.*)$', observed.stderr.decode(errors='replace'), re.M)
                outcome = headers[0] if headers else ('returned' if observed.returncode == 0 else f'exit {observed.returncode}')
                print(f'Inherited deinitialized-list branch ({mode}): {outcome}; excluded from parity', file=sys.stderr, flush=True)
        prelude = 'const vaxis=@import("vaxis"); fn build(_: *const anyopaque, _: usize, _: usize) ?vaxis.vxfw.Widget {return null;} '
        vprelude = 'module main\nimport vaxis.vxfw as fw\nfn build(_ voidptr, _ usize, _ usize) ?fw.Widget {return none}\n'
        contracts = [('Builder', 'ListBuilder', [('userdata', 'userdata', '@ptrFromInt(1)', 'unsafe{voidptr(1)}'), ('buildFn', 'build_fn', 'build', 'build')]),
                     ('ListView', 'ListView', [('children', 'children', '.{.slice=&.{}}', 'fw.ListSlice{widgets:[]}')]),
                     ('Slice', 'ListSlice', [('slice', 'widgets', '&.{}', '[]')])]
        omissions = 0
        for ztype, vtype, fields in contracts:
            for missing in [None, *[f[0] for f in fields]]:
                selected = [f for f in fields if f[0] != missing]
                zfields = ','.join(f'.{zname}={zval}' for zname, _, zval, _ in selected)
                vfields = ','.join(f'{vname}:{vval}' for _, vname, _, vval in selected)
                zpath, vpath = root/'contract.zig', root/'contract.v'
                if ztype == 'Slice':
                    zvalue = '.{.slice=&.{}}' if missing is None else '.slice'
                    zpath.write_text(prelude + 'pub fn main() void {const value: vaxis.vxfw.ListView = .{.children='+zvalue+'}; _=value;}\n')
                else:
                    zname = 'vaxis.vxfw.ListView.Builder' if ztype == 'Builder' else 'vaxis.vxfw.ListView'
                    zpath.write_text(prelude + 'pub fn main() void {_ = '+zname+'{'+zfields+'};}\n')
                vpath.write_text(vprelude + 'fn main(){value:=fw.'+vtype+'{'+vfields+'} _=value}\n')
                vmissing = next((f[1] for f in fields if f[0] == missing), None)
                for executable, command, field in [('native', native(zpath, '-fno-emit-bin'), missing),
                        ('translated', [str(args.v.resolve()), '-enable-globals', '-path', args.v_path or str(PROBE.parents[2])+'|@vlib|@vmodules', '-check', str(vpath)], vmissing)]:
                    result = subprocess.run(command, env=env, capture_output=True, timeout=90)
                    if missing is None and result.returncode:
                        raise AssertionError(f'{executable} rejected complete {ztype}: '+(result.stdout+result.stderr).decode(errors='replace'))
                    if missing is not None and not ordinary_rejection(result, field):
                        raise AssertionError(f'{executable} did not ordinarily reject missing {ztype}.{field}: '+(result.stdout+result.stderr).decode(errors='replace'))
                if missing is not None: omissions += 1
        print(f'ListView: {len(cases)} records, {len(traps())} strict traps, 2 isolated loop pairs, 3 complete constructors, {omissions} paired omission rejections; SHA256 '+hashlib.sha256(b'\n'.join(outputs[0])).hexdigest())
if __name__=='__main__':main()
