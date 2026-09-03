module stb

// stb_image_resize library bindings.
//
// This wraps the single-header stb_image_resize C library, mirroring the
// binding ghostty exposes in src/stb/main.zig (`stbir_resize_uint8`, used by
// src/font/face/freetype.zig to scale color glyph bitmaps). The C
// implementation is emitted by the co-located shim (stb_shims.h), which
// defines STB_IMAGE_RESIZE_IMPLEMENTATION before including the vendored
// stb_image_resize.h header.

// Compile the v1 implementation in its own translation unit. Some V graphics
// modules include stb_image_resize2; putting both headers into generated C
// causes conflicting declarations even though their implementations are
// independent.
#flag -I @VMODROOT/stb
#flag @VMODROOT/stb/stb_bridge.c
#include "stb_bridge.h"

// C entry point (medium-complexity API). We use the "generic" form so we can
// select the box filter, which for integer scale ratios performs
// nearest-neighbour resampling (each source pixel is replicated into the
// destination). This is the resampler behaviour our callers rely on for
// bitmap glyph scaling. Returns 1 on success and 0 on failure.
fn C.witty_stbir_resize_uint8(input_pixels &u8, input_w int, input_h int, input_stride_in_bytes int, output_pixels &u8, output_w int, output_h int, output_stride_in_bytes int, num_channels int) int

// stbir_resize_uint8 resizes an 8-bit image. `input_stride`/`output_stride`
// may be 0 to use a tightly-packed `width * num_channels` stride.
//
// Returns true on success, false on failure (e.g. non-positive dimensions or
// channel count). stb itself relies on asserts to reject degenerate
// dimensions, so we validate them up front to guarantee a clean false return
// rather than undefined behaviour.
pub fn stbir_resize_uint8(input_pixels &u8, input_w i32, input_h i32, input_stride i32, output_pixels &u8, output_w i32, output_h i32, output_stride i32, num_channels u32) bool {
	if input_w <= 0 || input_h <= 0 || output_w <= 0 || output_h <= 0 || num_channels == 0 {
		return false
	}
	res := unsafe {
		C.witty_stbir_resize_uint8(input_pixels, int(input_w), int(input_h), int(input_stride),
			output_pixels, int(output_w), int(output_h), int(output_stride), int(num_channels))
	}
	return res == 1
}
