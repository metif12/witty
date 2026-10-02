module synthetic

import os

fn test_file_writer_keeps_a_full_buffer_until_drain_and_flush() {
	path := os.join_path(os.temp_dir(), 'witty-source-writer-${os.getpid()}')
	defer { os.rm(path) or {} }
	mut file := os.create(path)!
	defer { file.close() }
	mut writer := FileWriter{
		fd: file.fd
	}
	data := []u8{len: 2048, init: `a`}
	source_write_all(mut writer, data)!
	assert writer.end == 2048
	assert os.file_size(path) == 0
	source_write_all(mut writer, 'b'.bytes())!
	assert writer.end == 1
	assert os.file_size(path) == 2048
	writer.flush()!
	assert writer.end == 0
	mut expected := data.clone()
	expected << u8(`b`)
	assert os.read_bytes(path)! == expected
}
