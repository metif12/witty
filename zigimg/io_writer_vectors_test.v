module zigimg

import os

fn test_writer_vectors_count_tail_and_preserve_input_headers() {
	mut bytes := []u8{len: 8}
	mut writer := WriteStream.init_memory(mut bytes)
	first := 'ab'.bytes()
	last := 'c'.bytes()
	data := [first, []u8{}, last, last]
	assert count_splat(data, 3) == 6
	assert count_splat(data, 0) == 3
	assert writer.write_vec(data)! == 4
	assert writer.buffered() == 'abcc'.bytes() && writer.get_pos() == 4
	assert data == [first, []u8{}, last, last] && data[2].data == data[3].data
}

fn test_writer_vectors_fixed_failure_retains_partial_prefix() {
	mut bytes := []u8{len: 5, init: 165}
	mut writer := WriteStream.init_memory(mut bytes)
	writer.write_byte(`a`)!
	mut status := 'ok'
	writer.write_vec(['bc'.bytes(), []u8{}, 'def'.bytes()]) or { status = err.msg() }
	assert status == 'WriteFailed' && writer.buffered() == 'abcde'.bytes()
	assert writer.get_pos() == 5 && bytes == 'abcde'.bytes()
	assert writer.write_vec([[]u8{}])! == 0
}

fn test_writer_vectors_file_drain_respects_slot_limit() {
	$if !windows {
		path := os.join_path(os.temp_dir(), 'witty-writer-vectors-${os.getpid()}.owned')
		mut file := os.create(path)!
		defer { os.rm(path) or {} }
		mut buffer := []u8{}
		mut writer := WriteStream.init_file_streaming(file, mut buffer)
		mut data := [][]u8{}
		for i in 0 .. 17 {
			data << [u8(i)]
		}
		assert writer.write_vec(data)! == 16
		assert writer.get_pos() == 16 && writer.buffered().len == 0
		assert writer.write_vec(data[16..])! == 1
		file.close()
		assert os.read_bytes(path)! == []u8{len: 17, init: u8(index)}
	}
}
