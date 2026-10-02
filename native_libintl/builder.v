module native_libintl

import os

pub const gettext_version = '0.24'
pub const gettext_source_hash = 'N-V-__8AADcZkgn4cMhTUpIz6mShCKyqqB-NBtf_S2bHaTC-'

// This is the exact pkg/libintl/build.zig source list. The package supplies
// Darwin's libintl; other Ghostty targets use their selected system gettext.
pub const sources = [
	'bindtextdom.c', 'dcgettext.c', 'dcigettext.c', 'dcngettext.c', 'dgettext.c',
	'dngettext.c', 'explodename.c', 'finddomain.c', 'gettext.c', 'hash-string.c',
	'intl-compat.c', 'l10nflist.c', 'langprefs.c', 'loadmsgcat.c', 'localealias.c',
	'log.c', 'ngettext.c', 'plural-exp.c', 'plural.c', 'setlocale.c', 'textdomain.c',
	'version.c', 'compat.c', 'gnulib-lib/getlocalename_l-unsafe.c',
	'gnulib-lib/localename.c', 'gnulib-lib/localename-environ.c',
	'gnulib-lib/localename-unsafe.c', 'gnulib-lib/setlocale-lock.c',
	'gnulib-lib/setlocale_null.c', 'gnulib-lib/setlocale_null-unlocked.c',
]!

pub fn archive_path(repo_root string) string {
	return os.join_path(repo_root, '.witty-build', 'native', 'libintl.a')
}

pub fn build(repo_root string, compiler string, compiler_args []string) !string {
	root := os.join_path(repo_root, 'thirdparty', 'libintl')
	output := os.join_path(repo_root, '.witty-build', 'native', 'intl-objects')
	os.mkdir_all(output)!
	mut objects := []string{cap: sources.len}
	for source in sources {
		object := os.join_path(output, source.replace('/', '_') + '.o')
		mut args := compiler_args.clone()
		args << ['-DHAVE_CONFIG_H', '-DLOCALEDIR=""', '-I' + root, '-I' + os.join_path(root, 'src'),
			'-I' + os.join_path(root, 'src', 'gnulib-lib'), '-c', os.join_path(root, 'src', source), '-o', object]
		run(compiler, args)!
		objects << object
	}
	archive := archive_path(repo_root)
	mut archive_args := ['rcs', archive]
	archive_args << objects
	run('ar', archive_args)!
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
