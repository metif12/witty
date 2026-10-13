module zigimg

import os

fn test_pcx_dimension_arithmetic_preserves_u16_boundaries() {
	codec := PCX{
		header: PCXHeader{
			xmin: 1
			xmax: 65535
			ymin: 65535
			ymax: 65535
		}
	}
	assert codec.width() == 65535
	assert codec.height() == 1
}

fn test_pcx_oversized_dimension_rejection_precedes_zero_dimension_arithmetic() {
	for dims in [[usize(0), 65536], [usize(65536), 0]] {
		mut bytes := []u8{len: 128, init: 165}
		mut stream := WriteStream.init_memory(mut bytes)
		image := ImageUnmanaged{
			width:  dims[0]
			height: dims[1]
		}
		PCX.write_image(mut stream, image, PcxEncoderOptions{}) or {
			assert err.msg() == 'Unsupported'
			assert stream.get_pos() == 0
			assert bytes == []u8{len: 128, init: 165}
			continue
		}
		assert false
	}
}

fn pcx_fixture(header PCXHeader, data []u8) []u8 {
	mut bytes := pcx_header_bytes(header)
	bytes << data
	return bytes
}

fn pcx_fixture_palette() []u8 {
	mut bytes := [u8(0x0c)]
	for i in 0 .. 256 {
		bytes << [u8(i), u8(255 - i), u8(i ^ 55)]
	}
	return bytes
}

fn test_pcx_header_layout_detection_and_coordinate_extents() {
	assert sizeof(PCXHeader) == 128
	assert PCX{}.width() == 1 && PCX{}.height() == 1
	assert PCX{
		header: PCXHeader{
			xmin: 1
			xmax: 65535
			ymin: 1
			ymax: 65535
		}
	}.width() == 65535
	assert PCX{
		header: PCXHeader{
			xmin: 1
			xmax: 65535
			ymin: 1
			ymax: 65535
		}
	}.height() == 65535
	for version in 0 .. 7 {
		mut reader := ReadStream.init_memory([u8(0x0a), u8(version)])
		assert PCX.format_detect(mut reader)! == (version <= 5)
		assert reader.get_pos() == 0
	}
	mut reader := ReadStream.init_memory([u8(0x0b), 5])
	assert !PCX.format_detect(mut reader)!
	unknown_palette := u16(99)
	mut header := PCXHeader{
		bpp:                 1
		xmin:                10
		ymin:                20
		xmax:                19
		ymax:                21
		horizontal_dpi:      123
		vertical_dpi:        456
		reserved0:           77
		planes:              1
		stride:              2
		palette_information: unsafe { PcxPaletteInfo(unknown_palette) }
		screen_width:        789
		screen_height:       345
	}
	header.builtin_palette[0] = Rgb24{
		r: 1
		g: 2
		b: 3
	}
	header.builtin_palette[1] = Rgb24{
		r: 4
		g: 5
		b: 6
	}
	header.padding[53] = 99
	reader = ReadStream.init_memory(pcx_fixture(header, [u8(0xaa), 0, 0x55, 0x11, 7]))
	mut codec := PCX{}
	pixels := codec.read(mut reader)!
	assert codec.header == header
	assert codec.width() == 10 && codec.height() == 2
	assert pixels.as_bytes() == [u8(1), 0, 1, 0, 1, 0, 1, 0, 0, 0, 0, 1, 0, 1, 0, 1, 0, 1, 0, 0]
	match pixels {
		IndexedStorage1 {
			assert pixels.palette == [Rgba32{ r: 1, g: 2, b: 3 },
				Rgba32{ r: 4, g: 5, b: 6 }]
		}
		else {
			assert false
		}
	}

	assert reader.get_pos() == 132
}

fn test_pcx_rle_always_applies_skips_zero_commands_and_carries_runs_between_rows() {
	for compression in [PcxCompression.none, .rle] {
		mut reader := ReadStream.init_memory(pcx_fixture(PCXHeader{
			compression: compression
			bpp:         1
			xmax:        7
			ymax:        1
			planes:      1
			stride:      1
		}, [u8(0xc0), 0xc0, 0xc2, 0xaa]))
		pixels := PCX.read_image(mut reader)!.raw_bytes()
		assert pixels == [u8(1), 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0]
		assert reader.get_pos() == 132
	}
	mut reader := ReadStream.init_memory(pcx_fixture(PCXHeader{
		bpp:    4
		xmax:   2
		ymax:   1
		planes: 1
		stride: 2
	}, [u8(0x12), 0x30, 0x45, 0x60]))
	image := PCX.read_image(mut reader)!
	assert image.raw_bytes() == [u8(1), 2, 3, 4, 5, 6]
	match image.pixels {
		IndexedStorage4 { assert image.pixels.palette.len == 16 }
		else { assert false }
	}
}

fn test_pcx_indexed8_palette_is_read_from_the_end_and_dummy_bytes_are_discarded() {
	mut data := [u8(1), 2, 3, 9, 4, 5, 6, 9, 77, 88]
	data << pcx_fixture_palette()
	mut reader := ReadStream.init_memory(pcx_fixture(PCXHeader{
		bpp:    8
		xmin:   2
		xmax:   4
		ymax:   1
		planes: 1
		stride: 4
	}, data))
	image := PCX.read_image(mut reader)!
	assert image.width == 3 && image.height == 2
	assert image.raw_bytes() == [u8(1), 2, 3, 4, 5, 6]
	assert reader.get_pos() == reader.get_end_pos()!
	match image.pixels {
		IndexedStorage8 {
			assert image.pixels.palette.len == 256
			assert image.pixels.palette[0] == Rgba32{
				r: 0
				g: 255
				b: 55
			}
			assert image.pixels.palette[255] == Rgba32{
				r: 255
				g: 0
				b: 200
			}
		}
		else {
			assert false
		}
	}
}

fn test_pcx_rgb_planes_dummy_bytes_and_source_scanline_discard_boundary() {
	mut reader := ReadStream.init_memory(pcx_fixture(PCXHeader{
		bpp:    8
		xmax:   2
		planes: 3
		stride: 4
	}, [u8(1), 2, 3, 0, 4, 5, 6, 0, 7, 8, 9, 0]))
	assert PCX.read_image(mut reader)!.raw_bytes() == [u8(1), 4, 7, 2, 5, 8, 3, 6, 9]
	assert reader.get_pos() == 140
	reader = ReadStream.init_memory(pcx_fixture(PCXHeader{
		bpp:    8
		xmax:   3
		planes: 3
		stride: 6
	}, [u8(1), 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18]))
	assert PCX.read_image(mut reader)!.raw_bytes() == [u8(1), 5, 9, 2, 6, 10, 3, 7, 11, 4, 8, 12]
	assert reader.get_pos() == 144
}

struct PcxWriteCase {
	width  usize
	height usize = 1
	pixels PixelStorage
	bpp    u8
	planes u8 = 1
	stride u16
	data   []u8
}

fn test_pcx_writers_preserve_header_stride_packing_partial_bytes_and_planar_rle() {
	cases := [
		PcxWriteCase{
			width:  8
			pixels: IndexedStorage1{
				palette: []Rgba32{}
				indices: []u8{len: 8, init: 1}
			}
			bpp:    1
			stride: 2
			data:   [u8(0xc1), 0xff]
		},
		PcxWriteCase{
			width:  9
			pixels: IndexedStorage1{
				palette: []Rgba32{}
				indices: []u8{len: 9, init: 1}
			}
			bpp:    1
			stride: 2
			data:   [u8(0xc1), 0xff, 0x80]
		},
		PcxWriteCase{
			width:  10
			pixels: IndexedStorage1{
				palette: []Rgba32{}
				indices: []u8{len: 10, init: 1}
			}
			bpp:    1
			stride: 2
			data:   [u8(0xc1), 0xff]
		},
		PcxWriteCase{
			width:  17
			pixels: IndexedStorage1{
				palette: []Rgba32{}
				indices: []u8{len: 17, init: 1}
			}
			bpp:    1
			stride: 2
			data:   [u8(0xc2), 0xff, 0x80]
		},
		PcxWriteCase{
			width:  4
			pixels: IndexedStorage4{
				palette: []Rgba32{}
				indices: [u8(1), 2, 3, 4]
			}
			bpp:    4
			stride: 2
			data:   [u8(0x12), 0x34]
		},
		PcxWriteCase{
			width:  3
			pixels: IndexedStorage4{
				palette: []Rgba32{}
				indices: [u8(15), 1, 2]
			}
			bpp:    4
			stride: 2
			data:   [u8(0xc1), 0xf1, 0x20]
		},
		PcxWriteCase{
			width:  2
			pixels: Rgb24Pixels{
				data: [Rgb24{ r: 1, g: 1, b: 1 }, Rgb24{ r: 1, g: 1, b: 1 }]
			}
			bpp:    8
			planes: 3
			stride: 2
			data:   [u8(0xc6), 1]
		},
		PcxWriteCase{
			width:  3
			pixels: Rgb24Pixels{
				data: [Rgb24{ r: 1, g: 3, b: 6 }, Rgb24{ r: 1, g: 4, b: 7 },
					Rgb24{ r: 2, g: 5, b: 8 }]
			}
			bpp:    8
			planes: 3
			stride: 4
			data:   [u8(0xc2), 1, 2, 0, 3, 4, 5, 0, 6, 7, 8, 0]
		},
	]
	mut output := []u8{len: 2000}
	for item in cases {
		mut writer := WriteStream.init_memory(mut output)
		image := ImageUnmanaged{
			width:  item.width
			height: item.height
			pixels: item.pixels
		}
		PCX.write_image(mut writer, image, PcxEncoderOptions{})!
		expected := pcx_fixture(PCXHeader{
			xmax:   u16(item.width - 1)
			ymax:   u16(item.height - 1)
			bpp:    item.bpp
			planes: item.planes
			stride: item.stride
		}, item.data)
		assert writer.buffered() == expected
	}
	indexed := IndexedStorage1{
		indices: [u8(1)]
		palette: [Rgba32{ r: 1, g: 2, b: 3, a: 4 }]
	}
	mut writer := WriteStream.init_memory(mut output)
	PCX.write_image(mut writer, ImageUnmanaged{ width: 1, height: 1, pixels: indexed }, PcxEncoderOptions{})!
	assert writer.buffered()[16..22] == [u8(1), 2, 3, 0, 0, 0]
	assert writer.buffered()[66..68] == [u8(0), 0] // Truncated width/8 produces zero stride.
	assert writer.buffered()[128..] == [u8(0x80)]
}

fn test_pcx_indexed8_encoder_writes_active_palette_and_uses_entire_even_index_slice() {
	mut output := []u8{len: 2000}
	mut writer := WriteStream.init_memory(mut output)
	indexed := IndexedStorage8{
		indices: [u8(0xc0), 0xc0]
		palette: [Rgba32{ r: 1, g: 2, b: 3, a: 4 }, Rgba32{ r: 5, g: 6, b: 7, a: 8 }]
	}
	PCX.write_image(mut writer, ImageUnmanaged{ width: 2, height: 1, pixels: indexed }, PcxEncoderOptions{})!
	assert writer.buffered()[128..] == [u8(0xc2), 0xc0, 0x0c, 1, 2, 3, 5, 6, 7]
	writer.seek_to(0)!
	PCX.write_image(mut writer, ImageUnmanaged{
		width:  2
		height: 1
		pixels: IndexedStorage8{
			palette: []Rgba32{}
			indices: [u8(1), 2, 3, 4]
		}
	}, PcxEncoderOptions{})!
	assert writer.buffered()[128..] == [u8(1), 2, 3, 4, 0x0c]
	writer.seek_to(0)!
	PCX.write_image(mut writer, ImageUnmanaged{
		width:  3
		height: 2
		pixels: IndexedStorage8{
			palette: []Rgba32{}
			indices: []u8{len: 6, init: 5}
		}
	}, PcxEncoderOptions{})!
	assert writer.buffered()[128..] == [u8(0xc3), 5, 0, 0xc3, 5, 0, 0x0c]
	writer.seek_to(0)!
	codec := PCX{
		header: PCXHeader{
			id:          7
			version:     6
			compression: .none
			bpp:         99
			xmax:        1
			ymin:        1
			ymax:        0
			planes:      2
			stride:      42
		}
	}
	codec.write(mut writer, indexed)!
	assert writer.buffered() == pcx_fixture(codec.header, [u8(0xc2), 0xc0, 0x0c, 1, 2, 3, 5, 6,
		7])
}

fn test_pcx_fast_rle_preserves_16_byte_accumulation_and_63_byte_split_quirks() {
	mut output := []u8{len: 1000}
	mut writer := WriteStream.init_memory(mut output)
	mut bytes := []u8{len: 65, init: 0x45}
	bytes << [u8(1), 1, 1, 1]
	pcx_rle_fast_encode(bytes, mut writer)!
	assert writer.buffered() == [u8(0xff), 0x45, 0x45, 0x45, 0xc4, 1]
	bytes = []u8{len: 16, init: 1}
	bytes << []u8{len: 16, init: 2}
	writer.seek_to(0)!
	pcx_rle_fast_encode(bytes, mut writer)!
	// The source replaces current_byte before flushing a accumulated full chunk.
	assert writer.buffered() == [u8(0xe0), 2]
	bytes = []u8{len: 16, init: 1}
	bytes << []u8{len: 8, init: 2}
	bytes << []u8{len: 8, init: 3}
	writer.seek_to(0)!
	pcx_rle_fast_encode(bytes, mut writer)!
	assert writer.buffered() == [u8(0xd8), 2, 0xc8, 3]
	writer.seek_to(0)!
	mut encoder := PcxRleStreamEncoder{}
	encoder.encode(mut writer, [u8(1), 1])!
	encoder.flush(mut writer)!
	encoder.flush(mut writer)!
	assert writer.buffered() == [u8(0xc2), 1, 0xc2, 1]
}

fn test_pcx_errors_preserve_header_assignment_run_and_palette_boundaries() {
	mut header := PCXHeader{
		bpp:    1
		xmax:   7
		planes: 1
		stride: 1
	}
	for length in [1, 127] {
		mut reader := ReadStream.init_memory(pcx_fixture(header, [u8(1)])[..length])
		mut codec := PCX{
			header: PCXHeader{
				version: 2
			}
		}
		codec.read(mut reader) or {
			assert err.msg() == 'EndOfStream'
			assert reader.get_pos() == 0 && codec.header.version == 2
			continue
		}
		assert false
	}
	for bad in [PCXHeader{ id: 0 }, PCXHeader{ version: 6 }, PCXHeader{ planes: 4 },
		PCXHeader{ planes: 2 }, PCXHeader{ planes: 1, bpp: 2 },
		PCXHeader{ planes: 3, bpp: 4 }] {
		mut reader := ReadStream.init_memory(pcx_fixture(bad, []))
		mut codec := PCX{}
		codec.read(mut reader) or {
			assert err.msg() == if bad.id != 0x0a || bad.version > 5 {
				'InvalidData'
			} else {
				'Unsupported'
			}
			assert reader.get_pos() == 128 && codec.header == bad
			continue
		}
		assert false
	}
	for data in [[u8(0xc1)], [u8(0xc2), 1]] {
		mut reader := ReadStream.init_memory(pcx_fixture(header, data))
		PCX.read_image(mut reader) or {
			assert err.msg() == if data.len == 1 {
				'EndOfStream'
			} else {
				'InvalidData'
			}
			assert reader.get_pos() == u64(128 + data.len)
			continue
		}
		assert false
	}
	header = PCXHeader{
		bpp:    8
		planes: 1
		stride: 2
	}
	for padding in [769, 639] {
		mut bytes := pcx_fixture(header, [u8(1), 0])
		bytes << []u8{len: padding}
		mut reader := ReadStream.init_memory(bytes)
		PCX.read_image(mut reader) or {
			assert err.msg() == 'InvalidData'
			assert reader.get_pos() == if padding == 769 {
				u64(131)
			} else {
				u64(1)
			}
			continue
		}
		assert false
	}
	mut output := []u8{len: 200}
	mut writer := WriteStream.init_memory(mut output)
	for image in [ImageUnmanaged{ width: 65536, height: 1 }, ImageUnmanaged{ width: 1, height: 65536 },
		ImageUnmanaged{ width: 1, height: 1, pixels: Grayscale8Pixels{} }] {
		PCX.write_image(mut writer, image, PcxEncoderOptions{}) or {
			assert err.msg() == 'Unsupported' && writer.get_pos() == 0
			continue
		}
		assert false
	}
	image := ImageUnmanaged{
		width:  8
		height: 1
		pixels: IndexedStorage1{
			palette: []Rgba32{}
			indices: []u8{len: 8, init: 1}
		}
	}
	for length in [0, 1, 127, 129] {
		mut small := []u8{len: length}
		mut short_writer := WriteStream.init_memory(mut small)
		PCX.write_image(mut short_writer, image, PcxEncoderOptions{}) or {
			assert err.msg() == 'WriteFailed' && short_writer.get_pos() == u64(length)
			continue
		}
		assert false
	}
}

fn test_pcx_file_buffers_preserve_palette_seek_and_padded_rgb_rows() {
	path := os.join_path(os.temp_dir(), 'witty-pcx-buffer-${os.getpid()}.pcx')
	defer { os.rm(path) or {} }
	indexed_header := PCXHeader{
		bpp:    8
		xmax:   2
		ymax:   1
		planes: 1
		stride: 4
	}
	rgb_header := PCXHeader{
		bpp:    8
		xmax:   2
		ymax:   1
		planes: 3
		stride: 4
	}
	mut indexed := [u8(1), 2, 3, 87, 4, 5, 6, 87, 99, 98]
	indexed << pcx_fixture_palette()
	rgb := [u8(1), 2, 3, 0, 4, 5, 6, 0, 7, 8, 9, 0, 10, 11, 12, 0, 13, 14, 15, 0, 16, 17, 18, 0]
	for data in [pcx_fixture(indexed_header, indexed), pcx_fixture(rgb_header, rgb)] {
		mut memory := ReadStream.init_memory(data)
		mut expected_codec := PCX{}
		expected := expected_codec.read(mut memory)!
		os.write_file_array(path, data)!
		for capacity in [128, 129, 131, 257, 1024] {
			mut file := os.open(path)!
			mut buffer := []u8{len: capacity, init: u8(165)}
			mut stream := ReadStream.init_file(file, mut buffer)
			mut codec := PCX{}
			actual := codec.read(mut stream)!
			assert codec.header == expected_codec.header
			assert actual.as_bytes() == expected.as_bytes()
			assert stream.get_pos() == memory.get_pos()
			if actual_palette := actual.get_palette() {
				assert actual_palette == expected.get_palette()?
			}
			file.close()
		}
	}
}
