module input

// Tests for paste encoding and safety (translated from input/paste.zig)

fn test_paste_is_safe_simple() {
	assert paste_is_safe('hello') == true
}

fn test_paste_is_safe_newline() {
	assert paste_is_safe('hello\n') == false
}

fn test_paste_is_safe_newline_middle() {
	assert paste_is_safe('hello\nworld') == false
}

fn test_paste_is_safe_bracketed_paste_end() {
	assert paste_is_safe('he\x1b[201~llo') == false
}

fn test_paste_is_safe_empty() {
	assert paste_is_safe('') == true
}

fn test_paste_encode_bracketed() {
	result := paste_encode('hello', PasteOptions{ bracketed: true })
	assert result[0] == '\x1b[200~'
	assert result[1] == 'hello'
	assert result[2] == '\x1b[201~'
}

fn test_paste_encode_unbracketed_no_newlines() {
	result := paste_encode('hello', PasteOptions{ bracketed: false })
	assert result[0] == ''
	assert result[1] == 'hello'
	assert result[2] == ''
}

fn test_paste_encode_unbracketed_newlines() {
	result := paste_encode('hello\nworld', PasteOptions{ bracketed: false })
	assert result[0] == ''
	assert result[1] == 'hello\rworld'
	assert result[2] == ''
}

fn test_paste_encode_unbracketed_windows_newline() {
	result := paste_encode('hello\r\nworld', PasteOptions{ bracketed: false })
	assert result[0] == ''
	assert result[1] == 'hello\r\rworld'
	assert result[2] == ''
}
