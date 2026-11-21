module main

import os
import zigimg as p

const formats = [p.PixelFormat.invalid, .indexed1, .indexed2, .indexed4, .indexed8, .indexed16,
	.grayscale1, .grayscale2, .grayscale4, .grayscale8, .grayscale16, .grayscale8_alpha,
	.grayscale16_alpha, .rgb332, .rgb555, .rgb565, .rgb24, .rgba32, .bgr555, .bgr24, .bgra32, .rgb48,
	.rgba64, .float32]
const floats = [u32(0), 0x80000000, 0x3e800000, 0xbf800000, 0x3f800000, 0x40400000, 0x7f800000,
	0xff800000, 0x7fc01234, 0x7fa01234]

__global (
	observed_path   string
	observed_pixels &p.PixelStorage
	observed_iter   = &p.PixelStorageIterator(unsafe { nil })
)
fn palette_bytes(pixels p.PixelStorage) string {
	if pal := pixels.get_palette() { return unsafe { (&u8(pal.data)).vbytes(pal.len * 4).hex() } }
	return '-'
}

fn observe() {
	mut out := '${u32(observed_pixels.pixel_format())}|${observed_pixels.len()}|${observed_pixels.as_bytes().hex()}|${palette_bytes(*observed_pixels)}'
	if observed_iter != unsafe { nil } {
		out += '|${observed_iter.current_index}|${observed_iter.end}'
	}
	os.write_file(observed_path, out) or { eprintln('OBSERVER ERROR: ${err}') }
}

fn typed_pointer(pixels p.PixelStorage) uint {
	return match pixels {
		p.InvalidPixels { uint(0) }
		p.IndexedStorage1 { uint(pixels.indices.data) }
		p.IndexedStorage2 { uint(pixels.indices.data) }
		p.IndexedStorage4 { uint(pixels.indices.data) }
		p.IndexedStorage8 { uint(pixels.indices.data) }
		p.IndexedStorage16 { uint(pixels.indices.data) }
		p.Grayscale1Pixels { uint(pixels.data.data) }
		p.Grayscale2Pixels { uint(pixels.data.data) }
		p.Grayscale4Pixels { uint(pixels.data.data) }
		p.Grayscale8Pixels { uint(pixels.data.data) }
		p.Grayscale16Pixels { uint(pixels.data.data) }
		p.Grayscale8AlphaPixels { uint(pixels.data.data) }
		p.Grayscale16AlphaPixels { uint(pixels.data.data) }
		p.Rgb332Pixels { uint(pixels.data.data) }
		p.Rgb555Pixels { uint(pixels.data.data) }
		p.Rgb565Pixels { uint(pixels.data.data) }
		p.Rgb24Pixels { uint(pixels.data.data) }
		p.Rgba32Pixels { uint(pixels.data.data) }
		p.Bgr555Pixels { uint(pixels.data.data) }
		p.Bgr24Pixels { uint(pixels.data.data) }
		p.Bgra32Pixels { uint(pixels.data.data) }
		p.Rgb48Pixels { uint(pixels.data.data) }
		p.Rgba64Pixels { uint(pixels.data.data) }
		p.Colorf32Pixels { uint(pixels.data.data) }
	}
}

fn make_pixels(format p.PixelFormat, count int, seed int) p.PixelStorage {
	mut pixels := p.PixelStorage.init(format, uint(count)) or { panic(err) }
	if format == .invalid { return pixels }
	mut raw := pixels.as_bytes()
	for i in 0 .. raw.len {
		raw[i] = u8(i * 17 + seed * 61)
	}
	if pal := pixels.get_palette() {
		mut palette := unsafe { pal }
		length := if pal.len > 16 { 16 } else { pal.len }
		for i in 0 .. length {
			palette[i] = p.Rgba32{
				r: u8(i * 29 + seed)
				g: u8(i * 13 + seed * 7)
				b: u8(i * 11 + seed * 19)
				a: u8(i * 31 + seed * 17)
			}
		}
		pixels.resize_palette(uint(length))
		stride := int(format.pixel_stride())
		for i in 0 .. count {
			value := (i + seed) % length
			raw[i * stride] = u8(value)
			if stride == 2 { raw[i * stride + 1] = u8(value >> 8) }
		}
	} else {
		match format {
			.grayscale1, .grayscale2, .grayscale4 {
				mask := if format == .grayscale1 {
					u8(1)
				} else if format == .grayscale2 {
					u8(3)
				} else {
					u8(15)
				}
				for i in 0 .. raw.len {
					raw[i] &= mask
				}
			}
			.rgb555, .bgr555 {
				for i in 0 .. count {
					raw[i * 2 + 1] &= 127
				}
			}
			.float32 {
				for i in 0 .. count * 4 {
					word := floats[(i + seed) % floats.len]
					for b in 0 .. 4 {
						raw[i * 4 + b] = u8(word >> u32(b * 8))
					}
				}
			}
			else {}
		}
	}
	return pixels
}

fn colors(mut iter p.PixelStorageIterator) string {
	mut out := ''
	for {
		if color := iter.next() {
			out += unsafe { (&u8(&color)).vbytes(16).hex() } + ','
		} else {
			break
		}
	}
	return out
}

fn main() {
	if os.args.len > 1 {
		observed_path = os.args[2]
		format := unsafe { p.PixelFormat(os.args[3].u32()) }
		count := os.args[4].int()
		mut pixels := make_pixels(format, count, 1)
		observed_pixels = &pixels
		at_exit(observe) or { panic(err) }
		if os.args[1] == '--slice' {
			_ = pixels.slice(uint(os.args[5].u64()), uint(os.args[6].u64()))
		} else {
			mut iter := p.PixelStorageIterator.init(&pixels)
			observed_iter = &iter
			iter.current_index = uint(os.args[5].u64())
			iter.end = uint(os.args[6].u64())
			if os.args[1] == '--palette' { pixels.resize_palette(uint(os.args[7].u64())) }
			if os.args[1] == '--replace' { pixels = make_pixels(.rgb24, 1, 2) }
			_ = iter.next()
		}
		eprintln('UNEXPECTED: operation returned')
		return
	}
	for format in formats {
		for count in 0 .. 9 {
			for seed in 0 .. 4 {
				pixels := make_pixels(format, count, seed)
				for begin in 0 .. count + 1 {
					for end in begin .. count + 1 {
						view := pixels.slice(uint(begin), uint(end))
						pointer_ok := format == .invalid || count == 0
							|| typed_pointer(view) == typed_pointer(pixels) + uint(begin) * uint(format.pixel_stride())
						palette_ok := if pal := view.get_palette() {
							original := pixels.get_palette() or { panic('missing palette') }
							uint(pal.data) == uint(original.data)
						} else {
							true
						}
						mut raw := view.as_bytes()
						mutation := if view.is_indexed() { int(format.pixel_stride()) } else { 1 }
						if raw.len != 0 { raw[raw.len - mutation] ^= 1 }
						prefix := 'S|${u32(format)}|${count}|${seed}|${begin}|${end}|${view.len()}|${pointer_ok}|${palette_ok}|${raw.hex()}|${pixels.as_bytes().hex()}|'
						mut iter := p.PixelStorageIterator.init(&view)
						converted := colors(mut iter)
						println(prefix + converted + '|${iter.current_index}|${iter.end}')
						if raw.len != 0 { raw[raw.len - mutation] ^= 1 }
					}
				}
				mut iter := p.PixelStorageIterator.init(&pixels)
				mut copied := iter
				_ = iter.next()
				prefix := 'C|${u32(format)}|${count}|${seed}|${iter.current_index}|${copied.current_index}|${uint(iter.pixels) == uint(copied.pixels)}|'
				converted := colors(mut copied)
				println(prefix + converted + '|${iter.current_index}|${copied.current_index}')
			}
		}
	}
	for initial in formats {
		for replacement in formats {
			for start in [uint(0), 2] {
				mut pixels := make_pixels(initial, 4, 0)
				mut iter := p.PixelStorageIterator.init(&pixels)
				iter.current_index = start
				pixels = make_pixels(replacement, 8, 2)
				prefix := 'L|${u32(initial)}|${u32(replacement)}|${start}|${iter.end}|'
				converted := colors(mut iter)
				println(prefix + converted +
					'|${iter.current_index}|${uint(iter.pixels) == uint(&pixels)}')
			}
		}
	}
	for format in formats {
		pixels := make_pixels(format, 4, 1)
		for bounds in [[uint(4), 4], [uint(5), 4], [~uint(0), ~uint(0)],
			[~uint(0), 0], [uint(0x100000000), 0x80000000],
			[uint(0), 0]] {
			mut iter := p.PixelStorageIterator.init(&pixels)
			iter.current_index = bounds[0]
			iter.end = bounds[1]
			exhausted := iter.next() == none
			println('E|${u32(format)}|${bounds[0]}|${bounds[1]}|${exhausted}|${iter.current_index}')
		}
	}
	invalid := p.PixelStorage(p.InvalidPixels{})
	for begin in [uint(0), 1, 0x80000000, 0x100000000, ~uint(0)] {
		for end in [uint(0), 1, 0x80000000, 0x100000000, ~uint(0)] {
			view := invalid.slice(begin, end)
			println('B|${begin}|${end}|${u32(view.pixel_format())}|${view.len()}')
		}
	}
	mut defaults := p.PixelStorageIterator{}
	none_first := defaults.next() == none
	println('D|${none_first}|${defaults.current_index}|${defaults.end}')
	defaults.current_index = ~uint(0)
	defaults.end = ~uint(0)
	none_last := defaults.next() == none
	println('D|${none_last}|${defaults.current_index}|${defaults.end}')
	mut wide := p.PixelStorageIterator.init(&invalid)
	wide.current_index = ~uint(0) - 1
	wide.end = ~uint(0)
	converted := colors(mut wide)
	println('W|' + converted + '|${wide.current_index}|${wide.end}')
}
