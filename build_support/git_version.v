module build_support

import os

// src/build/GitVersion.zig. Detection belongs to the build process; resulting
// values are passed to the compilation as generated build options.
pub struct GitVersion {
pub:
	short_hash string
	changes    bool
	tag        ?string
	branch     string
}

fn git_run(root string, args []string) !os.Result {
	os.find_abs_path_of_executable('git') or { return error('GitNotFound') }
	mut command := ['git', '-C', root]
	command << args
	mut process := os.new_process(command[0])
	process.set_args(command[1..])
	process.set_redirect_stdio()
	process.run()
	output := process.stdout_slurp()
	process.stderr_slurp()
	process.wait()
	result := os.Result{
		exit_code: process.code
		output:    output
	}
	process.close()
	return result
}

pub fn detect_git_version(root string) !GitVersion {
	branch_result := git_run(root, ['rev-parse', '--abbrev-ref', 'HEAD'])!
	if branch_result.exit_code != 0 { return error('GitNotRepository') }
	branch := branch_result.output.replace('/', '-').trim_right('\r\n ')
	hash_result := git_run(root, ['log', '--pretty=format:%h', '-n', '1'])!
	if hash_result.exit_code != 0 { return error('ExitCodeFailure') }
	tag_result := git_run(root, ['describe', '--exact-match', '--tags'])!
	tag := if tag_result.exit_code == 0 && tag_result.output.len > 0 {
		?string(tag_result.output.trim_right('\r\n '))
	} else {
		?string(none)
	}
	diff_result := git_run(root, ['diff', '--quiet', '--exit-code'])!
	return GitVersion{
		short_hash: hash_result.output.trim_right('\r\n ')
		changes:    diff_result.exit_code != 0
		tag:        tag
		branch:     branch
	}
}

// src/build/Config.zig version block. Dirty state is exposed separately, as
// the original does; it does not add an invented semantic-version suffix.
pub fn version_from_git(base string, git GitVersion) !string {
	if tag := git.tag {
		if tag != 'tip' {
			if tag != 'v${base}' {
				return error('tagged releases must be in vX.Y.Z format matching build.zig')
			}
			return base
		}
	}
	return '${base}-${git.branch}+${git.short_hash}'
}

pub fn detect_version(root string, base string) !string {
	git := detect_git_version(root) or {
		if err.msg() in ['GitNotFound', 'GitNotRepository'] { return '${base}-dev+0000000' }
		return err
	}
	return version_from_git(base, git)
}
