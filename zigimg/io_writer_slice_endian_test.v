module zigimg

import os

type WriterSliceSigned = i16
type WriterSliceBig = BigEndian

fn test_writer_integer_slice_orders_and_aliases_preserve_input() {
	mut bytes := []u8{len: 16, init: 165}
	mut writer := WriteStream.init_memory(mut bytes)
	values := [WriterSliceSigned(0x1234), WriterSliceSigned(-2)]
	writer.write_slice_endian[WriterSliceSigned, WriterSliceBig](values, WriterSliceBig{})!
	writer.write_slice_endian[u32, LittleEndian]([u32(0x12345678)], LittleEndian{})!
	assert writer.buffered() == [u8(0x12), 0x34, 0xff, 0xfe, 0x78, 0x56, 0x34, 0x12]
	assert values == [WriterSliceSigned(0x1234), WriterSliceSigned(-2)]
	writer.write_slice_swap[u8]([u8(17), 29])!
	assert writer.buffered()[8..] == [u8(17), 29]
	writer.write_slice_swap[u64]([]u64{})!
	writer.write_slice_endian[u64, BigEndian]([]u64{}, BigEndian{})!
	assert writer.get_pos() == 10
}

fn test_writer_swapped_slice_partial_failure_keeps_prefix_and_input() {
	mut bytes := []u8{len: 3, init: 165}
	mut writer := WriteStream.init_memory(mut bytes)
	values := [u16(0x1234), 0x5678]
	mut status := 'ok'
	writer.write_slice_endian[u16, BigEndian](values, BigEndian{}) or { status = err.msg() }
	assert status == 'WriteFailed'
	assert writer.buffered() == [u8(0x12), 0x34, 0x56]
	assert values == [u16(0x1234), 0x5678]
}

fn test_writer_slice_file_retains_per_element_buffering() {
	$if !windows {
		path := os.join_path(os.temp_dir(), 'witty-writer-slice-endian-${os.getpid()}.owned')
		mut file := os.create(path)!
		defer { os.rm(path) or {} }
		mut bytes := []u8{len: 3, init: 165}
		mut writer := WriteStream.init_file(file, mut bytes)
		writer.write_slice_endian[u16, BigEndian]([u16(0x1234), 0x5678], BigEndian{})!
		assert writer.get_pos() == 4 && writer.buffered() == [u8(0x56), 0x78]
		writer.flush()!
		file.close()
		assert os.read_bytes(path)! == [u8(0x12), 0x34, 0x56, 0x78]
	}
}
