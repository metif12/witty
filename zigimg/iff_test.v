module zigimg

fn iff_test_u16(mut bytes []u8, value u16) {
	bytes << [u8(value >> 8), u8(value)]
}

fn iff_test_chunk(name string, length u32, data []u8) []u8 {
	mut bytes := name.bytes()
	append_be_u32(mut bytes, length)
	bytes << data
	return bytes
}

fn iff_test_bmhd(header BmhdHeader) []u8 {
	mut bytes := []u8{}
	for value in [header.width, header.height, u16(header.x), u16(header.y)] {
		iff_test_u16(mut bytes, value)
	}
	bytes << [header.planes, u8(header.mask_type), u8(header.compression_type), header.pad]
	iff_test_u16(mut bytes, header.transparent_color)
	bytes << [header.x_asoect, header.y_aspect]
	iff_test_u16(mut bytes, header.page_width)
	iff_test_u16(mut bytes, header.page_height)
	return iff_test_chunk('BMHD', 20, bytes)
}

fn iff_test_fixture(format string, header BmhdHeader, chunks []u8) []u8 {
	mut bytes := 'FORM'.bytes()
	append_be_u32(mut bytes, 0xdeadbeef) // The declared FORM length is ignored.
	bytes << format.bytes()
	bytes << iff_test_bmhd(header)
	bytes << chunks
	return bytes
}

fn iff_test_planar(indices []u8, width int, height int, planes int, vertical bool) []u8 {
	pitch := ((width + 15) / 16) * 2
	mut bytes := []u8{len: pitch * height * planes}
	for row in 0 .. height {
		for plane in 0 .. planes {
			base := if vertical {
				plane * height * pitch + row * pitch
			} else {
				row * planes * pitch + plane * pitch
			}
			for col in 0 .. width {
				if indices[row * width + col] & (u8(1) << plane) != 0 {
					bytes[base + col / 8] |= u8(1) << (7 - col % 8)
				}
			}
		}
	}
	return bytes
}

fn test_iff_header_layout_detection_and_consumption() {
	assert sizeof(IffChunkHeader) == 8 && sizeof(BmhdHeader) == 20 && sizeof(DgblHeader) == 8
	assert iff_chunk_dgbl.name == 'DBGL'.bytes() && iff_chunk_bmhd.id == 0x424d4844
	mut chunk := IffChunkHeader{
		type_:  iff_chunk_bmhd.id
		length: 0
	}
	name := chunk.name()
	$if little_endian {
		assert name == 'DHMB'.bytes()
	} $else {
		assert name == 'BMHD'.bytes()
	}
	chunk.type_ = iff_chunk_body.id
	$if little_endian {
		assert name == 'YDOB'.bytes()
	} $else {
		assert name == 'BODY'.bytes()
	}
	for format in ['ILBM', 'PBM ', 'ACBM', 'DEEP', 'XXXX'] {
		mut reader := ReadStream.init_memory(iff_test_fixture(format, BmhdHeader{}, []u8{}))
		assert IFF.format_detect(mut reader)! == (format in ['ILBM', 'PBM ', 'ACBM'])
		assert reader.get_pos() == 0
	}
	for bytes in [[]u8{}, 'FORM'.bytes(), 'FORM0123ILB'.bytes()] {
		mut reader := ReadStream.init_memory(bytes)
		assert !IFF.format_detect(mut reader)! && reader.get_pos() == 0
	}
	mut reader := ReadStream.init_memory('FORM0123DEEP'.bytes())
	take_iff_format_id(mut reader) or { assert err.msg() == 'InvalidData' }
	assert reader.get_pos() == 12
	meta := BmhdHeader{
		width:             16
		height:            2
		x:                 -2
		y:                 -32768
		planes:            7
		mask_type:         .has_lasso
		compression_type:  .byterun2
		pad:               0x99
		transparent_color: 0x1234
		x_asoect:          5
		y_aspect:          6
		page_width:        789
		page_height:       1234
	}
	reader = ReadStream.init_memory(iff_test_bmhd(meta))
	decoded := decode_bmhd_chunk(mut reader)!
	assert decoded == meta
	assert reader.get_pos() == 28
	reader = ReadStream.init_memory([u8(1), 2, 3])
	assert decode_dbgl_chunk(mut reader)! == DgblHeader{} && reader.get_pos() == 0
	assert iff_load_header(mut reader, .deep)! == IffHeader(DgblHeader{})
	codec := IFF{
		header:        DgblHeader{
			width:  23
			height: 45
		}
		viewport_mode: u32(IffViewportMode.ham)
	}
	assert codec.width() == 23 && codec.height() == 45 && codec.pixel_format()! == .rgb24
}

fn test_iff_planar_chunky_and_chunk_walk_follow_source() {
	indices := [u8(0), 1, 2, 3, 1, 0, 2, 3, 0, 1, 2, 3, 3, 2, 1, 0, 3, 2, 1, 0, 2, 3, 1, 0, 3,
		2, 1, 0, 0, 1, 2, 3]
	palette := [u8(1), 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]
	for format in ['ILBM', 'ACBM'] {
		mut chunks := iff_test_chunk('JUNK', 1, [u8(99)]) // No odd-byte alignment.
		chunks << iff_test_chunk('CMAP', 12, palette)
		chunks << iff_test_chunk(if format == 'ACBM' { 'ABIT' } else { 'BODY' }, 1, iff_test_planar(indices,
			16, 2, 2, format == 'ACBM'))
		mut reader := ReadStream.init_memory(iff_test_fixture(format, BmhdHeader{
			width:            16
			height:           2
			planes:           2
			compression_type: if format == 'ACBM' { .byterun } else { .none }
		}, chunks))
		mut codec := IFF{}
		mut pixels := codec.read(mut reader)!
		assert pixels.as_bytes() == indices && reader.get_pos() == 85
		assert codec.pitch == 2 && codec.cmap_bits == 2
		if mut pixels is IndexedStorage8 {
			assert pixels.palette.len == 4 && pixels.palette[3] == Rgba32{
				r: 10
				g: 11
				b: 12
			}
			codec.palette.data[3].r = 99
			assert pixels.palette[3].r == 10
		} else {
			assert false
		}
	}
	mut raw := []u8{len: 32}
	for i in 0 .. raw.len {
		raw[i] = u8(i + 1)
	}
	mut reader := ReadStream.init_memory(iff_test_fixture('PBM ', BmhdHeader{
		width:  3
		height: 2
		planes: 8
	}, iff_test_chunk('BODY', 1, raw)))
	image := IFF.read_image(mut reader)!
	assert image.width == 3 && image.height == 2 && image.raw_bytes() == raw[..6]
	assert reader.get_pos() == 80
	codec := IFF{
		format_id: .ilbm
		header:    BmhdHeader{
			width:  9
			height: 2
			planes: 1
		}
		pitch:     2
	}
	mut chunky := []u8{len: 18}
	codec.planar_to_chunky([u8(0), 0x40, 0x80, 0], mut chunky)!
	assert chunky[9] == 1 // A set row-padding bit spills into the next row.
	assert chunky.filter(it != 0).len == 1
}

fn test_iff_packbits_and_direct_rgb24() {
	mut reader := ReadStream.init_memory(iff_test_fixture('ILBM', BmhdHeader{
		width:            16
		height:           1
		planes:           1
		compression_type: .byterun
	}, iff_test_chunk('BODY', 4, [u8(1), 0x80, 1, 0x99])))
	image := IFF.read_image(mut reader)!
	assert image.raw_bytes() == [u8(1), 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]
	assert reader.get_pos() == 51 && reader.take_byte()! == 0x99
	mut planes := []u8{len: 48}
	for channel, value in [u8(0xa5), 0x5a, 0xc3] {
		for bit in 0 .. 8 {
			if value & (u8(1) << bit) != 0 { planes[(channel * 8 + bit) * 2] = 0x80 }
		}
	}
	reader = ReadStream.init_memory(iff_test_fixture('ILBM', BmhdHeader{
		width:  1
		height: 1
		planes: 24
	}, iff_test_chunk('BODY', 0, planes)))
	assert IFF.read_image(mut reader)!.raw_bytes() == [u8(0xa5), 0x5a, 0xc3]
	assert reader.get_pos() == 96
}

fn test_iff_ham6_ham8_palette_reduction_and_ehb() {
	for case in [6, 8, 0] {
		planes := if case == 0 { 6 } else { case }
		palette_len := if case == 0 {
			256
		} else if planes == 6 {
			16
		} else {
			64
		}
		mut colors := []u8{len: palette_len * 3}
		colors[3] = 10
		colors[4] = 20
		colors[5] = 30
		control := if planes == 6 { u8(16) } else { u8(64) }
		indices := [u8(1), control + 10, control * 2 + 3, control * 3 + 4, control + 5, u8(1),
			control * 2 + 2, control * 3 + 6]
		mut chunks := iff_test_chunk('CMAP', u32(colors.len), colors)
		chunks << iff_test_chunk('CAMG', 900, [u8(0), 0, 8, 0]) // Declared size ignored.
		chunks << iff_test_chunk('BODY', 0, iff_test_planar(indices, 4, 2, planes, false))
		mut reader := ReadStream.init_memory(iff_test_fixture('ILBM', BmhdHeader{
			width:  4
			height: 2
			planes: u8(planes)
		}, chunks))
		image := IFF.read_image(mut reader)!
		shift := if planes == 6 { 4 } else { 2 }
		assert image.raw_bytes() == [u8(10), 20, 30, 10, 20, u8(10 << shift), u8(3 << shift), 20,
			u8(10 << shift), u8(3 << shift), u8(4 << shift), u8(10 << shift), 0, 0, u8(5 << shift),
			10, 20, 30, u8(2 << shift), 20, 30, u8(2 << shift), u8(6 << shift), 30]
	}
	mut codec := IFF{
		header:    BmhdHeader{
			planes: 6
		}
		cmap_bits: 8
	}
	codec.palette.resize(256)
	codec.reduce_ham_palette()
	assert codec.cmap_bits == 4 && codec.palette.data.len == 16
	// The public reducer truncates the shift count to the target word width.
	for planes in [u8(34), 66, 130] {
		mut reducer := IFF{
			header:    BmhdHeader{
				planes: planes
			}
			cmap_bits: planes + 1
		}
		reducer.palette.resize(256)
		reducer.reduce_ham_palette()
		shift := (planes - 2) & u8(sizeof(usize) * 8 - 1)
		assert reducer.cmap_bits == planes - 2
			&& reducer.palette.data.len == int(usize(256) >> shift)
	}
	codec.palette.resize(32)
	for i in 0 .. 32 {
		codec.palette.data[i] = Rgba32{
			r: u8(i * 3)
			g: u8(i * 5)
			b: u8(i * 7)
			a: 0
		}
	}
	extend_ehb_palette(mut codec.palette)
	assert codec.palette.data.len == 64
	assert codec.palette.data[63] == Rgba32{
		r: 46
		g: 77
		b: 108
	}
	mut palette_bytes := []u8{}
	for i in 0 .. 32 {
		palette_bytes << [u8(i * 3), u8(i * 5), u8(i * 7)]
	}
	mut chunks := iff_test_chunk('CMAP', 96, palette_bytes)
	chunks << iff_test_chunk('CAMG', 4, [u8(0), 0, 0, 0x80])
	chunks << iff_test_chunk('BODY', 0, iff_test_planar([u8(31), 63], 2, 1, 6, false))
	mut reader := ReadStream.init_memory(iff_test_fixture('ILBM', BmhdHeader{
		width:  2
		height: 1
		planes: 6
	}, chunks))
	mut pixels := IFF.read_image(mut reader)!.pixels
	if mut pixels is IndexedStorage8 {
		assert pixels.palette.len == 64 && pixels.indices == [u8(31), 63]
		assert pixels.palette[63] == Rgba32{
			r: 46
			g: 77
			b: 108
		}
	} else {
		assert false
	}
	// EHB expansion has priority over HAM palette reduction when both flags are set.
	chunks = iff_test_chunk('CMAP', 96, palette_bytes)
	chunks << iff_test_chunk('CAMG', 4, [u8(0), 0, 8, 0x80])
	chunks << iff_test_chunk('BODY', 0, iff_test_planar([u8(31), 63], 2, 1, 6, false))
	reader = ReadStream.init_memory(iff_test_fixture('ILBM', BmhdHeader{
		width:  2
		height: 1
		planes: 6
	}, chunks))
	assert IFF.read_image(mut reader)!.raw_bytes() == [u8(93), 155, 217, 46, 77, 108]
}

fn test_iff_byte_run2_commands_column_order_and_unread_literals() {
	codec := IFF{
		header: BmhdHeader{
			width:            32
			height:           3
			planes:           1
			compression_type: .byterun2
		}
		pitch:  4
	}
	// Negative literal, counted literal, counted repeat, short repeat.
	mut data := iff_test_chunk('VDAT', 0xffffffff, [u8(0), 6, 0xff, 0, 1, 2, 0x11, 0x22, 0, 1,
		0x33, 0x44, 0, 2, 0x55, 0x66, 0x77, 0x88])
	mut reader := ReadStream.init_memory(data)
	mut buffer := []u8{len: 12, init: 0xee}
	codec.decode_byte_run2(mut reader, mut buffer)!
	assert buffer == [u8(0x11), 0x22, 0x55, 0x66, 0x33, 0x44, 0x77, 0x88, 0x55, 0x66, 0x77, 0x88]
	assert reader.get_pos() == 26
	// -128 is a literal run, clipped at pitch rather than consuming its tail.
	data = iff_test_chunk('VDAT', 0, [u8(0), 3, 0x80, 0xa0, 0, 0xb0, 0, 0xc0, 0, 0xdd])
	reader = ReadStream.init_memory(data)
	one_col := IFF{
		header: BmhdHeader{
			width:  16
			height: 3
			planes: 1
		}
		pitch:  2
	}
	buffer = []u8{len: 6}
	one_col.decode_byte_run2(mut reader, mut buffer)!
	assert buffer == [u8(0xa0), 0, 0xb0, 0, 0xc0, 0] && reader.take_byte()! == 0xdd
	// Two VDAT planes; ILBM ByteRun2 is plane-interleaved, not row-interleaved.
	mut body := iff_test_chunk('VDAT', 0, [u8(0), 3, 2, 0x80, 0])
	body << iff_test_chunk('VDAT', 0, [u8(0), 3, 2, 0x40, 0])
	reader = ReadStream.init_memory(iff_test_fixture('ILBM', BmhdHeader{
		width:            16
		height:           2
		planes:           2
		compression_type: .byterun2
	}, iff_test_chunk('BODY', 0, body)))
	image := IFF.read_image(mut reader)!
	assert image.raw_bytes()[..16] == [u8(1), 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
	assert image.raw_bytes()[16..] == image.raw_bytes()[..16]
}

fn test_iff_partial_input_chunk_errors_and_noop_writer() {
	for size in [0, 7, 8, 27] {
		mut reader := ReadStream.init_memory(iff_test_bmhd(BmhdHeader{})[..size])
		decode_bmhd_chunk(mut reader) or {
			assert err.msg() == 'EndOfStream'
			assert reader.get_pos() == if size < 8 {
				u64(0)
			} else {
				u64(8)
			}
			continue
		}
		assert false
	}
	mut reader := ReadStream.init_memory(iff_test_chunk('BMHD', 19, []u8{len: 20}))
	decode_bmhd_chunk(mut reader) or { assert err.msg() == 'InvalidData' }
	assert reader.get_pos() == 8
	mut codec := IFF{
		header:        BmhdHeader{
			planes: 1
		}
		pitch:         2
		cmap_bits:     7
		viewport_mode: 0x99
	}
	reader = ReadStream.init_memory([u8(1), 2, 3, 4, 5])
	codec.decode_cmap_chunk(mut reader, IffChunkHeader{ type_: 0, length: 6 }) or {
		assert err.msg() == 'EndOfStream'
	}
	assert reader.get_pos() == 3 && codec.cmap_bits == 7 && codec.palette.data.len == 2
	assert codec.palette.data[0] == Rgba32{
		r: 1
		g: 2
		b: 3
	}
	reader = ReadStream.init_memory([u8(1), 2, 3, 0xff])
	codec.decode_cmap_chunk(mut reader, IffChunkHeader{ type_: 0, length: 4 })!
	assert reader.get_pos() == 3 && codec.cmap_bits == 0 && reader.take_byte()! == 0xff
	reader = ReadStream.init_memory([u8(1), 2, 3])
	codec.decode_camg_chunk(mut reader) or { assert err.msg() == 'EndOfStream' }
	assert reader.get_pos() == 0 && codec.viewport_mode == 0x99
	for size in [0, 3, 8, 9] {
		reader = ReadStream.init_memory([]u8{len: size})
		mut buffer := [u8(99), 99]
		codec.decode_byte_run2(mut reader, mut buffer) or {
			assert err.msg() == 'EndOfStream'
			assert reader.get_pos() == if size < 8 {
				u64(size)
			} else {
				u64(8)
			}
			assert buffer == [u8(0), 0]
			continue
		}
		assert false
	}
	reader = ReadStream.init_memory(iff_test_chunk('VDAT', 0, [u8(0), 5, 0xff, 0]))
	mut buffer := [u8(99), 99]
	codec.decode_byte_run2(mut reader, mut buffer) or { assert err.msg() == 'EndOfStream' }
	assert reader.get_pos() == 12 && buffer == [u8(0), 0] // Command prefix consumed.
	for tail in [0, 1] {
		mut chunks := iff_test_chunk('JUNK', 1, [u8(0)])
		chunks << []u8{len: tail}
		reader = ReadStream.init_memory(iff_test_fixture('ILBM', BmhdHeader{}, chunks))
		codec.read(mut reader) or {
			assert err.msg() == if tail == 0 {
				'Unseekable'
			} else {
				'Unsupported'
			}
			assert reader.get_pos() == if tail == 0 {
				u64(48)
			} else {
				u64(49)
			}
			continue
		}
		assert false
	}
	reader = ReadStream.init_memory(iff_test_fixture('ILBM', BmhdHeader{
		width:  16
		height: 1
		planes: 1
	}, iff_test_chunk('BODY', 1, [u8(0x80)])))
	codec.read(mut reader) or { assert err.msg() == 'EndOfStream' }
	assert reader.get_pos() == 49
	mut output := []u8{}
	mut writer := WriteStream.init_memory(mut output)
	IFF.write_image(mut writer, ImageUnmanaged{ width: 999, height: 123 })!
	assert writer.get_pos() == 0
}
