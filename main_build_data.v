// This generates data that is used by the build process.
//
// Translated from ghostty/src/main_build_data.zig.
//
// Ghostty builds this as a separate executable that the build runs with a
// `+action` argument, writing the artifact to stdout. Witty has no Zig build
// system, so it follows the same convention as `helpgen.v`: the generators are
// plain functions here, exercised by tests, for a build to call.
//
// The source's `Action` also has `bash`, `fish` and `zsh` for shell
// completions. Those generators reflect over `Config`'s field types to pick a
// completion strategy per field, and the V compiler miscompiles that
// reflection over a struct of `Config`'s size, so they are absent rather than
// stubbed. See AUDIT_FINDINGS.md for the specific failures.
module main

import extra
import terminfo

// BuildDataAction is the set of artifacts this can emit. It is
// `main_build_data.Action` minus the three shell completions.
pub enum BuildDataAction {
	// Editor syntax files
	sublime
	vim_syntax
	vim_ftdetect
	vim_ftplugin
	vim_compiler

	// Other
	terminfo
}

// build_data_action_name is the `+action` spelling for an action, matching the
// source's enum field names.
pub fn (action BuildDataAction) name() string {
	return match action {
		.sublime { 'sublime' }
		.vim_syntax { 'vim-syntax' }
		.vim_ftdetect { 'vim-ftdetect' }
		.vim_ftplugin { 'vim-ftplugin' }
		.vim_compiler { 'vim-compiler' }
		.terminfo { 'terminfo' }
	}
}

// build_data_action parses a `+action` spelling, or none if unrecognized.
pub fn build_data_action(name string) ?BuildDataAction {
	trimmed := name.trim_string_left('+')
	for action in [BuildDataAction.sublime, .vim_syntax, .vim_ftdetect, .vim_ftplugin,
		.vim_compiler, .terminfo] {
		if action.name() == trimmed {
			return action
		}
	}
	return none
}

// generate_build_data returns the artifact for the given action. The source
// writes this to stdout.
pub fn generate_build_data(action BuildDataAction) string {
	return match action {
		.sublime { extra.sublime_syntax() }
		.vim_syntax { extra.syntax() }
		.vim_ftdetect { extra.ftdetect }
		.vim_ftplugin { extra.ftplugin }
		.vim_compiler { extra.compiler }
		.terminfo { terminfo.ghostty_terminfo.encode() }
	}
}
