module simd

fn test_vt_decode_no_escape() {
	input := 'hello'.repeat(128).bytes()
	mut output := []u32{len: 1024}
	result := utf8_decode_until_control_seq(input, mut output)
	assert result == DecodeResult{
		consumed: uint(input.len)
		decoded: uint(input.len)
	}
}

fn test_vt_decode_ascii_to_escape() {
	prefix := 'hello'.repeat(64)
	input := (prefix + '\x1b' + 'world'.repeat(64)).bytes()
	mut output := []u32{len: 1024}
	result := utf8_decode_until_control_seq(input, mut output)
	assert result == DecodeResult{
		consumed: uint(prefix.len)
		decoded: uint(prefix.len)
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
		[u8(`h`), `e`, `l`, `l`, `o`, 0xc2],
		[u8(`h`), `e`, `l`, `l`, `o`, 0xe0, 0x00],
		[u8(`h`), `e`, `l`, `l`, `o`, 0xf0, 0x90],
	] {
		assert utf8_decode_until_control_seq(input, mut output) == DecodeResult{
			consumed: uint(5)
			decoded: uint(5)
		}
	}
}

fn test_vt_decode_invalid_utf8() {
	input := [u8(`h`), `e`, `l`, `l`, `o`, 0xc2, 0x01]
	mut output := []u32{len: 64}
	result := utf8_decode_until_control_seq(input, mut output)
	assert result == DecodeResult{
		consumed: uint(7)
		decoded: uint(7)
	}
	assert output[5] == 0xfffd
	assert output[6] == 0x01
}

fn test_vt_decode_invalid_leading_byte_is_not_consumed() {
	input := [u8(`h`), `e`, `l`, `l`, `o`, 0xff]
	mut output := []u32{len: 64}
	assert utf8_decode_until_control_seq(input, mut output) == DecodeResult{
		consumed: uint(5)
		decoded: uint(5)
	}
}

fn test_vt_decode_multibyte_codepoints() {
	input := 'é€👻'.bytes()
	mut output := []u32{len: input.len}
	result := utf8_decode_until_control_seq(input, mut output)
	assert result.consumed == uint(input.len)
	assert result.decoded == uint(3)
	assert output[..3] == [u32(0xe9), 0x20ac, 0x1f47b]
}
