module zigimg

import os

fn test_writer_consume_compacts_pending_bytes_and_saved_views() {
	mut bytes := 'abcdefgh'.bytes()
	mut writer := WriteStream.init_memory(mut bytes)
	writer.advance(6)
	saved := writer.buffered()
	assert writer.consume(2) == 0
	assert writer.buffered() == 'cdef'.bytes() && bytes == 'cdefefgh'.bytes()
	assert saved == 'cdefef'.bytes() && writer.get_pos() == 4
	assert writer.consume(7) == 3 && writer.buffered().len == 0
	assert writer.get_pos() == 0 && bytes == 'cdefefgh'.bytes()
	assert writer.consume(~uint(0)) == ~uint(0)
}

fn test_writer_consume_all_drops_pending_without_changing_backing() {
	mut bytes := 'abcdefgh'.bytes()
	mut writer := WriteStream.init_memory(mut bytes)
	writer.advance(5)
	mut saved := writer.buffered()
	assert writer.consume_all() == 0 && writer.buffered().len == 0
	assert bytes == 'abcdefgh'.bytes() && saved == 'abcde'.bytes()
	saved[0] = `x`
	assert bytes == 'xbcdefgh'.bytes()
	writer.write_all('YZ'.bytes())!
	assert writer.buffered() == 'YZ'.bytes() && saved == 'YZcde'.bytes()
	assert writer.consume_all() == 0 && writer.consume_all() == 0
}

fn test_writer_file_consume_keeps_output_accounting_with_the_caller() {
	$if !windows {
		path := os.join_path(os.temp_dir(), 'witty-writer-consume-${os.getpid()}.owned')
		mut file := os.create(path)!
		defer { os.rm(path) or {} }
		mut bytes := []u8{len: 8, init: 165}
		mut writer := WriteStream.init_file(file, mut bytes)
		writer.write_all('abcdef'.bytes())!
		assert writer.consume(2) == 0 && writer.buffered() == 'cdef'.bytes()
		assert writer.get_pos() == 4 && os.read_bytes(path)!.len == 0
		assert writer.consume_all() == 0 && writer.get_pos() == 0
		writer.write_all('xy'.bytes())!
		writer.flush()!
		file.close()
		assert os.read_bytes(path)! == 'xy'.bytes()
	}
}
