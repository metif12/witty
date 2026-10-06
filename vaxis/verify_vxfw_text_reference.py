"""Compare public Text drawing and iterator constructor contracts with unchanged source."""
import argparse, hashlib, itertools, os, resource, shutil, subprocess, sys, tempfile, time
from pathlib import Path
PROBE=Path(__file__).resolve().parent/'reference_probes/vxfw_text'
sys.path.insert(0,str(PROBE.parent/'widgets_classic'))
from source_build import VAXIS_SHA256,UUCODE_PACKAGE,module,prepare_uucode,tree_hash
sys.path.insert(0,str(PROBE.parents[1]))
from verify_vxfw_surface_reference import checked_trap
from verify_vxfw_constructors_reference import ordinary_rejection

def row(text=b'abc',method=0,wrap=1,align=0,overflow=0,basis=0,minw=0,minh=0,maxw=8,maxh=4,style=0,widget=0,mutate=''):
 return '|'.join(map(str,(text.hex(),method,wrap,align,overflow,basis,minw,minh,maxw,maxh,style,widget,mutate)))
def corpus():
 rows=[]
 samples=[b'',b'a',b'abc def gh',b'a\n\r\nb\rc\n',b'\r\n\n',b'  ab   cd   ',b'a\tb',b'\ta',b'a\t\tb',b'\x00\x01a\x1b',b'\xe1\x80a',b'\xf0\x9fab','café 漢字'.encode(),'👨\u200d👩\u200d👧'.encode(),b'e\xcc\x81']
 constraints=[(0,0,0,0),(0,2,0,3),(0,0,1,2),(0,0,2,4),(0,0,5,5),(7,2,8,1),(0,0,-1,4),(3,2,-1,4)]
 for text,method,wrap,align,overflow,basis,limits in itertools.product(samples,range(3),range(2),range(3),range(2),range(2),constraints):
  if basis and limits[2]<0:continue
  if text==b'a\t\tb' and wrap and limits[2]==1:continue
  rows.append(row(text,method,wrap,align,overflow,basis,*limits,style=(len(rows)%2),widget=(len(rows)%2)))
 for text,wrap,method in itertools.product((b'ab cd\ne',b'\ta\r\nb',b'a\xe1\x80b'),range(2),range(3)):
  rows.append(row(text,method,wrap,maxw=3,maxh=4,mutate='0:58,'+str(len(text)-1)+':59'))
 # A zero-width maximum returns before malformed decoding, width assertions or allocation.
 for method,wrap,basis in itertools.product(range(3),range(2),range(2)):
  rows.append(row(b'\xff\xcc\x81',method,wrap,basis=basis,minw=65535,minh=2,maxw=0,maxh=-1))
 for wrap in range(2):
  rows.append(row(b'\n'*65535,wrap=wrap,maxw=1,maxh=-1))
  rows.append(row(b'\n'*65536,wrap=wrap,maxw=1,maxh=65535))
 rows.append(row(('👨\u200d'*128+'👨').encode(),maxw=-1))
 rows.append(row(b'a'*65535,maxw=-1,maxh=1))
 # Plain drawing obtains a line before its height guard but does not decode it.
 rows.append(row(b'\xff\xcc\x81',wrap=0,maxw=8,maxh=0))
 rows.append(row(b'a\n\xff\xcc\x81',wrap=0,maxw=8,maxh=1))
 return rows

def traps():
 return {
  'parent_width':(row(basis=1,maxw=-1),('reached unreachable code','Assertion failed')),
  'area':(row(b'',minw=65535,minh=2,maxw=-1,maxh=0),('integer overflow',)*2),
  'rows_wrap':(row(b'\n'*65536,maxw=1,maxh=-1),('integer overflow',)*2),
  'rows_plain':(row(b'\n'*65536,wrap=0,maxw=1,maxh=-1),('integer overflow',)*2),
  'word_width':(row(b'a'*65536,maxw=-1),('integer overflow',)*2),
  'trim_underflow':(row(b'\t\t\t\tabc',maxw=2),('integer overflow',)*2),
  'tab_cast':(row(b'a'*65534+b'\tb',basis=1,maxw=65535,maxh=1),('integer does not fit in destination type','integer cast truncated bits')),
  'tab_add':(row(b'a'*65528+b'\tb',basis=1,maxw=65535,maxh=1),('integer overflow',)*2),
  'raw_unicode':(row(b'\xff\xcc\x81',maxw=8),('integer overflow',)*2),
  'raw_unicode_height0':(row(b'\xff\xcc\x81',maxw=8,maxh=0),('integer overflow',)*2),
  'raw_unicode_next_line':(row(b'a\n\xff\xcc\x81',maxw=8,maxh=1),('integer overflow',)*2),
  **{f'grapheme_cast_{method}_{wrap}':(row(('👨\u200d'*128+'👨').encode(),method=method,wrap=wrap,maxw=-1),('integer does not fit in destination type','integer cast truncated bits'))
     for method,wrap in itertools.product((1,2),range(2))},
 }

def contracts(root, native, vcommand, env):
 """Construct public payloads, and measure private Source method boundaries."""
 ctx_z='.{.arena=std.heap.page_allocator,.min=.{},.max=.{},.cell_size=.{}}'
 ctx_v='fw.DrawContext{min:fw.Size{},max:fw.MaxSize{},cell_size:fw.Size{}}'
 items=[
  ('LineIterator','fw.Text.LineIterator', [('buf','buf','"abc"',"'abc'")]),
  ('SoftwrapIterator','fw.Text.SoftwrapIterator', [
   ('ctx','ctx',ctx_z,ctx_v), ('hard_iter','hard_iter','.{.buf="abc"}',"fw.LineIterator{buf:'abc'}")]),
  ('WrappedLine','fw.Text.SoftwrapIterator.Line', [('width','width','3','3'),('bytes','bytes','"abc"',"'abc'")]),
 ]
 zpath,vpath=root/'contract.zig',root/'contract.v'
 def check(zbody,vbody,marker=None):
  zpath.write_text('const std=@import("std");const vx=@import("vaxis");const fw=vx.vxfw;pub fn main() void {'+zbody+'}\n')
  vpath.write_text('module main\nimport vaxis.vxfw as fw\nfn main(){'+vbody+'}\n')
  results=[subprocess.run(command,env=env,capture_output=True,timeout=180) for command in (native(zpath,'-fno-emit-bin'),vcommand(vpath))]
  for name,result in zip(('source','V'),results):
   good=result.returncode==0 if marker is None else ordinary_rejection(result,marker[0 if name=='source' else 1])
   if not good:raise AssertionError(name+' constructor failed: '+(result.stdout+result.stderr).decode(errors='replace'))
  return results
 omissions=0
 for kind,ztype,fields in items:
  print('Checking '+kind+' payload',file=sys.stderr,flush=True)
  for missing in [None]+[field[0] for field in fields]:
   selected=[f for f in fields if f[0]!=missing]
   zvalue='.{'+','.join('.'+z+'='+expr for _,z,expr,_ in selected)+'}'
   vvalue='fw.'+kind+'{'+','.join(v+':'+expr for v,_,_,expr in selected)+'}'
   markers=None if missing is None else ('missing struct field: '+missing,'vaxis.vxfw.'+kind+'.'+missing)
   check('const value:'+ztype+'='+zvalue+';_=value;','value:='+vvalue+' println(sizeof(value))',markers)
   omissions+=missing is not None
 boundaries=[
  ('LineIterator.next','var it:fw.Text.LineIterator=.{.buf="abc"};_=it.next();',"mut it:=fw.LineIterator{buf:'abc'} _=it.next()",'next'),
  ('SoftwrapIterator.init','_=fw.Text.SoftwrapIterator.init("abc",'+ctx_z+');',"_=fw.SoftwrapIterator.new('abc',"+ctx_v+')','init'),
  ('SoftwrapIterator.next','var it:fw.Text.SoftwrapIterator=.{.ctx='+ctx_z+',.hard_iter=.{.buf="abc"}};_=it.next();',"mut it:=fw.SoftwrapIterator{ctx:"+ctx_v+",hard_iter:fw.LineIterator{buf:'abc'}} _=it.next()",'next'),
 ]
 for label,zbody,vbody,method in boundaries:
  print('Checking private Source '+label,file=sys.stderr,flush=True)
  zpath.write_text('const std=@import("std");const vx=@import("vaxis");const fw=vx.vxfw;pub fn main() void {'+zbody+'}\n')
  vpath.write_text('module main\nimport vaxis.vxfw as fw\nfn main(){'+vbody+'}\n')
  original=subprocess.run(native(zpath,'-fno-emit-bin'),env=env,capture_output=True,timeout=180)
  translated=subprocess.run(vcommand(vpath),env=env,capture_output=True,timeout=180)
  if not ordinary_rejection(original,"'"+method+"' is not marked 'pub'") or translated.returncode:
   raise AssertionError(label+' private/public adapter boundary differs: '+(original.stdout+original.stderr+translated.stdout+translated.stderr).decode(errors='replace'))
 return len(items),omissions,len(boundaries)

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('source',type=Path);p.add_argument('zig',type=Path);p.add_argument('v',type=Path);p.add_argument('--uucode',type=Path,default=Path.home()/'.cache/zig/p'/UUCODE_PACKAGE);p.add_argument('--target',default='aarch64-macos.14.0');p.add_argument('--v-prod',action='store_true');p.add_argument('--zig-mode',choices=['Debug','ReleaseSafe']);p.add_argument('--v-path',help=argparse.SUPPRESS);p.add_argument('--timeout',type=int,default=120);p.add_argument('--trap-timeout',type=int,default=60);p.add_argument('--save-binaries',type=Path,help=argparse.SUPPRESS);args=p.parse_args()
 if args.timeout<=0:p.error('--timeout must be positive')
 if args.trap_timeout<=0:p.error('--trap-timeout must be positive')
 mode=args.zig_mode or ('ReleaseSafe' if args.v_prod else 'Debug');resource.setrlimit(resource.RLIMIT_CORE,(0,0));source=args.source.resolve()/'src'
 if tree_hash(source)!=VAXIS_SHA256:p.error('source differs from pinned tree')
 env=dict(os.environ,VEXE=str(args.v.resolve()),V_C_ERROR_BUG_REPORT_DISABLED='1')
 with tempfile.TemporaryDirectory(prefix='witty-vxfw-text-') as directory:
  root=Path(directory);shutil.copytree(source,root/'src');graph=prepare_uucode(args.zig.resolve(),root,args.uucode.resolve(),args.target)
  def native(path,output):return [str(args.zig.resolve()),'build-exe','-O',mode,'-target',args.target,'-lc',*module('root',path,['vaxis']),*module('vaxis',root/'src/main.zig',['uucode']),*graph,output]
  vpath=args.v_path or str(PROBE.parents[2])+'|@vlib|@vmodules';options=['-enable-globals']+(['-prod'] if args.v_prod else [])
  def vcommand(path):return [str(args.v.resolve()),*options,'-path',vpath,'-check',str(path)]
  print('Building unchanged source '+mode,file=sys.stderr,flush=True);subprocess.run(native(PROBE/'reference.zig',f'-femit-bin={root/"native"}'),env=env,check=True)
  print('Building V'+(' production' if args.v_prod else ' ordinary'),file=sys.stderr,flush=True);subprocess.run([str(args.v.resolve()),*options,'-path',vpath,'-o',str(root/'translated'),str(PROBE/'main.v')],env=env,check=True)
  if args.save_binaries:
   args.save_binaries.mkdir(parents=True,exist_ok=True)
   for name in ('native','translated'):shutil.copy2(root/name,args.save_binaries/name)
  cases=corpus();path=root/'cases.txt';path.write_text('\n'.join(cases)+'\n');outputs=[]
  for name in ('native','translated'):
   print(f'Running {name}: {len(cases)} records',file=sys.stderr,flush=True);started=time.monotonic();r=subprocess.run([str(root/name),str(path)],env=env,capture_output=True,timeout=args.timeout)
   if r.returncode or r.stderr:
    completed=len(r.stdout.splitlines());case=cases[completed] if completed<len(cases) else '<after matrix>'
    raise AssertionError(f'{name} failed after {completed} rows ({case}): '+r.stderr.decode(errors='replace'))
   output=r.stdout.splitlines()
   if len(output)!=len(cases):raise AssertionError(f'{name} returned {len(output)} of {len(cases)}')
   outputs.append(output);print(f'{name} completed in {time.monotonic()-started:.2f}s',file=sys.stderr,flush=True)
  for i,(case,expected,actual) in enumerate(zip(cases,*outputs)):
   if expected!=actual:raise AssertionError(f'record {i} ({case}): native={expected!r}, V={actual!r}')
  for label,(case,categories) in traps().items():
   path.write_text(case+'\n')
   for name,category in zip(('native','translated'),categories):
    print('Checking '+name+' trap '+label,file=sys.stderr,flush=True)
    try:result=subprocess.run([str(root/name),str(path)],env=env,capture_output=True,timeout=args.trap_timeout)
    except subprocess.TimeoutExpired as error:
     raise AssertionError(name+' trap '+label+' exceeded deadline: '+repr((error.stdout,error.stderr))) from error
    checked_trap(result,label,category,name)
  complete,omissions,boundaries=contracts(root,native,vcommand,env)
  print(f'Text: {len(cases)} records, {len(traps())} strict trap pairs, {complete} complete/{omissions} omission pairs, {boundaries} private Source/public V boundaries; SHA256 '+hashlib.sha256(b'\n'.join(outputs[0])).hexdigest())
if __name__=='__main__':main()
