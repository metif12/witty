#!/usr/bin/env python3
"""Compile unchanged upstream storage modules with the differential fixture."""
import pathlib, shutil, subprocess, sys, tempfile
reference = pathlib.Path(sys.argv[1])
zig = sys.argv[2]
with tempfile.TemporaryDirectory(prefix='witty-storage-reference-') as directory:
    root = pathlib.Path(directory)
    (root/'terminal').mkdir()
    for name in ('hash_map.zig','ref_counted_set.zig','size.zig'):
        shutil.copyfile(reference/'src'/'terminal'/name, root/'terminal'/name)
    # Debug's source-selected inlineAssert is std.debug.assert. Bind that
    # exact branch without pulling the unrelated font backend build graph.
    (root/'quirks.zig').write_text('pub const inlineAssert = @import("std").debug.assert;\n')
    shutil.copyfile(pathlib.Path(__file__).with_name('main.zig'), root/'main.zig')
    subprocess.run([zig,'run',str(root/'main.zig'),'-target','aarch64-macos.14.0','-lc'],check=True)
