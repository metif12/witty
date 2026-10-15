module zigimg

import os

fn test_writer_unused_space_borrows_without_reserving_and_aliases_input() {
	mut bytes := []u8{len: 8, init: 165}
	mut writer := WriteStream.init_memory(mut bytes)
	writer.write_all('ab'.bytes())!
	mut adapter := writer.writer()
	mut tail := adapter.unused_capacity_slice()
	assert adapter.unused_capacity_len() == 6 && writer.get_pos() == 2
	tail[0] = `c`
	bytes[3] = `d`
	assert tail[..2] == 'cd'.bytes() && bytes[..4] == 'abcd'.bytes()
	adapter.advance(2)
	assert writer.buffered() == 'abcd'.bytes() && writer.unused_capacity_len() == 4
	adapter.undo(3)
	assert writer.buffered() == 'a'.bytes() && writer.unused_capacity_len() == 7
	assert tail[..2] == 'cd'.bytes() && bytes[..4] == 'abcd'.bytes()
	writer.advance(7)
	assert writer.unused_capacity_slice().len == 0 && writer.get_pos() == 8
	writer.undo(8)
	assert writer.unused_capacity_len() == 8 && bytes[..4] == 'abcd'.bytes()
}

fn test_writer_empty_buffer_allows_zero_cursor_updates_without_io() {
	mut bytes := []u8{}
	mut writer := WriteStream.init_memory(mut bytes)
	writer.advance(0)
	writer.undo(0)
	assert writer.unused_capacity_slice().len == 0 && writer.unused_capacity_len() == 0
	assert writer.get_pos() == 0 && writer.buffered().len == 0
}

fn test_writer_reserved_output_flushes_to_a_file() {
	$if !windows {
		path := os.join_path(os.temp_dir(), 'witty-writer-buffer-${os.getpid()}.owned')
		mut file := os.create(path)!
		defer { os.rm(path) or {} }
		mut buffer := []u8{len: 8, init: 165}
		mut writer := WriteStream.init_file(file, mut buffer)
		mut tail := writer.unused_capacity_slice()
		for i, byte in 'hello'.bytes() {
			tail[i] = byte
		}
		assert writer.get_pos() == 0 && writer.unused_capacity_len() == 8
		writer.advance(5)
		writer.flush()!
		file.close()
		assert os.read_bytes(path)! == 'hello'.bytes()
		assert writer.get_pos() == 5 && writer.unused_capacity_len() == 8
	}
}
