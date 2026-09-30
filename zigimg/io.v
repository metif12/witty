module zigimg

// Memory variants of pinned io.ReadStream and io.WriteStream. File variants
// remain untranslated. Bit streams are translated in bit_stream.v.
pub struct ReadStream {
	buffer []u8
mut:
	position int
}

pub fn ReadStream.init_memory(buffer []u8) ReadStream {
	return ReadStream{
		buffer: unsafe { buffer }
	}
}

pub fn (stream ReadStream) get_pos() u64 {
	return u64(stream.position)
}

pub fn (stream ReadStream) get_end_pos() u64 {
	return u64(stream.buffer.len)
}

pub fn (mut stream ReadStream) seek_to(offset u64) ! {
	if offset >= u64(stream.buffer.len) { return error('Unseekable') }
	stream.position = int(offset)
}

pub fn (mut stream ReadStream) seek_by(offset i64) ! {
	position := i64(stream.position) + offset
	if position < 0 || position >= stream.buffer.len { return error('Unseekable') }
	stream.position = int(position)
}

pub fn (stream ReadStream) peek(count int) ![]u8 {
	assert count >= 0
	if count > stream.buffer.len - stream.position { return error('EndOfStream') }
	return unsafe { stream.buffer[stream.position..stream.position + count] }
}

pub fn (mut stream ReadStream) take(count int) ![]u8 {
	result := stream.peek(count)!
	stream.position += count
	return result
}

pub fn (mut stream ReadStream) take_byte() !u8 {
	return stream.take(1)![0]
}

// std.Io.Reader.readSliceAll consumes/copies the available prefix before EOF.
// This differs from take, whose fixed-memory peek leaves the position intact
// if the full request cannot be satisfied.
pub fn (mut stream ReadStream) read_slice_all(mut destination []u8) ! {
	remaining := stream.buffer.len - stream.position
	count := if destination.len < remaining { destination.len } else { remaining }
	bytes := stream.take(count)!
	copy(mut destination, bytes)
	if count < destination.len { return error('EndOfStream') }
}

pub struct WriteStream {
mut:
	buffer   []u8
	position int
}

pub fn WriteStream.init_memory(mut buffer []u8) WriteStream {
	return WriteStream{
		buffer: unsafe { buffer }
	}
}

pub fn (stream WriteStream) get_pos() u64 {
	return u64(stream.position)
}

pub fn (stream WriteStream) buffered() []u8 {
	return unsafe { stream.buffer[..stream.position] }
}

pub fn (mut stream WriteStream) seek_to(offset u64) ! {
	if offset >= u64(stream.buffer.len) { return error('Unseekable') }
	stream.position = int(offset)
}

pub fn (mut stream WriteStream) write_all(bytes []u8) ! {
	remaining := stream.buffer.len - stream.position
	count := if bytes.len < remaining { bytes.len } else { remaining }
	for i in 0 .. count {
		stream.buffer[stream.position + i] = bytes[i]
	}
	stream.position += count
	if count < bytes.len { return error('WriteFailed') }
}

pub fn (mut stream WriteStream) write_byte(byte u8) ! {
	if stream.position == stream.buffer.len { return error('WriteFailed') }
	stream.buffer[stream.position] = byte
	stream.position++
}

pub fn (mut stream WriteStream) flush() ! {}

fn read_be_u32(bytes []u8) u32 {
	return u32(bytes[0]) << 24 | u32(bytes[1]) << 16 | u32(bytes[2]) << 8 | u32(bytes[3])
}

fn append_be_u32(mut bytes []u8, value u32) {
	bytes << [u8(value >> 24), u8(value >> 16), u8(value >> 8), u8(value)]
}
