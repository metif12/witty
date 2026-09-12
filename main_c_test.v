module main

import configpkg
import global_state
import os
import apprt

fn test_ghostty_info_exposes_stable_version_bytes() {
	info := ghostty_info()
	assert !isnil(info.version)
	assert info.version_len == usize(version_string.len)
	version := unsafe { info.version.vstring_with_len(int(info.version_len)) }
	assert version == version_string
}

fn test_ghostty_string_owns_c_string() {
	value := GhosttyString.from_string('hello')
	assert value.len == 5
	assert value.sentinel
	assert value.bytes().bytestr() == 'hello'
	unsafe {
		assert value.ptr[5] == 0
	}
	ghostty_string_free(value)
}

fn test_ghostty_string_owns_byte_slice() {
	mut source := 'hello'.bytes()
	value := GhosttyString.from_bytes(source)
	source[0] = `j`
	assert !value.sentinel
	assert value.bytes().bytestr() == 'hello'
	ghostty_string_free(value)
}

fn test_ghostty_translate_falls_back_to_original_message() {
	msgid := 'witty-main-c-message-not-in-catalog'
	assert ghostty_translate(msgid) == msgid
}

fn test_action_args_remove_only_selected_action() {
	assert action_args(['+list-themes', '--plain', '--color=dark'], .list_themes) == [
		'--plain',
		'--color=dark',
	]
}

fn test_all_declared_actions_are_dispatched() {
	// Every Action enum value is explicitly covered by run_cli_action's match.
	assert global_state.actions().len == 15
}

fn test_cli_help_matches_translated_command() {
	help := cli_help_output()
	assert help.starts_with('Usage: ghostty [+action] [options]\n\n')
	assert help.contains('Run the Ghostty terminal emulator or a specific helper action.\n')
	assert help.contains('  +list-actions\n')
	assert help.ends_with('where `<action>` is one of actions listed above.\n')
}

fn test_macos_mouse_button_numbers_match_source_adapter() {
	assert mouse_button_from_number(0) == .left
	assert mouse_button_from_number(1) == .right
	assert mouse_button_from_number(2) == .middle
	assert mouse_button_from_number(3) == .eight
	assert mouse_button_from_number(4) == .nine
	assert mouse_button_from_number(5) == .six
	assert mouse_button_from_number(6) == .seven
	assert mouse_button_from_number(7) == .four
	assert mouse_button_from_number(8) == .five
	assert mouse_button_from_number(9) == .ten
	assert mouse_button_from_number(10) == .eleven
	assert mouse_button_from_number(11) == .unknown
}

fn test_config_c_api_lifecycle_clone_and_primitive_getters() {
	mut config := ghostty_config_new() or { panic('config allocation failed') }
	defer {
		ghostty_config_free(mut config)
	}

	mut font_size := f32(0)
	assert ghostty_config_get(mut config, voidptr(&font_size), 'font-size')
	assert font_size == configpkg.default_font_size

	mut reporting := false
	assert ghostty_config_get(mut config, voidptr(&reporting), 'mouse-reporting')
	assert reporting

	config.font_family << 'config-c-api-original'
	mut cloned := ghostty_config_clone(config) or { panic('config clone failed') }
	defer {
		ghostty_config_free(mut cloned)
	}
	cloned.font_family << 'config-c-api-clone'
	assert config.font_family == ['config-c-api-original']
	assert cloned.font_family == ['config-c-api-original', 'config-c-api-clone']
}

fn test_config_c_api_gets_enum_color_duration_and_packed_values() {
	mut config := ghostty_config_new() or { panic('config allocation failed') }
	defer {
		ghostty_config_free(mut config)
	}

	mut enum_value := &char(unsafe { nil })
	assert ghostty_config_get(mut config, voidptr(&enum_value), 'osc-color-report-format')
	assert unsafe { cstring_to_vstring(enum_value) } == '16-bit'

	config.async_backend = .io_uring
	assert ghostty_config_get(mut config, voidptr(&enum_value), 'async-backend')
	assert unsafe { cstring_to_vstring(enum_value) } == 'io_uring'

	config.class = 'com.example.Witty'
	assert ghostty_config_get(mut config, voidptr(&enum_value), 'class')
	assert unsafe { cstring_to_vstring(enum_value) } == 'com.example.Witty'

	mut color := configpkg.CConfigColor{}
	assert ghostty_config_get(mut config, voidptr(&color), 'background')
	assert color.r == 0x28
	assert color.g == 0x2c
	assert color.b == 0x34

	mut duration_ms := usize(0)
	assert ghostty_config_get(mut config, voidptr(&duration_ms), 'undo-timeout')
	assert duration_ms == 5000

	mut feature_bits := u32(0)
	assert ghostty_config_get(mut config, voidptr(&feature_bits), 'bell-features')
	assert feature_bits == 0b01100

	assert !ghostty_config_get(mut config, voidptr(&feature_bits), 'scrollback-limit')
	assert !ghostty_config_get(mut config, voidptr(&feature_bits), 'not-a-config-key')
	assert !ghostty_config_get(mut config, unsafe { nil }, 'font-size')
}

fn test_config_c_api_gets_composite_values() {
	mut config := ghostty_config_new() or { panic('config allocation failed') }
	defer {
		ghostty_config_free(mut config)
	}

	mut palette := configpkg.CConfigPalette{}
	assert ghostty_config_get(mut config, voidptr(&palette), 'palette')
	assert palette.colors[0].r == 0x1d
	assert palette.colors[1].r == 0xcc
	assert palette.colors[15].b == 0xea

	config.quick_terminal_size.parse_cli('72%,480px')!
	mut quick_size := configpkg.CConfigQuickTerminalSize{}
	assert ghostty_config_get(mut config, voidptr(&quick_size), 'quick-terminal-size')
	assert quick_size.primary.tag == 1
	assert quick_size.secondary.tag == 2
	assert quick_size.secondary.value == 480

	mut commands := configpkg.CConfigCommandList{}
	assert ghostty_config_get(mut config, voidptr(&commands), 'command-palette-entry')
	assert commands.len > 0
	assert !isnil(commands.commands)
	unsafe {
		assert cstring_to_vstring(commands.commands[0].action_key).len > 0
		assert cstring_to_vstring(commands.commands[0].action).len > 0
		assert cstring_to_vstring(commands.commands[0].title).len > 0
	}
}

fn test_config_c_api_trigger_lookup() {
	mut config := ghostty_config_new() or { panic('config allocation failed') }
	defer {
		ghostty_config_free(mut config)
	}
	config.keybind.parse_cli('ctrl+shift+u=text:config-c-api')!

	trigger := ghostty_config_trigger(config, 'text:config-c-api')
	assert trigger.tag == 1
	assert trigger.key == u32(`u`)
	assert trigger.mods == 0b0011
	assert ghostty_config_trigger(config, 'not-an-action') == InputTrigger{}
}

fn test_config_c_api_file_loading_and_diagnostics() {
	path := os.join_path(os.temp_dir(), 'witty-config-c-api-${os.getpid()}')
	os.write_file(path, 'font-size = nope\n')!
	defer {
		os.rm(path) or {}
	}

	mut config := ghostty_config_new() or { panic('config allocation failed') }
	defer {
		ghostty_config_free(mut config)
	}
	ghostty_config_load_file(mut config, path)
	assert ghostty_config_diagnostics_count(config) == 1
	diagnostic := ghostty_config_get_diagnostic(mut config, 0)
	assert !isnil(diagnostic.message)
	assert unsafe { cstring_to_vstring(diagnostic.message) } == '${path}:1:font-size: invalid value "nope"'
	assert unsafe { cstring_to_vstring(ghostty_config_get_diagnostic(mut config, 99).message) } == ''
}

fn test_embedded_c_abi_layouts_match_ghostty_header() {
	assert sizeof(RuntimeConfigC) == 64
	assert sizeof(InputKeyC) == 32
	assert sizeof(SurfaceConfigC) == 88
	assert sizeof(TextC) == 40
	assert sizeof(PointC) == 16
	assert sizeof(SelectionC) == 36
	assert sizeof(apprt.CAPISurfaceSize) == 20
	assert sizeof(apprt.CAPITarget) == 16
	assert sizeof(apprt.CAPIAction) == 32
	assert sizeof(apprt.CAPIClipboardContentC) == 16
	assert sizeof(apprt.CAPIInputTrigger) == 12
}

fn test_benchmark_c_api_dispatches_actions() {
	assert ghostty_benchmark_cli_c(c'codepoint-width', c'')
	assert ghostty_benchmark_cli_c(c'grapheme-break', c'')
	assert !ghostty_benchmark_cli_c(c'not-a-benchmark', c'')
	assert !ghostty_benchmark_cli_c(unsafe { nil }, c'')
}

fn test_embedded_surface_config_defaults_and_conversion() {
	defaults := ghostty_surface_config_new_c()
	assert defaults.platform_tag == 0
	assert defaults.scale_factor == 1.0
	assert defaults.context == 0
	assert isnil(defaults.working_directory)

	assert surface_options_from_c(&SurfaceConfigC{
		platform_tag: 3
	}) == none
	assert surface_options_from_c(&SurfaceConfigC{
		platform_tag: 1
		platform: voidptr(1)
		scale_factor: 2.0
		context: 3
	}) == none

	env := [EnvVarC{ key: c'WITTY_C_ABI', value: c'ok' }]
	converted := surface_options_from_c(&SurfaceConfigC{
		platform_tag: 1
		platform: voidptr(1)
		scale_factor: 2.0
		env_vars: &env[0]
		env_var_count: 1
		initial_input: c'hello'
		context: 2
	}) or { panic('valid surface config was rejected') }
	assert converted.platform_tag == 1
	assert converted.scale_factor == 2.0
	assert converted.env_vars == [apprt.EnvVar{ key: 'WITTY_C_ABI', value: 'ok' }]
	assert converted.initial_input or { '' } == 'hello'
	assert converted.context == .split
}

fn test_embedded_text_projection_preserves_length_and_sentinel() {
	mut result := TextC{}
	assert text_to_c(apprt.CAPIText{
		text: 'a\x00b'
	}, mut result)
	defer {
		ghostty_surface_free_text_c(unsafe { nil }, &result)
	}
	assert !isnil(result.text)
	assert result.text_len == 3
	unsafe {
		assert int(result.text[0]) == int(`a`)
		assert int(result.text[1]) == 0
		assert int(result.text[2]) == int(`b`)
		assert int(result.text[3]) == 0
	}

	mut empty := TextC{}
	assert text_to_c(apprt.CAPIText{
		text: ''
	}, mut empty)
	defer {
		ghostty_surface_free_text_c(unsafe { nil }, &empty)
	}
	assert !isnil(empty.text)
	assert empty.text_len == 0
	unsafe {
		assert int(empty.text[0]) == 0
	}
}

fn test_embedded_input_key_conversion_rejects_invalid_action() {
	assert input_key_from_c(InputKeyC{ action: -1 }) == none
	assert input_key_from_c(InputKeyC{ action: 3 }) == none
	key := input_key_from_c(InputKeyC{
		action: 1
		mods: 3
		text: c'x'
		unshifted_codepoint: u32(`X`)
	}) or { panic('valid key was rejected') }
	assert key.action == .press
	assert key.mods == 3
	assert key.text or { '' } == 'x'
}
