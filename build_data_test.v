module main

fn test_build_data_action_names_match_source_spellings() {
	// These are the `+action` spellings main_build_data.zig accepts.
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
	assert build_data_action('bash') == none
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
