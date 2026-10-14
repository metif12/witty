module zigimg

import os

type AllocSigned = i16
type AllocBig = BigEndian

fn test_read_alloc_returns_storage_independent_of_input_and_later_results() {
	input := 'abcdef'.bytes()
	mut reader := ReadStream.init_memory(input)
	mut first := reader.read_alloc(2)!
	second := reader.read_alloc(2)!
	first[0] = `Z`
	assert first == 'Zb'.bytes() && second == 'cd'.bytes()
	assert input == 'abcdef'.bytes() && reader.get_pos() == 4
	mut status := 'ok'
	reader.read_alloc(3) or { status = err.msg() }
	assert status == 'EndOfStream' && reader.get_pos() == 6
	assert first == 'Zb'.bytes() && second == 'cd'.bytes()
	empty := reader.read_alloc(0)!
	assert empty.len == 0 && reader.get_pos() == 6
}

fn test_allocated_endian_slices_decode_aliases_and_retain_eof_progress() {
	mut reader := ReadStream.init_memory([u8(0x12), 0x34, 0xff, 0xfe, 0x56])
	values := reader.read_slice_endian_alloc[AllocSigned, AllocBig](2, AllocBig{})!
	assert values == [AllocSigned(0x1234), AllocSigned(-2)]
	mut status := 'ok'
	reader.read_slice_endian_alloc[u16, BigEndian](1, BigEndian{}) or { status = err.msg() }
	assert status == 'EndOfStream' && reader.get_pos() == 5
	assert values == [AllocSigned(0x1234), AllocSigned(-2)]
	empty := reader.read_slice_endian_alloc[u64, LittleEndian](0, LittleEndian{})!
	assert empty.len == 0 && reader.get_pos() == 5
}

fn test_allocated_endian_file_read_exceeds_the_reader_buffer() {
	$if !windows {
		path := os.join_path(os.temp_dir(), 'witty-reader-alloc-${os.getpid()}.owned')
		os.write_file_array(path, [u8(0x34), 0x12, 0x78, 0x56, 0xbc, 0x9a])!
		defer { os.rm(path) or {} }
		mut file := os.open(path)!
		defer { file.close() }
		mut buffer := []u8{len: 1}
		mut reader := ReadStream.init_file_streaming(file, mut buffer)
		values := reader.read_slice_endian_alloc[u16, LittleEndian](3, LittleEndian{})!
		assert values == [u16(0x1234), 0x5678, 0x9abc]
		assert reader.get_pos() == 6
	}
}
