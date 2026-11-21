module zigimg

import hash.crc32

fn png_chunk_test_bytes(payload []u8) []u8 {
	mut bytes := []u8{}
	append_be_u32(mut bytes, u32(payload.len))
	bytes << 'IDAT'.bytes()
	bytes << payload
	append_be_u32(mut bytes, crc32.sum(bytes[4..]))
	return bytes
}

fn test_png_chunk_writer_keeps_inline_capacity_and_repeated_empty_flushes() {
	mut destination := []u8{len: 128, init: 0xa5}
	output := WriteStream.init_memory(mut destination)
	mut writer := PngChunkWriter.init([4]u8{}, output, [u8(`I`), `D`, `A`, `T`]!)
	assert writer.buf.len == 4 && sizeof(writer.buf) == 4
	count := writer.write('abcd'.bytes())!
	assert count == 4 && writer.end == 4 && writer.unbuffered_writer.get_pos() == 0
	zero := writer.write([])!
	assert zero == 0 && writer.end == 4
	writer.flush()!
	assert writer.end == 0
		&& writer.unbuffered_writer.buffered() == png_chunk_test_bytes('abcd'.bytes())
	writer.flush()!
	mut expected := png_chunk_test_bytes('abcd'.bytes())
	expected << png_chunk_test_bytes([])
	assert writer.unbuffered_writer.buffered() == expected
	assert destination[expected.len] == 0xa5
	mut defaults := png_chunk_writer(output, 'IDAT')
	assert defaults.buf.len == 16384 && sizeof(defaults.buf) == 16384
}

fn test_png_chunk_writer_flushes_before_copy_and_bypasses_framing_for_large_writes() {
	mut destination := []u8{len: 128}
	mut writer := PngChunkWriter.init([4]u8{}, WriteStream.init_memory(mut destination), [
		u8(`I`),
		`D`,
		`A`,
		`T`,
	]!)
	_ = writer.write('ab'.bytes())!
	_ = writer.write('cde'.bytes())!
	assert writer.unbuffered_writer.buffered() == png_chunk_test_bytes('ab'.bytes())
	assert writer.end == 3 && writer.buf[..3] == 'cde'.bytes()
	_ = writer.write('oversized'.bytes())!
	mut expected := png_chunk_test_bytes('ab'.bytes())
	expected << png_chunk_test_bytes('cde'.bytes())
	expected << 'oversized'.bytes()
	assert writer.end == 0 && writer.unbuffered_writer.buffered() == expected
	_ = writer.write('again'.bytes())!
	expected << png_chunk_test_bytes([])
	expected << 'again'.bytes()
	assert writer.unbuffered_writer.buffered() == expected
}

fn test_png_chunk_writer_retains_buffered_bytes_on_partial_flush_failure() {
	full := png_chunk_test_bytes('abcd'.bytes())
	for capacity in 0 .. full.len {
		mut destination := []u8{len: capacity}
		mut writer := PngChunkWriter.init([4]u8{}, WriteStream.init_memory(mut destination), [
			u8(`I`),
			`D`,
			`A`,
			`T`,
		]!)
		_ = writer.write('abcd'.bytes())!
		mut failure := ''
		writer.flush() or { failure = err.msg() }
		assert failure == 'WriteFailed' && writer.end == 4
		assert writer.unbuffered_writer.get_pos() == u64(capacity)
		assert destination == full[..capacity]
	}
}

fn png_chunk_test_capacity[B](buffer B, capacity int) ! {
	mut destination := []u8{len: 64}
	mut writer := png_chunk_writer_with_buffer[B, WriteStream](buffer,
		WriteStream.init_memory(mut destination), [u8(`I`), `D`, `A`, `T`]!)
	payload := []u8{len: capacity, init: u8(index + 1)}
	count := writer.write(payload)!
	assert count == uint(capacity)
	assert writer.end == uint(capacity)
	writer.flush()!
	assert writer.unbuffered_writer.buffered() == png_chunk_test_bytes(payload)
}

type PngChunkTestBuffer = [7]u8

fn test_png_chunk_writer_specializes_each_fixed_buffer_and_zero_capacity() {
	png_chunk_test_capacity([1]u8{}, 1)!
	png_chunk_test_capacity([4]u8{}, 4)!
	png_chunk_test_capacity([16]u8{}, 16)!
	buffer := PngChunkTestBuffer{}
	png_chunk_test_capacity(buffer, 7)!
	png_chunk_test_capacity([]u8{}, 0)!
	mut destination := []u8{len: 16}
	mut writer := png_chunk_writer_with_buffer([]u8{}, WriteStream.init_memory(mut destination), [
		u8(`I`),
		`D`,
		`A`,
		`T`,
	]!)
	count := writer.write('raw'.bytes())!
	assert count == 3
	mut expected := png_chunk_test_bytes([])
	expected << 'raw'.bytes()
	assert writer.end == 0 && writer.unbuffered_writer.buffered() == expected
}

fn test_png_chunk_writer_custom_chunk_identifier_participates_in_crc() {
	mut destination := []u8{len: 32}
	mut writer := png_chunk_writer_with_buffer([4]u8{}, WriteStream.init_memory(mut destination), [
		u8(`t`),
		`E`,
		`X`,
		`t`,
	]!)
	_ = writer.write('data'.bytes())!
	writer.flush()!
	mut expected := [u8(0), 0, 0, 4]
	expected << 'tEXtdata'.bytes()
	append_be_u32(mut expected, crc32.sum('tEXtdata'.bytes()))
	assert writer.unbuffered_writer.buffered() == expected
}

fn test_write_stream_integer_encoding_retains_partial_write_semantics() {
	mut destination := []u8{len: 19}
	mut output := WriteStream.init_memory(mut destination)
	output.write_int(i16(-2), BigEndian{})!
	output.write_int(u32(0x12345678), LittleEndian{})!
	output.write_int(u64(0x123456789abcdef0), BigEndian{})!
	output.write_int(u8(0xaa), BigEndian{})!
	output.write_int(u32(0xfedcba98), BigEndian{})!
	assert destination == [u8(0xff), 0xfe, 0x78, 0x56, 0x34, 0x12, 0x12, 0x34, 0x56, 0x78, 0x9a,
		0xbc, 0xde, 0xf0, 0xaa, 0xfe, 0xdc, 0xba, 0x98]
	mut short := []u8{len: 3}
	output = WriteStream.init_memory(mut short)
	mut failure := ''
	output.write_int(u32(0x12345678), BigEndian{}) or { failure = err.msg() }
	assert failure == 'WriteFailed' && short == [u8(0x12), 0x34, 0x56] && output.get_pos() == 3
}

fn test_png_chunk_writer_accepts_empty_and_adjacent_borrowed_buffer_ranges() {
	mut destination := []u8{len: 32, init: 0xa5}
	mut writer := png_chunk_writer_with_buffer([u8(1), 2, 3, 4]!,
		WriteStream.init_memory(mut destination), [u8(`I`), `D`, `A`, `T`]!)
	mut storage := png_chunk_buffer_bytes(mut writer.buf)
	empty := unsafe { storage[..0] }
	empty_count := writer.write(empty)!
	assert empty_count == 0
	writer.end = 2
	adjacent := unsafe { storage[..2] }
	adjacent_count := writer.write(adjacent)!
	assert adjacent_count == 2
	assert writer.buf == [u8(1), 2, 1, 2]!
	assert writer.end == 4
	full_empty := unsafe { storage[4..4] }
	full_empty_count := writer.write(full_empty)!
	assert full_empty_count == 0
	assert writer.end == 4 && writer.unbuffered_writer.get_pos() == 0
}

fn test_png_chunk_writer_defers_payload_bounds_until_header_writes_succeed() {
	for capacity in 0 .. 8 {
		mut destination := []u8{len: capacity, init: 0xa5}
		mut writer := png_chunk_writer_with_buffer([u8(1), 2, 3, 4]!,
			WriteStream.init_memory(mut destination), [u8(`I`), `D`, `A`, `T`]!)
		writer.end = 5
		mut failure := ''
		writer.flush() or { failure = err.msg() }
		assert failure == 'WriteFailed'
		assert writer.end == 5 && writer.buf == [u8(1), 2, 3, 4]!
		assert writer.unbuffered_writer.get_pos() == u64(capacity)
		prefix := [u8(0), 0, 0, 5, `I`, `D`, `A`, `T`]
		assert destination == prefix[..capacity]
	}
}
