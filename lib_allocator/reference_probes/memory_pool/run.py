#!/usr/bin/env python3
"""Compare actual Zig 0.15.2 pools/arena/maps with the translated allocators."""
import difflib, os, pathlib, subprocess, sys, tempfile
fixture=pathlib.Path(__file__).resolve().parent
repository=fixture.parents[2]
zig=sys.argv[1]
v=sys.argv[2]
source=subprocess.run([zig,'run','-target','aarch64-macos.14.0','-lc',str(fixture/'main.zig')],check=True,capture_output=True,text=True).stderr
with tempfile.TemporaryDirectory(prefix='witty-pool-reference-') as directory:
 # V resolves non-main test modules by their containing directory. Copy the
 # fixture into the actual module temporarily, leaving production untouched.
 target=repository/'lib_allocator'/'native_pool_reference_test.v'
 try:
  target.write_text((fixture/'native_trace_test.v').read_text())
  executable=pathlib.Path(directory)/'trace'
  env=dict(os.environ,VEXE=v)
  translated=subprocess.run([v,'-path',str(repository)+'|@vlib|@vmodules',str(target)],check=True,capture_output=True,text=True,env=env).stdout
 finally:
  target.unlink(missing_ok=True)
if translated!=source:
 print(''.join(difflib.unified_diff(source.splitlines(True),translated.splitlines(True),fromfile='original Zig',tofile='translated V')))
 raise SystemExit(1)
print(f'{len(source.splitlines())} original pool/arena/pin-map allocation events and snapshots matched')
