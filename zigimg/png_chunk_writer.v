module zigimg

import hash.crc32

// Buffer is a fixed byte array type, preserving ChunkWriter's inline storage
// and compile-time capacity without a value-parameterized V type factory.
// V rejects [0]u8, so the zero-capacity specialization uses an empty []u8.
pub struct PngChunkWriter[B, W] {
pub mut:
	unbuffered_writer W @[required]
	buf               B
	end               uint
	section_id        [4]u8 @[required]
}

fn png_chunk_check_element[E](element E) {
	// Pinned V's unaliased type categories look through pointers; preserve the
	// byte-only constraint while accepting scalar aliases of u8.
	$if E.indirections > 0 || ((int(E.unaliased_typ) >> 16) & 0xff) > 0 {
		$compile_error('PNG chunk storage requires a fixed byte array')
	} $else $if E.unaliased_typ is u8 {
		_ = element
	} $else {
		$compile_error('PNG chunk storage requires a fixed byte array')
	}
}

pub fn png_chunk_writer_with_buffer[B, W](buffer B, underlying W, section_id [4]u8) PngChunkWriter[B, W] {
	$if B.unaliased_typ is []u8 {
		if buffer.len != 0 { panic('PNG chunk slice storage must have zero capacity') }
	} $else $if B.unaliased_typ is $array_fixed {
		png_chunk_check_element(buffer[0])
	} $else {
		$compile_error('PNG chunk storage requires a fixed byte array')
	}
	return PngChunkWriter[B, W]{
		buf:               buffer
		unbuffered_writer: underlying
		section_id:        section_id
	}
}

pub fn PngChunkWriter.init[B, W](buffer B, underlying W, section_id [4]u8) PngChunkWriter[B, W] {
	return png_chunk_writer_with_buffer[B, W](buffer, underlying, section_id)
}

pub type PngChunkBuffer16K = [16384]u8

pub fn png_chunk_writer[W](underlying W, id string) PngChunkWriter[PngChunkBuffer16K, W] {
	// The source rejects an invalid comptime id. V strings are runtime values.
	if id.len != 4 { panic('PNG chunk id must be 4 characters') }
	mut section_id := [4]u8{}
	for i in 0 .. 4 {
		section_id[i] = id[i]
	}
	buffer := PngChunkBuffer16K{}
	return png_chunk_writer_with_buffer[PngChunkBuffer16K, W](buffer, underlying, section_id)
}

// The pinned V compiler caches the last fixed-array length in generic field
// slices. Build the borrowed byte header from sizeof(B) instead.
fn png_chunk_buffer_bytes[B](mut buffer B) []u8 {
	$if B.unaliased_typ is []u8 {
		if buffer.len != 0 { panic('PNG chunk slice storage must have zero capacity') }
		return unsafe { buffer[..] }
	} $else $if B.unaliased_typ is $array_fixed {
		png_chunk_check_element(buffer[0])
		return unsafe { (&u8(&buffer)).vbytes(int(sizeof(B))) }
	} $else {
		$compile_error('PNG chunk storage requires a fixed byte array')
	}
}

pub fn (mut writer PngChunkWriter[B, W]) flush[B, W]() ! {
	writer.unbuffered_writer.write_int(u32(writer.end), BigEndian{})! // Source truncates usize to u32.
	mut section := unsafe { writer.section_id[..] }
	mut crc := crc32.sum(section)
	writer.unbuffered_writer.write_all(section)!
	mut storage := png_chunk_buffer_bytes[B](mut writer.buf)
	if writer.end > uint(storage.len) { panic('index out of bounds') }
	mut payload := unsafe { storage[..int(writer.end)] }
	crc = png_reader_crc.update(crc, payload)
	writer.unbuffered_writer.write_all(payload)!
	writer.unbuffered_writer.write_int(crc, BigEndian{})!
	writer.end = 0
}

pub fn (mut writer PngChunkWriter[B, W]) write[B, W](bytes []u8) !uint {
	mut storage := png_chunk_buffer_bytes[B](mut writer.buf)
	if writer.end > ~uint(0) - uint(bytes.len) { panic('integer overflow') }
	if writer.end + uint(bytes.len) > uint(storage.len) {
		writer.flush()!
		// The pinned helper bypasses chunk framing for an oversized write,
		// even when flushing first emitted an empty chunk.
		if bytes.len > storage.len { return writer.unbuffered_writer.write(bytes) }
	}
	mut target := unsafe { storage[int(writer.end)..int(writer.end) + bytes.len] }
	// Source @memcpy rejects identical and partially overlapping nonempty
	// ranges. Pointer differences avoid overflowing an address + length.
	if bytes.len > 0 {
		source_address := uint(bytes.data)
		target_address := uint(target.data)
		if (source_address <= target_address && target_address - source_address < uint(bytes.len))
			|| (target_address < source_address
			&& source_address - target_address < uint(target.len)) {
			panic('@memcpy arguments alias')
		}
	}
	copy(mut target, bytes)
	writer.end += uint(bytes.len)
	return uint(bytes.len)
}
