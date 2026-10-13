module main

import os
import zigimg as p

__global (
	observed_path   string
	observed_codec  = &p.SGI(unsafe { nil })
	observed_reader = &p.ReadStream(unsafe { nil })
	observed_buffer []u8
)
fn header_bytes(header p.SgiHeader) string {
	return unsafe { (&u8(&header)).vbytes(510).hex() }
}

fn state() string {
	pal := observed_codec.palette.data
	return '${observed_reader.get_pos()}|${header_bytes(observed_codec.header)}|' +
		unsafe { (&u8(pal.data)).vbytes(pal.len * 4).hex() } + '|${observed_buffer.hex()}'
}

fn observe() {
	os.write_file(observed_path, state()) or { eprintln('OBSERVER ERROR: ${err}') }
}

fn header(width u16, height u16, channels u16, bpc u8) p.SgiHeader {
	mut name := [80]u8{}
	name[0] = `X`
	mut dummy := [404]u8{}
	dummy[403] = 77
	return p.SgiHeader{
		compression:       .rle
		bytes_per_channel: bpc
		dimension:         .single_channel
		x_size:            width
		y_size:            height
		z_size:            channels
		pix_min:           123
		pix_max:           456
		dummy1:            789
		image_name:        name
		pixel_format:      .normal
		dummy2:            dummy
	}
}

fn main() {
	if os.args.len > 1 {
		if os.args[2] != '-' {
			observed_path = os.args[2]
			at_exit(observe) or { panic(err) }
		}
		read := os.args[1] == '--read'
		mut codec := p.SGI{
			header: if read {
				header(7, 9, 3, 1)
			} else {
				header(os.args[4].u16(), os.args[5].u16(), os.args[6].u16(), os.args[3].u8())
			}
		}
		codec.palette.resize(4)
		for i in 0 .. 4 {
			codec.palette.data[i] = p.Rgba32{
				r: u8(i * 31)
				g: u8(i * 71)
				b: u8(i * 47)
				a: 99
			}
		}
		data := os.read_bytes(os.args[if read { 3 } else { 8 }]) or { panic(err) }
		mut reader := p.ReadStream.init_memory(data)
		observed_codec = &codec
		observed_reader = &reader
		if read {
			result := codec.read(mut reader) or {
				println('${err.msg()}|' + state())
				return
			}
			{
				println('ok|' + state() +
					'|${u32(result.pixel_format())}|${result.len()}|${result.as_bytes().hex()}')
				return
			}
		} else {
			mut buffer := []u8{len: os.args[7].int(), init: 165}
			observed_buffer = unsafe { buffer[..] }
			codec.uncompress_bitmap(mut reader, mut buffer) or {
				println('${err.msg()}|' + state())
				return
			}
			{
				println('ok|' + state())
				return
			}
		}
		eprintln('UNEXPECTED: operation returned')
		return
	}
	h := header(7, 9, 3, 1)
	println('H|${sizeof(p.SgiHeader)}|${header_bytes(h)}')
	for width in [u16(0), 1, 255, 32768, 65535] {
		for height in [u16(0), 1, 255, 32768, 65535] {
			codec := p.SGI{
				header: header(width, height, 3, 1)
			}
			println('D|${codec.width()}|${codec.height()}')
		}
	}
	for format in [p.SgiPixelFormat.normal, .dithered, .need_cmap, .cmap_only] {
		for dimension in [p.SgiDimensions.scanline, .single_channel, .multi_channel] {
			for bpc in [u8(0), 1, 2, 3, 255] {
				for channels in [u16(0), 1, 3, 4, 256, 65535] {
					mut codec := p.SGI{
						header: header(1, 1, channels, bpc)
					}
					codec.header.pixel_format = format
					codec.header.dimension = dimension
					mut status := 'ok'
					result := codec.pixel_format() or {
						status = err.msg()
						p.PixelFormat.invalid
					}
					println('P|${u32(format)}|${u16(dimension)}|${bpc}|${channels}|${status}|${u32(result)}')
				}
			}
		}
	}
}
