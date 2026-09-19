module input

import terminal

// Tests for paste encoding and safety (translated from input/paste.zig)

fn test_paste_options_from_terminal() ! {
	mut term := terminal.Terminal.init(terminal.Options{ cols: 2, rows: 2 })!
	defer {
		term.deinit()
	}
	assert !PasteOptions.from_terminal(&term).bracketed
	term.modes.set(.bracketed_paste, true)
	assert PasteOptions.from_terminal(&term).bracketed
}

fn test_is_safe_simple() {
	assert is_safe('hello') == true
}

fn test_is_safe_newline() {
	assert is_safe('hello\n') == false
}

fn test_is_safe_newline_middle() {
	assert is_safe('hello\nworld') == false
}

fn test_is_safe_bracketed_paste_end() {
	assert is_safe('he\x1b[201~llo') == false
}

fn test_is_safe_empty() {
	assert is_safe('') == true
}

fn test_paste_encode_bracketed() ! {
	result := paste_encode('hello', PasteOptions{ bracketed: true })!.parts()
	assert result[0] == '\x1b[200~'
	assert result[1] == 'hello'
	assert result[2] == '\x1b[201~'
}

fn test_paste_encode_unbracketed_no_newlines() ! {
	result := paste_encode('hello', PasteOptions{ bracketed: false })!.parts()
	assert result[0] == ''
	assert result[1] == 'hello'
	assert result[2] == ''
}

fn test_paste_encode_unbracketed_newlines_const_requires_mutable_copy() {
	paste_encode('hello\nworld', PasteOptions{ bracketed: false }) or {
		assert err.msg() == 'MutableRequired'
		return
	}
	assert false, 'expected MutableRequired'
}

fn test_paste_encode_unbracketed_newlines_mutates_copy() {
	mut data := 'hello\nworld'.bytes()
	result := paste_encode_mut(mut data, PasteOptions{ bracketed: false }).parts()
	assert result[0] == ''
	assert result[1] == 'hello\rworld'
	assert result[2] == ''
}

fn test_paste_encode_unbracketed_windows_newline() {
	mut data := 'hello\r\nworld'.bytes()
	result := paste_encode_mut(mut data, PasteOptions{ bracketed: false }).parts()
	assert result[0] == ''
	assert result[1] == 'hello\r\rworld'
	assert result[2] == ''
}
