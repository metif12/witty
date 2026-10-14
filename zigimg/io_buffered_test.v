module zigimg

import os

fn test_buffered_reader_views_borrow_storage_without_consuming() {
	mut data := [u8(0x7f), 0x80, 0xff, 0]
	mut reader := ReadStream.init_memory(data)
	mut adapter := reader.reader()
	mut view := unsafe { adapter.buffered() }
	copy := view.clone()
	data[0] = 1
	assert view == [u8(1), 0x80, 0xff, 0] && copy[0] == 0x7f
	view[1] = 2
	assert data[1] == 2 && reader.get_pos() == 0
	assert adapter.peek_greedy(0)! == data
	assert adapter.peek_byte()! == 1 && reader.get_pos() == 0
	adapter.toss_buffered()
	assert reader.get_pos() == 4 && adapter.buffered().len == 0
	assert view == data
	adapter.fill(0)!
	assert adapter.peek_greedy(0)!.len == 0
	mut status := 'ok'
	adapter.peek_byte() or { status = err.msg() }
	assert status == 'EndOfStream' && reader.get_pos() == 4
}

fn test_signed_byte_reads_preserve_all_bit_patterns() {
	for value in 0 .. 256 {
		mut reader := ReadStream.init_memory([u8(value)])
		assert reader.peek_byte()! == u8(value) && reader.get_pos() == 0
		signed := reader.take_byte_signed()!
		assert int(signed) == if value < 128 {
			value
		} else {
			value - 256
		}
		assert reader.get_pos() == 1 && reader.buffered().len == 0
	}
}

fn test_greedy_file_peeks_include_read_ahead_and_empty_peeks_do_not_read() {
	$if !windows {
		path := os.join_path(os.temp_dir(), 'witty-reader-buffered-${os.getpid()}.owned')
		os.write_file(path, 'abcdefghi')!
		defer { os.rm(path) or {} }
		mut file := os.open(path)!
		defer { file.close() }
		mut buffer := []u8{len: 4, init: 165}
		mut reader := ReadStream.init_file(file, mut buffer)
		assert reader.buffered().len == 0 && reader.get_pos() == 0
		reader.fill(0)!
		assert reader.peek_greedy(0)!.len == 0 && buffer == [u8(165), 165, 165, 165]
		reader.fill(1)!
		assert reader.get_pos() == 0 && reader.buffered() == 'abcd'.bytes()
		mut view := unsafe { reader.peek_greedy(1)! }
		assert view == 'abcd'.bytes()
		view[0] = `A`
		assert buffer[0] == `A` && reader.peek_byte()! == `A`
		reader.toss_buffered()
		assert reader.get_pos() == 4 && reader.buffered().len == 0 && view == 'Abcd'.bytes()
		reader.fill(1)!
		assert reader.get_pos() == 4 && reader.peek_greedy(1)! == 'efgh'.bytes()
	}
}

fn test_failed_fill_preserves_short_file_tail_and_retries() {
	$if !windows {
		path := os.join_path(os.temp_dir(), 'witty-reader-short-fill-${os.getpid()}.owned')
		os.write_file(path, 'abc')!
		defer { os.rm(path) or {} }
		mut file := os.open(path)!
		defer { file.close() }
		mut buffer := []u8{len: 8, init: 165}
		mut reader := ReadStream.init_file(file, mut buffer)
		for _ in 0 .. 2 {
			mut status := 'ok'
			reader.fill(4) or { status = err.msg() }
			assert status == 'EndOfStream' && reader.get_pos() == 0
			assert reader.buffered() == 'abc'.bytes()
		}
		assert reader.peek_greedy(1)! == 'abc'.bytes()
		reader.toss_buffered()
		assert reader.get_pos() == 3 && reader.peek_greedy(0)!.len == 0
	}
}
