module zigimg

import math
import os

const converter_test_formats = [PixelFormat.invalid, .indexed1, .indexed2, .indexed4, .indexed8,
	.indexed16, .grayscale1, .grayscale2, .grayscale4, .grayscale8, .grayscale16, .grayscale8_alpha,
	.grayscale16_alpha, .rgb332, .rgb555, .rgb565, .rgb24, .rgba32, .bgr555, .bgr24, .bgra32, .rgb48,
	.rgba64, .float32]

fn converter_test_mix(mut hash ConverterTestHash, value u64) {
	hash.value = (hash.value ^ value) * 1099511628211
}

struct ConverterTestHash {
mut:
	value u64
}

fn converter_test_pixels(format PixelFormat, count int, seed int, ordinal int) !PixelStorage {
	mut result := PixelStorage.init(format, usize(count))!
	mut bytes := result.as_bytes()
	for i in 0 .. bytes.len {
		bytes[i] = u8(i * 73 + ordinal * 19 + seed * 29)
	}
	if format == .invalid { return result }
	if format.is_indexed() {
		capacity := int(u32(1) << format.info().bits_per_channel())
		active := if capacity < 11 { capacity } else { 11 }
		result.resize_palette(usize(active))
		mut palette := result.get_palette() or { panic('missing palette') }
		for i in 0 .. active {
			palette[i] = Rgba32{
				r: u8(i * 31 + seed * 17)
				g: u8(i * 71 + seed * 29)
				b: u8(i * 113 + seed * 41)
				a: u8(i * 47 + seed * 53)
			}
		}
		for i in 0 .. count {
			converter_put_word(mut bytes, i * int(format.pixel_stride()),
				int(format.pixel_stride()), u32((i * 7 + seed) % active))
		}
	} else if format == .float32 {
		match mut result {
			Colorf32Pixels {
				for i in 0 .. count {
					result.data[i] = Colorf32{
						r: f32((i * 31 + seed * 17) % 257) / 256
						g: f32((i * 71 + seed * 29) % 257) / 256
						b: f32((i * 113 + seed * 41) % 257) / 256
						a: f32((i * 47 + seed * 53) % 257) / 256
					}
				}
			}
			else {
				panic('invalid float storage')
			}
		}
	} else if format in [.grayscale1, .grayscale2, .grayscale4] {
		for i in 0 .. count {
			bytes[i] &= u8(converter_max(format.info().bits_per_channel()))
		}
	} else if format in [.rgb555, .bgr555] {
		for i in 0 .. count {
			bytes[i * 2 + 1] &= 0x7f
		}
	}
	return result
}

fn test_converter_native_matrix() {
	mut hash := ConverterTestHash{
		value: 14695981039346656037
	}
	mut cases := 0
	for ordinal, source_format in converter_test_formats {
		for destination_format in converter_test_formats {
			for count in [0, 1, 3, 4, 5, 9, 17, 64] {
				for seed in 0 .. 4 {
					source := converter_test_pixels(source_format, count, seed, ordinal)!
					converter_test_mix(mut hash, u64(source_format))
					converter_test_mix(mut hash, u64(destination_format))
					converter_test_mix(mut hash, u64(count))
					converter_test_mix(mut hash, u64(seed))
					cases++
					if os.getenv('WITTY_CONVERTER_TRACE') != '' {
						eprintln('${ordinal} ${destination_format} ${count} ${seed} ${hash.value:016x}')
					}
					if source_format == .bgr555
						&& destination_format in [.rgb555, .rgb565, .rgb24, .rgba32, .bgr24, .bgra32, .rgb48, .rgba64, .float32] {
						converter_test_mix(mut hash, 3)
						continue
					}
					if count == 0
						&& ((source_format in [.rgba32, .bgra32] && destination_format == .float32)
						|| (source_format == .float32 && destination_format in [.rgba32, .bgra32])) {
						converter_test_mix(mut hash, 4)
						continue
					}
					destination := PixelFormatConverter.convert(&source, destination_format) or {
						assert err.msg() in ['NoConversionNeeded', 'NoConversionAvailable']
						converter_test_mix(mut hash, if err.msg() == 'NoConversionNeeded' {
							u64(1)
						} else {
							u64(2)
						})
						continue
					}
					converter_test_mix(mut hash, 0)
					converter_test_mix(mut hash, u64(destination.len()))
					for i, byte in destination.as_bytes() {
						defined := if destination_format in [.rgb555, .bgr555] && i % 2 == 1 {
							byte & 0x7f
						} else {
							byte
						}
						converter_test_mix(mut hash, u64(defined))
					}
					if palette := destination.get_palette() {
						converter_test_mix(mut hash, u64(palette.len))
						defined := if source_format.is_indexed() && source_format != .invalid
							&& source_format.info().bits_per_channel() < destination_format.info().bits_per_channel() {
							original := source.get_palette() or { panic('missing palette') }
							original.len
						} else {
							palette.len
						}
						for entry in palette[..defined] {
							converter_test_mix(mut hash, u64(entry.r))
							converter_test_mix(mut hash, u64(entry.g))
							converter_test_mix(mut hash, u64(entry.b))
							converter_test_mix(mut hash, u64(entry.a))
						}
					}
				}
			}
		}
	}
	assert cases == 18432
	assert hash.value == 0xe9de0fd7efd93e19
}

fn test_converter_source_alpha_and_simd_tail() {
	source := PixelStorage(Rgba32Pixels{
		data: [Rgba32{ r: 240, g: 128, b: 64, a: 128 }]
	})
	rgb := PixelFormatConverter.convert(&source, .rgb24)!
	assert rgb.as_bytes() == [u8(120), 64, 32]
	small := PixelFormatConverter.convert(&source, .rgb332)!
	assert small.as_bytes() == [u8(7 | 4 << 3 | 1 << 6)]
	floats := PixelStorage(Colorf32Pixels{
		data: []Colorf32{len: 5, init: Colorf32{
			r: 0.5
			g: 0.25
			b: 0.75
			a: 0.5
		}}
	})
	rounded := PixelFormatConverter.convert(&floats, .rgba32)!
	assert rounded.as_bytes() == [u8(127), 63, 191, 127, 127, 63, 191, 127, 127, 63, 191, 127,
		127, 63, 191, 127, 128, 64, 191, 128]
	borderline := PixelStorage(Colorf32Pixels{
		data: []Colorf32{len: 5, init: Colorf32{
			r: -0.001
			g: 1.003
			b: 0.5
		}}
	})
	fractional := PixelFormatConverter.convert(&borderline, .rgba32)!
	assert fractional.as_bytes()[..4] == [u8(0), 255, 127, 255]
	assert fractional.as_bytes()[16..] == [u8(0), 255, 128, 255]
	nans := PixelStorage(Colorf32Pixels{
		data: []Colorf32{len: 5, init: Colorf32{
			r: f32(math.nan())
		}}
	})
	nan_result := PixelFormatConverter.convert(&nans, .rgba32)!
	assert nan_result.as_bytes()[..4] == [u8(0), 0, 0, 255]
	assert nan_result.as_bytes()[16..] == [u8(255), 0, 0, 255]
	gray_source := converter_test_pixels(.rgba64, 3, 0, 22)!
	gray := PixelFormatConverter.convert(&gray_source, .grayscale8_alpha)!
	assert gray.as_bytes() == [u8(140), 161, 158, 233, 47, 50]
	palette_source := converter_test_pixels(.indexed8, 0, 0, 4)!
	indexed := PixelFormatConverter.convert(&palette_source, .indexed4)!
	palette := indexed.get_palette() or { panic('missing palette') }
	assert palette.len == 16
	for entry in palette[11..] {
		assert entry == Rgba32{}
	}
	owner := PixelStorage.init(.float32, 1)!
	empty_view := owner.slice(0, 0)
	for format in [PixelFormat.rgba32, .bgra32] {
		empty_result := PixelFormatConverter.convert(&empty_view, format)!
		assert empty_result.len() == 0
	}
}

fn test_converter_native_precision() {
	mut hash := ConverterTestHash{
		value: 14695981039346656037
	}
	mut pixels_checked := 0
	for format in [PixelFormat.rgb332, .rgb555, .bgr555, .rgb565, .rgba32, .rgba64,
		.grayscale16_alpha, .float32] {
		count := if format == .rgb332 {
			256
		} else if format in [.rgb555, .bgr555] {
			32768
		} else {
			65536
		}
		source := PixelStorage.init(format, usize(count))!
		mut bytes := source.as_bytes()
		for i in 0 .. count {
			if format in [.rgb332, .rgb555, .bgr555, .rgb565] {
				converter_put_word(mut bytes, i * int(format.pixel_stride()),
					int(format.pixel_stride()), u32(i))
			} else if format == .rgba32 {
				bytes[i * 4] = u8(i)
				bytes[i * 4 + 1] = u8(i * 13)
				bytes[i * 4 + 2] = u8(i * 29)
				bytes[i * 4 + 3] = u8(i >> 8)
			} else if format == .rgba64 {
				for channel, value in [i, i * 13, i * 29, i * 17 + 11] {
					converter_put_word(mut bytes, i * 8 + channel * 2, 2, u32(u16(value)))
				}
			} else if format == .grayscale16_alpha {
				converter_put_word(mut bytes, i * 4, 2, u32(i))
				converter_put_word(mut bytes, i * 4 + 2, 2, u32(u16(i * 17 + 11)))
			} else {
				for channel, value in [i, (i * 13) % 65536, (i * 29) % 65536, (i * 17 + 11) % 65536] {
					unsafe {
						*(&f32(&bytes[i * 16 + channel * 4])) = f32(value) / 65535
					}
				}
			}
		}
		for destination_format in converter_test_formats {
			if destination_format.is_indexed() || destination_format == format
				|| (format == .bgr555
				&& destination_format in [.rgb555, .rgb565, .rgb24, .rgba32, .bgr24, .bgra32, .rgb48, .rgba64, .float32]) {
				continue
			}
			converter_test_mix(mut hash, u64(format))
			converter_test_mix(mut hash, u64(destination_format))
			destination := PixelFormatConverter.convert(&source, destination_format) or {
				assert err.msg() == 'NoConversionAvailable'
				converter_test_mix(mut hash, 2)
				continue
			}
			converter_test_mix(mut hash, 0)
			pixels_checked += count
			for i, byte in destination.as_bytes() {
				converter_test_mix(mut hash, u64(if destination_format in [.rgb555, .bgr555]
					&& i % 2 == 1 {
					byte & 0x7f
				} else {
					byte
				}))
			}
		}
	}
	assert pixels_checked == 6066176
	assert hash.value == 0x9014fb50e8722857
}

fn test_converter_image_replacement_and_same_format() {
	mut image := ImageUnmanaged{
		width:     1
		height:    1
		pixels:    Rgba32Pixels{
			data: [Rgba32{ r: 240, g: 128, b: 64, a: 128 }]
		}
		animation: Animation{
			frames: [
				AnimationFrame{
					pixels:   Rgb24Pixels{
						data: [Rgb24{ r: 7, g: 8, b: 9 }]
					}
					duration: 0.25
				},
			]
		}
	}
	before := image.raw_bytes()
	image.convert(.rgba32)!
	assert image.raw_bytes().data == before.data
	image.convert(.rgb24)!
	assert image.raw_bytes() == [u8(120), 64, 32]
	assert image.animation.frames[0].pixels.as_bytes() == [u8(7), 8, 9]
	assert image.animation.frames[0].duration == 0.25
	image.convert_no_free(.rgba64)!
	assert image.pixel_format() == .rgba64
	PixelFormatConverter.convert(&image.pixels, .rgba64) or {
		assert err.msg() == 'NoConversionNeeded'
	}
	PixelFormatConverter.convert(&image.pixels, .grayscale16) or {
		assert err.msg() == 'NoConversionAvailable'
	}
	before_failure := image.raw_bytes()
	image.convert(.grayscale16) or { assert err.msg() == 'NoConversionAvailable' }
	assert image.raw_bytes().data == before_failure.data
	assert image.pixel_format() == .rgba64
}

fn test_converter_checks_dispatch_before_float_alignment() {
	bytes := []u8{len: 32}
	misaligned := if usize(bytes.data) % 4 == 0 { 1 } else { int(4 - usize(bytes.data) % 4) + 1 }
	source := PixelStorage.init_raw_pixels(bytes[misaligned..misaligned + 16], .float32)!
	for destination in [PixelFormat.float32, .grayscale16] {
		PixelFormatConverter.convert(&source, destination) or {
			assert err.msg() == if destination == .float32 {
				'NoConversionNeeded'
			} else {
				'NoConversionAvailable'
			}
			continue
		}
		assert false
	}
	mut image := ImageUnmanaged{
		width:  7
		height: 3
		pixels: source
	}
	image.convert(.float32)!
	assert image.pixel_format() == .float32
	assert image.width == 7 && image.height == 3
}
