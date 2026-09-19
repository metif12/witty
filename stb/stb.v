module stb

// stb_image and stb_image_resize library bindings.
//
// This wraps the stb_image and stb_image_resize C libraries, mirroring the
// three bindings Ghostty exposes in src/stb/main.zig. The C implementation is
// emitted by the co-located shim with the same PNG-only and maximum-dimension
// configuration as Ghostty's src/stb/stb.c.

// Compile the v1 implementation in its own translation unit. Some V graphics
// modules include stb_image_resize2; putting both headers into generated C
// causes conflicting declarations even though their implementations are
// independent.
#flag -I @VMODROOT/stb
#flag @VMODROOT/stb/stb_bridge.c
#include "stb_bridge.h"

fn C.witty_stbi_load_from_memory(buffer &u8, len int, x &int, y &int, channels_in_file &int, desired_channels int) &u8

fn C.witty_stbi_image_free(retval_from_stbi_load voidptr)

fn C.witty_stbir_resize_uint8(input_pixels &u8, input_w int, input_h int, input_stride_in_bytes int, output_pixels &u8, output_w int, output_h int, output_stride_in_bytes int, num_channels int) int

pub fn stbi_load_from_memory(buffer &u8, len int, x &int, y &int, channels_in_file &int, desired_channels int) &u8 {
	return C.witty_stbi_load_from_memory(buffer, len, x, y, channels_in_file, desired_channels)
}

pub fn stbi_image_free(retval_from_stbi_load voidptr) {
	C.witty_stbi_image_free(retval_from_stbi_load)
}

pub fn stbir_resize_uint8(input_pixels &u8, input_w int, input_h int, input_stride int, output_pixels &u8, output_w int, output_h int, output_stride int, num_channels int) int {
	return C.witty_stbir_resize_uint8(input_pixels, input_w, input_h, input_stride, output_pixels,
		output_w, output_h, output_stride, num_channels)
}
