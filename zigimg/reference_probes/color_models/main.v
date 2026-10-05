module main

import math
import os
import strings
import zigimg

fn float_value(bits u32) f32 {
	return unsafe { *(&f32(&bits)) }
}

fn emit(mut output strings.Builder, value f32) {
	bits := if math.is_nan(value) { u32(0x7fc00000) } else { unsafe { *(&u32(&value)) } }
	output.write_string('${bits},')
}

fn rgb(mut output strings.Builder, color zigimg.Colorf32) {
	for value in [color.r, color.g, color.b, color.a] {
		emit(mut output, value)
	}
}

fn hsl(mut output strings.Builder, color zigimg.Hsl) {
	for value in [color.hue, color.saturation, color.luminance] {
		emit(mut output, value)
	}
}

fn hsv(mut output strings.Builder, color zigimg.Hsv) {
	for value in [color.hue, color.saturation, color.value] {
		emit(mut output, value)
	}
}

fn predefined[T](mut output strings.Builder) {
	colors := zigimg.predefined_colors[T]()
	for color in [colors.red, colors.green, colors.blue, colors.white, colors.black, colors.cyan,
		colors.magenta, colors.yellow] {
		$if T is zigimg.Colorf32 {
			rgb(mut output, color)
		} $else {
			rgb(mut output, color.to_colorf32())
		}
	}
}

fn main() {
	for line in os.read_lines(os.args[1]) or { panic(err) } {
		fields := line.split('|')
		values := [float_value(fields[1].u32()), float_value(fields[2].u32()),
			float_value(fields[3].u32()), float_value(fields[4].u32())]!
		mut output := strings.new_builder(400)
		match fields[0] {
			'0' {
				value := zigimg.Colorf32{
					r: values[0]
					g: values[1]
					b: values[2]
					a: values[3]
				}
				s := zigimg.Hsl.from_rgb(value)
				hsl(mut output, s)
				rgb(mut output, s.to_rgb())
				hsv(mut output, s.to_hsv())
				v := zigimg.Hsv.from_rgb(value)
				hsv(mut output, v)
				rgb(mut output, v.to_rgb())
				hsl(mut output, v.to_hsl())
				c := zigimg.Cmykf32.from_colorf32(value)
				for channel in [c.c, c.m, c.y, c.k] {
					emit(mut output, channel)
				}
				rgb(mut output, c.to_colorf32())
				rgb(mut output, zigimg.Grayscalef32{
					value: values[0]
				}.to_colorf32())
				rgb(mut output,
					zigimg.Grayscalef32Alpha{
					value: values[0]
					alpha: values[3]
				}.to_colorf32())
			}
			'1' {
				s := zigimg.Hsl{
					hue:        values[0]
					saturation: values[1]
					luminance:  values[2]
				}
				rgb(mut output, s.to_rgb())
				hsv(mut output, s.to_hsv())
				v := zigimg.Hsv{
					hue:        values[0]
					saturation: values[1]
					value:      values[2]
				}
				rgb(mut output, v.to_rgb())
				hsl(mut output, v.to_hsl())
			}
			'2' {
				rgb(mut output, zigimg.Cmykf32{
					c: values[0]
					m: values[1]
					y: values[2]
					k: values[3]
				}.to_colorf32())
			}
			'3' {
				predefined[zigimg.Rgb24](mut output)
				predefined[zigimg.Rgba32](mut output)
				predefined[zigimg.Bgr24](mut output)
				predefined[zigimg.Bgra32](mut output)
				predefined[zigimg.Rgb48](mut output)
				predefined[zigimg.Rgba64](mut output)
				predefined[zigimg.Colorf32](mut output)
				predefined[zigimg.Rgb332](mut output)
				predefined[zigimg.Rgb555](mut output)
				predefined[zigimg.Bgr555](mut output)
				predefined[zigimg.Rgb565](mut output)
			}
			else {
				panic('InvalidMode')
			}
		}

		println(output.str())
	}
}
