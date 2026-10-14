module zigimg

import os

fn test_image_file_routes_restart_png_at_zero_and_keep_borrowed_descriptor() {
	path := os.join_path(os.temp_dir(), 'zigimg-image-api-png-${os.getpid()}.bin')
	defer { os.rm(path) or {} }
	mut raw := []u8{len: 24}
	for i in 0 .. raw.len {
		raw[i] = u8(i * 37 + 19)
	}
	image := ImageUnmanaged.from_raw_pixels(4, 2, raw, .rgb24)!
	managed := image.to_managed()
	for route in 0 .. 4 {
		os.write_file_array(path, []u8{len: 256, init: 165})!
		mut file := os.open_file(path, 'r+')!
		file.seek(256, .start)!
		mut buffer := []u8{len: 8, init: 165}
		for _ in 0 .. 2 {
			match route {
				0 { image.write_to_file(file, mut buffer, PngEncoderOptions{})! }
				1 { managed.write_to_file(file, mut buffer, PngEncoderOptions{})! }
				2 { image.write_to_file_path(path, mut buffer, PngEncoderOptions{})! }
				else { managed.write_to_file_path(path, mut buffer, PngEncoderOptions{})! }
			}

			assert file.tell()! == 256
			assert buffer == png_magic_header[..]
			disk := os.read_bytes(path)!
			assert disk[..8] == png_magic_header[..]
			if route < 2 {
				assert disk.len == 256 && disk[8..] == []u8{len: 248, init: 165}
			} else {
				assert disk.len == 8
			}
		}
		file.close()
	}
	assert image.raw_bytes() == raw
}

fn test_image_path_truncation_precedes_noop_and_unsupported_encoding() {
	path := os.join_path(os.temp_dir(), 'zigimg-image-api-truncate-${os.getpid()}.bin')
	defer { os.rm(path) or {} }
	mut raw := []u8{len: 24}
	for i in 0 .. raw.len {
		raw[i] = u8(i * 37 + 57)
	}
	image := ImageUnmanaged.from_raw_pixels(4, 2, raw, .bgr24)!
	managed := image.to_managed()
	for route in 0 .. 4 {
		for option in [EncoderOptions(GifEncoderOptions{}), PngEncoderOptions{}] {
			os.write_file_array(path, []u8{len: 256, init: 165})!
			mut file := os.open_file(path, 'r+')!
			file.seek(256, .start)!
			mut buffer := []u8{len: 8, init: 165}
			for _ in 0 .. 2 {
				mut status := 'ok'
				match route {
					0 {
						image.write_to_file(file, mut buffer, option) or { status = err.msg() }
					}
					1 {
						managed.write_to_file(file, mut buffer, option) or { status = err.msg() }
					}
					2 {
						image.write_to_file_path(path, mut buffer, option) or { status = err.msg() }
					}
					else {
						managed.write_to_file_path(path, mut buffer, option) or {
							status = err.msg()
						}
					}
				}

				assert status == if option.format() == .png {
					'Unsupported'
				} else {
					'ok'
				}
				assert file.tell()! == 256 && buffer == []u8{len: 8, init: 165}
				assert os.read_bytes(path)! == if route < 2 {
					[]u8{len: 256, init: 165}
				} else {
					[]u8{}
				}
			}
			file.close()
		}
	}
	assert image.raw_bytes() == raw
}

fn test_managed_image_defaults_creation_and_raw_copy() {
	mut empty := Image.init()
	assert empty.width == 0 && empty.height == 0
	assert empty.pixel_format() == .invalid && empty.image_byte_size() == 0
	assert !empty.is_animation() && empty.animation.loop_count == -1
	empty.deinit()
	formats := [PixelFormat.invalid, .indexed1, .indexed2, .indexed4, .indexed8, .indexed16,
		.grayscale1, .grayscale2, .grayscale4, .grayscale8, .grayscale16, .grayscale8_alpha,
		.grayscale16_alpha, .rgb332, .rgb555, .rgb565, .rgb24, .rgba32, .bgr555, .bgr24, .bgra32,
		.rgb48, .rgba64, .float32]
	for format in formats {
		mut image := Image.create(3, 2, format)!
		assert image.width == 3 && image.height == 2
		assert image.pixel_format() == format
		assert image.pixels.len() == if format == .invalid {
			usize(0)
		} else {
			usize(6)
		}
		assert image.image_byte_size() == usize(6 * format.pixel_stride())
		assert image.row_byte_size() == usize(3 * format.pixel_stride())
		image.deinit()
	}
	mut bytes := [u8(10), 20, 30, 40, 50, 60]
	image := Image.from_raw_pixels(9, 2, bytes, .rgb24)!
	assert image.width == 9 && image.height == 2 && image.pixels.len() == 2
	assert image.row_byte_size() == 3
	assert image.raw_bytes().data != bytes.data
	bytes[0] = 100
	assert image.raw_bytes()[0] == 10
}

fn test_managed_views_copy_headers_and_share_backing_pixels_and_frames() {
	mut indexed := IndexedStorage8.init_palette_size(2, 2)
	indexed.indices[1] = 1
	mut image := Image{
		width:     2
		height:    1
		pixels:    indexed
		animation: Animation{
			frames:     [AnimationFrame{ pixels: indexed, duration: 0.5 }]
			loop_count: 3
		}
	}
	mut view := image.to_unmanaged()
	view.width = 10
	view.animation.loop_count = 8
	view.animation.frames[0].duration = 0.75
	view.pixels.resize_palette(3)
	match mut view.pixels {
		IndexedStorage8 {
			view.pixels.indices[0] = 1
			view.pixels.palette[1].r = 91
			view.pixels.indices = unsafe { view.pixels.indices[..1] }
		}
		else {
			assert false
		}
	}

	assert image.width == 2 && image.animation.loop_count == 3
	assert image.animation.frames[0].duration == 0.75
	assert image.pixels.len() == 2
	assert (image.pixels.get_palette() or { panic('palette') }).len == 2
	assert image.raw_bytes() == [u8(1), 1]
	assert (image.pixels.get_palette() or { panic('palette') })[1].r == 91
	mut managed := view.to_managed()
	managed.pixels.resize_palette(1)
	assert (view.pixels.get_palette() or { panic('palette') }).len == 3
	assert managed.raw_bytes().data == view.raw_bytes().data
}

fn test_managed_editor_conversion_and_live_iterator() {
	mut image := Image.from_raw_pixels(2, 2, [u8(10), 20, 30, 40], .grayscale8)!
	image.animation.frames << AnimationFrame{
		pixels:   image.pixels
		duration: 0.5
	}
	image.flip_vertically()!
	assert image.raw_bytes() == [u8(30), 40, 10, 20]
	cropped := image.crop(Box{ x: 1, width: 8, height: 2 })!
	assert cropped.width == 1 && cropped.height == 2
	assert cropped.raw_bytes() == [u8(40), 20] && !cropped.is_animation()
	assert cropped.raw_bytes().data != image.raw_bytes().data
	mut iterator := image.iterator()
	image.convert(.rgba32)!
	assert iterator.pixels == &image.pixels
	color := iterator.next() or { panic('pixel') }
	assert color == Colorf32{
		r: f32(30) / 255
		g: f32(30) / 255
		b: f32(30) / 255
		a: 1
	}
	assert image.animation.frames[0].pixels.pixel_format() == .grayscale8
	pointer := image.raw_bytes().data
	image.convert(.rgba32)!
	assert image.raw_bytes().data == pointer
	image.convert(.grayscale16) or {
		assert err.msg() == 'NoConversionAvailable'
		assert image.pixel_format() == .rgba32 && image.raw_bytes().data == pointer
		return
	}
	assert false
}

fn image_api_options(format Format, variant int) EncoderOptions {
	return match format {
		.bmp {
			BmpEncoderOptions{}
		}
		.farbfeld {
			FarbfeldEncoderOptions{}
		}
		.gif {
			GifEncoderOptions{}
		}
		.iff {
			IffEncoderOptions{}
		}
		.jpeg {
			JpegEncoderOptions{}
		}
		.pam {
			PamEncoderOptions{
				comments: if variant == 1 { ['one', 'two'] } else { []string{} }
			}
		}
		.pbm {
			PbmEncoderOptions{
				binary: variant != 1
			}
		}
		.pcx {
			PcxEncoderOptions{}
		}
		.pgm {
			PgmEncoderOptions{
				binary: variant != 1
			}
		}
		.png {
			PngEncoderOptions{
				interlaced: variant == 1
			}
		}
		.ppm {
			PpmEncoderOptions{
				binary: variant != 1
			}
		}
		.qoi {
			QoiEncoderOptions{
				colorspace: if variant == 1 { .linear } else { .srgb }
			}
		}
		.ras {
			RasEncoderOptions{}
		}
		.sgi {
			SgiEncoderOptions{}
		}
		.tga {
			TgaEncoderOptions{
				rle_compressed:      variant != 1
				top_to_bottom_image: variant == 0
				image_id:            if variant == 2 { [u8(7), 8, 9] } else { []u8{} }
				author_name:         if variant == 2 { 'author' } else { '' }
			}
		}
		.tiff {
			TiffEncoderOptions{}
		}
		.xbm {
			XbmEncoderOptions{}
		}
	}
}

fn image_api_source(profile int) !ImageUnmanaged {
	formats := [PixelFormat.grayscale8, .rgb24, .rgba32, .bgr24, .bgra32, .rgba64, .indexed8,
		.invalid]
	mut image := ImageUnmanaged.create(4, 2, formats[profile])!
	mut bytes := image.raw_bytes()
	for i in 0 .. bytes.len {
		bytes[i] = u8(i * 37 + profile * 19)
	}
	if profile == 6 {
		image.pixels.resize_palette(4)
		match mut image.pixels {
			IndexedStorage8 {
				for i in 0 .. 8 {
					image.pixels.indices[i] = u8(i % 4)
				}
				for i in 0 .. 4 {
					image.pixels.palette[i] = Rgba32{
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

fn image_api_mix(mut hash []u64, value u64) {
	hash[0] = (hash[0] ^ value) * u64(1099511628211)
}

fn test_image_encoder_dispatch_matches_locked_reference() {
	formats := [Format.bmp, .farbfeld, .gif, .iff, .jpeg, .pam, .pbm, .pcx, .pgm, .png, .ppm, .qoi,
		.ras, .sgi, .tga, .tiff, .xbm]
	mut hash := [u64(14695981039346656037)]
	mut cases := 0
	for format in formats {
		for profile in 0 .. 8 {
			image := image_api_source(profile)!
			for variant in 0 .. 3 {
				options := image_api_options(format, variant)
				assert options.format() == format
				for size in [0, 1, 7, 8, 15, 31, 127, 1024] {
					for managed in 0 .. 2 {
						mut buffer := []u8{len: size, init: 0xa5}
						image_api_mix(mut hash, u64(format))
						image_api_mix(mut hash, u64(profile))
						image_api_mix(mut hash, u64(variant))
						image_api_mix(mut hash, u64(size))
						image_api_mix(mut hash, u64(managed))
						mut failure := ''
						result := if managed == 1 {
							image.to_managed().write_to_memory(mut buffer, options) or {
								failure = err.msg()
								[]u8{}
							}
						} else {
							image.write_to_memory(mut buffer, options) or {
								failure = err.msg()
								[]u8{}
							}
						}
						code := match failure {
							'' { u64(0) }
							'Unsupported' { u64(1) }
							'WriteFailed' { u64(2) }
							'EndOfStream' { u64(3) }
							'InvalidData' { u64(4) }
							'UnfinishedBits' { u64(5) }
							else { panic(failure) }
						}

						image_api_mix(mut hash, code)
						if code == 0 {
							image_api_mix(mut hash, u64(result.len))
							assert result.data == buffer.data
						}
						for byte in buffer {
							image_api_mix(mut hash, byte)
						}
						cases++
						if os.getenv('WITTY_IMAGE_API_TRACE') != '' {
							eprintln('${format} ${profile} ${variant} ${size} ${managed} ${hash[0]:016x}')
						}
					}
				}
			}
		}
	}
	eprintln('image encoder matrix: ${cases} cases, ${hash[0]:016x}')
	assert cases == 6528
	assert hash[0] == u64(0xe49e6984a209c47b)
}

fn test_image_memory_write_borrows_output_and_preserves_partial_prefix() {
	image := Image.create(1, 1, .rgba32)!
	mut buffer := []u8{len: 12, init: 0xa5}
	mut result := image.write_to_memory(mut buffer, PngEncoderOptions{})!
	assert result == [u8(137), 80, 78, 71, 13, 10, 26, 10]
	result[0] = 7
	assert buffer[0] == 7 && buffer[8..] == [u8(0xa5), 0xa5, 0xa5, 0xa5]
	mut short := []u8{len: 5, init: 0xa5}
	image.write_to_memory(mut short, PngEncoderOptions{}) or {
		assert err.msg() == 'WriteFailed'
		assert short == [u8(137), 80, 78, 71, 13]
		return
	}
	assert false
}

fn test_source_noop_writers_accept_invalid_images_and_empty_buffer() {
	image := ImageUnmanaged{
		width:  ~usize(0)
		height: ~usize(0)
	}
	for format in [Format.gif, .iff, .jpeg, .ras, .sgi, .tiff, .xbm] {
		mut buffer := []u8{}
		result := image.write_to_memory(mut buffer, image_api_options(format, 0))!
		assert result.len == 0
	}
}
