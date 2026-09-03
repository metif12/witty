module input

fn test_generate_help_action_names() {
	help := generate_help(.plaintext, false)
	assert help.starts_with('ignore\nunbind\ncsi\n')
	assert help.contains('toggle_command_palette\n')
	assert help.ends_with('crash\n')
}

fn test_generate_help_plaintext_docs() {
	help := generate_help(.plaintext, true)
	assert help.starts_with('ignore:\n  Ignore this key combination.\n')
	assert help.contains('new_window:\n  Open a new window.\n')
}

fn test_generate_help_markdown() {
	help := generate_help(.markdown, true)
	assert help.starts_with('---\ntitle: Keybinding Action Reference\n')
	assert help.contains('## `copy_to_clipboard`\nCopy the selected text to the clipboard.\n')
}
