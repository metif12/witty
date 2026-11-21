module zigimg

import os

#flag -I @VMODROOT/zigimg
#include "reference_probes/stream_seek/fixture_shims.h"

fn C.witty_stream_seek_setup(&char) int
fn C.witty_stream_seek_replace(int) int
fn C.witty_stream_seek_seed(uint, uint) int
fn C.witty_stream_seek_shutdown() int
fn C.witty_stream_seek_cleanup() int
fn C.witty_stream_seek_drain(&u8, uint) int

fn seek_reader_success_case(target u64) ! {
	path := os.join_path(os.temp_dir(), 'witty-seek-${os.getpid()}.owned')
	fd := C.witty_stream_seek_setup(path.str)
	assert fd >= 0
	defer { assert C.witty_stream_seek_cleanup() == 0 }
	mut buffer := []u8{len: 8, init: 165}
	mut reader := ReadStream.init_file(os.File{ fd: fd }, mut buffer)
	reader.seek_to(0)!
	assert C.witty_stream_seek_replace(0) == 0
	assert C.witty_stream_seek_seed(0, 32) == 0
	assert reader.take_byte()! == 7
	assert reader.get_pos() == 1 && reader.buffered_len() == 7
	before := buffer.clone()
	reader.seek_to(target)!
	expected := u64(8) + target - 1
	assert reader.get_pos() == expected && reader.buffered_len() == 0
	assert buffer == before
	assert reader.take_byte()! == u8(expected * 31 + 7)
	assert reader.get_pos() == expected + 1 && reader.buffered_len() == 7
	mut queued := []u8{len: 64}
	n := C.witty_stream_seek_drain(queued.data, uint(queued.len))
	assert n == 32 - int(expected) - 8
	assert queued[..int(n)] == []u8{len: int(n), init: u8((index + int(expected) + 8) * 31 + 7)}
}

fn seek_reader_incomplete_case(closed bool) ! {
	path := os.join_path(os.temp_dir(), 'witty-seek-incomplete-${os.getpid()}.owned')
	fd := C.witty_stream_seek_setup(path.str)
	assert fd >= 0
	defer { assert C.witty_stream_seek_cleanup() == 0 }
	mut buffer := []u8{len: 8, init: 165}
	mut reader := ReadStream.init_file(os.File{ fd: fd }, mut buffer)
	reader.seek_to(0)!
	assert C.witty_stream_seek_replace(0) == 0
	assert C.witty_stream_seek_seed(0, 9) == 0
	if closed { assert C.witty_stream_seek_shutdown() == 0
	 }
	assert reader.take_byte()! == 7
	before := buffer.clone()
	mut status := 'ok'
	reader.seek_to(5) or { status = err.msg() }
	assert status == if closed {
		'EndOfStream'
	} else {
		'ReadFailed'
	}
	assert reader.get_pos() == 2 && reader.buffered_len() == 7 && buffer == before
	assert reader.get_end_pos()! == u64(if closed {
		9
	} else {
		2048
	})
	assert reader.take_byte()! == 38
	assert reader.get_pos() == 3 && reader.buffered_len() == 6
	if !closed { assert C.witty_stream_seek_seed(9, 4) == 0
	 }
	mut queued := []u8{len: 64}
	n := C.witty_stream_seek_drain(queued.data, uint(queued.len))
	assert n == if closed {
		0
	} else {
		4
	}
	if !closed { assert queued[..4] == [u8(30), 61, 92, 123]
	 }
}

fn test_absolute_streaming_seek_discards_input_and_clears_read_ahead() {
	$if !windows {
		for target in [u64(1), 5] {
			seek_reader_success_case(target)!
		}
		for closed in [false, true] {
			seek_reader_incomplete_case(closed)!
		}
	}
}
