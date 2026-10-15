module zigimg

import os

#flag -I @VMODROOT/zigimg
#flag -I @VMODROOT/zigimg/reference_probes
#include "reference_probes/reader_exclusive/fixture_shims.h"

fn C.witty_reader_exclusive_payload(&char, &u8, usize) int
fn C.witty_reader_delimiter_replace(int) int
fn C.witty_reader_delimiter_seed(usize, usize) int
fn C.witty_reader_delimiter_cleanup() int

fn test_memory_vectors_keep_slice_headers_and_partial_eof_writes() {
	mut first := []u8{len: 2, init: 165}
	mut last := []u8{len: 3, init: 165}
	mut destinations := [unsafe { first }, []u8{}, unsafe { last }]
	mut reader := ReadStream.init_memory('abcd'.bytes())
	assert reader.read_vec(mut destinations)! == 4
	assert first == 'ab'.bytes() && last == [u8(`c`), `d`, 165]
	assert destinations[0].data == first.data && destinations[0].len == 2
	assert destinations[2].data == last.data && destinations[2].len == 3
	mut status := 'ok'
	reader.read_vec_all(mut destinations) or { status = err.msg() }
	assert status == 'EndOfStream' && reader.get_pos() == 4
	assert destinations[0].len == 2 && destinations[2].len == 3
	mut all_reader := ReadStream.init_memory('wxyz'.bytes())
	status = 'ok'
	all_reader.read_vec_all(mut destinations) or { status = err.msg() }
	assert status == 'EndOfStream' && all_reader.get_pos() == 4
	assert first == 'wx'.bytes() && last == [u8(`y`), `z`, 165]
	assert destinations[0].data == first.data && destinations[0].len == 2
	assert destinations[2].data == last.data && destinations[2].len == 3
	mut empty := [][]u8{}
	reader.read_vec_all(mut empty)!
	assert reader.read_vec(mut empty)! == 0
}

fn test_file_vectors_scatter_and_reuse_streaming_read_ahead() {
	$if !windows {
		path := os.join_path(os.temp_dir(), 'witty-vectors-${os.getpid()}.owned')
		os.write_file(path, 'abcdefghijklmnop')!
		defer { os.rm(path) or {} }
		mut file := os.open(path)!
		defer { file.close() }
		mut buffer := []u8{len: 4, init: 165}
		mut reader := ReadStream.init_file_streaming(file, mut buffer)
		mut first := []u8{len: 1, init: 165}
		mut last := []u8{len: 2, init: 165}
		mut destinations := [[]u8{}, unsafe { first }, []u8{}, unsafe { last }]
		assert reader.read_vec(mut destinations)! == 3
		assert first == 'a'.bytes() && last == 'bc'.bytes()
		assert reader.get_pos() == 3 && reader.buffered() == 'defg'.bytes()
		mut adapter := reader.reader()
		adapter.read_vec_all(mut destinations)!
		assert first == 'd'.bytes() && last == 'ef'.bytes()
		assert reader.get_pos() == 6 && reader.buffered() == 'g'.bytes()
		assert destinations[1].data == first.data && destinations[1].len == 1
		assert destinations[3].data == last.data && destinations[3].len == 2
	}
}

fn test_read_vec_exposes_zero_progress_when_a_file_becomes_a_pipe() {
	$if !windows {
		path := os.join_path(os.temp_dir(), 'witty-vector-pipe-${os.getpid()}.owned')
		data := 'abcdefghi'.bytes()
		fd := C.witty_reader_exclusive_payload(path.str, data.data, usize(data.len))
		assert fd >= 0
		defer { assert C.witty_reader_delimiter_cleanup() == 0 }
		mut buffer := []u8{len: 4, init: 165}
		mut reader := ReadStream.init_file(os.File{ fd: fd }, mut buffer)
		assert reader.get_end_pos()! == 9
		assert C.witty_reader_delimiter_replace(0) == 0
		assert C.witty_reader_delimiter_seed(0, 3) == 0
		mut output := []u8{len: 3, init: 165}
		mut destinations := [unsafe { output }]
		assert reader.read_vec(mut destinations)! == 0
		assert output == []u8{len: 3, init: 165} && reader.get_pos() == 0
		assert reader.read_vec(mut destinations)! == 3
		assert output == [u8(7), 38, 69] && reader.get_pos() == 3
		assert destinations[0].data == output.data && destinations[0].len == 3
	}
}
