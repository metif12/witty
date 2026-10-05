module main

import configpkg
import apprt
import input as inputpkg
import json
import macos
import os

#insert "@VMODROOT/native_title_font_darwin_test_abi.h"

fn C.witty_title_font_matches(view voidptr, family &char) bool

struct NativeConfigStringInput {
	label    string
	bytes    []u8
	expected string
}

struct NativeConfigStringRecord {
	input               string
	title               ?string
	family              ?string
	command_title       ?string
	command_description ?string
}

fn test_native_config_string_getters_preserve_swift_c_string_rules() {
	macos.app_init()
	mut config := configpkg.Config.default()
	defer { config.deinit() }
	inputs := [
		NativeConfigStringInput{'empty', [], ''},
		NativeConfigStringInput{'ascii', 'Courier'.bytes(), 'Courier'},
		NativeConfigStringInput{'unicode', 'Ω🚀'.bytes(), 'Ω🚀'},
		NativeConfigStringInput{'valid-replacement', [u8(0xef), 0xbf, 0xbd], '�'},
		NativeConfigStringInput{'nul', [u8(`a`), 0, `b`], 'a'},
		NativeConfigStringInput{'invalid-after-nul', [u8(`a`), 0, 0xff], 'a'},
		NativeConfigStringInput{'invalid-before-nul', [u8(0xff), 0, `a`], '�'},
		NativeConfigStringInput{'continuation', [u8(0x80)], '�'},
		NativeConfigStringInput{'invalid-lead', [u8(0xff)], '�'},
		NativeConfigStringInput{'overlong-2', [u8(0xc0), 0xaf], '��'},
		NativeConfigStringInput{'overlong-3', [u8(0xe0), 0x80, 0xaf], '���'},
		NativeConfigStringInput{'surrogate', [u8(0xed), 0xa0, 0x80], '���'},
		NativeConfigStringInput{'beyond-max', [u8(0xf4), 0x90, 0x80, 0x80], '����'},
		NativeConfigStringInput{'truncated-2', [u8(0xc2)], '�'},
		NativeConfigStringInput{'truncated-3', [u8(0xe2), 0x82], '�'},
		NativeConfigStringInput{'truncated-4', [u8(0xf0), 0x9f, 0x92], '�'},
		NativeConfigStringInput{'broken-continuation', [u8(0xe2), `X`, 0xa1], '�X�'},
		NativeConfigStringInput{'maximal-subpart', [u8(`a`), 0xe2, 0x82, `b`], 'a�b'},
		NativeConfigStringInput{'broken-4', [u8(0xf0), 0x9f, `A`], '�A'},
	]
	mut records := []NativeConfigStringRecord{}
	mut runtime := standalone_runtime()
	original_states := runtime.states.clone()
	runtime.states = []&TermState{}
	defer { runtime.states = original_states }
	for input in inputs {
		config.title = input.bytes.bytestr()
		config.window_title_font_family = input.bytes.bytestr()
		projection := native_window_config(&config)
		assert projection.title? == input.expected
		assert projection.window_title_font_family? == input.expected
		config.command_palette_entry.items = [inputpkg.Command{
			action: inputpkg.ActionQuit{}
			title: input.bytes.bytestr()
			description: input.bytes.bytestr()
		}]
		options := native_command_options(&apprt.App{config: config})
		command := options.filter(it.action == 'quit')[0]
		assert command.title == input.expected
		assert command.description == input.expected
		records << NativeConfigStringRecord{input.label, projection.title, projection.window_title_font_family,
			command.title, command.description}
	}
	config.title = none
	config.window_title_font_family = none
	projection := native_window_config(&config)
	assert projection.title == none
	assert projection.window_title_font_family == none
	records << NativeConfigStringRecord{input: 'nil', title: projection.title, family: projection.window_title_font_family}
	if path := os.getenv_opt('WITTY_CONFIG_STRING_MODEL_OUTPUT') {
		os.write_file(path, json.encode(records))!
	}
}

fn test_native_config_strings_reach_window_title_and_font_consumers() {
	macos.app_init()
	mut config := configpkg.Config.default()
	defer { config.deinit() }
	config.title = [u8(`t`), `i`, `t`, `l`, `e`, 0xff, 0, `x`].bytestr()
	config.window_title_font_family = [u8(`C`), `o`, `u`, `r`, `i`, `e`, `r`, 0, 0xff].bytestr()
	config.macos_titlebar_style = .tabs
	projection := native_window_config(&config)
	view := macos.create_restorable_window(400, 300, 'original title')
	window := macos.view_window(view)
	defer {
		macos.close_native_window(window)
		macos.release_native_object(window)
		macos.release_native_object(view)
	}
	macos.set_native_window_title_font(view, projection.window_title_font_family)
	macos.apply_native_window_config(view, projection, true, projection.background,
		projection.opacity, false)
	assert macos.native_window_title(view) == 'title�'
	assert C.witty_title_font_matches(view, c'Courier')
}
