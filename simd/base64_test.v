module simd

fn test_base64_max_len() {
	assert base64_max_len('aGVsbG8gd29ybGQ='.bytes()) == 11
}

fn test_base64_scalar_source_size_entry_points() {
	assert base64_scalar_calc_size_upper_bound(0)! == 0
	assert base64_scalar_calc_size_upper_bound(2)! == 1
	assert base64_scalar_calc_size_upper_bound(3)! == 2
	assert base64_scalar_calc_size_upper_bound(4)! == 3
	assert base64_scalar_calc_size_for_slice('aGVsbG8gd29ybGQ'.bytes())! == 11
	base64_scalar_calc_size_upper_bound(1) or {
		assert err.msg() == 'InvalidPadding'
		return
	}
	assert false, 'one trailing Base64 byte must be rejected'
}

fn test_base64_decode() {
	input := 'aGVsbG8gd29ybGQ='.bytes()
	mut output := []u8{len: int(base64_max_len(input))}
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
