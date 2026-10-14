module zigimg

import os

type SliceSigned = i16
type SliceBig = BigEndian

fn test_endian_slice_reads_native_integer_values_and_aliases() {
	mut reader := ReadStream.init_memory([u8(0x12), 0x34, 0xff, 0xfe])
	mut values := []SliceSigned{len: 2}
	reader.read_slice_endian[SliceSigned, SliceBig](mut values, SliceBig{})!
	assert values == [SliceSigned(0x1234), SliceSigned(-2)]
	assert reader.get_pos() == 4
	mut little := ReadStream.init_memory([u8(0x78), 0x56, 0x34, 0x12])
	mut words := []u32{len: 1}
	little.read_slice_endian[u32, LittleEndian](mut words, LittleEndian{})!
	assert words == [u32(0x12345678)]
}

fn test_endian_slice_failed_read_keeps_partial_bytes_unswapped() {
	mut reader := ReadStream.init_memory([u8(0x12), 0x34, 0x56])
	mut values := []u16{len: 2, init: 0xa5a5}
	mut status := 'ok'
	reader.read_slice_endian[u16, BigEndian](mut values, BigEndian{}) or { status = err.msg() }
	assert status == 'EndOfStream' && reader.get_pos() == 3
	bytes := unsafe { values.data.vbytes(4) }
	assert bytes == [u8(0x12), 0x34, 0x56, 0xa5]
	mut empty := []u64{}
	reader.read_slice_endian[u64, BigEndian](mut empty, BigEndian{})!
	assert reader.get_pos() == 3
}

fn test_endian_slice_streaming_file_reads_more_than_the_reader_buffer() {
	$if !windows {
		path := os.join_path(os.temp_dir(), 'witty-reader-slice-endian-${os.getpid()}.owned')
		os.write_file_array(path, [u8(0x12), 0x34, 0x56, 0x78, 0x9a, 0xbc])!
		defer { os.rm(path) or {} }
		mut file := os.open(path)!
		defer { file.close() }
		mut buffer := []u8{len: 1}
		mut reader := ReadStream.init_file_streaming(file, mut buffer)
		mut values := []u16{len: 3}
		reader.read_slice_endian[u16, BigEndian](mut values, BigEndian{})!
		assert values == [u16(0x1234), 0x5678, 0x9abc]
		assert reader.get_pos() == 6
	}
}
