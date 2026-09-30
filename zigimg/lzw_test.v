module zigimg

struct LzwCode {
	value u16
	bits  u16 = 3
}

fn lzw_test_stream[E](codes []LzwCode) ![]u8 {
	mut output := []u8{len: 20000}
	mut writer := WriteStream.init_memory(mut output)
	mut bits := BitWriter[E]{
		writer: unsafe { &writer }
	}
	for code in codes {
		bits.write_bits[E, u16](code.value, code.bits)!
	}
	bits.flush_bits()!
	return writer.buffered().clone()
}

fn lzw_test_literal_stream[E](initial u8, early u8, count int) ![]u8 {
	mut codes := [LzwCode{ value: u16(1) << initial, bits: u16(initial + 1) }]
	mut next := (u16(1) << initial) + 2
	mut width := u16(initial + 1)
	root_count := int(u16(1) << initial)
	for i in 0 .. count {
		codes << LzwCode{
			value: u16(i % root_count)
			bits:  width
		}
		if i > 0 {
			next++
			if next == (u16(1) << width) - early && width < 12 { width++ }
		}
	}
	codes << LzwCode{
		value: (u16(1) << initial) + 1
		bits:  width
	}
	return lzw_test_stream[E](codes)!
}

fn lzw_test_dictionary_paths[E]() ! {
	for codes, expected in {
		'known': [u8(0), u8(1), u8(0), u8(1)]
		'next':  [u8(1), u8(1), u8(1)]
		'other': [u8(1), u8(1), u8(1), u8(2)]
		'first': [u8(1)]
	} {
		sequence := match codes {
			'known' {
				[LzwCode{ value: 4 }, LzwCode{ value: 0 }, LzwCode{ value: 1 },
					LzwCode{ value: 6 }, LzwCode{ value: 5, bits: 4 }]
			}
			'next' {
				[LzwCode{ value: 4 }, LzwCode{ value: 1 }, LzwCode{ value: 6 },
					LzwCode{ value: 5 }]
			}
			'other' {
				[LzwCode{ value: 4 }, LzwCode{ value: 1 }, LzwCode{ value: 7 },
					LzwCode{ value: 2 }, LzwCode{ value: 5 }]
			}
			else {
				[LzwCode{ value: 7 }, LzwCode{ value: 1 }, LzwCode{ value: 5 }]
			}
		}

		input := lzw_test_stream[E](sequence)!
		mut reader := ReadStream.init_memory(input)
		mut output := []u8{len: 100}
		mut writer := WriteStream.init_memory(mut output)
		mut decoder := lzw_decoder_init[E](2, 0)!
		decoder.decode(mut reader, mut writer)!
		assert writer.buffered() == expected
		assert reader.get_pos() == u64(input.len)
		assert decoder.remaining_data == none
		if codes == 'known' {
			assert decoder.dictionary[6] == [u8(0), u8(1)]
			assert decoder.dictionary[7] == [u8(1), u8(0)]
			assert decoder.next_code == 8 && decoder.code_size == 3
		} else if codes == 'next' || codes == 'other' {
			assert decoder.dictionary[6] == [u8(1), u8(1)]
			assert 7 !in decoder.dictionary
			assert decoder.next_code == 7 && decoder.code_size == 2
		}
		decoder.deinit()
	}
}

fn test_lzw_known_dictionary_absent_code_and_ignored_invalid_code_paths() {
	lzw_test_dictionary_paths[LittleEndian]()!
	lzw_test_dictionary_paths[BigEndian]()!
	mut reader := ReadStream.init_memory([u8(0x4c), 0x01])
	mut output := []u8{len: 4}
	mut writer := WriteStream.init_memory(mut output)
	mut decoder := LzwDecoder.init[LittleEndian](2, 0)!
	decoder.decode(mut reader, mut writer)!
	assert writer.buffered() == [u8(1)]
}

fn lzw_test_code_sizes[E]() ! {
	for early in [u8(0), u8(1)] {
		for initial in [u8(2), u8(8)] {
			count := 5120
			mut reader := ReadStream.init_memory(lzw_test_literal_stream[E](initial, early, count)!)
			mut output := []u8{len: count}
			mut writer := WriteStream.init_memory(mut output)
			mut decoder := lzw_decoder_init[E](initial, early)!
			decoder.decode(mut reader, mut writer)!
			assert writer.get_pos() == u64(count)
			root_count := int(u16(1) << initial)
			for i, byte in writer.buffered() {
				assert byte == u8(i % root_count)
			}
			assert decoder.code_size == 11
			assert decoder.next_code == (u16(1) << initial) + 1 + u16(count)
			assert decoder.dictionary.len == int((u16(1) << initial) + u16(count) - 1)
			assert decoder.remaining_data == none
		}
	}
}

fn test_lzw_early_change_both_endian_orders_and_maximum_code_size() {
	lzw_test_code_sizes[LittleEndian]()!
	lzw_test_code_sizes[BigEndian]()!
}

fn lzw_test_continuation[E]() ! {
	input := lzw_test_stream[E]([LzwCode{ value: 4 }, LzwCode{ value: 1 },
		LzwCode{ value: 6 }, LzwCode{ value: 5 }])!
	mut reader := ReadStream.init_memory(input[..1])
	mut output := []u8{len: 20}
	mut writer := WriteStream.init_memory(mut output)
	mut decoder := lzw_decoder_init[E](2, 0)!
	decoder.decode(mut reader, mut writer)!
	assert writer.buffered() == [u8(1)] && reader.get_pos() == 1
	assert decoder.remaining_bits == 1 && decoder.previous_code == ?u16(1)
	$if E is LittleEndian {
		assert decoder.remaining_data == ?u16(2)
	} $else {
		assert decoder.remaining_data == ?u16(3)
	}
	reader = ReadStream.init_memory(input[1..])
	decoder.decode(mut reader, mut writer)!
	assert writer.buffered() == [u8(1), u8(1), u8(1)] && reader.get_pos() == 1
	assert decoder.remaining_data == none && decoder.previous_code == ?u16(6)
	assert decoder.dictionary[6] == [u8(1), u8(1)] && decoder.next_code == 7
}

fn test_lzw_partial_code_continuation_and_empty_resume_discards_pending_data() {
	lzw_test_continuation[LittleEndian]()!
	lzw_test_continuation[BigEndian]()!
	mut reader := ReadStream.init_memory([u8(0x8c)])
	mut output := []u8{len: 20}
	mut writer := WriteStream.init_memory(mut output)
	mut decoder := LzwDecoder.init[LittleEndian](2, 0)!
	decoder.decode(mut reader, mut writer)!
	assert decoder.remaining_data != none
	reader = ReadStream.init_memory([])
	decoder.decode(mut reader, mut writer)!
	assert decoder.remaining_data == none && decoder.remaining_bits == 1
	assert decoder.previous_code == ?u16(1) && writer.buffered() == [u8(1)]
}

fn test_lzw_first_partial_code_is_processed_and_initial_empty_input_is_successful() {
	mut output := []u8{len: 20}
	mut writer := WriteStream.init_memory(mut output)
	mut reader := ReadStream.init_memory([u8(65)])
	mut decoder := LzwDecoder.init[LittleEndian](8, 0)!
	decoder.decode(mut reader, mut writer)!
	assert writer.buffered() == [u8(65)] && decoder.previous_code == ?u16(65)
	assert decoder.remaining_data == ?u16(0) && decoder.remaining_bits == 9
	assert decoder.next_code == 258
	writer.seek_to(0)!
	reader = ReadStream.init_memory([u8(32)])
	mut big := LzwDecoder.init[BigEndian](8, 0)!
	big.decode(mut reader, mut writer)!
	assert writer.buffered() == [u8(32)] && big.previous_code == ?u16(32)
	assert big.remaining_data == ?u16(0) && big.remaining_bits == 9
	reader = ReadStream.init_memory([])
	mut empty := LzwDecoder.init[LittleEndian](2, 0)!
	empty.decode(mut reader, mut writer)!
	assert empty.remaining_data == none && empty.previous_code == none
}

fn lzw_test_writer_errors[E]() ! {
	for absent in [false, true] {
		sequence := if absent {
			[LzwCode{ value: 4 }, LzwCode{ value: 1 }, LzwCode{ value: 6 },
				LzwCode{ value: 5 }]
		} else {
			[LzwCode{ value: 4 }, LzwCode{ value: 0 }, LzwCode{ value: 1 },
				LzwCode{ value: 6 }, LzwCode{ value: 5, bits: 4 }]
		}
		mut reader := ReadStream.init_memory(lzw_test_stream[E](sequence)!)
		capacity := if absent { 2 } else { 3 }
		mut output := []u8{len: int(capacity)}
		mut writer := WriteStream.init_memory(mut output)
		mut decoder := lzw_decoder_init[E](2, 0)!
		decoder.decode(mut reader, mut writer) or {
			assert err.msg() == 'WriteFailed' && writer.get_pos() == u64(output.len)
			assert reader.get_pos() == 2 && decoder.previous_code == ?u16(1)
			assert decoder.next_code == if absent {
				u16(6)
			} else {
				u16(7)
			}
			assert decoder.dictionary[6] == if absent {
				[u8(1), u8(1)]
			} else {
				[u8(0), u8(1)]
			}
			assert 7 !in decoder.dictionary
			assert writer.buffered() == if absent {
				[u8(1), u8(1)]
			} else {
				[u8(0), u8(1), u8(0)]
			}
			continue
		}
		assert false
	}
}

fn test_lzw_dictionary_mutation_order_when_output_is_full() {
	lzw_test_writer_errors[LittleEndian]()!
	lzw_test_writer_errors[BigEndian]()!
}
