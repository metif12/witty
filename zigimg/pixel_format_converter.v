module zigimg

import math

// PixelFormatConverter.zig at d7b7ab0ba0899643831ef042bd73289510b39906.
// Scalar operations retain the baseline arm64/amd64 four-pixel SIMD boundary.
pub struct PixelFormatConverter {}

pub fn PixelFormatConverter.convert(source &PixelStorage, destination_format PixelFormat) !PixelStorage {
	source_format := source.pixel_format()
	if source_format == destination_format { return error('NoConversionNeeded') }
	mut destination := PixelStorage.init(destination_format, source.len())!
	if !converter_available(source_format, destination_format) {
		return error('NoConversionAvailable')
	}
	// These nine entries in the pinned table select .rgb555 on a .bgr555 union.
	if source_format == .bgr555
		&& destination_format in [.rgb555, .rgb565, .rgb24, .rgba32, .bgr24, .bgra32, .rgb48, .rgba64, .float32] {
		panic('access of union field rgb555 while field bgr555 is active')
	}
	if destination_format.is_indexed() {
		converter_to_indexed(source, mut destination)!
		return destination
	}
	source_bytes := source.as_bytes()
	mut destination_bytes := destination.as_bytes()
	// These casts run even for empty storage. Sliced empty float views can have
	// an aligned pointer; allocated/raw-initialized empties retain Zig's sentinel.
	if source_format == .float32 && destination_format in [.rgba32, .bgra32] {
		assert usize(source_bytes.data) % 4 == 0
	}
	if source_format in [.rgba32, .bgra32] && destination_format == .float32 {
		assert usize(destination_bytes.data) % 4 == 0
	}
	for index in 0 .. int(source.len()) {
		color := converter_read(source, source_bytes, index)
		converter_write(color, source_format, destination_format, index, int(source.len()), mut
			destination_bytes)
	}
	return destination
}

// The 460 table entries form these groups. In particular, indexed -> gray and
// RGB(A)/float -> grayscale16 are absent; same-format calls fail before lookup.
fn converter_available(source PixelFormat, destination PixelFormat) bool {
	if source == .invalid || destination == .invalid || source == destination { return false }
	if source.is_indexed() { return !destination.is_grayscale() }
	if source.is_grayscale() { return true }
	return destination != .grayscale16
}

struct ConversionColor {
mut:
	values   [4]u32
	bits     [4]u8
	floats   [4]f32
	floating bool
	gray     bool
	alpha    bool
}

fn converter_max(bits u8) u32 {
	return (u32(1) << bits) - 1
}

fn converter_scale(value u32, source_bits u8, destination_bits u8) u32 {
	assert value <= converter_max(source_bits)
	if source_bits > destination_bits { return value >> (source_bits - destination_bits) }
	if source_bits < destination_bits {
		maximum := converter_max(source_bits)
		return (value * converter_max(destination_bits) + maximum / 2) / maximum
	}
	return value
}

fn (color ConversionColor) normalized(channel int) f32 {
	if color.floating { return color.floats[channel] }
	return f32(color.values[channel]) / f32(converter_max(color.bits[channel]))
}

fn (color ConversionColor) scaled(channel int, bits u8) u32 {
	if color.floating { return quantizer_scale_float(color.floats[channel], converter_max(bits)) }
	return converter_scale(color.values[channel], color.bits[channel], bits)
}

fn converter_word(bytes []u8, offset int, width int) u32 {
	if width == 1 { return u32(bytes[offset]) }
	assert offset + 2 <= bytes.len
	return u32(unsafe { *(&u16(&bytes[offset])) })
}

fn converter_put_word(mut bytes []u8, offset int, width int, value u32) {
	if width == 1 {
		bytes[offset] = u8(value)
	} else {
		assert offset + 2 <= bytes.len
		unsafe {
			*(&u16(&bytes[offset])) = u16(value)
		}
	}
}

fn converter_rgba(color Rgba32) ConversionColor {
	return ConversionColor{
		values: [u32(color.r), u32(color.g), u32(color.b), u32(color.a)]!
		bits:   [u8(8), u8(8), u8(8), u8(8)]!
		alpha:  true
	}
}

fn converter_index(format PixelFormat, bytes []u8, index int) int {
	width := if format == .indexed16 { 2 } else { 1 }
	value := converter_word(bytes, index * width, width)
	assert value <= converter_max(format.info().bits_per_channel())
	return int(value)
}

fn converter_read(source &PixelStorage, bytes []u8, index int) ConversionColor {
	format := source.pixel_format()
	if format.is_indexed() {
		palette := source.get_palette() or { panic('missing indexed palette') }
		return converter_rgba(palette[converter_index(format, bytes, index)])
	}
	mut result := ConversionColor{
		values: [u32(0), u32(0), u32(0), u32(255)]!
		bits:   [u8(8), u8(8), u8(8), u8(8)]!
		gray:   format.is_grayscale()
		alpha:  format.channel_count() in [u8(2), u8(4)]
	}
	stride := int(format.pixel_stride())
	offset := index * stride
	if format == .float32 {
		assert offset + 16 <= bytes.len
		result.floating = true
		for channel in 0 .. 4 {
			result.floats[channel] = unsafe { *(&f32(&bytes[offset + channel * 4])) }
		}
		return result
	}
	if format in [.rgb332, .rgb555, .bgr555, .rgb565] {
		raw := converter_word(bytes, offset, stride)
		match format {
			.rgb332 {
				result.values = [raw & 7, (raw >> 3) & 7, raw >> 6, u32(255)]!
				result.bits = [u8(3), u8(3), u8(2), u8(8)]!
			}
			.rgb565 {
				result.values = [raw >> 11, (raw >> 5) & 63, raw & 31, u32(255)]!
				result.bits = [u8(5), u8(6), u8(5), u8(8)]!
			}
			else {
				result.values = [(raw >> 10) & 31, (raw >> 5) & 31, raw & 31, u32(255)]!
				result.bits = [u8(5), u8(5), u8(5), u8(8)]!
				if format == .bgr555 {
					result.values[0] = raw & 31
					result.values[2] = (raw >> 10) & 31
				}
			}
		}

		return result
	}
	bits := format.info().bits_per_channel()
	width := if bits == 16 { 2 } else { 1 }
	if result.gray {
		value := converter_word(bytes, offset, width)
		assert value <= converter_max(bits)
		for channel in 0 .. 3 {
			result.values[channel] = value
			result.bits[channel] = bits
		}
		if result.alpha {
			result.values[3] = converter_word(bytes, offset + width, width)
			result.bits[3] = bits
		}
	} else {
		for channel in 0 .. int(format.channel_count()) {
			position := if format in [.bgr24, .bgra32] && channel < 3 {
				2 - channel
			} else {
				channel
			}
			result.values[channel] = converter_word(bytes, offset + position * width, width)
			result.bits[channel] = bits
		}
	}
	return result
}

fn (mut color ConversionColor) premultiply() {
	alpha := color.normalized(3)
	for channel in 0 .. 3 {
		if color.floating {
			color.floats[channel] *= alpha
		} else {
			color.values[channel] = quantizer_scale_float(color.normalized(channel) * alpha,
				converter_max(color.bits[channel]))
		}
	}
}

fn converter_write(input ConversionColor, source PixelFormat, destination PixelFormat, index int, count int, mut bytes []u8) {
	mut color := input
	offset := index * int(destination.pixel_stride())
	if destination == .float32 {
		assert offset + 16 <= bytes.len
		for channel in 0 .. 4 {
			unsafe {
				*(&f32(&bytes[offset + channel * 4])) = color.normalized(channel)
			}
		}
		return
	}
	bits := destination.info().bits_per_channel()
	width := if bits == 16 { 2 } else { 1 }
	if destination.is_grayscale() {
		mut value := u32(0)
		if color.gray {
			value = if color.alpha && destination.channel_count() == 1 {
				quantizer_scale_float(color.normalized(0) * color.normalized(3),
					converter_max(bits))
			} else {
				color.scaled(0, bits)
			}
		} else {
			red := f32(0.2125) * color.normalized(0)
			green := f32(0.7154) * color.normalized(1)
			blue := f32(0.0721) * color.normalized(2)
			mut luminance := (red + green) + blue
			if destination.channel_count() == 1 { luminance *= color.normalized(3) }
			value = quantizer_scale_float(luminance, converter_max(bits))
		}
		converter_put_word(mut bytes, offset, width, value)
		if destination.channel_count() == 2 {
			alpha := if color.gray {
				color.scaled(3, bits)
			} else {
				quantizer_scale_float(color.normalized(3), converter_max(bits))
			}
			converter_put_word(mut bytes, offset + width, width, alpha)
		}
		return
	}
	if color.gray && color.alpha && destination.channel_count() == 3 {
		// Grayscale alpha drops into Grayscalef32 before destination scaling.
		gray := color.normalized(0) * color.normalized(3)
		color.floating = true
		color.floats = [gray, gray, gray, f32(1)]!
	} else if color.alpha && !color.floating && !color.gray
		&& ((destination.channel_count() == 3 && (destination != .rgb332 || source.is_indexed()))
		|| (source == .rgba64 && destination == .bgra32)) {
		// The table uses a straight conversion for rgba -> rgb332, and uses the
		// premultiplying RGB helper for rgba64 -> bgra32, retaining its alpha.
		color.premultiply()
	}
	mut channel_bits := [bits, bits, bits, bits]!
	if destination == .rgb332 { channel_bits = [u8(3), u8(3), u8(2), u8(8)]! }
	if destination == .rgb565 { channel_bits = [u8(5), u8(6), u8(5), u8(8)]! }
	mut values := [4]u32{}
	for channel in 0 .. int(destination.channel_count()) {
		if source == .float32 && destination in [.rgba32, .bgra32] && index < count / 4 * 4 {
			// SIMD floatToInt truncates without clamping; scalar tail rounds/clamps.
			scaled := color.floats[channel] * f32(255)
			// The pinned Zig/ARM64 cast emits zero for NaN without a safety trap.
			// Other targets' float-cast behavior remains a representation boundary.
			if scaled != scaled {
				values[channel] = 0
				continue
			}
			truncated := math.trunc(f64(scaled))
			assert truncated >= 0 && truncated <= 255
			values[channel] = u32(truncated)
		} else {
			values[channel] = color.scaled(channel, channel_bits[channel])
		}
	}
	if destination == .rgb332 {
		converter_put_word(mut bytes, offset, 1, values[0] | values[1] << 3 | values[2] << 6)
	} else if destination == .rgb565 {
		converter_put_word(mut bytes, offset, 2, values[0] << 11 | values[1] << 5 | values[2])
	} else if destination in [.rgb555, .bgr555] {
		rgb_word := (values[0] << 10) | (values[1] << 5) | values[2]
		bgr_word := (values[2] << 10) | (values[1] << 5) | values[0]
		raw := if destination == .rgb555 { rgb_word } else { bgr_word }
		converter_put_word(mut bytes, offset, 2, raw)
	} else {
		for channel in 0 .. int(destination.channel_count()) {
			position := if destination in [.bgr24, .bgra32] && channel < 3 {
				2 - channel
			} else {
				channel
			}
			converter_put_word(mut bytes, offset + position * width, width, values[channel])
		}
	}
}

fn converter_quantized(input ConversionColor) Rgb24 {
	mut color := input
	if color.gray {
		// Gray-alpha quantization narrows both fields to u8 before multiplying.
		value := color.scaled(0, 8)
		color = converter_rgba(Rgba32{
			r: u8(value)
			g: u8(value)
			b: u8(value)
			a: u8(color.scaled(3, 8))
		})
	}
	if color.alpha { color.premultiply() }
	return Rgb24{
		r: u8(color.scaled(0, 8))
		g: u8(color.scaled(1, 8))
		b: u8(color.scaled(2, 8))
	}
}

fn converter_to_indexed(source &PixelStorage, mut destination PixelStorage) ! {
	source_format := source.pixel_format()
	destination_format := destination.pixel_format()
	bytes := source.as_bytes()
	mut output := destination.as_bytes()
	mut palette := destination.get_palette() or { panic('missing indexed palette') }
	if source_format.is_indexed()
		&& source_format.info().bits_per_channel() < destination_format.info().bits_per_channel() {
		source_palette := source.get_palette() or { panic('missing indexed palette') }
		for index, entry in source_palette {
			palette[index] = entry
		}
		for index in 0 .. int(source.len()) {
			converter_put_word(mut output, index * int(destination_format.pixel_stride()),
				int(destination_format.pixel_stride()), u32(converter_index(source_format, bytes,
				index)))
		}
		return
	}
	mut quantizer := OctTreeQuantizer.init()
	if source_format.is_indexed() {
		source_palette := source.get_palette() or { panic('missing indexed palette') }
		for entry in source_palette {
			quantizer.add_color(entry) or { return error('QuantizeError') }
		}
	} else {
		for index in 0 .. int(source.len()) {
			quantizer.add_color(converter_quantized(converter_read(source, bytes, index))) or {
				return error('QuantizeError')
			}
		}
	}
	// Source assigns the shortened palette only to a local IndexedStorage copy.
	// The returned storage retains its full palette, including opaque black tail.
	quantizer.make_palette(u32(1) << destination_format.info().bits_per_channel(), mut palette)
	for index in 0 .. int(source.len()) {
		color := converter_quantized(converter_read(source, bytes, index))
		palette_index := quantizer.get_palette_index(color) or { return error('QuantizeError') }
		value := u32(palette_index) & converter_max(destination_format.info().bits_per_channel())
		converter_put_word(mut output, index * int(destination_format.pixel_stride()),
			int(destination_format.pixel_stride()), value)
	}
}
