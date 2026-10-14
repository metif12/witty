module zigimg

import os

#flag -I @VMODROOT/zigimg
#include "reference_probes/stream_transition/fixture_shims.h"

fn C.witty_stream_transition_setup(&char) int
fn C.witty_stream_transition_replace(int) int
fn C.witty_stream_transition_seed(usize, usize) int
fn C.witty_stream_transition_shutdown() int
fn C.witty_stream_transition_cleanup() int
fn C.witty_stream_transition_drain(&u8, usize) isize
fn C.witty_stream_transition_valid() int
fn C.witty_stream_transition_refs() int

fn transition_reader_case(buffered bool, incomplete bool, closed bool) ! {
	path := os.join_path(os.temp_dir(), 'witty-transition-${os.getpid()}.owned')
	fd := C.witty_stream_transition_setup(path.str)
	assert fd >= 0
	defer { assert C.witty_stream_transition_cleanup() == 0 }
	mut buffer := []u8{len: if buffered { 8 } else { 0 }, init: 165}
	mut reader := ReadStream.init_file(os.File{ fd: fd }, mut buffer)
	reader.seek_to(7)!
	assert C.witty_stream_transition_replace(0) == 0
	seed_count := if incomplete { 3 } else { 24 }
	assert C.witty_stream_transition_seed(0, usize(seed_count)) == 0
	if closed { assert C.witty_stream_transition_shutdown() == 0
	 }
	mut output := []u8{len: 1, init: 182}
	for attempt in 0 .. 2 {
		mut status := 'ok'
		if buffered {
			value := reader.take(1) or {
				status = err.msg()
				[]u8{}
			}
			if status == 'ok' { output[0] = value[0] }
		} else {
			reader.read_slice_all(mut output) or { status = err.msg() }
		}
		if incomplete {
			assert status == 'ReadFailed' && output == [u8(182)]
			assert reader.get_pos() == 3 && reader.buffered_len() == 0
			assert reader.get_end_pos()! == u64(if closed {
				3
			} else {
				2048
			})
			assert buffer == []u8{len: buffer.len, init: 165}
			if attempt == 0 && !closed { assert C.witty_stream_transition_seed(3, 16) == 0
			 }
		} else {
			assert status == 'ok' && output[0] == u8((7 + attempt) * 31 + 7)
			assert reader.get_pos() == u64(8 + attempt)
			assert reader.buffered_len() == if buffered {
				7 - attempt
			} else {
				0
			}
		}
		assert C.witty_stream_transition_valid() == 1
		assert C.witty_stream_transition_refs() == if closed {
			2
		} else {
			3
		}
	}
	mut queued := []u8{len: 64}
	n := C.witty_stream_transition_drain(queued.data, usize(queued.len))
	if incomplete {
		assert n == if closed {
			0
		} else {
			16
		}
		if !closed { assert queued[..16] == []u8{len: 16, init: u8((index + 3) * 31 + 7)}
		 }
	} else {
		start := if buffered { 15 } else { 9 }
		assert n == 24 - start
		assert queued[..int(n)] == []u8{len: 24 - start, init: u8((index + start) * 31 + 7)}
	}
}

fn test_positional_readers_reconcile_forward_offsets_on_owned_pipe_replacement() {
	$if !windows {
		for buffered in [false, true] {
			transition_reader_case(buffered, false, false)!
			for closed in [false, true] {
				transition_reader_case(buffered, true, closed)!
			}
		}
	}
}

fn test_stream_refills_entire_buffer_after_consuming_short_input() {
	$if !windows {
		path := os.join_path(os.temp_dir(), 'witty-transition-refill-${os.getpid()}.owned')
		fd := C.witty_stream_transition_setup(path.str)
		assert fd >= 0
		defer { assert C.witty_stream_transition_cleanup() == 0 }
		mut buffer := []u8{len: 8, init: 165}
		mut reader := ReadStream.init_file(os.File{ fd: fd }, mut buffer)
		reader.seek_to(0)!
		assert C.witty_stream_transition_replace(0) == 0
		assert C.witty_stream_transition_seed(0, 1) == 0
		assert reader.take_byte()! == 7
		assert C.witty_stream_transition_seed(1, 13) == 0
		assert reader.take_byte()! == 38
		assert reader.get_pos() == 2 && reader.buffered_len() == 7
		assert buffer == [u8(38), 69, 100, 131, 162, 193, 224, 255]
		mut queued := []u8{len: 64}
		assert C.witty_stream_transition_drain(queued.data, usize(queued.len)) == 5
		assert queued[..5] == [u8(30), 61, 92, 123, 154]
	}
}
