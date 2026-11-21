module zigimg

import os

#flag -I @VMODROOT/zigimg
#include "reference_probes/reader_delimiter/fixture_shims.h"

fn C.witty_reader_delimiter_setup(&char) int
fn C.witty_reader_delimiter_replace(int) int
fn C.witty_reader_delimiter_seed(uint, uint) int
fn C.witty_reader_delimiter_shutdown() int
fn C.witty_reader_delimiter_cleanup() int
fn C.witty_reader_delimiter_drain(&u8, uint) int

fn delimiter_failed_cursor_case(closed bool) ! {
	path := os.join_path(os.temp_dir(), 'witty-delimiter-cursor-${os.getpid()}.owned')
	fd := C.witty_reader_delimiter_setup(path.str)
	assert fd >= 0
	defer { assert C.witty_reader_delimiter_cleanup() == 0 }
	mut buffer := []u8{len: 8, init: 165}
	mut reader := ReadStream.init_file(os.File{ fd: fd }, mut buffer)
	reader.seek_to(0)!
	reader.peek(8)!
	reader.toss(1)
	assert C.witty_reader_delimiter_replace(0) == 0
	assert C.witty_reader_delimiter_seed(0, 7) == 0
	if closed { assert C.witty_reader_delimiter_shutdown() == 0
	 }
	mut status := 'ok'
	reader.peek(8) or { status = err.msg() }
	assert status == 'ReadFailed'
	reader.toss(uint(reader.buffered_len()))
	assert reader.get_pos() == 7 && reader.buffered_len() == 0
	before := buffer.clone()
	status = 'ok'
	reader.peek_delimiter_inclusive(22) or { status = err.msg() }
	assert status == 'ReadFailed' && reader.get_pos() == 7
	assert buffer == before && reader.buffered_len() == 0
	reader.seek_by(-1)!
	assert reader.get_pos() == 6 && reader.buffered_len() == 1
	line := reader.peek_delimiter_inclusive(22)!
	assert line == [u8(22)] && reader.get_pos() == 6
	taken := reader.take_delimiter_inclusive(22)!
	assert taken == [u8(22)] && reader.get_pos() == 7 && reader.buffered_len() == 0
	if !closed { assert C.witty_reader_delimiter_seed(7, 8) == 0
	 }
	status = 'ok'
	reader.peek_delimiter_inclusive(224) or { status = err.msg() }
	assert status == 'ReadFailed' && reader.get_pos() == 7
	mut queued := []u8{len: 64}
	n := C.witty_reader_delimiter_drain(queued.data, uint(queued.len))
	assert n == if closed {
		0
	} else {
		8
	}
	if !closed { assert queued[..8] == []u8{len: 8, init: u8((index + 7) * 31 + 7)}
	 }
}

fn test_failed_delimiter_retains_consumed_buffer_for_relative_rewind() {
	$if !windows {
		for closed in [false, true] {
			delimiter_failed_cursor_case(closed)!
		}
	}
}

fn test_full_original_buffer_reports_stream_too_long_without_consuming_pipe_input() {
	$if !windows {
		path := os.join_path(os.temp_dir(), 'witty-delimiter-full-${os.getpid()}.owned')
		fd := C.witty_reader_delimiter_setup(path.str)
		assert fd >= 0
		defer { assert C.witty_reader_delimiter_cleanup() == 0 }
		mut buffer := []u8{len: 8, init: 165}
		mut reader := ReadStream.init_file(os.File{ fd: fd }, mut buffer)
		reader.seek_to(0)!
		reader.peek(8)!
		before := buffer.clone()
		assert C.witty_reader_delimiter_replace(0) == 0
		assert C.witty_reader_delimiter_seed(0, 32) == 0
		mut status := 'ok'
		reader.peek_delimiter_inclusive(0) or { status = err.msg() }
		assert status == 'StreamTooLong' && reader.get_pos() == 0
		assert reader.buffered_len() == 8 && buffer == before
		mut queued := []u8{len: 64}
		assert C.witty_reader_delimiter_drain(queued.data, uint(queued.len)) == 32
		assert queued[..32] == []u8{len: 32, init: u8(index * 31 + 7)}
	}
}

fn test_exclusive_delimiters_borrow_prefix_and_leave_delimiter_unread() {
	mut bytes := 'abc\ndef'.bytes()
	mut reader := ReadStream.init_memory(bytes)
	line := reader.peek_delimiter_exclusive(`\n`)!
	assert line == 'abc'.bytes() && reader.get_pos() == 0
	bytes[0] = `A`
	assert line == 'Abc'.bytes()
	taken := reader.take_delimiter_exclusive(`\n`)!
	assert taken == 'Abc'.bytes() && reader.get_pos() == 3
	empty := reader.take_delimiter_exclusive(`\n`)!
	assert empty.len == 0 && reader.get_pos() == 3
	marker := reader.take_byte()!
	assert marker == `\n`
	tail := reader.peek_delimiter_exclusive(`\n`)!
	assert tail == 'def'.bytes() && reader.get_pos() == 4
	last := reader.take_delimiter_exclusive(`\n`)!
	assert last == 'def'.bytes() && reader.get_pos() == 7
	mut status := 'ok'
	reader.take_delimiter_exclusive(`\n`) or { status = err.msg() }
	assert status == 'EndOfStream' && reader.get_pos() == 7
}

fn test_exclusive_file_delimiters_distinguish_eof_tail_and_full_capacity() {
	$if !windows {
		path := os.join_path(os.temp_dir(), 'witty-exclusive-eof-${os.getpid()}.owned')
		os.write_file(path, 'abc')!
		defer { os.rm(path) or {} }
		for capacity in [3, 8] {
			mut file := os.open(path)!
			defer { file.close() }
			mut buffer := []u8{len: capacity, init: 165}
			mut reader := ReadStream.init_file(file, mut buffer)
			mut status := 'ok'
			mut output := []u8{}
			line := reader.peek_delimiter_exclusive(`\n`) or {
				status = err.msg()
				[]u8{}
			}
			output = line.clone()
			assert reader.get_pos() == 0 && reader.buffered_len() == 3
			if capacity == 3 {
				assert status == 'StreamTooLong' && output.len == 0
			} else {
				assert status == 'ok' && output == 'abc'.bytes()
				taken := reader.take_delimiter_exclusive(`\n`)!
				assert taken == 'abc'.bytes() && reader.get_pos() == 3
				status = 'ok'
				reader.peek_delimiter_exclusive(`\n`) or { status = err.msg() }
				assert status == 'EndOfStream' && reader.get_pos() == 3
			}
		}
	}
}

fn test_nullable_delimiter_consumes_separators_and_returns_eof_tail_once() {
	mut data := '\nA\n\nlast'.bytes()
	mut reader := ReadStream.init_memory(data)
	mut adapter := reader.reader()
	first := reader.take_delimiter(`\n`)!
	empty := first.line or { panic('Expected a present empty line') }
	assert empty.len == 0 && reader.get_pos() == 1
	second := adapter.take_delimiter(`\n`)!
	line := second.line or { panic('Expected the first text line') }
	before := line.clone()
	assert line == 'A'.bytes() && reader.get_pos() == 3
	data[1] = `B`
	assert line == 'B'.bytes() && before == 'A'.bytes()
	third := reader.take_delimiter(`\n`)!
	another_empty := third.line or { panic('Expected a second present empty line') }
	assert another_empty.len == 0 && reader.get_pos() == 4
	fourth := adapter.take_delimiter(`\n`)!
	tail := fourth.line or { panic('Expected the final EOF tail') }
	assert tail == 'last'.bytes() && reader.get_pos() == 8
	for _ in 0 .. 2 {
		eof := adapter.take_delimiter(`\n`)!
		assert eof.line == none && reader.get_pos() == 8
	}
}

fn test_nullable_file_delimiter_distinguishes_capacity_failure_from_eof() {
	$if !windows {
		path := os.join_path(os.temp_dir(), 'witty-delimited-eof-${os.getpid()}.owned')
		os.write_file(path, 'abc')!
		defer { os.rm(path) or {} }
		for capacity in [3, 8] {
			mut file := os.open(path)!
			defer { file.close() }
			mut buffer := []u8{len: capacity, init: 165}
			mut reader := ReadStream.init_file(file, mut buffer)
			mut status := 'ok'
			result := reader.take_delimiter(`\n`) or {
				status = err.msg()
				DelimiterResult{}
			}
			if capacity == 3 {
				assert status == 'StreamTooLong' && result.line == none
				assert reader.get_pos() == 0 && reader.buffered_len() == 3
			} else {
				assert status == 'ok'
				line := result.line or { panic('Expected a file EOF tail') }
				assert line == 'abc'.bytes() && reader.get_pos() == 3
				buffer[0] = `A`
				assert line == 'Abc'.bytes()
				eof := reader.take_delimiter(`\n`)!
				assert eof.line == none && reader.get_pos() == 3
			}
		}
	}
}

fn test_delimiter_discards_count_and_consume_the_source_prefix() {
	mut reader := ReadStream.init_memory('abc\n\nlast'.bytes())
	prefix := reader.discard_delimiter_exclusive(`\n`)!
	assert prefix == 3 && reader.get_pos() == 3
	at_marker := reader.discard_delimiter_exclusive(`\n`)!
	assert at_marker == 0 && reader.get_pos() == 3
	first_marker := reader.discard_delimiter_inclusive(`\n`)!
	assert first_marker == 1 && reader.get_pos() == 4
	second_marker := reader.discard_delimiter_inclusive(`\n`)!
	assert second_marker == 1 && reader.get_pos() == 5
	mut status := 'ok'
	reader.discard_delimiter_inclusive(`\n`) or { status = err.msg() }
	assert status == 'EndOfStream' && reader.get_pos() == 9
	at_eof := reader.discard_delimiter_exclusive(`\n`)!
	assert at_eof == 0 && reader.get_pos() == 9
}

fn test_bounded_delimiter_discard_checks_limit_before_next_byte_or_eof() {
	mut reader := ReadStream.init_memory('abc\nlast'.bytes())
	mut status := 'ok'
	reader.discard_delimiter_limit(`\n`, 3) or { status = err.msg() }
	assert status == 'StreamTooLong' && reader.get_pos() == 3
	status = 'ok'
	reader.discard_delimiter_limit(`\n`, 0) or { status = err.msg() }
	assert status == 'StreamTooLong' && reader.get_pos() == 3
	at_marker := reader.discard_delimiter_limit(`\n`, 1)!
	assert at_marker == 0 && reader.get_pos() == 3
	marker := reader.take_byte()!
	assert marker == `\n`
	status = 'ok'
	reader.discard_delimiter_limit(`\n`, 4) or { status = err.msg() }
	assert status == 'StreamTooLong' && reader.get_pos() == 8
	after_eof := reader.discard_delimiter_limit(`\n`, 1)!
	assert after_eof == 0 && reader.get_pos() == 8
}

fn test_delimiter_discard_crosses_file_buffer_boundaries() {
	$if !windows {
		path := os.join_path(os.temp_dir(), 'witty-discard-delimiter-${os.getpid()}.owned')
		os.write_file(path, 'abcdefghijk\nlast')!
		defer { os.rm(path) or {} }
		for capacity in [1, 2, 8] {
			mut file := os.open(path)!
			defer { file.close() }
			mut buffer := []u8{len: capacity, init: 165}
			mut reader := ReadStream.init_file(file, mut buffer)
			count := reader.discard_delimiter_inclusive(`\n`)!
			assert count == 12 && reader.get_pos() == 12
			tail := reader.discard_delimiter_exclusive(`\n`)!
			assert tail == 4 && reader.get_pos() == 16
		}
	}
}

fn test_stream_delimiter_retains_marker_and_distinguishes_eof() {
	mut reader := ReadStream.init_memory('abc\nlast'.bytes())
	mut bytes := []u8{len: 32, init: 90}
	mut writer := WriteStream.init_memory(mut bytes)
	mut adapter := reader.reader()
	mut sink := writer.writer()
	assert adapter.stream_delimiter(mut sink, `\n`)! == 3
	assert reader.get_pos() == 3 && writer.buffered() == 'abc'.bytes()
	assert adapter.stream_delimiter_ending(mut sink, `\n`)! == 0
	assert reader.get_pos() == 3 && writer.get_pos() == 3
	assert reader.take_byte()! == `\n`
	mut status := 'ok'
	reader.stream_delimiter(mut writer, `\n`) or { status = err.msg() }
	assert status == 'EndOfStream' && reader.get_pos() == 8
	assert writer.buffered() == 'abclast'.bytes()
	assert reader.stream_delimiter_ending(mut writer, `\n`)! == 0
}

fn test_stream_delimiter_bound_precedes_eof_and_writer_failure() {
	mut reader := ReadStream.init_memory('abc\n'.bytes())
	mut bytes := []u8{len: 3, init: 90}
	mut writer := WriteStream.init_memory(mut bytes)
	mut status := 'ok'
	reader.stream_delimiter_limit(mut writer, `\n`, 0) or { status = err.msg() }
	assert status == 'StreamTooLong' && reader.get_pos() == 0 && writer.get_pos() == 0
	status = 'ok'
	reader.stream_delimiter_limit(mut writer, `\n`, 3) or { status = err.msg() }
	assert status == 'StreamTooLong' && reader.get_pos() == 3 && writer.buffered() == 'abc'.bytes()
	assert reader.stream_delimiter_limit(mut writer, `\n`, 1)! == 0
	assert reader.get_pos() == 3 && writer.get_pos() == 3
	mut tail := ReadStream.init_memory('xyz'.bytes())
	mut target := []u8{len: 8}
	mut output := WriteStream.init_memory(mut target)
	status = 'ok'
	tail.stream_delimiter_limit(mut output, `\n`, 3) or { status = err.msg() }
	assert status == 'StreamTooLong' && tail.get_pos() == 3
	assert tail.stream_delimiter_limit(mut output, `\n`, 1)! == 0
	assert output.buffered() == 'xyz'.bytes()
}

fn test_stream_delimiter_partial_memory_write_leaves_reader_span_unconsumed() {
	mut reader := ReadStream.init_memory('abcdef\n'.bytes())
	mut bytes := []u8{len: 3, init: 90}
	mut writer := WriteStream.init_memory(mut bytes)
	for _ in 0 .. 2 {
		mut status := 'ok'
		reader.stream_delimiter(mut writer, `\n`) or { status = err.msg() }
		assert status == 'WriteFailed' && reader.get_pos() == 0
		assert reader.peek(7)! == 'abcdef\n'.bytes()
		assert writer.buffered() == 'abc'.bytes() && writer.get_pos() == 3
	}
}

fn test_stream_delimiter_file_failure_consumes_only_completed_spans() {
	$if !windows {
		path := os.join_path(os.temp_dir(), 'witty-delimiter-stream-${os.getpid()}.owned')
		os.write_file(path, 'abcdef\n')!
		defer { os.rm(path) or {} }
		for capacity in [1, 8] {
			mut file := os.open(path)!
			defer { file.close() }
			mut buffer := []u8{len: capacity, init: 165}
			mut reader := ReadStream.init_file(file, mut buffer)
			mut bytes := []u8{len: 3, init: 90}
			mut writer := WriteStream.init_memory(mut bytes)
			mut status := 'ok'
			reader.stream_delimiter_ending(mut writer, `\n`) or { status = err.msg() }
			assert status == 'WriteFailed' && writer.buffered() == 'abc'.bytes()
			assert reader.get_pos() == if capacity == 1 {
				u64(3)
			} else {
				u64(0)
			}
			assert reader.peek(reader.buffered_len())! == if capacity == 1 {
				'd'.bytes()
			} else {
				'abcdef\n'.bytes()
			}
		}
	}
}
