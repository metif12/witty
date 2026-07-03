module stb

// stb_image_resize library bindings.
//
// This wraps the single-header stb_image_resize C library, mirroring the
// binding ghostty exposes in src/stb/main.zig (`stbir_resize_uint8`, used by
// src/font/face/freetype.zig to scale color glyph bitmaps). The C
// implementation is emitted by the co-located shim (stb_shims.h), which
// defines STB_IMAGE_RESIZE_IMPLEMENTATION before including the vendored
// stb_image_resize.h header.

// The shim is resolved relative to this file's directory; add the module
// directory to the include path so the shim can locate the vendored
// stb_image_resize.h header alongside it.
#flag -I @VMODROOT/stb
#include "stb_shims.h"

// C entry point (medium-complexity API). We use the "generic" form so we can
// select the box filter, which for integer scale ratios performs
// nearest-neighbour resampling (each source pixel is replicated into the
// destination). This is the resampler behaviour our callers rely on for
// bitmap glyph scaling. Returns 1 on success and 0 on failure.
fn C.stbir_resize_uint8_generic(input_pixels &u8, input_w int, input_h int, input_stride_in_bytes int, output_pixels &u8, output_w int, output_h int, output_stride_in_bytes int, num_channels int, alpha_channel int, flags int, edge_wrap_mode int, filter int, space int, alloc_context voidptr) int

// stb filter / edge / colorspace enum values from stb_image_resize.h.
const stbir_filter_box = 1 // nearest-neighbour for integer scale ratios
const stbir_edge_clamp = 1
const stbir_colorspace_linear = 0
const stbir_alpha_channel_none = -1

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
		C.stbir_resize_uint8_generic(input_pixels, int(input_w), int(input_h), int(input_stride),
			output_pixels, int(output_w), int(output_h), int(output_stride), int(num_channels),
			stbir_alpha_channel_none, 0, stbir_edge_clamp, stbir_filter_box, stbir_colorspace_linear,
			nil)
	}
	return res == 1
}
