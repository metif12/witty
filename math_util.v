// Translated from Ghostty's math.zig
//
// Matrix math utilities for terminal rendering.

module main

// Mat is a 4x4 matrix of f32 values, stored as row-major.
pub struct Mat {
pub mut:
	data [16]f32
}

// 2D orthographic projection matrix.
//
// Creates a matrix that maps coordinates from the given bounds
// into normalized device coordinates [-1, 1].
pub fn ortho2d(left f32, right f32, bottom f32, top f32) Mat {
	w := right - left
	h := top - bottom
	return Mat{
		data: [
			f32(2.0 / w), 0, 0, 0,
			0, 2.0 / h, 0, 0,
			0, 0, -1.0, 0,
			-(right + left) / w, -(top + bottom) / h, 0, 1.0,
		]!
	}
}
