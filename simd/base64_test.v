module simd

fn test_base64_max_len() {
	assert base64_max_len('aGVsbG8gd29ybGQ='.bytes()) == 11
}

fn test_base64_decode() {
	input := 'aGVsbG8gd29ybGQ='.bytes()
	mut output := []u8{len: base64_max_len(input)}
	decoded := base64_decode(input, mut output)!
	assert decoded.bytestr() == 'hello world'
}

fn test_base64_decode_accepts_noncanonical_trailing_bits() {
	mut output := []u8{len: 1}
	decoded := base64_decode('Zh=='.bytes(), mut output)!
	assert decoded == [u8(`f`)]
}

fn test_base64_decode_rejects_invalid_character() {
	mut output := []u8{len: 3}
	base64_decode('AA!A'.bytes(), mut output) or {
		assert err.msg().contains('Base64Invalid')
		return
	}
	assert false, 'expected invalid Base64 to fail'
}

fn test_base64_decode_one_byte_input_matches_scalar_fallback() {
	mut output := []u8{}
	assert base64_decode('A'.bytes(), mut output)! == []u8{}
}
