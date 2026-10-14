module zigimg

import os

type ReaderFourBytes = [4]u8
type ReaderFourOther = [4]u8
type ReaderByteAlias = u8
type ReaderAliasedBytes = [2]ReaderByteAlias

fn test_peek_array_borrows_without_consuming_and_mutates_input() {
	mut input := 'abcdef'.bytes()
	mut reader := ReadStream.init_memory(input)
	mut value := reader.peek_array[ReaderFourBytes]()!
	assert (*value.value)[..] == 'abcd'.bytes()
	assert reader.get_pos() == 0
	unsafe {
		(*value.value)[1] = `Z`
	}
	assert input == 'aZcdef'.bytes()
	input[2] = `Q`
	assert (*value.value)[..] == 'aZQd'.bytes()
	reader.toss(2)
	assert (*value.value)[..] == 'aZQd'.bytes()
}

fn test_take_array_alias_consumes_only_after_success() {
	mut reader := ReadStream.init_memory('abcdef'.bytes())
	value := reader.take_array[ReaderFourOther]()!
	assert (*value.value)[..] == 'abcd'.bytes() && reader.get_pos() == 4
	mut status := 'ok'
	reader.take_array[[4]u8]() or { status = err.msg() }
	assert status == 'EndOfStream' && reader.get_pos() == 4
	tail := reader.take_array[ReaderAliasedBytes]()!
	assert (*tail.value)[0] == ReaderByteAlias(`e`) && (*tail.value)[1] == ReaderByteAlias(`f`)
	assert reader.get_pos() == 6
}

fn test_array_file_read_ahead_and_partial_eof() {
	$if !windows {
		path := os.join_path(os.temp_dir(), 'witty-reader-array-${os.getpid()}.owned')
		os.write_file(path, 'abcde')!
		defer { os.rm(path) or {} }
		mut file := os.open(path)!
		defer { file.close() }
		mut buffer := []u8{len: 4}
		mut reader := ReadStream.init_file_streaming(file, mut buffer)
		mut value := reader.take_array[ReaderFourBytes]()!
		assert (*value.value)[..] == 'abcd'.bytes() && reader.get_pos() == 4
		unsafe {
			(*value.value)[0] = `Z`
		}
		assert buffer == 'Zbcd'.bytes()
		mut status := 'ok'
		reader.peek_array[ReaderFourBytes]() or { status = err.msg() }
		assert status == 'EndOfStream' && reader.get_pos() == 4
		assert reader.buffered() == 'e'.bytes()
		byte := reader.take_array[[1]u8]()!
		assert (*byte.value)[0] == `e` && reader.get_pos() == 5
	}
}
