module configpkg

import terminal

// Generated from the documentation comments in the pinned Ghostty
// config/Config.zig. Records are separated by ASCII record separators so the
// Markdown remains byte-for-byte data rather than V string literals.
const config_help_data = $embed_file('config_help.txt').to_string()

struct ConfigEntryGroup {
	key    string
	values []string
}

// format_config returns this configuration in Ghostty's file syntax. With
// changes_only enabled, fields are compared after finalization against the
// platform defaults and only semantically changed fields are emitted.
pub fn (c Config) format_config(changes_only bool) string {
	return c.format_config_with_docs(changes_only, false)
}

// format_config_with_docs is Ghostty's FileFormatter: it emits each modeled
// public configuration field and optionally places its generated help text
// immediately above the field as configuration comments.
pub fn (c Config) format_config_with_docs(changes_only bool, docs bool) string {
	groups := config_entry_groups(c)
	mut default_values := map[string][]string{}
	if changes_only {
		for group in config_entry_groups(Config.default_config()) {
			default_values[group.key] = group.values
		}
	}
	mut lines := []string{}
	for group in groups {
		if changes_only && group.values == (default_values[group.key] or { []string{} }) {
			continue
		}
		mut documented := false
		if docs {
			if help := config_help(group.key) {
				for line in help.split('\n') {
					lines << '# ${line}'
				}
				documented = true
			}
		}
		for value in group.values {
			lines << '${group.key} = ${value}'
		}
		if documented {
			lines << ''
		}
	}
	if lines.len == 0 {
		return ''
	}
	return lines.join('\n') + '\n'
}

fn config_help(key string) ?string {
	marker := '\x1e${key}\n'
	marker_index := config_help_data.index(marker) or { return none }
	start := marker_index + marker.len
	rest := config_help_data[start..]
	end := rest.index_u8(30)
	value := if end < 0 { rest } else { rest[..end] }
	return value.trim_string_right('\n')
}

fn config_entry_groups(c Config) []ConfigEntryGroup {
	mut result := []ConfigEntryGroup{}
	add_group(mut result, 'font-family', repeat_strings(c.font_family))
	add_group(mut result, 'font-family-bold', repeat_strings(c.font_family_bold))
	add_group(mut result, 'font-family-italic', repeat_strings(c.font_family_italic))
	add_group(mut result, 'font-family-bold-italic', repeat_strings(c.font_family_bold_italic))
	add_group(mut result, 'font-style', [c.font_style])
	add_group(mut result, 'font-style-bold', [c.font_style_bold])
	add_group(mut result, 'font-style-italic', [c.font_style_italic])
	add_group(mut result, 'font-style-bold-italic', [c.font_style_bold_italic])
	add_group(mut result, 'font-size', ['${c.font_size}'])
	add_group(mut result, 'font-feature', repeat_strings(c.font_feature))
	add_group(mut result, 'font-thicken', [bool_string(c.font_thicken)])
	add_group(mut result, 'font-thicken-strength', ['${c.font_thicken_strength}'])
	add_group(mut result, 'font-shaping-break', [
		font_shaping_break_string(c.font_shaping_break),
	])
	add_group(mut result, 'grapheme-width-method', [c.grapheme_width_method.str()])
	add_group(mut result, 'scrollback-limit', ['${c.scrollback_limit}'])
	add_group(mut result, 'scrollbar', [c.scrollbar.str()])
	add_group(mut result, 'background', [format_color(c.background)])
	add_group(mut result, 'foreground', [format_color(c.foreground)])
	add_group(mut result, 'background-opacity', ['${c.background_opacity}'])
	add_group(mut result, 'background-opacity-cells', [
		bool_string(c.background_opacity_cells),
	])
	add_group(mut result, 'background-blur', [
		background_blur_string(c.background_blur),
	])
	add_group(mut result, 'background-image', [
		optional_path_string(c.background_image),
	])
	add_group(mut result, 'background-image-opacity', [
		'${c.background_image_opacity}',
	])
	add_group(mut result, 'background-image-position', [
		enum_config_string(c.background_image_position.str()),
	])
	add_group(mut result, 'background-image-fit', [
		enum_config_string(c.background_image_fit.str()),
	])
	add_group(mut result, 'background-image-repeat', [
		bool_string(c.background_image_repeat),
	])
	add_group(mut result, 'custom-shader', repeat_paths(c.custom_shader))
	add_group(mut result, 'custom-shader-animation', [
		enum_config_string(c.custom_shader_animation.str()),
	])
	add_group(mut result, 'cursor-color', [
		optional_terminal_color_string(c.cursor_color),
	])
	add_group(mut result, 'cursor-opacity', ['${c.cursor_opacity}'])
	add_group(mut result, 'cursor-text', [
		optional_terminal_color_string(c.cursor_text),
	])
	add_group(mut result, 'cursor-style', [c.cursor_style.str()])
	add_group(mut result, 'cursor-style-blink', [
		optional_bool_string(c.cursor_style_blink),
	])
	add_group(mut result, 'cursor-click-to-move', [
		bool_string(c.cursor_click_to_move),
	])
	add_group(mut result, 'faint-opacity', ['${c.faint_opacity}'])
	add_group(mut result, 'bold-color', [optional_bold_color_string(c.bold_color)])
	add_group(mut result, 'minimum-contrast', ['${c.minimum_contrast}'])
	add_group(mut result, 'selection-background', [
		optional_terminal_color_string(c.selection_background),
	])
	add_group(mut result, 'selection-foreground', [
		optional_terminal_color_string(c.selection_foreground),
	])
	add_group(mut result, 'selection-clear-on-copy', [
		bool_string(c.selection_clear_on_copy),
	])
	add_group(mut result, 'selection-clear-on-typing', [
		bool_string(c.selection_clear_on_typing),
	])
	add_group(mut result, 'selection-word-chars', [
		selection_word_chars_string(c.selection_word_chars),
	])
	add_group(mut result, 'search-background', [
		terminal_color_string(c.search_background),
	])
	add_group(mut result, 'search-foreground', [
		terminal_color_string(c.search_foreground),
	])
	add_group(mut result, 'search-selected-background', [
		terminal_color_string(c.search_selected_background),
	])
	add_group(mut result, 'search-selected-foreground', [
		terminal_color_string(c.search_selected_foreground),
	])
	add_group(mut result, 'unfocused-split-opacity', ['${c.unfocused_split_opacity}'])
	add_group(mut result, 'unfocused-split-fill', [
		optional_color_string(c.unfocused_split_fill),
	])
	add_group(mut result, 'split-divider-color', [
		optional_color_string(c.split_divider_color),
	])
	add_group(mut result, 'window-padding-top', ['${c.window_padding_top}'])
	add_group(mut result, 'window-padding-bottom', ['${c.window_padding_bottom}'])
	add_group(mut result, 'window-padding-left', ['${c.window_padding_left}'])
	add_group(mut result, 'window-padding-right', ['${c.window_padding_right}'])
	add_group(mut result, 'window-padding-balance', [
		bool_string(c.window_padding_balance),
	])
	add_group(mut result, 'window-padding-color', [
		enum_config_string(c.window_padding_color.str()),
	])
	add_group(mut result, 'window-width', ['${c.window_width}'])
	add_group(mut result, 'window-height', ['${c.window_height}'])
	add_group(mut result, 'window-vsync', [bool_string(c.window_vsync)])
	add_group(mut result, 'window-colorspace', [
		enum_config_string(c.window_colorspace.str()),
	])
	add_group(mut result, 'alpha-blending', [
		enum_config_string(c.alpha_blending.str()),
	])
	add_group(mut result, 'window-decoration', [
		enum_config_string(c.window_decoration.str()),
	])
	add_group(mut result, 'window-theme', [c.window_theme.str()])
	add_group(mut result, 'title', [optional_string(c.title)])
	add_group(mut result, 'title-report', [bool_string(c.title_report)])
	add_group(mut result, 'class', [optional_string(c.class)])
	add_group(mut result, 'x11-instance-name', [optional_string(c.x11_instance_name)])
	add_group(mut result, 'maximize', [bool_string(c.maximize)])
	add_group(mut result, 'fullscreen', [bool_string(c.fullscreen)])
	add_group(mut result, 'focus-follows-mouse', [bool_string(c.focus_follows_mouse)])
	add_group(mut result, 'window-inherit-working-directory', [
		bool_string(c.window_inherit_working_directory),
	])
	add_group(mut result, 'tab-inherit-working-directory', [
		bool_string(c.tab_inherit_working_directory),
	])
	add_group(mut result, 'split-inherit-working-directory', [
		bool_string(c.split_inherit_working_directory),
	])
	add_group(mut result, 'window-inherit-font-size', [
		bool_string(c.window_inherit_font_size),
	])
	add_group(mut result, 'initial-window', [bool_string(c.initial_window)])
	add_group(mut result, 'working-directory', [optional_string(c.working_directory)])
	add_group(mut result, 'command', [optional_command_string(c.command)])
	add_group(mut result, 'initial-command', [
		optional_command_string(c.initial_command),
	])
	add_group(mut result, 'initial-input', [optional_string(c.initial_input)])
	add_group(mut result, 'env', env_strings(c.env))
	add_group(mut result, 'term', [c.term])
	add_group(mut result, 'enquiry-response', [c.enquiry_response])
	add_group(mut result, 'shell-integration', [
		enum_config_string(c.shell_integration.str()),
	])
	add_group(mut result, 'shell-integration-features', [
		shell_integration_features_string(c.shell_integration_features),
	])
	add_group(mut result, 'link-previews', [enum_config_string(c.link_previews.str())])
	add_group(mut result, 'link-url', [bool_string(c.link_url)])
	add_group(mut result, 'clipboard-read', [c.clipboard_read.str()])
	add_group(mut result, 'clipboard-write', [c.clipboard_write.str()])
	add_group(mut result, 'clipboard-trim-trailing-spaces', [
		bool_string(c.clipboard_trim_trailing_spaces),
	])
	add_group(mut result, 'clipboard-paste-protection', [
		bool_string(c.clipboard_paste_protection),
	])
	add_group(mut result, 'clipboard-paste-bracketed-safe', [
		bool_string(c.clipboard_paste_bracketed_safe),
	])
	add_group(mut result, 'clipboard-codepoint-map', clipboard_codepoint_map_strings(c.clipboard_codepoint_map))
	add_group(mut result, 'copy-on-select', [
		enum_config_string(c.copy_on_select.str()),
	])
	add_group(mut result, 'confirm-close-surface', [
		enum_config_string(c.confirm_close_surface.str()),
	])
	add_group(mut result, 'mouse-hide-while-typing', [
		bool_string(c.mouse_hide_while_typing),
	])
	add_group(mut result, 'mouse-reporting', [bool_string(c.mouse_reporting)])
	add_group(mut result, 'mouse-shift-capture', [
		enum_config_string(c.mouse_shift_capture.str()),
	])
	add_group(mut result, 'mouse-scroll-multiplier', ['${c.mouse_scroll_multiplier}'])
	add_group(mut result, 'right-click-action', [
		enum_config_string(c.right_click_action.str()),
	])
	add_group(mut result, 'click-repeat-interval', ['${c.click_repeat_interval}'])
	add_group(mut result, 'desktop-notifications', [
		bool_string(c.desktop_notifications),
	])
	add_group(mut result, 'notify-on-command-finish', [
		c.notify_on_command_finish.str(),
	])
	add_group(mut result, 'abnormal-command-exit-runtime', [
		'${c.abnormal_command_exit_runtime}',
	])
	add_group(mut result, 'scroll-to-bottom', [
		scroll_to_bottom_string(c.scroll_to_bottom),
	])
	add_group(mut result, 'vt-kam-allowed', [bool_string(c.vt_kam_allowed)])
	add_group(mut result, 'wait-after-command', [bool_string(c.wait_after_command)])
	add_group(mut result, 'image-storage-limit', ['${c.image_storage_limit}'])
	add_group(mut result, 'quit-after-last-window-closed', [
		bool_string(c.quit_after_last_window_closed),
	])
	add_group(mut result, 'theme', [optional_string(c.theme)])
	add_group(mut result, 'config-default-files', [
		bool_string(c.config_default_files),
	])
	add_group(mut result, 'config-file', repeat_paths(c.config_file))
	add_group(mut result, 'keybind', keybind_values(c.keybind))
	add_group(mut result, 'key-remap', c.key_remap.format_entry())
	add_group(mut result, 'osc-color-report-format', [
		osc_color_report_format_string(c.osc_color_report_format),
	])
	add_group(mut result, 'macos-dock-drop-behavior', [
		enum_config_string(c.macos_dock_drop_behavior.str()),
	])
	add_group(mut result, 'gtk-single-instance', [
		enum_config_string(c.gtk_single_instance.str()),
	])
	add_group(mut result, 'palette', palette_strings(c.palette))
	return result
}

fn add_group(mut groups []ConfigEntryGroup, key string, values []string) {
	groups << ConfigEntryGroup{
		key: key
		values: if values.len == 0 { [''] } else { values }
	}
}

fn bool_string(value bool) string {
	return if value { 'true' } else { 'false' }
}

fn optional_bool_string(value ?bool) string {
	return if actual := value { bool_string(actual) } else { '' }
}

fn optional_string(value ?string) string {
	return value or { '' }
}

fn repeat_strings(values []string) []string {
	return if values.len == 0 { [''] } else { values.clone() }
}

fn enum_config_string(value string) string {
	if value == 'format_8_bit' {
		return '8-bit'
	}
	if value == 'format_16_bit' {
		return '16-bit'
	}
	return value.trim_string_right('_').replace('_', '-')
}

fn terminal_color_string(value TerminalColor) string {
	return match value.kind {
		.color { format_color(value.color) }
		.cell_foreground { 'cell-foreground' }
		.cell_background { 'cell-background' }
	}
}

fn optional_terminal_color_string(value ?TerminalColor) string {
	return if actual := value { terminal_color_string(actual) } else { '' }
}

fn optional_color_string(value ?ColorRGB) string {
	return if actual := value { format_color(actual) } else { '' }
}

fn optional_bold_color_string(value ?BoldColor) string {
	return if actual := value {
		if actual.bright { 'bright' } else { format_color(actual.color) }
	} else {
		''
	}
}

fn background_blur_string(value BackgroundBlur) string {
	return match value.kind {
		.bool_false { 'false' }
		.bool_true { 'true' }
		.radius { '${value.radius}' }
		.macos_glass_regular { 'macos-glass-regular' }
		.macos_glass_clear { 'macos-glass-clear' }
	}
}

fn path_string(value Path) string {
	return '${if value.optional { '?' } else { '' }}${value.path}'
}

fn optional_path_string(value ?Path) string {
	return if actual := value { path_string(actual) } else { '' }
}

fn repeat_paths(value RepeatablePath) []string {
	if value.items.len == 0 {
		return ['']
	}
	return value.items.map(path_string(it))
}

fn optional_command_string(value ?Command) string {
	if command := value {
		match command {
			ShellCmd {
				return command.shell
			}
			DirectCmd {
				return 'direct:${command.direct.join(' ')}'
			}
		}
	}
	return ''
}

fn env_strings(value RepeatableStringMap) []string {
	if value.entries.len == 0 {
		return ['']
	}
	return value.entries.map('${it.key}=${it.value}')
}

fn font_shaping_break_string(value FontShapingBreak) string {
	return if value.cursor { 'cursor' } else { 'no-cursor' }
}

fn shell_integration_features_string(value ShellIntegrationFeatures) string {
	return [
		if value.cursor { 'cursor' } else { 'no-cursor' },
		if value.sudo { 'sudo' } else { 'no-sudo' },
		if value.title { 'title' } else { 'no-title' },
		if value.ssh_env { 'ssh-env' } else { 'no-ssh-env' },
		if value.ssh_terminfo { 'ssh-terminfo' } else { 'no-ssh-terminfo' },
		if value.path { 'path' } else { 'no-path' },
	].join(',')
}

fn scroll_to_bottom_string(value ScrollToBottom) string {
	return [if value.keystroke { 'keystroke' } else { 'no-keystroke' },
		if value.output { 'output' } else { 'no-output' }].join(',')
}

fn selection_word_chars_string(value SelectionWordChars) string {
	if value.codepoints.len <= 1 {
		return ''
	}
	return value.codepoints[1..].map(rune(it).str()).join('')
}

fn clipboard_codepoint_map_strings(value RepeatableClipboardCodepointMap) []string {
	mut result := []string{}
	for entry in value.map {
		range_text := if entry.range_start == entry.range_end {
			'U+${entry.range_start:X}'
		} else {
			'U+${entry.range_start:X}-${entry.range_end:X}'
		}
		replacement := match entry.replacement {
			terminal.CodepointRepl { 'U+${entry.replacement.codepoint:X}' }
			terminal.StringRepl { entry.replacement.str }
		}
		result << '${range_text}=${replacement}'
	}
	return if result.len == 0 { [''] } else { result }
}

fn keybind_values(value Keybinds) []string {
	return value.format_entries().map(it.all_after('keybind = '))
}

fn osc_color_report_format_string(value OSCColorReportFormat) string {
	return match value {
		.none_ { 'none' }
		.format_8_bit { '8-bit' }
		.format_16_bit { '16-bit' }
	}
}

fn palette_strings(value Palette) []string {
	mut result := []string{cap: 256}
	for i, color in value.value {
		result << '${i}=${format_color(color)}'
	}
	return result
}
