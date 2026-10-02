module build_support

import semver

pub enum Mode {
	debug
	release_safe
	release_fast
	release_small
}

pub enum Artifact {
	exe
	lib
	wasm_module
}

// src/build/Config.zig addOptions/fromOptions and src/build_config.zig.
// These values describe the compile being scheduled, rather than the build
// driver's own compiler mode.
pub fn compile_options(root string, mode Mode, artifact Artifact, explicit_version ?string) ![]string {
	version := if value := explicit_version { value } else { detect_version(root, '1.3.0')! }
	parsed := semver.from(version)!
	git := detect_git_version(root) or {
		GitVersion{
			short_hash: '0000000'
			branch:     'dev'
		}
	}
	mut args := [
		'-d',
		'app_version_string=${version}',
		'-d',
		'release_channel=${if parsed.prerelease.len == 0 { 'stable' } else { 'tip' }}',
		'-d',
		'commit_hash=${git.short_hash}',
		'-d',
		'git_branch=${git.branch}',
		'-d',
		'git_changes=${git.changes}',
	]
	match mode {
		.debug { args << '-g' }
		.release_safe { args << ['-d', 'release_safe', '-cflags', '-O2'] }
		.release_fast { args << '-prod' }
		.release_small { args << ['-prod', '-no-prod-options', '-cflags', '-Os'] }
	}

	match artifact {
		.exe {}
		.lib { args << ['-shared', '-d', 'ghostty_lib'] }
		.wasm_module { args << ['-b', 'wasm', '-d', 'ghostty_wasm_module'] }
	}

	return args
}
