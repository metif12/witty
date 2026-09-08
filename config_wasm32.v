// Translated from Ghostty's src/config/Wasm.zig.

module main

import configpkg

// Create a new configuration filled with the initial default values.
@[export: 'config_new']
fn config_new_wasm_export() voidptr {
	result := ghostty_config_new() or {
		eprintln('error allocating config')
		return unsafe { nil }
	}
	return voidptr(result)
}

@[export: 'config_free']
fn config_free_wasm_export(raw voidptr) {
	if isnil(raw) {
		return
	}
	mut config := unsafe { &configpkg.Config(raw) }
	ghostty_config_free(mut config)
}

// Load configuration from the desktop file syntax stored in a byte slice.
@[export: 'config_load_string']
fn config_load_string_wasm_export(raw voidptr, str &u8, len usize) {
	mut config := unsafe { &configpkg.Config(raw) }
	content := unsafe { tos(str, int(len)) }
	config.load_string(content)
}

@[export: 'config_finalize']
fn config_finalize_wasm_export(raw voidptr) {
	mut config := unsafe { &configpkg.Config(raw) }
	config.finalize() or {
		eprintln('error finalizing config err=${err}')
	}
}
