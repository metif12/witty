module main

import global_state

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

fn test_unavailable_action_returns_error_instead_of_false_success() {
	run_cli_action(global_state.Action.show_face, []) or {
		assert err.msg().contains('not available')
		return
	}
	assert false, 'unavailable action must not report success'
}
