module main

fn test_helpgen_extracts_config_fields() {
	help := gen_config()
	assert help.entries.len > 100
	assert help.entries[0].name == 'font_size'
	assert help.entries.any(it.name == 'image_storage_limit')
}

fn test_helpgen_extracts_cli_actions() {
	help := gen_actions()
	assert help.entries.len > 10
	assert help.entries[0].name == 'none'
	assert help.entries.any(it.name == 'list_themes')
	assert help.entries.any(it.name == 'crash_report')
}

fn test_helpgen_extracts_keybind_docs() {
	help := gen_keybind_actions()
	assert help.entries.len > 50
	ignore := help.entries.filter(it.name == 'ignore')
	assert ignore.len == 1
	assert ignore[0].text == 'Ignore this key combination.'
	assert help.entries.any(it.name == 'crash')
}

fn test_find_common_prefix_ignores_empty_lines() {
	assert find_common_prefix(['  first', '', '    second']) == 2
}
