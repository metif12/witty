module native_sentry

import os

pub struct Options {
pub:
	c_compiler    string = 'cc'
	cpp_compiler  string = 'c++'
	compiler_args []string
	os_tag        string = os.user_os()
}

pub fn archive_path(repo_root string, name string) string {
	return os.join_path(repo_root, '.witty-build', 'native', 'lib${name}.a')
}

// Source: pkg/sentry/build.zig and pkg/breakpad/build.zig, as selected by
// SharedDeps (.breakpad backend; .none transport). No network transport links.
pub fn build(repo_root string, options Options) ![]string {
	if options.os_tag !in ['macos', 'ios', 'linux'] { return error('UnsupportedTarget') }
	mut breakpad_sources := breakpad_common[..].clone()
	if options.os_tag in ['macos', 'ios'] {
		breakpad_sources << breakpad_common_apple[..]
		breakpad_sources << breakpad_client_apple[..]
		if options.os_tag == 'macos' {
			breakpad_sources << breakpad_common_mac[..]
			breakpad_sources << breakpad_client_mac[..]
		} else {
			breakpad_sources << breakpad_client_ios[..]
		}
	} else {
		breakpad_sources << breakpad_common_linux[..]
		breakpad_sources << breakpad_client_linux[..]
	}
	breakpad_root := os.join_path(repo_root, 'thirdparty', 'breakpad')
	vendor := os.join_path(repo_root, 'thirdparty', 'breakpad-vendor')
	breakpad_archive := compile_archive(repo_root, 'breakpad', breakpad_root, breakpad_sources,
		['-I' + vendor, '-I' + os.join_path(breakpad_root, 'src')], options)!
	mut sentry_sources := sentry_common[..].clone()
	sentry_sources << ['src/sentry_unix_pageallocator.c', 'src/path/sentry_path_unix.c',
		'src/symbolizer/sentry_symbolizer_unix.c', 'src/unwinder/sentry_unwinder_libbacktrace.c',
		'src/transports/sentry_transport_none.c', 'src/backends/sentry_backend_breakpad.cpp']
	if options.os_tag == 'linux' {
		sentry_sources << ['vendor/stb_sprintf.c', 'src/modulefinder/sentry_modulefinder_linux.c']
	} else {
		sentry_sources << 'src/modulefinder/sentry_modulefinder_apple.c'
	}
	sentry_root := os.join_path(repo_root, 'thirdparty', 'sentry')
	sentry_archive := compile_archive(repo_root, 'sentry', sentry_root, sentry_sources,
		['-DSENTRY_WITH_UNWINDER_LIBBACKTRACE', '-DSENTRY_BACKEND_BREAKPAD',
			'-I' + os.join_path(sentry_root, 'include'), '-I' + os.join_path(sentry_root, 'src'),
			'-I' + os.join_path(breakpad_root, 'src'), '-I' + vendor], options)!
	return [sentry_archive, breakpad_archive]
}

fn compile_archive(repo_root string, name string, source_root string, sources []string, flags []string, options Options) !string {
	output := os.join_path(repo_root, '.witty-build', 'native', name + '-objects')
	os.mkdir_all(output)!
	mut objects := []string{cap: sources.len}
	for source in sources {
		object := os.join_path(output, source.replace('/', '_') + '.o')
		mut args := options.compiler_args.clone()
		args << flags
		cpp := source.ends_with('.cpp') || source.ends_with('.cc') || source.ends_with('.mm')
		if cpp { args << '-std=c++17' }
		args << ['-c', os.join_path(source_root, source), '-o', object]
		run(if cpp { options.cpp_compiler } else { options.c_compiler }, args)!
		objects << object
	}
	archive := archive_path(repo_root, name)
	if os.exists(archive) { os.rm(archive)! }
	mut args := ['rcs', archive]
	args << objects
	run('ar', args)!
	return archive
}

fn run(executable string, args []string) ! {
	mut process := os.new_process(executable)
	process.set_args(args)
	process.set_redirect_stdio()
	process.run()
	output := process.stdout_slurp()
	errors := process.stderr_slurp()
	process.wait()
	code := process.code
	process.close()
	if code != 0 { return error('${executable} failed (${code}): ${output}${errors}') }
}
