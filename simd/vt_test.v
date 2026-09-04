module simd

fn test_vt_decode_no_escape() {
	input := 'hello'.repeat(128).bytes()
	mut output := []u32{len: 1024}
	result := utf8_decode_until_control_seq(input, mut output)
	assert result == DecodeResult{
		consumed: input.len
		decoded: input.len
	}
}

fn test_vt_decode_ascii_to_escape() {
	prefix := 'hello'.repeat(64)
	input := (prefix + '\x1b' + 'world'.repeat(64)).bytes()
	mut output := []u32{len: 1024}
	result := utf8_decode_until_control_seq(input, mut output)
	assert result == DecodeResult{
		consumed: prefix.len
		decoded: prefix.len
	}
}

fn test_vt_decode_immediate_escape() {
	input := '\x1b[?5s'.bytes()
	mut output := []u32{len: 64}
	assert utf8_decode_until_control_seq(input, mut output) == DecodeResult{}
}

fn test_vt_decode_incomplete_utf8() {
	mut output := []u32{len: 64}
	for input in [
		[`h`, `e`, `l`, `l`, `o`, u8(0xc2)],
		[`h`, `e`, `l`, `l`, `o`, u8(0xe0), u8(0x00)],
		[`h`, `e`, `l`, `l`, `o`, u8(0xf0), u8(0x90)],
	] {
		assert utf8_decode_until_control_seq(input, mut output) == DecodeResult{
			consumed: 5
			decoded: 5
		}
	}
}

fn test_vt_decode_invalid_utf8() {
	input := [`h`, `e`, `l`, `l`, `o`, u8(0xc2), u8(0x01)]
	mut output := []u32{len: 64}
	result := utf8_decode_until_control_seq(input, mut output)
	assert result == DecodeResult{
		consumed: 7
		decoded: 7
	}
	assert output[5] == 0xfffd
	assert output[6] == 0x01
}

fn test_vt_decode_invalid_leading_byte_is_not_consumed() {
	input := [`h`, `e`, `l`, `l`, `o`, u8(0xff)]
	mut output := []u32{len: 64}
	assert utf8_decode_until_control_seq(input, mut output) == DecodeResult{
		consumed: 5
		decoded: 5
	}
}

fn test_vt_decode_multibyte_codepoints() {
	input := 'é€👻'.bytes()
	mut output := []u32{len: input.len}
	result := utf8_decode_until_control_seq(input, mut output)
	assert result.consumed == input.len
	assert result.decoded == 3
	assert output[..3] == [u32(0xe9), 0x20ac, 0x1f47b]
}
