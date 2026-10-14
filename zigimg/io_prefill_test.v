module zigimg

import os

#flag -I @VMODROOT/zigimg
#include "reference_probes/reader_prefill/fixture_shims.h"

fn C.witty_reader_prefill_setup(&char) int
fn C.witty_reader_prefill_replace(int) int
fn C.witty_reader_prefill_seed(usize, usize) int
fn C.witty_reader_prefill_cleanup() int
fn C.witty_reader_prefill_drain(&u8, usize) isize

fn test_prefilled_slice_read_combines_original_bytes_with_pipe_input() {
	$if !windows {
		path := os.join_path(os.temp_dir(), 'witty-prefill-slice-${os.getpid()}.owned')
		fd := C.witty_reader_prefill_setup(path.str)
		assert fd >= 0
		defer { assert C.witty_reader_prefill_cleanup() == 0 }
		mut buffer := []u8{len: 8, init: 165}
		mut reader := ReadStream.init_file(os.File{ fd: fd }, mut buffer)
		reader.seek_to(0)!
		reader.peek(8)!
		reader.toss(1)
		assert reader.get_pos() == 1 && reader.buffered_len() == 7
		assert C.witty_reader_prefill_replace(0) == 0
		assert C.witty_reader_prefill_seed(0, 32) == 0
		mut output := []u8{len: 8, init: 182}
		reader.read_slice_all(mut output)!
		assert output[..7] == []u8{len: 7, init: u8((index + 1) * 37 + 19)}
		assert output[7] == 255 && reader.get_pos() == 9
		assert reader.buffered_len() == 8
		assert buffer == []u8{len: 8, init: u8((index + 9) * 31 + 7)}
		// The pinned public seekBy workaround uses physical progress once it
		// leaves the buffered cursor range, and does not seek the live pipe.
		reader.seek_by(-1)!
		assert reader.get_pos() == 16 && reader.buffered_len() == 0
		next := reader.take_byte()!
		assert next == 22
		assert reader.get_pos() == 17
		mut queued := []u8{len: 64}
		assert C.witty_reader_prefill_drain(queued.data, usize(queued.len)) == 7
		assert queued[..7] == []u8{len: 7, init: u8((index + 25) * 31 + 7)}
	}
}

fn test_failed_prefilled_take_preserves_original_pending_bytes_and_sticky_failure() {
	$if !windows {
		path := os.join_path(os.temp_dir(), 'witty-prefill-failure-${os.getpid()}.owned')
		fd := C.witty_reader_prefill_setup(path.str)
		assert fd >= 0
		defer { assert C.witty_reader_prefill_cleanup() == 0 }
		mut buffer := []u8{len: 8, init: 165}
		mut reader := ReadStream.init_file(os.File{ fd: fd }, mut buffer)
		reader.seek_to(0)!
		reader.peek(8)!
		reader.toss(1)
		assert C.witty_reader_prefill_replace(0) == 0
		assert C.witty_reader_prefill_seed(0, 7) == 0
		mut status := 'ok'
		reader.take(8) or { status = err.msg() }
		assert status == 'ReadFailed' && reader.get_pos() == 0
		assert reader.buffered_len() == 7 && reader.get_end_pos()! == 2048
		assert reader.peek(7)! == []u8{len: 7, init: u8((index + 1) * 37 + 19)}
		assert C.witty_reader_prefill_seed(7, 7) == 0
		first := reader.take_byte()!
		assert first == 56
		assert reader.get_pos() == 1
		status = 'ok'
		reader.take(7) or { status = err.msg() }
		assert status == 'ReadFailed' && reader.get_pos() == 1
		assert reader.buffered_len() == 6
		mut queued := []u8{len: 64}
		assert C.witty_reader_prefill_drain(queued.data, usize(queued.len)) == 7
		assert queued[..7] == []u8{len: 7, init: u8((index + 7) * 31 + 7)}
	}
}

fn test_fully_consumed_original_buffer_retains_a_valid_failed_reader_position() {
	$if !windows {
		path := os.join_path(os.temp_dir(), 'witty-prefill-consumed-${os.getpid()}.owned')
		fd := C.witty_reader_prefill_setup(path.str)
		assert fd >= 0
		defer { assert C.witty_reader_prefill_cleanup() == 0 }
		mut buffer := []u8{len: 8, init: 165}
		mut reader := ReadStream.init_file(os.File{ fd: fd }, mut buffer)
		reader.seek_to(0)!
		reader.peek(8)!
		reader.toss(8)
		assert C.witty_reader_prefill_replace(0) == 0
		mut status := 'ok'
		reader.take(1) or { status = err.msg() }
		assert status == 'ReadFailed' && reader.get_pos() == 0 && reader.buffered_len() == 0
		assert reader.peek(0)! == []u8{}
		assert C.witty_reader_prefill_seed(0, 8) == 0
		status = 'ok'
		reader.take(1) or { status = err.msg() }
		assert status == 'ReadFailed' && reader.get_pos() == 0
		mut queued := []u8{len: 64}
		assert C.witty_reader_prefill_drain(queued.data, usize(queued.len)) == 8
		assert queued[..8] == []u8{len: 8, init: u8(index * 31 + 7)}
	}
}
