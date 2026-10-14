module zigimg

import os

#flag -I @VMODROOT/zigimg
#include "reference_probes/reader_delimiter/fixture_shims.h"

fn C.witty_reader_delimiter_setup(&char) int
fn C.witty_reader_delimiter_replace(int) int
fn C.witty_reader_delimiter_seed(usize, usize) int
fn C.witty_reader_delimiter_shutdown() int
fn C.witty_reader_delimiter_cleanup() int
fn C.witty_reader_delimiter_drain(&u8, usize) isize

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
	reader.toss(usize(reader.buffered_len()))
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
	n := C.witty_reader_delimiter_drain(queued.data, usize(queued.len))
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
		assert C.witty_reader_delimiter_drain(queued.data, usize(queued.len)) == 32
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
