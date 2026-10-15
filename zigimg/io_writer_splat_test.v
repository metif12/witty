module zigimg

import os

fn test_writer_splat_repeats_only_tail_and_preserves_inputs() {
	mut bytes := []u8{len: 16, init: 165}
	mut writer := WriteStream.init_memory(mut bytes)
	tail := 'bc'.bytes()
	data := ['a'.bytes(), []u8{}, tail]
	assert writer.write_splat(data, 3)! == 7
	assert writer.buffered() == 'abcbcbc'.bytes() && tail == 'bc'.bytes()
	assert writer.write_splat(['d'.bytes(), tail], 0)! == 1
	assert writer.splat_byte(`e`, 2)! == 2
	assert writer.splat_bytes('fg'.bytes(), 2)! == 4
	assert writer.buffered() == 'abcbcbcdeefgfg'.bytes()
	assert writer.splat_bytes([]u8{}, ~usize(0))! == 0
}

fn test_writer_splat_memory_failure_keeps_partial_pattern() {
	mut bytes := []u8{len: 5, init: 165}
	mut writer := WriteStream.init_memory(mut bytes)
	mut status := 'ok'
	writer.write_splat(['a'.bytes(), 'bc'.bytes()], 3) or { status = err.msg() }
	assert status == 'WriteFailed' && writer.buffered() == 'abcbc'.bytes()
	assert writer.get_pos() == 5
}

fn test_writer_splat_file_output_uses_spare_scratch_space() {
	$if !windows {
		path := os.join_path(os.temp_dir(), 'witty-writer-splat-${os.getpid()}.owned')
		mut file := os.create(path)!
		defer { os.rm(path) or {} }
		mut bytes := []u8{len: 64, init: 165}
		mut writer := WriteStream.init_file_streaming(file, mut bytes)
		assert writer.splat_byte(17, 129)! == 129
		assert writer.get_pos() == 129 && writer.buffered().len == 0
		assert bytes == []u8{len: 64, init: 17}
		assert writer.splat_bytes('ab'.bytes(), 2)! == 4
		writer.flush()!
		file.close()
		mut expected := []u8{len: 129, init: 17}
		expected << 'abab'.bytes()
		assert os.read_bytes(path)! == expected
	}
}
