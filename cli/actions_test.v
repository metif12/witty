module cli

import os

fn test_list_colors_plain_contains_complete_sorted_x11_data() {
	output := list_colors_output(['--plain'])!
	lines := output.trim_space().split_into_lines()
	assert lines.len == 782
	assert lines[0] == 'alice blue = #f0f8ff'
	assert lines[1] == 'AliceBlue = #f0f8ff'
	assert output.contains('RebeccaPurple = #663399\n')
	assert output.contains('yellow green = #9acd32\n')
}

fn test_list_colors_rejects_unknown_options() {
	list_colors_output(['--wat']) or {
		assert err.msg().contains('unknown option')
		return
	}
	assert false
}

fn test_list_keybinds_default_is_valid_config_syntax() {
	output := list_keybinds_output(['--default', '--plain'])!
	assert output.len > 0
	assert output.contains('keybind = ')
	assert output.contains('=new_window\n')
}

fn test_format_font_list_sorts_unfiltered_and_preserves_filtered_priority() {
	entries := [
		FontListEntry{ family: 'Zulu', name: 'Zulu Bold' },
		FontListEntry{ family: 'Alpha', name: 'Alpha Italic' },
		FontListEntry{ family: 'Alpha', name: 'Alpha Regular' },
	]
	assert format_font_list(entries, true) == 'Alpha\n  Alpha Italic\n  Alpha Regular\n\nZulu\n  Zulu Bold\n\n'
	assert format_font_list(entries, false) == 'Zulu\n  Zulu Bold\n\nAlpha\n  Alpha Italic\n  Alpha Regular\n\n'
}

fn test_list_fonts_options() {
	opts := parse_list_fonts_options(['--family=JetBrains Mono', '--style', 'Italic', '--bold',
		'--italic'])!
	assert opts.family? == 'JetBrains Mono'
	assert opts.style? == 'Italic'
	assert opts.bold
	assert opts.italic
}

fn test_validate_config_specific_file() {
	dir := os.join_path(os.temp_dir(), 'witty-cli-validate-${os.getpid()}')
	os.rmdir_all(dir) or {}
	os.mkdir_all(dir)!
	defer {
		os.rmdir_all(dir) or {}
	}
	valid_path := os.join_path(dir, 'valid.conf')
	os.write_file(valid_path, 'font-size = 14\n')!
	valid := validate_config(['--config-file', valid_path])!
	assert valid.code == 0
	assert valid.output == ''

	invalid_path := os.join_path(dir, 'invalid.conf')
	os.write_file(invalid_path, 'no-such-option = true\n')!
	invalid := validate_config(['--config-file=${invalid_path}'])!
	assert invalid.code == 1
	assert invalid.output.contains('no-such-option: unknown field')
}

fn test_choose_editor_prefers_visual_and_ignores_empty_values() {
	assert choose_editor('nvim', 'vim') == 'nvim'
	assert choose_editor('', 'vim') == 'vim'
	assert choose_editor('', '') == ''
}

fn test_edit_config_target_creates_parent_directory() {
	dir := os.join_path(os.temp_dir(), 'witty-cli-edit-${os.getpid()}')
	os.rmdir_all(dir) or {}
	defer {
		os.rmdir_all(dir) or {}
	}
	path := os.join_path(dir, 'ghostty', 'config.ghostty')
	ensure_config_parent(path)!
	assert os.is_dir(os.dir(path))
}

fn test_show_config_changes_only_and_full_default() {
	full := show_config_output(['--default'])!
	assert full.contains('font-size = 13.0\n')
	assert full.contains('background = #282c34\n')
	assert full.contains('palette = 255=#eeeeee\n')
	assert full.contains('keybind = ')

	opts := parse_show_config_options(['--changes-only=false', '--docs'])!
	assert !opts.changes_only
	assert opts.docs
}

fn test_show_config_changes_only_false_outputs_every_field() {
	output := show_config_output(['--changes-only=false'])!
	assert output.contains('font-size = 13.0\n')
	assert output.contains('config-default-files = true\n')
}

fn test_show_config_rejects_config_and_unknown_options() {
	show_config_output(['--font-size=19']) or {
		assert err.msg().contains('unknown option')
		return
	}
	assert false
}

fn test_show_config_docs_comments_documented_fields() {
	output := show_config_output(['--default', '--docs'])!
	assert output.starts_with('# The font families to use.\n')
	assert output.contains('# Font size in points. This value can be a non-integer')
	assert output.contains('\nfont-size = 13.0\n\n')
}

fn test_show_face_options_and_required_input() {
	opts := parse_show_face_options(['--cp=0x41', '--style=bold_italic', '--presentation=text',
		'--font-family=Menlo'])!
	assert opts.cp? == 65
	assert opts.style == .bold_italic
	assert opts.presentation? == .text
	assert opts.config_args == ['--font-family=Menlo']

	missing := show_face([])!
	assert missing.code == 1
	assert missing.errors.contains('You must specify a codepoint')
}

fn test_show_face_codepoint_bases_and_invalid_values() {
	assert parse_show_face_codepoint('65')? == 65
	assert parse_show_face_codepoint('0x41')? == 65
	assert parse_show_face_codepoint('0o101')? == 65
	assert parse_show_face_codepoint('0b1000001')? == 65
	assert parse_show_face_codepoint('0x200000') == none
	assert parse_show_face_codepoint('wat') == none
}

fn test_show_face_resolves_embedded_face_and_sprites() {
	text := show_face(['--cp=65', '--config-default-files=false'])!
	assert text.code == 0
	assert text.output.contains('U+41 « A » found in face')

	sprite := show_face(['--cp=0x2500', '--config-default-files=false'])!
	assert sprite.code == 0
	assert sprite.output.contains("handled by Ghostty's internal sprites")
}
