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
fn C.witty_image_file_write_vectors(int, u64, &voidptr, &usize, int, &int) isize

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

// Borrow the remaining output space without reserving or draining it.
pub fn (stream WriteStream) unused_capacity_slice() []u8 {
	return unsafe { stream.buffer[stream.position..] }
}

pub fn (stream WriteStream) unused_capacity_len() usize {
	return usize(stream.buffer.len - stream.position)
}

// Keep Source's checked addition and capacity assertion before cursor mutation.
pub fn (mut stream WriteStream) advance(count usize) {
	if count > ~usize(0) - usize(stream.position) { panic('integer overflow') }
	end := usize(stream.position) + count
	if end > usize(stream.buffer.len) { panic('reached unreachable code') }
	stream.position = int(end)
}

pub fn (mut stream WriteStream) undo(count usize) {
	if count > usize(stream.position) { panic('integer overflow') }
	stream.position -= int(count)
}

// Account for drained bytes by shifting pending output; return any excess count.
pub fn (mut stream WriteStream) consume(count usize) usize {
	if count < usize(stream.position) {
		remaining := stream.position - int(count)
		for i in 0 .. remaining {
			stream.buffer[i] = stream.buffer[int(count) + i]
		}
		stream.position = remaining
		return 0
	}
	remaining := count - usize(stream.position)
	stream.position = 0
	return remaining
}

pub fn (mut stream WriteStream) consume_all() usize {
	stream.position = 0
	return 0
}

// Drain once while default rebase temporarily hides its preserved tail.
fn (mut stream WriteStream) drain_buffer_once() ! {
	if stream.position == 0 { return }
	if stream.streaming < 0 { return error('WriteFailed') }
	file := stream.file or { return error('WriteFailed') }
	n := C.witty_image_file_write(file.fd, stream.file_pos, stream.buffer.data,
		usize(stream.position), unsafe { nil }, 0, &stream.streaming)
	if n < 0 {
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

pub fn (mut stream WriteStream) rebase(preserve usize, minimum_len usize) ! {
	if stream.unused_capacity_len() >= minimum_len { return }
	// The fixed writer uses failingRebase, without changing its buffer.
	if stream.file == none { return error('WriteFailed') }
	for stream.unused_capacity_len() < minimum_len {
		preserved_len := int(if preserve < usize(stream.position) {
			preserve
		} else {
			usize(stream.position)
		})
		preserved_head := stream.position - preserved_len
		{
			stream.position = preserved_head
			defer { stream.position += preserved_len }
			stream.drain_buffer_once()!
			if stream.position > preserved_head + preserved_len { panic('reached unreachable code') }
			// The destination precedes the source, including overlapping tails.
			for i in 0 .. preserved_len {
				stream.buffer[stream.position + i] = stream.buffer[preserved_head + i]
			}
		}
		if preserve > usize(stream.buffer.len) { panic('integer overflow') }
		if usize(stream.buffer.len) - preserve < minimum_len { panic('reached unreachable code') }
	}
}

pub fn (mut stream WriteStream) writable_slice_greedy_preserve(preserve usize, minimum_len usize) ![]u8 {
	if stream.unused_capacity_len() >= minimum_len { return stream.unused_capacity_slice() }
	stream.rebase(preserve, minimum_len)!
	if minimum_len > ~usize(0) - preserve { panic('integer overflow') }
	if usize(stream.buffer.len) < preserve + minimum_len { panic('reached unreachable code') }
	return stream.unused_capacity_slice()
}

pub fn (mut stream WriteStream) writable_slice_greedy(minimum_len usize) ![]u8 {
	return stream.writable_slice_greedy_preserve(0, minimum_len)
}

pub fn (mut stream WriteStream) writable_slice_preserve(preserve usize, len usize) ![]u8 {
	bytes := stream.writable_slice_greedy_preserve(preserve, len)!
	stream.advance(len)
	return unsafe { bytes[..int(len)] }
}

pub fn (mut stream WriteStream) writable_slice(len usize) ![]u8 {
	return stream.writable_slice_preserve(0, len)
}

pub fn (mut stream WriteStream) ensure_unused_capacity(count usize) ! {
	stream.writable_slice_greedy(count)!
}

fn writer_array_length[A](value A) int {
	$if A.indirections > 0 || ((int(A.unaliased_typ) >> 16) & 0xff) > 0 {
		$compile_error('Writer array requires an inline fixed byte array')
	} $else $if A.unaliased_typ is $array_fixed {
		writer_array_byte(value[0])
		return value.len
	} $else {
		$compile_error('Writer array requires an inline fixed byte array')
	}
}

fn writer_array_byte[T](value T) {
	$if T.indirections > 0 || ((int(T.unaliased_typ) >> 16) & 0xff) > 0 {
		$compile_error('Writer array requires byte elements')
	} $else $if T.unaliased_typ is u8 {
		_ = value
	} $else {
		$compile_error('Writer array requires byte elements')
	}
}

// Carry a borrowed fixed-array pointer through V's fallible return machinery.
pub struct WriterArray[A] {
pub mut:
	value &A
}

pub fn (mut stream WriteStream) writable_array[A]() !WriterArray[A] {
	shape := A{}
	len := writer_array_length(shape)
	bytes := stream.writable_slice_greedy(usize(len))!
	stream.advance(usize(len))
	return WriterArray[A]{
		value: unsafe { voidptr(bytes.data) }
	}
}

pub fn (mut stream WriteStream) write_byte_preserve(preserve usize, byte u8) ! {
	if stream.unused_capacity_len() == 0 { stream.rebase(preserve, 1)! }
	stream.buffer[stream.position] = byte
	stream.position++
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

// Count all prefix vectors and repeat only the last vector.
pub fn count_splat(data [][]u8, splat usize) usize {
	if data.len == 0 { panic('integer overflow') }
	mut total := usize(0)
	for bytes in data[..data.len - 1] {
		if usize(bytes.len) > ~usize(0) - total { panic('integer overflow') }
		total += usize(bytes.len)
	}
	pattern_len := usize(data[data.len - 1].len)
	if pattern_len != 0 && splat > ~usize(0) / pattern_len { panic('integer overflow') }
	last := pattern_len * splat
	if last > ~usize(0) - total { panic('integer overflow') }
	return total + last
}

// Make one drain at most; pending output occupies the first of 16 file slots.
pub fn (mut stream WriteStream) write_vec(data [][]u8) !usize {
	if data.len == 0 { panic('reached unreachable code') }
	count := count_splat(data, 1)
	if count > ~usize(0) - usize(stream.position) { panic('integer overflow') }
	if usize(stream.position) + count <= usize(stream.buffer.len) {
		for bytes in data {
			for i, byte in bytes {
				stream.buffer[stream.position + i] = byte
			}
			stream.position += bytes.len
		}
		return count
	}
	if file := stream.file {
		mut pointers := unsafe { [16]voidptr{} }
		mut lengths := [16]usize{}
		mut slots := 0
		if stream.position > 0 {
			pointers[slots] = stream.buffer.data
			lengths[slots] = usize(stream.position)
			slots++
		}
		for bytes in data {
			if bytes.len == 0 { continue
			 }
			if slots == pointers.len { break
			 }
			pointers[slots] = bytes.data
			lengths[slots] = usize(bytes.len)
			slots++
		}
		n := C.witty_image_file_write_vectors(file.fd, stream.file_pos, &pointers[0], &lengths[0],
			slots, &stream.streaming)
		if n < 0 {
			if stream.streaming < 0 {
				stream.file_pos = 0
				stream.file_seek_error = 'Unseekable'
			}
			return error('WriteFailed')
		}
		if u64(n) > u64(0xffffffffffffffff) - stream.file_pos { panic('integer overflow') }
		stream.file_pos += u64(n)
		if n < stream.position {
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
	for bytes in data {
		space := stream.buffer.len - stream.position
		len := if bytes.len < space { bytes.len } else { space }
		for i in 0 .. len {
			stream.buffer[stream.position + i] = bytes[i]
		}
		stream.position += len
		if bytes.len > space { return error('WriteFailed') }
	}
	panic('reached unreachable code')
}

// Repeat the final vector while copying every prefix once, with one drain at most.
pub fn (mut stream WriteStream) write_splat(data [][]u8, splat usize) !usize {
	if data.len == 0 { panic('reached unreachable code') }
	count := count_splat(data, splat)
	if count > ~usize(0) - usize(stream.position) { panic('integer overflow') }
	pattern := data[data.len - 1]
	if usize(stream.position) + count <= usize(stream.buffer.len) {
		for bytes in data[..data.len - 1] {
			for i, byte in bytes {
				stream.buffer[stream.position + i] = byte
			}
			stream.position += bytes.len
		}
		if pattern.len == 1 {
			for i in 0 .. int(splat) {
				stream.buffer[stream.position + i] = pattern[0]
			}
			stream.position += int(splat)
		} else if pattern.len > 1 {
			for _ in 0 .. int(splat) {
				for i, byte in pattern {
					stream.buffer[stream.position + i] = byte
				}
				stream.position += pattern.len
			}
		}
		return count
	}
	if stream.file != none { return stream.file_write_splat(data, splat) }
	for bytes in data[..data.len - 1] {
		space := stream.buffer.len - stream.position
		len := if bytes.len < space { bytes.len } else { space }
		for i in 0 .. len {
			stream.buffer[stream.position + i] = bytes[i]
		}
		stream.position += len
		if bytes.len > space { return error('WriteFailed') }
	}
	if pattern.len == 0 { return 0 }
	if pattern.len == 1 {
		space := stream.buffer.len - stream.position
		if splat < usize(space) { panic('reached unreachable code') }
		for i in 0 .. space {
			stream.buffer[stream.position + i] = pattern[0]
		}
		stream.position += space
		return error('WriteFailed')
	}
	mut remaining := splat
	for remaining > 0 {
		space := stream.buffer.len - stream.position
		len := if pattern.len < space { pattern.len } else { space }
		for i in 0 .. len {
			stream.buffer[stream.position + i] = pattern[i]
		}
		stream.position += len
		if pattern.len > space { return error('WriteFailed') }
		remaining--
	}
	panic('reached unreachable code')
}

fn (mut stream WriteStream) file_write_splat(data [][]u8, splat usize) !usize {
	file := stream.file or { return error('WriteFailed') }
	mut pointers := unsafe { [16]voidptr{} }
	mut lengths := [16]usize{}
	mut slots := 0
	if stream.position > 0 {
		pointers[slots] = stream.buffer.data
		lengths[slots] = usize(stream.position)
		slots++
	}
	for bytes in data[..data.len - 1] {
		if bytes.len == 0 { continue
		 }
		pointers[slots] = bytes.data
		lengths[slots] = usize(bytes.len)
		slots++
		if slots == pointers.len { break
		 }
	}
	pattern := data[data.len - 1]
	mut backup := [64]u8{}
	if slots < pointers.len && splat > 0 && pattern.len > 0 {
		$if windows {
			pointers[slots] = pattern.data
			lengths[slots] = usize(pattern.len)
			slots++
		} $else {
			if splat == 1 {
				pointers[slots] = pattern.data
				lengths[slots] = usize(pattern.len)
				slots++
			} else if pattern.len == 1 {
				mut scratch := unsafe { backup[..] }
				if stream.buffer.len - stream.position >= backup.len {
					scratch = unsafe { stream.buffer[stream.position..] }
				}
				len := if splat < usize(scratch.len) { int(splat) } else { scratch.len }
				for i in 0 .. len {
					scratch[i] = pattern[0]
				}
				pointers[slots] = scratch.data
				lengths[slots] = usize(len)
				slots++
				mut remaining := splat - usize(len)
				for remaining > usize(scratch.len) && slots < pointers.len {
					pointers[slots] = scratch.data
					lengths[slots] = usize(scratch.len)
					slots++
					remaining -= usize(scratch.len)
				}
				if remaining > 0 && slots < pointers.len {
					pointers[slots] = scratch.data
					lengths[slots] = remaining
					slots++
				}
			} else {
				mut remaining := splat
				for remaining > 0 && slots < pointers.len {
					pointers[slots] = pattern.data
					lengths[slots] = usize(pattern.len)
					slots++
					remaining--
				}
			}
		}
	}
	if slots == 0 { return 0 }
	n := C.witty_image_file_write_vectors(file.fd, stream.file_pos, &pointers[0], &lengths[0],
		slots, &stream.streaming)
	if n < 0 {
		if stream.streaming < 0 {
			stream.file_pos = 0
			stream.file_seek_error = 'Unseekable'
		}
		return error('WriteFailed')
	}
	if u64(n) > u64(0xffffffffffffffff) - stream.file_pos { panic('integer overflow') }
	stream.file_pos += u64(n)
	if n < stream.position {
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

// Consume a header followed by prefix vectors and a repeated final vector.
pub fn (mut stream WriteStream) write_splat_header(header []u8, data [][]u8, splat usize) !usize {
	return stream.write_splat_header_limit(header, data, splat, Limit.unlimited())
}

pub fn (mut stream WriteStream) write_splat_header_limit(header []u8, data [][]u8, splat usize, limit Limit) !usize {
	mut remaining := limit.value
	mut len := int(Limit.limited(remaining).min_int(usize(header.len)))
	if len > stream.buffer.len - stream.position { len = stream.buffer.len - stream.position }
	if header.len != len {
		return stream.write_splat_header_limit_finish(header, data, splat, remaining)
	}
	for i in 0 .. len {
		stream.buffer[stream.position + i] = header[i]
	}
	stream.position += len
	remaining -= usize(len)
	if data.len == 0 { panic('integer overflow') }
	for index, bytes in data[..data.len - 1] {
		len = int(Limit.limited(remaining).min_int(usize(bytes.len)))
		if len > stream.buffer.len - stream.position { len = stream.buffer.len - stream.position }
		if bytes.len != len {
			written := stream.write_splat_header_limit_finish([]u8{}, data[index..], splat,
				remaining)!
			buffered := limit.value - remaining
			if written > ~usize(0) - buffered { panic('integer overflow') }
			return buffered + written
		}
		for i in 0 .. len {
			stream.buffer[stream.position + i] = bytes[i]
		}
		stream.position += len
		remaining -= usize(len)
	}
	pattern := data[data.len - 1]
	if pattern.len != 0 && splat > ~usize(0) / usize(pattern.len) { panic('integer overflow') }
	count := usize(pattern.len) * splat
	if count > Limit.limited(remaining).min_int(usize(stream.buffer.len - stream.position)) {
		buffered := limit.value - remaining
		written := stream.write_splat_header_limit_finish([]u8{}, data[data.len - 1..], splat,
			remaining)!
		if written > ~usize(0) - buffered { panic('integer overflow') }
		return buffered + written
	}
	if pattern.len > 0 {
		for _ in 0 .. int(splat) {
			for i, byte in pattern {
				stream.buffer[stream.position + i] = byte
			}
			stream.position += pattern.len
		}
	}
	remaining -= count
	return limit.value - remaining
}

fn (mut stream WriteStream) write_splat_header_limit_finish(header []u8, data [][]u8, splat usize, limit usize) !usize {
	mut remaining := limit
	mut vecs := [][]u8{cap: 8}
	if header.len != 0 {
		len := int(Limit.limited(remaining).min_int(usize(header.len)))
		vecs << unsafe { header[..len] }
		remaining -= usize(len)
		if remaining == 0 { return stream.header_drain(vecs, 1) }
	}
	if data.len == 0 { panic('integer overflow') }
	for bytes in data[..data.len - 1] {
		if bytes.len == 0 { continue
		 }
		// The pinned Writer uses header.len here and passes the entire prefix.
		len := Limit.limited(remaining).min_int(usize(header.len))
		vecs << unsafe { bytes }
		remaining -= len
		if remaining == 0 || vecs.len == 8 { return stream.header_drain(vecs, 1) }
	}
	pattern := data[data.len - 1]
	if splat == 1 {
		len := int(Limit.limited(remaining).min_int(usize(pattern.len)))
		vecs << unsafe { pattern[..len] }
		return stream.header_drain(vecs, 1)
	}
	vecs << unsafe { pattern }
	if pattern.len == 0 { panic('division by zero') }
	return stream.header_drain(vecs, Limit.limited(remaining / usize(pattern.len)).min_int(splat))
}

// Call drain directly: its fixed-buffer behavior differs from write_splat's fast path.
fn (mut stream WriteStream) header_drain(data [][]u8, splat usize) !usize {
	if stream.file != none { return stream.file_write_splat(data, splat) }
	if data.len == 0 { return 0 }
	for bytes in data[..data.len - 1] {
		space := stream.buffer.len - stream.position
		len := if bytes.len < space { bytes.len } else { space }
		for i in 0 .. len {
			stream.buffer[stream.position + i] = bytes[i]
		}
		stream.position += len
		if bytes.len > space { return error('WriteFailed') }
	}
	pattern := data[data.len - 1]
	if pattern.len == 0 { return 0 }
	if pattern.len == 1 {
		space := stream.buffer.len - stream.position
		if splat < usize(space) { panic('reached unreachable code') }
		for i in 0 .. space {
			stream.buffer[stream.position + i] = pattern[0]
		}
		stream.position += space
		return error('WriteFailed')
	}
	mut remaining := splat
	for remaining > 0 {
		space := stream.buffer.len - stream.position
		len := if pattern.len < space { pattern.len } else { space }
		for i in 0 .. len {
			stream.buffer[stream.position + i] = pattern[i]
		}
		stream.position += len
		if pattern.len > space { return error('WriteFailed') }
		remaining--
	}
	panic('reached unreachable code')
}

pub fn (mut stream WriteStream) splat_byte(byte u8, count usize) !usize {
	return stream.write_splat([[byte]], count)
}

pub fn (mut stream WriteStream) splat_bytes(bytes []u8, count usize) !usize {
	return stream.write_splat([bytes], count)
}

// Restore each borrowed input header after retrying a partial vector write.
pub fn (mut stream WriteStream) write_vec_all(mut data [][]u8) ! {
	mut index := 0
	mut truncate := usize(0)
	for index < data.len {
		{
			untruncated := data[index]
			data[index] = unsafe { untruncated[int(truncate)..] }
			defer { data[index] = untruncated }
			n := stream.write_vec(data[index..])!
			if n > ~usize(0) - truncate { panic('integer overflow') }
			truncate += n
		}
		for index < data.len && truncate >= usize(data[index].len) {
			truncate -= usize(data[index].len)
			index++
		}
	}
}

pub fn (mut stream WriteStream) write_splat_all(mut data [][]u8, splat usize) ! {
	mut index := 0
	mut truncate := usize(0)
	for index + 1 < data.len {
		{
			untruncated := data[index]
			data[index] = unsafe { untruncated[int(truncate)..] }
			defer { data[index] = untruncated }
			n := stream.write_splat(data[index..], splat)!
			if n > ~usize(0) - truncate { panic('integer overflow') }
			truncate += n
		}
		for truncate >= usize(data[index].len) && index + 1 < data.len {
			truncate -= usize(data[index].len)
			index++
		}
	}
	if data.len == 0 { return }
	pattern := data[index]
	if pattern.len != 0 && splat > ~usize(0) / usize(pattern.len) { panic('integer overflow') }
	if truncate < usize(pattern.len) * splat {
		if index != data.len - 1 { panic('reached unreachable code') }
		mut remaining := splat
		for {
			used := truncate / usize(pattern.len)
			if used > remaining { panic('integer overflow') }
			remaining -= used
			truncate %= usize(pattern.len)
			if remaining == 0 { break
			 }
			n := stream.write_splat([unsafe { pattern[int(truncate)..] }, pattern], remaining - 1)!
			if n > ~usize(0) - truncate { panic('integer overflow') }
			truncate += n
		}
	}
}

pub fn (mut stream WriteStream) splat_byte_all(byte u8, count usize) ! {
	mut remaining := count
	for remaining > 0 {
		n := stream.splat_byte(byte, remaining)!
		if n > remaining { panic('integer overflow') }
		remaining -= n
	}
}

pub fn (mut stream WriteStream) splat_bytes_all(bytes []u8, splat usize) ! {
	if bytes.len != 0 && splat > ~usize(0) / usize(bytes.len) { panic('integer overflow') }
	mut remaining := usize(bytes.len) * splat
	first := stream.splat_bytes(bytes, splat)!
	if first > remaining { panic('integer overflow') }
	remaining -= first
	for remaining > 0 {
		leftover_splat := remaining / usize(bytes.len)
		leftover_bytes := remaining % usize(bytes.len)
		n := stream.write_splat([unsafe { bytes[bytes.len - int(leftover_bytes)..] }, bytes],
			leftover_splat)!
		if n > remaining { panic('integer overflow') }
		remaining -= n
	}
}

// Keep Source's buffered-tail compaction and short-write order.
pub fn (mut stream WriteStream) splat_byte_preserve(preserve usize, byte u8, count usize) ! {
	if count > ~usize(0) - usize(stream.position) { panic('integer overflow') }
	new_end := usize(stream.position) + count
	if new_end <= usize(stream.buffer.len) {
		for i in 0 .. int(count) {
			stream.buffer[stream.position + i] = byte
		}
		stream.position = int(new_end)
		return
	}
	mut remaining := count
	for remaining > preserve {
		if remaining == 0 { panic('reached unreachable code') }
		n := stream.splat_byte(byte, remaining - preserve)!
		if n > remaining { panic('integer overflow') }
		remaining -= n
		if remaining > ~usize(0) - usize(stream.position) { panic('integer overflow') }
		if usize(stream.position) + remaining <= usize(stream.buffer.len) {
			for i in 0 .. int(remaining) {
				stream.buffer[stream.position + i] = byte
			}
			stream.position += int(remaining)
			return
		}
	}
	if preserve < usize(stream.position) {
		for i in 0 .. int(preserve) {
			stream.buffer[i] = stream.buffer[stream.position - int(preserve) + i]
		}
		stream.position = int(preserve)
	}
	for remaining > 0 {
		n := stream.splat_byte(byte, remaining)!
		if n > remaining { panic('integer overflow') }
		remaining -= n
	}
}

pub enum Alignment {
	left
	center
	right
}

pub struct FormatOptions {
pub mut:
	precision ?usize
	width     ?usize
	alignment Alignment = .right
	fill      u8        = ` `
}

pub enum NumberMode {
	decimal
	binary
	octal
	hex
	scientific
}

pub fn (mode NumberMode) base() ?u8 {
	return match mode {
		.decimal { u8(10) }
		.binary { u8(2) }
		.octal { u8(8) }
		.hex { u8(16) }
		.scientific { none }
	}
}

pub struct NumberFormat {
pub mut:
	mode        NumberMode = .decimal
	letter_case FormatCase = .lower
	precision   ?usize
	width       ?usize
	alignment   Alignment = .right
	fill        u8        = ` `
}

pub fn (options FormatOptions) to_number(mode NumberMode, letter_case FormatCase) NumberFormat {
	return NumberFormat{
		mode:        mode
		letter_case: letter_case
		precision:   options.precision
		width:       options.width
		alignment:   options.alignment
		fill:        options.fill
	}
}

// Retain Source's separate payload and padding writes, including failure order.
pub fn (mut stream WriteStream) align_buffer(buffer []u8, width usize, alignment Alignment, fill u8) ! {
	padding := if usize(buffer.len) < width { width - usize(buffer.len) } else { usize(0) }
	if padding == 0 { return stream.write_all(buffer) }
	match alignment {
		.left {
			stream.write_all(buffer)!
			stream.splat_byte_all(fill, padding)!
		}
		.center {
			left := padding / 2
			if padding == ~usize(0) { panic('integer overflow') }
			right := (padding + 1) / 2
			stream.splat_byte_all(fill, left)!
			stream.write_all(buffer)!
			stream.splat_byte_all(fill, right)!
		}
		.right {
			stream.splat_byte_all(fill, padding)!
			stream.write_all(buffer)!
		}
	}
}

pub fn (mut stream WriteStream) align_buffer_options(buffer []u8, options FormatOptions) ! {
	width := options.width or { usize(buffer.len) }
	return stream.align_buffer(buffer, width, options.alignment, options.fill)
}

// Native-width integers retain Source's sign rules and complete-before-write order.
pub fn (mut stream WriteStream) print_int_any[T](value T, base u8, letter_case FormatCase, options FormatOptions) ! {
	$if T.unaliased_typ is $int {
		if base < 2 { panic('reached unreachable code') }
		mut magnitude := u64(0)
		mut sign := u8(0)
		$if T.unaliased_typ is i8 || T.unaliased_typ is i16 || T.unaliased_typ is int
			|| T.unaliased_typ is i64 || T.unaliased_typ is isize {
			n := i64(value)
			if n < 0 {
				magnitude = u64(-(n + 1)) + 1
				sign = `-`
			} else {
				magnitude = u64(n)
				if width := options.width {
					if width != 0 { sign = `+` }
				}
			}
		} $else {
			magnitude = u64(value)
		}
		mut bytes := [65]u8{}
		mut index := bytes.len
		alphabet := if letter_case == .upper {
			'0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ'
		} else {
			'0123456789abcdefghijklmnopqrstuvwxyz'
		}
		for {
			digit := magnitude % u64(base)
			if digit >= 36 { panic('reached unreachable code') }
			index--
			bytes[index] = alphabet[int(digit)]
			magnitude /= u64(base)
			if magnitude == 0 { break
			 }
		}
		if sign != 0 {
			index--
			bytes[index] = sign
		}
		return stream.align_buffer_options(bytes[index..], options)
	} $else {
		$compile_error('print_int_any requires a native integer type')
	}
}

// Source widens native integers before printing; their observable bytes agree.
pub fn (mut stream WriteStream) print_int[T](value T, base u8, letter_case FormatCase, options FormatOptions) ! {
	return stream.print_int_any[T](value, base, letter_case, options)
}

// Render completely in Source's f64-sized scratch buffer before parent output.
pub fn (mut stream WriteStream) print_float[T](value T, options NumberFormat) ! {
	mode := match options.mode {
		.decimal { FloatRenderMode.decimal }
		.scientific { FloatRenderMode.scientific }
		.binary, .octal, .hex { panic('reached unreachable code') }
	}

	mut storage := [347]u8{}
	mut bytes := unsafe { storage[..] }
	printed := render_float[T](mut bytes, value, FloatRenderOptions{
		mode:      mode
		precision: options.precision
	}) or { '(float)'.bytes() }
	return stream.align_buffer(printed, options.width or { usize(printed.len) }, options.alignment,
		options.fill)
}

fn io_address_integer(mut stream WriteStream, address usize) ! {
	mut value := address
	mut bytes := [16]u8{}
	mut index := bytes.len
	for {
		index--
		bytes[index] = '0123456789abcdef'[int(value & 15)]
		value >>= 4
		if value == 0 { break
		 }
	}
	return stream.write_all(bytes[index..])
}

fn io_address_type_name[T]() string {
	$if T is $option {
		$compile_error('print_address does not represent optional pointees')
	} $else $if T.unaliased_typ is voidptr {
		return '*anyopaque'
	} $else $if T.indirections > 0 || ((int(T.unaliased_typ) >> 16) & 0xff) > 0 {
		$compile_error('print_address does not represent nested pointees')
	} $else $if T.unaliased_typ is int {
		return 'i32'
	} $else $if T.unaliased_typ is u8 {
		return 'u8'
	} $else $if T.unaliased_typ is u16 {
		return 'u16'
	} $else $if T.unaliased_typ is u32 {
		return 'u32'
	} $else $if T.unaliased_typ is u64 {
		return 'u64'
	} $else $if T.unaliased_typ is usize {
		return 'usize'
	} $else $if T.unaliased_typ is i8 {
		return 'i8'
	} $else $if T.unaliased_typ is i16 {
		return 'i16'
	} $else $if T.unaliased_typ is i64 {
		return 'i64'
	} $else $if T.unaliased_typ is isize {
		return 'isize'
	} $else $if T.unaliased_typ is f32 {
		return 'f32'
	} $else $if T.unaliased_typ is f64 {
		return 'f64'
	} $else $if T.unaliased_typ is bool {
		return 'bool'
	} $else {
		$compile_error('print_address requires native scalar or pointer pointees')
	}
}

fn io_address_pointer[T](mut stream WriteStream, value &T) ! {
	$if T.unaliased_typ is $array_fixed {
		witness := T{}
		name := io_value_array_address_name(witness)!
		stream.write_all((name + '@').bytes())!
	} $else {
		stream.write_all((io_address_type_name[T]() + '@').bytes())!
	}
	return io_address_integer(mut stream, usize(voidptr(value)))
}

fn io_address_optional[T](mut stream WriteStream, value ?&T) ! {
	stream.write_all(('*' + io_address_type_name[T]() + '@').bytes())!
	address := unsafe { usize(voidptr(value or { nil })) }
	return io_address_integer(mut stream, address)
}

fn io_address_slice[T](mut stream WriteStream, value []T) ! {
	$if T is $option {
		witness := $zero(T)
		name := io_value_optional_address_name(witness)!
		stream.write_all((name + '@').bytes())!
	} $else $if T.unaliased_typ is $array_fixed || T.unaliased_typ is $array {
		witness := T{}
		name := io_value_array_address_name(witness)!
		stream.write_all((name + '@').bytes())!
	} $else $if T.indirections > 0 || ((int(T.unaliased_typ) >> 16) & 0xff) > 0 {
		witness := $zero(T)
		name := io_value_array_address_name(witness)!
		stream.write_all((name + '@').bytes())!
	} $else {
		stream.write_all((io_address_type_name[T]() + '@').bytes())!
	}
	return io_address_integer(mut stream, usize(value.data))
}

// Type prefix and hexadecimal address are separate Source writes; never dereference.
pub fn (mut stream WriteStream) print_address[P](value P) ! {
	$if P is $option {
		$if P.indirections != 1 && ((int(P.unaliased_typ) >> 16) & 0xff) != 1 {
			$compile_error('print_address requires a single optional pointer')
		}
		return io_address_optional(mut stream, value)
	} $else $if P.unaliased_typ is voidptr {
		stream.write_all('anyopaque@'.bytes())!
		return io_address_integer(mut stream, usize(value))
	} $else $if P.unaliased_typ is $array_fixed {
		$if P.indirections == 1 || ((int(P.unaliased_typ) >> 16) & 0xff) == 1 {
			return io_address_pointer(mut stream, value)
		} $else {
			$compile_error('print_address requires a pointer or slice')
		}
	} $else $if P.unaliased_typ is $array {
		return io_address_slice(mut stream, value)
	} $else $if P.indirections > 0 || ((int(P.unaliased_typ) >> 16) & 0xff) > 0 {
		$if P is $alias {
			mut normalized := $zero(P.unaliased_typ)
			unsafe { vmemcpy(&normalized, &value, int(sizeof(P))) }
			return stream.print_address(normalized)
		} $else {
			return io_address_pointer(mut stream, value)
		}
	} $else {
		$compile_error('print_address requires a pointer or slice')
	}
}

pub enum ByteSizeUnits {
	decimal
	binary
}

// Source chooses magnitudes from an integer logarithm, including its SI thresholds.
pub fn (mut stream WriteStream) print_byte_size(value u64, units ByteSizeUnits, options FormatOptions) ! {
	if value == 0 { return stream.align_buffer_options('0B'.bytes(), options) }
	mut reduced := value
	mut log2 := 0
	for reduced > 1 {
		reduced >>= 1
		log2++
	}
	magnitude := log2 / if units == .decimal { 9 } else { 10 }
	// Every reachable Source pow result is an exactly representable f64 integer.
	divisor := if units == .decimal {
		[f64(1), 1e3, 1e6, 1e9, 1e12, 1e15, 1e18, 1e21][magnitude]
	} else {
		f64(u64(1) << (10 * magnitude))
	}
	mut storage := [56]u8{}
	mut bytes := unsafe { storage[..] }
	mut index := 0
	if magnitude == 0 {
		mut integer := WriteStream.init_memory(mut bytes)
		integer.print_int[u64](value, 10, .lower, FormatOptions{}) or {
			panic('reached unreachable code')
		}
		index = integer.buffered().len
	} else {
		text := render_float[f64](mut bytes, f64(value) / divisor, FloatRenderOptions{
			mode:      .decimal
			precision: options.precision
		}) or { panic('attempt to unwrap error: ${err.msg()}') }
		index = text.len
	}
	suffix := if magnitude == 0 {
		'B'.bytes()
	} else if units == .decimal {
		['kB', 'MB', 'GB', 'TB', 'PB', 'EB', 'ZB'][magnitude - 1].bytes()
	} else {
		['KiB', 'MiB', 'GiB', 'TiB', 'PiB', 'EiB'][magnitude - 1].bytes()
	}
	if suffix.len > bytes.len - index {
		panic('index out of bounds: index ${index + suffix.len}, len ${bytes.len}')
	}
	for i, byte in suffix {
		bytes[index + i] = byte
	}
	return stream.align_buffer_options(bytes[..index + suffix.len], options)
}

// Hex floats retain Source's rounding and separate sign/fraction/exponent writes.
pub fn (mut stream WriteStream) print_float_hex[T](value T, letter_case FormatCase, precision ?usize) ! {
	$if T.unaliased_typ is f32 || T.unaliased_typ is f64 {
		mut raw := u64(0)
		mut fractional_bits := 52
		mut exponent_bits := 11
		$if T.unaliased_typ is f32 {
			raw = u64(unsafe { *(&u32(&value)) })
			fractional_bits = 23
			exponent_bits = 8
		} $else {
			raw = unsafe { *(&u64(&value)) }
		}
		if raw >> (fractional_bits + exponent_bits) != 0 { stream.write_byte(`-`)! }
		mut mantissa := raw & ((u64(1) << fractional_bits) - 1)
		exponent_mask := (1 << exponent_bits) - 1
		mut exponent := int((raw >> fractional_bits) & u64(exponent_mask))
		if exponent == exponent_mask {
			if mantissa != 0 {
				return stream.write_all(if letter_case == .upper {
					'NAN'.bytes()
				} else {
					'nan'.bytes()
				})
			}
			return stream.write_all(if letter_case == .upper { 'INF'.bytes() } else { 'inf'.bytes() })
		}
		if exponent == 0 && mantissa == 0 {
			stream.write_all('0x0'.bytes())!
			if digits := precision {
				if digits > 0 {
					stream.write_byte(`.`)!
					stream.splat_byte_all(`0`, digits)!
				}
			} else {
				stream.write_all('.0'.bytes())!
			}
			return stream.write_all('p0'.bytes())
		}
		if exponent == 0 {
			exponent++
		} else {
			mantissa |= u64(1) << fractional_bits
		}
		mantissa_digits := (fractional_bits + 3) / 4
		mantissa <<= mantissa_digits * 4 - fractional_bits
		if digits := precision {
			if digits < usize(mantissa_digits) {
				shift := (mantissa_digits - int(digits)) * 4
				mut extra_bits := shift
				for extra_bits > 2 {
					mantissa = (mantissa >> 1) | (mantissa & 1)
					extra_bits--
				}
				if mantissa & 4 != 0 { mantissa |= 1 }
				mantissa++
				mantissa = (mantissa >> 2) << shift
				if mantissa & (u64(1) << (1 + mantissa_digits * 4)) != 0 {
					mantissa >>= 1
					exponent++
				}
			}
		}
		alphabet := if letter_case == .upper { '0123456789ABCDEF' } else { '0123456789abcdef' }
		mut buffer := [14]u8{}
		for i in 0 .. mantissa_digits + 1 {
			buffer[mantissa_digits - i] = alphabet[int((mantissa >> (i * 4)) & 15)]
		}
		mut end := mantissa_digits + 1
		for end > 1 && buffer[end - 1] == `0` {
			end--
		}
		stream.write_all('0x'.bytes())!
		stream.write_byte(buffer[0])!
		if digits := precision {
			if digits > 0 { stream.write_byte(`.`)! }
		} else if end > 1 {
			stream.write_byte(`.`)!
		}
		stream.write_all(buffer[1..end])!
		if digits := precision {
			if digits > usize(end - 1) { stream.splat_byte_all(`0`, digits - usize(end - 1))! }
		}
		stream.write_byte(`p`)!
		return stream.print_int[int](exponent - ((1 << (exponent_bits - 1)) - 1), 10, letter_case, FormatOptions{})
	} $else {
		$compile_error('print_float_hex requires f32 or f64')
	}
}

// Source renders into fifty bytes before alignment; private failures are traps.
pub fn (mut stream WriteStream) print_float_hex_options[T](value T, options NumberFormat) ! {
	match options.mode {
		.decimal, .scientific { panic('reached unreachable code') }
		.binary, .octal { panic('TODO') }
		.hex {}
	}

	mut storage := [50]u8{}
	mut bytes := unsafe { storage[..] }
	mut inner := WriteStream.init_memory(mut bytes)
	inner.print_float_hex[T](value, options.letter_case, options.precision) or {
		panic('attempt to unwrap error: ${err.msg()}')
	}
	printed := inner.buffered()
	return stream.align_buffer(printed, options.width or { usize(printed.len) }, options.alignment,
		options.fill)
}

// Direct duration output retains separate sign, integer, fraction and unit writes.
pub fn (mut stream WriteStream) print_duration_signed(nanoseconds i64) ! {
	if nanoseconds < 0 {
		stream.write_byte(`-`)!
		return stream.print_duration_unsigned(u64(-(nanoseconds + 1)) + 1)
	}
	return stream.print_duration_unsigned(u64(nanoseconds))
}

pub fn (mut stream WriteStream) print_duration_unsigned(nanoseconds u64) ! {
	mut remaining := nanoseconds
	for i, unit in [u64(31536000000000000), 604800000000000, 86400000000000, 3600000000000,
		60000000000] {
		if remaining >= unit {
			count := remaining / unit
			stream.print_int[u64](count, 10, .lower, FormatOptions{})!
			stream.write_byte('ywdhm'[i])!
			remaining -= count * unit
			if remaining == 0 { return }
		}
	}
	for i, unit in [u64(1000000000), 1000000, 1000] {
		thousandths := remaining * 1000 / unit
		if thousandths >= 1000 {
			stream.print_int[u64](thousandths / 1000, 10, .lower, FormatOptions{})!
			fraction := thousandths % 1000
			if fraction > 0 {
				mut decimal := [u8(`.`), 0, 0, 0]!
				mut digits := unsafe { (&u8(&decimal[1])).vbytes(3) }
				mut inner := WriteStream.init_memory(mut digits)
				inner.print_int[u64](fraction, 10, .lower, FormatOptions{ width: usize(3), fill: `0` }) or {
					panic('reached unreachable code')
				}
				mut end := 4
				for end > 1 && decimal[end - 1] == `0` {
					end--
				}
				stream.write_all(decimal[..end])!
			}
			suffix := if i == 0 {
				's'
			} else if i == 1 {
				'ms'
			} else {
				'us'
			}
			return stream.write_all(suffix.bytes())
		}
	}
	stream.print_int[u64](remaining, 10, .lower, FormatOptions{})!
	return stream.write_all('ns'.bytes())
}

// The options variant renders fully before touching the destination writer.
pub fn (mut stream WriteStream) print_duration[T](nanoseconds T, options FormatOptions) ! {
	$if T.unaliased_typ is $int {
		mut storage := [24]u8{}
		mut bytes := unsafe { storage[..] }
		mut inner := WriteStream.init_memory(mut bytes)
		$if T.unaliased_typ is i8 || T.unaliased_typ is i16 || T.unaliased_typ is int
			|| T.unaliased_typ is i64 || T.unaliased_typ is isize {
			inner.print_duration_signed(i64(nanoseconds)) or {
				panic('attempt to unwrap error: ${err.msg()}')
			}
		} $else {
			inner.print_duration_unsigned(u64(nanoseconds)) or {
				panic('attempt to unwrap error: ${err.msg()}')
			}
		}
		return stream.align_buffer_options(inner.buffered(), options)
	} $else {
		$compile_error('print_duration requires a native integer type')
	}
}

// ASCII formatting accepts arbitrary bytes; precision is ignored by alignment.
pub fn (mut stream WriteStream) print_ascii_char(byte u8, options FormatOptions) ! {
	return stream.align_buffer_options([byte], options)
}

pub fn (mut stream WriteStream) print_ascii(bytes []u8, options FormatOptions) ! {
	return stream.align_buffer_options(bytes, options)
}

// u32 carries Source's u21 parameter. Check its range before any writer effects.
pub fn (mut stream WriteStream) print_unicode_codepoint(codepoint u32) ! {
	if codepoint > 0x1fffff { panic('integer does not fit in destination type') }
	c := if codepoint > 0x10ffff || (codepoint >= 0xd800 && codepoint <= 0xdfff) {
		u32(0xfffd)
	} else {
		codepoint
	}
	mut bytes := [4]u8{}
	mut len := 1
	if c < 0x80 {
		bytes[0] = u8(c)
	} else if c < 0x800 {
		len = 2
		bytes[0] = u8(0xc0 | (c >> 6))
		bytes[1] = u8(0x80 | (c & 0x3f))
	} else if c < 0x10000 {
		len = 3
		bytes[0] = u8(0xe0 | (c >> 12))
		bytes[1] = u8(0x80 | ((c >> 6) & 0x3f))
		bytes[2] = u8(0x80 | (c & 0x3f))
	} else {
		len = 4
		bytes[0] = u8(0xf0 | (c >> 18))
		bytes[1] = u8(0x80 | ((c >> 12) & 0x3f))
		bytes[2] = u8(0x80 | ((c >> 6) & 0x3f))
		bytes[3] = u8(0x80 | (c & 0x3f))
	}
	return stream.write_all(bytes[..len])
}

pub enum FormatCase {
	lower
	upper
}

// Keep each nibble as a separate byte write, including partial-write failures.
pub fn (mut stream WriteStream) print_hex(bytes []u8, letter_case FormatCase) ! {
	charset := if letter_case == .upper { '0123456789ABCDEF' } else { '0123456789abcdef' }
	for byte in bytes {
		stream.write_byte(charset[byte >> 4])!
		stream.write_byte(charset[byte & 15])!
	}
}

// Source encodes each three-byte window separately, then writes its four bytes.
pub fn (mut stream WriteStream) print_base64(bytes []u8) ! {
	charset := 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
	mut offset := 0
	for offset < bytes.len {
		count := if bytes.len - offset < 3 { bytes.len - offset } else { 3 }
		chunk := bytes[offset..offset + count]
		mut encoded := [4]u8{init: `=`}
		encoded[0] = charset[chunk[0] >> 2]
		encoded[1] = charset[(chunk[0] & 3) << 4 | if count > 1 { chunk[1] >> 4 } else { u8(0) }]
		if count > 1 {
			encoded[2] = charset[(chunk[1] & 15) << 2 | if count > 2 { chunk[2] >> 6 } else { u8(0) }]
		}
		if count > 2 { encoded[3] = charset[chunk[2] & 63] }
		stream.write_all(encoded[..])!
		offset += count
	}
}

// Swapped slices write each element separately, retaining partial-write order.
pub fn (mut stream WriteStream) write_slice_swap[T](values []T) ! {
	$if T.unaliased_typ is $int {
		for value in values {
			mut copy := value
			mut bytes := unsafe { (&u8(&copy)).vbytes(int(sizeof(T))) }
			for i in 0 .. bytes.len / 2 {
				bytes[i], bytes[bytes.len - 1 - i] = bytes[bytes.len - 1 - i], bytes[i]
			}
			stream.write_all(bytes)!
		}
	} $else {
		$compile_error('write_slice_swap requires a native integer type')
	}
}

pub fn (mut stream WriteStream) write_slice_endian[T, E](values []T, endian E) ! {
	$if T.unaliased_typ is $int {
		$if E.unaliased_typ is BigEndian || E.unaliased_typ is LittleEndian {
			mut swap := false
			$if E.unaliased_typ is BigEndian {
				$if little_endian { swap = true }
			} $else {
				$if big_endian { swap = true }
			}
			if swap { return stream.write_slice_swap[T](values) }
			if values.len > 0x7fffffff / int(sizeof(T)) {
				panic('Writer byte span exceeds V array length')
			}
			bytes := unsafe { values.data.vbytes(values.len * int(sizeof(T))) }
			stream.write_all(bytes)!
		} $else {
			$compile_error('write_slice_endian requires BigEndian or LittleEndian')
		}
	} $else {
		$compile_error('write_slice_endian requires a native integer type')
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

// Encode the complete representation before write_all, preserving its native
// buffering and partial-error behavior. Unsigned inputs may need a signed u65.
fn (mut stream WriteStream) write_leb128_unsigned(value u64, signed bool) ! {
	mut bytes := [10]u8{}
	mut count := 0
	mut remaining := value
	for {
		mut byte := u8(remaining & 0x7f)
		remaining >>= 7
		more := remaining != 0 || (signed && byte & 0x40 != 0)
		if more { byte |= 0x80 }
		bytes[count] = byte
		count++
		if !more { break
		 }
	}
	stream.write_all(bytes[..count])!
}

fn (mut stream WriteStream) write_leb128_signed(value i64) ! {
	mut bytes := [10]u8{}
	mut count := 0
	mut remaining := value
	for {
		mut byte := u8(u64(remaining) & 0x7f)
		remaining >>= 7
		more := !((remaining == 0 && byte & 0x40 == 0) || (remaining == -1 && byte & 0x40 != 0))
		if more { byte |= 0x80 }
		bytes[count] = byte
		count++
		if !more { break
		 }
	}
	stream.write_all(bytes[..count])!
}

pub fn (mut stream WriteStream) write_leb128[T](value T) ! {
	$if T.unaliased_typ is $int {
		$if T.unaliased_typ is i8 || T.unaliased_typ is i16 || T.unaliased_typ is int
			|| T.unaliased_typ is i64 || T.unaliased_typ is isize {
			stream.write_leb128_signed(i64(value))!
		} $else {
			stream.write_leb128_unsigned(u64(value), false)!
		}
	} $else {
		$compile_error('write_leb128 requires a native integer type')
	}
}

pub fn (mut stream WriteStream) write_uleb128[T](value T) ! {
	$if T.unaliased_typ is $int {
		$if T.unaliased_typ is i8 || T.unaliased_typ is i16 || T.unaliased_typ is int
			|| T.unaliased_typ is i64 || T.unaliased_typ is isize {
			if i64(value) < 0 { panic('integer does not fit in destination type') }
		}
		stream.write_leb128_unsigned(u64(value), false)!
	} $else {
		$compile_error('write_uleb128 requires a native integer type')
	}
}

pub fn (mut stream WriteStream) write_sleb128[T](value T) ! {
	$if T.unaliased_typ is $int {
		$if T.unaliased_typ is i8 || T.unaliased_typ is i16 || T.unaliased_typ is int
			|| T.unaliased_typ is i64 || T.unaliased_typ is isize {
			stream.write_leb128_signed(i64(value))!
		} $else {
			stream.write_leb128_unsigned(u64(value), true)!
		}
	} $else {
		$compile_error('write_sleb128 requires a native integer type')
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
