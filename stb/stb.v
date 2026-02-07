module stb

// Stub stb image resize library bindings.
// XTODO: Replace with real stb_image_resize C bindings when available.

// stbir_resize_uint8 resizes an 8-bit image.
// Returns true on success.
pub fn stbir_resize_uint8(input_pixels &u8, input_w i32, input_h i32, input_stride i32, output_pixels &u8, output_w i32, output_h i32, output_stride i32, num_channels u32) bool {
	// XTODO: call stbir_resize_uint8 from stb_image_resize
	return false
}
