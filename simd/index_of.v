module simd

// index_of returns the first byte offset of needle in input. This is the
// scalar fallback from src/simd/index_of.zig; the public contract is identical
// when Ghostty's optional C++ SIMD backend is disabled.
@[inline]
pub fn index_of(input []u8, needle u8) ?int {
	for i, value in input {
		if value == needle {
			return i
		}
	}
	return none
}
