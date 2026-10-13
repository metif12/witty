module main

import os
import zigimg as p

__global (
	observed_path   string
	observed_codec  = &p.BMP(unsafe { nil })
	observed_reader = &p.ReadStream(unsafe { nil })
	observed_writer = &p.WriteStream(unsafe { nil })
	observed_output []u8
)

fn record_bytes[T](header T) string {
	return unsafe { (&u8(&header)).vbytes(int(sizeof(T))).hex() }
}

fn info(value p.BitmapInfoHeader) string {
	return match value {
		p.BitmapInfoHeaderWindows31 { '40|' + record_bytes(value) }
		p.BitmapInfoHeaderV4 { '108|' + record_bytes(value) }
		p.BitmapInfoHeaderV5 { '124|' + record_bytes(value) }
	}
}

fn codec_state(codec p.BMP) string {
	return record_bytes(codec.file_header) + '|' + info(codec.info_header)
}

fn observe() {
	mut out := ''
	if observed_reader != unsafe { nil } { out += '${observed_reader.get_pos()}|' }
	if observed_writer != unsafe { nil } {
		out += '${observed_writer.get_pos()}|${observed_output.hex()}|'
	}
	if observed_codec != unsafe { nil } { out += codec_state(observed_codec) }
	os.write_file(observed_path, out) or { eprintln('OBSERVER ERROR: ${err}') }
}

fn make_codec(kind int, width i32, height i32) p.BMP {
	header := match kind {
		40 {
			p.BitmapInfoHeader(p.BitmapInfoHeaderWindows31{
				header_size:           40
				width:                 width
				height:                height
				bit_count:             99
				compression_method:    .png
				horizontal_resolution: 17
			})
		}
		108 {
			p.BitmapInfoHeader(p.BitmapInfoHeaderV4{
				header_size:           108
				width:                 width
				height:                height
				bit_count:             99
				compression_method:    .png
				horizontal_resolution: 17
			})
		}
		else {
			p.BitmapInfoHeader(p.BitmapInfoHeaderV5{
				header_size:           124
				width:                 width
				height:                height
				bit_count:             99
				compression_method:    .png
				horizontal_resolution: 17
			})
		}
	}

	return p.BMP{
		file_header: p.BitmapFileHeader{
			magic_header: [u8(`X`), `Y`]!
			size:         1
			reserved:     0x12345678
			pixel_offset: 9000
		}
		info_header: header
	}
}

fn pixels(format p.PixelFormat, count int, seed int) p.PixelStorage {
	mut result := p.PixelStorage.init(format, usize(count)) or { panic(err) }
	mut raw := result.as_bytes()
	for i in 0 .. raw.len {
		raw[i] = u8(if seed == 0 {
			1
		} else if seed == 1 {
			i * 17
		} else {
			192
		})
	}
	return result
}

fn write_case(kind int, format p.PixelFormat, width int, height int, seed int, capacity int) {
	data := pixels(format, width * height, seed)
	mut buf := []u8{len: 1024, init: 165}
	mut section := unsafe { buf[..capacity] }
	mut writer := p.WriteStream.init_memory(mut section)
	mut status := 'ok'
	if kind == 0 {
		p.BMP.write_image(mut writer, p.ImageUnmanaged{
			width:  usize(width)
			height: usize(height)
			pixels: data
		}, p.BmpEncoderOptions{}) or { status = err.msg() }
	} else {
		codec := make_codec(kind, i32(width), i32(height))
		codec.write(mut writer, data) or { status = err.msg() }
	}
	println('W|${kind}|${u32(format)}|${width}|${height}|${seed}|${capacity}|${status}|${writer.get_pos()}|${buf[..capacity].hex()}')
}

fn main() {
	if os.args.len > 1 {
		if os.args[2] != '-' {
			observed_path = os.args[2]
			at_exit(observe) or { panic(err) }
		}
		if os.args[1].starts_with('--read') {
			bytes := os.read_bytes(os.args[3]) or { panic(err) }
			mut reader := p.ReadStream.init_memory(bytes)
			observed_reader = &reader
			if os.args[1] == '--read-image' {
				image := p.BMP.read_image(mut reader) or {
					if observed_path != '' {
						eprintln('UNEXPECTED: recoverable ${err.msg()}')
						return
					}
					println('${err.msg()}|${reader.get_pos()}')
					return
				}
				if observed_path == '' {
					println('ok|${reader.get_pos()}|${image.width}|${image.height}|${image.raw_bytes().hex()}')
					return
				}
			} else {
				mut codec := make_codec(124, 7, 9)
				observed_codec = &codec
				result := codec.read(mut reader) or {
					if observed_path != '' {
						eprintln('UNEXPECTED: recoverable ${err.msg()}')
						return
					}
					println('${err.msg()}|${reader.get_pos()}|${codec_state(codec)}')
					return
				}
				if observed_path == '' {
					data := if codec.width() >= 0 && codec.height() >= 0 {
						result.as_bytes().hex()
					} else {
						'-'
					}
					println('ok|${reader.get_pos()}|${codec_state(codec)}|${result.len()}|${data}')
					return
				}
			}
		} else {
			capacity := os.args[3].int()
			mut output := []u8{len: 1024, init: 165}
			mut section := unsafe { output[..capacity] }
			mut writer := p.WriteStream.init_memory(mut section)
			observed_writer = &writer
			observed_output = unsafe { output[..capacity] }
			format := unsafe { p.PixelFormat(os.args[6].u32()) }
			data := pixels(format, os.args[7].int(), 1)
			mut status := 'ok'
			if os.args[1] == '--image' {
				p.BMP.write_image(mut writer, p.ImageUnmanaged{
					width:  usize(os.args[4].u64())
					height: usize(os.args[5].u64())
					pixels: data
				}, p.BmpEncoderOptions{}) or { status = err.msg() }
			} else {
				mut codec := make_codec(os.args[8].int(), i32(os.args[4].i64()),
					i32(os.args[5].i64()))
				observed_codec = &codec
				codec.write(mut writer, data) or { status = err.msg() }
			}
			if observed_path == '' {
				println('${status}|${writer.get_pos()}|${output[..capacity].hex()}')
				return
			}
		}
		eprintln('UNEXPECTED: operation returned')
		return
	}
	println('H|${sizeof(p.BitmapFileHeader)}|${sizeof(p.BitmapInfoHeaderWindows31)}|${sizeof(p.BitmapInfoHeaderV4)}|${sizeof(p.BitmapInfoHeaderV5)}|${record_bytes(p.BitmapFileHeader{})}|${record_bytes(p.BitmapInfoHeaderWindows31{})}|${record_bytes(p.BitmapInfoHeaderV4{})}|${record_bytes(p.BitmapInfoHeaderV5{})}')
	for kind in [40, 108, 124] {
		for width in [i32(-2147483648), -3, 0, 1, 2147483647] {
			for height in [i32(-2147483648), -2, 0, 2, 2147483647] {
				codec := make_codec(kind, width, height)
				println('D|${kind}|${codec.width()}|${codec.height()}')
			}
		}
		for bits in [u16(0), 1, 8, 16, 24, 32, 64, 65535] {
			for compression in [p.BmpCompressionMethod.none, .rle8, .rle4, .bitfields, .jpg, .png,
				.alpha_bit_fields, .cmyk, .cmyk_rle8, .cmyk_rle4] {
				mut codec := make_codec(kind, 1, 1)
				match mut codec.info_header {
					p.BitmapInfoHeaderWindows31 {
						codec.info_header.bit_count = bits
						codec.info_header.compression_method = compression
					}
					p.BitmapInfoHeaderV4 {
						codec.info_header.bit_count = bits
						codec.info_header.compression_method = compression
					}
					p.BitmapInfoHeaderV5 {
						codec.info_header.bit_count = bits
						codec.info_header.compression_method = compression
					}
				}

				mut status := 'ok'
				format := codec.pixel_format() or {
					status = err.msg()
					p.PixelFormat.invalid
				}
				println('P|${kind}|${bits}|${u32(compression)}|${status}|${u32(format)}')
			}
		}
	}
	for kind in [0, 40, 108, 124] {
		for format in [p.PixelFormat.bgr24, .bgra32, .grayscale8] {
			for width in [0, 1, 2, 3, 8, 17] {
				for height in 0 .. 4 {
					for seed in 0 .. 3 {
						for capacity in [0, 1, 13, 14, 121, 122, 123, 137, 138, 139, 256, 1024] {
							write_case(kind, format, width, height, seed, capacity)
						}
					}
				}
			}
		}
	}
}
