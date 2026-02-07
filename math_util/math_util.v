// Translated from Ghostty's math.zig
//
// Matrix math utilities for terminal rendering.

module math_util

// Mat is a 4x4 matrix of f32 values, stored as row-major.
pub type Mat = [4][4]f32

// 2D orthographic projection matrix.
//
// Creates a matrix that maps coordinates from the given bounds
// into normalized device coordinates [-1, 1].
pub fn ortho2d(left f32, right f32, bottom f32, top f32) Mat {
	w := right - left
	h := top - bottom
	return [
		[f32(2.0 / w), 0, 0, 0]!,
		[f32(0), 2.0 / h, 0, 0]!,
		[f32(0.0), 0.0, -1.0, 0.0]!,
		[f32(-(right + left) / w), -(top + bottom) / h, 0.0, 1.0]!,
	]!
}
