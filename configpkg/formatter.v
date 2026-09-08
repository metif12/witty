module configpkg

import input
import font
import datastruct.comparison

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
	default_config := Config.default_config()
	mut lines := []string{}
	for group in groups {
		if changes_only && !default_config.changed(&c, group.key) {
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

// changed reports whether one public configuration field differs between two
// configs. Ghostty's API takes its generated Key enum; V uses the equivalent
// hyphenated key spelling. The compile-time field projection is the V
// equivalent of Zig's comptime Key-to-field lookup.
pub fn (c &Config) changed(new &Config, key string) bool {
	$for field in Config.fields {
		$if !field.is_map {
			if field.name !in ['diagnostics', 'conditional_state', 'theme_pair', 'loading_theme',
				'replay_steps', 'replaying', 'xdg_terminal_exec', 'capi_commands'] && field.name.replace('_', '-') == key {
				return !comparison.deep_equal(c.$(field.name), new.$(field.name))
			}
		}
	}
	panic('unknown config key: ${key}')
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
	add_group(mut result, 'font-style', [font_style_string(c.font_style)])
	add_group(mut result, 'font-style-bold', [font_style_string(c.font_style_bold)])
	add_group(mut result, 'font-style-italic', [
		font_style_string(c.font_style_italic),
	])
	add_group(mut result, 'font-style-bold-italic', [
		font_style_string(c.font_style_bold_italic),
	])
	add_group(mut result, 'font-synthetic-style', [
		font_synthetic_style_string(c.font_synthetic_style),
	])
	add_group(mut result, 'font-size', ['${c.font_size}'])
	add_group(mut result, 'font-feature', repeat_strings(c.font_feature))
	add_group(mut result, 'font-variation', font_variation_strings(c.font_variation))
	add_group(mut result, 'font-variation-bold', font_variation_strings(c.font_variation_bold))
	add_group(mut result, 'font-variation-italic', font_variation_strings(c.font_variation_italic))
	add_group(mut result, 'font-variation-bold-italic', font_variation_strings(c.font_variation_bold_italic))
	add_group(mut result, 'font-codepoint-map', font_codepoint_map_strings(c.font_codepoint_map))
	add_group(mut result, 'font-thicken', [bool_string(c.font_thicken)])
	add_group(mut result, 'font-thicken-strength', ['${c.font_thicken_strength}'])
	add_group(mut result, 'font-shaping-break', [
		font_shaping_break_string(c.font_shaping_break),
	])
	add_group(mut result, 'adjust-cell-width', [
		metric_modifier_string(c.adjust_cell_width),
	])
	add_group(mut result, 'adjust-cell-height', [
		metric_modifier_string(c.adjust_cell_height),
	])
	add_group(mut result, 'adjust-font-baseline', [
		metric_modifier_string(c.adjust_font_baseline),
	])
	add_group(mut result, 'adjust-underline-position', [
		metric_modifier_string(c.adjust_underline_position),
	])
	add_group(mut result, 'adjust-underline-thickness', [
		metric_modifier_string(c.adjust_underline_thickness),
	])
	add_group(mut result, 'adjust-strikethrough-position', [
		metric_modifier_string(c.adjust_strikethrough_position),
	])
	add_group(mut result, 'adjust-strikethrough-thickness', [
		metric_modifier_string(c.adjust_strikethrough_thickness),
	])
	add_group(mut result, 'adjust-overline-position', [
		metric_modifier_string(c.adjust_overline_position),
	])
	add_group(mut result, 'adjust-overline-thickness', [
		metric_modifier_string(c.adjust_overline_thickness),
	])
	add_group(mut result, 'adjust-cursor-thickness', [
		metric_modifier_string(c.adjust_cursor_thickness),
	])
	add_group(mut result, 'adjust-cursor-height', [
		metric_modifier_string(c.adjust_cursor_height),
	])
	add_group(mut result, 'adjust-box-thickness', [
		metric_modifier_string(c.adjust_box_thickness),
	])
	add_group(mut result, 'adjust-icon-height', [
		metric_modifier_string(c.adjust_icon_height),
	])
	add_group(mut result, 'grapheme-width-method', [c.grapheme_width_method.str()])
	add_group(mut result, 'freetype-load-flags', [
		freetype_load_flags_string(c.freetype_load_flags),
	])
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
	add_group(mut result, 'split-preserve-zoom', [
		split_preserve_zoom_string(c.split_preserve_zoom),
	])
	add_group(mut result, 'window-padding-x', [
		window_padding_string(c.window_padding_x),
	])
	add_group(mut result, 'window-padding-y', [
		window_padding_string(c.window_padding_y),
	])
	add_group(mut result, 'window-padding-balance', [
		bool_string(c.window_padding_balance),
	])
	add_group(mut result, 'window-padding-color', [
		enum_config_string(c.window_padding_color.str()),
	])
	add_group(mut result, 'window-width', ['${c.window_width}'])
	add_group(mut result, 'window-height', ['${c.window_height}'])
	add_group(mut result, 'window-position-x', [
		optional_i16_string(c.window_position_x),
	])
	add_group(mut result, 'window-position-y', [
		optional_i16_string(c.window_position_y),
	])
	add_group(mut result, 'window-save-state', [
		enum_config_string(c.window_save_state.str()),
	])
	add_group(mut result, 'window-step-resize', [bool_string(c.window_step_resize)])
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
	add_group(mut result, 'window-title-font-family', [
		optional_string(c.window_title_font_family),
	])
	add_group(mut result, 'window-subtitle', [
		enum_config_string(c.window_subtitle.str()),
	])
	add_group(mut result, 'window-theme', [c.window_theme.str()])
	add_group(mut result, 'window-titlebar-background', [
		optional_color_string(c.window_titlebar_background),
	])
	add_group(mut result, 'window-titlebar-foreground', [
		optional_color_string(c.window_titlebar_foreground),
	])
	add_group(mut result, 'window-new-tab-position', [
		enum_config_string(c.window_new_tab_position.str()),
	])
	add_group(mut result, 'window-show-tab-bar', [
		enum_config_string(c.window_show_tab_bar.str()),
	])
	add_group(mut result, 'resize-overlay', [
		enum_config_string(c.resize_overlay.str()),
	])
	add_group(mut result, 'resize-overlay-position', [
		enum_config_string(c.resize_overlay_position.str()),
	])
	add_group(mut result, 'resize-overlay-duration', [
		c.resize_overlay_duration.format(),
	])
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
	add_group(mut result, 'undo-timeout', [c.undo_timeout.format()])
	add_group(mut result, 'quick-terminal-position', [
		enum_config_string(c.quick_terminal_position.str()),
	])
	add_group(mut result, 'quick-terminal-size', if c.quick_terminal_size.primary != none {
		[quick_terminal_size_string(c.quick_terminal_size)]
	} else {
		[]string{}
	})
	add_group(mut result, 'gtk-quick-terminal-layer', [
		enum_config_string(c.gtk_quick_terminal_layer.str()),
	])
	add_group(mut result, 'gtk-quick-terminal-namespace', [
		c.gtk_quick_terminal_namespace,
	])
	add_group(mut result, 'quick-terminal-screen', [
		enum_config_string(c.quick_terminal_screen.str()),
	])
	add_group(mut result, 'quick-terminal-animation-duration', [
		'${c.quick_terminal_animation_duration}',
	])
	add_group(mut result, 'quick-terminal-autohide', [
		bool_string(c.quick_terminal_autohide),
	])
	add_group(mut result, 'quick-terminal-space-behavior', [
		enum_config_string(c.quick_terminal_space_behavior.str()),
	])
	add_group(mut result, 'quick-terminal-keyboard-interactivity', [
		enum_config_string(c.quick_terminal_keyboard_interactivity.str()),
	])
	add_group(mut result, 'working-directory', [optional_string(c.working_directory)])
	add_group(mut result, 'command', [optional_command_string(c.command)])
	add_group(mut result, 'initial-command', [
		optional_command_string(c.initial_command),
	])
	add_group(mut result, 'input', readable_io_strings(c.input))
	add_group(mut result, 'env', env_strings(c.env))
	add_group(mut result, 'term', [c.term])
	add_group(mut result, 'enquiry-response', [c.enquiry_response])
	add_group(mut result, 'shell-integration', [
		enum_config_string(c.shell_integration.str()),
	])
	add_group(mut result, 'shell-integration-features', [
		shell_integration_features_string(c.shell_integration_features),
	])
	// RepeatableLink.formatEntry intentionally emits nothing because parsing
	// custom links is not implemented upstream yet. The key still participates
	// in docs and change tracking.
	add_group(mut result, 'link', []string{})
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
	add_group(mut result, 'mouse-scroll-multiplier', [
		c.mouse_scroll_multiplier.format(),
	])
	add_group(mut result, 'right-click-action', [
		enum_config_string(c.right_click_action.str()),
	])
	add_group(mut result, 'click-repeat-interval', ['${c.click_repeat_interval}'])
	add_group(mut result, 'desktop-notifications', [
		bool_string(c.desktop_notifications),
	])
	add_group(mut result, 'bell-features', [bell_features_string(c.bell_features)])
	add_group(mut result, 'bell-audio-path', [optional_path_string(c.bell_audio_path)])
	add_group(mut result, 'bell-audio-volume', ['${c.bell_audio_volume}'])
	add_group(mut result, 'app-notifications', [
		app_notifications_string(c.app_notifications),
	])
	add_group(mut result, 'notify-on-command-finish', [
		c.notify_on_command_finish.str(),
	])
	add_group(mut result, 'notify-on-command-finish-action', [
		notify_on_command_finish_action_string(c.notify_on_command_finish_action),
	])
	add_group(mut result, 'notify-on-command-finish-after', [
		c.notify_on_command_finish_after.format(),
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
	add_group(mut result, 'quit-after-last-window-closed-delay', [
		optional_duration_string(c.quit_after_last_window_closed_delay),
	])
	add_group(mut result, 'theme', [optional_string(c.theme)])
	add_group(mut result, 'config-default-files', [
		bool_string(c.config_default_files),
	])
	add_group(mut result, 'config-file', repeat_paths(c.config_file))
	add_group(mut result, 'keybind', keybind_values(c.keybind))
	add_group(mut result, 'command-palette-entry', command_palette_entry_strings(c.command_palette_entry))
	add_group(mut result, 'key-remap', c.key_remap.format_entry())
	add_group(mut result, 'osc-color-report-format', [
		osc_color_report_format_string(c.osc_color_report_format),
	])
	add_group(mut result, 'macos-non-native-fullscreen', [
		enum_config_string(c.macos_non_native_fullscreen.str()),
	])
	add_group(mut result, 'macos-window-buttons', [
		enum_config_string(c.macos_window_buttons.str()),
	])
	add_group(mut result, 'macos-titlebar-style', [
		enum_config_string(c.macos_titlebar_style.str()),
	])
	add_group(mut result, 'macos-titlebar-proxy-icon', [
		enum_config_string(c.macos_titlebar_proxy_icon.str()),
	])
	add_group(mut result, 'macos-dock-drop-behavior', [
		enum_config_string(c.macos_dock_drop_behavior.str()),
	])
	add_group(mut result, 'macos-option-as-alt', [
		optional_option_as_alt_string(c.macos_option_as_alt),
	])
	add_group(mut result, 'macos-window-shadow', [bool_string(c.macos_window_shadow)])
	add_group(mut result, 'macos-hidden', [enum_config_string(c.macos_hidden.str())])
	add_group(mut result, 'macos-auto-secure-input', [
		bool_string(c.macos_auto_secure_input),
	])
	add_group(mut result, 'macos-secure-input-indication', [
		bool_string(c.macos_secure_input_indication),
	])
	add_group(mut result, 'macos-icon', [enum_config_string(c.macos_icon.str())])
	add_group(mut result, 'macos-custom-icon', [optional_string(c.macos_custom_icon)])
	add_group(mut result, 'macos-icon-frame', [
		enum_config_string(c.macos_icon_frame.str()),
	])
	add_group(mut result, 'macos-icon-ghost-color', [
		optional_color_string(c.macos_icon_ghost_color),
	])
	add_group(mut result, 'macos-icon-screen-color', [
		optional_color_list_string(c.macos_icon_screen_color),
	])
	add_group(mut result, 'macos-shortcuts', [
		enum_config_string(c.macos_shortcuts.str()),
	])
	add_group(mut result, 'linux-cgroup', [enum_config_string(c.linux_cgroup.str())])
	add_group(mut result, 'linux-cgroup-memory-limit', [
		optional_u64_string(c.linux_cgroup_memory_limit),
	])
	add_group(mut result, 'linux-cgroup-processes-limit', [
		optional_u64_string(c.linux_cgroup_processes_limit),
	])
	add_group(mut result, 'linux-cgroup-hard-fail', [
		bool_string(c.linux_cgroup_hard_fail),
	])
	add_group(mut result, 'gtk-single-instance', [
		enum_config_string(c.gtk_single_instance.str()),
	])
	add_group(mut result, 'gtk-opengl-debug', [bool_string(c.gtk_opengl_debug)])
	add_group(mut result, 'gtk-titlebar', [bool_string(c.gtk_titlebar)])
	add_group(mut result, 'gtk-tabs-location', [
		enum_config_string(c.gtk_tabs_location.str()),
	])
	add_group(mut result, 'gtk-titlebar-hide-when-maximized', [
		bool_string(c.gtk_titlebar_hide_when_maximized),
	])
	add_group(mut result, 'gtk-toolbar-style', [
		enum_config_string(c.gtk_toolbar_style.str()),
	])
	add_group(mut result, 'gtk-titlebar-style', [
		enum_config_string(c.gtk_titlebar_style.str()),
	])
	add_group(mut result, 'gtk-wide-tabs', [bool_string(c.gtk_wide_tabs)])
	add_group(mut result, 'gtk-custom-css', repeat_paths(c.gtk_custom_css))
	add_group(mut result, 'async-backend', [async_backend_string(c.async_backend)])
	add_group(mut result, 'auto-update', [optional_auto_update_string(c.auto_update)])
	add_group(mut result, 'auto-update-channel', [
		optional_release_channel_string(c.auto_update_channel),
	])
	add_group(mut result, 'palette', palette_strings(c.palette))

	// Config's V field layout groups values by subsystem. FileFormatter and
	// Config.Key instead follow the source Config.zig declaration order.
	mut ordered := []ConfigEntryGroup{cap: config_keys.len}
	for key in config_keys {
		mut found := false
		for group in result {
			if group.key == key {
				ordered << ConfigEntryGroup{
					key: group.key
					values: group.values.clone()
				}
				found = true
				break
			}
		}
		if !found {
			panic('missing config formatter key: ${key}')
		}
	}
	return ordered
}

fn readable_io_strings(value RepeatableReadableIO) []string {
	return value.format_entry()
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

fn optional_duration_string(value ?Duration) string {
	return if actual := value { actual.format() } else { '' }
}

fn optional_u64_string(value ?u64) string {
	return if actual := value { actual.str() } else { '' }
}

fn optional_i16_string(value ?i16) string {
	return if actual := value { actual.str() } else { '' }
}

fn optional_auto_update_string(value ?AutoUpdate) string {
	return if actual := value { enum_config_string(actual.str()) } else { '' }
}

fn optional_release_channel_string(value ?ReleaseChannel) string {
	return if actual := value { enum_config_string(actual.str()) } else { '' }
}

fn async_backend_string(value AsyncBackend) string {
	return match value {
		.auto { 'auto' }
		.epoll { 'epoll' }
		.io_uring { 'io_uring' }
	}
}

fn repeat_strings(values []string) []string {
	return if values.len == 0 { [''] } else { values.clone() }
}

fn font_style_string(value FontStyle) string {
	return match value.kind {
		.default_ { 'default' }
		.false_ { 'false' }
		.name { value.name }
	}
}

fn font_variation_strings(value RepeatableFontVariation) []string {
	if value.list.len == 0 {
		return ['']
	}
	return value.list.map('${it.id.str()}=${format_f64(it.value)}')
}

fn font_codepoint_map_strings(value RepeatableCodepointMap) []string {
	if value.map.entries.len == 0 {
		return ['']
	}
	mut result := []string{cap: value.map.entries.len}
	for entry in value.map.entries {
		family := entry.descriptor.family or { '' }
		if entry.range[0] == entry.range[1] {
			result << 'U+${entry.range[0]:04X}=${family}'
		} else {
			result << 'U+${entry.range[0]:04X}-U+${entry.range[1]:04X}=${family}'
		}
	}
	return result
}

fn metric_modifier_string(value ?font.MetricsModifier) string {
	modifier := value or { return '' }
	if modifier.is_percent {
		return '${format_f64((modifier.percent - 1.0) * 100.0)}%'
	}
	return modifier.absolute.str()
}

fn font_synthetic_style_string(value font.FontSyntheticStyle) string {
	return [if value.bold { 'bold' } else { 'no-bold' },
		if value.italic { 'italic' } else { 'no-italic' },
		if value.bold_italic { 'bold-italic' } else { 'no-bold-italic' }].join(',')
}

fn freetype_load_flags_string(value font.FreetypeLoadFlags) string {
	return [if value.hinting { 'hinting' } else { 'no-hinting' },
		if value.force_autohint { 'force-autohint' } else { 'no-force-autohint' },
		if value.monochrome { 'monochrome' } else { 'no-monochrome' },
		if value.autohint { 'autohint' } else { 'no-autohint' },
		if value.light { 'light' } else { 'no-light' }].join(',')
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

fn optional_color_list_string(value ?ColorList) string {
	return if actual := value { actual.format_entry() } else { '' }
}

fn optional_option_as_alt_string(value ?input.OptionAsAlt) string {
	return if actual := value { enum_config_string(actual.str()) } else { '' }
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

fn quick_terminal_size_string(value QuickTerminalSize) string {
	return value.format_entry() or { '' }
}

fn path_string(value Path) string {
	return value.format_entry()
}

fn optional_path_string(value ?Path) string {
	return if actual := value { path_string(actual) } else { '' }
}

fn repeat_paths(value RepeatablePath) []string {
	return value.format_entry()
}

fn optional_command_string(value ?Command) string {
	if command := value {
		return command.format_entry()
	}
	return ''
}

fn command_palette_entry_strings(value RepeatableCommand) []string {
	if value.items.len == 0 {
		return ['']
	}
	mut result := []string{cap: value.items.len}
	for item in value.items {
		mut entry := 'title:"${input.zig_escape(item.title)}"'
		if item.description.len > 0 {
			entry += ',description:"${input.zig_escape(item.description)}"'
		}
		entry += ',action:"${item.action.format()}"'
		result << entry
	}
	return result
}

fn env_strings(value RepeatableStringMap) []string {
	return value.format_entry()
}

fn font_shaping_break_string(value FontShapingBreak) string {
	return if value.cursor { 'cursor' } else { 'no-cursor' }
}

fn split_preserve_zoom_string(value SplitPreserveZoom) string {
	return if value.navigation { 'navigation' } else { 'no-navigation' }
}

fn window_padding_string(value WindowPadding) string {
	if value.top_left == value.bottom_right {
		return value.top_left.str()
	}
	return '${value.top_left},${value.bottom_right}'
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

fn bell_features_string(value BellFeatures) string {
	return [
		if value.system { 'system' } else { 'no-system' },
		if value.audio { 'audio' } else { 'no-audio' },
		if value.attention { 'attention' } else { 'no-attention' },
		if value.title { 'title' } else { 'no-title' },
		if value.border { 'border' } else { 'no-border' },
	].join(',')
}

fn app_notifications_string(value AppNotifications) string {
	return [if value.clipboard_copy { 'clipboard-copy' } else { 'no-clipboard-copy' },
		if value.config_reload { 'config-reload' } else { 'no-config-reload' }].join(',')
}

fn notify_on_command_finish_action_string(value NotifyOnCommandFinishAction) string {
	return [if value.bell { 'bell' } else { 'no-bell' },
		if value.notify { 'notify' } else { 'no-notify' }].join(',')
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
	return value.format_entry()
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
	return value.format_entry()
}
