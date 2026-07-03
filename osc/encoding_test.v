module osc

fn test_is_safe_utf8_hello() {
	assert is_safe_utf8('Hello world!')
}

fn test_is_safe_utf8_unicode() {
	assert is_safe_utf8('安全的ユニコード☀️')
}

fn test_is_safe_utf8_no_linebreaks() {
	assert !is_safe_utf8('No linebreaks\nallowed')
}

fn test_is_safe_utf8_no_bells() {
	assert !is_safe_utf8('\x07no bells')
}

fn test_is_safe_utf8_no_osc() {
	assert !is_safe_utf8('\x1b]9;no OSCs\x1b\\\x1b[m')
}

fn test_is_safe_utf8_no_8bit_escapes() {
	// 0x9f is a C1 control code
	assert !is_safe_utf8([u8(0x9f), `8`, `-`, `b`, `i`, `t`].bytestr())
}
