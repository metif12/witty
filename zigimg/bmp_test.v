module zigimg

fn bmp_fixture(file BitmapFileHeader, info BitmapInfoHeader, data []u8) []u8 {
	mut bytes := bmp_file_header_bytes(file)
	match info {
		BitmapInfoHeaderWindows31 { bytes << bmp_info_header_bytes(info) }
		BitmapInfoHeaderV4 { bytes << bmp_info_header_bytes(info) }
		BitmapInfoHeaderV5 { bytes << bmp_info_header_bytes(info) }
	}

	bytes << data
	return bytes
}

fn test_bmp_header_layout_enum_words_and_detection() {
	assert sizeof(BitmapFileHeader) == 14
	assert sizeof(BitmapInfoHeaderWindows31) == bitmap_info_header_windows31_size
	assert sizeof(BitmapInfoHeaderV4) == bitmap_info_header_v4_size
	assert sizeof(BitmapInfoHeaderV5) == bitmap_info_header_v5_size
	assert sizeof(CieXyz) == 12 && sizeof(CieXyzTriple) == 36
	assert u32(BitmapColorSpace.srgb) == 0x73524742
	assert u32(BitmapColorSpace.windows_color_space) == 0x57696e20
	assert u32(BitmapColorSpace.profile_linked) == 0x4c494e4b
	assert u32(BitmapColorSpace.profile_embedded) == 0x4d424544
	assert u32(BitmapIntent.graphics) == 2
	for bytes in [[u8(`B`), `M`], [u8(`B`), `N`]] {
		mut reader := ReadStream.init_memory(bytes)
		assert BMP.format_detect(mut reader)! == (bytes[1] == `M`)
		assert reader.get_pos() == 0
	}
	for bytes in [[]u8{}, [u8(`B`)]] {
		mut reader := ReadStream.init_memory(bytes)
		BMP.format_detect(mut reader) or {
			assert err.msg() == 'EndOfStream' && reader.get_pos() == 0
			continue
		}
		assert false
	}
}

fn test_bmp_v4_metadata_bottom_up_rows_and_ignored_offset_padding_and_masks() {
	file := BitmapFileHeader{
		size:         1
		reserved:     0x12345678
		pixel_offset: 9000
	}
	info := BitmapInfoHeaderV4{
		header_size:           bitmap_info_header_v4_size
		width:                 1
		height:                2
		color_plane:           17
		bit_count:             24
		image_raw_size:        99
		horizontal_resolution: 11
		vertical_resolution:   12
		palette_size:          13
		important_colors:      14
		red_mask:              0x10203040
		green_mask:            0x50607080
		blue_mask:             0x90abcdef
		alpha_mask:            0xdeadbeef
		color_space:           .profile_linked
		cie_end_points:        CieXyzTriple{
			red:   CieXyz{
				x: 1
				y: 2
				z: 3
			}
			green: CieXyz{
				x: 4
				y: 5
				z: 6
			}
			blue:  CieXyz{
				x: 7
				y: 8
				z: 9
			}
		}
		gamma_red:             0x11223344
		gamma_green:           0x55667788
		gamma_blue:            0x99aabbcc
	}
	mut reader := ReadStream.init_memory(bmp_fixture(file, info, [u8(1), 2, 3, 0, 4, 5, 6, 0]))
	mut codec := BMP{}
	pixels := codec.read(mut reader)!
	assert codec.file_header == file && codec.info_header == BitmapInfoHeader(info)
	assert codec.width() == 1 && codec.height() == 2 && codec.pixel_format()! == .bgr24
	assert pixels.as_bytes() == [u8(0), 4, 5, 1, 2, 3]
	assert reader.get_pos() == 128 // The source consumes neither row padding nor the advertised offset.
	assert reader.take(2)! == [u8(6), 0]
}

fn test_bmp_v5_metadata_alpha_and_both_supported_format_header_combinations() {
	info := BitmapInfoHeaderV5{
		header_size:        bitmap_info_header_v5_size
		width:              2
		height:             2
		bit_count:          32
		compression_method: .bitfields
		color_plane:        0
		red_mask:           1
		green_mask:         2
		blue_mask:          3
		alpha_mask:         4
		color_space:        .windows_color_space
		gamma_red:          5
		gamma_green:        6
		gamma_blue:         7
		intent:             .absolute_colorimetric
		profile_data:       123
		profile_size:       456
		reserved:           789
	}
	mut data := []u8{len: 16}
	for i in 0 .. data.len {
		data[i] = u8(i)
	}
	mut reader := ReadStream.init_memory(bmp_fixture(BitmapFileHeader{}, info, data))
	mut codec := BMP{}
	pixels := codec.read(mut reader)!
	assert codec.info_header == BitmapInfoHeader(info)
	assert pixels.as_bytes() == [u8(8), 9, 10, 11, 12, 13, 14, 15, 0, 1, 2, 3, 4, 5, 6, 7]
	assert reader.get_pos() == 154
	for header in [
		BitmapInfoHeader(BitmapInfoHeaderV4{
			header_size:        108
			width:              1
			height:             1
			bit_count:          32
			compression_method: .bitfields
		}),
		BitmapInfoHeader(BitmapInfoHeaderV5{
			header_size: 124
			width:       1
			height:      1
			bit_count:   24
		}),
	] {
		reader = ReadStream.init_memory(bmp_fixture(BitmapFileHeader{}, header, [
			u8(1),
			2,
			3,
			4,
		]))
		image := BMP.read_image(mut reader)!
		assert image.width == 1 && image.height == 1
		assert image.raw_bytes() == if header is BitmapInfoHeaderV4 {
			[u8(1), 2, 3, 4]
		} else {
			[u8(1), 2, 3]
		}
	}
}

fn test_bmp_writers_emit_exact_source_headers_masks_and_unpadded_bottom_up_pixels() {
	mut output := []u8{len: 1000}
	mut writer := WriteStream.init_memory(mut output)
	image := ImageUnmanaged{
		width:  1
		height: 2
		pixels: Bgr24Pixels{
			data: [Bgr24{ b: 1, g: 2, r: 3 }, Bgr24{ b: 4, g: 5, r: 6 }]
		}
	}
	BMP.write_image(mut writer, image, BmpEncoderOptions{})!
	info := BitmapInfoHeaderV4{
		header_size:           108
		width:                 1
		height:                2
		color_plane:           1
		bit_count:             24
		image_raw_size:        6
		horizontal_resolution: 2835
		vertical_resolution:   2835
	}
	assert writer.buffered() == bmp_fixture(BitmapFileHeader{ size: 128, pixel_offset: 122 }, info, [
		u8(4),
		5,
		6,
		1,
		2,
		3,
	])
	assert writer.buffered()[..18] == [u8(`B`), `M`, 128, 0, 0, 0, 0, 0, 0, 0, 122, 0, 0, 0, 108,
		0, 0, 0]
	writer.seek_to(0)!
	alpha := ImageUnmanaged{
		width:  1
		height: 2
		pixels: Bgra32Pixels{
			data: [Bgra32{ b: 1, g: 2, r: 3, a: 4 }, Bgra32{ b: 5, g: 6, r: 7, a: 8 }]
		}
	}
	BMP.write_image(mut writer, alpha, BmpEncoderOptions{})!
	info5 := BitmapInfoHeaderV5{
		header_size:           124
		width:                 1
		height:                2
		color_plane:           1
		bit_count:             32
		compression_method:    .bitfields
		image_raw_size:        8
		horizontal_resolution: 2835
		vertical_resolution:   2835
		red_mask:              0x0000ff00
		green_mask:            0x00ff0000
		blue_mask:             0xff000000
		alpha_mask:            0x000000ff
	}
	assert writer.buffered() == bmp_fixture(BitmapFileHeader{ size: 146, pixel_offset: 138 },
		info5, [u8(5), 6, 7, 8, 1, 2, 3, 4])
	assert writer.buffered()[54..74] == [u8(0), 255, 0, 0, 0, 0, 255, 0, 0, 0, 0, 255, 255, 0,
		0, 0, 0x42, 0x47, 0x52, 0x73]
	mut reader := ReadStream.init_memory(writer.buffered())
	assert BMP.read_image(mut reader)!.raw_bytes() == alpha.raw_bytes()
	codec := BMP{
		file_header: BitmapFileHeader{
			magic_header: [u8(`X`), `Y`]!
			pixel_offset: 999
		}
		info_header: BitmapInfoHeaderV4{
			header_size:        7
			width:              1
			height:             1
			bit_count:          1
			compression_method: .rle4
		}
	}
	writer.seek_to(0)!
	codec.write(mut writer, Bgra32Pixels{
		data: [Bgra32{ b: 1, g: 2, r: 3, a: 4 }]
	})!
	assert writer.buffered() == bmp_fixture(codec.file_header, codec.info_header, [
		u8(1),
		2,
		3,
		4,
	])
}

fn test_bmp_zero_sized_images_and_signed_dimensions_follow_source_header_paths() {
	mut output := []u8{len: 200}
	for dims in [[usize(0), usize(0)], [usize(0), usize(1)], [usize(1), usize(0)]] {
		mut writer := WriteStream.init_memory(mut output)
		BMP.write_image(mut writer, ImageUnmanaged{
			width:  dims[0]
			height: dims[1]
			pixels: Bgr24Pixels{}
		}, BmpEncoderOptions{})!
		assert writer.get_pos() == 122
		mut reader := ReadStream.init_memory(writer.buffered())
		image := BMP.read_image(mut reader)!
		assert image.width == dims[0] && image.height == dims[1] && image.raw_bytes().len == 0
		assert reader.get_pos() == 122
	}
	mut reader := ReadStream.init_memory(bmp_fixture(BitmapFileHeader{}, BitmapInfoHeaderV4{
		header_size: 108
		width:       -1
		height:      -2
		bit_count:   24
	}, []))
	mut codec := BMP{}
	// The source allocates from the signed product, then reads no negative-height rows.
	// Its uninitialized pixels cannot be compared with V's zeroed storage.
	assert codec.read(mut reader)!.len() == 2
	assert codec.width() == -1 && codec.height() == -2 && reader.get_pos() == 122
}

fn test_bmp_reader_errors_retain_assignment_and_atomic_header_and_pixel_positions() {
	file := BitmapFileHeader{
		size:         123
		reserved:     456
		pixel_offset: 789
	}
	info := BitmapInfoHeaderV4{
		header_size: 108
		width:       1
		height:      2
		bit_count:   24
	}
	fixture := bmp_fixture(file, info, [u8(1), 2, 3, 4, 5, 6])
	for length in [0, 1, 13, 14, 15, 17, 121, 122, 123, 125, 126, 127] {
		mut reader := ReadStream.init_memory(fixture[..length])
		mut codec := BMP{
			file_header: BitmapFileHeader{
				size: 99
			}
			info_header: BitmapInfoHeaderV5{
				width: 777
			}
		}
		codec.read(mut reader) or {
			assert err.msg() == 'EndOfStream'
			position := if length < 14 {
				0
			} else if length < 122 {
				14
			} else if length < 125 {
				122
			} else {
				125
			}
			assert reader.get_pos() == u64(position)
			assert codec.file_header == if length < 14 {
				BitmapFileHeader{
					size: 99
				}
			} else {
				file
			}
			assert codec.info_header == if length < 122 {
				BitmapInfoHeader(BitmapInfoHeaderV5{
					width: 777
				})
			} else {
				BitmapInfoHeader(info)
			}
			continue
		}
		assert false
	}
	mut bad_file := file
	bad_file.magic_header[1] = `X`
	mut reader := ReadStream.init_memory(bmp_fixture(bad_file, info, []))
	mut codec := BMP{}
	codec.read(mut reader) or {
		assert err.msg() == 'InvalidData' && reader.get_pos() == 14 && codec.file_header == bad_file
		return
	}
	assert false
}

fn test_bmp_unsupported_headers_and_formats_leave_source_positions() {
	for size in [u32(0), 12, 64, 109] {
		mut bytes := bmp_file_header_bytes(BitmapFileHeader{})
		bmp_append_u32(mut bytes, size)
		mut reader := ReadStream.init_memory(bytes)
		mut codec := BMP{
			info_header: BitmapInfoHeaderV5{
				width: 777
			}
		}
		codec.read(mut reader) or {
			assert err.msg() == 'Unsupported' && reader.get_pos() == 14
			assert codec.info_header == BitmapInfoHeader(BitmapInfoHeaderV5{
				width: 777
			})
			continue
		}
		assert false
	}
	for header in [
		BitmapInfoHeader(BitmapInfoHeaderWindows31{
			header_size: 40
			width:       1
			height:      1
			bit_count:   24
		}),
		BitmapInfoHeader(BitmapInfoHeaderV4{
			header_size: 108
			bit_count:   32
		}),
		BitmapInfoHeader(BitmapInfoHeaderV5{
			header_size:        124
			bit_count:          24
			compression_method: .bitfields
		}),
		BitmapInfoHeader(BitmapInfoHeaderV5{
			header_size: 124
			bit_count:   8
		}),
	] {
		bytes := bmp_fixture(BitmapFileHeader{}, header, [])
		mut reader := ReadStream.init_memory(bytes)
		mut codec := BMP{}
		codec.read(mut reader) or {
			assert err.msg() == 'Unsupported' && reader.get_pos() == u64(bytes.len)
			assert codec.info_header == header
			continue
		}
		assert false
	}
	for bits in [u32(1), 4, 8, 16, 24, 32, 48] {
		for compression in [BmpCompressionMethod.none, .rle8, .rle4, .bitfields, .jpg, .png,
			.alpha_bit_fields, .cmyk, .cmyk_rle8, .cmyk_rle4] {
			format := bmp_find_pixel_format(bits, compression) or {
				assert err.msg() == 'Unsupported'
				assert !(bits == 24 && compression == .none) && !(bits == 32
					&& compression == .bitfields)
				continue
			}
			assert format == if bits == 24 {
				PixelFormat.bgr24
			} else {
				PixelFormat.bgra32
			}
		}
	}
}

fn test_bmp_other_header_and_alpha_pixel_truncation_are_atomic() {
	for header in [BitmapInfoHeader(BitmapInfoHeaderWindows31{
		header_size: 40
	}),
		BitmapInfoHeader(BitmapInfoHeaderV5{
			header_size:        124
			width:              1
			height:             2
			bit_count:          32
			compression_method: .bitfields
		})] {
		bytes := bmp_fixture(BitmapFileHeader{}, header, [])
		mut reader := ReadStream.init_memory(bytes[..bytes.len - 1])
		mut codec := BMP{
			info_header: BitmapInfoHeaderV4{
				width: 999
			}
		}
		codec.read(mut reader) or {
			assert err.msg() == 'EndOfStream' && reader.get_pos() == 14
			assert codec.info_header == BitmapInfoHeader(BitmapInfoHeaderV4{
				width: 999
			})
			continue
		}
		assert false
	}
	for length in 0 .. 8 {
		mut reader := ReadStream.init_memory(bmp_fixture(BitmapFileHeader{}, BitmapInfoHeaderV5{
			header_size:        124
			width:              1
			height:             2
			bit_count:          32
			compression_method: .bitfields
		}, []u8{len: length}))
		mut codec := BMP{}
		codec.read(mut reader) or {
			assert err.msg() == 'EndOfStream'
			assert reader.get_pos() == if length < 4 {
				u64(138)
			} else {
				u64(142)
			}
			continue
		}
		assert false
	}
}

fn test_bmp_writer_errors_preserve_written_headers_and_partial_buffers() {
	mut output := []u8{len: 200}
	mut writer := WriteStream.init_memory(mut output)
	mut rejected := false
	BMP.write_image(mut writer, ImageUnmanaged{ width: 1, height: 1, pixels: Rgb24Pixels{} }, BmpEncoderOptions{}) or {
		assert err.msg() == 'InvalidData' && writer.get_pos() == 0
		rejected = true
	}
	assert rejected
	for codec in [BMP{ info_header: BitmapInfoHeaderWindows31{} },
		BMP{ info_header: BitmapInfoHeaderV4{} }, BMP{ info_header: BitmapInfoHeaderV5{} }] {
		writer.seek_to(0)!
		codec.write(mut writer, Grayscale8Pixels{}) or {
			assert err.msg() == 'InvalidData'
			assert writer.get_pos() == if codec.info_header is BitmapInfoHeaderWindows31 {
				u64(14)
			} else if codec.info_header is BitmapInfoHeaderV4 {
				u64(122)
			} else {
				u64(138)
			}
			continue
		}
		assert false
	}
	image := ImageUnmanaged{
		width:  1
		height: 2
		pixels: Bgr24Pixels{
			data: [Bgr24{ b: 1, g: 2, r: 3 }, Bgr24{ b: 4, g: 5, r: 6 }]
		}
	}
	mut complete := WriteStream.init_memory(mut output)
	BMP.write_image(mut complete, image, BmpEncoderOptions{})!
	for length in [0, 1, 13, 14, 100, 121, 122, 123, 124, 125, 127] {
		mut small := []u8{len: length}
		mut short := WriteStream.init_memory(mut small)
		BMP.write_image(mut short, image, BmpEncoderOptions{}) or {
			assert err.msg() == 'WriteFailed' && short.get_pos() == u64(length)
			assert short.buffered() == complete.buffered()[..length]
			continue
		}
		assert false
	}
}
