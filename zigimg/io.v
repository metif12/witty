module zigimg

import os

#flag -I @VMODROOT/zigimg
#include "file_io_shims.h"

fn C.witty_image_file_size(int, &u64) int
fn C.witty_image_file_seek(int, u64) int
fn C.witty_image_file_seek_by(int, u64) int
fn C.witty_image_file_read(int, u64, &u8, usize, &int) isize
fn C.witty_image_file_read_once(int, u64, &u8, usize, &int) isize
fn C.witty_image_file_read_vec(int, u64, &u8, usize, &u8, usize, &int) isize
fn C.witty_image_file_read_vectors(int, u64, &voidptr, &usize, int, &int) isize
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
	file_seek_error    string
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
		file_seek_error: 'Unseekable'
	}
}

pub fn (stream ReadStream) buffered_len() int {
	return stream.end - stream.position
}

// Borrow the pending span without filling or advancing the reader.
pub fn (stream ReadStream) buffered() []u8 {
	return unsafe { stream.buffer[stream.position..stream.end] }
}

pub fn (mut stream ReadStream) toss_buffered() {
	stream.position = stream.end
}

// The adapter borrows the live buffer and position, as io.ReadStream.reader
// does. Keep the owning stream alive while using this pointer.
pub fn (mut stream ReadStream) reader() &ReadStream {
	return &stream
}

pub fn (stream ReadStream) get_pos() u64 {
	if stream.file != none {
		pending := u64(stream.end - stream.position)
		// Source checks this subtraction even after a failed streaming transition.
		if stream.file_pos < pending { panic('integer overflow') }
		return stream.file_pos - pending
	}
	return u64(stream.position)
}

pub fn (mut stream ReadStream) get_end_pos() !u64 {
	if file := stream.file {
		if size := stream.file_size { return size }
		if stream.file_size_error != '' { return error(stream.file_size_error) }
		mut size := u64(0)
		result := C.witty_image_file_size(file.fd, &size)
		// Source std.posix.fstat treats a bad descriptor as unreachable.
		if result == 4 { panic('reached unreachable code') }
		if result != 0 {
			if result == 1 && stream.streaming >= 0 { stream.streaming = 1 }
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
		if stream.streaming < 0 { return error(stream.file_seek_error) }
		if stream.streaming != 0 {
			stream.file_seek_streaming(offset)!
		} else {
			stream.file_set_logical_pos(offset)
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
	if offset > 0 && current > maximum - offset { panic('integer overflow') }
	return current + offset
}

fn (mut stream ReadStream) file_set_logical_pos(offset u64) {
	logical := stream.get_pos()
	if offset < logical || offset >= stream.file_pos {
		stream.position = 0
		stream.end = 0
		stream.file_pos = offset
	} else {
		stream.position += int(offset - logical)
	}
}

fn file_reader_seek_error(result int) string {
	return match result {
		1 { 'Unseekable' }
		2 { 'AccessDenied' }
		else { 'Unexpected' }
	}
}

// File.Reader's streaming seek discards from the descriptor, then clears
// buffered read-ahead. Preserve that behavior even for a zero forward delta.
fn (mut stream ReadStream) file_seek_streaming(offset u64) ! {
	logical := stream.get_pos()
	file := stream.file or { return error('Unexpected') }
	if offset < logical {
		if stream.file_seek_error != '' { return error(stream.file_seek_error) }
		result := C.witty_image_file_seek(file.fd, offset)
		if result == 4 { panic('reached unreachable code') }
		if result != 0 {
			stream.file_seek_error = file_reader_seek_error(result)
			return error(stream.file_seek_error)
		}
		stream.file_set_logical_pos(offset)
		return
	}
	delta := offset - logical
	if delta > u64(0x7fffffffffffffff) { panic('integer cast truncated bits') }
	if stream.file_seek_error == '' {
		mut result := 1
		$if !windows { result = C.witty_image_file_seek_by(file.fd, delta) }
		if result == 4 { panic('reached unreachable code') }
		if result == 0 {
			stream.file_set_logical_pos(offset)
			return
		}
		stream.file_seek_error = file_reader_seek_error(result)
	}
	stream.file_discard_forward(delta)!
	stream.position = 0
	stream.end = 0
}

fn (mut stream ReadStream) file_discard_forward(count u64) ! {
	mut remaining := count
	for remaining > 0 {
		mut trash := []u8{len: if remaining < 128 { int(remaining) } else { 128 }}
		n := stream.file_read(mut trash) or {
			stream.file_seek_error = err.msg()
			return err
		}
		remaining -= u64(n)
	}
}

// A positional reader switching to streaming must first reach its old offset.
// Source resets its position, seeks if possible, otherwise discards forward.
// Failure preserves consumed progress and becomes sticky for later native reads.
fn (mut stream ReadStream) file_prepare_streaming() ! {
	$if !windows {
		if stream.file_pos > u64(0x7fffffffffffffff) { panic('integer cast truncated bits') }
		offset := stream.file_pos
		stream.file_pos = 0
		file := stream.file or { return error('ReadFailed') }
		result := C.witty_image_file_seek_by(file.fd, offset)
		if result == 4 { panic('reached unreachable code') }
		if result == 0 {
			stream.file_pos = offset
		} else {
			stream.file_seek_error = file_reader_seek_error(result)
			stream.file_discard_forward(offset) or {
				stream.streaming = -1
				return error('ReadFailed')
			}
		}
		stream.position = 0
		stream.end = 0
		return
	}
	return error('ReadFailed')
}

fn (mut stream ReadStream) file_read(mut destination []u8) !int {
	if destination.len == 0 { return 0 }
	if stream.streaming < 0 { return error('ReadFailed') }
	file := stream.file or { return error('ReadFailed') }
	count := C.witty_image_file_read(file.fd, stream.file_pos, destination.data,
		usize(destination.len), &stream.streaming)
	if count == -3 {
		stream.file_prepare_streaming()!
		return 0
	}
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
		stream.rebase(usize(count))!
		for stream.end - stream.position < count {
			// File.Reader's native refill reuses the whole buffer after consuming it.
			if stream.position == stream.end && stream.streaming >= 0 {
				stream.position = 0
				stream.end = 0
			}
			mut target := unsafe { stream.buffer[stream.end..] }
			read := stream.file_read(mut target)!
			stream.end += read
		}
	}
	return unsafe { stream.buffer[stream.position..stream.position + count] }
}

pub fn (mut stream ReadStream) fill(count int) ! {
	stream.peek(count)!
}

// Rebase for one additional byte, then invoke the reader once. Switching from
// positional to streaming IO may succeed without adding any buffered bytes.
pub fn (mut stream ReadStream) fill_more() ! {
	if stream.file == none { return error('EndOfStream') }
	stream.rebase(usize(stream.end - stream.position) + 1)!
	if stream.position == stream.end && stream.streaming >= 0 {
		stream.position = 0
		stream.end = 0
	}
	mut target := unsafe { stream.buffer[stream.end..] }
	if stream.streaming < 0 { return error('ReadFailed') }
	file := stream.file or { return error('ReadFailed') }
	read := C.witty_image_file_read_once(file.fd, stream.file_pos, target.data, usize(target.len),
		&stream.streaming)
	if read == -4 { return }
	if read == -3 {
		stream.file_prepare_streaming()!
		return
	}
	if read < 0 { return error('ReadFailed') }
	if read == 0 {
		stream.file_size = stream.file_pos
		return error('EndOfStream')
	}
	stream.file_pos += u64(read)
	stream.end += int(read)
}

// Ensure the minimum, then borrow the whole pending span, including read-ahead.
pub fn (mut stream ReadStream) peek_greedy(count int) ![]u8 {
	stream.fill(count)!
	return stream.buffered()
}

// Ensure room from the current cursor without reading or consuming input.
// Fixed memory cannot move; file buffers compact before the capacity assertion.
pub fn (mut stream ReadStream) rebase(capacity usize) ! {
	if usize(stream.buffer.len - stream.position) >= capacity { return }
	if stream.file == none { return error('EndOfStream') }
	remaining := stream.end - stream.position
	for i in 0 .. remaining {
		stream.buffer[i] = stream.buffer[stream.position + i]
	}
	stream.position = 0
	stream.end = remaining
	if capacity > usize(stream.buffer.len) { panic('reached unreachable code') }
}

pub fn (mut stream ReadStream) peek_byte() !u8 {
	return stream.peek(1)![0]
}

pub fn (mut stream ReadStream) take_byte_signed() !i8 {
	return i8(stream.take_byte()!)
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

// Read the enum's native-width tag before checking its declared values.
// @[nonexhaustive] carries Source's acceptance of unnamed integer tags.
pub fn (mut stream ReadStream) take_enum[T, E](endian E) !T {
	$if T.unaliased_typ is $enum {
		bytes := stream.take(int(sizeof(T)))!
		mut word := u64(0)
		for i, byte in bytes {
			$if E.unaliased_typ is BigEndian {
				word = word << 8 | u64(byte)
			} $else $if E.unaliased_typ is LittleEndian {
				word |= u64(byte) << (i * 8)
			} $else {
				$compile_error('take_enum requires BigEndian or LittleEndian')
			}
		}
		value := unsafe { T(word) }
		$for attribute in T.attributes {
			if attribute.name == 'nonexhaustive' { return value }
		}
		$for entry in T.values {
			if value == unsafe { T(entry.value) } { return value }
		}
		return error('InvalidEnumTag')
	} $else {
		$compile_error('take_enum requires an enum type')
	}
}

// Source requires a nonexhaustive enum at compile time. V's explicit marker
// is checked before any input is touched; type/endian checks remain static.
pub fn (mut stream ReadStream) take_enum_nonexhaustive[T, E](endian E) !T {
	$if T.unaliased_typ is $enum {
		mut nonexhaustive := false
		$for attribute in T.attributes {
			if attribute.name == 'nonexhaustive' { nonexhaustive = true }
		}
		if !nonexhaustive { panic('take_enum_nonexhaustive requires @[nonexhaustive]') }
		return stream.take_enum[T, E](endian)
	} $else {
		$compile_error('take_enum_nonexhaustive requires an enum type')
	}
}

// Read an integer without consuming its bytes, retaining any file read-ahead.
pub fn (mut stream ReadStream) peek_int[T, E](endian E) !T {
	$if T.unaliased_typ is $int {
		bytes := stream.peek(int(sizeof(T)))!
		mut word := u64(0)
		for i, byte in bytes {
			$if E.unaliased_typ is BigEndian {
				word = word << 8 | u64(byte)
			} $else $if E.unaliased_typ is LittleEndian {
				word |= u64(byte) << (i * 8)
			} $else {
				$compile_error('peek_int requires BigEndian or LittleEndian')
			}
		}
		return T(word)
	} $else {
		$compile_error('peek_int requires a native integer type')
	}
}

// Short representations are zero-extended, including into signed types. Only
// a representation occupying the full target width sets its signed high bit.
pub fn (mut stream ReadStream) take_var_int[T, E](endian E, count usize) !T {
	$if T.unaliased_typ is $int {
		if count > usize(sizeof(T)) { panic('reached unreachable code') }
		bytes := stream.take(int(count))!
		mut word := u64(0)
		for i, byte in bytes {
			$if E.unaliased_typ is BigEndian {
				word = word << 8 | u64(byte)
			} $else $if E.unaliased_typ is LittleEndian {
				word |= u64(byte) << (i * 8)
			} $else {
				$compile_error('take_var_int requires BigEndian or LittleEndian')
			}
		}
		return T(word)
	} $else {
		$compile_error('take_var_int requires a native integer type')
	}
}

// Decode through the terminator before reporting overflow. Preserve the wider
// seven-bit grouping used by Source, including its 70-bit intermediate for u64.
pub fn (mut stream ReadStream) take_leb128[T]() !T {
	$if T.unaliased_typ is $int {
		maximum_groups := (int(sizeof(T)) * 8 + 6) / 7
		mut groups := 0
		mut word := u64(0)
		mut high := u8(0)
		mut negative := false
		mut fits := true
		for {
			bytes := stream.peek_greedy(1)!
			for index, byte in bytes {
				payload := byte & 0x7f
				if groups < maximum_groups {
					shift := groups * 7
					if shift == 63 {
						word |= u64(payload & 1) << 63
						high = payload >> 1
					} else {
						word |= u64(payload) << shift
					}
					negative = payload & 0x40 != 0
					groups++
				} else if fits {
					$if T.unaliased_typ is i8 || T.unaliased_typ is i16 || T.unaliased_typ is int
						|| T.unaliased_typ is i64 || T.unaliased_typ is isize {
						fits = payload == if negative { u8(0x7f) } else { u8(0) }
					} $else {
						fits = payload == 0
					}
				}
				if byte & 0x80 != 0 { continue
				 }
				stream.toss(usize(index + 1))
				if !fits { return error('Overflow') }
				$if T.unaliased_typ is i8 || T.unaliased_typ is i16 || T.unaliased_typ is int
					|| T.unaliased_typ is i64 || T.unaliased_typ is isize {
					bits := groups * 7
					if bits > 64 {
						expected_high := if negative { u8(0x3f) } else { u8(0) }
						if high != expected_high || (word >> 63 != 0) != negative {
							return error('Overflow')
						}
					} else if negative {
						word |= ~u64(0) << bits
					}
					value := T(word)
					if i64(value) != i64(word) { return error('Overflow') }
					return value
				} $else {
					value := T(word)
					if high != 0 || u64(value) != word { return error('Overflow') }
					return value
				}
			}
			stream.toss(usize(bytes.len))
		}
	} $else {
		$compile_error('take_leb128 requires a native integer type')
	}
	panic('reached unreachable code')
}

fn reader_array_length[A](value A) int {
	$if A.indirections > 0 || ((int(A.unaliased_typ) >> 16) & 0xff) > 0 {
		$compile_error('Reader array requires an inline fixed byte array')
	} $else $if A.unaliased_typ is $array_fixed {
		reader_array_byte(value[0])
		return value.len
	} $else {
		$compile_error('Reader array requires an inline fixed byte array')
	}
}

fn reader_array_byte[T](value T) {
	$if T.indirections > 0 || ((int(T.unaliased_typ) >> 16) & 0xff) > 0 {
		$compile_error('Reader array requires byte elements')
	} $else $if T.unaliased_typ is u8 {
		_ = value
	} $else {
		$compile_error('Reader array requires byte elements')
	}
}

// A names a fixed byte array, such as `type HeaderBytes = [8]u8`.
// The record carries the borrowed pointer through V's fallible return machinery.
pub struct ReaderArray[A] {
pub mut:
	value &A
}

// The pointer remains valid until the next operation that can refill the reader.
pub fn (mut stream ReadStream) peek_array[A]() !ReaderArray[A] {
	shape := A{}
	bytes := stream.peek(reader_array_length(shape))!
	return ReaderArray[A]{
		value: unsafe { voidptr(bytes.data) }
	}
}

pub fn (mut stream ReadStream) take_array[A]() !ReaderArray[A] {
	shape := A{}
	bytes := stream.take(reader_array_length(shape))!
	return ReaderArray[A]{
		value: unsafe { voidptr(bytes.data) }
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
		// Reader.fillMore requests one more byte. Retain the prefix in place
		// while the tail has room; readVec resets an entirely consumed buffer.
		if stream.position == stream.end && stream.streaming >= 0 {
			stream.position = 0
			stream.end = 0
		} else if stream.end == stream.buffer.len {
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

// V represents a sentinel-terminated slice with its complete borrowed span.
// Only the reader constructs these views; bytes() omits the final sentinel.
@[noinit]
pub struct SentinelSlice {
	storage []u8
}

pub fn (view SentinelSlice) bytes() []u8 {
	return unsafe { view.storage[..view.storage.len - 1] }
}

pub fn (view SentinelSlice) with_sentinel() []u8 {
	return unsafe { view.storage }
}

pub fn (mut stream ReadStream) peek_sentinel(sentinel u8) !SentinelSlice {
	line := stream.peek_delimiter_inclusive(sentinel)!
	return SentinelSlice{
		storage: unsafe { line }
	}
}

pub fn (mut stream ReadStream) take_sentinel(sentinel u8) !SentinelSlice {
	line := stream.peek_delimiter_inclusive(sentinel)!
	stream.toss(usize(line.len))
	return SentinelSlice{
		storage: unsafe { line }
	}
}

pub fn (mut stream ReadStream) take_delimiter_inclusive(delimiter u8) ![]u8 {
	line := stream.peek_delimiter_inclusive(delimiter)!
	stream.position += line.len
	return line
}

// EOF supplies the remaining nonempty prefix for the exclusive APIs. A
// delimiter at the current cursor succeeds with an empty borrowed slice.
pub fn (mut stream ReadStream) peek_delimiter_exclusive(delimiter u8) ![]u8 {
	line := stream.peek_delimiter_inclusive(delimiter) or {
		if err.msg() != 'EndOfStream' { return err }
		if stream.position == stream.end { return err }
		return unsafe { stream.buffer[stream.position..stream.end] }
	}
	return unsafe { line[..line.len - 1] }
}

// Source advances only over the returned prefix, leaving its delimiter unread.
pub fn (mut stream ReadStream) take_delimiter_exclusive(delimiter u8) ![]u8 {
	line := stream.peek_delimiter_exclusive(delimiter)!
	stream.position += line.len
	return line
}

// V represents Source's error union containing an optional slice with a
// result record. A present empty line differs from the absent line at EOF.
pub struct DelimiterResult {
pub:
	line ?[]u8
}

// Omit the delimiter from the borrowed result, but consume it when present.
// A nonempty EOF tail is returned once; subsequent EOF returns an absent line.
pub fn (mut stream ReadStream) take_delimiter(delimiter u8) !DelimiterResult {
	line := stream.peek_delimiter_inclusive(delimiter) or {
		if err.msg() != 'EndOfStream' { return err }
		if stream.position == stream.end { return DelimiterResult{} }
		remaining := unsafe { stream.buffer[stream.position..stream.end] }
		stream.position += remaining.len
		return DelimiterResult{
			line: unsafe { remaining }
		}
	}
	stream.position += line.len
	return DelimiterResult{
		line: unsafe { line[..line.len - 1] }
	}
}

// std.Io.Reader.readVec with one destination vector, and File.Reader's
// positional/streaming native scatter read including buffered read-ahead.
fn (mut stream ReadStream) read_vec_one(mut destination []u8) !int {
	remaining := stream.end - stream.position
	count := if destination.len < remaining { destination.len } else { remaining }
	copy(mut destination, stream.take(count)!)
	if count == destination.len { return count }
	if stream.file == none {
		if count == 0 { return error('EndOfStream') }
		return count
	}
	if stream.streaming < 0 { return error('ReadFailed') }
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
	if n == -3 {
		stream.file_prepare_streaming()!
		return count
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

// Transfer pending bytes before invoking one native scatter-read callback.
// Restore a temporarily shortened destination header on returns and IO errors.
pub fn (mut stream ReadStream) read_vec(mut destinations [][]u8) !usize {
	mut seek := stream.position
	for i in 0 .. destinations.len {
		mut destination := unsafe { destinations[i] }
		remaining := stream.end - seek
		count := if remaining < destination.len { remaining } else { destination.len }
		mut target := unsafe { destination[..count] }
		copy(mut target, unsafe { stream.buffer[seek..seek + count] })
		seek += count
		if count == destination.len { continue
		 }
		copied := usize(seek - stream.position)
		stream.position = seek
		destinations[i] = unsafe { destination[count..] }
		defer { destinations[i] = unsafe { destination } }
		mut tail := unsafe { destinations[i..] }
		read := stream.file_read_vectors(mut tail) or {
			if err.msg() == 'EndOfStream' && copied != 0 { return copied }
			return err
		}
		return copied + read
	}
	count := usize(seek - stream.position)
	stream.position = seek
	return count
}

fn (mut stream ReadStream) file_read_vectors(mut destinations [][]u8) !usize {
	if stream.file == none { return error('EndOfStream') }
	if stream.streaming < 0 { return error('ReadFailed') }
	$if windows {
		mut first := unsafe { destinations[0] }
		return usize(stream.read_vec_one(mut first)!)
	} $else {
		file := stream.file or { return error('ReadFailed') }
		mut bases := unsafe { [16]voidptr{} }
		mut lengths := [16]usize{}
		mut count := 0
		mut data_size := usize(0)
		mut full := false
		for destination in destinations {
			if count == 16 {
				full = true
				break
			}
			if destination.len == 0 { continue
			 }
			bases[count] = destination.data
			lengths[count] = usize(destination.len)
			data_size += usize(destination.len)
			count++
		}
		if !full && stream.buffer.len != 0 {
			stream.position = 0
			stream.end = 0
			// Pinned writableVectorPosix appends before checking this last slot.
			if count == 16 { panic('index out of bounds: index 16, len 16') }
			bases[count] = stream.buffer.data
			lengths[count] = usize(stream.buffer.len)
			count++
		}
		n := C.witty_image_file_read_vectors(file.fd, stream.file_pos, &bases[0], &lengths[0],
			count, &stream.streaming)
		if n == -3 {
			stream.file_prepare_streaming()!
			return 0
		}
		if n == -4 { return 0 }
		if n < 0 { return error('ReadFailed') }
		if n == 0 {
			stream.file_size = stream.file_pos
			return error('EndOfStream')
		}
		stream.file_pos += u64(n)
		if usize(n) > data_size {
			stream.end += int(usize(n) - data_size)
			return data_size
		}
		return usize(n)
	}
}

// Fill every destination, retaining partial writes if a later read fails.
pub fn (mut stream ReadStream) read_vec_all(mut destinations [][]u8) ! {
	mut index := 0
	mut truncate := usize(0)
	for index < destinations.len {
		{
			original := unsafe { destinations[index] }
			destinations[index] = unsafe { original[int(truncate)..] }
			defer { destinations[index] = unsafe { original } }
			mut tail := unsafe { destinations[index..] }
			truncate += stream.read_vec(mut tail)!
		}
		for index < destinations.len && truncate >= usize(destinations[index].len) {
			truncate -= usize(destinations[index].len)
			index++
		}
	}
}

pub fn (mut stream ReadStream) read_slice_short(mut destination []u8) !usize {
	mut filled := 0
	for filled < destination.len {
		mut target := unsafe { destination[filled..] }
		filled += stream.read_vec_one(mut target) or {
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

// Read the whole integer slice before converting byte order. A failed read
// leaves its copied prefix in the caller's native storage without swapping.
pub fn (mut stream ReadStream) read_slice_endian[T, E](mut destination []T, endian E) ! {
	$if T.unaliased_typ is $int {
		$if E.unaliased_typ is BigEndian || E.unaliased_typ is LittleEndian {
			if destination.len > 0x7fffffff / int(sizeof(T)) {
				panic('Reader byte span exceeds V array length')
			}
			mut bytes := unsafe { destination.data.vbytes(destination.len * int(sizeof(T))) }
			stream.read_slice_all(mut bytes)!
			mut swap := false
			$if E.unaliased_typ is BigEndian {
				$if little_endian { swap = true }
			} $else {
				$if big_endian { swap = true }
			}
			if swap {
				width := int(sizeof(T))
				for i in 0 .. destination.len {
					for j in 0 .. width / 2 {
						a, b := i * width + j, (i + 1) * width - 1 - j
						bytes[a], bytes[b] = bytes[b], bytes[a]
					}
				}
			}
		} $else {
			$compile_error('read_slice_endian requires BigEndian or LittleEndian')
		}
	} $else {
		$compile_error('read_slice_endian requires a native integer type')
	}
}

// GC owns the returned allocation. Read failure retains reader progress and
// leaves the incomplete allocation unreachable rather than returning its prefix.
pub fn (mut stream ReadStream) read_alloc(count usize) ![]u8 {
	if count > usize(0x7fffffff) { panic('Reader allocation exceeds V array length') }
	mut destination := []u8{len: int(count)}
	stream.read_slice_all(mut destination)!
	return destination
}

pub fn (mut stream ReadStream) read_slice_endian_alloc[T, E](count usize, endian E) ![]T {
	$if T.unaliased_typ is $int {
		$if E.unaliased_typ is BigEndian || E.unaliased_typ is LittleEndian {
			if count > usize(0x7fffffff) / usize(sizeof(T)) {
				panic('Reader allocation exceeds V array length')
			}
			mut destination := []T{len: int(count)}
			stream.read_slice_endian[T, E](mut destination, endian)!
			return destination
		} $else {
			$compile_error('read_slice_endian_alloc requires BigEndian or LittleEndian')
		}
	} $else {
		$compile_error('read_slice_endian_alloc requires a native integer type')
	}
}

fn (mut stream ReadStream) flate_fill_word() ! {
	stream.peek(int(sizeof(usize)))!
}

fn (stream ReadStream) flate_buffered_len() int {
	return stream.end - stream.position
}

fn (mut stream ReadStream) flate_read_vec(mut destination []u8) !int {
	return stream.read_vec_one(mut destination)
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
	read := stream.read_vec_one(mut destination)!
	return destination[..read]
}

// File.Reader's discard callback uses cached size only while both error caches
// are clear. A failed physical seek selects read-based discard for later calls.
fn (mut stream ReadStream) file_discard(count u64) !u64 {
	if stream.file == none { return error('EndOfStream') }
	if stream.streaming < 0 { return error('ReadFailed') }
	if stream.streaming == 0 {
		size := stream.get_end_pos() or {
			stream.streaming = 1
			return 0
		}
		available := size - stream.file_pos
		delta := if count < available { count } else { available }
		stream.file_pos += delta
		return delta
	}
	if stream.file_size_error == '' && stream.file_seek_error == '' {
		size := stream.get_end_pos() or { return 0 }
		available := size - stream.file_pos
		delta := if count < available { count } else { available }
		limited := if delta < u64(0x7fffffffffffffff) { delta } else { u64(0x7fffffffffffffff) }
		file := stream.file or { return error('ReadFailed') }
		mut result := 1
		$if !windows { result = C.witty_image_file_seek_by(file.fd, limited) }
		if result == 4 { panic('reached unreachable code') }
		if result != 0 {
			stream.file_seek_error = file_reader_seek_error(result)
			return 0
		}
		stream.file_pos += limited
		return limited
	}
	mut trash := []u8{len: if count < 128 { int(count) } else { 128 }}
	return u64(stream.file_read(mut trash)!)
}

// Scan every available buffered byte after filling to at least one byte.
// Reaching the limit fails even if EOF or a delimiter is exactly next.
pub fn (mut stream ReadStream) discard_delimiter_limit(delimiter u8, limit usize) !usize {
	mut remaining := limit
	for remaining != 0 {
		stream.peek(1) or {
			if err.msg() == 'EndOfStream' { return limit - remaining }
			return err
		}
		available := usize(stream.end - stream.position)
		count := if remaining < available { remaining } else { available }
		for index in 0 .. int(count) {
			if stream.buffer[stream.position + index] == delimiter {
				stream.toss(usize(index))
				remaining -= usize(index)
				return limit - remaining
			}
		}
		stream.toss(count)
		remaining -= count
	}
	return error('StreamTooLong')
}

// EOF succeeds with the discarded prefix; a found delimiter stays unread.
pub fn (mut stream ReadStream) discard_delimiter_exclusive(delimiter u8) !usize {
	return stream.discard_delimiter_limit(delimiter, ~usize(0)) or {
		if err.msg() == 'StreamTooLong' { panic('reached unreachable code') }
		return err
	}
}

// Unlike exclusive discard, absence of a delimiter fails after consuming the
// EOF prefix. A found delimiter is counted and consumed.
pub fn (mut stream ReadStream) discard_delimiter_inclusive(delimiter u8) !usize {
	count := stream.discard_delimiter_exclusive(delimiter)!
	if stream.position == stream.end { return error('EndOfStream') }
	if stream.buffer[stream.position] != delimiter { panic('reached unreachable code') }
	stream.toss(1)
	if count == ~usize(0) { panic('integer overflow') }
	return count + 1
}

// Each span is consumed only after write_all succeeds. A failing writer may
// retain a partial span while the same bytes remain buffered in the reader.
pub fn (mut stream ReadStream) stream_delimiter_limit(mut writer WriteStream, delimiter u8, limit usize) !usize {
	mut remaining := limit
	for remaining != 0 {
		stream.peek(1) or {
			if err.msg() == 'EndOfStream' { return limit - remaining }
			return err
		}
		available := usize(stream.end - stream.position)
		count := if remaining < available { remaining } else { available }
		for index in 0 .. int(count) {
			if stream.buffer[stream.position + index] == delimiter {
				writer.write_all(stream.buffer[stream.position..stream.position + index])!
				stream.toss(usize(index))
				remaining -= usize(index)
				return limit - remaining
			}
		}
		writer.write_all(stream.buffer[stream.position..stream.position + int(count)])!
		stream.toss(count)
		remaining -= count
	}
	return error('StreamTooLong')
}

pub fn (mut stream ReadStream) stream_delimiter_ending(mut writer WriteStream, delimiter u8) !usize {
	return stream.stream_delimiter_limit(mut writer, delimiter, ~usize(0)) or {
		if err.msg() == 'StreamTooLong' { panic('reached unreachable code') }
		return err
	}
}

pub fn (mut stream ReadStream) stream_delimiter(mut writer WriteStream, delimiter u8) !usize {
	count := stream.stream_delimiter_ending(mut writer, delimiter)!
	if stream.position == stream.end { return error('EndOfStream') }
	return count
}

// Consume up to count bytes; EOF returns the consumed prefix, while read errors
// retain progress and propagate. Source checks the proposed seek before mutation.
pub fn (mut stream ReadStream) discard_short(count usize) !usize {
	if count > ~usize(0) - usize(stream.position) { panic('integer overflow') }
	proposed := usize(stream.position) + count
	if proposed <= usize(stream.end) {
		stream.position = int(proposed)
		return count
	}
	mut remaining := count - usize(stream.end - stream.position)
	stream.position = stream.end
	for {
		discarded := stream.file_discard(u64(remaining)) or {
			if err.msg() == 'EndOfStream' { return count - remaining }
			return err
		}
		remaining -= usize(discarded)
		if remaining == 0 { return count }
	}
	panic('reached unreachable code')
}

// Drain pending bytes and then the callback until it discovers EOF. Preserve
// Source's zero-progress loop when a cached positional size is exhausted.
pub fn (mut stream ReadStream) discard_remaining() !usize {
	mut offset := usize(stream.end - stream.position)
	stream.position = stream.end
	for {
		discarded := stream.file_discard(u64(~usize(0))) or {
			if err.msg() == 'EndOfStream' { return offset }
			return err
		}
		if discarded > u64(~usize(0) - offset) { panic('integer overflow') }
		offset += usize(discarded)
	}
	panic('reached unreachable code')
}

pub fn (mut stream ReadStream) discard_all64(count u64) ! {
	mut remaining := count
	for remaining > 0 {
		chunk := if remaining < u64(~usize(0)) { usize(remaining) } else { ~usize(0) }
		if stream.discard_short(chunk)! != chunk { return error('EndOfStream') }
		remaining -= u64(chunk)
	}
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
		remaining -= usize(stream.file_discard(u64(remaining))!)
		// Preserve Source's zero-progress loop when the positional/cached size
		// is exhausted without a native read discovering end-of-stream.
	}
}

pub fn (mut stream ReadStream) toss(count usize) {
	// Source updates seek before its end assertion. V array cursors use int;
	// a failed offset beyond that carrier remains a representation boundary.
	if count > ~usize(0) - usize(stream.position) { panic('integer overflow') }
	if count > usize(0x7fffffff - stream.position) {
		panic('reached unreachable code')
	}
	stream.position += int(count)
	if stream.position > stream.end { panic('reached unreachable code') }
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
		panic('integer overflow')
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
			if result == 4 { panic('reached unreachable code') }
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
