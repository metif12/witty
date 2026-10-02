module zigimg

import os

fn test_file_reader_preserves_positional_start_read_ahead_and_seek_by_workaround() {
	path := os.join_path(os.temp_dir(), 'witty-zigimg-reader-${os.getpid()}')
	os.write_file(path, '0123456789abcdefghijklmnop')!
	defer { os.rm(path) or {} }
	mut file := os.open(path)!
	defer { file.close() }
	file.seek(7, .start)!
	mut buffer := []u8{len: 8}
	mut reader := ReadStream.init_file(file, mut buffer)
	assert reader.get_pos() == 0
	assert reader.get_end_pos()! == 26
	assert reader.take(5)!.bytestr() == '01234'
	assert reader.file_pos == 8 && reader.get_pos() == 5
	assert file.tell()! == 7
	reader.seek_by(4)!
	assert reader.get_pos() == 12 // source uses physical pos, not logical pos
	assert reader.take(2)!.bytestr() == 'cd'
	reader.seek_to(0)!
	mut destination := []u8{len: 3}
	assert reader.read_slice_short(mut destination)! == 3
	assert destination.bytestr() == '012'
	$if !windows { assert reader.file_pos == 11 && reader.end == 8 }
	reader.seek_to(25)!
	mut short := []u8{len: 3, init: 0xa5}
	reader.read_slice_all(mut short) or { assert err.msg() == 'EndOfStream' }
	assert short == [u8(`p`), 0xa5, 0xa5]
	assert reader.get_pos() == 26
	reader.seek_to(26) or { assert err.msg() == 'Unseekable' }
}

fn test_file_writer_buffering_flush_seeks_and_image_api() {
	path := os.join_path(os.temp_dir(), 'witty-zigimg-writer-${os.getpid()}')
	defer { os.rm(path) or {} }
	mut file := os.create(path)!
	defer { file.close() }
	mut buffer := []u8{len: 4}
	mut writer := WriteStream.init_file(file, mut buffer)
	writer.write_all('abc'.bytes())!
	assert writer.get_pos() == 3
	assert os.file_size(path) == 0
	writer.write_all('defgh'.bytes())!
	assert writer.get_pos() == 8
	writer.seek_to(2)!
	writer.write_all('XY'.bytes())!
	writer.flush()!
	assert os.read_file(path)! == 'abXYefgh'
	image := Image.from_raw_pixels(2, 1, [u8(1), 2, 3, 4, 5, 6], .rgb24)!
	image.write_to_file_path(path, mut buffer, QoiEncoderOptions{})!
	mut read_buffer := []u8{len: 256}
	decoded := Image.from_file_path(path, mut read_buffer)!
	assert decoded.raw_bytes() == image.raw_bytes()
	assert Image.detect_format_from_file_path(path, mut read_buffer)! == .qoi
}
