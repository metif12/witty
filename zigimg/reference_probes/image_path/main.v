module main

import os
import encoding.hex
import zigimg

#flag -I @DIR
#include "fixture_shims.h"

fn C.witty_image_path_permissions() int
fn C.witty_image_path_setup(&char, int, &u8, uint) int
fn C.witty_image_path_count() int
fn C.witty_image_path_valid(int) int
fn C.witty_image_path_mode(int) int
fn C.witty_image_path_bytes(int, &u8, uint) int
fn C.witty_image_path_cleanup(&char, int) int

__global (
	observed_path   string
	observed_root   string
	observed_fd     int
	observed_count  int
	observed_image  = &zigimg.ImageUnmanaged(unsafe { nil })
	observed_buffer []u8
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

fn snapshot() string {
	mut bytes := []u8{len: 4096}
	n := C.witty_image_path_bytes(observed_fd, bytes.data, uint(bytes.len))
	if n < 0 { panic('path observer read failed') }
	image := observed_image
	mut out := '${C.witty_image_path_valid(observed_fd)}:${C.witty_image_path_count() - observed_count}:${C.witty_image_path_mode(observed_fd)}|${observed_buffer.hex()}|${image.width}:${image.height}:${u32(image.pixel_format())}:${image.pixels.len()}:${image.raw_bytes().hex()}|'
	if pal := image.pixels.get_palette() {
		out += unsafe { (&u8(pal.data)).vbytes(pal.len * 4).hex() }
	} else {
		out += '-'
	}
	return out + '|' + bytes[..int(n)].hex()
}

fn observe() {
	if observed_path == '' { return }
	state := snapshot()
	os.write_file(observed_path, state) or { eprintln('OBSERVER ERROR: ${err}') }
	if C.witty_image_path_cleanup(observed_root.str, observed_fd) != 0 {
		eprintln('OBSERVER CLEANUP ERROR')
	}
}

fn path_for_kind(kind int) string {
	return match kind {
		0 { observed_root + '/missing/child' }
		1 { observed_root + '/seed/child' }
		2 { observed_root + '/dir' }
		3 { observed_root + '/seed' }
		4 { observed_root + '/denied/child' }
		5 { observed_root + '/loop' }
		6 { observed_root + '/dangling' }
		7 { observed_root + '/' + 'a'.repeat(256) }
		8 { 'a'.repeat(1024) }
		9 { '' }
		10 { observed_root + '/missing' }
		11 { observed_root + '/seed' + '\x00junk' }
		12 { '\x00' }
		13 { observed_root + '/missing/child' + '\x00junk' }
		14 { 'a'.repeat(1024) + '\x00' }
		15 { 'a'.repeat(1023) }
		else { panic('invalid path kind') }
	}
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
	if f[7] == '1' { image.width = 0 }
	if f[7] == '2' { image.height = 0 }
	if f[7] == '3' && image.pixels.len() > 0 { image.pixels = image.pixels.slice(0, 1) }
	managed := image.to_managed()
	observed_image = &image
	mut buffer := []u8{len: f[3].int(), init: 165}
	observed_buffer = unsafe { buffer }
	kind := f[5].int()
	seed := hex.decode('6661726266656c64000000010000000100130038005dffff') or { panic(err) }
	observed_fd = C.witty_image_path_setup(observed_root.str, kind, seed.data, uint(seed.len))
	if observed_fd < 0 { panic('path setup failed') }
	observed_count = C.witty_image_path_count()
	defer {
		if C.witty_image_path_cleanup(observed_root.str, observed_fd) != 0 {
			panic('path cleanup failed')
		}
	}
	target := path_for_kind(kind)
	opts := options(unsafe { zigimg.Format(f[1].u8()) }, 0)
	mut out := snapshot() + '~'
	for _ in 0 .. f[6].int() {
		mut status := 'ok'
		mut result := '-'
		if op == 0 {
			if f[4] == '1' {
				managed.write_to_file_path(target, mut buffer, opts) or { status = err.msg() }
			} else {
				image.write_to_file_path(target, mut buffer, opts) or { status = err.msg() }
			}
		} else if op == 1 {
			value := detect(target, mut buffer, f[4] == '1') or {
				status = err.msg()
				unsafe { zigimg.Format(0) }
			}
			if status == 'ok' { result = '${value}' }
		} else {
			mut value := decode(target, mut buffer, f[4] == '1') or {
				status = err.msg()
				zigimg.ImageUnmanaged{}
			}
			if status == 'ok' {
				result = '${value.width}:${value.height}:${u32(value.pixel_format())}'
				value.deinit()
			}
		}
		out += '${status}:${result}|${snapshot()}~'
	}
	return out
}

fn main() {
	if C.witty_image_path_permissions() != 1 {
		panic('path proof requires an unprivileged POSIX user')
	}
	if os.args[1] == '--trap' {
		observed_path = os.args[2]
		observed_root = observed_path + '.case'
		at_exit(observe) or { panic(err) }
		result := record(os.args[3])
		observed_path = ''
		println(result)
		return
	}
	observed_root = os.args[1] + '.case'
	for line in (os.read_file(os.args[1]) or { panic(err) }).split_into_lines() {
		if line != '' { println(record(line)) }
	}
}
