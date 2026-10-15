module zigimg

import os

type WriterFourBytes = [4]u8
type WriterByteAlias = u8
type WriterAliasedBytes = [2]WriterByteAlias

fn test_writer_fixed_arrays_reserve_and_alias_caller_storage() {
	mut bytes := []u8{len: 8, init: 165}
	mut writer := WriteStream.init_memory(mut bytes)
	mut adapter := writer.writer()
	mut first := adapter.writable_array[WriterFourBytes]()!
	unsafe {
		(*first.value)[0] = 17
	}
	bytes[1] = 18
	assert (*first.value)[..2] == [u8(17), 18] && writer.get_pos() == 4
	mut next := adapter.writable_array[WriterAliasedBytes]()!
	unsafe {
		(*next.value)[1] = WriterByteAlias(19)
	}
	assert bytes[5] == 19 && writer.get_pos() == 6
	writer.undo(6)
	assert (*first.value)[1] == 18 && (*next.value)[1] == WriterByteAlias(19)
	mut inline := writer.writable_array[[1]u8]()!
	unsafe {
		(*inline.value)[0] = 20
	}
	assert bytes[0] == 20 && (*first.value)[0] == 20 && writer.get_pos() == 1
}

fn test_writer_fixed_array_failure_leaves_memory_unchanged() {
	mut bytes := 'abc'.bytes()
	mut writer := WriteStream.init_memory(mut bytes)
	writer.advance(1)
	writer.writable_array[WriterFourBytes]() or {
		assert err.msg() == 'WriteFailed' && writer.get_pos() == 1
		assert bytes == 'abc'.bytes() && writer.buffered() == 'a'.bytes()
		return
	}
	assert false
}

fn test_writer_preserved_byte_and_array_file_output() {
	$if !windows {
		path := os.join_path(os.temp_dir(), 'witty-writer-array-${os.getpid()}.owned')
		mut file := os.create(path)!
		defer { os.rm(path) or {} }
		mut bytes := []u8{len: 8, init: 165}
		mut writer := WriteStream.init_file(file, mut bytes)
		writer.write_all('abcdefgh'.bytes())!
		writer.write_byte_preserve(5, `i`)!
		assert writer.buffered() == 'defghi'.bytes() && writer.get_pos() == 9
		assert os.read_bytes(path)! == 'abc'.bytes()
		mut reserved := writer.writable_array[WriterFourBytes]()!
		assert writer.get_pos() == 13 && os.read_bytes(path)! == 'abcdefghi'.bytes()
		unsafe {
			for i, byte in 'jklm'.bytes() {
				(*reserved.value)[i] = byte
			}
		}
		writer.write_byte_preserve(~usize(0), `n`)!
		writer.flush()!
		file.close()
		assert os.read_bytes(path)! == 'abcdefghijklmn'.bytes()
	}
}
