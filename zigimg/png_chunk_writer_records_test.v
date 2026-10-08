module zigimg

type ChunkRecordBytes = [4]u8
type ChunkRecordByte = u8
type ChunkRecordAliasedBytes = [4]ChunkRecordByte
type ChunkRecordStream = WriteStream
type ChunkRecordAlias = PngChunkWriter[ChunkRecordBytes, ChunkRecordStream]

fn test_png_chunk_record_defaults_and_public_mutation() {
	mut destination := []u8{len: 32, init: 0xa5}
	mut writer := PngChunkWriter[ChunkRecordBytes, WriteStream]{
		unbuffered_writer: WriteStream.init_memory(mut destination)
		section_id:        [u8(`I`), `D`, `A`, `T`]!
	}
	assert writer.end == 0
	// The source default buffer is undefined; seed it before observing bytes.
	writer.buf = ChunkRecordBytes([u8(1), 2, 3, 4]!)
	writer.end = 2
	writer.section_id = [u8(`t`), `E`, `X`, `t`]!
	writer.flush()!
	assert writer.end == 0
	assert destination[..10] == [u8(0), 0, 0, 2, `t`, `E`, `X`, `t`, 1, 2]
}

fn chunk_record_from_local(mut destination []u8) PngChunkWriter[ChunkRecordAliasedBytes, WriteStream] {
	mut buffer := ChunkRecordAliasedBytes([ChunkRecordByte(1), 2, 3, 4]!)
	writer := png_chunk_writer_with_buffer(buffer, WriteStream.init_memory(mut destination), [
		u8(`I`),
		`D`,
		`A`,
		`T`,
	]!)
	buffer[0] = ChunkRecordByte(99)
	return writer
}

fn test_png_chunk_record_owns_scalar_aliased_inline_bytes_after_constructor_returns() {
	mut destination := []u8{len: 32, init: 0xa5}
	mut writer := chunk_record_from_local(mut destination)
	assert writer.buf == ChunkRecordAliasedBytes([ChunkRecordByte(1), 2, 3, 4]!)
	mut borrowed := unsafe { (&u8(&writer.buf)).vbytes(4) }
	borrowed[0] = 9
	assert writer.buf[0] == ChunkRecordByte(9)
	writer.end = 4
	writer.flush()!
	assert destination[8..12] == [u8(9), 2, 3, 4]
}

fn test_png_chunk_record_alias_copies_inline_state_and_shares_destination_bytes() {
	mut destination := []u8{len: 32, init: 0xa5}
	mut writer := ChunkRecordAlias{
		unbuffered_writer: ChunkRecordStream(WriteStream.init_memory(mut destination))
		section_id:        [u8(`I`), `D`, `A`, `T`]!
		buf:               ChunkRecordBytes([u8(1), 2, 3, 4]!)
		end:               2
	}
	mut copied := writer
	copied.buf[0] = 9
	copied.end = 1
	copied.section_id = [u8(`t`), `E`, `X`, `t`]!
	copied.flush()!
	assert writer.end == 2 && writer.buf[0] == 1 && writer.section_id[0] == `I`
	assert destination[..9] == [u8(0), 0, 0, 1, `t`, `E`, `X`, `t`, 9]
	assert writer.unbuffered_writer.get_pos() == 0 && copied.unbuffered_writer.get_pos() == 13
	writer.flush()!
	assert destination[..10] == [u8(0), 0, 0, 2, `I`, `D`, `A`, `T`, 1, 2]
}
