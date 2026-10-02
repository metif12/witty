#!/usr/bin/env python3
"""Compare the unchanged pinned Ghostty logger in actual Wasm, in all modes."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

p = argparse.ArgumentParser()
p.add_argument('ghostty', type=Path)
p.add_argument('zig', type=Path)
p.add_argument('v', type=Path)
p.add_argument('emcc', type=Path)
p.add_argument('em_config', type=Path)
a = p.parse_args()
root = Path(__file__).resolve().parents[3]
fixtures = Path(__file__).resolve().parent
env = dict(os.environ, VEXE=str(a.v), V_C_ERROR_BUG_REPORT_DISABLED='1', EM_CONFIG=str(a.em_config))
with tempfile.TemporaryDirectory(prefix='witty-wasm-log-') as directory:
    tmp = Path(directory)
    (tmp/'os/wasm').mkdir(parents=True)
    for relative in ['os/wasm.zig', 'os/wasm/log.zig']:
        shutil.copyfile(a.ghostty/'src'/relative, tmp/relative)
    (tmp/'source.zig').write_text('pub const log = @import("os/wasm/log.zig").log;\n')
    (tmp/'options.zig').write_text('pub const wasm_shared = false;\n')
    for mode, flags in [('Debug', []), ('ReleaseSafe', ['-d', 'release_safe']),
                        ('ReleaseFast', ['-prod']), ('ReleaseSmall', ['-prod', '-d', 'release_small'])]:
        original = tmp/f'original-{mode}.wasm'
        translated = tmp/f'translated-{mode}.js'
        subprocess.run([str(a.zig), 'build-exe', '-O', mode, '-target', 'wasm32-freestanding',
                        '-fno-entry', '-rdynamic', '-femit-bin='+str(original), '--dep', 'source_log',
                        '-Mroot='+str(fixtures/'log.zig'), '--dep', 'build_options',
                        '-Msource_log='+str(tmp/'source.zig'), '-Mbuild_options='+str(tmp/'options.zig')], check=True)
        subprocess.run([str(a.v), '-path', str(root)+'|@vlib|@vmodules', '-os', 'wasm32_emscripten',
                        '-gc', 'none', '-d', 'no_simd', '-d', 'no_sentry', '-d', 'no_i18n', *flags,
                        '-cc', str(a.emcc), '-ldflags', '-sSTANDALONE_WASM=1 --no-entry -sMODULARIZE=1 '
                        '-sGLOBAL_BASE=65536 -sEXPORTED_FUNCTIONS=_probe_log --js-library='+str(root/'wasm_log/host.js'),
                        '-o', str(translated), str(fixtures/'log.v')], cwd=root, env=env, check=True)
        subprocess.run(['node', str(fixtures/'compare_log.cjs'), str(original), str(translated), mode], check=True)
