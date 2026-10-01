module main

import os
import encoding.hex
import zigimg

fn numbers(text string) []u32 {
	if text.len == 0 { return []u32{} }
	return text.split(',').map(it.u32())
}

fn mix(mut hash []u64, value u64) {
	hash[0] = (hash[0] ^ value) * u64(1099511628211)
}

fn pixel_hash(pixels zigimg.PixelStorage) u64 {
	mut hash := [u64(14695981039346656037)]
	mix(mut hash, u64(pixels.len()))
	match pixels {
		zigimg.Grayscale1Pixels {
			for pixel in pixels.data {
				mix(mut hash, pixel.value)
			}
		}
		zigimg.Grayscale8Pixels {
			for pixel in pixels.data {
				mix(mut hash, pixel.value)
			}
		}
		zigimg.Grayscale16Pixels {
			for pixel in pixels.data {
				mix(mut hash, pixel.value)
			}
		}
		zigimg.IndexedStorage8 {
			for index in pixels.indices {
				mix(mut hash, index)
			}
			for color in pixels.palette {
				for channel in [color.r, color.g, color.b, color.a] {
					mix(mut hash, channel)
				}
			}
		}
		zigimg.Rgb24Pixels {
			for color in pixels.data {
				for channel in [color.r, color.g, color.b] {
					mix(mut hash, channel)
				}
			}
		}
		zigimg.Rgba32Pixels {
			for color in pixels.data {
				for channel in [color.r, color.g, color.b, color.a] {
					mix(mut hash, channel)
				}
			}
		}
		else {
			panic('unexpected test format')
		}
	}

	return hash[0]
}

fn initialize(mut pixels zigimg.PixelStorage) {
	match mut pixels {
		zigimg.Grayscale1Pixels {
			for mut pixel in pixels.data {
				pixel.value = 1
			}
		}
		zigimg.Grayscale8Pixels {
			for mut pixel in pixels.data {
				pixel.value = 0xa5
			}
		}
		zigimg.Grayscale16Pixels {
			for mut pixel in pixels.data {
				pixel.value = 0x5aa5
			}
		}
		zigimg.IndexedStorage8 {
			for mut index in pixels.indices {
				index = 0xa5
			}
		}
		zigimg.Rgb24Pixels {
			for index in 0 .. pixels.data.len {
				pixels.data[index] = zigimg.Rgb24{
					r: 0xa5
					g: 0x5a
					b: 0x81
				}
			}
		}
		zigimg.Rgba32Pixels {
			for index in 0 .. pixels.data.len {
				pixels.data[index] = zigimg.Rgba32{
					r: 0xa5
					g: 0x5a
					b: 0x81
					a: 0x7e
				}
			}
		}
		else {
			panic('unexpected test format')
		}
	}
}

fn boundary(name string, fixed_path string) {
	mut stream := zigimg.ReadStream.init_memory([u8(0), 0x7e, 0x7e])
	mut codec := zigimg.TIFF{
		bitmap: zigimg.TiffBitmapDescriptor{
			image_width:       1
			image_height:      1
			rows_per_strip:    1
			strip_offsets:     [u32(1)]
			strip_byte_counts: [u32(1)]
		}
	}
	codec.bitmap.bits_per_sample.resize(1)
	codec.bitmap.bits_per_sample.data[0] = 8
	mut pixels := zigimg.PixelStorage.init(.grayscale8, 2) or { panic(err) }
	match name {
		'sum_overflow' {
			codec.bitmap.image_height = 0xffffffff
		}
		'sum_underflow' {
			codec.bitmap.image_height = 0
			codec.bitmap.rows_per_strip = 0
		}
		'zero_rows' {
			codec.bitmap.rows_per_strip = 0
		}
		'empty_height' {
			codec.bitmap.image_height = 0
		}
		'missing_counts' {
			codec.bitmap.strip_byte_counts = none
		}
		'missing_offsets' {
			codec.bitmap.strip_offsets = none
		}
		'short_counts' {
			codec.bitmap.image_height = 2
			codec.bitmap.strip_offsets = [u32(1), 2]
		}
		'short_offsets' {
			codec.bitmap.image_height = 2
			codec.bitmap.strip_byte_counts = [u32(1), 1]
		}
		'zero_pixels' {
			pixels = zigimg.PixelStorage.init(.grayscale8, 0) or { panic(err) }
		}
		'rgb_stride' {
			pixels = zigimg.PixelStorage.init(.rgb24, 1) or { panic(err) }
		}
		'palette_bounds' {
			pixels = zigimg.PixelStorage.init(.indexed8, 1) or { panic(err) }
			pixels.resize_palette(1)
			codec.bitmap.color_map.resize(2)
		}
		'packbits_overrun' {
			codec.bitmap.compression = .packbits
			codec.bitmap.strip_byte_counts = [u32(2)]
			stream = zigimg.ReadStream.init_memory([u8(0), 0x82, 0x7e])
		}
		'ccitt_run' {
			stream = zigimg.ReadStream.init_memory([u8(0x98)])
			mut destination := []u8{len: 1}
			codec.uncompress_ccitt(mut stream, mut destination, 1, 1) or {
				eprintln('UNEXPECTED: CCITT error ${err.msg()}')
				return
			}
			eprintln('UNEXPECTED: CCITT returned')
			return
		}
		'fixed_window' {
			stream = zigimg.ReadStream.init_memory(os.read_bytes(fixed_path) or { panic(err) })
			mut destination := []u8{len: 70000}
			codec.uncompress_deflate(mut stream, mut destination) or {
				eprintln('UNEXPECTED: fixed block error ${err.msg()}')
				return
			}
			eprintln('UNEXPECTED: fixed block returned')
			return
		}
		'pixel_overflow' {
			mut bytes := 'II'.bytes()
			bytes << [u8(0), 0, 8, 0, 0, 0, 3, 0]
			for tag in [u16(256), 257, 258] {
				bytes << [u8(tag), u8(tag >> 8), u8(if tag == 258 { 3 } else { 4 }), 0, 1, 0, 0,
					0]
				bytes << if tag == 258 { [u8(8), 0, 0, 0] } else { [u8(0), 0, 1, 0] }
			}
			bytes << [u8(0), 0, 0, 0]
			stream = zigimg.ReadStream.init_memory(bytes)
			_ = codec.read(mut stream) or {
				eprintln('UNEXPECTED: read error ${err.msg()}')
				return
			}
			eprintln('UNEXPECTED: read returned')
			return
		}
		else {
			panic('unknown boundary')
		}
	}

	codec.read_strips(mut stream, mut pixels) or {
		eprintln('UNEXPECTED: strip error ${err.msg()}')
		return
	}
	eprintln('UNEXPECTED: strip operation returned')
}

fn main() {
	if os.args[1] == '--bounds' {
		boundary(os.args[2], os.args[3])
		return
	}
	formats := [zigimg.PixelFormat.grayscale1, .grayscale8, .indexed8, .rgb24, .rgba32, .grayscale16]
	for line in os.read_lines(os.args[1]) or { panic(err) } {
		fields := line.split('|')
		operation := fields[0].int()
		bytes := hex.decode(fields[12]) or { panic(err) }
		mut stream := zigimg.ReadStream.init_memory(bytes)
		mut codec := zigimg.TIFF{
			endianess: .big
			header:    zigimg.TiffHeader{
				version:    123
				idf_offset: 77
			}
		}
		mut status := 'ok'
		mut hash := u64(0)
		if operation <= 2 {
			mut destination := []u8{len: fields[8].int(), init: 0xa5}
			match operation {
				0 {
					codec.uncompress_deflate(mut stream, mut destination) or { status = err.msg() }
				}
				1 {
					codec.uncompress_lzw(mut stream, mut destination) or { status = err.msg() }
				}
				2 {
					codec.bitmap.photometric_interpretation = fields[3].u16()
					codec.uncompress_ccitt(mut stream, mut destination, usize(fields[5].u64()),
						usize(fields[6].u64())) or { status = err.msg() }
				}
				else {}
			}

			mut accumulator := [u64(14695981039346656037)]
			for byte in destination {
				mix(mut accumulator, byte)
			}
			hash = accumulator[0]
		} else if operation == 3 {
			codec.bitmap.compression = unsafe { zigimg.TiffCompressionType(fields[2].u16()) }
			codec.bitmap.photometric_interpretation = fields[3].u16()
			codec.bitmap.predictor = fields[4].u16()
			codec.bitmap.image_width = fields[5].u32()
			codec.bitmap.image_height = fields[6].u32()
			codec.bitmap.rows_per_strip = fields[7].u32()
			bits := numbers(fields[9])
			codec.bitmap.samples_per_pixel = u16(bits.len)
			codec.bitmap.bits_per_sample.resize(usize(bits.len))
			for index, value in bits {
				codec.bitmap.bits_per_sample.data[index] = u16(value)
			}
			codec.bitmap.strip_offsets = numbers(fields[10])
			codec.bitmap.strip_byte_counts = numbers(fields[11])
			codec.bitmap.color_map.resize(256)
			for index in 0 .. 256 {
				codec.bitmap.color_map.data[index] = zigimg.Rgba32{
					r: u8(index)
					g: u8(index * 7)
					b: u8(index * 13)
					a: 255
				}
			}
			mut pixels := zigimg.PixelStorage.init(formats[fields[1].int()], usize(fields[8].u64())) or {
				panic(err)
			}
			initialize(mut pixels)
			codec.read_strips(mut stream, mut pixels) or { status = err.msg() }
			hash = pixel_hash(pixels)
		} else if operation == 4 {
			pixels := codec.read(mut stream) or {
				status = err.msg()
				zigimg.PixelStorage(zigimg.InvalidPixels{})
			}
			if status == 'ok' { hash = pixel_hash(pixels) }
		} else {
			image := zigimg.TIFF.read_image(mut stream) or {
				status = err.msg()
				zigimg.ImageUnmanaged{}
			}
			if status == 'ok' {
				hash = pixel_hash(image.pixels)
				codec.bitmap.image_width = u32(image.width)
				codec.bitmap.image_height = u32(image.height)
			}
		}
		println('${status}|${stream.get_pos()}|${codec.width()}|${codec.height()}|${codec.header.version}|${codec.header.idf_offset}|${int(codec.endianess)}|${hash:016x}')
	}
}
