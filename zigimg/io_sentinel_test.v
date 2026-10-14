module zigimg

import os

fn test_sentinel_peek_borrows_prefix_and_terminator_without_consuming() {
	mut input := [u8(`a`), `b`, 0, `c`]
	mut reader := ReadStream.init_memory(input)
	view := reader.peek_sentinel(0)!
	mut bytes := view.bytes()
	assert bytes == 'ab'.bytes() && view.with_sentinel() == [u8(`a`), `b`, 0]
	assert reader.get_pos() == 0
	input[0] = `Z`
	assert bytes[0] == `Z`
	bytes[1] = `Q`
	assert input == [u8(`Z`), `Q`, 0, `c`]
	reader.toss_buffered()
	assert view.bytes() == 'ZQ'.bytes() && view.with_sentinel()[2] == 0
}

fn test_sentinel_take_consumes_empty_prefix_and_rejects_unterminated_tail() {
	mut reader := ReadStream.init_memory([u8(255), `a`, 255, `z`])
	empty := reader.take_sentinel(255)!
	assert empty.bytes().len == 0 && empty.with_sentinel() == [u8(255)]
	assert reader.get_pos() == 1
	value := reader.take_sentinel(255)!
	assert value.bytes() == 'a'.bytes() && reader.get_pos() == 3
	mut status := 'ok'
	reader.take_sentinel(255) or { status = err.msg() }
	assert status == 'EndOfStream' && reader.get_pos() == 3
	assert reader.buffered() == 'z'.bytes()
}

fn test_sentinel_file_retains_full_buffer_and_eof_tail() {
	$if !windows {
		path := os.join_path(os.temp_dir(), 'witty-reader-sentinel-${os.getpid()}.owned')
		os.write_file_array(path, [u8(`a`), 0, `z`])!
		defer { os.rm(path) or {} }
		mut file := os.open(path)!
		defer { file.close() }
		mut buffer := []u8{len: 2}
		mut reader := ReadStream.init_file_streaming(file, mut buffer)
		value := reader.take_sentinel(0)!
		assert value.bytes() == 'a'.bytes() && reader.get_pos() == 2
		mut status := 'ok'
		reader.peek_sentinel(0) or { status = err.msg() }
		assert status == 'EndOfStream' && reader.get_pos() == 2
		assert reader.buffered() == 'z'.bytes()

		mut full := ReadStream.init_file(file, mut buffer)
		status = 'ok'
		full.peek_sentinel(255) or { status = err.msg() }
		assert status == 'StreamTooLong' && full.get_pos() == 0
		assert full.buffered() == [u8(`a`), 0]
	}
}
