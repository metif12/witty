module zigimg

// ScaleValue(f32): normalize each integer component by the maximum of its
// source bit width. Alpha is straight; iteration does not premultiply it.
pub fn (color Rgb24) to_colorf32() Colorf32 {
	return Colorf32{
		r: f32(color.r) / 255
		g: f32(color.g) / 255
		b: f32(color.b) / 255
	}
}

pub fn (color Rgba32) to_colorf32() Colorf32 {
	return Colorf32{
		r: f32(color.r) / 255
		g: f32(color.g) / 255
		b: f32(color.b) / 255
		a: f32(color.a) / 255
	}
}

pub fn (color Bgr24) to_colorf32() Colorf32 {
	return Colorf32{
		r: f32(color.r) / 255
		g: f32(color.g) / 255
		b: f32(color.b) / 255
	}
}

pub fn (color Bgra32) to_colorf32() Colorf32 {
	return Colorf32{
		r: f32(color.r) / 255
		g: f32(color.g) / 255
		b: f32(color.b) / 255
		a: f32(color.a) / 255
	}
}

pub fn (color Rgb48) to_colorf32() Colorf32 {
	return Colorf32{
		r: f32(color.r) / 65535
		g: f32(color.g) / 65535
		b: f32(color.b) / 65535
	}
}

pub fn (color Rgba64) to_colorf32() Colorf32 {
	return Colorf32{
		r: f32(color.r) / 65535
		g: f32(color.g) / 65535
		b: f32(color.b) / 65535
		a: f32(color.a) / 65535
	}
}

pub fn (color Rgb332) to_colorf32() Colorf32 {
	return Colorf32{
		r: f32(color.raw & 7) / 7
		g: f32((color.raw >> 3) & 7) / 7
		b: f32(color.raw >> 6) / 3
	}
}

pub fn (color Rgb555) to_colorf32() Colorf32 {
	return Colorf32{
		r: f32((color.raw >> 10) & 31) / 31
		g: f32((color.raw >> 5) & 31) / 31
		b: f32(color.raw & 31) / 31
	}
}

pub fn (color Rgb565) to_colorf32() Colorf32 {
	return Colorf32{
		r: f32(color.raw >> 11) / 31
		g: f32((color.raw >> 5) & 63) / 63
		b: f32(color.raw & 31) / 31
	}
}

pub fn (color Bgr555) to_colorf32() Colorf32 {
	return Colorf32{
		r: f32(color.raw & 31) / 31
		g: f32((color.raw >> 5) & 31) / 31
		b: f32((color.raw >> 10) & 31) / 31
	}
}

fn gray_colorf32(value f32, alpha f32) Colorf32 {
	return Colorf32{
		r: value
		g: value
		b: value
		a: alpha
	}
}

pub fn (gray Grayscale1) to_colorf32() Colorf32 {
	assert gray.value <= 1
	return gray_colorf32(f32(gray.value), 1)
}

pub fn (gray Grayscale2) to_colorf32() Colorf32 {
	assert gray.value <= 3
	return gray_colorf32(f32(gray.value) / 3, 1)
}

pub fn (gray Grayscale4) to_colorf32() Colorf32 {
	assert gray.value <= 15
	return gray_colorf32(f32(gray.value) / 15, 1)
}

pub fn (gray Grayscale8) to_colorf32() Colorf32 {
	return gray_colorf32(f32(gray.value) / 255, 1)
}

pub fn (gray Grayscale16) to_colorf32() Colorf32 {
	return gray_colorf32(f32(gray.value) / 65535, 1)
}

pub fn (gray Grayscale8Alpha) to_colorf32() Colorf32 {
	return gray_colorf32(f32(gray.value) / 255, f32(gray.alpha) / 255)
}

pub fn (gray Grayscale16Alpha) to_colorf32() Colorf32 {
	return gray_colorf32(f32(gray.value) / 65535, f32(gray.alpha) / 65535)
}
