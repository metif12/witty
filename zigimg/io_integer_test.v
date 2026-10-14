module zigimg

import os

type ReaderIntegerAlias = i64
type ReaderIntegerEndianAlias = BigEndian

fn test_integer_peeks_preserve_cursor_and_decode_both_byte_orders() {
	mut reader := ReadStream.init_memory([u8(0xfe), 0xdc, 0xba, 0x98, 0x76, 0x54, 0x32, 0x10])
	assert reader.peek_int[u64, BigEndian](BigEndian{})! == u64(0xfedcba9876543210)
	assert reader.peek_int[u64, LittleEndian](LittleEndian{})! == u64(0x1032547698badcfe)
	assert reader.peek_int[ReaderIntegerAlias, ReaderIntegerEndianAlias](ReaderIntegerEndianAlias{})! == ReaderIntegerAlias(-81985529216486896)
	assert reader.get_pos() == 0 && reader.buffered_len() == 8
	assert reader.take_var_int[i64, BigEndian](BigEndian{}, 8)! == i64(-81985529216486896)
	assert reader.get_pos() == 8
}

fn test_short_signed_integer_reads_zero_extend_and_empty_reads_succeed_at_eof() {
	for value in 0 .. 256 {
		mut reader := ReadStream.init_memory([u8(value), u8(value)])
		assert reader.take_var_int[i16, BigEndian](BigEndian{}, 1)! == i16(value)
		assert reader.take_var_int[i8, LittleEndian](LittleEndian{}, 1)! == i8(value)
		assert reader.get_pos() == 2
		assert reader.take_var_int[ReaderIntegerAlias, ReaderIntegerEndianAlias](ReaderIntegerEndianAlias{},
			0)! == ReaderIntegerAlias(0)
		assert reader.get_pos() == 2
	}
	mut reader := ReadStream.init_memory([u8(0x80), 0])
	assert reader.take_var_int[i16, BigEndian](BigEndian{}, 2)! == i16(-32768)
}

fn test_integer_file_peeks_retain_read_ahead_and_failed_reads_retain_eof_tail() {
	$if !windows {
		path := os.join_path(os.temp_dir(), 'witty-reader-integer-${os.getpid()}.owned')
		os.write_file(path, 'abcdef')!
		defer { os.rm(path) or {} }
		mut file := os.open(path)!
		defer { file.close() }
		mut buffer := []u8{len: 8, init: 165}
		mut reader := ReadStream.init_file(file, mut buffer)
		assert reader.take_var_int[i64, BigEndian](BigEndian{}, 0)! == 0
		assert reader.get_pos() == 0 && reader.buffered_len() == 0
		assert buffer == []u8{len: 8, init: 165}
		assert reader.peek_int[u16, BigEndian](BigEndian{})! == u16(0x6162)
		assert reader.peek_int[u16, LittleEndian](LittleEndian{})! == u16(0x6261)
		assert reader.get_pos() == 0 && reader.buffered() == 'abcdef'.bytes()
		assert reader.take_var_int[i64, BigEndian](BigEndian{}, 3)! == i64(0x616263)
		mut status := 'ok'
		reader.take_var_int[u64, BigEndian](BigEndian{}, 4) or { status = err.msg() }
		assert status == 'EndOfStream' && reader.get_pos() == 3
		assert reader.buffered() == 'def'.bytes()
		assert reader.take_var_int[int, LittleEndian](LittleEndian{}, 3)! == int(0x666564)
		assert reader.get_pos() == 6
	}
}
