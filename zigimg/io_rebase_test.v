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

fn test_memory_rebase_keeps_the_original_buffer_and_cursor() {
	mut bytes := 'abcdef'.bytes()
	mut reader := ReadStream.init_memory(bytes)
	reader.toss(2)
	reader.rebase(4)!
	assert reader.get_pos() == 2 && reader.buffered() == 'cdef'.bytes()
	mut status := 'ok'
	reader.rebase(5) or { status = err.msg() }
	assert status == 'EndOfStream'
	assert reader.get_pos() == 2 && reader.buffered() == 'cdef'.bytes()
	assert bytes == 'abcdef'.bytes()
	reader.toss_buffered()
	reader.rebase(0)!
	status = 'ok'
	reader.rebase(1) or { status = err.msg() }
	assert status == 'EndOfStream' && reader.get_pos() == 6
}

fn test_file_rebase_compacts_only_when_required_and_keeps_read_ahead() {
	$if !windows {
		path := os.join_path(os.temp_dir(), 'witty-rebase-${os.getpid()}.owned')
		os.write_file(path, 'abcdefgh')!
		defer { os.rm(path) or {} }
		mut file := os.open(path)!
		defer { file.close() }
		mut buffer := []u8{len: 4, init: 165}
		mut reader := ReadStream.init_file(file, mut buffer)
		reader.rebase(4)!
		assert buffer == []u8{len: 4, init: 165} && reader.buffered_len() == 0
		assert reader.take(2)! == 'ab'.bytes()
		reader.rebase(2)!
		assert buffer == 'abcd'.bytes()
		mut adapter := reader.reader()
		adapter.rebase(3)!
		assert reader.get_pos() == 2 && reader.buffered() == 'cd'.bytes()
		assert buffer == 'cdcd'.bytes()
		assert reader.take(4)! == 'cdef'.bytes()
		assert reader.take(2)! == 'gh'.bytes()
		mut status := 'ok'
		reader.peek_byte() or { status = err.msg() }
		assert status == 'EndOfStream'
		reader.rebase(4)!
		assert reader.get_pos() == 8 && reader.buffered_len() == 0
	}
}

fn test_rebase_after_a_failed_streaming_transition_does_not_read_the_pipe() {
	$if !windows {
		path := os.join_path(os.temp_dir(), 'witty-rebase-pipe-${os.getpid()}.owned')
		data := []u8{len: 16, init: u8(index * 37 + 19)}
		fd := C.witty_reader_exclusive_payload(path.str, data.data, uint(data.len))
		assert fd >= 0
		defer { assert C.witty_reader_delimiter_cleanup() == 0 }
		mut buffer := []u8{len: 8, init: 165}
		mut reader := ReadStream.init_file(os.File{ fd: fd }, mut buffer)
		reader.peek(8)!
		reader.toss(1)
		assert C.witty_reader_delimiter_replace(0) == 0
		assert C.witty_reader_delimiter_seed(0, 7) == 0
		mut status := 'ok'
		reader.peek(8) or { status = err.msg() }
		assert status == 'ReadFailed' && reader.get_pos() == 0
		reader.toss(1)
		assert C.witty_reader_delimiter_seed(7, 3) == 0
		reader.rebase(8)!
		assert reader.get_pos() == 1 && reader.buffered() == data[2..8]
		assert buffer[..6] == data[2..8]
		mut wire := []u8{len: 8}
		assert C.witty_reader_delimiter_drain(wire.data, uint(wire.len)) == 3
		assert wire[..3] == []u8{len: 3, init: u8((index + 7) * 31 + 7)}
	}
}
