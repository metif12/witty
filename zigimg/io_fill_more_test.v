module zigimg

import os

#flag -I @VMODROOT/zigimg
#flag -I @VMODROOT/zigimg/reference_probes
#include "reference_probes/reader_exclusive/fixture_shims.h"

fn C.witty_reader_exclusive_payload(&char, &u8, uint) int
fn C.witty_reader_delimiter_replace(int) int
fn C.witty_reader_delimiter_seed(uint, uint) int
fn C.witty_reader_delimiter_cleanup() int
fn C.witty_reader_delimiter_drain(&u8, uint) int

fn test_memory_fill_more_reports_eof_without_consuming_pending_bytes() {
	for bytes in [[]u8{}, 'abc'.bytes()] {
		mut reader := ReadStream.init_memory(bytes)
		mut status := 'ok'
		reader.fill_more() or { status = err.msg() }
		assert status == 'EndOfStream' && reader.get_pos() == 0
		assert reader.buffered() == bytes
	}
}

fn test_fill_more_compacts_pending_bytes_and_preserves_eof_tails() {
	$if !windows {
		path := os.join_path(os.temp_dir(), 'witty-fill-more-file-${os.getpid()}.owned')
		os.write_file(path, 'abcdef')!
		defer { os.rm(path) or {} }
		mut file := os.open(path)!
		defer { file.close() }
		mut buffer := []u8{len: 4, init: 165}
		mut reader := ReadStream.init_file(file, mut buffer)
		reader.fill_more()!
		assert reader.get_pos() == 0 && reader.buffered() == 'abcd'.bytes()
		reader.toss(1)
		reader.fill_more()!
		assert reader.get_pos() == 1 && reader.buffered() == 'bcde'.bytes()
		reader.toss(1)
		reader.fill_more()!
		assert reader.get_pos() == 2 && reader.buffered() == 'cdef'.bytes()
		reader.toss(1)
		mut status := 'ok'
		reader.fill_more() or { status = err.msg() }
		assert status == 'EndOfStream' && reader.get_pos() == 3
		assert reader.buffered() == 'def'.bytes() && buffer == 'deff'.bytes()
	}
}

fn test_fill_more_mode_transition_returns_zero_progress_before_streaming_read() {
	$if !windows {
		path := os.join_path(os.temp_dir(), 'witty-fill-more-transition-${os.getpid()}.owned')
		data := []u8{len: 16, init: u8(index * 37 + 19)}
		fd := C.witty_reader_exclusive_payload(path.str, data.data, uint(data.len))
		assert fd >= 0
		defer { assert C.witty_reader_delimiter_cleanup() == 0 }
		mut buffer := []u8{len: 8, init: 165}
		mut reader := ReadStream.init_file(os.File{ fd: fd }, mut buffer)
		assert reader.get_end_pos()! == 16
		assert C.witty_reader_delimiter_replace(0) == 0
		assert C.witty_reader_delimiter_seed(0, 8) == 0
		reader.fill_more()!
		assert reader.get_pos() == 0 && reader.buffered().len == 0
		assert buffer == []u8{len: 8, init: 165}
		mut wire := []u8{len: 8}
		assert C.witty_reader_delimiter_drain(wire.data, uint(wire.len)) == 8
		assert wire == []u8{len: 8, init: u8(index * 31 + 7)}
		assert C.witty_reader_delimiter_seed(8, 8) == 0
		reader.fill_more()!
		assert reader.get_pos() == 0
			&& reader.buffered() == []u8{len: 8, init: u8((index + 8) * 31 + 7)}
		reader.toss_buffered()
		mut status := 'ok'
		reader.fill_more() or { status = err.msg() }
		assert status == 'ReadFailed' && reader.get_pos() == 8 && reader.buffered().len == 0
		assert C.witty_reader_delimiter_seed(16, 3) == 0
		reader.fill_more()!
		assert reader.get_pos() == 8
			&& reader.buffered() == []u8{len: 3, init: u8((index + 16) * 31 + 7)}
	}
}

fn test_fill_more_sticky_failure_retains_pending_and_consumed_cursors() {
	$if !windows {
		path := os.join_path(os.temp_dir(), 'witty-fill-more-sticky-${os.getpid()}.owned')
		data := []u8{len: 16, init: u8(index * 37 + 19)}
		fd := C.witty_reader_exclusive_payload(path.str, data.data, uint(data.len))
		assert fd >= 0
		defer { assert C.witty_reader_delimiter_cleanup() == 0 }
		mut buffer := []u8{len: 8, init: 165}
		mut reader := ReadStream.init_file(os.File{ fd: fd }, mut buffer)
		reader.peek(8)!
		reader.toss(1)
		assert C.witty_reader_delimiter_replace(0) == 0 && C.witty_reader_delimiter_seed(0, 7) == 0
		mut status := 'ok'
		reader.peek(8) or { status = err.msg() }
		assert status == 'ReadFailed' && reader.get_pos() == 0
		before := buffer.clone()
		status = 'ok'
		reader.fill_more() or { status = err.msg() }
		assert status == 'ReadFailed' && reader.get_pos() == 0 && buffer == before
		assert reader.buffered() == data[1..8]
		reader.toss_buffered()
		status = 'ok'
		reader.fill_more() or { status = err.msg() }
		assert status == 'ReadFailed' && reader.get_pos() == 7 && buffer == before
		reader.seek_by(-1)!
		assert reader.peek_byte()! == data[7] && reader.get_pos() == 6
	}
}
