// This generates data that is used by the build process.
//
// Translated from ghostty/src/main_build_data.zig.
//
// Ghostty builds this as a separate executable that the build runs with a
// `+action` argument, writing the artifact to stdout. Witty has no Zig build
// system, so it follows the same convention as `helpgen.v`: the generators are
// plain functions here, exercised by tests, for a build to call.
//
module main

import extra
import terminfo

// BuildDataAction is the complete set of artifacts emitted by the source
// command, in source declaration order.
pub enum BuildDataAction {
	// Shell completions
	bash
	fish
	zsh

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
		.bash { 'bash' }
		.fish { 'fish' }
		.zsh { 'zsh' }
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
	for action in [BuildDataAction.bash, .fish, .zsh, .sublime, .vim_syntax, .vim_ftdetect,
		.vim_ftplugin, .vim_compiler, .terminfo] {
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
		.bash { extra.bash_completions() }
		.fish { extra.fish_completions() }
		.zsh { extra.zsh_completions() }
		.sublime { extra.sublime_syntax() }
		.vim_syntax { extra.syntax() }
		.vim_ftdetect { extra.ftdetect }
		.vim_ftplugin { extra.ftplugin }
		.vim_compiler { extra.compiler }
		.terminfo { terminfo.ghostty.encode() }
	}
}
