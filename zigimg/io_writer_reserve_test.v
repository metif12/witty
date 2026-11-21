module zigimg

import os

fn test_writer_reservations_alias_and_advance_only_exact_slices() {
	mut bytes := []u8{len: 8, init: 165}
	mut writer := WriteStream.init_memory(mut bytes)
	writer.write_all('ab'.bytes())!
	mut adapter := writer.writer()
	mut greedy := adapter.writable_slice_greedy_preserve(~uint(0), 2)!
	assert greedy.len == 6 && writer.get_pos() == 2
	greedy[0] = `c`
	mut exact := adapter.writable_slice(2)!
	exact[1] = `d`
	assert writer.buffered() == 'abcd'.bytes() && greedy[..2] == 'cd'.bytes()
	writer.ensure_unused_capacity(4)!
	writer.rebase(~uint(0), 0)!
	assert writer.get_pos() == 4 && bytes[..4] == 'abcd'.bytes()
}

fn test_writer_fixed_reservations_fail_before_mutation() {
	mut bytes := 'abcd'.bytes()
	mut writer := WriteStream.init_memory(mut bytes)
	writer.advance(3)
	writer.writable_slice_preserve(1, 2) or {
		assert err.msg() == 'WriteFailed'
		assert writer.buffered() == 'abc'.bytes() && bytes == 'abcd'.bytes()
		return
	}
	assert false
}

fn test_writer_rebase_preserves_tail_and_returns_live_file_reservations() {
	$if !windows {
		path := os.join_path(os.temp_dir(), 'witty-writer-reserve-${os.getpid()}.owned')
		mut file := os.create(path)!
		defer { os.rm(path) or {} }
		mut bytes := []u8{len: 8, init: 165}
		mut writer := WriteStream.init_file(file, mut bytes)
		writer.write_all('abcdef'.bytes())!
		mut tail := writer.writable_slice_greedy_preserve(3, 4)!
		assert writer.get_pos() == 6 && writer.buffered() == 'def'.bytes()
		assert tail.len == 5 && os.read_bytes(path)! == 'abc'.bytes()
		tail[0] = `g`
		mut reserved := writer.writable_slice_preserve(3, 2)!
		reserved[1] = `h`
		assert writer.buffered() == 'defgh'.bytes()
		writer.flush()!
		file.close()
		assert os.read_bytes(path)! == 'abcdefgh'.bytes() && writer.get_pos() == 8
	}
}
