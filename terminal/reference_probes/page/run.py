#!/usr/bin/env python3
"""Compile/run unchanged original Page and its storage dependencies."""
import pathlib,shutil,subprocess,sys,tempfile
reference=pathlib.Path(sys.argv[1]);zig=sys.argv[2]
with tempfile.TemporaryDirectory(prefix='witty-page-reference-') as directory:
 root=pathlib.Path(directory)
 for directory in ('terminal','lib'):shutil.copytree(reference/'src'/directory,root/directory)
 shutil.copyfile(reference/'src/fastmem.zig',root/'fastmem.zig')
 # Style's only instantiated SGR dependency is the exact source Underline
 # declaration. Isolate it from the unrelated terminal Parser/C API imports.
 sgr=(reference/'src/terminal/sgr.zig').read_text()
 start=sgr.index('pub const Underline ='); opening=sgr.index('{',start)
 depth=1;end=opening+1
 while depth:
  if sgr[end]=='{':depth+=1
  elif sgr[end]=='}':depth-=1
  end+=1
 (root/'terminal/sgr.zig').write_text('pub const Attribute=struct {\n'+sgr[start:end]+';\n};\n')
 # This is kitty.zig's evaluated graphics declaration for the false option.
 (root/'terminal/kitty.zig').write_text('pub const graphics=struct {};\n')

 # The production assertion aliases std.debug.assert in Debug. Config is an
 # unused style rendering dependency; this fixture uses only style storage.
 (root/'quirks.zig').write_text('pub const inlineAssert=@import("std").debug.assert;\n')
 (root/'config.zig').write_text('')
 (root/'terminal_options.zig').write_text('pub const kitty_graphics=false;pub const c_abi=false;pub const slow_runtime_safety=false;\n')
 shutil.copyfile(pathlib.Path(__file__).with_name('main.zig'),root/'main.zig')
 subprocess.run([zig,'run','-target','aarch64-macos.14.0','-lc','--dep','terminal_options','-Mroot='+str(root/'main.zig'),'-Mterminal_options='+str(root/'terminal_options.zig')],check=True)
