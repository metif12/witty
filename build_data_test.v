module main

import crypto.sha256

fn test_build_data_action_names_match_source_spellings() {
	// These are the `+action` spellings main_build_data.zig accepts.
	assert BuildDataAction.bash.name() == 'bash'
	assert BuildDataAction.fish.name() == 'fish'
	assert BuildDataAction.zsh.name() == 'zsh'
	assert BuildDataAction.sublime.name() == 'sublime'
	assert BuildDataAction.vim_syntax.name() == 'vim-syntax'
	assert BuildDataAction.vim_ftdetect.name() == 'vim-ftdetect'
	assert BuildDataAction.vim_ftplugin.name() == 'vim-ftplugin'
	assert BuildDataAction.vim_compiler.name() == 'vim-compiler'
	assert BuildDataAction.terminfo.name() == 'terminfo'
}

fn test_build_data_action_parses_with_and_without_plus() {
	assert build_data_action('terminfo')? == .terminfo
	assert build_data_action('+terminfo')? == .terminfo
	assert build_data_action('+vim-ftplugin')? == .vim_ftplugin
	assert build_data_action('bash')? == .bash
	assert build_data_action('+fish')? == .fish
	assert build_data_action('zsh')? == .zsh
	assert build_data_action('nonsense') == none
}

fn test_generate_build_data_emits_each_artifact() {
	terminfo_src := generate_build_data(.terminfo)
	assert terminfo_src.starts_with('xterm-ghostty|ghostty|Ghostty,\n')
	assert terminfo_src.contains('\tam,\n')

	assert generate_build_data(.sublime).starts_with('%YAML 1.2\n')
	assert generate_build_data(.vim_syntax).starts_with('" Vim syntax file\n')
	assert generate_build_data(.vim_ftdetect).contains('setf ghostty')
	assert generate_build_data(.vim_ftplugin).contains('let b:did_ftplugin = 1')
	assert generate_build_data(.vim_compiler).contains('let current_compiler = "ghostty"')
}

fn test_generate_build_data_matches_pinned_ghostty_byte_for_byte() {
	// Hashes are from ghostty-build-data built at the pinned reference commit.
	expected := {
		BuildDataAction.bash:         'd54cd2e625f2fa3159e9d5be60e0694643b257c56cbfd7163031107b082cdfa9'
		BuildDataAction.fish:         '0710c138ebd53520bb7b9a03f44b7dba76c02916af24966ba77ca5c3638d64a2'
		BuildDataAction.zsh:          '0fe61025e35e673e05b95c2c1785bb8030e320e16dc8c7eac5f2eafdd09e0769'
		BuildDataAction.sublime:      '200c97530ddaa9e093bbfe006e83307934d8e69b7cfd1a4b8ded64361e5c6668'
		BuildDataAction.vim_syntax:   '072ffea05c6a08e923daeaae9dd5418dde8640d0a8bfca6496680d1b21f87654'
		BuildDataAction.vim_ftdetect: '080ebfbba18da85a36ca637429dc524c0726f445980ac28463fb8e91fc309447'
		BuildDataAction.vim_ftplugin: 'd5725ccfcf8e482afb37d758331e2afb059c6725e9c5ae5b3a0e246e1b46a739'
		BuildDataAction.vim_compiler: '4fd2b1d1ad0597e3b6419066f368f3bc76f2e3f09eed3ef9206e8bcc58b955f3'
		BuildDataAction.terminfo:     '9f5732d1a960c3330479dcb42f3e2d38e9d5572912b9ee069f7a8a44799efd23'
	}
	for action, digest in expected {
		actual := sha256.sum(generate_build_data(action).bytes()).hex()
		assert actual == digest, '${action.name()} output drifted from pinned Ghostty'
	}
}
