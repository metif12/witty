module main

import os
import math
import zigimg as p

__global (
	observed_path   string
	observed_pixels &p.PixelStorage
	observed_image  = &p.ImageUnmanaged(unsafe { nil })
)
fn snapshot() string {
	pixels := if observed_image != unsafe { nil } { observed_image.pixels } else { *observed_pixels }
	mut out := '${u32(pixels.pixel_format())}|${pixels.len()}|${pixels.as_bytes().hex()}|'
	if pal := pixels.get_palette() {
		out += unsafe { (&u8(pal.data)).vbytes(pal.len * 4).hex() }
	} else {
		out += '-'
	}
	if observed_image != unsafe { nil } {
		out += '|${observed_image.width}|${observed_image.height}|${observed_image.animation.loop_count}|'
		for frame in observed_image.animation.frames {
			out +=
				unsafe { (&u8(&frame.duration)).vbytes(4).hex() } + ':' + frame.pixels.as_bytes().hex() +
				';'
		}
	}
	return out
}

fn observe() {
	os.write_file(observed_path, snapshot()) or { eprintln('OBSERVER ERROR: ${err}') }
}

fn word(mut raw []u8, offset int, value u32) {
	for b in 0 .. 4 {
		raw[offset + b] = u8(value >> u32(b * 8))
	}
}

fn bits(value f32) u32 {
	return unsafe { *(&u32(&value)) }
}

fn float_from_bits(value u32) f32 {
	return unsafe { *(&f32(&value)) }
}

fn make_pixels(format p.PixelFormat, count int, offset int, owned bool) p.PixelStorage {
	mut pixels := p.PixelStorage(p.InvalidPixels{})
	if format == .float32 && !owned {
		length := if count == 0 { 16 } else { count * 16 }
		data := []u8{len: length + 32}
		base := if usize(data.data) % 16 == 0 { 0 } else { int(16 - usize(data.data) % 16) }
		all := p.PixelStorage.init_raw_pixels(data[base + offset..base + offset + length], format) or {
			panic(err)
		}
		pixels = all.slice(0, usize(count))
	} else {
		pixels = p.PixelStorage.init(format, usize(count)) or { panic(err) }
	}
	mut raw := pixels.as_bytes()
	for i in 0 .. raw.len {
		raw[i] = u8(i * 37 + 19)
	}
	if format == .float32 {
		for i in 0 .. count * 4 {
			word(mut raw, i * 4, bits(f32((i * 31 + 17) % 257) / 256))
		}
	} else if format == .bgr555 {
		for i in 0 .. count {
			raw[i * 2 + 1] &= 127
		}
	} else if _ := pixels.get_palette() {
		mut pal := pixels.get_palette() or { panic('missing palette') }
		pixels.resize_palette(1)
		pal[0] = p.Rgba32{
			r: 31
			g: 73
			b: 127
			a: 191
		}
		for i in 0 .. count {
			raw[i * int(format.pixel_stride())] = 1
			if format == .indexed16 { raw[i * 2 + 1] = 0 }
		}
	}
	return pixels
}

fn put(pixels p.PixelStorage, pixel int, channel int, value u32) {
	mut raw := pixels.as_bytes()
	word(mut raw, (pixel * 4 + channel) * 4, value)
}

fn returning(pixels &p.PixelStorage, destination p.PixelFormat) string {
	result := p.PixelFormatConverter.convert(pixels, destination) or {
		return '${err.msg()}|${pixels.len()}|${pixels.as_bytes().hex()}'
	}
	return 'ok|${result.len()}|${result.as_bytes().hex()}|${pixels.as_bytes().hex()}'
}

fn main() {
	if os.args.len > 1 {
		observed_path = os.args[2]
		source := unsafe { p.PixelFormat(os.args[3].u32()) }
		destination := unsafe { p.PixelFormat(os.args[4].u32()) }
		count := os.args[5].int()
		offset := os.args[6].int()
		mut pixels := make_pixels(source, count, offset, os.args[7] == 'owned')
		if source == .float32 && count != 0 && os.args.len > 8 {
			put(pixels, os.args[8].int(), os.args[9].int(), os.args[10].u32())
		}
		observed_pixels = &pixels
		at_exit(observe) or { panic(err) }
		if os.args[1] == '--direct' {
			_ = p.PixelFormatConverter.convert(&pixels, destination) or {
				eprintln('UNEXPECTED: recoverable ${err.msg()}')
				return
			}
		} else {
			mut image := p.ImageUnmanaged{
				width:     7
				height:    3
				pixels:    pixels
				animation: p.Animation{
					loop_count: 4
				}
			}
			image.animation.frames << p.AnimationFrame{
				pixels:   make_pixels(.rgb24, 1, 0, true)
				duration: 0.25
			}
			observed_image = &image
			if os.args[1] == '--image' {
				image.convert(destination) or {
					eprintln('UNEXPECTED: recoverable ${err.msg()}')
					return
				}
			} else {
				image.convert_no_free(destination) or {
					eprintln('UNEXPECTED: recoverable ${err.msg()}')
					return
				}
			}
		}
		eprintln('UNEXPECTED: operation returned')
		return
	}
	println('V|16')
	for destination in [p.PixelFormat.rgba32, .bgra32] {
		for count in 1 .. 18 {
			for seed in 0 .. 8 {
				pixels := make_pixels(.float32, count, 0, true)
				for i in 0 .. count * 4 {
					put(pixels, i / 4, i % 4, bits(f32((i * 31 + seed * 17) % 257) / 256))
				}
				println('R|${u32(destination)}|${count}|${seed}|' + returning(&pixels, destination))
			}
		}
		values := [f32(-0.003), 1.003, -0.0, 0.0, 0.5, 1.0, f32(math.nan()), float_from_bits(1)]
		for count in 1 .. 18 {
			for v, value in values {
				for channel in 0 .. 4 {
					pixels := make_pixels(.float32, count, 0, true)
					for i in 0 .. count {
						put(pixels, i, channel, bits(value))
					}
					println('B|${u32(destination)}|${count}|${v}|${channel}|' +
						returning(&pixels, destination))
				}
			}
		}
		for count in [1, 2, 3, 5, 6, 7, 9, 10, 11, 13, 14, 15, 17] {
			for v, value in [f32(-1), 2, f32(math.inf(1)), f32(math.inf(-1)), f32(math.nan())] {
				for channel in 0 .. 4 {
					pixels := make_pixels(.float32, count, 0, true)
					put(pixels, count - 1, channel, bits(value))
					println('T|${u32(destination)}|${count}|${v}|${channel}|' +
						returning(&pixels, destination))
				}
			}
		}
	}
	for source in [p.PixelFormat.rgba32, .bgra32] {
		for count in 1 .. 18 {
			for seed in 0 .. 8 {
				pixels := make_pixels(source, count, 0, true)
				mut raw := pixels.as_bytes()
				for i in 0 .. raw.len {
					raw[i] = u8(i * 73 + seed * 29)
				}
				println('U|${u32(source)}|${count}|${seed}|' + returning(&pixels, .float32))
			}
		}
	}
	for destination in [p.PixelFormat.float32, .grayscale16, .rgb24, .rgba64, .rgba32, .bgra32] {
		for count in [0, 1, 4] {
			for offset in 0 .. 4 {
				if offset != 0 && destination in [.rgba32, .bgra32] { continue
				 }
				pixels := make_pixels(.float32, count, offset, false)
				println('O|${u32(destination)}|${count}|${offset}|' +
					returning(&pixels, destination))
			}
		}
	}
}
