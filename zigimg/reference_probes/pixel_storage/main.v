module main

import os
import zigimg as p

__global (
	observed_path  string
	observed_len   = &int(unsafe { nil })
	observed_bytes []u8
)
fn observe() {
	prefix := if observed_len == unsafe { nil } { '-|' } else { '${*observed_len}|' }
	os.write_file(observed_path, prefix + observed_bytes.hex()) or {
		eprintln('OBSERVER ERROR: ${err}')
	}
}

fn aligned(format p.PixelFormat) bool {
	return format in [.grayscale16_alpha, .rgb555, .rgb565, .bgr555]
}

fn supported(format p.PixelFormat) bool {
	return format !in [.invalid, .indexed1, .indexed2, .indexed4, .indexed8, .indexed16, .grayscale16]
}

fn typed_pointer(storage p.PixelStorage) uint {
	return match storage {
		p.InvalidPixels { uint(0) }
		p.IndexedStorage1 { uint(storage.indices.data) }
		p.IndexedStorage2 { uint(storage.indices.data) }
		p.IndexedStorage4 { uint(storage.indices.data) }
		p.IndexedStorage8 { uint(storage.indices.data) }
		p.IndexedStorage16 { uint(storage.indices.data) }
		p.Grayscale1Pixels { uint(storage.data.data) }
		p.Grayscale2Pixels { uint(storage.data.data) }
		p.Grayscale4Pixels { uint(storage.data.data) }
		p.Grayscale8Pixels { uint(storage.data.data) }
		p.Grayscale16Pixels { uint(storage.data.data) }
		p.Grayscale8AlphaPixels { uint(storage.data.data) }
		p.Grayscale16AlphaPixels { uint(storage.data.data) }
		p.Rgb332Pixels { uint(storage.data.data) }
		p.Rgb555Pixels { uint(storage.data.data) }
		p.Rgb565Pixels { uint(storage.data.data) }
		p.Rgb24Pixels { uint(storage.data.data) }
		p.Rgba32Pixels { uint(storage.data.data) }
		p.Bgr555Pixels { uint(storage.data.data) }
		p.Bgr24Pixels { uint(storage.data.data) }
		p.Bgra32Pixels { uint(storage.data.data) }
		p.Rgb48Pixels { uint(storage.data.data) }
		p.Rgba64Pixels { uint(storage.data.data) }
		p.Colorf32Pixels { uint(storage.data.data) }
	}
}

fn indexed_1() {
	sizes := []int{len: 3, init: index}
	for size in sizes {
		for count in [0, 1, 7, 31] {
			mut x := p.IndexedStorage1.init_palette_size(uint(count), uint(size))
			mut black := true
			for color in x.palette {
				black = black && color.r == 0 && color.g == 0 && color.b == 0 && color.a == 255
			}
			for i in 0 .. x.indices.len {
				x.indices[i] = u8(i % 2)
			}
			bytes := unsafe { (&u8(x.indices.data)).vbytes(x.indices.len * 1) }
			println('I|1|${size}|${count}|${x.palette.len}|${black}|${bytes.hex()}')
		}
	}
	mut x := p.IndexedStorage1.init(7)
	for i in 0 .. x.palette.len {
		x.palette[i] = p.Rgba32{
			r: u8(i)
			g: u8(i >> 8)
			b: u8(i * 7)
			a: 255
		}
	}
	for i in 0 .. x.indices.len {
		x.indices[i] = u8(i % 2)
	}
	copied := x
	original := x.palette.data
	for size in [0, 1, 1, 1, 2] {
		x.resize_palette(uint(size))
		mut storage := p.PixelStorage(x)
		storage.resize_palette(uint(size))
		sub := storage.slice(1, 6)
		mut pal := sub.get_palette() or { panic('missing palette') }
		if pal.len != 0 { pal[0] = p.Rgba32{
				r: 9
				g: 8
				b: 7
				a: 6
			} }
		first := unsafe { (&u8(copied.palette.data)).vbytes(4) }
		println('R|1|${size}|${copied.palette.len}|${x.palette.data == original}|${sub.len()}|${pal.data == original}|${first.hex()}|${sub.as_bytes().hex()}')
	}
}

fn trap_1(mode string, size uint) {
	if mode == '--init' {
		_ = p.IndexedStorage1.init_palette_size(7, size)
	} else {
		mut x := p.IndexedStorage1.init(7)
		observed_len = &x.palette.len
		observed_bytes = unsafe { (&u8(x.palette.data)).vbytes(8) }
		if mode == '--resize' {
			x.resize_palette(size)
		} else {
			mut storage := p.PixelStorage(x)
			match mut storage {
				p.IndexedStorage1 { observed_len = &storage.palette.len }
				else { panic('wrong storage') }
			}

			storage.resize_palette(size)
		}
	}
	eprintln('UNEXPECTED: indexed operation returned')
}

fn indexed_2() {
	sizes := []int{len: 5, init: index}
	for size in sizes {
		for count in [0, 1, 7, 31] {
			mut x := p.IndexedStorage2.init_palette_size(uint(count), uint(size))
			mut black := true
			for color in x.palette {
				black = black && color.r == 0 && color.g == 0 && color.b == 0 && color.a == 255
			}
			for i in 0 .. x.indices.len {
				x.indices[i] = u8(i % 4)
			}
			bytes := unsafe { (&u8(x.indices.data)).vbytes(x.indices.len * 1) }
			println('I|2|${size}|${count}|${x.palette.len}|${black}|${bytes.hex()}')
		}
	}
	mut x := p.IndexedStorage2.init(7)
	for i in 0 .. x.palette.len {
		x.palette[i] = p.Rgba32{
			r: u8(i)
			g: u8(i >> 8)
			b: u8(i * 7)
			a: 255
		}
	}
	for i in 0 .. x.indices.len {
		x.indices[i] = u8(i % 4)
	}
	copied := x
	original := x.palette.data
	for size in [0, 1, 2, 3, 4] {
		x.resize_palette(uint(size))
		mut storage := p.PixelStorage(x)
		storage.resize_palette(uint(size))
		sub := storage.slice(1, 6)
		mut pal := sub.get_palette() or { panic('missing palette') }
		if pal.len != 0 { pal[0] = p.Rgba32{
				r: 9
				g: 8
				b: 7
				a: 6
			} }
		first := unsafe { (&u8(copied.palette.data)).vbytes(4) }
		println('R|2|${size}|${copied.palette.len}|${x.palette.data == original}|${sub.len()}|${pal.data == original}|${first.hex()}|${sub.as_bytes().hex()}')
	}
}

fn trap_2(mode string, size uint) {
	if mode == '--init' {
		_ = p.IndexedStorage2.init_palette_size(7, size)
	} else {
		mut x := p.IndexedStorage2.init(7)
		observed_len = &x.palette.len
		observed_bytes = unsafe { (&u8(x.palette.data)).vbytes(8) }
		if mode == '--resize' {
			x.resize_palette(size)
		} else {
			mut storage := p.PixelStorage(x)
			match mut storage {
				p.IndexedStorage2 { observed_len = &storage.palette.len }
				else { panic('wrong storage') }
			}

			storage.resize_palette(size)
		}
	}
	eprintln('UNEXPECTED: indexed operation returned')
}

fn indexed_4() {
	sizes := []int{len: 17, init: index}
	for size in sizes {
		for count in [0, 1, 7, 31] {
			mut x := p.IndexedStorage4.init_palette_size(uint(count), uint(size))
			mut black := true
			for color in x.palette {
				black = black && color.r == 0 && color.g == 0 && color.b == 0 && color.a == 255
			}
			for i in 0 .. x.indices.len {
				x.indices[i] = u8(i % 16)
			}
			bytes := unsafe { (&u8(x.indices.data)).vbytes(x.indices.len * 1) }
			println('I|4|${size}|${count}|${x.palette.len}|${black}|${bytes.hex()}')
		}
	}
	mut x := p.IndexedStorage4.init(7)
	for i in 0 .. x.palette.len {
		x.palette[i] = p.Rgba32{
			r: u8(i)
			g: u8(i >> 8)
			b: u8(i * 7)
			a: 255
		}
	}
	for i in 0 .. x.indices.len {
		x.indices[i] = u8(i % 16)
	}
	copied := x
	original := x.palette.data
	for size in [0, 1, 8, 15, 16] {
		x.resize_palette(uint(size))
		mut storage := p.PixelStorage(x)
		storage.resize_palette(uint(size))
		sub := storage.slice(1, 6)
		mut pal := sub.get_palette() or { panic('missing palette') }
		if pal.len != 0 { pal[0] = p.Rgba32{
				r: 9
				g: 8
				b: 7
				a: 6
			} }
		first := unsafe { (&u8(copied.palette.data)).vbytes(4) }
		println('R|4|${size}|${copied.palette.len}|${x.palette.data == original}|${sub.len()}|${pal.data == original}|${first.hex()}|${sub.as_bytes().hex()}')
	}
}

fn trap_4(mode string, size uint) {
	if mode == '--init' {
		_ = p.IndexedStorage4.init_palette_size(7, size)
	} else {
		mut x := p.IndexedStorage4.init(7)
		observed_len = &x.palette.len
		observed_bytes = unsafe { (&u8(x.palette.data)).vbytes(8) }
		if mode == '--resize' {
			x.resize_palette(size)
		} else {
			mut storage := p.PixelStorage(x)
			match mut storage {
				p.IndexedStorage4 { observed_len = &storage.palette.len }
				else { panic('wrong storage') }
			}

			storage.resize_palette(size)
		}
	}
	eprintln('UNEXPECTED: indexed operation returned')
}

fn indexed_8() {
	sizes := []int{len: 257, init: index}
	for size in sizes {
		for count in [0, 1, 7, 31] {
			mut x := p.IndexedStorage8.init_palette_size(uint(count), uint(size))
			mut black := true
			for color in x.palette {
				black = black && color.r == 0 && color.g == 0 && color.b == 0 && color.a == 255
			}
			for i in 0 .. x.indices.len {
				x.indices[i] = u8(i % 256)
			}
			bytes := unsafe { (&u8(x.indices.data)).vbytes(x.indices.len * 1) }
			println('I|8|${size}|${count}|${x.palette.len}|${black}|${bytes.hex()}')
		}
	}
	mut x := p.IndexedStorage8.init(7)
	for i in 0 .. x.palette.len {
		x.palette[i] = p.Rgba32{
			r: u8(i)
			g: u8(i >> 8)
			b: u8(i * 7)
			a: 255
		}
	}
	for i in 0 .. x.indices.len {
		x.indices[i] = u8(i % 256)
	}
	copied := x
	original := x.palette.data
	for size in [0, 1, 128, 255, 256] {
		x.resize_palette(uint(size))
		mut storage := p.PixelStorage(x)
		storage.resize_palette(uint(size))
		sub := storage.slice(1, 6)
		mut pal := sub.get_palette() or { panic('missing palette') }
		if pal.len != 0 { pal[0] = p.Rgba32{
				r: 9
				g: 8
				b: 7
				a: 6
			} }
		first := unsafe { (&u8(copied.palette.data)).vbytes(4) }
		println('R|8|${size}|${copied.palette.len}|${x.palette.data == original}|${sub.len()}|${pal.data == original}|${first.hex()}|${sub.as_bytes().hex()}')
	}
}

fn trap_8(mode string, size uint) {
	if mode == '--init' {
		_ = p.IndexedStorage8.init_palette_size(7, size)
	} else {
		mut x := p.IndexedStorage8.init(7)
		observed_len = &x.palette.len
		observed_bytes = unsafe { (&u8(x.palette.data)).vbytes(8) }
		if mode == '--resize' {
			x.resize_palette(size)
		} else {
			mut storage := p.PixelStorage(x)
			match mut storage {
				p.IndexedStorage8 { observed_len = &storage.palette.len }
				else { panic('wrong storage') }
			}

			storage.resize_palette(size)
		}
	}
	eprintln('UNEXPECTED: indexed operation returned')
}

fn indexed_16() {
	sizes := [0, 1, 2, 15, 16, 255, 256, 32767, 65535, 65536]
	for size in sizes {
		for count in [0, 1, 7, 31] {
			mut x := p.IndexedStorage16.init_palette_size(uint(count), uint(size))
			mut black := true
			for color in x.palette {
				black = black && color.r == 0 && color.g == 0 && color.b == 0 && color.a == 255
			}
			for i in 0 .. x.indices.len {
				x.indices[i] = u16(i % 65536)
			}
			bytes := unsafe { (&u8(x.indices.data)).vbytes(x.indices.len * 2) }
			println('I|16|${size}|${count}|${x.palette.len}|${black}|${bytes.hex()}')
		}
	}
	mut x := p.IndexedStorage16.init(7)
	for i in 0 .. x.palette.len {
		x.palette[i] = p.Rgba32{
			r: u8(i)
			g: u8(i >> 8)
			b: u8(i * 7)
			a: 255
		}
	}
	for i in 0 .. x.indices.len {
		x.indices[i] = u16(i % 65536)
	}
	copied := x
	original := x.palette.data
	for size in [0, 1, 32768, 65535, 65536] {
		x.resize_palette(uint(size))
		mut storage := p.PixelStorage(x)
		storage.resize_palette(uint(size))
		sub := storage.slice(1, 6)
		mut pal := sub.get_palette() or { panic('missing palette') }
		if pal.len != 0 { pal[0] = p.Rgba32{
				r: 9
				g: 8
				b: 7
				a: 6
			} }
		first := unsafe { (&u8(copied.palette.data)).vbytes(4) }
		println('R|16|${size}|${copied.palette.len}|${x.palette.data == original}|${sub.len()}|${pal.data == original}|${first.hex()}|${sub.as_bytes().hex()}')
	}
}

fn trap_16(mode string, size uint) {
	if mode == '--init' {
		_ = p.IndexedStorage16.init_palette_size(7, size)
	} else {
		mut x := p.IndexedStorage16.init(7)
		observed_len = &x.palette.len
		observed_bytes = unsafe { (&u8(x.palette.data)).vbytes(8) }
		if mode == '--resize' {
			x.resize_palette(size)
		} else {
			mut storage := p.PixelStorage(x)
			match mut storage {
				p.IndexedStorage16 { observed_len = &storage.palette.len }
				else { panic('wrong storage') }
			}

			storage.resize_palette(size)
		}
	}
	eprintln('UNEXPECTED: indexed operation returned')
}

fn main() {
	if os.args.len > 1 {
		if os.args[1] == '--boxed' {
			bits := os.args[2].u32()
			mut storage := p.PixelStorage.init(unsafe { p.PixelFormat(bits) }, 7) or { panic(err) }
			copied := storage
			storage.resize_palette(1)
			println('${(storage.get_palette() or { panic(err) }).len}|${(copied.get_palette() or {
				panic(err)
			}).len}')
			return
		}
		observed_path = os.args[2]
		at_exit(observe) or { panic(err) }
		if os.args[1] == '--raw' {
			bytes := []u8{len: 160, init: 165}
			base := if uint(bytes.data) % 16 == 0 { 0 } else { int(16 - uint(bytes.data) % 16) }
			observed_bytes = bytes[base..base + 64]
			format := unsafe { p.PixelFormat(os.args[3].u32()) }
			offset := os.args[4].int()
			len := os.args[5].int()
			_ = p.PixelStorage.init_raw_pixels(bytes[base + offset..base + offset + len], format) or {
				panic(err)
			}
			eprintln('UNEXPECTED: raw operation returned')
		} else {
			bits := os.args[3].int()
			size := uint(os.args[4].u64())
			match bits {
				1 { trap_1(os.args[1], size) }
				2 { trap_2(os.args[1], size) }
				4 { trap_4(os.args[1], size) }
				8 { trap_8(os.args[1], size) }
				16 { trap_16(os.args[1], size) }
				else { panic('unknown bits') }
			}
		}
		return
	}
	indexed_1()
	indexed_2()
	indexed_4()
	indexed_8()
	indexed_16()
	formats := [p.PixelFormat.invalid, .indexed1, .indexed2, .indexed4, .indexed8, .indexed16,
		.grayscale1, .grayscale2, .grayscale4, .grayscale8, .grayscale16, .grayscale8_alpha,
		.grayscale16_alpha, .rgb332, .rgb555, .rgb565, .rgb24, .rgba32, .bgr555, .bgr24, .bgra32,
		.rgb48, .rgba64, .float32]
	for format in formats {
		for offset in 0 .. 4 {
			for count in 0 .. 9 {
				for seed in 0 .. 4 {
					if supported(format) && count != 0 && aligned(format) && offset % 2 != 0 { continue
					 }
					mut bytes := []u8{len: 192}
					base := if uint(bytes.data) % 16 == 0 {
						0
					} else {
						int(16 - uint(bytes.data) % 16)
					}
					for i in 0 .. 160 {
						bytes[base + i] = u8(i * 17 + seed * 61)
					}
					stride := if supported(format) { int(format.pixel_stride()) } else { 1 }
					input := bytes[base + offset..base + offset + count * stride]
					result := p.PixelStorage.init_raw_pixels(input, format) or {
						println('E|${u32(format)}|${offset}|${count}|${seed}|${err.msg()}')
						continue
					}
					// Source empty slice pointers are undefined, so observe only lengths.
					pointer_ok := count == 0 || typed_pointer(result) == uint(input.data)
					mut raw := result.as_bytes()
					if raw.len != 0 { raw[raw.len - 1] = u8(seed + 97) }
					sub := result.slice(uint(count / 2), uint(count))
					println('B|${u32(format)}|${offset}|${count}|${seed}|${result.len()}|${pointer_ok}|${raw.hex()}|${input.hex()}|${sub.as_bytes().hex()}')
				}
			}
		}
	}
}
