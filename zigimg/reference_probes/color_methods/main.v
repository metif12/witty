module main

import math
import os
import strings
import zigimg

fn float_value(bits u32) f32 {
	return unsafe { *(&f32(&bits)) }
}

fn double_value(bits u64) f64 {
	return unsafe { *(&f64(&bits)) }
}

fn emit_float(mut output strings.Builder, value f32) {
	bits := if math.is_nan(value) { u32(0x7fc00000) } else { unsafe { *(&u32(&value)) } }
	output.write_string(bits.str())
	output.write_string(',')
}

fn emit_double(mut output strings.Builder, value f64) {
	bits := if math.is_nan(value) { u64(0x7ff8000000000000) } else { unsafe { *(&u64(&value)) } }
	output.write_string(bits.str())
	output.write_string(',')
}

fn emit[T](mut output strings.Builder, value T) {
	output.write_string('${value.to_u32_rgba()},${value.to_u32_rgb()},${value.to_u64_rgba()},${value.to_u64_rgb()},')
	for channel in value.to_float4() {
		emit_float(mut output, channel)
	}
	premultiplied := value.premultiplied_alpha()
	output.write_string('${premultiplied.to_u32_rgba()},${premultiplied.to_u64_rgba()},')
	for channel in premultiplied.to_float4() {
		emit_float(mut output, channel)
	}
}

fn constructors[T](mut output strings.Builder, value T) {
	$if T is zigimg.Rgb332 || T is zigimg.Rgb555 || T is zigimg.Rgb565 || T is zigimg.Bgr555 {
		// Packed fields must be extracted without scaling back from u16.
		$if T is zigimg.Rgb332 {
			emit(mut output, zigimg.Rgb332.rgb(value.raw & 7, (value.raw >> 3) & 7, value.raw >> 6))
			emit(mut output, zigimg.Rgb332.rgba(value.raw & 7, (value.raw >> 3) & 7,
				value.raw >> 6, zigimg.NoColorAlpha{}))
		} $else $if T is zigimg.Rgb565 {
			emit(mut output, zigimg.Rgb565.rgb(u8(value.raw >> 11), u8((value.raw >> 5) & 63),
				u8(value.raw & 31)))
			emit(mut output, zigimg.Rgb565.rgba(u8(value.raw >> 11), u8((value.raw >> 5) & 63),
				u8(value.raw & 31), zigimg.NoColorAlpha{}))
		} $else $if T is zigimg.Rgb555 {
			emit(mut output, zigimg.Rgb555.rgb(u8((value.raw >> 10) & 31),
				u8((value.raw >> 5) & 31), u8(value.raw & 31)))
			emit(mut output, zigimg.Rgb555.rgba(u8((value.raw >> 10) & 31),
				u8((value.raw >> 5) & 31), u8(value.raw & 31), zigimg.NoColorAlpha{}))
		} $else {
			emit(mut output, zigimg.Bgr555.rgb(u8(value.raw & 31), u8((value.raw >> 5) & 31),
				u8((value.raw >> 10) & 31)))
			emit(mut output, zigimg.Bgr555.rgba(u8(value.raw & 31), u8((value.raw >> 5) & 31),
				u8((value.raw >> 10) & 31), zigimg.NoColorAlpha{}))
		}
	} $else {
		$if T is zigimg.Rgb24 {
			emit(mut output, zigimg.Rgb24.rgb(value.r, value.g, value.b))
		} $else $if T is zigimg.Bgr24 {
			emit(mut output, zigimg.Bgr24.rgb(value.r, value.g, value.b))
		} $else $if T is zigimg.Rgb48 {
			emit(mut output, zigimg.Rgb48.rgb(value.r, value.g, value.b))
		} $else $if T is zigimg.Rgba32 {
			emit(mut output, zigimg.Rgba32.rgb(value.r, value.g, value.b))
		} $else $if T is zigimg.Bgra32 {
			emit(mut output, zigimg.Bgra32.rgb(value.r, value.g, value.b))
		} $else $if T is zigimg.Rgba64 {
			emit(mut output, zigimg.Rgba64.rgb(value.r, value.g, value.b))
		} $else $if T is zigimg.Colorf32 {
			emit(mut output, zigimg.Colorf32.rgb(value.r, value.g, value.b))
		}
		emit(mut output, value)
	}
	$if T is zigimg.Rgb332 || T is zigimg.Rgb565 {
		return
	} $else {
		arr := value.to_array()
		for index in 0 .. 4 {
			channel := arr[index]
			$if T is zigimg.Colorf32 {
				emit_float(mut output, channel)
			} $else {
				output.write_string('${channel},')
			}
		}
		$if T is zigimg.Rgb555 {
			emit(mut output, zigimg.Rgb555.from_array(arr))
		} $else $if T is zigimg.Bgr555 {
			emit(mut output, zigimg.Bgr555.from_array(arr))
		} $else $if T is zigimg.Rgb24 {
			emit(mut output, zigimg.Rgb24.from_array(arr))
		} $else $if T is zigimg.Rgba32 {
			emit(mut output, zigimg.Rgba32.from_array(arr))
		} $else $if T is zigimg.Bgr24 {
			emit(mut output, zigimg.Bgr24.from_array(arr))
		} $else $if T is zigimg.Bgra32 {
			emit(mut output, zigimg.Bgra32.from_array(arr))
		} $else $if T is zigimg.Rgb48 {
			emit(mut output, zigimg.Rgb48.from_array(arr))
		} $else $if T is zigimg.Rgba64 {
			emit(mut output, zigimg.Rgba64.from_array(arr))
		} $else $if T is zigimg.Colorf32 {
			emit(mut output, zigimg.Colorf32.from_array(arr))
		}
	}
}

fn converted[S](mut output strings.Builder, value S) {
	emit(mut output, value.to_color[zigimg.Rgb332]())
	emit(mut output, value.to_color[zigimg.Rgb555]())
	emit(mut output, value.to_color[zigimg.Rgb565]())
	emit(mut output, value.to_color[zigimg.Bgr555]())
	emit(mut output, value.to_color[zigimg.Rgb24]())
	emit(mut output, value.to_color[zigimg.Rgba32]())
	emit(mut output, value.to_color[zigimg.Bgr24]())
	emit(mut output, value.to_color[zigimg.Bgra32]())
	emit(mut output, value.to_color[zigimg.Rgb48]())
	emit(mut output, value.to_color[zigimg.Rgba64]())
	emit(mut output, value.to_color[zigimg.Colorf32]())
}

fn gray[S](mut output strings.Builder, value S) {
	emit(mut output, zigimg.Rgb332.from_grayscale(value))
	emit(mut output, zigimg.Rgb555.from_grayscale(value))
	emit(mut output, zigimg.Rgb565.from_grayscale(value))
	emit(mut output, zigimg.Bgr555.from_grayscale(value))
	emit(mut output, zigimg.Rgb24.from_grayscale(value))
	emit(mut output, zigimg.Rgba32.from_grayscale(value))
	emit(mut output, zigimg.Bgr24.from_grayscale(value))
	emit(mut output, zigimg.Bgra32.from_grayscale(value))
	emit(mut output, zigimg.Rgb48.from_grayscale(value))
	emit(mut output, zigimg.Rgba64.from_grayscale(value))
	emit(mut output, zigimg.Colorf32.from_grayscale(value))
}

fn scale[I](mut output strings.Builder, value I) {
	output.write_string(zigimg.scale_value[u8, I](value).str())
	output.write_string(',')
	output.write_string(zigimg.scale_value[u16, I](value).str())
	output.write_string(',')
	output.write_string(zigimg.scale_value[u32, I](value).str())
	output.write_string(',')
	output.write_string(zigimg.scale_value[u64, I](value).str())
	output.write_string(',')
	emit_float(mut output, zigimg.scale_value[f32, I](value))
	emit_double(mut output, zigimg.scale_value[f64, I](value))
}

struct Mixed {
pub:
	r u8
	g u16
	b f64
	a f32
}

struct Ignored {
pub:
	r u8
	g u16
	b f64
	a string
}

struct IgnoredGray {
pub:
	value f64
	alpha string
}

struct CustomTarget {
	value u8
}

pub fn CustomTarget.from_color[S](_ S) CustomTarget {
	return CustomTarget{
		value: 17
	}
}

struct TaggedTarget {
	value u64
}

pub fn TaggedTarget.from_color[S](value S) TaggedTarget {
	return TaggedTarget{
		value: value.to_u64_rgba() ^ u64(0xfedcba9876543210)
	}
}

type AliasRgb332 = zigimg.Rgb332
type AliasRgb555 = zigimg.Rgb555
type AliasRgb565 = zigimg.Rgb565
type AliasBgr555 = zigimg.Bgr555
type AliasGray2 = zigimg.Grayscale2

fn main() {
	for line in os.read_lines(os.args[1]) or { panic(err) } {
		fields := line.split('|')
		mut output := strings.new_builder(8000)
		if fields[0] == '5' {
			text := fields[1]
			if value := zigimg.Rgb24.from_html_hex(text) {
				emit(mut output, value)
			} else {
				output.write_string('InvalidHtmlHexString,')
			}
			if value := zigimg.Rgba32.from_html_hex(text) {
				emit(mut output, value)
			} else {
				output.write_string('InvalidHtmlHexString,')
			}
			if value := zigimg.Bgr24.from_html_hex(text) {
				emit(mut output, value)
			} else {
				output.write_string('InvalidHtmlHexString,')
			}
			if value := zigimg.Bgra32.from_html_hex(text) {
				emit(mut output, value)
			} else {
				output.write_string('InvalidHtmlHexString,')
			}
			println(output.str())
			continue
		}
		inputs := [fields[1].u64(), fields[2].u64(), fields[3].u64(),
			fields[4].u64()]!
		values := [float_value(u32(inputs[0])), float_value(u32(inputs[1])),
			float_value(u32(inputs[2])), float_value(u32(inputs[3]))]!
		match fields[0] {
			'0' {
				value := inputs[0]
				emit(mut output, zigimg.Rgb332.from_u32_rgba(u32(value)))
				emit(mut output, zigimg.Rgb332.from_u32_rgb(u32(value)))
				emit(mut output, zigimg.Rgb332.from_u64_rgba(value))
				emit(mut output, zigimg.Rgb332.from_u64_rgb(value))
				emit(mut output, zigimg.Rgb555.from_u32_rgba(u32(value)))
				emit(mut output, zigimg.Rgb555.from_u32_rgb(u32(value)))
				emit(mut output, zigimg.Rgb555.from_u64_rgba(value))
				emit(mut output, zigimg.Rgb555.from_u64_rgb(value))
				emit(mut output, zigimg.Rgb565.from_u32_rgba(u32(value)))
				emit(mut output, zigimg.Rgb565.from_u32_rgb(u32(value)))
				emit(mut output, zigimg.Rgb565.from_u64_rgba(value))
				emit(mut output, zigimg.Rgb565.from_u64_rgb(value))
				emit(mut output, zigimg.Bgr555.from_u32_rgba(u32(value)))
				emit(mut output, zigimg.Bgr555.from_u32_rgb(u32(value)))
				emit(mut output, zigimg.Bgr555.from_u64_rgba(value))
				emit(mut output, zigimg.Bgr555.from_u64_rgb(value))
				emit(mut output, zigimg.Rgb24.from_u32_rgba(u32(value)))
				emit(mut output, zigimg.Rgb24.from_u32_rgb(u32(value)))
				emit(mut output, zigimg.Rgb24.from_u64_rgba(value))
				emit(mut output, zigimg.Rgb24.from_u64_rgb(value))
				emit(mut output, zigimg.Rgba32.from_u32_rgba(u32(value)))
				emit(mut output, zigimg.Rgba32.from_u32_rgb(u32(value)))
				emit(mut output, zigimg.Rgba32.from_u64_rgba(value))
				emit(mut output, zigimg.Rgba32.from_u64_rgb(value))
				emit(mut output, zigimg.Bgr24.from_u32_rgba(u32(value)))
				emit(mut output, zigimg.Bgr24.from_u32_rgb(u32(value)))
				emit(mut output, zigimg.Bgr24.from_u64_rgba(value))
				emit(mut output, zigimg.Bgr24.from_u64_rgb(value))
				emit(mut output, zigimg.Bgra32.from_u32_rgba(u32(value)))
				emit(mut output, zigimg.Bgra32.from_u32_rgb(u32(value)))
				emit(mut output, zigimg.Bgra32.from_u64_rgba(value))
				emit(mut output, zigimg.Bgra32.from_u64_rgb(value))
				emit(mut output, zigimg.Rgb48.from_u32_rgba(u32(value)))
				emit(mut output, zigimg.Rgb48.from_u32_rgb(u32(value)))
				emit(mut output, zigimg.Rgb48.from_u64_rgba(value))
				emit(mut output, zigimg.Rgb48.from_u64_rgb(value))
				emit(mut output, zigimg.Rgba64.from_u32_rgba(u32(value)))
				emit(mut output, zigimg.Rgba64.from_u32_rgb(u32(value)))
				emit(mut output, zigimg.Rgba64.from_u64_rgba(value))
				emit(mut output, zigimg.Rgba64.from_u64_rgb(value))
				emit(mut output, zigimg.Colorf32.from_u32_rgba(u32(value)))
				emit(mut output, zigimg.Colorf32.from_u32_rgb(u32(value)))
				emit(mut output, zigimg.Colorf32.from_u64_rgba(value))
				emit(mut output, zigimg.Colorf32.from_u64_rgb(value))
			}
			'1' {
				emit(mut output, zigimg.Rgb332.from_float4(values))
				emit(mut output, zigimg.Rgb555.from_float4(values))
				emit(mut output, zigimg.Rgb565.from_float4(values))
				emit(mut output, zigimg.Bgr555.from_float4(values))
				emit(mut output, zigimg.Rgb24.from_float4(values))
				emit(mut output, zigimg.Rgba32.from_float4(values))
				emit(mut output, zigimg.Bgr24.from_float4(values))
				emit(mut output, zigimg.Bgra32.from_float4(values))
				emit(mut output, zigimg.Rgb48.from_float4(values))
				emit(mut output, zigimg.Rgba64.from_float4(values))
				emit(mut output, zigimg.Colorf32.from_float4(values))
			}
			'2' {
				match inputs[0] {
					0 {
						gray(mut output, zigimg.Grayscale1{ value: u8(inputs[1]) & 1 })
					}
					1 {
						gray(mut output, zigimg.Grayscale2{ value: u8(inputs[1]) & 3 })
					}
					2 {
						gray(mut output, zigimg.Grayscale4{ value: u8(inputs[1]) & 15 })
					}
					3 {
						gray(mut output, zigimg.Grayscale8{ value: u8(inputs[1]) })
					}
					4 {
						gray(mut output, zigimg.Grayscale16{ value: u16(inputs[1]) })
					}
					5 {
						gray(mut output, zigimg.Grayscale8Alpha{
							value: u8(inputs[1])
							alpha: u8(inputs[2])
						})
					}
					6 {
						gray(mut output, zigimg.Grayscale16Alpha{
							value: u16(inputs[1])
							alpha: u16(inputs[2])
						})
					}
					7 {
						gray(mut output, zigimg.Grayscalef32{ value: values[1] })
					}
					8 {
						gray(mut output, zigimg.Grayscalef32Alpha{
							value: values[1]
							alpha: values[2]
						})
					}
					else {
						panic('invalid gray')
					}
				}
			}
			'3' {
				match inputs[0] {
					0 { converted(mut output, zigimg.Rgb332.from_u64_rgba(inputs[1])) }
					1 { converted(mut output, zigimg.Rgb555.from_u64_rgba(inputs[1])) }
					2 { converted(mut output, zigimg.Rgb565.from_u64_rgba(inputs[1])) }
					3 { converted(mut output, zigimg.Bgr555.from_u64_rgba(inputs[1])) }
					4 { converted(mut output, zigimg.Rgb24.from_u64_rgba(inputs[1])) }
					5 { converted(mut output, zigimg.Rgba32.from_u64_rgba(inputs[1])) }
					6 { converted(mut output, zigimg.Bgr24.from_u64_rgba(inputs[1])) }
					7 { converted(mut output, zigimg.Bgra32.from_u64_rgba(inputs[1])) }
					8 { converted(mut output, zigimg.Rgb48.from_u64_rgba(inputs[1])) }
					9 { converted(mut output, zigimg.Rgba64.from_u64_rgba(inputs[1])) }
					10 { converted(mut output, zigimg.Colorf32.from_u64_rgba(inputs[1])) }
					else { panic('invalid color') }
				}
			}
			'4' {
				scale(mut output, u8(inputs[0]))
				scale(mut output, u16(inputs[0]))
				scale(mut output, u32(inputs[0]))
				scale(mut output, u64(inputs[0]))
				output.write_string('${zigimg.scale_value[u8, f32](values[1])},${zigimg.scale_value[u8, f64](double_value(inputs[2]))},')
				output.write_string('${zigimg.scale_value[u16, f32](values[1])},${zigimg.scale_value[u16, f64](double_value(inputs[2]))},')
				emit_float(mut output, zigimg.scale_value[f32, f32](values[1]))
				emit_double(mut output, zigimg.scale_value[f64, f32](values[1]))
				emit_float(mut output, zigimg.scale_value[f32, f64](double_value(inputs[2])))
				emit_double(mut output, zigimg.scale_value[f64, f64](double_value(inputs[2])))
			}
			'6' {
				constructors(mut output, zigimg.Rgb332.from_u64_rgba(inputs[0]))
				constructors(mut output, zigimg.Rgb555.from_u64_rgba(inputs[0]))
				constructors(mut output, zigimg.Rgb565.from_u64_rgba(inputs[0]))
				constructors(mut output, zigimg.Bgr555.from_u64_rgba(inputs[0]))
				constructors(mut output, zigimg.Rgb24.from_u64_rgba(inputs[0]))
				constructors(mut output, zigimg.Rgba32.from_u64_rgba(inputs[0]))
				constructors(mut output, zigimg.Bgr24.from_u64_rgba(inputs[0]))
				constructors(mut output, zigimg.Bgra32.from_u64_rgba(inputs[0]))
				constructors(mut output, zigimg.Rgb48.from_u64_rgba(inputs[0]))
				constructors(mut output, zigimg.Rgba64.from_u64_rgba(inputs[0]))
				constructors(mut output, zigimg.Colorf32.from_u64_rgba(inputs[0]))
			}
			'7' {
				match inputs[0] {
					3 {
						emit(mut output, zigimg.Rgb555.rgb(u8(inputs[1]), 0, 0))
					}
					4 {
						emit(mut output, zigimg.Rgb332.rgb(0, 0, u8(inputs[1])))
					}
					5 {
						arr := [u8(0), 0, 0, u8(inputs[1])]!
						emit(mut output, zigimg.Rgb555.from_array(arr))
					}
					6 {
						gray(mut output, zigimg.Grayscale2{ value: u8(inputs[1]) })
					}
					else {
						panic('invalid trap')
					}
				}
			}
			'8' {
				mixed := Mixed{
					r: u8(inputs[0])
					g: u16(inputs[1])
					b: double_value(inputs[2])
					a: values[3]
				}
				ignored := Ignored{
					r: mixed.r
					g: mixed.g
					b: mixed.b
					a: 'unused'
				}
				ignored_gray := IgnoredGray{
					value: mixed.b
					alpha: 'unused'
				}
				emit(mut output, zigimg.Rgb332.from_color(mixed))
				emit(mut output, zigimg.Rgb555.from_color(mixed))
				emit(mut output, zigimg.Rgb565.from_color(mixed))
				emit(mut output, zigimg.Bgr555.from_color(mixed))
				emit(mut output, zigimg.Rgb24.from_color(mixed))
				emit(mut output, zigimg.Rgba32.from_color(mixed))
				emit(mut output, zigimg.Bgr24.from_color(mixed))
				emit(mut output, zigimg.Bgra32.from_color(mixed))
				emit(mut output, zigimg.Rgb48.from_color(mixed))
				emit(mut output, zigimg.Rgba64.from_color(mixed))
				emit(mut output, zigimg.Colorf32.from_color(mixed))
				emit(mut output, zigimg.Rgb332.from_color(ignored))
				emit(mut output, zigimg.Rgb332.from_grayscale(ignored_gray))
				emit(mut output, zigimg.Rgb555.from_color(ignored))
				emit(mut output, zigimg.Rgb555.from_grayscale(ignored_gray))
				emit(mut output, zigimg.Rgb565.from_color(ignored))
				emit(mut output, zigimg.Rgb565.from_grayscale(ignored_gray))
				emit(mut output, zigimg.Bgr555.from_color(ignored))
				emit(mut output, zigimg.Bgr555.from_grayscale(ignored_gray))
				emit(mut output, zigimg.Rgb24.from_color(ignored))
				emit(mut output, zigimg.Rgb24.from_grayscale(ignored_gray))
				emit(mut output, zigimg.Bgr24.from_color(ignored))
				emit(mut output, zigimg.Bgr24.from_grayscale(ignored_gray))
				emit(mut output, zigimg.Rgb48.from_color(ignored))
				emit(mut output, zigimg.Rgb48.from_grayscale(ignored_gray))
			}
			'9' {
				{
					value := zigimg.Rgb332.from_u64_rgba(inputs[0])
					custom := value.to_color[CustomTarget]()
					tagged := value.to_color[TaggedTarget]()
					output.write_string(custom.value.str())
					output.write_string(',')
					output.write_string(tagged.value.str())
					output.write_string(',')
				}
				{
					value := zigimg.Rgb555.from_u64_rgba(inputs[0])
					custom := value.to_color[CustomTarget]()
					tagged := value.to_color[TaggedTarget]()
					output.write_string(custom.value.str())
					output.write_string(',')
					output.write_string(tagged.value.str())
					output.write_string(',')
				}
				{
					value := zigimg.Rgb565.from_u64_rgba(inputs[0])
					custom := value.to_color[CustomTarget]()
					tagged := value.to_color[TaggedTarget]()
					output.write_string(custom.value.str())
					output.write_string(',')
					output.write_string(tagged.value.str())
					output.write_string(',')
				}
				{
					value := zigimg.Bgr555.from_u64_rgba(inputs[0])
					custom := value.to_color[CustomTarget]()
					tagged := value.to_color[TaggedTarget]()
					output.write_string(custom.value.str())
					output.write_string(',')
					output.write_string(tagged.value.str())
					output.write_string(',')
				}
				{
					value := zigimg.Rgb24.from_u64_rgba(inputs[0])
					custom := value.to_color[CustomTarget]()
					tagged := value.to_color[TaggedTarget]()
					output.write_string(custom.value.str())
					output.write_string(',')
					output.write_string(tagged.value.str())
					output.write_string(',')
				}
				{
					value := zigimg.Rgba32.from_u64_rgba(inputs[0])
					custom := value.to_color[CustomTarget]()
					tagged := value.to_color[TaggedTarget]()
					output.write_string(custom.value.str())
					output.write_string(',')
					output.write_string(tagged.value.str())
					output.write_string(',')
				}
				{
					value := zigimg.Bgr24.from_u64_rgba(inputs[0])
					custom := value.to_color[CustomTarget]()
					tagged := value.to_color[TaggedTarget]()
					output.write_string(custom.value.str())
					output.write_string(',')
					output.write_string(tagged.value.str())
					output.write_string(',')
				}
				{
					value := zigimg.Bgra32.from_u64_rgba(inputs[0])
					custom := value.to_color[CustomTarget]()
					tagged := value.to_color[TaggedTarget]()
					output.write_string(custom.value.str())
					output.write_string(',')
					output.write_string(tagged.value.str())
					output.write_string(',')
				}
				{
					value := zigimg.Rgb48.from_u64_rgba(inputs[0])
					custom := value.to_color[CustomTarget]()
					tagged := value.to_color[TaggedTarget]()
					output.write_string(custom.value.str())
					output.write_string(',')
					output.write_string(tagged.value.str())
					output.write_string(',')
				}
				{
					value := zigimg.Rgba64.from_u64_rgba(inputs[0])
					custom := value.to_color[CustomTarget]()
					tagged := value.to_color[TaggedTarget]()
					output.write_string(custom.value.str())
					output.write_string(',')
					output.write_string(tagged.value.str())
					output.write_string(',')
				}
				{
					value := zigimg.Colorf32.from_u64_rgba(inputs[0])
					custom := value.to_color[CustomTarget]()
					tagged := value.to_color[TaggedTarget]()
					output.write_string(custom.value.str())
					output.write_string(',')
					output.write_string(tagged.value.str())
					output.write_string(',')
				}
			}
			'10' {
				{
					value := zigimg.color_from_u64_rgba[AliasRgb332](inputs[0])
					emit(mut output, zigimg.Rgba32.from_color(value))
					emit(mut output, value.to_color[zigimg.Rgba32]())
					emit(mut output, value.to_color[AliasBgr555]())
					emit(mut output, zigimg.color_from_color[AliasBgr555, AliasRgb332](value))
				}
				{
					value := zigimg.color_from_u64_rgba[AliasRgb555](inputs[0])
					emit(mut output, zigimg.Rgba32.from_color(value))
					emit(mut output, value.to_color[zigimg.Rgba32]())
					emit(mut output, value.to_color[AliasBgr555]())
					emit(mut output, zigimg.color_from_color[AliasBgr555, AliasRgb555](value))
				}
				{
					value := zigimg.color_from_u64_rgba[AliasRgb565](inputs[0])
					emit(mut output, zigimg.Rgba32.from_color(value))
					emit(mut output, value.to_color[zigimg.Rgba32]())
					emit(mut output, value.to_color[AliasBgr555]())
					emit(mut output, zigimg.color_from_color[AliasBgr555, AliasRgb565](value))
				}
				{
					value := zigimg.color_from_u64_rgba[AliasBgr555](inputs[0])
					emit(mut output, zigimg.Rgba32.from_color(value))
					emit(mut output, value.to_color[zigimg.Rgba32]())
					emit(mut output, value.to_color[AliasBgr555]())
					emit(mut output, zigimg.color_from_color[AliasBgr555, AliasBgr555](value))
				}
				arr := [u8(inputs[0] & 31), u8((inputs[0] >> 5) & 31), u8((inputs[0] >> 10) & 31),
					u8((inputs[0] >> 15) & 31)]!
				emit(mut output, zigimg.color_from_array[AliasBgr555, u8](arr))
				emit(mut output,
					zigimg.Rgba32.from_grayscale(AliasGray2{ value: u8(inputs[0] & 3) }))
			}
			else {
				panic('invalid mode')
			}
		}

		println(output.str())
	}
}
