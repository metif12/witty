"""Compare public Image geometry and Vaxis transmission against pinned source."""
import argparse
from collections import Counter
import hashlib
import itertools
import json
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
from unittest.mock import patch

PROBE = Path(__file__).resolve().parent / 'reference_probes/image'
sys.path.insert(0, str(PROBE.parent / 'widgets_classic'))
from source_build import VAXIS_SHA256, UUCODE_SHA256, UUCODE_PACKAGE, module, prepare_uucode, tree_hash
from verify_vxfw_surface_reference import checked_trap


STDLIB_SHA256 = {
    'math.zig': '65645001357d5f78cbf646485e009a048b828680bb1b47fb3de0fd8617d91af1',
    'base64.zig': 'f506bb85c053a0bda914258c3c295107e9987c48674c2addf57ffecd5dddca8d',
    'Io/Writer.zig': 'f541f60754a1c4835381217e5072ce0eb311393efc38eb180c0adb740dd50543',
}


def check_stdlib(zig):
    root = zig.resolve().parent / 'lib/std'
    for name, expected in STDLIB_SHA256.items():
        if hashlib.sha256((root/name).read_bytes()).hexdigest() != expected:
            raise ValueError('Zig standard library differs: '+name)


ZIGIMG_SHA256 = "ca759a44a902143a60f42f0810dc90df7250c0f92804cf201353f0141650eb6b"
ZIGIMG_PACKAGE_SHA256 = "6a2871b44b8699244584194964a3611cfd184805d1f8266188a1999bbc5188e0"
ZIGIMG_ROOT_SHA256 = "3e847079e41f2ca99ff7f77df1d374e7d05cadbd8c9043f02a850e63e5633812"

EXPECTED_ROWS = 5506
EXPECTED_SHA256 = 'e58eae6f7ede06b34fc86cfab106ec0a8f106162693f3f06ab0ae5bab3c6157e'
EXPECTED_STATE_SHA256 = '89e0105b69174290783306c5ecf88ff4b3ea6fbe07429fe0c5420524a3e77897'


def corpus():
    rows = []
    def add(*values): rows.append('|'.join(map(str, values)))
    dimensions = (0, 1, 2, 3, 80, 32768, 65535)
    rng = random.Random(0x494D414745)
    # Physical storage is one fully initialized cell. Every attempted write is
    # to (0,0); manually changing public geometry never reads missing cells.
    for sw, sh, pixels, scale, seed in itertools.product(dimensions, dimensions,
            ((0,0),(1,1),(7,17),(65535,65535)), range(4), range(4)):
        add('G', sw, sh, *pixels, sw, sh, rng.choice(dimensions),
            rng.choice(dimensions), scale, seed)
    for scale in range(4):
        add('G',1,1,65535,65535,65535,32768,65535,65535,scale,1)
    for _ in range(2048):
        add('G', rng.choice(dimensions), rng.choice(dimensions),
            rng.randrange(65536), rng.randrange(65536), rng.choice(dimensions),
            rng.choice(dimensions), rng.randrange(65536), rng.randrange(65536),
            rng.randrange(4), rng.randrange(65536))
    for op, cap, image_id, format in itertools.product(('L','T'),range(2),
            (0,1,0xfffffffe),range(3)):
        lengths = (0,1,2,3,3070,3071,3072,4095) if op=='L' else (0,1,4095,4096,4097,8192,8193)
        for length in lengths:
            payload=bytes((i*73+length)%256 for i in range(length))
            add(op,cap,image_id,0,65535,image_id%3,format,payload.hex())
    for op, fmt in itertools.product(('L','T'),range(3)):
        add(op,0,0xffffffff,65535,0,2,fmt,bytes(range(256)).hex())
    for medium, fmt in itertools.product(range(3),range(3)):
        add('L',1,1,17,23,medium,fmt,b'/a\0\xff'.hex())
    for cap, fmt, length in itertools.product(range(2),range(3),(0,3,6,9,12)):
        add('M',cap,17,1,1,0,fmt,bytes(range(1,length+1)).hex())
    for cap, width, height, length in ((1,65536,1,0),(1,1,65536,3),(0,65536,65536,9)):
        add('M',cap,17,width,height,0,2,bytes(range(1,length+1)).hex())
    return rows


TRAPS = tuple((label, category, category) for label,category in (
    ('path_id','integer overflow'),('path_error_id','integer overflow'),
    ('encoded_id','integer overflow'),('width_cast','integer does not fit in destination type'),
    ('height_cast','integer does not fit in destination type'),
    ('width_rgba_cast','integer does not fit in destination type'),
    ('width_png_cast','integer does not fit in destination type'))) + (('png_header','reached unreachable code','Assertion failed'),)



def constructors(args, root, invoke, native_command):
    specs = (
        ('Image','v.Image',{'id':'0','width':'0','height':'0'}),
        ('ImageCellDimensions','v.Image.CellSize',{'rows':'0','cols':'0'}),
        ('ImagePlacement','v.Image.Placement',{'img_id':'0','options':'.{}'}),
        ('ImagePixelOffset','Offset',{'x':'0','y':'0'}),
        ('ImageSourcePath',None,{'path':'""'}),
        ('ImageSourceMemory',None,{'bytes':'[]u8{}'}),
    )
    prefix = 'const v=@import("vaxis"); const Offset=@typeInfo(@TypeOf((v.Image.DrawOptions{}).pixel_offset)).optional.child;\n'
    def zig(name, fields, alias=False, mutate=False):
        init=','.join('.'+k+'='+val for k,val in fields.items())
        updates=''.join('x.'+k+'='+value+';' for k,value in fields.items()) if mutate else ''
        return prefix + ('const Alias='+name+';\n' if alias else '') + 'pub fn main() void {'+('var' if mutate else 'const')+' x:'+('Alias' if alias else name)+'=.{'+init+'};'+updates+('' if mutate else '_ = x;')+'}\n'
    def translated(name, fields, alias=False, mutate=False):
        init='\n'.join(k+': '+('v.ImageDrawOptions{}' if k=='options' else val) for k,val in fields.items())
        updates='\n'.join('x.'+k+'='+('v.ImageDrawOptions{}' if k=='options' else value) for k,value in fields.items()) if mutate else ''
        return 'module main\nimport vaxis as v\n'+('type Alias = v.'+name+'\n' if alias else '')+'fn main(){'+('mut ' if mutate else '')+'x:='+('Alias' if alias else 'v.'+name)+'{'+init+'}\n'+updates+'\n_ = x}\n'
    def check(label, language, content, expected, field=None):
        path=root/(label+('.zig' if language=='source' else '.v'));path.write_text(content)
        if language=='source':
            cmd=[str(args.zig.resolve()),'build-exe','-O',native_command[native_command.index('-O')+1],'-target',args.target,'-lc']
            graph=native_command[native_command.index('--dep'): -1]
            cmd += [x.replace(str(PROBE/'reference.zig'),str(path)) for x in graph]+['-fno-emit-bin']
        else:
            cmd=[str(args.v.resolve()),'-enable-globals',*(['-prod'] if args.v_prod else []),'-check','-path',args.v_path or str(PROBE.parents[2])+'|@vlib|@vmodules',str(path)]
        result=invoke(label+'-'+language,cmd)
        diagnostic=(result.stdout+result.stderr).decode(errors='replace')
        if (result.returncode==0)!=expected:
            raise AssertionError(label+' '+language+' unexpected compile result: '+diagnostic)
        if not expected:
            if result.returncode <= 0 or any(x in diagnostic.lower() for x in ('panic:', 'compiler bug', 'segmentation fault', 'c error found', 'internal compiler error')):
                raise AssertionError(label+' is not an ordinary compiler rejection: '+diagnostic)
            marker = r'error: missing struct field: '+re.escape(field)+r'(?=\s|$)' if language=='source' else r'error: field `vaxis\.[^.]+\.'+re.escape(field)+r'` must be initialized'
            if not re.search(marker, diagnostic):
                raise AssertionError(label+' lacks its exact required-field diagnostic: '+diagnostic)
        return {'accepted':result.returncode==0,'consumer_sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
    observations=[]
    for name,source_name,fields in specs:
        row={'type':name,'source_type':source_name}
        row['control_v']=check(name+'-control','v',translated(name,fields,mutate=source_name is not None),True)
        if source_name: row['control_source']=check(name+'-control','source',zig(source_name,fields,mutate=True),True)
        for field in fields:
            missing={k:val for k,val in fields.items() if k!=field}
            entry={'field':field,'v':check(name+'-'+field,'v',translated(name,missing),False,field),
                   'v_alias':check(name+'-'+field+'-alias','v',translated(name,missing,True),True)}
            if source_name:
                entry['source']=check(name+'-'+field,'source',zig(source_name,missing),False,field)
                entry['source_alias']=check(name+'-'+field+'-alias','source',zig(source_name,missing,True),False,field)
            observations.append({**row,**entry})
    return observations


def verify(args, root, env, mode):
    source = args.source.resolve() / 'src'
    shutil.copytree(source, root / 'src')
    shutil.copytree(args.zigimg.resolve(), root / 'zigimg')
    fixtures = {path.name: hashlib.sha256(path.read_bytes()).hexdigest()
                for path in (PROBE / 'reference.zig', PROBE / 'main.v', Path(__file__))}
    metadata = {'source_sha256': VAXIS_SHA256, 'zigimg_src_sha256': ZIGIMG_SHA256, 'zigimg_root_sha256': ZIGIMG_ROOT_SHA256, 'zigimg_package_sha256': ZIGIMG_PACKAGE_SHA256, 'uucode_sha256': UUCODE_SHA256, 'fixtures': fixtures,
                'stdlib_sha256':STDLIB_SHA256, 'source_mode': mode, 'v_mode': 'production' if args.v_prod else 'ordinary',
                'target': args.target, 'environment': env,
                'source_writer': 'std.Io.Writer.Allocating with successful allocations',
                'source_build_sha256': hashlib.sha256((PROBE.parent / 'widgets_classic/source_build.py').read_bytes()).hexdigest()}
    (root / 'metadata.json').write_text(json.dumps(metadata, indent=2) + '\n')

    def invoke(label, command, timeout=args.timeout, **kwargs):
        (root / (label + '-argv.json')).write_text(json.dumps({'argv': command, 'cwd': str(kwargs.get('cwd', Path.cwd()))}, indent=2) + '\n')
        result = original_run(command, env=env, capture_output=True, timeout=timeout, **kwargs)
        (root / (label + '.stdout')).write_bytes(result.stdout)
        (root / (label + '.stderr')).write_bytes(result.stderr)
        return result

    original_run = subprocess.run
    dependency_commands = 0

    def dependency_run(command, **kwargs):
        nonlocal dependency_commands
        check = kwargs.pop('check', False)
        result = invoke('unicode-' + str(dependency_commands), command, **kwargs)
        dependency_commands += 1
        if check:
            result.check_returncode()
        return result

    print('Generating unchanged locked Unicode dependency tables', file=sys.stderr, flush=True)
    with patch('source_build.subprocess.run', dependency_run):
        graph = prepare_uucode(args.zig.resolve(), root, args.uucode.resolve(), args.target)
    commands = [('native ' + mode, [str(args.zig.resolve()), 'build-exe', '-O', mode, '-target', args.target, '-lc',
                 *module('root', PROBE / 'reference.zig', ['vaxis','zigimg']), *module('vaxis', root / 'src/main.zig', ['uucode','zigimg']),
                 *module('zigimg', root / 'zigimg/zigimg.zig'),
                 *graph, f'-femit-bin={root / "native"}']),
                ('V production' if args.v_prod else 'V ordinary', [str(args.v.resolve()), '-enable-globals',
                 *(['-prod'] if args.v_prod else []), '-path', args.v_path or str(PROBE.parents[2]) + '|@vlib|@vmodules',
                 '-o', str(root / 'translated'), str(PROBE / 'main.v')])]
    for index, (label, command) in enumerate(commands):
        print('Building ' + label, file=sys.stderr, flush=True)
        result = invoke(('native' if index == 0 else 'translated') + '-build', command)
        if result.returncode:
            raise AssertionError(label + ' failed to build: ' + (result.stdout+result.stderr).decode(errors='replace'))
    rows = corpus()
    if len(rows) != EXPECTED_ROWS:
        raise AssertionError('returning corpus count changed')
    data = root / 'cases.txt'
    data.write_text('\n'.join(rows) + '\n')
    outputs = []
    for executable in ('native', 'translated'):
        print(f'Running {executable}: {len(rows)} returning records', file=sys.stderr, flush=True)
        start = time.monotonic()
        command = [str(root / executable), str(data)]
        (root / (executable + '-argv.json')).write_text(json.dumps({'argv': command, 'cwd': str(Path.cwd())}, indent=2) + '\n')
        with (root / (executable + '.stdout')).open('wb') as out, (root / (executable + '.stderr')).open('wb') as err:
            result = original_run(command, env=env, stdout=out, stderr=err, timeout=args.timeout)
        output = (root / (executable + '.stdout')).read_bytes().splitlines()
        error = (root / (executable + '.stderr')).read_bytes()
        if result.returncode or error or len(output) != len(rows):
            raise AssertionError(f'{executable} failed after {len(output)} of {len(rows)} records: ' + error.decode(errors='replace'))
        outputs.append(output)
        print(f'{executable} completed in {time.monotonic()-start:.2f}s', file=sys.stderr, flush=True)
    for i, (case, expected, actual) in enumerate(zip(rows, *outputs)):
        if expected != actual:
            raise AssertionError(f'record {i} ({case}): source={expected!r}, V={actual!r}')
    constructor_observations = constructors(args, root, invoke, commands[0][1])
    states = []
    for label, source_category, v_category in TRAPS:
        observations = []
        for executable, category in (('native', source_category), ('translated', v_category)):
            path = root / (executable + '-' + label + '.state')
            result = invoke(executable + '-' + label, [str(root / executable), '--trap', label, str(path)])
            checked_trap(result, label, category, executable)
            observations.append(path.read_bytes())
        if observations[0] != observations[1]:
            raise AssertionError(f'{label} panic state: source={observations[0]!r}, V={observations[1]!r}')
        states.append(label.encode() + b'|' + observations[0])
        print(f'{label}: strict panic category and retained state match', file=sys.stderr, flush=True)
    for name, path, expected in (('original source', source, VAXIS_SHA256), ('copied source', root / 'src', VAXIS_SHA256),
            ('original zigimg package', args.zigimg.resolve(), ZIGIMG_PACKAGE_SHA256), ('copied zigimg package', root / 'zigimg', ZIGIMG_PACKAGE_SHA256),
            ('original zigimg', args.zigimg.resolve() / 'src', ZIGIMG_SHA256), ('copied zigimg', root / 'zigimg/src', ZIGIMG_SHA256),
            ('original Unicode', args.uucode.resolve(), UUCODE_SHA256), ('copied Unicode', root / 'uucode', UUCODE_SHA256)):
        if tree_hash(path) != expected:
            raise AssertionError(name + ' changed during verification')
    for path in (PROBE / 'reference.zig', PROBE / 'main.v', Path(__file__)):
        if hashlib.sha256(path.read_bytes()).hexdigest() != fixtures[path.name]:
            raise AssertionError('fixture changed during verification: ' + str(path))
    for path in (args.zigimg.resolve() / 'zigimg.zig', root / 'zigimg/zigimg.zig'):
        if hashlib.sha256(path.read_bytes()).hexdigest() != ZIGIMG_ROOT_SHA256:
            raise AssertionError('zigimg root entrypoint changed')
    check_stdlib(args.zig)
    output_hash = hashlib.sha256(b'\n'.join(outputs[0])).hexdigest()
    state_hash = hashlib.sha256(b'\n'.join(states)).hexdigest()
    if output_hash != EXPECTED_SHA256 or state_hash != EXPECTED_STATE_SHA256:
        raise AssertionError('recorded returning or panic-state hash changed')
    metadata.update({'constructor_observations': constructor_observations, 'paired_required_omissions':9, 'v_wrapper_omissions':2, 'v_alias_boundary_cases':11, 'returning_records': len(rows), 'strict_traps': len(TRAPS), 'panic_states': len(states),
                     'output_sha256': output_hash, 'panic_state_sha256': state_hash, 'unchanged_source_postcheck': True})
    (root / 'metadata.json').write_text(json.dumps(metadata, indent=2) + '\n')
    print(f'Image: {len(rows)} returning records {dict(Counter(row[0] for row in rows))}, {len(TRAPS)} strict traps and panic states; '
          'SHA256 ' + output_hash + '; state SHA256 ' + state_hash)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('zig', type=Path)
    parser.add_argument('--zigimg', type=Path, required=True)
    parser.add_argument('v', type=Path)
    parser.add_argument('--uucode', type=Path, default=Path.home() / '.cache/zig/p' / UUCODE_PACKAGE)
    parser.add_argument('--target', default='aarch64-macos.14.0')
    parser.add_argument('--v-prod', action='store_true')
    parser.add_argument('--zig-mode', choices=('Debug', 'ReleaseSafe'))
    parser.add_argument('--v-path', help=argparse.SUPPRESS)
    parser.add_argument('--timeout', type=int, default=180)
    parser.add_argument('--build-dir', type=Path, help='Keep fresh artifacts for inspection; directory must not exist')
    args = parser.parse_args()
    if args.timeout <= 0:
        parser.error('--timeout must be positive')
    check_stdlib(args.zig)
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
    if tree_hash(args.source.resolve() / 'src') != VAXIS_SHA256:
        parser.error('vaxis source differs from the recorded local source')
    if tree_hash(args.zigimg.resolve()) != ZIGIMG_PACKAGE_SHA256 or tree_hash(args.zigimg.resolve() / 'src') != ZIGIMG_SHA256 or hashlib.sha256((args.zigimg.resolve() / 'zigimg.zig').read_bytes()).hexdigest() != ZIGIMG_ROOT_SHA256:
        parser.error('zigimg source differs from the recorded pinned source')
    # Record the complete child environment without retaining unrelated secrets.
    keys = ('PATH', 'HOME', 'TMPDIR', 'SDKROOT', 'MACOSX_DEPLOYMENT_TARGET', 'LANG', 'LC_ALL')
    env = {key: os.environ[key] for key in keys if key in os.environ}
    env.update(VEXE=str(args.v.resolve()), V_C_ERROR_BUG_REPORT_DISABLED='1')
    mode = args.zig_mode or ('ReleaseSafe' if args.v_prod else 'Debug')
    if args.build_dir:
        args.build_dir.mkdir(parents=True, exist_ok=False)
        verify(args, args.build_dir.resolve(), env, mode)
    else:
        with tempfile.TemporaryDirectory(prefix='witty-image-') as directory:
            verify(args, Path(directory), env, mode)


if __name__ == '__main__':
    main()
