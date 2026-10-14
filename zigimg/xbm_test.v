module zigimg

import os

fn test_xbm_continuous_lsb_first_bits_palette_and_extra_data() {
	mut reader := ReadStream.init_memory(('#define name_width 4\n#define name_height 4\n' +
		'static unsigned char bits[] = {\n0x0F, 0x0F, 0xF0, 0xF0\n};\n').bytes())
	mut codec := XBM{}
	pixels := codec.read(mut reader)!
	assert codec.width == 4 && codec.height == 4
	assert pixels.pixel_format() == .indexed1
	assert pixels.as_bytes() == [u8(1), 1, 1, 1, 0, 0, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0]
	match pixels {
		IndexedStorage1 {
			assert pixels.palette == [Rgba32{ r: 255, g: 255, b: 255 },
				Rgba32{ r: 0, g: 0, b: 0 }]
		}
		else {
			assert false
		}
	}

	assert reader.get_pos() == reader.get_end_pos()!
	reader = ReadStream.init_memory('#define a 8\n#define b 2\n{0X55, 0xaa};\n'.bytes())
	image := XBM.read_image(mut reader)!
	assert image.raw_bytes() == [u8(1), 0, 1, 0, 1, 0, 1, 0, 0, 1, 0, 1, 0, 1, 0, 1]
}

fn test_xbm_defines_follow_order_and_zero_hotspot_sentinel() {
	mut reader := ReadStream.init_memory(('#define unrelated +0_8 \r\n#define whatever +1\n' +
		'#define y -0\n#define x 7\n#define more 8\n#define ignored 9\n{0x01}\n').bytes())
	mut codec := XBM{}
	assert codec.read(mut reader)!.len() == 8
	assert codec.width == 8 && codec.height == 1
	assert codec.hotspot_x == 7 && codec.hotspot_y == 8
	reader = ReadStream.init_memory('#define width 0\n#define height 5\n{ };\n'.bytes())
	assert XBM.read_image(mut reader)!.raw_bytes().len == 0
}

fn test_xbm_hex_words_truncate_to_two_bytes_and_skip_invalid_tokens() {
	mut reader := ReadStream.init_memory(('#define w 16\n#define h 2\n' +
		'{0xgg, 0x1ffffffff, 0x-1, 0x, 0x+1_55, 0x-0, 0x123456, 77};\n').bytes())
	image := XBM.read_image(mut reader)!
	assert image.raw_bytes() == [u8(1), 0, 1, 0, 1, 0, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
		0, 0, 0, 0, 0, 1, 1, 0, 1, 0, 1, 0]
	reader = ReadStream.init_memory('#define w 8\n#define h 1\n{0xff}\r\n'.bytes())
	// The first pixel line is trimmed; subsequent pixel lines retain CR.
	assert XBM.read_image(mut reader)!.raw_bytes() == []u8{len: 8, init: 1}
	reader = ReadStream.init_memory('#define w 8\n#define h 1\n{\n0xff\r\n0x55\n}\n'.bytes())
	assert XBM.read_image(mut reader)!.raw_bytes() == [u8(1), 0, 1, 0, 1, 0, 1, 0]
}

fn test_xbm_unterminated_final_lines_are_ignored_without_consumption() {
	prefix := '#define w 8\n#define h 1\n{0xff}\n'
	mut reader := ReadStream.init_memory('${prefix}0x55'.bytes())
	assert XBM.read_image(mut reader)!.raw_bytes() == []u8{len: 8, init: 1}
	assert reader.get_pos() == u64(prefix.len)
	reader = ReadStream.init_memory('#define w 8\n#define h 1\n{\n0xff'.bytes())
	XBM.read_image(mut reader) or {
		assert err.msg() == 'InvalidData'
		assert reader.get_pos() == 26
	}
	reader = ReadStream.init_memory('#define w 8\n#define h 1\n{0xff}'.bytes())
	XBM.read_image(mut reader) or {
		assert err.msg() == 'EndOfStream'
		assert reader.get_pos() == 24
	}
}

fn test_xbm_errors_leave_codec_fields_at_source_assignment_boundary_and_writer_is_noop() {
	for text in ['#define w -1\n', '#define w 4294967296\n', '#define w 8\t\n'] {
		mut reader := ReadStream.init_memory(text.bytes())
		mut codec := XBM{
			width:  99
			height: 88
		}
		codec.read(mut reader) or {
			assert err.msg() == 'InvalidData'
			assert reader.get_pos() == u64(text.len)
			assert codec.width == 99 && codec.height == 88
			continue
		}
		assert false
	}
	mut reader := ReadStream.init_memory('#define w 8\n{}\n'.bytes())
	XBM.read_image(mut reader) or { assert err.msg() == 'InvalidData' }
	reader = ReadStream.init_memory('#define w 8\n#define h 1\n{}\n'.bytes())
	mut codec := XBM{
		width:  99
		height: 88
	}
	codec.read(mut reader) or {
		assert err.msg() == 'InvalidData'
		assert codec.width == 8 && codec.height == 1
		assert reader.get_pos() == reader.get_end_pos()!
	}
	mut output := []u8{}
	mut writer := WriteStream.init_memory(mut output)
	XBM.write_image(mut writer, ImageUnmanaged{})!
	assert writer.get_pos() == 0
}

fn test_xbm_detection_non_define_and_delimiter_peeks_do_not_advance() {
	for text in ['anything\n', '\n', ' #define w 8\n'] {
		mut reader := ReadStream.init_memory(text.bytes())
		assert !XBM.format_detect(mut reader)!
		assert reader.get_pos() == 0
	}
	for text in ['', '#define w 8'] {
		mut reader := ReadStream.init_memory(text.bytes())
		XBM.format_detect(mut reader) or {
			assert err.msg() == 'EndOfStream'
			assert reader.get_pos() == 0
			continue
		}
		assert false
	}
	mut bytes := 'a\nb\nc'.bytes()
	mut reader := ReadStream.init_memory(bytes)
	line := reader.peek_delimiter_inclusive(`\n`)!
	assert line.data == bytes.data
	assert reader.get_pos() == 0
	assert reader.take_delimiter_inclusive(`\n`)! == 'a\n'.bytes()
	assert reader.take_delimiter_inclusive(`\n`)! == 'b\n'.bytes()
	reader.take_delimiter_inclusive(`\n`) or {
		assert err.msg() == 'EndOfStream'
		assert reader.get_pos() == 4
	}
}

fn test_xbm_file_errors_preserve_native_buffer_and_assignment_boundaries() {
	for index, text in ['#define w 8\n#define h',
		'#define w 8\n#define h 1\n{0xff}\n' + ' '.repeat(25) + '\n'] {
		path := os.join_path(os.temp_dir(), 'witty-xbm-state-${os.getpid()}-${index}.bin')
		os.write_file(path, text)!
		defer { os.rm(path) or {} }
		mut file := os.open(path)!
		defer { file.close() }
		file.seek(i64(text.len), .start)!
		mut buffer := []u8{len: 24, init: 165}
		mut reader := ReadStream.init_file(file, mut buffer)
		mut codec := XBM{
			width:     97
			height:    89
			hotspot_x: 77
			hotspot_y: 66
		}
		codec.read(mut reader) or {
			if index == 0 {
				assert err.msg() == 'EndOfStream'
				assert reader.get_pos() == 12 && reader.buffered_len() == 9
				assert buffer[..text.len] == text.bytes()
				assert buffer[text.len..] == [u8(165), 165, 165]
				assert codec == XBM{
					width:     97
					height:    89
					hotspot_x: 77
					hotspot_y: 66
				}
			} else {
				assert err.msg() == 'StreamTooLong'
				assert reader.get_pos() == 31 && reader.buffered_len() == 24
				assert buffer == ' '.repeat(24).bytes()
				assert codec == XBM{
					width:  8
					height: 1
				}
			}
			assert os.read_file(path)! == text
			continue
		}
		assert false
	}
}
