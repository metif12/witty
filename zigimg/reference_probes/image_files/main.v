module main

import os
import zigimg

__global (
	observed_path   string
	observed_disk   string
	observed_file   os.File
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
	image := observed_image
	mut out := '${observed_file.tell() or { panic(err) }}|${observed_buffer.hex()}|${image.width}:${image.height}:${u32(image.pixel_format())}:${image.pixels.len()}:${image.raw_bytes().hex()}|'
	if pal := image.pixels.get_palette() {
		out += unsafe { (&u8(pal.data)).vbytes(pal.len * 4).hex() }
	} else {
		out += '-'
	}
	return out + '|' + (os.read_bytes(observed_disk) or { panic(err) }).hex()
}

fn observe() {
	if observed_path == '' { return }
	os.write_file(observed_path, snapshot()) or { eprintln('OBSERVER ERROR: ${err}') }
}

fn record(line string, path string) string {
	f := line.split('|')
	format := unsafe { zigimg.Format(f[0].u8()) }
	profile := f[1].int()
	variant := f[2].int()
	cap := f[3].int()
	route := f[4].int()
	shape := f[5].int()
	mut image := source(profile) or { panic(err) }
	if shape == 1 { image.width = 0 }
	if shape == 2 { image.height = 0 }
	if shape == 3 && image.pixels.len() > 0 { image.pixels = image.pixels.slice(0, 1) }
	managed := image.to_managed()
	observed_image = &image
	mut buffer := []u8{len: cap, init: 165}
	observed_buffer = unsafe { buffer }
	os.write_file_array(path, []u8{len: 256, init: 165}) or { panic(err) }
	mut file := os.open_file(path, 'r+') or { panic(err) }
	defer { file.close() }
	file.seek(256, .start) or { panic(err) }
	observed_file = file
	observed_disk = path
	opts := options(format, variant)
	mut out := snapshot() + '~'
	for _ in 0 .. f[6].int() {
		mut status := 'ok'
		match route {
			0 { image.write_to_file(file, mut buffer, opts) or { status = err.msg() } }
			1 { managed.write_to_file(file, mut buffer, opts) or { status = err.msg() } }
			2 { image.write_to_file_path(path, mut buffer, opts) or { status = err.msg() } }
			else { managed.write_to_file_path(path, mut buffer, opts) or { status = err.msg() } }
		}

		out += '${status}|${snapshot()}~'
	}
	return out
}

fn main() {
	if os.args[1] == '--trap' {
		observed_path = os.args[2]
		at_exit(observe) or { panic(err) }
		result := record(os.args[3], observed_path + '.bin')
		observed_path = ''
		println(result)
		return
	}
	for line in (os.read_file(os.args[1]) or { panic(err) }).split_into_lines() {
		if line != '' { println(record(line, os.args[1] + '.v.bin')) }
	}
}
