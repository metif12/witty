module zigimg

// Pinned TIFF codec state. Metadata and strips are split across source files.
pub struct TIFF {
pub mut:
	endianess TiffEndian
	// Source defaults these records to undefined; V retains zero initialization.
	header TiffHeader = TiffHeader{
		version:    0
		idf_offset: 0
	}
	ifd    TiffIFD = TiffIFD{
		tags_map:    TiffTagMap{}
		read_stream: unsafe { nil }
	}
	bitmap TiffBitmapDescriptor
}

pub fn (codec TIFF) width() usize {
	return codec.bitmap.image_width
}

pub fn (codec TIFF) height() usize {
	return codec.bitmap.image_height
}

fn tiff_compression(value u16) TiffCompressionType {
	for kind in [TiffCompressionType.uncompressed, .ccitt_rle, .gp_3_fax, .gp_4_fax, .lzw, .jpeg,
		.deflate, .uncompressed_old, .packbits, .pixar_deflate] {
		if u16(kind) == value { return kind }
	}
	panic('invalid enum value')
}

fn tiff_resolution_unit(value u16) TiffResolutionUnit {
	if value !in [u16(1), 2, 3] { panic('invalid enum value') }
	return unsafe { TiffResolutionUnit(value) }
}

pub fn (mut codec TIFF) decode_bitmap(mut stream ReadStream) ! {
	endianess := codec.endianess
	mut bitmap := &codec.bitmap
	bitmap.bits_per_sample.resize(1)
	bitmap.bits_per_sample.data[0] = 1
	mut iterator := codec.ifd.tags_map.key_iterator()
	for {
		key := iterator.next() or { break }
		tag := codec.ifd.tags_map.get(*key) or { panic('missing TIFF tag') }
		match *key {
			.image_width {
				bitmap.image_width = tag.to_long_or_short(endianess)
			}
			.image_height {
				bitmap.image_height = tag.to_long_or_short(endianess)
			}
			.compression {
				bitmap.compression = tiff_compression(tag.to_short(endianess))
			}
			.color_map {
				palette := tag.read_tag_data(mut stream, endianess)!
				bits := bitmap.bits_per_sample.data[0]
				if bits >= 16 { panic('attempt to unwrap error: Overflow') }
				colors := u16(1) << bits
				bitmap.color_map.resize(usize(colors))
				for index in 0 .. int(colors) {
					bitmap.color_map.data[index] = Rgba32{
						r: u8(palette[index] / 256)
						g: u8(palette[index + int(colors)] / 256)
						b: u8(palette[index + int(colors) * 2] / 256)
						a: 255
					}
				}
			}
			.strip_byte_counts {
				bitmap.strip_byte_counts = tag.read_tag_data(mut stream, endianess)!
			}
			.strip_offsets {
				bitmap.strip_offsets = tag.read_tag_data(mut stream, endianess)!
			}
			.rows_per_strip {
				bitmap.rows_per_strip = tag.to_long_or_short(endianess)
			}
			.photometric_interpretation {
				bitmap.photometric_interpretation = tag.to_short(endianess)
			}
			.samples_per_pixel {
				bitmap.samples_per_pixel = tag.to_short(endianess)
			}
			.resolution_unit {
				bitmap.resolution_unit = tiff_resolution_unit(tag.to_short(endianess))
			}
			.new_subfile_type {
				bitmap.new_subfile_type = tag.to_long()
			}
			.bits_per_sample {
				bitmap.bits_per_sample.resize(usize(tag.data_count))
				match tag.data_count {
					1 {
						bitmap.bits_per_sample.data[0] = tag.to_short(endianess)
					}
					3, 4 {
						bits := tag.read_tag_data(mut stream, endianess)!
						for index in 0 .. int(tag.data_count) {
							bitmap.bits_per_sample.data[index] = u16(bits[index])
						}
					}
					else {
						return error('Unsupported')
					}
				}
			}
			.extra_samples {
				bitmap.extra_samples.resize(usize(tag.data_count))
				if tag.data_count != 1 { return error('Unsupported') }
				bitmap.extra_samples.data[0] = tag.to_short(endianess)
			}
			.x_resolution {
				bitmap.x_resolution = tag.read_rational(mut stream, endianess)!
			}
			.y_resolution {
				bitmap.y_resolution = tag.read_rational(mut stream, endianess)!
			}
			.planar_configuration {
				bitmap.planar_configuration = tag.to_short(endianess)
			}
			.predictor {
				bitmap.predictor = tag.to_short(endianess)
			}
			else {}
		}
	}
}

pub fn (codec TIFF) cal_row_byte_size() !usize {
	mut bits := usize(0)
	for index in 0 .. int(codec.bitmap.samples_per_pixel) {
		tiff_check_index(usize(index), codec.bitmap.bits_per_sample.data.len)
		value := usize(codec.bitmap.bits_per_sample.data[index])
		if bits > ~usize(0) - value { panic('integer overflow') }
		bits += value
	}
	if bits == 1 { return usize(codec.bitmap.image_width >> 3) }
	if bits >= 8 {
		return image_pixel_count(usize(codec.bitmap.image_width), bits / 8)
	}
	return error('Unsupported')
}

pub fn TIFF.format_detect(mut stream ReadStream) !bool {
	magic := stream.peek(2) or { return false }
	return magic == tiff_little_endian_magic.bytes() || magic == tiff_big_endian_magic.bytes()
}

pub fn TIFF.write_image(mut stream WriteStream, image ImageUnmanaged, options EncoderOptions) ! {
	_ = stream
	_ = image
	_ = options
}
