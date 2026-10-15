module zigimg

import os

type WriterLebSignedAlias = i64
type WriterLebUnsignedAlias = u64

fn test_leb128_writer_examples_signedness_and_native_extremes() {
	mut bytes := []u8{len: 64, init: 165}
	mut writer := WriteStream.init_memory(mut bytes)
	mut adapter := writer.writer()
	adapter.write_uleb128[u32](624485)!
	adapter.write_sleb128[int](-624485)!
	adapter.write_leb128[i8](-1)!
	adapter.write_sleb128[u8](127)!
	assert writer.buffered() == [u8(0xe5), 0x8e, 0x26, 0x9b, 0xf1, 0x59, 0x7f, 0xff, 0]
	writer.write_sleb128[WriterLebUnsignedAlias](0xffffffffffffffff)!
	writer.write_leb128[WriterLebSignedAlias](-9223372036854775807 - 1)!
	assert writer.buffered()[9..19] == [u8(255), 255, 255, 255, 255, 255, 255, 255, 255, 1]
	assert writer.buffered()[19..29] == [u8(128), 128, 128, 128, 128, 128, 128, 128, 128, 127]
	assert writer.get_pos() == 29 && bytes[29] == 165
}

fn test_leb128_writer_partial_memory_failure_retains_the_encoded_prefix() {
	mut bytes := []u8{len: 2, init: 165}
	mut writer := WriteStream.init_memory(mut bytes)
	mut status := 'ok'
	writer.write_uleb128[u32](624485) or { status = err.msg() }
	assert status == 'WriteFailed' && bytes == [u8(0xe5), 0x8e]
	assert writer.get_pos() == 2 && writer.buffered() == bytes
	status = 'ok'
	writer.write_leb128[int](0) or { status = err.msg() }
	assert status == 'WriteFailed' && bytes == [u8(0xe5), 0x8e]
}

fn test_leb128_writer_file_flush_matches_the_memory_encoding() {
	$if !windows {
		path := os.join_path(os.temp_dir(), 'witty-writer-leb128-${os.getpid()}.owned')
		mut file := os.create(path)!
		defer { os.rm(path) or {} }
		mut buffer := []u8{len: 2, init: 165}
		mut writer := WriteStream.init_file(file, mut buffer)
		writer.write_leb128[i16](-65)!
		writer.write_uleb128[u16](128)!
		writer.write_sleb128[u8](64)!
		writer.flush()!
		file.close()
		assert os.read_bytes(path)! == [u8(0xbf), 0x7f, 0x80, 1, 0xc0, 0]
		assert writer.get_pos() == 6 && writer.buffered().len == 0
	}
}
