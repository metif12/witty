module zigimg

import os

#flag -I @VMODROOT/zigimg
#include "file_io_shims.h"
fn C.witty_image_file_size(int, &u64) int
fn C.witty_image_file_read(int, u64, &u8, usize, &int) isize
fn C.witty_image_file_read_vec(int, u64, &u8, usize, &u8, usize, &int) isize
fn C.witty_image_file_write(int, u64, &u8, usize, &u8, usize, &int) isize

pub const default_buffer_size = 4096

// io.ReadStream's memory/file variants and the buffered std.Io.Reader paths
// used by the locked codecs. File offsets start at zero independently of the
// descriptor's seek position, matching fs.File.Reader's positional mode.
@[heap]
pub struct ReadStream {
mut:
	buffer []u8
	position int
	end int
	file ?os.File
	file_pos u64
	file_size ?u64
	file_size_error string
	streaming int
}

pub fn ReadStream.init_memory(buffer []u8) ReadStream {
	return ReadStream{ buffer: unsafe { buffer }, end: buffer.len }
}

pub fn ReadStream.init_file(file os.File, mut buffer []u8) ReadStream {
	return ReadStream{ buffer: unsafe { buffer }, file: file }
}

pub fn (stream ReadStream) get_pos() u64 {
	if stream.file != none { return stream.file_pos - u64(stream.end - stream.position) }
	return u64(stream.position)
}

pub fn (mut stream ReadStream) get_end_pos() !u64 {
	if file := stream.file {
		if size := stream.file_size { return size }
		if stream.file_size_error != '' { return error(stream.file_size_error) }
		mut size := u64(0)
		result := C.witty_image_file_size(file.fd, &size)
		if result != 0 {
			stream.file_size_error = if result == 1 { 'Streaming' } else { 'Unexpected' }
			return error(stream.file_size_error)
		}
		stream.file_size = size
		return size
	}
	return u64(stream.buffer.len)
}

pub fn (mut stream ReadStream) seek_to(offset u64) ! {
	if stream.file != none {
		size := stream.get_end_pos() or { return error('Unseekable') }
		if offset >= size { return error('Unseekable') }
		logical := stream.get_pos()
		if offset < logical || offset >= stream.file_pos {
			stream.position = 0
			stream.end = 0
			stream.file_pos = offset
		} else {
			stream.position += int(offset - logical)
		}
		return
	}
	if offset >= u64(stream.end) { return error('Unseekable') }
	stream.position = int(offset)
}

pub fn (mut stream ReadStream) seek_by(offset i64) ! {
	mut position := i64(stream.position) + offset
	if stream.file != none {
		// The locked io.zig explicitly preserves this workaround's use of the
		// physical file pos when an offset leaves the buffered range.
		if position >= 0 && position < stream.end { stream.position = int(position); return }
		stream.position = 0
		stream.end = 0
		position = i64(stream.file_pos) + offset
		size := stream.get_end_pos() or { return error('Unseekable') }
		if position < 0 || u64(position) >= size { return error('Unseekable') }
		stream.file_pos = u64(position)
		return
	}
	if position < 0 || position >= stream.end { return error('Unseekable') }
	stream.position = int(position)
}

fn (mut stream ReadStream) file_read(mut destination []u8) !int {
	if destination.len == 0 { return 0 }
	file := stream.file or { return error('ReadFailed') }
	count := C.witty_image_file_read(file.fd, stream.file_pos, destination.data,
		usize(destination.len), &stream.streaming)
	if count < 0 { return error('ReadFailed') }
	if count == 0 { return error('EndOfStream') }
	stream.file_pos += u64(count)
	return int(count)
}

pub fn (mut stream ReadStream) peek(count int) ![]u8 {
	assert count >= 0
	if stream.position + count > stream.end {
		if stream.file == none { return error('EndOfStream') }
		if stream.buffer.len - stream.position < count {
			remaining := stream.end - stream.position
			for i in 0 .. remaining { stream.buffer[i] = stream.buffer[stream.position + i] }
			stream.position = 0
			stream.end = remaining
			assert count <= stream.buffer.len
		}
		for stream.end < stream.position + count {
			mut target := unsafe { stream.buffer[stream.end..] }
			stream.end += stream.file_read(mut target)!
		}
	}
	return unsafe { stream.buffer[stream.position..stream.position + count] }
}

pub fn (mut stream ReadStream) take(count int) ![]u8 {
	result := stream.peek(count)!
	stream.position += count
	return result
}

pub fn (mut stream ReadStream) take_byte() !u8 { return stream.take(1)![0] }

pub fn (mut stream ReadStream) peek_delimiter_inclusive(delimiter u8) ![]u8 {
	for i in stream.position .. stream.end {
		if stream.buffer[i] == delimiter { return unsafe { stream.buffer[stream.position..i + 1] } }
	}
	for {
		content_len := stream.end - stream.position
		if stream.buffer.len - content_len == 0 { break }
		if stream.file == none { return error('EndOfStream') }
		// Reader.fillMore rebases the retained prefix and fills the free tail.
		if stream.position != 0 {
			for i in 0 .. content_len { stream.buffer[i] = stream.buffer[stream.position + i] }
			stream.position = 0
			stream.end = content_len
		}
		mut target := unsafe { stream.buffer[stream.end..] }
		stream.end += stream.file_read(mut target)!
		for i in stream.position + content_len .. stream.end {
			if stream.buffer[i] == delimiter { return unsafe { stream.buffer[stream.position..i + 1] } }
		}
	}
	// The fixed reader's stream callback reports EOF. File.Reader's failing
	// writer reports StreamTooLong before a native read can consume bytes.
	if stream.file == none { return error('EndOfStream') }
	return error('StreamTooLong')
}

pub fn (mut stream ReadStream) take_delimiter_inclusive(delimiter u8) ![]u8 {
	line := stream.peek_delimiter_inclusive(delimiter)!
	stream.position += line.len
	return line
}

// std.Io.Reader.readVec with one destination vector, and File.Reader's
// positional/streaming native scatter read including buffered read-ahead.
fn (mut stream ReadStream) read_vec(mut destination []u8) !int {
	remaining := stream.end - stream.position
	count := if destination.len < remaining { destination.len } else { remaining }
	copy(mut destination, stream.take(count)!)
	if count == destination.len { return count }
	if stream.file == none {
		if count == 0 { return error('EndOfStream') }
		return count
	}
	file := stream.file or { return error('ReadFailed') }
	mut target := unsafe { destination[count..] }
	mut data_size := target.len
	mut n := isize(0)
	$if windows {
		if stream.position == stream.end { stream.position = 0; stream.end = 0 }
		if target.len >= stream.buffer.len - stream.end {
			n = C.witty_image_file_read(file.fd, stream.file_pos, target.data,
				usize(target.len), &stream.streaming)
		} else {
			mut tail := unsafe { stream.buffer[stream.end..] }
			data_size = 0
			n = C.witty_image_file_read(file.fd, stream.file_pos, tail.data,
				usize(tail.len), &stream.streaming)
		}
	} $else {
		stream.position = 0
		stream.end = 0
		n = C.witty_image_file_read_vec(file.fd, stream.file_pos, target.data,
			usize(target.len), stream.buffer.data, usize(stream.buffer.len), &stream.streaming)
	}
	if n < 0 { return error('ReadFailed') }
	if n == 0 {
		stream.file_size = stream.file_pos
		if count == 0 { return error('EndOfStream') }
		return count
	}
	stream.file_pos += u64(n)
	if int(n) > data_size {
		stream.end += int(n) - data_size
		return count + data_size
	}
	return count + int(n)
}

pub fn (mut stream ReadStream) read_slice_short(mut destination []u8) !usize {
	mut filled := 0
	for filled < destination.len {
		mut target := unsafe { destination[filled..] }
		filled += stream.read_vec(mut target) or {
			if err.msg() == 'EndOfStream' { return usize(filled) }
			return err
		}
	}
	return usize(filled)
}

pub fn (mut stream ReadStream) read_slice_all(mut destination []u8) ! {
	count := stream.read_slice_short(mut destination)!
	if count < usize(destination.len) { return error('EndOfStream') }
}

fn (mut stream ReadStream) flate_fill_word() ! { stream.peek(int(sizeof(usize)))! }
fn (stream ReadStream) flate_buffered_len() int { return stream.end - stream.position }
fn (mut stream ReadStream) flate_read_vec(mut destination []u8) !int {
	return stream.read_vec(mut destination)
}

pub fn (mut stream ReadStream) discard_all(count usize) ! {
	buffered := usize(stream.end - stream.position)
	if count <= buffered { stream.position += int(count); return }
	mut remaining := count - buffered
	stream.position = stream.end
	for remaining > 0 {
		if stream.file == none { return error('EndOfStream') }
		if stream.streaming == 0 {
			size := stream.get_end_pos() or { stream.streaming = 1; continue }
			available := size - stream.file_pos
			delta := if u64(remaining) < available { u64(remaining) } else { available }
			stream.file_pos += delta
			remaining -= usize(delta)
			// File.Reader.discard and Reader.discardShort preserve the original
			// zero-progress behavior for an overlong positional discard.
			continue
		}
		mut trash := []u8{len: if remaining < 128 { int(remaining) } else { 128 }}
		remaining -= usize(stream.file_read(mut trash)!)
	}
}

pub fn (mut stream ReadStream) toss(count usize) {
	assert count <= usize(stream.end - stream.position)
	stream.position += int(count)
}

pub struct WriteStream {
mut:
	buffer []u8
	position int
	file ?os.File
	file_pos u64
	streaming int
}

pub fn WriteStream.init_memory(mut buffer []u8) WriteStream {
	return WriteStream{ buffer: unsafe { buffer } }
}

pub fn WriteStream.init_file(file os.File, mut buffer []u8) WriteStream {
	return WriteStream{ buffer: unsafe { buffer }, file: file }
}

pub fn (stream WriteStream) get_pos() u64 { return stream.file_pos + u64(stream.position) }
pub fn (stream WriteStream) buffered() []u8 { return unsafe { stream.buffer[..stream.position] } }

pub fn (mut stream WriteStream) seek_to(offset u64) ! {
	if stream.file != none {
		stream.flush() or { return error('Unexpected') }
		stream.position = 0
		stream.file_pos = offset
		return
	}
	if offset >= u64(stream.buffer.len) { return error('Unseekable') }
	stream.position = int(offset)
}

pub fn (mut stream WriteStream) write(bytes []u8) !usize {
	if bytes.len <= stream.buffer.len - stream.position {
		for i, byte in bytes { stream.buffer[stream.position + i] = byte }
		stream.position += bytes.len
		return usize(bytes.len)
	}
	if file := stream.file {
		n := C.witty_image_file_write(file.fd, stream.file_pos, stream.buffer.data,
			usize(stream.position), bytes.data, usize(bytes.len), &stream.streaming)
		if n < 0 { return error('WriteFailed') }
		stream.file_pos += u64(n)
		if int(n) < stream.position {
			remaining := stream.position - int(n)
			for i in 0 .. remaining { stream.buffer[i] = stream.buffer[int(n) + i] }
			stream.position = remaining
			return 0
		}
		consumed := usize(n) - usize(stream.position)
		stream.position = 0
		return consumed
	}
	remaining := stream.buffer.len - stream.position
	for i in 0 .. remaining { stream.buffer[stream.position + i] = bytes[i] }
	stream.position += remaining
	return error('WriteFailed')
}

pub fn (mut stream WriteStream) write_all(bytes []u8) ! {
	mut index := 0
	for index < bytes.len { index += int(stream.write(bytes[index..])!) }
}

pub fn (mut stream WriteStream) write_byte(byte u8) ! { stream.write_all([byte])! }

pub fn (mut stream WriteStream) flush() ! {
	if stream.file == none { return }
	file := stream.file or { return }
	for stream.position != 0 {
		n := C.witty_image_file_write(file.fd, stream.file_pos, stream.buffer.data,
			usize(stream.position), unsafe { nil }, 0, &stream.streaming)
		if n <= 0 { return error('WriteFailed') }
		stream.file_pos += u64(n)
		remaining := stream.position - int(n)
		for i in 0 .. remaining { stream.buffer[i] = stream.buffer[int(n) + i] }
		stream.position = remaining
	}
}

fn read_be_u32(bytes []u8) u32 {
	return u32(bytes[0]) << 24 | u32(bytes[1]) << 16 | u32(bytes[2]) << 8 | u32(bytes[3])
}

fn append_be_u32(mut bytes []u8, value u32) {
	bytes << [u8(value >> 24), u8(value >> 16), u8(value >> 8), u8(value)]
}
