module main

import os
import encoding.hex
import zigimg

#flag -I @DIR
#include "fixture_shims.h"

fn C.witty_image_fifo_open(&char) int
fn C.witty_image_fifo_remove(&char) int
fn C.witty_image_fifo_kind(&char) int
fn C.witty_image_fifo_refs(int) int
fn C.witty_image_fifo_close(int) int
fn C.witty_image_fifo_valid(int) int
fn C.witty_image_fifo_write(int, &u8, uint) int
fn C.witty_image_fifo_read(int, &u8, uint) int

__global (
	observed_path   string
	observed_fd     int
	observed_fifo   string
	observed_image  = &zigimg.ImageUnmanaged(unsafe { nil })
	observed_buffer []u8
	observed_wire   []u8
	observed_drain  int
)
fn options(format zigimg.Format, variant int) zigimg.EncoderOptions {
	return match format {
		.bmp {
			zigimg.BmpEncoderOptions{}
		}
		.farbfeld {
			zigimg.FarbfeldEncoderOptions{}
		}
		.gif {
			zigimg.GifEncoderOptions{}
		}
		.iff {
			zigimg.IffEncoderOptions{}
		}
		.jpeg {
			zigimg.JpegEncoderOptions{}
		}
		.pam {
			zigimg.PamEncoderOptions{
				comments: if variant == 1 { ['one', 'two'] } else { []string{} }
			}
		}
		.pbm {
			zigimg.PbmEncoderOptions{
				binary: variant != 1
			}
		}
		.pcx {
			zigimg.PcxEncoderOptions{}
		}
		.pgm {
			zigimg.PgmEncoderOptions{
				binary: variant != 1
			}
		}
		.png {
			zigimg.PngEncoderOptions{
				interlaced: variant == 1
			}
		}
		.ppm {
			zigimg.PpmEncoderOptions{
				binary: variant != 1
			}
		}
		.qoi {
			zigimg.QoiEncoderOptions{
				colorspace: if variant == 1 { .linear } else { .srgb }
			}
		}
		.ras {
			zigimg.RasEncoderOptions{}
		}
		.sgi {
			zigimg.SgiEncoderOptions{}
		}
		.tga {
			zigimg.TgaEncoderOptions{
				rle_compressed:      variant != 1
				top_to_bottom_image: variant == 0
				image_id:            if variant == 2 { [u8(7), 8, 9] } else { []u8{} }
				author_name:         if variant == 2 { 'author' } else { '' }
			}
		}
		.tiff {
			zigimg.TiffEncoderOptions{}
		}
		.xbm {
			zigimg.XbmEncoderOptions{}
		}
	}
}

fn source(profile int) !zigimg.ImageUnmanaged {
	formats := [zigimg.PixelFormat.grayscale8, .rgb24, .rgba32, .bgr24, .bgra32, .rgba64, .indexed8,
		.invalid]
	mut image := zigimg.ImageUnmanaged.create(4, 2, formats[profile])!
	mut bytes := image.raw_bytes()
	for i in 0 .. bytes.len {
		bytes[i] = u8(i * 37 + profile * 19)
	}
	if profile == 6 {
		image.pixels.resize_palette(4)
		match mut image.pixels {
			zigimg.IndexedStorage8 {
				for i in 0 .. 8 {
					image.pixels.indices[i] = u8(i % 4)
				}
				for i in 0 .. 4 {
					image.pixels.palette[i] = zigimg.Rgba32{
						r: u8(i * 71)
						g: u8(i * 53)
						b: u8(i * 37)
						a: 255
					}
				}
			}
			else {
				assert false
			}
		}
	}
	return image
}

fn snapshot(drain bool) string {
	if drain {
		mut bytes := []u8{len: 4096}
		for {
			n := C.witty_image_fifo_read(observed_fd, bytes.data, uint(bytes.len))
			if n <= 0 {
				observed_drain = int(n)
				break
			}
			observed_wire << bytes[..int(n)]
		}
	}
	image := observed_image
	mut out := '${C.witty_image_fifo_kind(observed_fifo.str)}:${C.witty_image_fifo_valid(observed_fd)}:${C.witty_image_fifo_refs(observed_fd)}:${observed_drain}|${observed_buffer.hex()}|${image.width}:${image.height}:${u32(image.pixel_format())}:${image.pixels.len()}:${image.raw_bytes().hex()}|'
	if pal := image.pixels.get_palette() {
		out += unsafe { (&u8(pal.data)).vbytes(pal.len * 4).hex() }
	} else {
		out += '-'
	}
	return out + '|' + observed_wire.hex()
}

fn observe() {
	if observed_path == '' { return }
	state := snapshot(true)
	os.write_file(observed_path, state) or { eprintln('OBSERVER ERROR: ${err}') }
	C.witty_image_fifo_remove(observed_fifo.str)
}

fn detect(path string, mut buffer []u8, managed bool) !zigimg.Format {
	if managed { return zigimg.Image.detect_format_from_file_path(path, mut buffer) }
	return zigimg.ImageUnmanaged.detect_format_from_file_path(path, mut buffer)
}

fn decode(path string, mut buffer []u8, managed bool) !zigimg.ImageUnmanaged {
	if managed {
		image := zigimg.Image.from_file_path(path, mut buffer)!
		return image.to_unmanaged()
	}
	return zigimg.ImageUnmanaged.from_file_path(path, mut buffer)
}

fn record(line string) string {
	f := line.split('|')
	op := f[0].int()
	mut image := source(f[2].int()) or { panic(err) }
	if f[6] == '1' { image.width = 0 }
	if f[6] == '2' { image.height = 0 }
	if f[6] == '3' && image.pixels.len() > 0 { image.pixels = image.pixels.slice(0, 1) }
	managed := image.to_managed()
	observed_image = &image
	mut buffer := []u8{len: f[4].int(), init: 165}
	observed_buffer = unsafe { buffer }
	observed_fd = C.witty_image_fifo_open(observed_fifo.str)
	if observed_fd < 0 { panic('FIFO setup failed') }
	defer {
		C.witty_image_fifo_close(observed_fd)
		C.witty_image_fifo_remove(observed_fifo.str)
	}
	seed := hex.decode(f[8]) or { panic(err) }
	if seed.len > 0 && C.witty_image_fifo_write(observed_fd, seed.data, uint(seed.len)) != seed.len {
		panic('FIFO seed failed')
	}
	observed_wire = []u8{}
	observed_drain = -3
	opts := options(unsafe { zigimg.Format(f[1].u8()) }, f[3].int())
	mut out := snapshot(false) + '~'
	for _ in 0 .. f[7].int() {
		mut status := 'ok'
		mut result := '-'
		if op == 0 {
			if f[5] == '1' {
				managed.write_to_file_path(observed_fifo, mut buffer, opts) or {
					status = err.msg()
				}
			} else {
				image.write_to_file_path(observed_fifo, mut buffer, opts) or { status = err.msg() }
			}
		} else if op == 1 {
			value := detect(observed_fifo, mut buffer, f[5] == '1') or {
				status = err.msg()
				unsafe { zigimg.Format(0) }
			}
			if status == 'ok' { result = '${value}' }
		} else {
			mut value := decode(observed_fifo, mut buffer, f[5] == '1') or {
				status = err.msg()
				zigimg.ImageUnmanaged{}
			}
			if status == 'ok' {
				result = '${value.width}:${value.height}:${u32(value.pixel_format())}'
				value.deinit()
			}
		}
		out += '${status}:${result}|${snapshot(true)}~'
	}
	return out
}

fn main() {
	if os.args[1] == '--trap' {
		observed_path = os.args[2]
		observed_fifo = observed_path + '.fifo'
		at_exit(observe) or { panic(err) }
		result := record(os.args[3])
		observed_path = ''
		println(result)
		return
	}
	observed_fifo = os.args[1] + '.fifo'
	for line in (os.read_file(os.args[1]) or { panic(err) }).split_into_lines() {
		if line != '' { println(record(line)) }
	}
}
