module simd

// Base64 routines translated from src/simd/base64.zig. Witty currently uses
// Ghostty's scalar path because it does not link the optional Highway C++
// implementation.

// base64_scalar_input removes trailing padding so the scalar decoder has the
// same output behavior as Ghostty's SIMD implementation.
fn base64_scalar_input(input []u8) []u8 {
	mut end := input.len
	for end > 0 && input[end - 1] == `=` {
		end--
	}
	return input[..end]
}

// base64_max_len returns the exact decoded length, or zero for an invalid
// input length.
pub fn base64_max_len(input []u8) int {
	scalar := base64_scalar_input(input)
	return scalar_base64_calc_size(scalar) or { 0 }
}

// base64_decode decodes input into caller-owned storage and returns the used
// prefix. Invalid alphabet characters produce Base64Invalid.
pub fn base64_decode(input []u8, mut output []u8) ![]u8 {
	scalar := base64_scalar_input(input)
	size := base64_max_len(scalar)
	if size == 0 {
		return output[..0]
	}
	assert output.len >= size
	scalar_base64_decode(scalar, mut output) or { return error('Base64Invalid') }
	return output[..size]
}
