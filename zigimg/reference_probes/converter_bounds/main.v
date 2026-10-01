module main

import math
import os
import zigimg

fn main() {
	assert os.args.len == 2
	name := os.args[1]
	mut source := zigimg.PixelStorage(zigimg.InvalidPixels{})
	mut destination := zigimg.PixelFormat.rgb24
	if name.starts_with('bgr_') {
		source = zigimg.Bgr555Pixels{
			data: [zigimg.Bgr555{ raw: 1 }]
		}
		destination = match name {
			'bgr_rgb555' { .rgb555 }
			'bgr_rgb565' { .rgb565 }
			'bgr_rgb24' { .rgb24 }
			'bgr_rgba32' { .rgba32 }
			'bgr_bgr24' { .bgr24 }
			'bgr_bgra32' { .bgra32 }
			'bgr_rgb48' { .rgb48 }
			'bgr_rgba64' { .rgba64 }
			'bgr_float32' { .float32 }
			else { panic('unknown case') }
		}
	} else if name == 'empty_raw_float' {
		mut bytes := []u8{len: 1}
		source = zigimg.PixelStorage.init_raw_pixels(unsafe { bytes[..0] }, .float32) or {
			panic(err)
		}
		destination = .rgba32
	} else if name.starts_with('empty_') {
		format := if name in ['empty_rgba32', 'empty_bgra32'] {
			if name == 'empty_rgba32' {
				zigimg.PixelFormat.rgba32
			} else {
				zigimg.PixelFormat.bgra32
			}
		} else {
			zigimg.PixelFormat.float32
		}
		source = zigimg.PixelStorage.init(format, 0) or { panic(err) }
		destination = if format != .float32 {
			zigimg.PixelFormat.float32
		} else if name == 'empty_float_rgba' {
			zigimg.PixelFormat.rgba32
		} else {
			zigimg.PixelFormat.bgra32
		}
	} else if name == 'unaligned_float' {
		mut bytes := []u8{len: 17}
		assert usize(bytes.data) % 4 == 0
		source = zigimg.PixelStorage.init_raw_pixels(unsafe { bytes[1..] }, .float32) or {
			panic(err)
		}
		destination = .rgba32
	} else if name == 'palette_index' {
		mut indexed := zigimg.IndexedStorage8.init_palette_size(1, 1)
		indexed.indices[0] = 1
		source = indexed
	} else if name.starts_with('float_') {
		value := match name {
			'float_negative' { f32(-1) }
			'float_large' { f32(2) }
			'float_nan' { f32(math.nan()) }
			'float_infinity' { f32(math.inf(1)) }
			else { panic('unknown case') }
		}

		source = zigimg.Colorf32Pixels{
			data: []zigimg.Colorf32{len: 4, init: zigimg.Colorf32{
				r: value
			}}
		}
		destination = .rgba32
	} else {
		panic('unknown case')
	}
	result := zigimg.PixelFormatConverter.convert(&source, destination) or { panic(err) }
	if name == 'float_nan' {
		bytes := result.as_bytes()
		for i in 0 .. 4 {
			assert bytes[i * 4] == 0
		}
		eprintln('PASS: pinned ARM64 NaN prefix converts to zero')
		return
	}
	eprintln('UNEXPECTED: converter returned')
}
