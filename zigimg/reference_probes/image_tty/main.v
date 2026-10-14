module main

import os
import encoding.hex
import zigimg

#flag -I @DIR
#include "fixture_shims.h"

fn C.witty_image_tty_keeper_fd() int
fn C.witty_image_tty_positional_error(int) int
fn C.witty_image_tty_setup() int
fn C.witty_image_tty_path() &char
fn C.witty_image_tty_cleanup() int
fn C.witty_image_tty_state() int
fn C.witty_image_tty_session() int
fn C.witty_image_tty_refs() int
fn C.witty_image_tty_raw(int, int) int
fn C.witty_image_tty_raw_close(int) int
fn C.witty_image_tty_seed(&u8, usize) isize
fn C.witty_image_tty_read(int, &u8, usize) isize

__global (
	observed_path        string
	observed_drain_input int
	observed_tty         string
	observed_image       = &zigimg.ImageUnmanaged(unsafe { nil })
	observed_buffer      []u8
	observed_wire        []u8
	observed_input       []u8
	observed_drain       int
	observed_output      []u8
	observed_pos         u64
	observed_pending     []u8
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
			n := C.witty_image_tty_read(0, bytes.data, usize(bytes.len))
			if n <= 0 {
				observed_drain = int(n)
				break
			}
			observed_wire << bytes[..int(n)]
		}
		for {
			n := C.witty_image_tty_read(1, bytes.data, usize(bytes.len))
			if n <= 0 {
				observed_drain_input = int(n)
				break
			}
			observed_input << bytes[..int(n)]
		}
	}
	image := observed_image
	mut out := '${C.witty_image_tty_state()}:${C.witty_image_tty_session()}:${C.witty_image_tty_refs()}:${observed_drain}:${observed_drain_input}|${observed_buffer.hex()}|${image.width}:${image.height}:${u32(image.pixel_format())}:${image.pixels.len()}:${image.raw_bytes().hex()}|'
	if pal := image.pixels.get_palette() {
		out += unsafe { (&u8(pal.data)).vbytes(pal.len * 4).hex() }
	} else {
		out += '-'
	}
	return out + '|' + observed_wire.hex() + '|' + observed_input.hex() + '|' +
		observed_output.hex() + '|${observed_pos}:${observed_pending.hex()}'
}

fn observe() {
	if observed_path == '' { return }
	state := snapshot(true)
	os.write_file(observed_path, state) or { eprintln('OBSERVER ERROR: ${err}') }
	C.witty_image_tty_cleanup()
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
	if C.witty_image_tty_setup() != 0 { panic('PTY setup failed') }
	observed_tty = unsafe { cstring_to_vstring(C.witty_image_tty_path()) }
	defer {
		if C.witty_image_tty_cleanup() != 0 { panic('PTY cleanup failed') }
	}
	seed := hex.decode(f[8]) or { panic(err) }
	if seed.len > 0 && C.witty_image_tty_seed(seed.data, usize(seed.len)) != seed.len {
		panic('PTY seed failed')
	}
	observed_wire = []u8{}
	observed_input = []u8{}
	observed_drain = -3
	observed_drain_input = -3
	observed_output = []u8{len: if op > 2 { f[1].int() } else { 0 }, init: 182}
	observed_pos = 0
	observed_pending = []u8{}
	opts := options(unsafe { zigimg.Format(f[1].u8()) }, f[3].int())
	mut out := snapshot(false) + '~'
	for _ in 0 .. f[7].int() {
		mut status := 'ok'
		mut result := '-'
		if op == 0 {
			if f[5] == '1' {
				managed.write_to_file_path(observed_tty, mut buffer, opts) or { status = err.msg() }
			} else {
				image.write_to_file_path(observed_tty, mut buffer, opts) or { status = err.msg() }
			}
		} else if op == 1 {
			value := detect(observed_tty, mut buffer, f[5] == '1') or {
				status = err.msg()
				unsafe { zigimg.Format(0) }
			}
			if status == 'ok' { result = '${value}' }
		} else if op == 2 {
			mut value := decode(observed_tty, mut buffer, f[5] == '1') or {
				status = err.msg()
				zigimg.ImageUnmanaged{}
			}
			if status == 'ok' {
				result = '${value.width}:${value.height}:${u32(value.pixel_format())}'
				value.deinit()
			}
		}
		if op > 2 {
			file := os.File{
				fd: C.witty_image_tty_keeper_fd()
			}
			mut stream := zigimg.ReadStream.init_file(file, mut buffer)
			if op == 3 {
				stream.read_slice_all(mut observed_output) or { status = err.msg() }
			} else {
				value := stream.take(observed_output.len) or {
					status = err.msg()
					[]u8{}
				}
				if status == 'ok' {
					for i, byte in value {
						observed_output[i] = byte
					}
				}
			}
			observed_pos = stream.get_pos()
			observed_pending = []u8{}
			// buffered bytes are read through the adapter without advancing it.
			if stream.buffered_len() > 0 {
				observed_pending = stream.peek(stream.buffered_len()) or { panic(err) }
				observed_pending = observed_pending.clone()
			}
		}
		out += '${status}:${result}|${snapshot(true)}~'
	}
	return out
}

fn main() {
	if os.args[1] == '--calibrate' {
		writing := os.args[2].int()
		noctty := os.args[3].int()
		if C.witty_image_tty_setup() != 0 { panic('Calibration setup failed') }
		fd := C.witty_image_tty_raw(writing, noctty)
		if fd < 0 { panic('Calibration open failed') }
		opened := C.witty_image_tty_state()
		if C.witty_image_tty_raw_close(fd) != 0 { panic('Calibration close failed') }
		closed := C.witty_image_tty_state()
		position_error := C.witty_image_tty_positional_error(writing)
		if C.witty_image_tty_cleanup() != 0 { panic('Calibration cleanup failed') }
		println('${writing}:${noctty}|${opened}:${closed}:${C.witty_image_tty_session()}:${position_error}')
		return
	}
	if os.args[1] == '--trap' {
		observed_path = os.args[2]
		at_exit(observe) or { panic(err) }
		result := record(os.args[3])
		observed_path = ''
		println(result)
		return
	}
	println(record(os.args[1]))
}
