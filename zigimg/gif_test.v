module zigimg

fn test_gif_loop_count_uses_first_recognized_record_and_live_data() {
	mut codec := GIF.init()
	codec.application_infos << GifApplicationExtension{
		application_identifier: [u8(`U`), `N`, `K`, `N`, `O`, `W`, `N`, `!`]!
		authentification_code:  [u8(`a`), `b`, `c`]!
		data:                   []u8{}
	}
	codec.application_infos << GifApplicationExtension{
		application_identifier: [u8(`N`), `E`, `T`, `S`, `C`, `A`, `P`, `E`]!
		authentification_code:  [u8(`a`), `b`, `c`]!
		data:                   [u8(1)]
	}
	assert codec.loop_count() == 0
	codec.application_infos << GifApplicationExtension{
		application_identifier: [u8(`A`), `N`, `I`, `M`, `E`, `X`, `T`, `S`]!
		authentification_code:  [u8(`1`), `.`, `0`]!
		data:                   [u8(99), 0, 0, 165]
	}
	codec.application_infos << GifApplicationExtension{
		application_identifier: [u8(`N`), `E`, `T`, `S`, `C`, `A`, `P`, `E`]!
		authentification_code:  [u8(`2`), `.`, `0`]!
		data:                   []u8{}
	}
	assert codec.loop_count() == animation_loop_infinite
	codec.application_infos[2].data[0] = 255
	codec.application_infos[2].data[3] = 0
	assert codec.loop_count() == animation_loop_infinite
	codec.application_infos[2].data[1] = 255
	codec.application_infos[2].data[2] = 255
	assert codec.loop_count() == 65535
	mut copied := codec.application_infos[2]
	copied.application_identifier[0] = `X`
	copied.data[1] = 17
	assert codec.loop_count() == 65297
	assert codec.application_infos[2].application_identifier[0] == `A`
}

fn gif_test_u16(mut bytes []u8, value u16) {
	bytes << [u8(value), u8(value >> 8)]
}

fn gif_test_fixture(width u16, height u16, flags u8, background u8, colors []u8, blocks []u8) []u8 {
	mut bytes := 'GIF89a'.bytes()
	gif_test_u16(mut bytes, width)
	gif_test_u16(mut bytes, height)
	bytes << [flags, background, u8(77)]
	bytes << colors
	bytes << blocks
	return bytes
}

fn gif_test_data(indices []u8, initial u8, block_size int) ![]u8 {
	mut output := []u8{len: indices.len * 4 + 10}
	mut writer := WriteStream.init_memory(mut output)
	mut bits := BitWriter[LittleEndian]{
		writer: unsafe { &writer }
	}
	clear := u16(1) << initial
	for index in indices {
		bits.write_bits[LittleEndian, u16](clear, u16(initial + 1))!
		bits.write_bits[LittleEndian, u16](u16(index), u16(initial + 1))!
	}
	bits.write_bits[LittleEndian, u16](clear + 1, u16(initial + 1))!
	bits.flush_bits()!
	encoded := writer.buffered()
	mut bytes := [initial]
	for offset := 0; offset < encoded.len; {
		count := if encoded.len - offset < block_size { encoded.len - offset } else { block_size }
		bytes << u8(count)
		bytes << encoded[offset..offset + count]
		offset += count
	}
	bytes << u8(0)
	return bytes
}

fn gif_test_image(width u16, height u16, left u16, top u16, flags u8, colors []u8, indices []u8, initial u8, block_size int) ![]u8 {
	mut bytes := [u8(0x2c)]
	for value in [left, top, width, height] {
		gif_test_u16(mut bytes, value)
	}
	bytes << flags
	bytes << colors
	bytes << gif_test_data(indices, initial, block_size)!
	return bytes
}

fn gif_test_control(flags u8, delay u16, transparent u8) []u8 {
	mut bytes := [u8(0x21), 0xf9, 0, flags] // Size and terminator are ignored.
	gif_test_u16(mut bytes, delay)
	bytes << [transparent, u8(0xee)]
	return bytes
}

fn gif_test_application(identifier string, code string, count u16) []u8 {
	mut bytes := [u8(0x21), 0xff, 1] // The source reads eleven bytes despite this size.
	bytes << identifier.bytes()
	bytes << code.bytes()
	bytes << [u8(3), 99, u8(count), u8(count >> 8), 0] // The first data byte is ignored by loopCount.
	return bytes
}

fn test_gif_header_flags_layout_detection_and_empty_canvas() {
	assert sizeof(GifHeaderFlags) == 1 && sizeof(GifImageDescriptorFlags) == 1
	assert sizeof(GifGraphicControlExtensionFlags) == 1 && sizeof(GifGraphicControlExtension) == 4
	assert sizeof(GifHeader) == 13 && sizeof(GifImageDescriptor) == 9
	flags := GifHeaderFlags{
		raw: 0xed
	}
	assert flags.global_color_table_size() == 5 && flags.sorted() && flags.color_resolution() == 6
		&& flags.use_global_color_table()
	descriptor := GifImageDescriptorFlags{
		raw: 0xfd
	}
	assert descriptor.local_color_table_size() == 5 && descriptor.reserved() == 3
	assert descriptor.sort() && descriptor.is_interlaced() && descriptor.has_local_color_table()
	control := GifGraphicControlExtensionFlags{
		raw: 0xff
	}
	assert control.has_transparent_color() && control.user_input()
		&& u8(control.disposal_method()) == 7 && control.reserved() == 7
	for magic in ['GIF87a', 'GIF89a', 'GIF90a', 'BAD89a'] {
		mut reader := ReadStream.init_memory(magic.bytes())
		assert GIF.format_detect(mut reader)! == (magic in ['GIF87a', 'GIF89a'])
			&& reader.get_pos() == 0
	}
	for size in [0, 3, 5] {
		mut reader := ReadStream.init_memory('GIF89a'.bytes()[..size])
		GIF.format_detect(mut reader) or {
			assert err.msg() == 'EndOfStream'
			continue
		}
		assert false
	}
	mut reader := ReadStream.init_memory(gif_test_fixture(2, 2, 0xf8, 1, [u8(1), 2, 3, 4, 5, 6], [
		u8(0x3b),
	]))
	mut codec := GIF.init()
	frames := codec.read(mut reader)!
	assert codec.header.width == 2 && codec.header.height == 2
		&& codec.header.pixel_aspect_ratio == 77
	assert codec.header.flags.raw == 0xf8 && codec.global_color_table.data.len == 2
		&& codec.frames.len == 0
	assert frames.len == 1 && frames[0].pixels.pixel_format() == .indexed1
	assert frames[0].pixels.as_bytes() == [u8(1), 1, 1, 1] && frames[0].duration == 0
	assert frames[0].pixels.get_palette()?[1] == Rgba32{
		r: 4
		g: 5
		b: 6
	}
	assert reader.get_pos() == 20 && codec.loop_count() == 0
}

fn test_gif_lzw_subblocks_bare_image_grouping_and_animation_extensions() {
	colors := [u8(1), 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]
	for identifier in ['', 'NETSCAPE', 'ANIMEXTS', 'UNKNWNID'] {
		mut blocks := []u8{}
		if identifier != '' { blocks << gif_test_application(identifier, if identifier == 'ANIMEXTS' {
				'1.0'
			} else {
				'2.0'
			}, 7)
		 }
		blocks << gif_test_image(1, 1, 0, 0, 0, []u8{}, [u8(1)], 2, 1)!
		blocks << gif_test_image(1, 1, 1, 0, 0, []u8{}, [u8(2)], 2, 1)!
		blocks << u8(0x3b)
		mut reader := ReadStream.init_memory(gif_test_fixture(2, 1, 0x81, 0, colors, blocks))
		mut codec := GIF.init()
		frames := codec.read(mut reader)!
		animated := identifier in ['NETSCAPE', 'ANIMEXTS']
		assert frames.len == if animated {
			2
		} else {
			1
		}
		assert codec.frames.len == frames.len && codec.loop_count() == if animated {
			7
		} else {
			0
		}
		assert frames[frames.len - 1].pixels.as_bytes() == [u8(1), 2]
		assert frames[0].pixels.as_bytes() == if animated {
			[u8(1), 0]
		} else {
			[u8(1), 2]
		}
		assert reader.get_pos() == u64(13 + colors.len + blocks.len)
	}
	mut blocks := gif_test_application('NETSCAPE', '2.0', 0)
	blocks << gif_test_image(2, 1, 0, 0, 0, []u8{}, [u8(1), 0], 2, 255)!
	blocks << u8(0x3b)
	mut reader := ReadStream.init_memory(gif_test_fixture(2, 1, 0x80, 0, colors[..6], blocks))
	mut image := GIF.read_image(mut reader)!
	assert image.animation.loop_count == animation_loop_infinite && image.is_animation()
	mut pixels := image.pixels.as_bytes()
	pixels[0] = 0
	assert image.animation.frames[0].pixels.as_bytes()[0] == 0
}

fn test_gif_interlace_canvas_height_linear_clipping_and_index_truncation() {
	colors := [u8(0), 0, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
	for flags in [u8(0), 0x40] {
		mut blocks := gif_test_image(1, 2, 0, 0, flags, []u8{}, [u8(1), 2], 2, 255)!
		blocks << u8(0x3b)
		mut reader := ReadStream.init_memory(gif_test_fixture(1, 5, 0x81, 0, colors, blocks))
		image := GIF.read_image(mut reader)!
		assert image.raw_bytes() == if flags == 0 {
			[u8(1), 2, 0, 0, 0]
		} else {
			[u8(1), 0, 0, 0, 2]
		}
	}
	mut blocks := gif_test_image(3, 1, 0, 0, 0, []u8{}, [u8(1), 2, 3], 2, 255)!
	blocks << u8(0x3b)
	mut reader := ReadStream.init_memory(gif_test_fixture(2, 2, 0x81, 0, colors, blocks))
	assert GIF.read_image(mut reader)!.raw_bytes() == [u8(1), 2, 3, 0]
	blocks = gif_test_image(1, 1, 0, 0, 0, []u8{}, [u8(3)], 2, 255)!
	blocks << u8(0x3b)
	reader = ReadStream.init_memory(gif_test_fixture(1, 1, 0x80, 0, colors[..6], blocks))
	assert GIF.read_image(mut reader)!.raw_bytes() == [u8(1)]
}

fn test_gif_transparency_disposal_and_uncontrolled_frame_filtering() {
	colors := [u8(0), 0, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
	for dispose in [u8(0), 1, 2, 3, 7] {
		mut blocks := gif_test_control(dispose << 2, 37, 99)
		blocks << gif_test_image(1, 1, 1, 0, 0, []u8{}, [u8(1)], 2, 255)!
		blocks << gif_test_control(1, 25, 0)
		blocks << gif_test_image(2, 1, 0, 0, 0, []u8{}, [u8(1), 0], 2, 255)!
		blocks << u8(0x3b)
		mut reader := ReadStream.init_memory(gif_test_fixture(3, 1, 0x81, 0, colors, blocks))
		image := GIF.read_image(mut reader)!
		frames := image.animation.frames
		assert frames.len == 2 && image.pixel_format() == .indexed2
		assert frames[0].pixels.as_bytes() == [u8(0), 1, 0]
		assert frames[1].pixels.as_bytes() == [u8(1), if dispose in [u8(2), 3] {
			u8(0)
		} else {
			u8(1)
		}, 0]
		assert frames[0].duration == f32(37) * f32(0.01) && frames[1].duration == f32(0.25)
		assert frames[1].pixels.get_palette()?[0].a == 255 // Indexed transparency does not change the palette alpha.
	}
	mut blocks := gif_test_image(1, 1, 0, 0, 0, []u8{}, [u8(1)], 2, 255)!
	blocks << gif_test_control(0, 10, 0)
	blocks << gif_test_image(1, 1, 1, 0, 0, []u8{}, [u8(2)], 2, 255)!
	blocks << u8(0x3b)
	mut reader := ReadStream.init_memory(gif_test_fixture(3, 1, 0x81, 0, colors, blocks))
	mut codec := GIF.init()
	frames := codec.read(mut reader)!
	assert codec.frames.len == 2 && frames.len == 1
	assert frames[0].pixels.as_bytes() == [u8(1), 2, 0]
	assert frames[0].duration == f32(10) * f32(0.01)
}

fn test_gif_palette_format_thresholds_local_palette_and_rgba_background_quirk() {
	for size in 0 .. 8 {
		count := 1 << (size + 1)
		mut colors := []u8{len: count * 3}
		colors[3] = 11
		colors[4] = 22
		colors[5] = 33
		mut blocks := gif_test_image(1, 1, 0, 0, 0, []u8{}, [u8(1)], 2, 255)!
		blocks << u8(0x3b)
		mut reader := ReadStream.init_memory(gif_test_fixture(1, 1, 0x80 | u8(size), 0, colors,
			blocks))
		image := GIF.read_image(mut reader)!
		assert image.pixel_format() == if size == 0 {
			PixelFormat.indexed1
		} else if size == 1 {
			.indexed2
		} else if size < 4 {
			.indexed4
		} else {
			.indexed8
		}
		assert image.raw_bytes() == [u8(1)] && image.pixels.get_palette()?[1] == Rgba32{
			r: 11
			g: 22
			b: 33
		}
	}
	mut global_colors := []u8{len: 768}
	global_colors[6] = 10
	global_colors[7] = 20
	global_colors[8] = 30
	local := [u8(4), 5, 6, 7, 8, 9]
	for transparent in [false, true] {
		mut blocks := []u8{}
		if transparent { blocks << gif_test_control(1, 100, 1) }
		blocks << gif_test_image(2, 1, 0, 0, 0x80, local, [u8(0), 1], 2, 255)!
		blocks << u8(0x3b)
		mut reader := ReadStream.init_memory(gif_test_fixture(2, 1, 0x87, 2, global_colors, blocks))
		image := GIF.read_image(mut reader)!
		assert image.pixel_format() == if transparent {
			PixelFormat.rgba32
		} else {
			.rgb24
		}
		assert image.raw_bytes() == if transparent {
			[u8(4), 5, 6, 255, 0, 10, 20, 30]
		} else {
			[u8(4), 5, 6, 7, 8, 9]
		}
	}
	mut blocks := gif_test_image(1, 1, 0, 0, 0x80, local, [u8(1)], 2, 255)!
	blocks << u8(0x3b)
	mut reader := ReadStream.init_memory(gif_test_fixture(1, 1, 0, 0, []u8{}, blocks))
	image := GIF.read_image(mut reader)!
	assert image.pixel_format() == .indexed1 && image.pixels.get_palette()?[1] == Rgba32{
		r: 7
		g: 8
		b: 9
	}
}

fn test_gif_comments_application_metadata_unknown_extensions_and_plain_text() {
	mut blocks := [u8(0x21), 0xfe, 2, `a`, 0, 1, `b`, 0]
	blocks << gif_test_application('UNKNWNID', 'abc', 42)
	blocks << [u8(0x21), 0xee, 2, `x`, `y`, 0] // Unknown extensions scan bytes to the first zero.
	blocks << [u8(0x21), 1, 0, 254]
	blocks << []u8{len: 254, init: `A`}
	blocks << [u8(0), 0x3b]
	mut reader := ReadStream.init_memory(gif_test_fixture(1, 1, 0x80, 0, [u8(1), 2, 3, 4, 5, 6],
		blocks))
	mut codec := GIF.init()
	frames := codec.read(mut reader)!
	assert frames.len == 1 && codec.comments.len == 1
		&& codec.comments[0].comment == [u8(`a`), 0, `b`]
	assert codec.application_infos.len == 1
		&& codec.application_infos[0].application_identifier[..].bytestr() == 'UNKNWNID'
	assert codec.application_infos[0].authentification_code[..].bytestr() == 'abc'
	assert codec.application_infos[0].data == [u8(99), 42, 0] && codec.loop_count() == 0
	assert reader.get_pos() == u64(19 + blocks.len)
}

fn test_gif_error_positions_short_dimensions_and_ignored_write_failures() {
	full := gif_test_fixture(1, 1, 0x80, 0, [u8(1), 2, 3, 4, 5, 6], [u8(0x3b)])
	for size in [0, 6, 12, 13, 17, 19] {
		mut reader := ReadStream.init_memory(full[..size])
		mut codec := GIF.init()
		codec.read(mut reader) or {
			assert err.msg() == if size == 19 {
				'InvalidData'
			} else {
				'EndOfStream'
			}
			assert reader.get_pos() == if size < 13 {
				u64(0)
			} else if size < 16 {
				u64(13)
			} else if size < 19 {
				u64(16)
			} else {
				u64(19)
			}
			continue
		}
		assert false
	}
	mut invalid := full.clone()
	invalid[0] = `X`
	mut reader := ReadStream.init_memory(invalid)
	mut codec := GIF.init()
	codec.read(mut reader) or { assert err.msg() == 'InvalidData' }
	assert reader.get_pos() == 13 && codec.global_color_table.data.len == 0
	for suffix, position in {
		'\x00':           20
		'\x21\xee\x02A':  23
		'\x21\xfe\x04AB': 24
	} {
		mut input := full[..19].clone()
		input << suffix.bytes()
		reader = ReadStream.init_memory(input)
		codec = GIF.init()
		codec.read(mut reader) or {
			assert err.msg() == if suffix == '\x00' {
				'InvalidData'
			} else {
				'EndOfStream'
			}
			assert reader.get_pos() == u64(position)
			if suffix[1..] == '\xfe\x04AB' { assert codec.comments.len == 1
			 }
			continue
		}
		assert false
	}
	mut blocks := [u8(0x2c)]
	for value in [u16(0), 0, 0, 1] {
		gif_test_u16(mut blocks, value)
	}
	blocks << [u8(0x80), 0x3b] // Zero local width returns before reading its color table or LZW byte.
	reader = ReadStream.init_memory(gif_test_fixture(1, 1, 0x80, 1, [u8(1), 2, 3, 4, 5, 6], blocks))
	codec = GIF.init()
	frames := codec.read(mut reader)!
	assert frames.len == 1 && codec.frames[0].sub_images[0].pixels.len == 0
	assert codec.frames[0].sub_images[0].local_color_table.data.len == 0
	assert frames[0].pixels.as_bytes() == [u8(1)]
	blocks = gif_test_image(1, 1, 0, 0, 0, []u8{}, [u8(1), 2, 3], 2, 255)!
	blocks << u8(0x3b)
	reader = ReadStream.init_memory(gif_test_fixture(1, 1, 0x81, 0, [u8(0), 0, 0, 1, 2, 3, 4, 5,
		6, 7, 8, 9], blocks))
	assert GIF.read_image(mut reader)!.raw_bytes() == [u8(1)]
	assert reader.get_pos() == u64(25 + blocks.len)
	mut output := []u8{}
	mut writer := WriteStream.init_memory(mut output)
	GIF.write_image(mut writer, ImageUnmanaged{ width: 99, height: 1 })!
	assert writer.get_pos() == 0
}

fn test_gif_local_palette_overwrite_and_opaque_transparent_background_restoration() {
	first := [u8(1), 2, 3, 4, 5, 6]
	last := [u8(7), 8, 9, 10, 11, 12]
	mut blocks := gif_test_image(1, 1, 0, 0, 0x80, first, [u8(1)], 2, 255)!
	blocks << gif_test_image(1, 1, 1, 0, 0x80, last, [u8(0)], 2, 255)!
	blocks << u8(0x3b)
	mut reader := ReadStream.init_memory(gif_test_fixture(2, 1, 0, 0, []u8{}, blocks))
	mut codec := GIF.init()
	frames := codec.read(mut reader)!
	assert frames.len == 1 && frames[0].pixels.pixel_format() == .indexed2
	assert frames[0].pixels.as_bytes() == [u8(1), 0]
	assert frames[0].pixels.get_palette()?[1] == Rgba32{
		r: 10
		g: 11
		b: 12
	}
	codec.frames[0].sub_images[0].pixels[0] = 0
	assert frames[0].pixels.as_bytes()[0] == 1
	mut colors := []u8{len: 768}
	colors[6] = 10
	colors[7] = 20
	colors[8] = 30
	blocks = gif_test_control(9, 20, 1)
	blocks << gif_test_image(2, 1, 0, 0, 0x80, last, [u8(0), 1], 2, 255)!
	blocks << gif_test_control(1, 30, 1)
	blocks << gif_test_image(2, 1, 0, 0, 0x80, last, [u8(1), 1], 2, 255)!
	blocks << u8(0x3b)
	reader = ReadStream.init_memory(gif_test_fixture(2, 1, 0x87, 2, colors, blocks))
	image := GIF.read_image(mut reader)!
	assert image.animation.frames[0].pixels.as_bytes() == [u8(7), 8, 9, 255, 0, 10, 20, 30]
	assert image.animation.frames[1].pixels.as_bytes() == [u8(10), 11, 12, 255, 10, 11, 12, 255]
}

fn test_gif_previous_canvas_survives_restore_to_previous() {
	colors := [u8(0), 0, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
	mut blocks := gif_test_control(4, 0, 0)
	blocks << gif_test_image(1, 1, 1, 0, 0, []u8{}, [u8(1)], 2, 255)!
	blocks << gif_test_control(12, 0, 0)
	blocks << gif_test_image(1, 1, 0, 0, 0, []u8{}, [u8(2)], 2, 255)!
	blocks << gif_test_control(0, 0, 0)
	blocks << gif_test_image(1, 1, 2, 0, 0, []u8{}, [u8(1)], 2, 255)!
	blocks << u8(0x3b)
	mut reader := ReadStream.init_memory(gif_test_fixture(3, 1, 0x81, 0, colors, blocks))
	image := GIF.read_image(mut reader)!
	assert image.animation.frames.len == 3
	assert image.animation.frames[0].pixels.as_bytes() == [u8(0), 1, 0]
	assert image.animation.frames[1].pixels.as_bytes() == [u8(2), 1, 0]
	assert image.animation.frames[2].pixels.as_bytes() == [u8(0), 1, 1]
}
