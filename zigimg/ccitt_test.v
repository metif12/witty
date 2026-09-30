module zigimg

fn test_ccitt_all_locked_code_tables_and_lookup_color_state() {
	assert sizeof(CcittCode) == 6
	mut hash := u64(0xcbf29ce484222325)
	for table in [ccitt_white_terminating_codes[..], ccitt_black_terminating_codes[..], ccitt_white_make_up_codes[..],
		ccitt_black_make_up_codes[..], ccitt_additional_make_up_codes[..]] {
		for item in table {
			for byte in [u8(item.run_length), u8(item.run_length >> 8), u8(item.code),
				u8(item.code >> 8), item.code_length] {
				hash = (hash ^ u64(byte)) * 0x100000001b3
			}
		}
	}
	assert hash == 0x8aa26e4c9fe26ada
	mut decoder := CcittDecoder.init(8, 1, 1)!
	for color in [CcittColor.white, .black] {
		decoder.current_color = color
		terminating := if color == .white {
			ccitt_white_terminating_codes[..]
		} else {
			ccitt_black_terminating_codes[..]
		}
		make_up := if color == .white {
			ccitt_white_make_up_codes[..]
		} else {
			ccitt_black_make_up_codes[..]
		}
		for item in terminating {
			decoder.should_reverse = false
			assert decoder.get_run_length(item.code, item.code_length) == ?u16(item.run_length)
			assert decoder.should_reverse
		}
		for item in make_up {
			decoder.should_reverse = false
			assert decoder.get_run_length(item.code, item.code_length) == ?u16(item.run_length)
			assert !decoder.should_reverse
		}
		for item in ccitt_additional_make_up_codes {
			assert decoder.get_run_length(item.code, item.code_length) == ?u16(item.run_length)
		}
		assert decoder.get_run_length(0, 14) == none
	}
	decoder.current_color = .white
	assert decoder.get_terminating_code(0x35, 8) == ?u16(0)
	assert decoder.get_make_up_code(0x1b, 5) == ?u16(64)
	assert decoder.should_reverse
}

struct CcittCase {
	width    usize
	rows     usize = 1
	input    []u8
	expected []u8
	color    CcittColor = .black
	position u64
}

fn test_ccitt_zero_and_make_up_runs_row_color_and_unflushed_partial_output() {
	for white in [u8(0), 1] {
		for item in [
			CcittCase{
				width:    8
				input:    [u8(0x98)]
				expected: [u8(0xff)]
				position: 1
			},
			CcittCase{
				width:    8
				input:    [u8(0x35), 0x14]
				expected: [u8(0)]
				color:    .white
				position: 2
			},
			CcittCase{
				width:    8
				input:    [u8(0xb6)]
				expected: [u8(0xf0)]
				color:    .white
				position: 1
			},
			CcittCase{
				width:    7
				input:    [u8(0xf0)]
				expected: []
				position: 1
			},
			CcittCase{
				width:    15
				input:    [u8(0xd4)]
				expected: [u8(0xff)]
				position: 1
			},
			CcittCase{
				width:    65
				input:    [u8(0xd8), 0xe0]
				expected: []u8{len: 8, init: 255}
				position: 2
			},
			CcittCase{
				width:    64
				input:    [u8(0xd9), 0xa8]
				expected: []u8{len: 8, init: 255}
				color:    .white
				position: 1
			},
			CcittCase{
				width:    8
				rows:     2
				input:    [u8(0x98), 0x14]
				expected: [u8(255), 0]
				color:    .white
				position: 2
			},
			CcittCase{
				width:    8
				rows:     3
				input:    [u8(0x98), 0x14, 0x13]
				expected: [u8(255), 0, 255]
				position: 3
			},
		] {
			mut reader := ReadStream.init_memory(item.input)
			mut output := []u8{len: item.expected.len}
			mut writer := WriteStream.init_memory(mut output)
			mut decoder := CcittDecoder.init(item.width, item.rows, white)!
			decoder.decode(mut reader, mut writer)!
			expected := if white == 1 { item.expected } else { item.expected.map(it ^ 255) }
			assert writer.buffered() == expected
			assert reader.get_pos() == item.position
			assert decoder.current_color == item.color && !decoder.should_reverse
		}
	}
}

fn test_ccitt_decoder_reuse_preserves_color_and_zero_dimensions_write_no_bytes() {
	mut output := []u8{len: 2}
	mut writer := WriteStream.init_memory(mut output)
	mut reader := ReadStream.init_memory([u8(0x98)])
	mut decoder := CcittDecoder.init(8, 1, 1)!
	decoder.decode(mut reader, mut writer)!
	reader = ReadStream.init_memory([u8(0x14)])
	decoder.decode(mut reader, mut writer)!
	assert writer.buffered() == [u8(255), 0] && decoder.current_color == .white
	for dims in [[usize(0), usize(1)], [usize(8), usize(0)]] {
		reader = ReadStream.init_memory([])
		writer.seek_to(0)!
		decoder = CcittDecoder.init(dims[0], dims[1], 1)!
		decoder.decode(mut reader, mut writer)!
		assert writer.get_pos() == 0 && reader.get_pos() == 0
	}
}

fn test_ccitt_invalid_codes_and_full_output_retain_failure_state() {
	for input in [[]u8{}, [u8(0), 0]] {
		mut reader := ReadStream.init_memory(input)
		mut output := []u8{len: 1}
		mut writer := WriteStream.init_memory(mut output)
		mut decoder := CcittDecoder.init(8, 1, 1)!
		decoder.decode(mut reader, mut writer) or {
			assert err.msg() == 'InvalidData'
			assert reader.get_pos() == u64(input.len) && writer.get_pos() == 0
			assert decoder.current_color == .white && !decoder.should_reverse
			continue
		}
		assert false
	}
	mut reader := ReadStream.init_memory([u8(0x98)])
	mut output := []u8{}
	mut writer := WriteStream.init_memory(mut output)
	mut decoder := CcittDecoder.init(8, 1, 1)!
	decoder.decode(mut reader, mut writer) or {
		assert err.msg() == 'WriteFailed' && reader.get_pos() == 1 && writer.get_pos() == 0
		assert decoder.current_color == .white && decoder.should_reverse
		return
	}
	assert false
}
