module zigimg

import os

fn test_writer_all_vectors_restore_headers_on_fixed_failure() {
	mut bytes := []u8{len: 5, init: 165}
	mut writer := WriteStream.init_memory(mut bytes)
	tail := 'cdef'.bytes()
	mut data := ['ab'.bytes(), []u8{}, tail]
	mut status := 'ok'
	writer.write_vec_all(mut data) or { status = err.msg() }
	assert status == 'WriteFailed' && writer.buffered() == 'abcde'.bytes()
	assert data == ['ab'.bytes(), []u8{}, 'cdef'.bytes()] && tail == 'cdef'.bytes()
}

fn test_writer_all_repetitions_and_empty_vectors() {
	mut bytes := []u8{len: 24}
	mut writer := WriteStream.init_memory(mut bytes)
	mut empty := [][]u8{}
	writer.write_vec_all(mut empty)!
	writer.write_splat_all(mut empty, ~usize(0))!
	mut data := ['ba'.bytes(), 'na'.bytes()]
	writer.write_splat_all(mut data, 2)!
	writer.splat_byte_all(`!`, 2)!
	writer.splat_bytes_all('xy'.bytes(), 3)!
	writer.splat_bytes_all([]u8{}, ~usize(0))!
	assert writer.buffered() == 'banana!!xyxyxy'.bytes()
	assert data == ['ba'.bytes(), 'na'.bytes()]
}

fn test_writer_all_positional_retries_restore_input_headers() {
	$if !windows {
		path := os.join_path(os.temp_dir(), 'witty-writer-all-${os.getpid()}.owned')
		mut file := os.create(path)!
		defer { os.rm(path) or {} }
		mut bytes := []u8{len: 1}
		mut writer := WriteStream.init_file(file, mut bytes)
		mut data := ['a'.bytes(), []u8{}, 'bc'.bytes()]
		writer.write_splat_all(mut data, 3)!
		writer.write_vec_all(mut data)!
		writer.splat_byte_all(`!`, 129)!
		writer.splat_bytes_all('xy'.bytes(), 3)!
		writer.flush()!
		assert writer.get_pos() == 145
		file.close()
		mut expected := 'abcbcbcabc'.bytes()
		expected << []u8{len: 129, init: `!`}
		expected << 'xyxyxy'.bytes()
		assert os.read_bytes(path)! == expected
		assert data == ['a'.bytes(), []u8{}, 'bc'.bytes()]
	}
}
