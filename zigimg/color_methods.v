module zigimg

import encoding.hex
import math

// FromMethods/ToMethods use field-width scaling independently of image format
// conversion. Wider V values back the source's packed u2/u3/u5/u6 channels.
enum ColorChannelKind {
	absent
	integer
	float32
	float64
}
struct ColorMethodChannel {
	kind     ColorChannelKind
	integer  u64
	bits     u8
	float32  f32
	floating f64
}

struct ColorMethodChannels {
mut:
	values [4]ColorMethodChannel
}

fn color_method_max(bits u8) u64 {
	assert bits > 0 && bits <= 64
	return if bits == 64 { ~u64(0) } else { (u64(1) << bits) - 1 }
}

fn color_method_integer(value u64, bits u8) ColorMethodChannel {
	if value > color_method_max(bits) { panic('color channel is outside its native bit width') }
	return ColorMethodChannel{
		kind:    .integer
		integer: value
		bits:    bits
	}
}

fn color_method_channel[V](value V) ColorMethodChannel {
	$if V.unaliased_typ is f32 {
		return ColorMethodChannel{
			kind:    .float32
			float32: value
		}
	} $else $if V.unaliased_typ is f64 {
		return ColorMethodChannel{
			kind:     .float64
			floating: value
		}
	} $else $if V.unaliased_typ is u8 || V.unaliased_typ is u16 || V.unaliased_typ is u32
		|| V.unaliased_typ is u64 || V.unaliased_typ is uint {
		return color_method_integer(u64(value), u8(sizeof(V) * 8))
	} $else {
		$compile_error('ScaleValue requires an unsigned integer or floating point type')
	}
}

fn (channel ColorMethodChannel) scaled_integer(bits u8) u64 {
	maximum := color_method_max(bits)
	match channel.kind {
		.absent {
			return maximum
		}
		.integer {
			if channel.bits > bits { return channel.integer >> (channel.bits - bits) }
			if channel.bits == bits { return channel.integer }
			input_max := color_method_max(channel.bits)
			// Split the product to retain ScaleValue's exact integer rounding
			// when widening to u64, without requiring V to provide u128.
			return channel.integer * (maximum / input_max) +
				(channel.integer * (maximum % input_max) + input_max / 2) / input_max
		}
		.float32 {
			product := channel.float32 * f32(maximum)
			rounded := f32(math.round(f64(product)))
			clamped := color_max_f32(0, color_min_f32(rounded, f32(maximum)))
			if bits >= 32 {
				assert f64(clamped) < math.pow(2, f64(bits))
			}
			return u64(clamped)
		}
		.float64 {
			rounded := math.round(channel.floating * f64(maximum))
			clamped := if rounded < 0 {
				f64(0)
			} else if !(rounded <= f64(maximum)) {
				f64(maximum)
			} else {
				rounded
			}
			if bits >= 32 {
				assert clamped < math.pow(2, f64(bits))
			}
			return u64(clamped)
		}
	}
}

fn color_method_cast[O](channel ColorMethodChannel) O {
	$if O.unaliased_typ is f32 {
		if channel.kind == .integer {
			return O(f32(channel.integer) / f32(color_method_max(channel.bits)))
		}
		if channel.kind == .absent { return O(1) }
		if channel.kind == .float32 { return O(channel.float32) }
		return O(channel.floating)
	} $else $if O.unaliased_typ is f64 {
		if channel.kind == .integer {
			return O(f64(channel.integer) / f64(color_method_max(channel.bits)))
		}
		if channel.kind == .absent { return O(1) }
		if channel.kind == .float32 { return O(channel.float32) }
		return O(channel.floating)
	} $else $if O.unaliased_typ is u8 || O.unaliased_typ is u16 || O.unaliased_typ is u32
		|| O.unaliased_typ is u64 || O.unaliased_typ is uint {
		return O(channel.scaled_integer(u8(sizeof(O) * 8)))
	} $else {
		$compile_error('ScaleValue requires an unsigned integer or floating point type')
	}
}

fn color_method_assign[O](_ O, channel ColorMethodChannel) O {
	return color_method_cast[O](channel)
}

// V callers specify both native types; unlike Zig, V does not infer remaining
// generic arguments after an explicit output type.
fn color_method_scale_constraint[O, I](_ O, _ I) {
	$if O.unaliased_typ is u8 || O.unaliased_typ is u16 || O.unaliased_typ is u32
		|| O.unaliased_typ is u64 || O.unaliased_typ is uint {
		$if I.unaliased_typ is f32 {
			$if sizeof(O) >= 4 {
				$compile_error('ScaleValue source clamp cannot represent the output integer maximum in this float type')
			}
		} $else $if I.unaliased_typ is f64 {
			$if sizeof(O) >= 8 {
				$compile_error('ScaleValue source clamp cannot represent the output integer maximum in this float type')
			}
		}
	}
}

pub fn scale_value[O, I](value I) O {
	color_method_scale_constraint(O(0), value)
	return color_method_cast[O](color_method_channel(value))
}

fn color_method_rgb_channels[D](color D) ColorMethodChannels {
	mut result := ColorMethodChannels{}
	$if D.unaliased_typ is Rgb332 {
		result.values[0] = color_method_integer(u64(color.raw & 7), 3)
		result.values[1] = color_method_integer(u64((color.raw >> 3) & 7), 3)
		result.values[2] = color_method_integer(u64(color.raw >> 6), 2)
	} $else $if D.unaliased_typ is Rgb555 {
		result.values[0] = color_method_integer(u64((color.raw >> 10) & 31), 5)
		result.values[1] = color_method_integer(u64((color.raw >> 5) & 31), 5)
		result.values[2] = color_method_integer(u64(color.raw & 31), 5)
	} $else $if D.unaliased_typ is Rgb565 {
		result.values[0] = color_method_integer(u64(color.raw >> 11), 5)
		result.values[1] = color_method_integer(u64((color.raw >> 5) & 63), 6)
		result.values[2] = color_method_integer(u64(color.raw & 31), 5)
	} $else $if D.unaliased_typ is Bgr555 {
		result.values[0] = color_method_integer(u64(color.raw & 31), 5)
		result.values[1] = color_method_integer(u64((color.raw >> 5) & 31), 5)
		result.values[2] = color_method_integer(u64((color.raw >> 10) & 31), 5)
	} $else {
		_ = color.r
		_ = color.g
		_ = color.b
		$for field in D.fields {
			$if field.name == 'r' {
				result.values[0] = color_method_channel(color.$(field.name))
			} $else $if field.name == 'g' {
				result.values[1] = color_method_channel(color.$(field.name))
			} $else $if field.name == 'b' {
				result.values[2] = color_method_channel(color.$(field.name))
			}
		}
	}
	for index in 0 .. 3 {
		assert result.values[index].kind != .absent
	}
	return result
}

fn color_method_channels[D](color D) ColorMethodChannels {
	mut result := color_method_rgb_channels(color)
	$for field in D.fields {
		$if field.name == 'a' { result.values[3] = color_method_channel(color.$(field.name)) }
	}
	return result
}

fn color_method_construct[T](channels ColorMethodChannels) T {
	$if T.unaliased_typ is Rgb332 {
		return T{
			raw: u8(channels.values[0].scaled_integer(3) | channels.values[1].scaled_integer(3) << 3 | channels.values[2].scaled_integer(2) << 6)
		}
	} $else $if T.unaliased_typ is Rgb555 {
		return T{
			raw: u16(channels.values[0].scaled_integer(5) << 10 | channels.values[1].scaled_integer(5) << 5 | channels.values[2].scaled_integer(5))
		}
	} $else $if T.unaliased_typ is Rgb565 {
		return T{
			raw: u16(channels.values[0].scaled_integer(5) << 11 | channels.values[1].scaled_integer(6) << 5 | channels.values[2].scaled_integer(5))
		}
	} $else $if T.unaliased_typ is Bgr555 {
		return T{
			raw: u16(channels.values[0].scaled_integer(5) | channels.values[1].scaled_integer(5) << 5 | channels.values[2].scaled_integer(5) << 10)
		}
	} $else {
		mut result := T{}
		// Require the same three fields as the source namespace factory.
		_ = result.r
		_ = result.g
		_ = result.b
		$for field in T.fields {
			$if field.name == 'r' {
				result.$(field.name) = color_method_assign(result.$(field.name), channels.values[0])
			} $else $if field.name == 'g' {
				result.$(field.name) = color_method_assign(result.$(field.name), channels.values[1])
			} $else $if field.name == 'b' {
				result.$(field.name) = color_method_assign(result.$(field.name), channels.values[2])
			} $else $if field.name == 'a' {
				if channels.values[3].kind != .absent {
					result.$(field.name) = color_method_assign(result.$(field.name),
						channels.values[3])
				}
			}
		}
		return result
	}
}

pub fn color_from_color[T, S](value S) T {
	mut channels := color_method_rgb_channels(value)
	target_value := T{}
	$for target in T.fields {
		$if target.name == 'r' || target.name == 'g' || target.name == 'b' {
			$if S.unaliased_typ is Rgb332 || S.unaliased_typ is Rgb555 || S.unaliased_typ is Rgb565
				|| S.unaliased_typ is Bgr555 {
				assert true
			} $else {
				$if target.name == 'r' {
					color_method_scale_constraint(target_value.$(target.name), value.r)
				} $else $if target.name == 'g' {
					color_method_scale_constraint(target_value.$(target.name), value.g)
				} $else $if target.name == 'b' {
					color_method_scale_constraint(target_value.$(target.name), value.b)
				}
			}
		} $else $if target.name == 'a' {
			$for field in S.fields {
				$if field.name == 'a' {
					color_method_scale_constraint(target_value.a, value.$(field.name))
				}
			}
		}
	}
	// The source never reads the optional alpha when the target lacks it.
	$for target in T.fields {
		$if target.name == 'a' {
			$for field in S.fields {
				$if field.name == 'a' {
					channels.values[3] = color_method_channel(value.$(field.name))
				}
			}
		}
	}
	return color_method_construct[T](channels)
}

pub fn color_from_grayscale[T, S](gray S) T {
	mut channels := ColorMethodChannels{}
	target_value := T{}
	$for target in T.fields {
		$if target.name == 'r' || target.name == 'g' || target.name == 'b' {
			color_method_scale_constraint(target_value.$(target.name), gray.value)
		} $else $if target.name == 'a' {
			$for field in S.fields {
				$if field.name == 'alpha' {
					color_method_scale_constraint(target_value.a, gray.$(field.name))
				}
			}
		}
	}
	$if S.unaliased_typ is Grayscale1 {
		channels.values[0] = color_method_integer(gray.value, 1)
	} $else $if S.unaliased_typ is Grayscale2 {
		channels.values[0] = color_method_integer(gray.value, 2)
	} $else $if S.unaliased_typ is Grayscale4 {
		channels.values[0] = color_method_integer(gray.value, 4)
	} $else {
		channels.values[0] = color_method_channel(gray.value)
	}
	channels.values[1] = channels.values[0]
	channels.values[2] = channels.values[0]
	$for target in T.fields {
		$if target.name == 'a' {
			$for field in S.fields {
				$if field.name == 'alpha' {
					channels.values[3] = color_method_channel(gray.$(field.name))
				}
			}
		}
	}
	return color_method_construct[T](channels)
}

pub fn color_from_float4[T](value Float4) T {
	mut channels := ColorMethodChannels{}
	target_value := T{}
	$for target in T.fields {
		$if target.name == 'r' || target.name == 'g' || target.name == 'b' || target.name == 'a' {
			color_method_scale_constraint(target_value.$(target.name), value[0])
		}
	}
	for index in 0 .. 4 {
		channels.values[index] = color_method_channel(value[index])
	}
	return color_method_construct[T](channels)
}

pub fn color_from_u32_rgba[T](value u32) T {
	return color_from_color[T, Rgba32](Rgba32{
		r: u8(value >> 24)
		g: u8(value >> 16)
		b: u8(value >> 8)
		a: u8(value)
	})
}

pub fn color_from_u32_rgb[T](value u32) T {
	return color_from_color[T, Rgb24](Rgb24{ r: u8(value >> 16), g: u8(value >> 8), b: u8(value) })
}

pub fn color_from_u64_rgba[T](value u64) T {
	return color_from_color[T, Rgba64](Rgba64{
		r: u16(value >> 48)
		g: u16(value >> 32)
		b: u16(value >> 16)
		a: u16(value)
	})
}

pub fn color_from_u64_rgb[T](value u64) T {
	return color_from_color[T, Rgb48](Rgb48{ r: u16(value >> 32), g: u16(value >> 16), b: u16(value) })
}

pub fn color_from_html_hex[T](value string) !T {
	$if T.unaliased_typ is Rgb332 || T.unaliased_typ is Rgb555 || T.unaliased_typ is Rgb565
		|| T.unaliased_typ is Bgr555 {
		$compile_error('html_hex requires 8-bit channels')
	}
	$for field in T.fields {
		$if field.name == 'r' || field.name == 'g' || field.name == 'b' || field.name == 'a' {
			$if field.typ is u8 {
				assert true
			} $else {
				$compile_error('html_hex requires 8-bit channels')
			}
		}
	}
	mut has_alpha := false
	$for field in T.fields {
		$if field.name == 'a' { has_alpha = true }
	}
	if value.len == 0 || value[0] != `#` || !(value.len in [4, 7]
		|| (has_alpha && value.len in [5, 9])) {
		return error('InvalidHtmlHexString')
	}
	mut text := value[1..]
	if value.len in [4, 5] {
		text = ''
		for byte in value[1..].bytes() {
			text += byte.ascii_str() + byte.ascii_str()
		}
	}
	bytes := hex.decode(text) or { return error('InvalidHtmlHexString') }
	mut parsed := Rgba32{
		r: bytes[0]
		g: bytes[1]
		b: bytes[2]
	}
	if bytes.len == 4 { parsed.a = bytes[3] }
	return color_from_color[T, Rgba32](parsed)
}

pub fn color_to_u32_rgba[D](color D) u32 {
	channels := color_method_channels(color)
	return u32(channels.values[0].scaled_integer(8)) << 24 | u32(channels.values[1].scaled_integer(8)) << 16 | u32(channels.values[2].scaled_integer(8)) << 8 | u32(channels.values[3].scaled_integer(8))
}

pub fn color_to_u32_rgb[D](color D) u32 {
	channels := color_method_channels(color)
	return u32(channels.values[0].scaled_integer(8)) << 16 | u32(channels.values[1].scaled_integer(8)) << 8 | u32(channels.values[2].scaled_integer(8))
}

pub fn color_to_u64_rgba[D](color D) u64 {
	channels := color_method_channels(color)
	return channels.values[0].scaled_integer(16) << 48 | channels.values[1].scaled_integer(16) << 32 | channels.values[2].scaled_integer(16) << 16 | channels.values[3].scaled_integer(16)
}

pub fn color_to_u64_rgb[D](color D) u64 {
	channels := color_method_channels(color)
	return channels.values[0].scaled_integer(16) << 32 | channels.values[1].scaled_integer(16) << 16 | channels.values[2].scaled_integer(16)
}

pub fn color_to_float4[D](color D) Float4 {
	channels := color_method_channels(color)
	mut result := Float4{}
	for index in 0 .. 4 {
		result[index] = color_method_cast[f32](channels.values[index])
	}
	return result
}

fn color_method_premul_scale_constraint[O, I](target O, _ I) {
	$if I.unaliased_typ is f64 {
		color_method_scale_constraint(target, f64(0))
	} $else {
		color_method_scale_constraint(target, f32(0))
	}
}

pub fn color_premultiplied_alpha[D](color D) D {
	mut channels := color_method_channels(color)
	$for field in D.fields {
		$if field.name == 'a' {
			color_method_premul_scale_constraint(color.r, color.a)
			color_method_premul_scale_constraint(color.g, color.a)
			color_method_premul_scale_constraint(color.b, color.a)
		}
	}
	if channels.values[3].kind == .absent { return color }
	alpha := color_method_cast[f32](channels.values[3])
	alpha64 := if channels.values[3].kind == .float64 {
		channels.values[3].floating
	} else {
		f64(alpha)
	}
	for index in 0 .. 3 {
		if channels.values[3].kind == .float64 || channels.values[index].kind == .float64 {
			// Integer components still normalize through f32 before promotion.
			component := if channels.values[index].kind == .float64 {
				channels.values[index].floating
			} else {
				f64(color_method_cast[f32](channels.values[index]))
			}
			channels.values[index] = color_method_channel(component * alpha64)
		} else {
			channels.values[index] =
				color_method_channel(color_method_cast[f32](channels.values[index]) * alpha)
		}
	}
	$if D.unaliased_typ is Rgb332 || D.unaliased_typ is Rgb555 || D.unaliased_typ is Rgb565
		|| D.unaliased_typ is Bgr555 {
		return color_method_construct[D](channels)
	} $else {
		mut result := color
		$for field in D.fields {
			$if field.name == 'r' {
				result.$(field.name) = color_method_assign(result.$(field.name), channels.values[0])
			} $else $if field.name == 'g' {
				result.$(field.name) = color_method_assign(result.$(field.name), channels.values[1])
			} $else $if field.name == 'b' {
				result.$(field.name) = color_method_assign(result.$(field.name), channels.values[2])
			}
		}
		return result
	}
}

fn color_method_to_target[T, S](value S) T {
	// Pinned V mutates static-call resolution when a built-in alias is used
	// beside other target specializations. Its factory has known behavior.
	$if T.unaliased_typ is Rgb332 || T.unaliased_typ is Rgb555 || T.unaliased_typ is Rgb565
		|| T.unaliased_typ is Bgr555 || T.unaliased_typ is Rgb24 || T.unaliased_typ is Rgba32
		|| T.unaliased_typ is Bgr24 || T.unaliased_typ is Bgra32 || T.unaliased_typ is Rgb48
		|| T.unaliased_typ is Rgba64 || T.unaliased_typ is Colorf32 {
		return color_from_color[T, S](value)
	} $else {
		return T.from_color(value)
	}
}

// Scalar constructors and receiver adapters use V static methods for the
// source's zero-sized `from` namespace and receiver methods for its `to` field.
// A source void alpha argument is represented by this empty value.
pub struct NoColorAlpha {}

pub fn color_from_array[T, V](value [4]V) T {
	$if T.unaliased_typ is Rgb332 || T.unaliased_typ is Rgb565 {
		$compile_error('color_from_array requires matching channel types')
	} $else $if T.unaliased_typ is Rgb555 || T.unaliased_typ is Bgr555 {
		$if V is u8 {
			assert true
		} $else {
			$compile_error('packed 5-bit channels require u8 storage')
		}
		mut channels := ColorMethodChannels{}
		for index in 0 .. 4 {
			channels.values[index] = color_method_integer(u64(value[index]), 5)
		}
		return color_method_construct[T](channels)
	} $else {
		$for field in T.fields {
			$if field.name == 'r' || field.name == 'g' || field.name == 'b' || field.name == 'a' {
				$if field.typ is V {
					assert true
				} $else {
					$compile_error('color_from_array requires matching channel types')
				}
			}
		}
		mut channels := ColorMethodChannels{}
		for index in 0 .. 4 {
			channels.values[index] = color_method_channel(value[index])
		}
		return color_method_construct[T](channels)
	}
}

pub fn Rgb332.rgb(r u8, g u8, b u8) Rgb332 {
	channels := ColorMethodChannels{
		values: [
			color_method_integer(u64(r), 3),
			color_method_integer(u64(g), 3),
			color_method_integer(u64(b), 2),
			ColorMethodChannel{},
		]!
	}
	return color_method_construct[Rgb332](channels)
}

pub fn Rgb332.rgba(r u8, g u8, b u8, a NoColorAlpha) Rgb332 {
	return Rgb332.rgb(r, g, b)
}

pub fn Rgb332.from_color[S](value S) Rgb332 {
	return color_from_color[Rgb332, S](value)
}

pub fn Rgb332.from_grayscale[S](value S) Rgb332 {
	return color_from_grayscale[Rgb332, S](value)
}

pub fn Rgb332.from_u32_rgb(value u32) Rgb332 {
	return color_from_u32_rgb[Rgb332](value)
}

pub fn Rgb332.from_u32_rgba(value u32) Rgb332 {
	return color_from_u32_rgba[Rgb332](value)
}

pub fn Rgb332.from_u64_rgb(value u64) Rgb332 {
	return color_from_u64_rgb[Rgb332](value)
}

pub fn Rgb332.from_u64_rgba(value u64) Rgb332 {
	return color_from_u64_rgba[Rgb332](value)
}

pub fn Rgb332.from_float4(value Float4) Rgb332 {
	return color_from_float4[Rgb332](value)
}

pub fn (color Rgb332) to_color[T]() T {
	return color_method_to_target[T, Rgb332](color)
}

pub fn (color Rgb332) to_u32_rgb() u32 {
	return color_to_u32_rgb(color)
}

pub fn (color Rgb332) to_u32_rgba() u32 {
	return color_to_u32_rgba(color)
}

pub fn (color Rgb332) to_u64_rgb() u64 {
	return color_to_u64_rgb(color)
}

pub fn (color Rgb332) to_u64_rgba() u64 {
	return color_to_u64_rgba(color)
}

pub fn (color Rgb332) to_float4() Float4 {
	return color_to_float4(color)
}

pub fn (color Rgb332) premultiplied_alpha() Rgb332 {
	return color_premultiplied_alpha(color)
}

pub fn Rgb555.rgb(r u8, g u8, b u8) Rgb555 {
	channels := ColorMethodChannels{
		values: [
			color_method_integer(u64(r), 5),
			color_method_integer(u64(g), 5),
			color_method_integer(u64(b), 5),
			ColorMethodChannel{},
		]!
	}
	return color_method_construct[Rgb555](channels)
}

pub fn Rgb555.rgba(r u8, g u8, b u8, a NoColorAlpha) Rgb555 {
	return Rgb555.rgb(r, g, b)
}

pub fn Rgb555.from_color[S](value S) Rgb555 {
	return color_from_color[Rgb555, S](value)
}

pub fn Rgb555.from_grayscale[S](value S) Rgb555 {
	return color_from_grayscale[Rgb555, S](value)
}

pub fn Rgb555.from_u32_rgb(value u32) Rgb555 {
	return color_from_u32_rgb[Rgb555](value)
}

pub fn Rgb555.from_u32_rgba(value u32) Rgb555 {
	return color_from_u32_rgba[Rgb555](value)
}

pub fn Rgb555.from_u64_rgb(value u64) Rgb555 {
	return color_from_u64_rgb[Rgb555](value)
}

pub fn Rgb555.from_u64_rgba(value u64) Rgb555 {
	return color_from_u64_rgba[Rgb555](value)
}

pub fn Rgb555.from_float4(value Float4) Rgb555 {
	return color_from_float4[Rgb555](value)
}

pub fn Rgb555.from_array(value [4]u8) Rgb555 {
	return color_from_array[Rgb555, u8](value)
}

pub fn (color Rgb555) to_color[T]() T {
	return color_method_to_target[T, Rgb555](color)
}

pub fn (color Rgb555) to_u32_rgb() u32 {
	return color_to_u32_rgb(color)
}

pub fn (color Rgb555) to_u32_rgba() u32 {
	return color_to_u32_rgba(color)
}

pub fn (color Rgb555) to_u64_rgb() u64 {
	return color_to_u64_rgb(color)
}

pub fn (color Rgb555) to_u64_rgba() u64 {
	return color_to_u64_rgba(color)
}

pub fn (color Rgb555) to_float4() Float4 {
	return color_to_float4(color)
}

pub fn (color Rgb555) to_array() [4]u8 {
	channels := color_method_channels(color)
	return [u8(channels.values[0].integer), u8(channels.values[1].integer),
		u8(channels.values[2].integer), u8(31)]!
}

pub fn (color Rgb555) premultiplied_alpha() Rgb555 {
	return color_premultiplied_alpha(color)
}

pub fn Rgb565.rgb(r u8, g u8, b u8) Rgb565 {
	channels := ColorMethodChannels{
		values: [
			color_method_integer(u64(r), 5),
			color_method_integer(u64(g), 6),
			color_method_integer(u64(b), 5),
			ColorMethodChannel{},
		]!
	}
	return color_method_construct[Rgb565](channels)
}

pub fn Rgb565.rgba(r u8, g u8, b u8, a NoColorAlpha) Rgb565 {
	return Rgb565.rgb(r, g, b)
}

pub fn Rgb565.from_color[S](value S) Rgb565 {
	return color_from_color[Rgb565, S](value)
}

pub fn Rgb565.from_grayscale[S](value S) Rgb565 {
	return color_from_grayscale[Rgb565, S](value)
}

pub fn Rgb565.from_u32_rgb(value u32) Rgb565 {
	return color_from_u32_rgb[Rgb565](value)
}

pub fn Rgb565.from_u32_rgba(value u32) Rgb565 {
	return color_from_u32_rgba[Rgb565](value)
}

pub fn Rgb565.from_u64_rgb(value u64) Rgb565 {
	return color_from_u64_rgb[Rgb565](value)
}

pub fn Rgb565.from_u64_rgba(value u64) Rgb565 {
	return color_from_u64_rgba[Rgb565](value)
}

pub fn Rgb565.from_float4(value Float4) Rgb565 {
	return color_from_float4[Rgb565](value)
}

pub fn (color Rgb565) to_color[T]() T {
	return color_method_to_target[T, Rgb565](color)
}

pub fn (color Rgb565) to_u32_rgb() u32 {
	return color_to_u32_rgb(color)
}

pub fn (color Rgb565) to_u32_rgba() u32 {
	return color_to_u32_rgba(color)
}

pub fn (color Rgb565) to_u64_rgb() u64 {
	return color_to_u64_rgb(color)
}

pub fn (color Rgb565) to_u64_rgba() u64 {
	return color_to_u64_rgba(color)
}

pub fn (color Rgb565) to_float4() Float4 {
	return color_to_float4(color)
}

pub fn (color Rgb565) premultiplied_alpha() Rgb565 {
	return color_premultiplied_alpha(color)
}

pub fn Bgr555.rgb(r u8, g u8, b u8) Bgr555 {
	channels := ColorMethodChannels{
		values: [
			color_method_integer(u64(r), 5),
			color_method_integer(u64(g), 5),
			color_method_integer(u64(b), 5),
			ColorMethodChannel{},
		]!
	}
	return color_method_construct[Bgr555](channels)
}

pub fn Bgr555.rgba(r u8, g u8, b u8, a NoColorAlpha) Bgr555 {
	return Bgr555.rgb(r, g, b)
}

pub fn Bgr555.from_color[S](value S) Bgr555 {
	return color_from_color[Bgr555, S](value)
}

pub fn Bgr555.from_grayscale[S](value S) Bgr555 {
	return color_from_grayscale[Bgr555, S](value)
}

pub fn Bgr555.from_u32_rgb(value u32) Bgr555 {
	return color_from_u32_rgb[Bgr555](value)
}

pub fn Bgr555.from_u32_rgba(value u32) Bgr555 {
	return color_from_u32_rgba[Bgr555](value)
}

pub fn Bgr555.from_u64_rgb(value u64) Bgr555 {
	return color_from_u64_rgb[Bgr555](value)
}

pub fn Bgr555.from_u64_rgba(value u64) Bgr555 {
	return color_from_u64_rgba[Bgr555](value)
}

pub fn Bgr555.from_float4(value Float4) Bgr555 {
	return color_from_float4[Bgr555](value)
}

pub fn Bgr555.from_array(value [4]u8) Bgr555 {
	return color_from_array[Bgr555, u8](value)
}

pub fn (color Bgr555) to_color[T]() T {
	return color_method_to_target[T, Bgr555](color)
}

pub fn (color Bgr555) to_u32_rgb() u32 {
	return color_to_u32_rgb(color)
}

pub fn (color Bgr555) to_u32_rgba() u32 {
	return color_to_u32_rgba(color)
}

pub fn (color Bgr555) to_u64_rgb() u64 {
	return color_to_u64_rgb(color)
}

pub fn (color Bgr555) to_u64_rgba() u64 {
	return color_to_u64_rgba(color)
}

pub fn (color Bgr555) to_float4() Float4 {
	return color_to_float4(color)
}

pub fn (color Bgr555) to_array() [4]u8 {
	channels := color_method_channels(color)
	return [u8(channels.values[0].integer), u8(channels.values[1].integer),
		u8(channels.values[2].integer), u8(31)]!
}

pub fn (color Bgr555) premultiplied_alpha() Bgr555 {
	return color_premultiplied_alpha(color)
}

pub fn Rgb24.rgb(r u8, g u8, b u8) Rgb24 {
	return Rgb24{
		r: r
		g: g
		b: b
	}
}

pub fn Rgb24.rgba(r u8, g u8, b u8, a NoColorAlpha) Rgb24 {
	return Rgb24.rgb(r, g, b)
}

pub fn Rgb24.from_color[S](value S) Rgb24 {
	return color_from_color[Rgb24, S](value)
}

pub fn Rgb24.from_grayscale[S](value S) Rgb24 {
	return color_from_grayscale[Rgb24, S](value)
}

pub fn Rgb24.from_u32_rgb(value u32) Rgb24 {
	return color_from_u32_rgb[Rgb24](value)
}

pub fn Rgb24.from_u32_rgba(value u32) Rgb24 {
	return color_from_u32_rgba[Rgb24](value)
}

pub fn Rgb24.from_u64_rgb(value u64) Rgb24 {
	return color_from_u64_rgb[Rgb24](value)
}

pub fn Rgb24.from_u64_rgba(value u64) Rgb24 {
	return color_from_u64_rgba[Rgb24](value)
}

pub fn Rgb24.from_float4(value Float4) Rgb24 {
	return color_from_float4[Rgb24](value)
}

pub fn Rgb24.from_array(value [4]u8) Rgb24 {
	return color_from_array[Rgb24, u8](value)
}

pub fn Rgb24.from_html_hex(value string) !Rgb24 {
	return color_from_html_hex[Rgb24](value)
}

pub fn (color Rgb24) to_color[T]() T {
	return color_method_to_target[T, Rgb24](color)
}

pub fn (color Rgb24) to_u32_rgb() u32 {
	return color_to_u32_rgb(color)
}

pub fn (color Rgb24) to_u32_rgba() u32 {
	return color_to_u32_rgba(color)
}

pub fn (color Rgb24) to_u64_rgb() u64 {
	return color_to_u64_rgb(color)
}

pub fn (color Rgb24) to_u64_rgba() u64 {
	return color_to_u64_rgba(color)
}

pub fn (color Rgb24) to_float4() Float4 {
	return color_to_float4(color)
}

pub fn (color Rgb24) to_array() [4]u8 {
	return [color.r, color.g, color.b, u8(255)]!
}

pub fn (color Rgb24) premultiplied_alpha() Rgb24 {
	return color_premultiplied_alpha(color)
}

pub fn Rgba32.rgb(r u8, g u8, b u8) Rgba32 {
	return Rgba32{
		r: r
		g: g
		b: b
	}
}

pub fn Rgba32.rgba(r u8, g u8, b u8, a u8) Rgba32 {
	return Rgba32{
		r: r
		g: g
		b: b
		a: a
	}
}

pub fn Rgba32.from_color[S](value S) Rgba32 {
	return color_from_color[Rgba32, S](value)
}

pub fn Rgba32.from_grayscale[S](value S) Rgba32 {
	return color_from_grayscale[Rgba32, S](value)
}

pub fn Rgba32.from_u32_rgb(value u32) Rgba32 {
	return color_from_u32_rgb[Rgba32](value)
}

pub fn Rgba32.from_u32_rgba(value u32) Rgba32 {
	return color_from_u32_rgba[Rgba32](value)
}

pub fn Rgba32.from_u64_rgb(value u64) Rgba32 {
	return color_from_u64_rgb[Rgba32](value)
}

pub fn Rgba32.from_u64_rgba(value u64) Rgba32 {
	return color_from_u64_rgba[Rgba32](value)
}

pub fn Rgba32.from_float4(value Float4) Rgba32 {
	return color_from_float4[Rgba32](value)
}

pub fn Rgba32.from_array(value [4]u8) Rgba32 {
	return color_from_array[Rgba32, u8](value)
}

pub fn Rgba32.from_html_hex(value string) !Rgba32 {
	return color_from_html_hex[Rgba32](value)
}

pub fn (color Rgba32) to_color[T]() T {
	return color_method_to_target[T, Rgba32](color)
}

pub fn (color Rgba32) to_u32_rgb() u32 {
	return color_to_u32_rgb(color)
}

pub fn (color Rgba32) to_u32_rgba() u32 {
	return color_to_u32_rgba(color)
}

pub fn (color Rgba32) to_u64_rgb() u64 {
	return color_to_u64_rgb(color)
}

pub fn (color Rgba32) to_u64_rgba() u64 {
	return color_to_u64_rgba(color)
}

pub fn (color Rgba32) to_float4() Float4 {
	return color_to_float4(color)
}

pub fn (color Rgba32) to_array() [4]u8 {
	return [color.r, color.g, color.b, u8(color.a)]!
}

pub fn (color Rgba32) premultiplied_alpha() Rgba32 {
	return color_premultiplied_alpha(color)
}

pub fn Bgr24.rgb(r u8, g u8, b u8) Bgr24 {
	return Bgr24{
		r: r
		g: g
		b: b
	}
}

pub fn Bgr24.rgba(r u8, g u8, b u8, a NoColorAlpha) Bgr24 {
	return Bgr24.rgb(r, g, b)
}

pub fn Bgr24.from_color[S](value S) Bgr24 {
	return color_from_color[Bgr24, S](value)
}

pub fn Bgr24.from_grayscale[S](value S) Bgr24 {
	return color_from_grayscale[Bgr24, S](value)
}

pub fn Bgr24.from_u32_rgb(value u32) Bgr24 {
	return color_from_u32_rgb[Bgr24](value)
}

pub fn Bgr24.from_u32_rgba(value u32) Bgr24 {
	return color_from_u32_rgba[Bgr24](value)
}

pub fn Bgr24.from_u64_rgb(value u64) Bgr24 {
	return color_from_u64_rgb[Bgr24](value)
}

pub fn Bgr24.from_u64_rgba(value u64) Bgr24 {
	return color_from_u64_rgba[Bgr24](value)
}

pub fn Bgr24.from_float4(value Float4) Bgr24 {
	return color_from_float4[Bgr24](value)
}

pub fn Bgr24.from_array(value [4]u8) Bgr24 {
	return color_from_array[Bgr24, u8](value)
}

pub fn Bgr24.from_html_hex(value string) !Bgr24 {
	return color_from_html_hex[Bgr24](value)
}

pub fn (color Bgr24) to_color[T]() T {
	return color_method_to_target[T, Bgr24](color)
}

pub fn (color Bgr24) to_u32_rgb() u32 {
	return color_to_u32_rgb(color)
}

pub fn (color Bgr24) to_u32_rgba() u32 {
	return color_to_u32_rgba(color)
}

pub fn (color Bgr24) to_u64_rgb() u64 {
	return color_to_u64_rgb(color)
}

pub fn (color Bgr24) to_u64_rgba() u64 {
	return color_to_u64_rgba(color)
}

pub fn (color Bgr24) to_float4() Float4 {
	return color_to_float4(color)
}

pub fn (color Bgr24) to_array() [4]u8 {
	return [color.r, color.g, color.b, u8(255)]!
}

pub fn (color Bgr24) premultiplied_alpha() Bgr24 {
	return color_premultiplied_alpha(color)
}

pub fn Bgra32.rgb(r u8, g u8, b u8) Bgra32 {
	return Bgra32{
		r: r
		g: g
		b: b
	}
}

pub fn Bgra32.rgba(r u8, g u8, b u8, a u8) Bgra32 {
	return Bgra32{
		r: r
		g: g
		b: b
		a: a
	}
}

pub fn Bgra32.from_color[S](value S) Bgra32 {
	return color_from_color[Bgra32, S](value)
}

pub fn Bgra32.from_grayscale[S](value S) Bgra32 {
	return color_from_grayscale[Bgra32, S](value)
}

pub fn Bgra32.from_u32_rgb(value u32) Bgra32 {
	return color_from_u32_rgb[Bgra32](value)
}

pub fn Bgra32.from_u32_rgba(value u32) Bgra32 {
	return color_from_u32_rgba[Bgra32](value)
}

pub fn Bgra32.from_u64_rgb(value u64) Bgra32 {
	return color_from_u64_rgb[Bgra32](value)
}

pub fn Bgra32.from_u64_rgba(value u64) Bgra32 {
	return color_from_u64_rgba[Bgra32](value)
}

pub fn Bgra32.from_float4(value Float4) Bgra32 {
	return color_from_float4[Bgra32](value)
}

pub fn Bgra32.from_array(value [4]u8) Bgra32 {
	return color_from_array[Bgra32, u8](value)
}

pub fn Bgra32.from_html_hex(value string) !Bgra32 {
	return color_from_html_hex[Bgra32](value)
}

pub fn (color Bgra32) to_color[T]() T {
	return color_method_to_target[T, Bgra32](color)
}

pub fn (color Bgra32) to_u32_rgb() u32 {
	return color_to_u32_rgb(color)
}

pub fn (color Bgra32) to_u32_rgba() u32 {
	return color_to_u32_rgba(color)
}

pub fn (color Bgra32) to_u64_rgb() u64 {
	return color_to_u64_rgb(color)
}

pub fn (color Bgra32) to_u64_rgba() u64 {
	return color_to_u64_rgba(color)
}

pub fn (color Bgra32) to_float4() Float4 {
	return color_to_float4(color)
}

pub fn (color Bgra32) to_array() [4]u8 {
	return [color.r, color.g, color.b, u8(color.a)]!
}

pub fn (color Bgra32) premultiplied_alpha() Bgra32 {
	return color_premultiplied_alpha(color)
}

pub fn Rgb48.rgb(r u16, g u16, b u16) Rgb48 {
	return Rgb48{
		r: r
		g: g
		b: b
	}
}

pub fn Rgb48.rgba(r u16, g u16, b u16, a NoColorAlpha) Rgb48 {
	return Rgb48.rgb(r, g, b)
}

pub fn Rgb48.from_color[S](value S) Rgb48 {
	return color_from_color[Rgb48, S](value)
}

pub fn Rgb48.from_grayscale[S](value S) Rgb48 {
	return color_from_grayscale[Rgb48, S](value)
}

pub fn Rgb48.from_u32_rgb(value u32) Rgb48 {
	return color_from_u32_rgb[Rgb48](value)
}

pub fn Rgb48.from_u32_rgba(value u32) Rgb48 {
	return color_from_u32_rgba[Rgb48](value)
}

pub fn Rgb48.from_u64_rgb(value u64) Rgb48 {
	return color_from_u64_rgb[Rgb48](value)
}

pub fn Rgb48.from_u64_rgba(value u64) Rgb48 {
	return color_from_u64_rgba[Rgb48](value)
}

pub fn Rgb48.from_float4(value Float4) Rgb48 {
	return color_from_float4[Rgb48](value)
}

pub fn Rgb48.from_array(value [4]u16) Rgb48 {
	return color_from_array[Rgb48, u16](value)
}

pub fn (color Rgb48) to_color[T]() T {
	return color_method_to_target[T, Rgb48](color)
}

pub fn (color Rgb48) to_u32_rgb() u32 {
	return color_to_u32_rgb(color)
}

pub fn (color Rgb48) to_u32_rgba() u32 {
	return color_to_u32_rgba(color)
}

pub fn (color Rgb48) to_u64_rgb() u64 {
	return color_to_u64_rgb(color)
}

pub fn (color Rgb48) to_u64_rgba() u64 {
	return color_to_u64_rgba(color)
}

pub fn (color Rgb48) to_float4() Float4 {
	return color_to_float4(color)
}

pub fn (color Rgb48) to_array() [4]u16 {
	return [color.r, color.g, color.b, u16(65535)]!
}

pub fn (color Rgb48) premultiplied_alpha() Rgb48 {
	return color_premultiplied_alpha(color)
}

pub fn Rgba64.rgb(r u16, g u16, b u16) Rgba64 {
	return Rgba64{
		r: r
		g: g
		b: b
	}
}

pub fn Rgba64.rgba(r u16, g u16, b u16, a u16) Rgba64 {
	return Rgba64{
		r: r
		g: g
		b: b
		a: a
	}
}

pub fn Rgba64.from_color[S](value S) Rgba64 {
	return color_from_color[Rgba64, S](value)
}

pub fn Rgba64.from_grayscale[S](value S) Rgba64 {
	return color_from_grayscale[Rgba64, S](value)
}

pub fn Rgba64.from_u32_rgb(value u32) Rgba64 {
	return color_from_u32_rgb[Rgba64](value)
}

pub fn Rgba64.from_u32_rgba(value u32) Rgba64 {
	return color_from_u32_rgba[Rgba64](value)
}

pub fn Rgba64.from_u64_rgb(value u64) Rgba64 {
	return color_from_u64_rgb[Rgba64](value)
}

pub fn Rgba64.from_u64_rgba(value u64) Rgba64 {
	return color_from_u64_rgba[Rgba64](value)
}

pub fn Rgba64.from_float4(value Float4) Rgba64 {
	return color_from_float4[Rgba64](value)
}

pub fn Rgba64.from_array(value [4]u16) Rgba64 {
	return color_from_array[Rgba64, u16](value)
}

pub fn (color Rgba64) to_color[T]() T {
	return color_method_to_target[T, Rgba64](color)
}

pub fn (color Rgba64) to_u32_rgb() u32 {
	return color_to_u32_rgb(color)
}

pub fn (color Rgba64) to_u32_rgba() u32 {
	return color_to_u32_rgba(color)
}

pub fn (color Rgba64) to_u64_rgb() u64 {
	return color_to_u64_rgb(color)
}

pub fn (color Rgba64) to_u64_rgba() u64 {
	return color_to_u64_rgba(color)
}

pub fn (color Rgba64) to_float4() Float4 {
	return color_to_float4(color)
}

pub fn (color Rgba64) to_array() [4]u16 {
	return [color.r, color.g, color.b, u16(color.a)]!
}

pub fn (color Rgba64) premultiplied_alpha() Rgba64 {
	return color_premultiplied_alpha(color)
}

pub fn Colorf32.rgb(r f32, g f32, b f32) Colorf32 {
	return Colorf32{
		r: r
		g: g
		b: b
	}
}

pub fn Colorf32.rgba(r f32, g f32, b f32, a f32) Colorf32 {
	return Colorf32{
		r: r
		g: g
		b: b
		a: a
	}
}

pub fn Colorf32.from_color[S](value S) Colorf32 {
	return color_from_color[Colorf32, S](value)
}

pub fn Colorf32.from_grayscale[S](value S) Colorf32 {
	return color_from_grayscale[Colorf32, S](value)
}

pub fn Colorf32.from_u32_rgb(value u32) Colorf32 {
	return color_from_u32_rgb[Colorf32](value)
}

pub fn Colorf32.from_u32_rgba(value u32) Colorf32 {
	return color_from_u32_rgba[Colorf32](value)
}

pub fn Colorf32.from_u64_rgb(value u64) Colorf32 {
	return color_from_u64_rgb[Colorf32](value)
}

pub fn Colorf32.from_u64_rgba(value u64) Colorf32 {
	return color_from_u64_rgba[Colorf32](value)
}

pub fn Colorf32.from_float4(value Float4) Colorf32 {
	return color_from_float4[Colorf32](value)
}

pub fn Colorf32.from_array(value [4]f32) Colorf32 {
	return color_from_array[Colorf32, f32](value)
}

pub fn (color Colorf32) to_color[T]() T {
	return color_method_to_target[T, Colorf32](color)
}

pub fn (color Colorf32) to_u32_rgb() u32 {
	return color_to_u32_rgb(color)
}

pub fn (color Colorf32) to_u32_rgba() u32 {
	return color_to_u32_rgba(color)
}

pub fn (color Colorf32) to_u64_rgb() u64 {
	return color_to_u64_rgb(color)
}

pub fn (color Colorf32) to_u64_rgba() u64 {
	return color_to_u64_rgba(color)
}

pub fn (color Colorf32) to_float4() Float4 {
	return color_to_float4(color)
}

pub fn (color Colorf32) to_array() [4]f32 {
	return [color.r, color.g, color.b, f32(color.a)]!
}

pub fn (color Colorf32) premultiplied_alpha() Colorf32 {
	return color_premultiplied_alpha(color)
}
