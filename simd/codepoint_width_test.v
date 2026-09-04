module simd

fn test_codepoint_width_basic() {
	assert codepoint_width(u32(`a`)) == 1
	assert codepoint_width(0x100) == 1
	assert codepoint_width(0x3400) == 2
	assert codepoint_width(0x2e3a) == 2
	assert codepoint_width(0x1f1e6) == 2
	assert codepoint_width(0x4e00) == 2
	assert codepoint_width(0xf900) == 2
	assert codepoint_width(0x20000) == 2
	assert codepoint_width(0x30000) == 2
	assert codepoint_width(0x200000) == 1
}
