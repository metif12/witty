module zigimg

import os

fn test_writer_header_buffered_and_zero_repetitions() {
	mut bytes := []u8{len: 16, init: 165}
	mut writer := WriteStream.init_memory(mut bytes)
	data := ['b'.bytes(), 'cd'.bytes()]
	assert writer.write_splat_header('a'.bytes(), data, 3)! == 8
	assert writer.buffered() == 'abcdcdcd'.bytes()
	assert writer.write_splat_header_limit('e'.bytes(), data, 0, Limit.limited(2))! == 2
	assert writer.buffered() == 'abcdcdcdeb'.bytes()
	assert data == ['b'.bytes(), 'cd'.bytes()]
	// A zero limit can finish through an empty header vector without touching data.
	assert writer.write_splat_header_limit('header'.bytes(), [][]u8{}, 1, Limit.nothing())! == 0
}

fn test_writer_header_failure_preserves_copied_header_and_prefix() {
	mut bytes := []u8{len: 4, init: 165}
	mut writer := WriteStream.init_memory(mut bytes)
	mut status := 'ok'
	writer.write_splat_header_limit('a'.bytes(), ['bcdef'.bytes(),
		'g'.bytes()], 1, Limit.limited(2)) or { status = err.msg() }
	assert status == 'WriteFailed'
	assert writer.buffered() == 'abcd'.bytes() && writer.get_pos() == 4
}

fn test_writer_header_file_retains_pinned_limit_and_eight_slot_behavior() {
	$if !windows {
		path := os.join_path(os.temp_dir(), 'witty-writer-header-${os.getpid()}.owned')
		mut file := os.create(path)!
		defer { os.rm(path) or {} }
		mut bytes := []u8{}
		mut writer := WriteStream.init_file_streaming(file, mut bytes)
		// Source passes whole prefix vectors and accounts for header.len in its helper.
		assert writer.write_splat_header_limit('a'.bytes(), [
			'bcdef'.bytes(),
			'g'.bytes(),
		], 1, Limit.limited(3))! == 7
		assert writer.write_splat_header('H'.bytes(), ['1'.bytes(),
			'2'.bytes(), '3'.bytes(), '4'.bytes(), '5'.bytes(),
			'6'.bytes(), '7'.bytes(), '8'.bytes(), 'tail'.bytes()], 3)! == 8
		file.close()
		assert os.read_bytes(path)! == 'abcdefgH1234567'.bytes()
	}
}
