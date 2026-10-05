module zigimg

// Scientific color models from locked color.zig. Float4 conversion copies
// component bits, while the packed four-float records also support borrowed
// array views in the colorspace slice APIs.
pub const cie_epsilon = f32(216.0 / 24389.0)
pub const cie_kappa = f32(24389.0 / 27.0)

@[packed]
pub struct CIEXYZ {
pub mut:
	x f32
	y f32
	z f32
}

@[packed]
pub struct CIEXYZAlpha {
pub mut:
	x f32
	y f32
	z f32
	a f32 = 1
}

pub fn CIEXYZAlpha.from_float4(value Float4) CIEXYZAlpha {
	return CIEXYZAlpha{
		x: value[0]
		y: value[1]
		z: value[2]
		a: value[3]
	}
}

pub fn (value CIEXYZAlpha) to_float4() Float4 {
	return Float4([value.x, value.y, value.z, value.a]!)
}

@[packed]
pub struct CIELab {
pub mut:
	l f32
	a f32
	b f32
}

@[packed]
pub struct CIELabAlpha {
pub mut:
	l     f32
	a     f32
	b     f32
	alpha f32 = 1
}

pub fn CIELabAlpha.from_float4(value Float4) CIELabAlpha {
	return CIELabAlpha{
		l:     value[0]
		a:     value[1]
		b:     value[2]
		alpha: value[3]
	}
}

pub fn (value CIELabAlpha) to_float4() Float4 {
	return Float4([value.l, value.a, value.b, value.alpha]!)
}

@[packed]
pub struct CIELCHab {
pub mut:
	l f32
	c f32
	h f32
}

@[packed]
pub struct CIELCHabAlpha {
pub mut:
	l     f32
	c     f32
	h     f32
	alpha f32 = 1
}

pub fn CIELCHabAlpha.from_float4(value Float4) CIELCHabAlpha {
	return CIELCHabAlpha{
		l:     value[0]
		c:     value[1]
		h:     value[2]
		alpha: value[3]
	}
}

pub fn (value CIELCHabAlpha) to_float4() Float4 {
	return Float4([value.l, value.c, value.h, value.alpha]!)
}

@[packed]
pub struct CIELuv {
pub mut:
	l f32
	u f32
	v f32
}

@[packed]
pub struct CIELuvAlpha {
pub mut:
	l     f32
	u     f32
	v     f32
	alpha f32 = 1
}

pub fn CIELuvAlpha.from_float4(value Float4) CIELuvAlpha {
	return CIELuvAlpha{
		l:     value[0]
		u:     value[1]
		v:     value[2]
		alpha: value[3]
	}
}

pub fn (value CIELuvAlpha) to_float4() Float4 {
	return Float4([value.l, value.u, value.v, value.alpha]!)
}

@[packed]
pub struct CIELCHuv {
pub mut:
	l f32
	c f32
	h f32
}

@[packed]
pub struct CIELCHuvAlpha {
pub mut:
	l     f32
	c     f32
	h     f32
	alpha f32 = 1
}

pub fn CIELCHuvAlpha.from_float4(value Float4) CIELCHuvAlpha {
	return CIELCHuvAlpha{
		l:     value[0]
		c:     value[1]
		h:     value[2]
		alpha: value[3]
	}
}

pub fn (value CIELCHuvAlpha) to_float4() Float4 {
	return Float4([value.l, value.c, value.h, value.alpha]!)
}

// The MIT License (MIT)

// Copyright © 2015 Alexei Boronine (original idea, JavaScript implementation)
// Copyright © 2015 Roger Tallada (Obj-C implementation)
// Copyright © 2017 Martin Mitáš (C implementation, based on Obj-C implementation)

// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the “Software”),
// to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense,
// and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

// The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

// THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
// WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

@[packed]
pub struct HSLuv {
pub mut:
	h f32
	s f32
	l f32
}

@[packed]
pub struct HSLuvAlpha {
pub mut:
	h     f32
	s     f32
	l     f32
	alpha f32
}

@[packed]
pub struct Oklab {
pub mut:
	l f32
	a f32
	b f32
}

@[packed]
pub struct OklabAlpha {
pub mut:
	l     f32
	a     f32
	b     f32
	alpha f32 = 1
}

pub fn OklabAlpha.from_float4(value Float4) OklabAlpha {
	return OklabAlpha{
		l:     value[0]
		a:     value[1]
		b:     value[2]
		alpha: value[3]
	}
}

pub fn (value OklabAlpha) to_float4() Float4 {
	return Float4([value.l, value.a, value.b, value.alpha]!)
}

@[packed]
pub struct OkLCh {
pub mut:
	l f32
	c f32
	h f32
}

@[packed]
pub struct OkLChAlpha {
pub mut:
	l     f32
	c     f32
	h     f32
	alpha f32 = 1
}

pub fn OkLChAlpha.from_float4(value Float4) OkLChAlpha {
	return OkLChAlpha{
		l:     value[0]
		c:     value[1]
		h:     value[2]
		alpha: value[3]
	}
}

pub fn (value OkLChAlpha) to_float4() Float4 {
	return Float4([value.l, value.c, value.h, value.alpha]!)
}

pub struct CIExyY {
pub mut:
	x f32
	y f32
}

pub fn (value CIExyY) z() f32 {
	return 1 - value.x - value.y
}

pub fn (value CIExyY) to_xyz(y f32) CIEXYZ {
	return CIEXYZ{
		x: value.x / value.y * y
		y: y
		z: value.z() / value.y * y
	}
}

pub fn (value CIExyY) equals(right CIExyY) bool {
	return value.x == right.x && value.y == right.y
}

pub fn (value CIEXYZAlpha) to_xyz() CIEXYZ {
	return CIEXYZ{
		x: value.x
		y: value.y
		z: value.z
	}
}

pub fn CIELab.from_xyz(xyz CIEXYZ, white_point CIExyY) CIELab {
	return CIELab.from_xyz_precomputed_white_point(xyz, white_point.to_xyz(1))
}

pub fn CIELab.from_xyz_precomputed_white_point(xyz CIEXYZ, white CIEXYZ) CIELab {
	factor_x := cie_lab_factor(xyz.x / white.x)
	factor_y := cie_lab_factor(xyz.y / white.y)
	factor_z := cie_lab_factor(xyz.z / white.z)
	scaled_l := f32(116) * factor_y
	l := scaled_l - 16
	a := f32(500) * (factor_x - factor_y)
	b := f32(200) * (factor_y - factor_z)
	return CIELab{
		l: l / 100
		a: a / 100
		b: b / 100
	}
}

pub fn (value CIELab) to_xyz(white CIExyY) CIEXYZ {
	return value.to_xyz_precomputed_white_point(white.to_xyz(1))
}

pub fn (value CIELab) to_xyz_precomputed_white_point(white CIEXYZ) CIEXYZ {
	scaled_l := value.l * f32(100)
	scaled_a := value.a * f32(100)
	scaled_b := value.b * f32(100)
	factor_y := (scaled_l + 16) / f32(116)
	factor_z := factor_y - scaled_b / f32(200)
	factor_x := scaled_a / f32(500) + factor_y
	cubic_factor_x := factor_x * factor_x * factor_x
	cubic_factor_z := factor_z * factor_z * factor_z
	x_linear := f32(116) * factor_x
	z_linear := f32(116) * factor_z
	result_x := if cubic_factor_x > cie_epsilon {
		cubic_factor_x
	} else {
		(x_linear - 16) / cie_kappa
	}
	result_y := if scaled_l > cie_kappa * cie_epsilon {
		color_pow_f32((scaled_l + 16) / f32(116), 3)
	} else {
		scaled_l / cie_kappa
	}
	result_z := if cubic_factor_z > cie_epsilon {
		cubic_factor_z
	} else {
		(z_linear - 16) / cie_kappa
	}
	return CIEXYZ{
		x: result_x * white.x
		y: result_y * white.y
		z: result_z * white.z
	}
}

fn cie_lab_factor(value f32) f32 {
	if value > cie_epsilon { return color_cbrt_f32(value) }
	product := cie_kappa * value
	return (product + 16) / f32(116)
}

pub fn CIELuv.from_xyz(xyz CIEXYZ, white_point CIExyY) CIELuv {
	return CIELuv.from_xyz_precomputed_white_point(xyz, white_point.to_xyz(1))
}

pub fn CIELuv.from_xyz_precomputed_white_point(xyz CIEXYZ, white CIEXYZ) CIELuv {
	y_relative := xyz.y / white.y
	y_term := f32(15) * xyz.y
	z_term := f32(3) * xyz.z
	value_denominator := xyz.x + y_term + z_term
	is_value_zero := cie_near_zero(value_denominator)
	u_prime := if !is_value_zero { f32(4) * xyz.x / value_denominator } else { f32(0) }
	v_prime := if !is_value_zero { f32(9) * xyz.y / value_denominator } else { f32(0) }
	white_y_term := f32(15) * white.y
	white_z_term := f32(3) * white.z
	white_denominator := white.x + white_y_term + white_z_term
	white_u_prime := f32(4) * white.x / white_denominator
	white_v_prime := f32(9) * white.y / white_denominator
	cubic_term := f32(116) * color_cbrt_f32(y_relative)
	l := if y_relative > cie_epsilon { cubic_term - 16 } else { cie_kappa * y_relative }
	chroma_scale := f32(13) * l
	u := chroma_scale * (u_prime - white_u_prime)
	v := chroma_scale * (v_prime - white_v_prime)
	return CIELuv{
		l: l / 100
		u: u / 100
		v: v / 100
	}
}

pub fn (value CIELuv) to_xyz(white CIExyY) CIEXYZ {
	return value.to_xyz_precomputed_white_point(white.to_xyz(1))
}

pub fn (value CIELuv) to_xyz_precomputed_white_point(white CIEXYZ) CIEXYZ {
	scaled_l := value.l * f32(100)
	scaled_u := value.u * f32(100)
	scaled_v := value.v * f32(100)
	if cie_near_zero(scaled_l) { return CIEXYZ{} }
	white_y_term := f32(15) * white.y
	white_z_term := f32(3) * white.z
	white_denominator := white.x + white_y_term + white_z_term
	white_u_zero := f32(4) * white.x / white_denominator
	white_v_zero := f32(9) * white.y / white_denominator
	y := if scaled_l > cie_kappa * cie_epsilon {
		color_pow_f32((scaled_l + 16) / f32(116), 3)
	} else {
		scaled_l / cie_kappa
	}
	u_term := f32(13) * scaled_l * white_u_zero
	a := (f32(52) * scaled_l / (scaled_u + u_term) - 1) * f32(1.0 / 3.0)
	b := f32(-5) * y
	c := f32(-1.0 / 3.0)
	v_term := f32(13) * scaled_l * white_v_zero
	d := y * (f32(39) * scaled_l / (scaled_v + v_term) - 5)
	x := (d - b) / (a - c)
	z_term := x * a
	z := z_term + b
	return CIEXYZ{
		x: x
		y: y
		z: z
	}
}

fn cie_near_zero(value f32) bool {
	return value == 0 || (value == value && C.fabsf(value) <= f32(0.00000011920928955078125))
}

pub fn CIELabAlpha.from_xyz_alpha(value CIEXYZAlpha, white CIExyY) CIELabAlpha {
	return CIELabAlpha.from_xyz_alpha_precomputed_white_point(value, white.to_xyz(1))
}

pub fn CIELabAlpha.from_xyz_alpha_precomputed_white_point(value CIEXYZAlpha, white CIEXYZ) CIELabAlpha {
	color := CIELab.from_xyz_precomputed_white_point(value.to_xyz(), white)
	return CIELabAlpha{
		l:     color.l
		a:     color.a
		b:     color.b
		alpha: value.a
	}
}

pub fn (value CIELabAlpha) to_xyz_alpha(white CIExyY) CIEXYZAlpha {
	return value.to_xyz_alpha_precomputed_white_point(white.to_xyz(1))
}

pub fn (value CIELabAlpha) to_xyz_alpha_precomputed_white_point(white CIEXYZ) CIEXYZAlpha {
	color := value.to_lab().to_xyz_precomputed_white_point(white)
	return CIEXYZAlpha{
		x: color.x
		y: color.y
		z: color.z
		a: value.alpha
	}
}

pub fn (value CIELabAlpha) to_lab() CIELab {
	return CIELab{
		l: value.l
		a: value.a
		b: value.b
	}
}

pub fn CIELab.from_lchab(value CIELCHab) CIELab {
	return value.to_lab()
}

pub fn (value CIELab) to_lchab() CIELCHab {
	return CIELCHab.from_lab(value)
}

pub fn CIELabAlpha.from_lchab_alpha(value CIELCHabAlpha) CIELabAlpha {
	return value.to_lab_alpha()
}

pub fn (value CIELabAlpha) to_lchab_alpha() CIELCHabAlpha {
	return CIELCHabAlpha.from_lab_alpha(value)
}

pub fn CIELuvAlpha.from_xyz_alpha(value CIEXYZAlpha, white CIExyY) CIELuvAlpha {
	return CIELuvAlpha.from_xyz_alpha_precomputed_white_point(value, white.to_xyz(1))
}

pub fn CIELuvAlpha.from_xyz_alpha_precomputed_white_point(value CIEXYZAlpha, white CIEXYZ) CIELuvAlpha {
	color := CIELuv.from_xyz_precomputed_white_point(value.to_xyz(), white)
	return CIELuvAlpha{
		l:     color.l
		u:     color.u
		v:     color.v
		alpha: value.a
	}
}

pub fn (value CIELuvAlpha) to_xyz_alpha(white CIExyY) CIEXYZAlpha {
	return value.to_xyz_alpha_precomputed_white_point(white.to_xyz(1))
}

pub fn (value CIELuvAlpha) to_xyz_alpha_precomputed_white_point(white CIEXYZ) CIEXYZAlpha {
	color := value.to_luv().to_xyz_precomputed_white_point(white)
	return CIEXYZAlpha{
		x: color.x
		y: color.y
		z: color.z
		a: value.alpha
	}
}

pub fn (value CIELuvAlpha) to_luv() CIELuv {
	return CIELuv{
		l: value.l
		u: value.u
		v: value.v
	}
}

pub fn CIELuv.from_lchuv(value CIELCHuv) CIELuv {
	return value.to_luv()
}

pub fn (value CIELuv) to_lchuv() CIELCHuv {
	return CIELCHuv.from_luv(value)
}

pub fn CIELuvAlpha.from_lchuv_alpha(value CIELCHuvAlpha) CIELuvAlpha {
	return value.to_luv_alpha()
}

pub fn (value CIELuvAlpha) to_lchuv_alpha() CIELCHuvAlpha {
	return CIELCHuvAlpha.from_luv_alpha(value)
}

pub fn CIELCHab.from_lab(value CIELab) CIELCHab {
	x_squared := value.a * value.a
	y_squared := value.b * value.b
	c := C.sqrtf(x_squared + y_squared)
	mut h := color_atan2_f32(value.b, value.a)
	if h < 0 { h += f32(2.0 * 3.14159265358979323846) }
	return CIELCHab{
		l: value.l
		c: c
		h: h
	}
}

pub fn (value CIELCHab) to_lab() CIELab {
	return CIELab{
		l: value.l
		a: value.c * color_cos_f32(value.h)
		b: value.c * color_sin_f32(value.h)
	}
}

pub fn CIELCHabAlpha.from_lab_alpha(value CIELabAlpha) CIELCHabAlpha {
	color := CIELCHab.from_lab(value.to_lab())
	return CIELCHabAlpha{
		l:     color.l
		c:     color.c
		h:     color.h
		alpha: value.alpha
	}
}

pub fn (value CIELCHabAlpha) to_lab_alpha() CIELabAlpha {
	color := value.to_lchab().to_lab()
	return CIELabAlpha{
		l:     color.l
		a:     color.a
		b:     color.b
		alpha: value.alpha
	}
}

pub fn (value CIELCHabAlpha) to_lchab() CIELCHab {
	return CIELCHab{
		l: value.l
		c: value.c
		h: value.h
	}
}

pub fn CIELCHuv.from_luv(value CIELuv) CIELCHuv {
	x_squared := value.u * value.u
	y_squared := value.v * value.v
	c := C.sqrtf(x_squared + y_squared)
	mut h := color_atan2_f32(value.v, value.u)
	if h < 0 { h += f32(2.0 * 3.14159265358979323846) }
	return CIELCHuv{
		l: value.l
		c: c
		h: h
	}
}

pub fn (value CIELCHuv) to_luv() CIELuv {
	return CIELuv{
		l: value.l
		u: value.c * color_cos_f32(value.h)
		v: value.c * color_sin_f32(value.h)
	}
}

pub fn CIELCHuvAlpha.from_luv_alpha(value CIELuvAlpha) CIELCHuvAlpha {
	color := CIELCHuv.from_luv(value.to_luv())
	return CIELCHuvAlpha{
		l:     color.l
		c:     color.c
		h:     color.h
		alpha: value.alpha
	}
}

pub fn (value CIELCHuvAlpha) to_luv_alpha() CIELuvAlpha {
	color := value.to_lchuv().to_luv()
	return CIELuvAlpha{
		l:     color.l
		u:     color.u
		v:     color.v
		alpha: value.alpha
	}
}

pub fn (value CIELCHuvAlpha) to_lchuv() CIELCHuv {
	return CIELCHuv{
		l: value.l
		c: value.c
		h: value.h
	}
}

pub fn OkLCh.from_oklab(value Oklab) OkLCh {
	x_squared := value.a * value.a
	y_squared := value.b * value.b
	c := C.sqrtf(x_squared + y_squared)
	mut h := color_atan2_f32(value.b, value.a)
	if h < 0 { h += f32(2.0 * 3.14159265358979323846) }
	return OkLCh{
		l: value.l
		c: c
		h: h
	}
}

pub fn (value OkLCh) to_oklab() Oklab {
	return Oklab{
		l: value.l
		a: value.c * color_cos_f32(value.h)
		b: value.c * color_sin_f32(value.h)
	}
}

pub fn OkLChAlpha.from_oklab_alpha(value OklabAlpha) OkLChAlpha {
	color := OkLCh.from_oklab(value.to_oklab())
	return OkLChAlpha{
		l:     color.l
		c:     color.c
		h:     color.h
		alpha: value.alpha
	}
}

pub fn (value OkLChAlpha) to_oklab_alpha() OklabAlpha {
	color := value.to_ok_lch().to_oklab()
	return OklabAlpha{
		l:     color.l
		a:     color.a
		b:     color.b
		alpha: value.alpha
	}
}

pub fn (value OkLChAlpha) to_ok_lch() OkLCh {
	return OkLCh{
		l: value.l
		c: value.c
		h: value.h
	}
}

pub fn Oklab.from_xyz(value CIEXYZ) Oklab {
	return OklabAlpha.from_xyz_alpha(CIEXYZAlpha{ x: value.x, y: value.y, z: value.z }).to_oklab()
}

pub fn (value Oklab) to_xyz() CIEXYZ {
	return value.to_oklab_alpha().to_xyz_alpha().to_xyz()
}

pub fn (value Oklab) to_oklab_alpha() OklabAlpha {
	return OklabAlpha{
		l: value.l
		a: value.a
		b: value.b
	}
}

pub fn (value Oklab) to_ok_lch() OkLCh {
	return OkLCh.from_oklab(value)
}

pub fn (value OklabAlpha) to_oklab() Oklab {
	return Oklab{
		l: value.l
		a: value.a
		b: value.b
	}
}

pub fn (value OklabAlpha) to_ok_lch_alpha() OkLChAlpha {
	return OkLChAlpha.from_oklab_alpha(value)
}

const oklab_xyza_to_lms = Float4x4.from_array([f32(0.8189330101), 0.3618667424, -0.1288597137,
	0, 0.0329845436, 0.9293118715, 0.0361456387, 0, 0.0482003018, 0.2643662691, 0.6338517070, 0,
	0, 0, 0, 1]!)
const oklab_lms_prime_to_lab = Float4x4.from_array([f32(0.2104542553), 0.7936177850, -0.0040720468,
	0, 1.9779984951, -2.4285922050, 0.4505937099, 0, 0.0259040371, 0.7827717662, -0.8086757660,
	0, 0, 0, 0, 1]!)
const oklab_lab_to_lms_prime = oklab_lms_prime_to_lab.inverse()
const oklab_lms_to_xyza = oklab_xyza_to_lms.inverse()

pub fn OklabAlpha.from_xyz_alpha(value CIEXYZAlpha) OklabAlpha {
	mut lmsa := oklab_xyza_to_lms.mul_vector(value.to_float4())
	for i in 0 .. 3 {
		lmsa[i] = color_cbrt_f32(lmsa[i])
	}
	laba := oklab_lms_prime_to_lab.mul_vector(lmsa)
	return OklabAlpha{
		l:     laba[0]
		a:     laba[1]
		b:     laba[2]
		alpha: value.a
	}
}

pub fn (value OklabAlpha) to_xyz_alpha() CIEXYZAlpha {
	mut lmsa := oklab_lab_to_lms_prime.mul_vector(value.to_float4())
	for i in 0 .. 3 {
		lmsa[i] = lmsa[i] * lmsa[i] * lmsa[i]
	}
	return CIEXYZAlpha.from_float4(oklab_lms_to_xyza.mul_vector(lmsa))
}

struct HSLuvLine {
	a f32
	b f32
}

fn (value HSLuvLine) ray_length_until_intersect(angle f32) f32 {
	product := value.a * color_cos_f32(angle)
	return value.b / (color_sin_f32(angle) - product)
}

pub fn HSLuv.from_cielchuv(value CIELCHuv, xyz_to_rgb_matrix Float4x4) HSLuv {
	s := if value.l > f32(0.99999999999) || value.l < f32(0.00000001) {
		f32(0)
	} else {
		value.c / (hsluv_max_chroma_for_lh(value.l, value.h, xyz_to_rgb_matrix) / 100)
	}
	h := if value.c < f32(0.00000001) { f32(0) } else { value.h }
	return HSLuv{
		h: h
		s: s
		l: value.l
	}
}

pub fn (value HSLuv) to_cielchuv(xyz_to_rgb_matrix Float4x4) CIELCHuv {
	c := if value.l > f32(0.99999999999) || value.l < f32(0.00000001) {
		f32(0)
	} else {
		(hsluv_max_chroma_for_lh(value.l, value.h, xyz_to_rgb_matrix) / 100) * value.s
	}
	h := if value.s < f32(0.00000001) { f32(0) } else { value.h }
	return CIELCHuv{
		l: value.l
		c: c
		h: h
	}
}

fn hsluv_max_chroma_for_lh(l f32, h f32, matrix Float4x4) f32 {
	mut minimum := f32(3.40282346638528859812e38)
	bounds := hsluv_bounds(l, matrix)
	for i in 0 .. 6 {
		bound := bounds[i]
		length := bound.ray_length_until_intersect(h)
		if length >= 0 && length < minimum { minimum = length }
	}
	return minimum
}

fn hsluv_bounds(l f32, matrix Float4x4) [6]HSLuvLine {
	scaled_l := l * f32(100)
	tl := scaled_l + 16
	sub1 := tl * tl * tl / f32(1560896)
	sub2 := if sub1 > cie_epsilon { sub1 } else { f32(1) / cie_kappa }
	mut bounds := [6]HSLuvLine{}
	for channel in 0 .. 3 {
		m1 := matrix.matrix[channel][0]
		m2 := matrix.matrix[channel][1]
		m3 := matrix.matrix[channel][2]
		for t in 0 .. 2 {
			top1_a := f32(284517) * m1
			top1_b := f32(94839) * m3
			top1 := (top1_a - top1_b) * sub2
			top2_a := f32(838422) * m3
			top2_b := f32(769860) * m2
			top2_c := f32(731718) * m1
			top2_d := (top2_a + top2_b + top2_c) * scaled_l * sub2
			top2_e := f32(769860) * f32(t) * scaled_l
			top2 := top2_d - top2_e
			bottom_a := f32(632260) * m3
			bottom_b := f32(126452) * m2
			bottom_c := (bottom_a - bottom_b) * sub2
			bottom := bottom_c + f32(126452) * f32(t)
			bounds[channel * 2 + t] = HSLuvLine{
				a: top1 / bottom
				b: top2 / bottom
			}
		}
	}
	return bounds
}

pub fn HSLuvAlpha.from_cielchuv_alpha(value CIELCHuvAlpha, matrix Float4x4) HSLuvAlpha {
	color := HSLuv.from_cielchuv(value.to_lchuv(), matrix)
	return HSLuvAlpha{
		h:     color.h
		s:     color.s
		l:     color.l
		alpha: value.alpha
	}
}

pub fn (value HSLuvAlpha) to_cielchuv_alpha(matrix Float4x4) CIELCHuvAlpha {
	color := value.to_hsluv().to_cielchuv(matrix)
	return CIELCHuvAlpha{
		l:     color.l
		c:     color.c
		h:     color.h
		alpha: value.alpha
	}
}

pub fn (value HSLuvAlpha) to_hsluv() HSLuv {
	return HSLuv{
		h: value.h
		s: value.s
		l: value.l
	}
}

// Preserve the pinned HSLuvAlpha factory's wrong return type.
pub fn HSLuvAlpha.from_float4(value Float4) CIELuvAlpha {
	return CIELuvAlpha.from_float4(value)
}

// The pinned namespace accepts CIELuvAlpha here, as does its factory.
pub fn HSLuvAlpha.to_float4(value CIELuvAlpha) Float4 {
	return value.to_float4()
}

fn hsluv_line_intersect(left HSLuvLine, right HSLuvLine) f32 {
	return (left.b - right.b) / (right.a - left.a)
}
