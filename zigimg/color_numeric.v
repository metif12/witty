module zigimg

import math.bits

#include <math.h>
#include "@VMODROOT/zigimg/color_trig.h"

fn C.sqrtf(f32) f32
fn C.sinf(f32) f32
fn C.cosf(f32) f32
fn C.witty_color_sincosf(f32, &f32, &f32)
fn C.expf(f32) f32
fn C.logf(f32) f32
fn C.truncf(f32) f32
fn C.fabsf(f32) f32

// Public cylindrical conversions retain independent source calls. LLVM may
// pair them after inlining into a consumer; that depends on the caller.
@[noinline]
fn color_sin_f32(value f32) f32 {
	return C.sinf(value)
}

@[noinline]
fn color_cos_f32(value f32) f32 {
	return C.cosf(value)
}

// Source Debug uses independent calls; Darwin ReleaseSafe selects a paired
// intrinsic. The primitive wrapper follows the corresponding V build mode.
fn color_sincos_f32(value f32) (f32, f32) {
	mut sine := f32(0)
	mut cosine := f32(0)
	C.witty_color_sincosf(value, &sine, &cosine)
	return sine, cosine
}

fn color_float_bits(value f32) u32 {
	return unsafe { *(&u32(&value)) }
}

fn color_bits_float(value u32) f32 {
	return unsafe { *(&f32(&value)) }
}

// Zig 0.15.2 math.cbrt's f32 branch, including its two f64 Newton steps.
// Original implementation is the MIT-licensed musl cbrtf algorithm.
fn color_cbrt_f32(value f32) f32 {
	mut raw := color_float_bits(value)
	mut magnitude := raw & 0x7fffffff
	if magnitude >= 0x7f800000 { return value + value }
	if magnitude < 0x00800000 {
		if magnitude == 0 { return value }
		raw = color_float_bits(value * f32(16777216))
		magnitude = raw & 0x7fffffff
		magnitude = magnitude / 3 + 642849266
	} else {
		magnitude = magnitude / 3 + 709958130
	}
	raw = (raw & 0x80000000) | magnitude
	mut t := f64(color_bits_float(raw))
	mut r := t * t * t
	t = t * (f64(value) + f64(value) + r) / (f64(value) + r + r)
	r = t * t * t
	t = t * (f64(value) + f64(value) + r) / (f64(value) + r + r)
	return f32(t)
}

// Zig 0.15.2's MIT-licensed musl atan32 and atan2_32 branches.
fn color_atan_f32(value f32) f32 {
	hi := [f32(4.6364760399e-01), 7.8539812565e-01, 9.8279368877e-01, 1.5707962513e+00]!
	lo := [f32(5.0121582440e-09), 3.7748947079e-08, 3.4473217170e-08, 7.5497894159e-08]!
	coefficients := [f32(3.3333328366e-01), -1.9999158382e-01, 1.4253635705e-01, -1.0648017377e-01,
		6.1687607318e-02]!
	mut x := value
	raw := color_float_bits(x)
	sign := raw >> 31
	magnitude := raw & 0x7fffffff
	if magnitude >= 0x4c800000 {
		if x != x { return x }
		z := hi[3] + f32(7.5231638452626400509999138382224e-37)
		return if sign != 0 { -z } else { z }
	}
	mut id := -1
	if magnitude < 0x3ee00000 {
		if magnitude < 0x39800000 { return x }
	} else {
		x = C.fabsf(x)
		if magnitude < 0x3f980000 {
			if magnitude < 0x3f300000 {
				id = 0
				product := f32(2) * x
				x = (product - 1) / (2 + x)
			} else {
				id = 1
				x = (x - 1) / (x + 1)
			}
		} else if magnitude < 0x401c0000 {
			id = 2
			product := f32(1.5) * x
			x = (x - f32(1.5)) / (1 + product)
		} else {
			id = 3
			x = f32(-1) / x
		}
	}
	z := x * x
	w := z * z
	term_a := w * coefficients[4]
	term_b := w * (coefficients[2] + term_a)
	s1 := z * (coefficients[0] + term_b)
	term_c := w * coefficients[3]
	s2 := w * (coefficients[1] + term_c)
	product := x * (s1 + s2)
	if id >= 0 {
		zz := hi[id] - ((product - lo[id]) - x)
		return if sign != 0 { -zz } else { zz }
	}
	return x - product
}

fn color_atan2_f32(y f32, x f32) f32 {
	pi := f32(3.1415927410)
	pi_lo := f32(-8.7422776573e-08)
	if x != x || y != y { return x + y }
	mut ix := color_float_bits(x)
	mut iy := color_float_bits(y)
	if ix == 0x3f800000 { return color_atan_f32(y) }
	m := ((iy >> 31) & 1) | ((ix >> 30) & 2)
	ix &= 0x7fffffff
	iy &= 0x7fffffff
	if iy == 0 {
		return match m {
			0, 1 { y }
			2 { pi }
			else { -pi }
		}
	}
	if ix == 0 { return if m & 1 != 0 { -pi / 2 } else { pi / 2 }
	 }
	if ix == 0x7f800000 {
		if iy == 0x7f800000 {
			return match m {
				0 { pi / 4 }
				1 { -pi / 4 }
				2 { 3 * pi / 4 }
				else { -3 * pi / 4 }
			}
		}
		return match m {
			0 { f32(0) }
			1 { f32(-0.0) }
			2 { pi }
			else { -pi }
		}
	}
	if ix + (u32(26) << 23) < iy || iy == 0x7f800000 {
		return if m & 1 != 0 { -pi / 2 } else { pi / 2 }
	}
	z := if m & 2 != 0 && iy + (u32(26) << 23) < ix {
		f32(0)
	} else {
		color_atan_f32(C.fabsf(y / x))
	}
	return match m {
		0 { z }
		1 { -z }
		2 { pi - (z - pi_lo) }
		else { (z - pi_lo) - pi }
	}
}

// Zig 0.15.2's BSD-licensed Go pow algorithm, specialized to f32. Its
// exp/log/sqrt builtins use the same native f32 functions through C.
fn color_pow_f32(x f32, y f32) f32 {
	if y == 0 || x == 1 { return 1 }
	if x != x || y != y { return color_bits_float(0x7fc00000) }
	if y == 1 { return x }
	if x == 0 {
		if y < 0 {
			return if color_is_odd_integer(y) {
				color_bits_float(0x7f800000 | (color_float_bits(x) & 0x80000000))
			} else {
				color_bits_float(0x7f800000)
			}
		}
		return if color_is_odd_integer(y) { x } else { f32(0) }
	}
	if color_float_bits(y) & 0x7fffffff == 0x7f800000 {
		if x == -1 { return 1 }
		if (C.fabsf(x) < 1) == (y > 0) { return 0 }
		return color_bits_float(0x7f800000)
	}
	if color_float_bits(x) & 0x7fffffff == 0x7f800000 {
		if x < 0 { return color_pow_f32(f32(1) / x, -y) }
		return if y < 0 { f32(0) } else { x }
	}
	if y == f32(0.5) { return C.sqrtf(x) }
	if y == f32(-0.5) { return f32(1) / C.sqrtf(x) }
	mut yi := C.truncf(C.fabsf(y))
	mut yf := C.fabsf(y) - yi
	if yf != 0 && x < 0 { return color_bits_float(0x7fc00000) }
	if yi >= f32(2147483648) { return C.expf(y * C.logf(x)) }
	mut a1 := f32(1)
	mut ae := 0
	if yf != 0 {
		if yf > f32(0.5) {
			yf -= 1
			yi += 1
		}
		a1 = C.expf(yf * C.logf(x))
	}
	mut x1, mut xe := color_frexp_f32(x)
	mut i := int(yi)
	for i != 0 {
		if xe < -512 || xe > 512 {
			ae += xe
			break
		}
		if i & 1 == 1 {
			a1 *= x1
			ae += xe
		}
		x1 *= x1
		xe *= 2
		if x1 < f32(0.5) {
			x1 += x1
			xe -= 1
		}
		i >>= 1
	}
	if y < 0 {
		a1 = f32(1) / a1
		ae = -ae
	}
	return color_ldexp_f32(a1, ae)
}

fn color_is_odd_integer(value f32) bool {
	if C.fabsf(value) >= f32(9007199254740992) { return false }
	integer := C.truncf(value)
	return value - integer == 0 && i64(integer) & 1 == 1
}

fn color_frexp_f32(value f32) (f32, int) {
	mut raw := color_float_bits(value)
	mantissa := raw & 0x007fffff
	exponent := (raw >> 23) & 0xff
	if exponent == 0 {
		if mantissa == 0 { return value, 0 }
		offset := bits.leading_zeros_32(mantissa) - 9
		raw = (raw & 0x80000000) | 0x3f000000 | ((mantissa << (offset + 1)) & 0x007fffff)
		return color_bits_float(raw), -126 - offset
	}
	return color_bits_float((raw & 0x807fffff) | 0x3f000000), int(exponent) - 126
}

fn color_ldexp_f32(value f32, n int) f32 {
	representation := color_float_bits(value)
	sign := representation & 0x80000000
	if representation & 0x7fffffff >= 0x7f800000 { return value }
	mut exponent := int((representation << 1) >> 24)
	if exponent == 0 { exponent += 8 - bits.leading_zeros_32(representation << 1) }
	if n >= 0 {
		if n > 254 - exponent { return color_bits_float(0x7f800000 | sign) }
		if exponent + n <= 0 { return color_bits_float((representation << n) | sign) }
		if exponent <= 0 {
			result := (u32(n + exponent) << 23) | ((representation << (1 - exponent)) & 0x007fffff)
			return color_bits_float(result | sign)
		}
		return color_bits_float(representation + (u32(n) << 23))
	}
	if n <= -exponent {
		if n < -(23 + exponent) { return color_bits_float(sign) }
		shift := if -n < -(exponent + n) + 1 { -n } else { -(exponent + n) + 1 }
		tie := bits.trailing_zeros_32(representation) == shift - 1
		mut result := (representation & 0x007fffff) | (if exponent > 0 {
			u32(1) << 23
		} else {
			u32(0)
		})
		result >>= shift - 1
		result = ((result + 1) >> 1) & ~(if tie { u32(1) } else { u32(0) })
		return color_bits_float(result | sign)
	}
	return color_bits_float(representation - (u32(-n) << 23))
}
