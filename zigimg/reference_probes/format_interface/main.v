module main

import os
import zigimg

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

fn mix(mut hash []u64, value u64) {
	hash[0] = (hash[0] ^ value) * u64(1099511628211)
}

fn main() {
	if os.args.len > 1 {
		format := if os.args[1] == 'png' { zigimg.Format.png } else { zigimg.Format.tga }
		codec := format.format_interface()
		mut bytes := []u8{len: 1024}
		mut stream := zigimg.WriteStream.init_memory(mut bytes)
		codec.write_image(mut stream, source(7) or { panic(err) }, zigimg.QoiEncoderOptions{}) or {
			eprintln('UNEXPECTED ${err}')
			return
		}
		eprintln('UNEXPECTED')
		return
	}
	formats := [zigimg.Format.bmp, .farbfeld, .gif, .iff, .jpeg, .pam, .pbm, .pcx, .pgm, .png,
		.ppm, .qoi, .ras, .sgi, .tga, .tiff, .xbm]
	for format in formats {
		codec := format.format_interface()
		for option in formats {
			if format in [.png, .tga] && option != format { continue
			 }
			for profile in 0 .. 8 {
				image := source(profile) or { panic(err) }
				for variant in 0 .. 3 {
					for size in [0, 1, 7, 8, 15, 31, 127, 1024] {
						mut bytes := []u8{len: size, init: 0xa5}
						mut stream := zigimg.WriteStream.init_memory(mut bytes)
						mut status := 'ok'
						codec.write_image(mut stream, image, options(option, variant)) or {
							status = err.msg()
						}
						mut hash := [u64(14695981039346656037)]
						for byte in bytes {
							mix(mut hash, byte)
						}
						println('${format}:${option}:${profile}:${variant}:${size}|${status}:${stream.get_pos()}:${hash[0]:016x}')
					}
				}
			}
		}
	}
}
