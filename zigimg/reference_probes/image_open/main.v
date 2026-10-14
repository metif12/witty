module main

import os
import encoding.hex
import zigimg

#flag -I @DIR
#include "fixture_shims.h"

fn C.witty_image_open_setup(&char, int, &u8, usize) int
fn C.witty_image_open_cleanup(&char) int
fn C.witty_image_open_mask(int) int
fn C.witty_image_open_mode(&char) int
fn C.witty_image_open_kind(&char) int
fn C.witty_image_open_bytes(&char, &u8, usize) isize
fn C.witty_image_open_find(&char) int
fn C.witty_image_open_flag(int, int) int
fn C.witty_image_open_exec(&char, int) int
fn C.witty_image_open_child(int, u64, u64) int
fn C.witty_image_open_watch(&char, &char, &char) int

__global (
	observed_path   string
	observed_root   string
	observed_target string
	observed_exe    string
	observed_mask   int
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

fn disk(path string) string {
	mut bytes := []u8{len: 4096}
	n := C.witty_image_open_bytes(path.str, bytes.data, usize(bytes.len))
	return if n < 0 { '-' } else { bytes[..int(n)].hex() }
}

fn snapshot() string {
	fd := C.witty_image_open_find(observed_target.str)
	if fd == -2 { panic('multiple owned target descriptors') }
	flags := if fd < 0 {
		'-'
	} else {
		'${C.witty_image_open_flag(fd, 0)}:${C.witty_image_open_flag(fd, 1)}:${C.witty_image_open_flag(fd, 2)}:${C.witty_image_open_exec(observed_exe.str, fd)}'
	}
	image := observed_image
	mut out := '${flags}|${C.witty_image_open_kind(observed_target.str)}:${C.witty_image_open_mode(observed_target.str)}|${observed_buffer.hex()}|${image.width}:${image.height}:${u32(image.pixel_format())}:${image.pixels.len()}:${image.raw_bytes().hex()}|'
	if pal := image.pixels.get_palette() {
		out += unsafe { (&u8(pal.data)).vbytes(pal.len * 4).hex() }
	} else {
		out += '-'
	}
	return out + '|' + disk(observed_target) + '|' + disk(observed_root + '/seed')
}

fn observe() {
	if observed_path == '' { return }
	state := snapshot()
	C.witty_image_open_mask(observed_mask)
	os.write_file(observed_path, state) or { eprintln('OBSERVER ERROR: ${err}') }
	if C.witty_image_open_cleanup(observed_root.str) != 0 { eprintln('OBSERVER CLEANUP ERROR') }
}

fn record(line string, ready string) string {
	f := line.split('|')
	op := f[0].int()
	mut image := source(f[2].int()) or { panic(err) }
	if f[7] == '1' { image.width = 0 }
	observed_image = &image
	managed := image.to_managed()
	mut buffer := []u8{len: f[3].int(), init: 165}
	observed_buffer = unsafe { buffer }
	seed := if op == 0 { []u8{len: 256, init: 165} } else { '#define w 8\n'.bytes() }
	if C.witty_image_open_setup(observed_root.str, f[5].int(), seed.data, usize(seed.len)) != 0 {
		panic('open fixture setup failed')
	}
	observed_target = observed_root + '/target'
	observed_mask = C.witty_image_open_mask(f[6].int())
	defer {
		C.witty_image_open_mask(observed_mask)
		if C.witty_image_open_cleanup(observed_root.str) != 0 {
			panic('open fixture cleanup failed')
		}
	}
	if ready != ''
		&& C.witty_image_open_watch(observed_target.str, ready.str, observed_exe.str) != 0 {
		panic('open watcher failed')
	}
	opts := options(unsafe { zigimg.Format(f[1].u8()) }, 0)
	mut out := snapshot() + '~'
	for _ in 0 .. f[8].int() {
		mut status := 'ok'
		if op == 0 {
			if f[4] == '1' {
				managed.write_to_file_path(observed_target, mut buffer, opts) or {
					status = err.msg()
				}
			} else {
				image.write_to_file_path(observed_target, mut buffer, opts) or {
					status = err.msg()
				}
			}
		} else if op == 1 {
			if f[4] == '1' {
				zigimg.Image.detect_format_from_file_path(observed_target, mut buffer) or {
					status = err.msg()
				}
			} else {
				zigimg.ImageUnmanaged.detect_format_from_file_path(observed_target, mut buffer) or {
					status = err.msg()
				}
			}
		} else {
			if f[4] == '1' {
				zigimg.Image.from_file_path(observed_target, mut buffer) or { status = err.msg() }
			} else {
				zigimg.ImageUnmanaged.from_file_path(observed_target, mut buffer) or {
					status = err.msg()
				}
			}
		}
		out += '${status}|${snapshot()}~'
	}
	return out
}

fn main() {
	if os.args[1] == '--child' {
		exit(C.witty_image_open_child(os.args[2].int(), os.args[3].u64(), os.args[4].u64()))
	}
	observed_exe = os.args[0]
	if os.args[1] == '--trap' {
		observed_path = os.args[2]
		observed_root = observed_path + '.case'
		at_exit(observe) or { panic(err) }
		result := record(os.args[3], '')
		observed_path = ''
		println(result)
		return
	}
	if os.args[1] == '--loop' {
		observed_root = os.args[2] + '.case'
		println(record(os.args[3], os.args[2]))
		return
	}
	observed_root = os.args[1] + '.case'
	for line in (os.read_file(os.args[1]) or { panic(err) }).split_into_lines() {
		if line != '' { println(record(line, '')) }
	}
}
