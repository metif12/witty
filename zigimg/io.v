module zigimg

import os

#flag -I @VMODROOT/zigimg
#include "file_io_shims.h"

fn C.witty_image_file_size(int, &u64) int
fn C.witty_image_file_seek(int, u64) int
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
	buffer             []u8
	position           int
	end                int
	file               ?os.File
	file_pos           u64
	file_size          ?u64
	file_size_error    string
	streaming          int
	tga_stream_reading bool
}

pub fn ReadStream.init_memory(buffer []u8) ReadStream {
	return ReadStream{
		buffer: unsafe { buffer }
		end:    buffer.len
	}
}

pub fn ReadStream.init_file(file os.File, mut buffer []u8) ReadStream {
	return ReadStream{
		buffer: unsafe { buffer }
		file:   file
	}
}

// std.fs.File.Reader.initStreaming starts at the descriptor's live position
// and caches the unavailable size until a read observes EOF.
pub fn ReadStream.init_file_streaming(file os.File, mut buffer []u8) ReadStream {
	return ReadStream{
		buffer:          unsafe { buffer }
		file:            file
		streaming:       1
		file_size_error: 'Streaming'
	}
}

pub fn (stream ReadStream) buffered_len() int {
	return stream.end - stream.position
}

// The adapter borrows the live buffer and position, as io.ReadStream.reader
// does. Keep the owning stream alive while using this pointer.
pub fn (mut stream ReadStream) reader() &ReadStream {
	return &stream
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
		if stream.streaming != 0 && offset < logical { return error('Unseekable') }
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
	mut position := stream_seek_position(u64(stream.position), offset)
	if stream.file != none {
		// The locked io.zig explicitly preserves this workaround's use of the
		// physical file pos when an offset leaves the buffered range.
		if position >= 0 && position < stream.end {
			stream.position = int(position)
			return
		}
		stream.position = 0
		stream.end = 0
		position = stream_seek_position(stream.file_pos, offset)
		size := stream.get_end_pos() or { return error('Unseekable') }
		if position < 0 || u64(position) >= size { return error('Unseekable') }
		stream.file_pos = u64(position)
		return
	}
	if position < 0 || position >= stream.end { return error('Unseekable') }
	stream.position = int(position)
}

// Zig checks both the unsigned position cast and the signed addition. Explicit
// checks keep these traps when V's production build removes assertions.
fn stream_seek_position(position u64, offset i64) i64 {
	maximum := i64(0x7fffffffffffffff)
	if position > u64(maximum) { panic('Stream seek position does not fit i64') }
	current := i64(position)
	if offset > 0 && current > maximum - offset { panic('Stream seek integer overflow') }
	return current + offset
}

fn (mut stream ReadStream) file_read(mut destination []u8) !int {
	if destination.len == 0 { return 0 }
	file := stream.file or { return error('ReadFailed') }
	count := C.witty_image_file_read(file.fd, stream.file_pos, destination.data,
		usize(destination.len), &stream.streaming)
	if count < 0 { return error('ReadFailed') }
	if count == 0 {
		stream.file_size = stream.file_pos
		return error('EndOfStream')
	}
	stream.file_pos += u64(count)
	return int(count)
}

pub fn (mut stream ReadStream) peek(count int) ![]u8 {
	if count < 0 { panic('Stream byte count must be nonnegative') }
	if count > stream.end - stream.position {
		if stream.file == none { return error('EndOfStream') }
		if stream.buffer.len - stream.position < count {
			remaining := stream.end - stream.position
			for i in 0 .. remaining {
				stream.buffer[i] = stream.buffer[stream.position + i]
			}
			stream.position = 0
			stream.end = remaining
			if count > stream.buffer.len { panic('Stream request exceeds buffer capacity') }
		}
		for stream.end - stream.position < count {
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

pub fn (mut stream ReadStream) take_byte() !u8 {
	return stream.take(1)![0]
}

// std.Io.Reader.takeInt reads the native-width integer representation without
// normalizing signed bits. Type markers replace the comptime endian argument.
pub fn (mut stream ReadStream) take_int[T, E](endian E) !T {
	$if T.unaliased_typ is $int {
		bytes := stream.take(int(sizeof(T)))!
		mut word := u64(0)
		for i, byte in bytes {
			$if E.unaliased_typ is BigEndian {
				word = word << 8 | u64(byte)
			} $else $if E.unaliased_typ is LittleEndian {
				word |= u64(byte) << (i * 8)
			} $else {
				$compile_error('take_int requires BigEndian or LittleEndian')
			}
		}
		return T(word)
	} $else {
		$compile_error('take_int requires a native integer type')
	}
}

pub fn (mut stream ReadStream) peek_delimiter_inclusive(delimiter u8) ![]u8 {
	for i in stream.position .. stream.end {
		if stream.buffer[i] == delimiter { return unsafe { stream.buffer[stream.position..i + 1] } }
	}
	for {
		content_len := stream.end - stream.position
		if stream.buffer.len - content_len == 0 {
			break
		}
		if stream.file == none { return error('EndOfStream') }
		// Reader.fillMore rebases the retained prefix and fills the free tail.
		if stream.position != 0 {
			for i in 0 .. content_len {
				stream.buffer[i] = stream.buffer[stream.position + i]
			}
			stream.position = 0
			stream.end = content_len
		}
		mut target := unsafe { stream.buffer[stream.end..] }
		stream.end += stream.file_read(mut target)!
		for i in stream.position + content_len .. stream.end {
			if stream.buffer[i] == delimiter {
				return unsafe { stream.buffer[stream.position..i + 1] }
			}
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
		if stream.position == stream.end {
			stream.position = 0
			stream.end = 0
		}
		if target.len >= stream.buffer.len - stream.end {
			n = C.witty_image_file_read(file.fd, stream.file_pos, target.data, usize(target.len),
				&stream.streaming)
		} else {
			mut tail := unsafe { stream.buffer[stream.end..] }
			data_size = 0
			n = C.witty_image_file_read(file.fd, stream.file_pos, tail.data, usize(tail.len),
				&stream.streaming)
		}
	} $else {
		stream.position = 0
		stream.end = 0
		n = C.witty_image_file_read_vec(file.fd, stream.file_pos, target.data, usize(target.len),
			stream.buffer.data, usize(stream.buffer.len), &stream.streaming)
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

fn (mut stream ReadStream) flate_fill_word() ! {
	stream.peek(int(sizeof(usize)))!
}

fn (stream ReadStream) flate_buffered_len() int {
	return stream.end - stream.position
}

fn (mut stream ReadStream) flate_read_vec(mut destination []u8) !int {
	return stream.read_vec(mut destination)
}

// Reader.stream into TargaRLEDecoder's fixed output writer. Unlike readVec,
// buffered data returns immediately; a file first switches from sendFile to
// positional/streaming reads without making progress. Keep that transition
// on the owning stream so repeated TGA reads retain it.
fn (mut stream ReadStream) tga_stream(limit int) ![]u8 {
	available := stream.end - stream.position
	count := if limit < available { limit } else { available }
	if count > 0 { return stream.take(count) }
	// A fixed Reader's callback reports EOF even for a zero limit.
	if stream.file == none { return error('EndOfStream') }
	if !stream.tga_stream_reading {
		stream.tga_stream_reading = true
		return []u8{}
	}
	// File.Reader asks the fixed writer for at least one writable byte before
	// limiting its slice. Writer exhaustion reaches defaultReadVec's trap.
	if limit == 0 { panic('reached unreachable code') }
	mut destination := []u8{len: limit}
	read := stream.read_vec(mut destination)!
	return destination[..read]
}

pub fn (mut stream ReadStream) discard_all(count usize) ! {
	buffered := usize(stream.end - stream.position)
	if count <= buffered {
		stream.position += int(count)
		return
	}
	mut remaining := count - buffered
	stream.position = stream.end
	for remaining > 0 {
		if stream.file == none { return error('EndOfStream') }
		if stream.streaming == 0 {
			size := stream.get_end_pos() or {
				stream.streaming = 1
				continue
			}
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
	// Source updates seek before its end assertion. V array cursors use int;
	// a failed offset beyond that carrier remains a representation boundary.
	if count > ~usize(0) - usize(stream.position) { panic('integer overflow') }
	if count > usize(0x7fffffff - stream.position) {
		panic('Stream toss exceeds buffered bytes')
	}
	stream.position += int(count)
	if stream.position > stream.end { panic('Stream toss exceeds buffered bytes') }
}

pub struct WriteStream {
mut:
	buffer          []u8
	position        int
	file            ?os.File
	file_pos        u64
	streaming       int
	file_seek_error string
}

pub fn WriteStream.init_memory(mut buffer []u8) WriteStream {
	return WriteStream{
		buffer: unsafe { buffer }
	}
}

pub fn WriteStream.init_file(file os.File, mut buffer []u8) WriteStream {
	return WriteStream{
		buffer: unsafe { buffer }
		file:   file
	}
}

pub fn WriteStream.init_file_streaming(file os.File, mut buffer []u8) WriteStream {
	return WriteStream{
		buffer:    unsafe { buffer }
		file:      file
		streaming: 1
	}
}

// The adapter shares pending bytes and writes with its owning stream.
pub fn (mut stream WriteStream) writer() &WriteStream {
	return unsafe { &stream }
}

pub fn (stream WriteStream) get_pos() u64 {
	if stream.file_pos > u64(0xffffffffffffffff) - u64(stream.position) {
		panic('Stream write position integer overflow')
	}
	return stream.file_pos + u64(stream.position)
}

pub fn (stream WriteStream) buffered() []u8 {
	return unsafe { stream.buffer[..stream.position] }
}

pub fn (mut stream WriteStream) seek_to(offset u64) ! {
	if stream.file != none {
		stream.flush() or { return error('Unexpected') }
		stream.position = 0
		if stream.streaming != 0 {
			if stream.file_seek_error != '' { return error(stream.file_seek_error) }
			file := stream.file or { return error('Unexpected') }
			result := C.witty_image_file_seek(file.fd, offset)
			if result == 4 { panic('Stream seek used a closed file descriptor') }
			if result != 0 {
				stream.file_seek_error = match result {
					1 { 'Unseekable' }
					2 { 'AccessDenied' }
					else { 'Unexpected' }
				}

				return error(stream.file_seek_error)
			}
		}
		stream.file_pos = offset
		return
	}
	if offset >= u64(stream.buffer.len) { return error('Unseekable') }
	stream.position = int(offset)
}

pub fn (mut stream WriteStream) write(bytes []u8) !usize {
	if bytes.len <= stream.buffer.len - stream.position {
		for i, byte in bytes {
			stream.buffer[stream.position + i] = byte
		}
		stream.position += bytes.len
		return usize(bytes.len)
	}
	if file := stream.file {
		n := C.witty_image_file_write(file.fd, stream.file_pos, stream.buffer.data,
			usize(stream.position), bytes.data, usize(bytes.len), &stream.streaming)
		if n < 0 {
			if stream.streaming < 0 {
				stream.file_pos = 0
				stream.file_seek_error = 'Unseekable'
			}
			return error('WriteFailed')
		}
		stream.file_pos += u64(n)
		if int(n) < stream.position {
			remaining := stream.position - int(n)
			for i in 0 .. remaining {
				stream.buffer[i] = stream.buffer[int(n) + i]
			}
			stream.position = remaining
			return 0
		}
		consumed := usize(n) - usize(stream.position)
		stream.position = 0
		return consumed
	}
	remaining := stream.buffer.len - stream.position
	for i in 0 .. remaining {
		stream.buffer[stream.position + i] = bytes[i]
	}
	stream.position += remaining
	return error('WriteFailed')
}

pub fn (mut stream WriteStream) write_all(bytes []u8) ! {
	mut index := 0
	for index < bytes.len {
		index += int(stream.write(bytes[index..])!)
	}
}

pub fn (mut stream WriteStream) write_byte(byte u8) ! {
	stream.write_all([byte])!
}

// std.Io.Writer.writeInt delegates to writeAll after encoding a native-width
// integer. Type markers retain Zig's comptime endian argument.
pub fn (mut stream WriteStream) write_int[T, E](value T, endian E) ! {
	$if T.unaliased_typ is $int {
		mut bytes := []u8{len: int(sizeof(T))}
		word := u64(value)
		for i in 0 .. bytes.len {
			$if E.unaliased_typ is BigEndian {
				bytes[i] = u8(word >> ((bytes.len - 1 - i) * 8))
			} $else $if E.unaliased_typ is LittleEndian {
				bytes[i] = u8(word >> (i * 8))
			} $else {
				$compile_error('write_int requires BigEndian or LittleEndian')
			}
		}
		stream.write_all(bytes)!
	} $else {
		$compile_error('write_int requires a native integer type')
	}
}

pub fn (mut stream WriteStream) flush() ! {
	if stream.file == none { return }
	file := stream.file or { return }
	for stream.position != 0 {
		previous_mode := stream.streaming
		n := C.witty_image_file_write(file.fd, stream.file_pos, stream.buffer.data,
			usize(stream.position), unsafe { nil }, 0, &stream.streaming)
		if n == 0 && previous_mode == 0 && stream.streaming == 1 {
			continue
		}
		if n <= 0 {
			if stream.streaming < 0 {
				stream.file_pos = 0
				stream.file_seek_error = 'Unseekable'
			}
			return error('WriteFailed')
		}
		stream.file_pos += u64(n)
		remaining := stream.position - int(n)
		for i in 0 .. remaining {
			stream.buffer[i] = stream.buffer[int(n) + i]
		}
		stream.position = remaining
	}
}

fn read_be_u32(bytes []u8) u32 {
	return u32(bytes[0]) << 24 | u32(bytes[1]) << 16 | u32(bytes[2]) << 8 | u32(bytes[3])
}

fn append_be_u32(mut bytes []u8, value u32) {
	bytes << [u8(value >> 24), u8(value >> 16), u8(value >> 8), u8(value)]
}
