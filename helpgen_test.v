module main

fn test_helpgen_extracts_config_fields() {
	help := gen_config()
	assert help.entries.len > 100
	assert help.entries[0].name == 'font-family'
	assert help.entries.any(it.name == 'image-storage-limit')
	assert help.entries.all(!it.name.starts_with('_'))
}

fn test_helpgen_extracts_cli_actions() {
	help := gen_actions()
	assert help.entries.len == 15
	assert help.entries[0].name == 'version'
	assert help.entries.any(it.name == 'list-themes')
	crash := help.entries.filter(it.name == 'crash-report')
	assert crash.len == 1
	assert crash[0].text.contains('Viewing\nand sending crash reports is unimplemented')
}

fn test_helpgen_extracts_keybind_docs() {
	help := gen_keybind_actions()
	assert help.entries.len == 83
	ignore := help.entries.filter(it.name == 'ignore')
	assert ignore.len == 1
	assert ignore[0].text.contains('Ghostty will not process this combination')
	assert help.entries.any(it.name == 'crash')
}

fn test_generated_help_parser_preserves_blank_and_indented_lines() {
	entries := generated_help_entries('@@one\nfirst\n\n  second\n@@two\nlast', '@@')
	assert entries == [
		HelpEntry{ name: 'one', text: 'first\n\n  second' },
		HelpEntry{ name: 'two', text: 'last' },
	]
}
