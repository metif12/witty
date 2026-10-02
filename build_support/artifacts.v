module build_support

import os

fn compiler_argument(value string) string {
	// V accepts a string of C flags; its C compiler command still needs shell
	// quoting even though the outer build invocation uses structured argv.
	return "'" + value.replace("'", "'\\''") + "'"
}

pub fn (d Driver) v_arguments(artifact Artifact, deps NativeDeps) ![]string {
	mut args := [d.cfg.compiler, '-path', '${d.cfg.root}|@vlib|@vmodules', '-cc', os.getenv_opt('CC') or {
		'clang'
	},
		'-d', 'managed_native']
	args << d.cfg.options(artifact)!
	for define in deps.defines {
		args << ['-d', define]
	}
	os_name := if d.cfg.target.os == 'ios' { 'ios' } else { d.cfg.target.os }
	args << ['-os', os_name]
	if d.cfg.target.arch in ['aarch64', 'x86_64', 'x86'] {
		args << ['-arch', match d.cfg.target.arch {
			'aarch64' { 'arm64' }
			'x86_64' { 'amd64' }
			else { 'i386' }
		}]
	}
	for argument in d.cfg.sdk_arguments()! {
		args << ['-cflags', compiler_argument(argument)]
	}
	if d.cfg.target.abi == 'gnu' { args << '-glibc' }
	if d.cfg.target.abi == 'musl' { args << '-musl' }
	for argument in deps.compiler_flags {
		args << ['-cflags', compiler_argument(argument)]
	}
	for archive in deps.archives {
		args << ['-ldflags', compiler_argument(archive)]
	}
	for flag in deps.link_flags {
		args << ['-ldflags', compiler_argument(flag)]
	}
	return args
}

fn (d Driver) stage_sources(name string, filenames []string) !string {
	path := d.cache_path('staging', name)
	os.mkdir_all(path)!
	mut imports := []string{}
	mut bodies := []string{}
	for filename in filenames {
		if filename.ends_with('_darwin.v') && !d.cfg.target.darwin() { continue
		 }
		text := os.read_file(os.join_path(d.cfg.root, filename))!
		mut body := []string{}
		for line in text.split('\n') {
			if line == 'module main' { continue
			 }
			if line.starts_with('import ') {
				if line !in imports { imports << line }
			} else {
				body << line
			}
		}
		bodies << body.join('\n')
	}
	// Directory builds qualify the module by its containing directories. A
	// single no_main compilation unit preserves V's exported-function runtime
	// initializer and lazy reachability; function bodies are copied unchanged.
	output := os.join_path(path, name + '.v')
	os.write_file(output, 'module no_main\n\n' + imports.join('\n') + '\n\n' + bodies.join('\n\n'))!
	return output
}

pub fn (d Driver) build_vt() !string {
	deps := d.build_native_dependencies(true)!
	source := d.stage_sources('vt', ['lib_vt.v', 'lib_vt_c.v'])!
	mut args :=
		d.v_arguments(if d.cfg.target.wasm() { Artifact.wasm_module } else { Artifact.lib }, deps)!
	args << ['-d', 'no_oniguruma', '-d', 'no_i18n', '-d', 'no_sentry']
	if !d.cfg.target.wasm() { args = args.filter(it != '-shared') }
	extension := if d.cfg.target.wasm() {
		'.wasm'
	} else if d.cfg.target.os == 'windows' {
		'.dll'
	} else if d.cfg.target.darwin() {
		'.dylib'
	} else {
		'.so'
	}
	output := d.cache_path('artifacts', 'libghostty-vt' + extension)
	os.mkdir_all(os.dir(output))!
	if !d.cfg.target.wasm() {
		object := output + '.o'
		args << ['-is_o', '-cflags', '-fPIC', '-o', object, source]
		checked_process(d.cfg.root, args)!
		d.link_library(object, output, deps)!
	} else {
		args << ['-o', output, source]
		checked_process(d.cfg.root, args)!
	}
	if !d.cfg.target.wasm() {
		d.install_file(output, 'lib/' + os.base(output))!
		d.install_tree(os.join_path(d.cfg.root, 'include', 'ghostty'), 'include/ghostty', [])!
		pc :=
			'prefix=${d.cfg.prefix}\nincludedir=\x24{prefix}/include\nlibdir=\x24{prefix}/lib\n\n' +
			'Name: libghostty-vt\nURL: https://github.com/ghostty-org/ghostty\nDescription: Ghostty VT library\n' +
			'Version: 0.1.0\nCflags: -I\x24{includedir}\nLibs: -L\x24{libdir} -lghostty-vt'
		d.install_text('share/pkgconfig/libghostty-vt.pc', pc)!
		if d.cfg.target.darwin() {
			checked_process(d.cfg.root, ['dsymutil', output, '-o', output + '.dSYM'])!
		}
	} else {
		d.install_file(output, 'bin/ghostty-vt.wasm')!
	}
	return output
}

pub fn (d Driver) build_library(deps NativeDeps, static_ bool) !string {
	source := d.stage_sources('lib', ['main_c.v', 'embedded_c.v', 'embedded_c_darwin.v', 'config_c.v',
		'build_config.v'])!
	mut args := d.v_arguments(.lib, deps)!
	args = args.filter(it != '-shared')
	object := d.cache_path('artifacts', 'libghostty.o')
	os.mkdir_all(os.dir(object))!
	args << ['-is_o', '-cflags', '-fPIC', '-o', object, source]
	checked_process(d.cfg.root, args)!
	if !static_ {
		extension := if d.cfg.target.os == 'windows' {
			'.dll'
		} else if d.cfg.target.darwin() {
			'.dylib'
		} else {
			'.so'
		}
		output := d.cache_path('artifacts', 'libghostty' + extension)
		d.link_library(object, output, deps)!
		if d.cfg.target.darwin() {
			checked_process(d.cfg.root, ['dsymutil', output, '-o', output + '.dSYM'])!
		}
		return output
	}
	archive := d.cache_path('artifacts', 'libghostty.a')
	if os.exists(archive) { os.rm(archive)! }
	if d.cfg.target.darwin() {
		mut command := ['libtool', '-static', '-o', archive]
		command << deps.archives
		command << d.runtime_archive()!
		command << object
		checked_process(d.cfg.root, command)!
	} else {
		checked_process(d.cfg.root, ['ar', 'rcs', archive, object])!
	}
	return archive
}

pub fn (d Driver) build_executable(deps NativeDeps) !string {
	if d.cfg.target.os == 'linux' && d.cfg.target.arch == host_target().arch
		&& os.exists('/etc/NIXOS') && os.getenv_opt('IN_NIX_SHELL') == none {
		return error('Detected building on and for NixOS outside of the Nix shell environment. Run nix develop -c v run tools/build.')
	}
	mut args := d.v_arguments(.exe, deps)!
	output := d.cache_path('artifacts', 'ghostty' + if d.cfg.target.os == 'windows' {
		'.exe'
	} else {
		''
	})
	os.mkdir_all(os.dir(output))!
	args << ['-o', output, d.cfg.root]
	checked_process(d.cfg.root, args)!
	if value := d.cfg.patch_rpath {
		if value.len > 0 {
			checked_process(d.cfg.root, ['patchelf', '--set-rpath', value, output])!
		}
	}
	if d.cfg.strip { checked_process(d.cfg.root, ['strip', output])! }
	return output
}

fn (d Driver) link_library(object string, output string, deps NativeDeps) ! {
	mut command := [os.getenv_opt('CC') or { 'clang' }]
	command << d.cfg.sdk_arguments()!
	command << [if d.cfg.target.darwin() { '-dynamiclib' } else { '-shared' }, '-o', output, object]
	command << deps.archives
	command << deps.link_flags
	command << d.runtime_archive()!
	if !d.cfg.target.darwin() && d.cfg.target.os != 'windows' {
		command << ['-lpthread', '-ldl', '-lm']
	}
	checked_process(d.cfg.root, command)!
}

// Compiler runtime adaptation: use the selected V compiler's unchanged GC
// source with the artifact's target. A prebuilt host archive cannot be used
// in retargeted static libraries or XCFramework slices.
fn (d Driver) runtime_archive() !string {
	root := os.join_path(os.dir(os.real_path(d.cfg.compiler)), 'thirdparty', 'libgc')
	mut flags := ['-I' + os.join_path(root, 'include'), '-DGC_THREADS=1', '-DTHREAD_LOCAL_ALLOC=1',
		'-DGC_BUILTIN_ATOMIC=1', '-DALL_INTERIOR_POINTERS=1', '-DNO_EXECUTE_PERMISSION=1', '-fPIC']
	if d.cfg.target.darwin() { flags << '-DMPROTECT_VDB=1' }
	if d.cfg.target.os == 'windows' { flags << ['-DGC_NOT_DLL=1', '-DGC_WIN32_THREADS=1'] }
	if d.cfg.target.os == 'freebsd' { flags << ['-DBUS_PAGE_FAULT=T_PAGEFLT', '-DUSE_MMAP'] }
	return d.compile_native('v-runtime-gc', root, ['gc.c'], NativeCompileOptions{
		compiler:  os.getenv_opt('CC') or { 'clang' }
		arguments: d.cfg.sdk_arguments()!
	}, flags)
}
