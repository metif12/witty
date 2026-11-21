module simd

// index_of returns the first byte offset of needle in input. This is the
// scalar fallback from src/simd/index_of.zig; the public contract is identical
// when Ghostty's optional C++ SIMD backend is disabled.
@[inline]
pub fn index_of(input []u8, needle u8) ?uint {
	$if !js && !wasm32 && !no_simd ? {
		result := C.ghostty_simd_index_of(needle, input.data, uint(input.len))
		return if result == uint(input.len) { none } else { result }
	}
	for i, value in input {
		if value == needle {
			return uint(i)
		}
	}
	return none
}
