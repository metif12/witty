module zigimg

import os

type ReaderLeb128Alias = i64

fn test_leb128_signed_values_and_full_64_bit_limits() {
	mut reader := ReadStream.init_memory([u8(0xe5), 0x8e, 0x26, 0x9b, 0xf1, 0x59])
	assert reader.take_leb128[u32]()! == u32(624485)
	assert reader.take_leb128[int]()! == -624485
	assert reader.get_pos() == 6
	mut maximum := ReadStream.init_memory([u8(0xff), 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
		0xff, 0x01])
	assert maximum.take_leb128[u64]()! == ~u64(0)
	mut minimum := ReadStream.init_memory([u8(0x80), 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80,
		0x80, 0x7f])
	assert minimum.take_leb128[ReaderLeb128Alias]()! == ReaderLeb128Alias(-9223372036854775807 - 1)
}

fn test_leb128_overflow_consumes_through_terminator_and_accepts_sign_extension() {
	mut reader := ReadStream.init_memory([u8(0xff), 0x82, 0x00, 0x01])
	mut status := 'ok'
	reader.take_leb128[u8]() or { status = err.msg() }
	assert status == 'Overflow' && reader.get_pos() == 3
	assert reader.take_leb128[u8]()! == 1
	mut negative := ReadStream.init_memory([u8(0xff), 0xff, 0xff, 0x7f])
	negative_value := negative.take_leb128[i8]()!
	assert negative_value == -1
	assert negative.get_pos() == 4
	mut truncated := ReadStream.init_memory([u8(0xff), 0x82, 0x80])
	status = 'ok'
	truncated.take_leb128[u8]() or { status = err.msg() }
	assert status == 'EndOfStream' && truncated.get_pos() == 3
}

fn test_leb128_file_refills_preserve_terminator_tail_and_partial_eof_progress() {
	$if !windows {
		path := os.join_path(os.temp_dir(), 'witty-reader-leb128-${os.getpid()}.owned')
		data := [u8(0xe5), 0x8e, 0x26, 0x01, 0x80, 0x80]
		os.write_file_array(path, data)!
		defer { os.rm(path) or {} }
		mut file := os.open(path)!
		defer { file.close() }
		mut buffer := []u8{len: 2, init: 165}
		mut reader := ReadStream.init_file(file, mut buffer)
		assert reader.take_leb128[u32]()! == u32(624485)
		assert reader.get_pos() == 3 && reader.buffered() == [u8(1)]
		byte_value := reader.take_leb128[u8]()!
		assert byte_value == 1
		assert reader.get_pos() == 4
		mut status := 'ok'
		reader.take_leb128[u8]() or { status = err.msg() }
		assert status == 'EndOfStream' && reader.get_pos() == 6
		assert reader.buffered_len() == 0
	}
}
