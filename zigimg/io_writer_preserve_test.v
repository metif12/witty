module zigimg

import os

fn test_splat_byte_preserve_compacts_buffered_tail() {
	mut bytes := 'abcdefgh'.bytes()
	mut writer := WriteStream.init_memory(mut bytes)
	writer.advance(8)
	writer.splat_byte_preserve(5, `x`, 3)!
	assert writer.buffered() == 'defghxxx'.bytes() && bytes == 'defghxxx'.bytes()
	writer.splat_byte_preserve(~usize(0), `y`, 0)!
	assert writer.buffered() == 'defghxxx'.bytes()
}

fn test_splat_byte_preserve_fixed_failure_precedes_compaction() {
	mut bytes := 'abcdefgh'.bytes()
	mut writer := WriteStream.init_memory(mut bytes)
	writer.advance(8)
	mut status := 'ok'
	writer.splat_byte_preserve(2, `x`, 3) or { status = err.msg() }
	assert status == 'WriteFailed' && writer.buffered() == 'abcdefgh'.bytes()
}

fn test_splat_byte_preserve_streamed_blocks() {
	$if !windows {
		path := os.join_path(os.temp_dir(), 'witty-writer-preserve-${os.getpid()}.owned')
		mut file := os.create(path)!
		defer { os.rm(path) or {} }
		mut bytes := []u8{len: 64}
		mut writer := WriteStream.init_file_streaming(file, mut bytes)
		writer.write_all('prefix'.bytes())!
		writer.splat_byte_preserve(3, 17, 129)!
		assert writer.buffered() == [u8(17), 17, 17] && writer.get_pos() == 135
		writer.flush()!
		file.close()
		mut expected := 'prefix'.bytes()
		expected << []u8{len: 129, init: 17}
		assert os.read_bytes(path)! == expected
	}
}
