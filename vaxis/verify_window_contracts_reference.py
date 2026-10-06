"""Compare public Window record contracts with unchanged pinned Vaxis."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import resource
import shutil
import subprocess
import sys
import tempfile

PROBE = Path(__file__).resolve().parent / 'reference_probes/window_contracts'
REPO = PROBE.parents[2]
sys.path.insert(0, str(PROBE.parent / 'widgets_classic'))
from source_build import VAXIS_SHA256, UUCODE_PACKAGE, module, prepare_uucode, tree_hash

WINDOW = dict(x_off='0', y_off='0', parent_x_off='0', parent_y_off='0', width='7', height='3', screen='&screen')
RESULT = dict(col='65535', row='65535', overflow='false')


def ordinary_rejection(result, label, marker=None):
    diagnostic = (result.stdout + result.stderr).decode(errors='replace')
    bug = re.search(r'(?im)(?:panic:|segmentation fault|compiler bug|compiler error:|C compilation failed|builder error:|internal compiler|report a bug|please report this|C error found)', diagnostic)
    if result.returncode != 1 or bug or not re.search(r'(?m)^.*error:.*$', diagnostic) or (marker is not None and marker not in diagnostic):
        raise AssertionError(f'{label}: not the expected ordinary rejection: {diagnostic}')


def literal(fields, source, kind):
    return ('.{' if source else 'vaxis.'+kind+'{') + ','.join(('.'+field+'=' if source else field+':')+value for field,value in fields.items())+'}'


def compare(args, root):
    source = args.source.resolve() / 'src'
    if tree_hash(source) != VAXIS_SHA256:
        raise ValueError('vaxis source differs from the pinned tree')
    shutil.copytree(source, root / 'src')
    graph = prepare_uucode(args.zig.resolve(), root, args.uucode.resolve(), args.target)
    mode = 'ReleaseSafe' if args.v_prod else 'Debug'
    env = dict(os.environ, VEXE=str(args.v.resolve()), V_C_ERROR_BUG_REPORT_DISABLED='1')
    native_prefix = [str(args.zig.resolve()), 'build-exe', '-O', mode, '-target', args.target, '-lc']
    v_prefix = [str(args.v.resolve()), *(['-prod'] if args.v_prod else []), '-path', f'{REPO}|@vlib|@vmodules']

    def command(path, language, output=None):
        if language == 'Source':
            return [*native_prefix, *module('root',path,['vaxis']), *module('vaxis',root/'src/main.zig',['uucode']), *graph, '-fno-emit-bin' if output is None else '-femit-bin='+str(output)]
        return [*v_prefix, *(['-check'] if output is None else ['-o',str(output)]), str(path)]

    def invoke(name, argv, timeout=180):
        (root/(name+'-argv.json')).write_text(json.dumps(argv))
        result = subprocess.run(argv, env=env, capture_output=True, timeout=timeout)
        (root/(name+'.stdout')).write_bytes(result.stdout)
        (root/(name+'.stderr')).write_bytes(result.stderr)
        return result

    outputs = []
    layout = []
    for language, file, binary in [('Source','reference.zig','native'),('V','main.v','translated')]:
        print('Building '+language+' '+mode, file=sys.stderr, flush=True)
        result = invoke(binary+'-build',command(PROBE/file,language,root/binary))
        if result.returncode:
            raise AssertionError(f'{language}: returning consumer build failed: '+(result.stdout+result.stderr).decode(errors='replace'))
        result = invoke(binary,[str(root/binary)])
        if result.returncode or result.stderr or len(result.stdout.splitlines()) != 311:
            raise AssertionError(f'{language}: returning consumer failed: {result}')
        outputs.append(result.stdout)
        result = invoke(binary+'-layout',[str(root/binary),'layout'])
        if result.returncode or result.stderr:
            raise AssertionError(f'{language}: layout observation failed: {result}')
        layout.append(result.stdout)
    if outputs[0] != outputs[1]:
        for index, (expected,actual) in enumerate(zip(outputs[0].splitlines(),outputs[1].splitlines())):
            if expected != actual:
                raise AssertionError(f'record {index}: Source={expected!r}, V={actual!r}')
        raise AssertionError('record count differs')
    if not layout[0].startswith(b'Locations|1|4\n') or not layout[1].startswith(b'Locations|4|32\n'):
        raise AssertionError('packed/native record representation observation changed: '+repr(layout))

    # V sum carriers contain boxed payload pointers. Copying a carrier aliases
    # that payload, unlike a Source union value or a direct V wrapper record.
    for language,file,expected in [('Source','payload_copy.zig',b'new\n0\n1\n0\n'),('V','payload_copy.v',b'new\nnew\n1\n1\n')]:
        binary = root/('payload-copy-'+language)
        result = invoke('payload-copy-'+language+'-build',command(PROBE/file,language,binary))
        if result.returncode:
            raise AssertionError(f'{language}: payload-copy consumer build failed: '+(result.stdout+result.stderr).decode(errors='replace'))
        result = invoke('payload-copy-'+language,[str(binary)])
        if result.returncode or result.stderr or result.stdout != expected:
            raise AssertionError(f'{language}: payload-copy boundary changed: {result}')

    def case(name,zbody,vbody,zreject=None,vreject=None,expected=b'',aliases=''):
        zp,vp = root/(name+'.zig'),root/(name+'.v')
        zp.write_text('const std=@import("std");const vaxis=@import("vaxis");const W=vaxis.Window;const B=W.BorderOptions;'
            'pub fn main()void{var screen:vaxis.Screen=.{};_ = &screen;'+zbody+'}\n')
        vp.write_text('module main\nimport vaxis\n'+aliases+'\nfn main(){mut screen := vaxis.Screen{}\n_ = &screen\n'+vbody+'}\n')
        for language,path,rejected in [('Source',zp,zreject),('V',vp,vreject)]:
            binary = root/(name+'-'+language)
            result = invoke(name+'-'+language+'-build',command(path,language,None if rejected is not None else binary))
            if rejected is not None:
                ordinary_rejection(result,name+' '+language,rejected or None)
            elif result.returncode:
                raise AssertionError(f'{name} {language}: consumer failed to compile: '+(result.stdout+result.stderr).decode(errors='replace'))
            else:
                result = invoke(name+'-'+language,[str(binary)],30)
                if result.returncode or result.stderr or result.stdout != expected:
                    raise AssertionError(f'{name} {language}: unexpected consumer result: {result}')

    omissions = 0
    for kind,ztype,fields in [('Window','W',WINDOW),('PrintResult','W.PrintResult',RESULT)]:
        for missing in fields:
            print('Checking required '+kind+'.'+missing,file=sys.stderr,flush=True)
            selected = {key:value for key,value in fields.items() if key != missing}
            case('omit_'+kind+'_'+missing,'const value:'+ztype+'='+literal(selected,True,kind)+';_ = value;',
                 'value := '+literal(selected,False,kind)+'\n_ = value',
                 'missing struct field: '+missing,'vaxis.'+kind+'.'+missing)
            omissions += 1
    case('omit_custom','const value:B.Glyphs=.custom;_ = value;','value := vaxis.BorderCustom{}\n_ = value',"must initialize '[6][]const u8' field 'custom'",'vaxis.BorderCustom.glyphs')
    omissions += 1

    complete = [
        ('window','W',literal(WINDOW,True,'Window'),literal(WINDOW,False,'Window')),
        ('result','W.PrintResult',literal(RESULT,True,'PrintResult'),literal(RESULT,False,'PrintResult')),
        ('child','W.ChildOptions','.{ }','vaxis.WindowChildOptions{}'),
        ('border','B','.{ }','vaxis.WindowBorderOptions{}'),
        ('locations','B.Locations','.{ }','vaxis.BorderLocations{}'),
        ('custom','B.Glyphs','.{.custom=.{"0","1","2","3","4","5"}}',"vaxis.BorderCustom{glyphs:['0','1','2','3','4','5']!}"),
        ('print','W.PrintOptions','.{ }','vaxis.PrintOptions{}'),
    ]
    for name,ztype,zvalue,vvalue in complete:
        case('complete_'+name,'const value:'+ztype+'='+zvalue+';_ = value;','value := '+vvalue+'\n_ = value')
    for length in (5,7):
        zv=','.join('"'+str(i)+'"' for i in range(length)); vv=','.join("'"+str(i)+"'" for i in range(length))
        case('glyph_length_'+str(length),'const value:B.Glyphs=.{.custom=.{'+zv+'}};_ = value;',
             'value := vaxis.BorderCustom{glyphs:['+vv+']!}\n_ = value',
             'expected 6 array elements; found 5' if length == 5 else 'index 6 outside array of length 6',
             f'expected `[6]string`, not `[{length}]string`')

    # These values are constructed and observed without calling Window methods;
    # checked method boundaries are covered by separate behavioral probes.
    wider = 0
    for kind,ztype,fields in [('Window','W',WINDOW),('ChildOptions','W.ChildOptions',dict(x_off='0',y_off='0'))]:
        vk = 'Window' if kind == 'Window' else 'WindowChildOptions'
        for field in ('x_off','y_off','parent_x_off','parent_y_off') if kind == 'Window' else ('x_off','y_off'):
            for number in (-65537,65536):
                selected = dict(fields,**{field:str(number)})
                case('wide_'+kind+'_'+field+'_'+str(abs(number)),'const value:'+ztype+'='+literal(selected,True,vk)+';_ = value;',
                     'value := '+literal(selected,False,vk)+'\nprintln(value.'+field+')','cannot represent integer value',None,(str(number)+'\n').encode())
                wider += 1

    alias_cases = [
        ('window','W','Window',dict(WINDOW), 'width','type Alias = vaxis.Window\n','println(value.width)','0\n'),
        ('result','W.PrintResult','PrintResult',dict(RESULT),'overflow','type Alias = vaxis.PrintResult\n','println(int(value.overflow))','0\n'),
        ('custom','B.Glyphs','BorderCustom',{},'glyphs','type Alias = vaxis.BorderCustom\n','println(value.glyphs[0].len)','0\n'),
    ]
    for name,ztype,kind,fields,missing,aliases,observe,expected in alias_cases:
        if name == 'custom':
            zbody = 'const Alias=B.Glyphs;const value:Alias=.custom;_ = value;'
            vbody = 'value := Alias{}\n'+observe
            source_marker = "must initialize '[6][]const u8' field 'custom'"
        else:
            fields.pop(missing)
            zbody = 'const Alias='+ztype+';const value:Alias='+literal(fields,True,kind)+';_ = value;'
            vbody = 'value := Alias{'+','.join(k+':'+v for k,v in fields.items())+'}\n'+observe
            source_marker = 'missing struct field: '+missing
        case('alias_omission_'+name,zbody,vbody,source_marker,None,expected.encode(),aliases)

    null = dict(WINDOW,screen='@ptrFromInt(0)')
    vnull = dict(WINDOW,screen='unsafe { nil }')
    case('null_pointer','const value:W='+literal(null,True,'Window')+';_ = value;',
         'value := '+literal(vnull,False,'Window')+'\nprintln(usize(value.screen))','does not allow address zero',None,b'0\n')
    digest = hashlib.sha256(outputs[0]).hexdigest()
    print(f'Window contracts ({mode}, V {"production" if args.v_prod else "ordinary"}): 311 returning records, 13 selected default observations, 7 public record mutation/copy checks, '
          f'{len(complete)} complete pairs, {omissions} omission pairs, 2 fixed-glyph length rejection pairs; '
          f'{wider} wider-i17, 3 alias-required, 1 null-pointer, 1 packed/record ABI and 2 boxed-carrier sharing observations; SHA256 {digest}')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source',type=Path); parser.add_argument('zig',type=Path); parser.add_argument('v',type=Path)
    parser.add_argument('--target',default='aarch64-macos.14.0')
    parser.add_argument('--uucode',type=Path,default=Path.home()/'.cache/zig/p'/UUCODE_PACKAGE)
    parser.add_argument('--v-prod',action='store_true'); parser.add_argument('--workdir',type=Path)
    args = parser.parse_args()
    resource.setrlimit(resource.RLIMIT_CORE,(0,0))
    if args.workdir:
        args.workdir.mkdir(parents=True,exist_ok=False)
        compare(args,args.workdir.resolve())
    else:
        with tempfile.TemporaryDirectory(prefix='witty-window-contracts-') as directory:
            compare(args,Path(directory))


if __name__ == '__main__':
    main()
