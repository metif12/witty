module zigimg

import math

// Device-dependent color models from locked color.zig. These functions retain
// the source's f32 arithmetic and accept channels outside the usual 0..1 range.
pub struct Hsl {
pub mut:
	hue        f32
	saturation f32
	luminance  f32
}

pub fn Hsl.from_rgb(rgb Colorf32) Hsl {
	maximum := color_max_f32(rgb.r, color_max_f32(rgb.g, rgb.b))
	minimum := color_min_f32(rgb.r, color_min_f32(rgb.g, rgb.b))
	range := maximum - minimum
	luminance := (maximum + minimum) / f32(2)
	mut hue := f32(0)
	if range == 0 {
		hue = 0
	} else if maximum == rgb.r {
		hue = 60 * color_mod_f32((rgb.g - rgb.b) / range, 6)
	} else if maximum == rgb.g {
		hue = 60 * ((rgb.b - rgb.r) / range + 2)
	} else if maximum == rgb.b {
		hue = 60 * ((rgb.r - rgb.g) / range + 4)
	}
	saturation := if luminance == 0 || luminance == 1 {
		f32(0)
	} else {
		(maximum - luminance) / color_min_f32(luminance, 1 - luminance)
	}
	return Hsl{
		hue:        hue
		saturation: saturation
		luminance:  luminance
	}
}

pub fn (color Hsl) to_rgb() Colorf32 {
	return Colorf32{
		r: color.rgb_component(0)
		g: color.rgb_component(8)
		b: color.rgb_component(4)
		a: 1
	}
}

pub fn (color Hsl) to_hsv() Hsv {
	// Separate operations prevent C from contracting the source's multiply/add
	// into a fused operation with different f32 rounding.
	offset := color.saturation * color_min_f32(color.luminance, 1 - color.luminance)
	value := color.luminance + offset
	return Hsv{
		hue:        color.hue
		saturation: if value == 0 { f32(0) } else { 2 * (1 - color.luminance / value) }
		value:      value
	}
}

fn (color Hsl) rgb_component(n f32) f32 {
	a := color.saturation * color_min_f32(color.luminance, 1 - color.luminance)
	k := color_mod_f32(n + color.hue / f32(30), 12)
	offset := a * color_max_f32(-1, color_min_f32(k - 3, color_min_f32(9 - k, 1)))
	return color.luminance - offset
}

pub struct Hsv {
pub mut:
	hue        f32
	saturation f32
	value      f32
}

pub fn Hsv.from_rgb(rgb Colorf32) Hsv {
	maximum := color_max_f32(rgb.r, color_max_f32(rgb.g, rgb.b))
	minimum := color_min_f32(rgb.r, color_min_f32(rgb.g, rgb.b))
	range := maximum - minimum
	mut hue := f32(0)
	if range == 0 {
		hue = 0
	} else if maximum == rgb.r {
		hue = 60 * color_mod_f32((rgb.g - rgb.b) / range, 6)
	} else if maximum == rgb.g {
		hue = 60 * ((rgb.b - rgb.r) / range + 2)
	} else if maximum == rgb.b {
		hue = 60 * ((rgb.r - rgb.g) / range + 4)
	}
	return Hsv{
		hue:        hue
		saturation: if maximum == 0 { f32(0) } else { range / maximum }
		value:      maximum
	}
}

pub fn (color Hsv) to_rgb() Colorf32 {
	return Colorf32{
		r: color.rgb_component(5)
		g: color.rgb_component(3)
		b: color.rgb_component(1)
		a: 1
	}
}

pub fn (color Hsv) to_hsl() Hsl {
	luminance := color.value * (1 - color.saturation / f32(2))
	return Hsl{
		hue:        color.hue
		saturation: if luminance == 0 {
			f32(0)
		} else {
			(color.value - luminance) / color_min_f32(luminance, 1 - luminance)
		}
		luminance:  luminance
	}
}

fn (color Hsv) rgb_component(n f32) f32 {
	k := color_mod_f32(n + color.hue / f32(60), 6)
	a := color.value * color.saturation
	offset := a * color_max_f32(0, color_min_f32(k, color_min_f32(4 - k, 1)))
	return color.value - offset
}

@[packed]
pub struct Cmykf32 {
pub mut:
	c f32
	m f32
	y f32
	k f32
}

pub fn Cmykf32.from_colorf32(value Colorf32) Cmykf32 {
	maximum := color_max_f32(value.r, color_max_f32(value.g, value.b))
	k := 1 - maximum
	minus_k := 1 - k
	if math.abs(minus_k) <= f32(0.00000011920928955078125) {
		return Cmykf32{
			k: k
		}
	}
	return Cmykf32{
		c: (1 - value.r - k) / minus_k
		m: (1 - value.g - k) / minus_k
		y: (1 - value.b - k) / minus_k
		k: k
	}
}

pub fn (color Cmykf32) to_colorf32() Colorf32 {
	minus_k := 1 - color.k
	return Colorf32{
		r: (1 - color.c) * minus_k
		g: (1 - color.m) * minus_k
		b: (1 - color.y) * minus_k
		a: 1
	}
}

pub struct Grayscalef32 {
pub mut:
	value f32
}

pub struct Grayscalef32Alpha {
pub mut:
	value f32
	alpha f32 = 1
}

pub fn (gray Grayscalef32) to_colorf32() Colorf32 {
	return gray_colorf32(gray.value, 1)
}

pub fn (gray Grayscalef32Alpha) to_colorf32() Colorf32 {
	return gray_colorf32(gray.value, gray.alpha)
}

// Zig's floating min/max select the non-NaN operand. Keep this behavior for
// the public model functions instead of depending on V's generic comparisons.
fn color_min_f32(left f32, right f32) f32 {
	if left != left { return right }
	if right != right { return left }
	if left == 0 && right == 0 {
		bits := unsafe { *(&u32(&left)) | *(&u32(&right)) }
		return unsafe { *(&f32(&bits)) }
	}
	return if left < right { left } else { right }
}

fn color_max_f32(left f32, right f32) f32 {
	if left != left { return right }
	if right != right { return left }
	if left == 0 && right == 0 {
		bits := unsafe { *(&u32(&left)) & *(&u32(&right)) }
		return unsafe { *(&f32(&bits)) }
	}
	return if left > right { left } else { right }
}

fn color_mod_f32(value f32, divisor f32) f32 {
	remainder := f32(math.fmod(f64(value), f64(divisor)))
	modulo := if remainder < 0 { remainder + divisor } else { remainder }
	// Rounding a tiny negative remainder can produce the divisor itself;
	// Zig keeps the modulus inside [0, divisor) at that boundary.
	return if modulo == divisor { f32(0) } else { modulo }
}
