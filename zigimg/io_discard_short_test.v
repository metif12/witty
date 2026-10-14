module zigimg

import os

fn test_short_memory_discard_returns_eof_prefix_and_all64_reports_short_input() {
	mut reader := ReadStream.init_memory('abc'.bytes())
	first := reader.discard_short(2)!
	assert first == 2 && reader.get_pos() == 2
	last := reader.discard_short(100)!
	assert last == 1 && reader.get_pos() == 3
	assert reader.discard_short(0)! == 0
	mut exact := ReadStream.init_memory('abc'.bytes())
	mut status := 'ok'
	exact.discard_all64(4) or { status = err.msg() }
	assert status == 'EndOfStream' && exact.get_pos() == 3
	exact.discard_all64(0)!
}

fn test_discard_remaining_consumes_only_the_memory_pending_span() {
	mut reader := ReadStream.init_memory('abcdef'.bytes())
	reader.toss(2)
	count := reader.discard_remaining()!
	assert count == 4 && reader.get_pos() == 6 && reader.buffered_len() == 0
	assert reader.discard_remaining()! == 0
}

fn test_streaming_file_discard_preserves_buffer_and_returns_partial_eof_count() {
	$if !windows {
		path := os.join_path(os.temp_dir(), 'witty-reader-discard-short-${os.getpid()}.owned')
		os.write_file(path, 'abcdefghij')!
		defer { os.rm(path) or {} }
		mut file := os.open(path)!
		defer { file.close() }
		mut buffer := []u8{len: 4, init: 165}
		mut reader := ReadStream.init_file_streaming(file, mut buffer)
		reader.fill(4)!
		reader.toss(1)
		before := buffer.clone()
		short := reader.discard_short(6)!
		assert short == 6 && reader.get_pos() == 7 && buffer == before
		remaining := reader.discard_remaining()!
		assert remaining == 3 && reader.get_pos() == 10 && buffer == before
		assert reader.discard_short(2)! == 0 && reader.get_pos() == 10
	}
}
