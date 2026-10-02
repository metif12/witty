module simd

import unicode

// codepoint_width is the scalar fallback from Ghostty's
// src/simd/codepoint_width.zig. Witty does not link the optional Highway C++
// backend, so the pinned source selects this exact uucode table path.
@[inline]
pub fn codepoint_width(cp u32) i8 {
	$if !js && !wasm32 && !no_simd ? {
		return C.ghostty_simd_codepoint_width(cp)
	}
	if cp > 0x1fffff {
		return 1
	}
	return i8(unicode.get(cp).width())
}
