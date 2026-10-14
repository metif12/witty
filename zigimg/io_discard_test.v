module zigimg

import os

#flag -I @VMODROOT/zigimg
#include "reference_probes/stream_discard/fixture_shims.h"

fn C.witty_stream_discard_setup(&char) int
fn C.witty_stream_discard_replace(int) int
fn C.witty_stream_discard_restore(&char, usize) int
fn C.witty_stream_discard_seed(usize, usize) int
fn C.witty_stream_discard_shutdown() int
fn C.witty_stream_discard_close() int
fn C.witty_stream_discard_cleanup() int
fn C.witty_stream_discard_refs() int

fn test_discard_uses_cached_size_for_successful_physical_seek_after_replacement() {
	$if !windows {
		path := os.join_path(os.temp_dir(), 'witty-discard-regular-${os.getpid()}.owned')
		fd := C.witty_stream_discard_setup(path.str)
		assert fd >= 0
		defer { assert C.witty_stream_discard_cleanup() == 0 }
		mut buffer := []u8{}
		mut reader := ReadStream.init_file(os.File{ fd: fd }, mut buffer)
		reader.seek_to(0)!
		assert C.witty_stream_discard_replace(0) == 0
		assert C.witty_stream_discard_seed(0, 1) == 0
		mut byte := [u8(182)]
		reader.read_slice_all(mut byte)!
		assert byte == [u8(7)] && reader.get_pos() == 1
		restored := path + '.restored'
		assert C.witty_stream_discard_restore(restored.str, 0) == 0
		reader.discard_all(1)!
		assert reader.get_pos() == 2 && reader.get_end_pos()! == 2048
		mut status := 'ok'
		reader.read_slice_all(mut byte) or { status = err.msg() }
		assert status == 'EndOfStream' && reader.get_end_pos()! == 2
		assert byte == [u8(7)] && C.witty_stream_discard_refs() == 2
	}
}

fn test_discard_caches_failed_seek_before_owned_descriptor_invalidation() {
	$if !windows {
		path := os.join_path(os.temp_dir(), 'witty-discard-cache-${os.getpid()}.owned')
		fd := C.witty_stream_discard_setup(path.str)
		assert fd >= 0
		defer { assert C.witty_stream_discard_cleanup() == 0 }
		mut buffer := []u8{}
		mut reader := ReadStream.init_file(os.File{ fd: fd }, mut buffer)
		reader.seek_to(0)!
		assert C.witty_stream_discard_replace(0) == 0
		assert C.witty_stream_discard_seed(0, 64) == 0
		mut byte := [u8(182)]
		reader.read_slice_all(mut byte)!
		reader.discard_all(1)!
		assert C.witty_stream_discard_close() == 0
		mut status := 'ok'
		reader.seek_to(0) or { status = err.msg() }
		assert status == 'Unseekable' && reader.get_pos() == 2
		assert byte == [u8(7)] && C.witty_stream_discard_refs() == 2
	}
}

fn discard_partial_case(closed bool) ! {
	path := os.join_path(os.temp_dir(), 'witty-discard-partial-${os.getpid()}.owned')
	fd := C.witty_stream_discard_setup(path.str)
	assert fd >= 0
	defer { assert C.witty_stream_discard_cleanup() == 0 }
	mut buffer := []u8{len: 8, init: 165}
	mut reader := ReadStream.init_file(os.File{ fd: fd }, mut buffer)
	reader.seek_to(0)!
	assert C.witty_stream_discard_replace(0) == 0
	assert C.witty_stream_discard_seed(0, 9) == 0
	if closed { assert C.witty_stream_discard_shutdown() == 0
	 }
	assert reader.take_byte()! == 7
	before := buffer.clone()
	mut status := 'ok'
	reader.discard_all(9) or { status = err.msg() }
	assert status == if closed {
		'EndOfStream'
	} else {
		'ReadFailed'
	}
	assert reader.get_pos() == 9 && reader.buffered_len() == 0 && buffer == before
	assert reader.get_end_pos()! == u64(if closed {
		9
	} else {
		2048
	})
	status = 'ok'
	reader.seek_to(0) or { status = err.msg() }
	assert status == 'Unseekable'
	if !closed {
		assert C.witty_stream_discard_seed(9, 3) == 0
		assert reader.take_byte()! == 30
		assert reader.get_pos() == 10 && reader.buffered_len() == 2
	}
}

fn test_discard_consumes_buffered_prefix_and_retains_partial_failure_progress() {
	$if !windows {
		for closed in [false, true] {
			discard_partial_case(closed)!
		}
	}
}

fn test_nonregular_size_query_preserves_a_failed_reader_mode() {
	$if !windows {
		path := os.join_path(os.temp_dir(), 'witty-discard-failed-mode-${os.getpid()}.owned')
		fd := C.witty_stream_discard_setup(path.str)
		assert fd >= 0
		defer { assert C.witty_stream_discard_cleanup() == 0 }
		mut buffer := []u8{}
		mut reader := ReadStream.init_file(os.File{ fd: fd }, mut buffer)
		mut byte := [u8(182)]
		// Read positionally without querying size, then replace the descriptor.
		reader.read_slice_all(mut byte)!
		assert byte == [u8(7)]
		assert C.witty_stream_discard_replace(0) == 0
		mut status := 'ok'
		reader.read_slice_all(mut byte) or { status = err.msg() }
		assert status == 'ReadFailed' && reader.get_pos() == 0
		status = 'ok'
		reader.get_end_pos() or { status = err.msg() }
		assert status == 'Streaming'
		assert C.witty_stream_discard_seed(0, 4) == 0
		status = 'ok'
		reader.read_slice_all(mut byte) or { status = err.msg() }
		assert status == 'ReadFailed' && reader.get_pos() == 0 && byte == [u8(7)]
	}
}
