#!/usr/bin/env python3
"""Run unchanged Ghostty PageList/MemoryPool with local package bridges."""
import difflib,os,pathlib,shutil,subprocess,sys,tempfile
reference=pathlib.Path(sys.argv[1]);zig=sys.argv[2]
fixture=pathlib.Path(__file__).resolve().parent;repository=fixture.parents[2]
with tempfile.TemporaryDirectory(prefix='witty-page-list-pool-reference-') as directory:
 root=pathlib.Path(directory)
 shutil.copytree(reference/'src',root,dirs_exist_ok=True)
 for name in ('fastmem.zig','tripwire.zig'):shutil.copyfile(reference/'src'/name,root/name)
 sgr=(reference/'src/terminal/sgr.zig').read_text();start=sgr.index('pub const Underline =');opening=sgr.index('{',start);depth=1;end=opening+1
 while depth:
  if sgr[end]=='{':depth+=1
  elif sgr[end]=='}':depth-=1
  end+=1
 (root/'terminal/sgr.zig').write_text('pub const Attribute=struct {\n'+sgr[start:end]+';\n};\n')
 (root/'terminal/kitty.zig').write_text('pub const graphics=struct {};\n')
 (root/'quirks.zig').write_text('pub const inlineAssert=@import("std").debug.assert;\n')
 (root/'config.zig').write_text('')
 (root/'terminal/Screen.zig').write_text('')
 (root/'datastruct/main.zig').write_text('pub const IntrusiveDoublyLinkedList=@import("intrusive_linked_list.zig").DoublyLinkedList;\n')
 (root/'terminal_options.zig').write_text('pub const kitty_graphics=false;pub const c_abi=false;pub const slow_runtime_safety=false;\n')
 shutil.copyfile(pathlib.Path(__file__).with_name('main.zig'),root/'main.zig')
 source=subprocess.run([zig,'run','-target','aarch64-macos.14.0','-lc','--dep','terminal_options','-Mroot='+str(root/'main.zig'),'-Mterminal_options='+str(root/'terminal_options.zig')],check=True,capture_output=True,text=True).stderr
if len(sys.argv)<4:
 print(source,end='');raise SystemExit(0)
v=sys.argv[3];target=repository/'terminal'/'native_page_list_pool_reference_test.v'
try:
 target.write_text((fixture/'native_trace_test.v').read_text())
 translated=subprocess.run([v,'-path',str(repository)+'|@vlib|@vmodules',str(target)],check=True,capture_output=True,text=True,env=dict(os.environ,VEXE=v)).stdout
finally:
 target.unlink(missing_ok=True)
if source!=translated:
 print(''.join(difflib.unified_diff(source.splitlines(True),translated.splitlines(True),fromfile='original Ghostty',tofile='translated V')))
 raise SystemExit(1)
print('5 original PageList MemoryPool/lifecycle/pin/clone snapshots matched')
