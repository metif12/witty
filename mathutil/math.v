module mathutil

// Mat is the 4x4 shader matrix type. V represents the four source vectors as
// one flat fixed array with the same element order and byte layout.
pub type Mat = [16]f32

// ortho2d returns a 2D orthographic projection matrix.
pub fn ortho2d(left f32, right f32, bottom f32, top f32) Mat {
	w := right - left
	h := top - bottom
	return Mat([
		f32(2 / w),
		0,
		0,
		0,
		0,
		2 / h,
		0,
		0,
		0,
		0,
		-1,
		0,
		-(right + left) / w,
		-(top + bottom) / h,
		0,
		1,
	]!)
}
