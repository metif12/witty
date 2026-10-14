module zigimg

import os

#flag -I @VMODROOT/zigimg/reference_probes/streams
#include "fixture_shims.h"

fn C.witty_stream_probe_pipe(&int) int
fn C.witty_stream_probe_close(int) int
fn C.witty_stream_probe_read(int, &u8, usize) isize

fn test_file_reader_preserves_positional_start_read_ahead_and_seek_by_workaround() {
	path := os.join_path(os.temp_dir(), 'witty-zigimg-reader-${os.getpid()}')
	os.write_file(path, '0123456789abcdefghijklmnop')!
	defer { os.rm(path) or {} }
	mut file := os.open(path)!
	defer { file.close() }
	file.seek(7, .start)!
	mut buffer := []u8{len: 8}
	mut reader := ReadStream.init_file(file, mut buffer)
	assert reader.get_pos() == 0
	assert reader.get_end_pos()! == 26
	assert reader.take(5)!.bytestr() == '01234'
	assert reader.file_pos == 8 && reader.get_pos() == 5
	assert file.tell()! == 7
	reader.seek_by(4)!
	assert reader.get_pos() == 12 // source uses physical pos, not logical pos
	assert reader.take(2)!.bytestr() == 'cd'
	reader.seek_to(0)!
	mut destination := []u8{len: 3}
	assert reader.read_slice_short(mut destination)! == 3
	assert destination.bytestr() == '012'
	$if macos || ios || haiku || serenity {
		// Source preadv reads only the destination vector on these targets.
		assert reader.file_pos == 3 && reader.end == 0
	} $else $if !windows {
		assert reader.file_pos == 11 && reader.end == 8
	}
	reader.seek_to(25)!
	mut short := []u8{len: 3, init: 0xa5}
	reader.read_slice_all(mut short) or { assert err.msg() == 'EndOfStream' }
	assert short == [u8(`p`), 0xa5, 0xa5]
	assert reader.get_pos() == 26
	reader.seek_to(26) or { assert err.msg() == 'Unseekable' }
}

fn test_file_writer_buffering_flush_seeks_and_image_api() {
	path := os.join_path(os.temp_dir(), 'witty-zigimg-writer-${os.getpid()}')
	defer { os.rm(path) or {} }
	mut file := os.create(path)!
	defer { file.close() }
	mut buffer := []u8{len: 4}
	mut writer := WriteStream.init_file(file, mut buffer)
	writer.write_all('abc'.bytes())!
	assert writer.get_pos() == 3
	assert os.file_size(path) == 0
	writer.write_all('defgh'.bytes())!
	assert writer.get_pos() == 8
	writer.seek_to(2)!
	writer.write_all('XY'.bytes())!
	writer.flush()!
	assert os.read_file(path)! == 'abXYefgh'
	image := Image.from_raw_pixels(2, 1, [u8(1), 2, 3, 4, 5, 6], .rgb24)!
	image.write_to_file_path(path, mut buffer, QoiEncoderOptions{})!
	mut read_buffer := []u8{len: 256}
	decoded := Image.from_file_path(path, mut read_buffer)!
	assert decoded.raw_bytes() == image.raw_bytes()
	assert Image.detect_format_from_file_path(path, mut read_buffer)! == .qoi
}

fn test_file_reader_updates_cached_size_when_buffer_fill_observes_eof() {
	path := os.join_path(os.temp_dir(), 'witty-zigimg-eof-size-${os.getpid()}')
	os.write_file(path, '01234567')!
	defer { os.rm(path) or {} }
	mut file := os.open(path)!
	defer { file.close() }
	mut buffer := []u8{len: 8}
	mut stream := ReadStream.init_file(file, mut buffer)
	assert stream.get_end_pos()! == 8
	// Replacing the contents keeps the open descriptor and cached size alive.
	os.write_file(path, '012')!
	assert stream.take(3)!.bytestr() == '012'
	stream.take_byte() or { assert err.msg() == 'EndOfStream' }
	assert stream.get_pos() == 3
	assert stream.get_end_pos()! == 3
	stream.seek_to(3) or { assert err.msg() == 'Unseekable' }
}

fn test_stream_adapters_borrow_live_memory_buffers_and_positions() {
	mut stream := ReadStream.init_memory('abc'.bytes())
	mut reader := stream.reader()
	assert voidptr(reader) == voidptr(&stream)
	assert reader.take_byte()! == `a`
	assert stream.get_pos() == 1
	stream.seek_by(1)!
	assert reader.take_byte()! == `c`
	reader.seek_to(0)!
	assert stream.get_pos() == 0
	mut bytes := []u8{len: 4}
	mut output := WriteStream.init_memory(mut bytes)
	mut writer := output.writer()
	assert voidptr(writer) == voidptr(&output)
	writer.write_all('ab'.bytes())!
	assert output.get_pos() == 2
	output.seek_to(1)!
	writer.write_byte(`X`)!
	writer.flush()!
	assert output.buffered().bytestr() == 'aX'
	assert bytes == [u8(`a`), `X`, 0, 0]
}

fn test_memory_reader_large_request_returns_source_eof_without_int_overflow() {
	mut stream := ReadStream.init_memory('abc'.bytes())
	assert stream.take_byte()! == `a`
	stream.peek(0x7fffffff) or { assert err.msg() == 'EndOfStream' }
	assert stream.get_pos() == 1
	stream.seek_by(i64(-0x7fffffffffffffff) - 1) or { assert err.msg() == 'Unseekable' }
	assert stream.get_pos() == 1
}

type StreamIntAlias = i16
type StreamEndianAlias = LittleEndian

fn test_stream_integer_adapters_preserve_signed_bits_and_native_aliases() {
	mut bytes := []u8{len: 10}
	mut output := WriteStream.init_memory(mut bytes)
	mut writer := output.writer()
	writer.write_int[StreamIntAlias, StreamEndianAlias](StreamIntAlias(-2), StreamEndianAlias{})!
	output.write_int[u64, BigEndian](0xfedcba9876543210, BigEndian{})!
	assert output.buffered() == [u8(0xfe), 0xff, 0xfe, 0xdc, 0xba, 0x98, 0x76, 0x54, 0x32, 0x10]
	mut input := ReadStream.init_memory(output.buffered())
	mut reader := input.reader()
	assert reader.take_int[StreamIntAlias, StreamEndianAlias](StreamEndianAlias{})! == StreamIntAlias(-2)
	assert input.take_int[u64, BigEndian](BigEndian{})! == u64(0xfedcba9876543210)
	input.take_int[u8, BigEndian](BigEndian{}) or { assert err.msg() == 'EndOfStream' }
	assert input.get_pos() == 10
}

fn test_file_writer_single_byte_retains_source_pending_buffer_on_darwin() {
	$if macos {
		path := os.join_path(os.temp_dir(), 'witty-zigimg-vector-write-${os.getpid()}')
		defer { os.rm(path) or {} }
		mut file := os.create(path)!
		defer { file.close() }
		mut buffer := []u8{len: 1}
		mut stream := WriteStream.init_file(file, mut buffer)
		assert stream.write([u8(0xa7)])! == 1
		stream.write_byte(0xff)!
		assert stream.get_pos() == 2
		assert stream.buffered() == [u8(0xff)]
		assert os.read_bytes(path)! == [u8(0xa7)]
		stream.flush()!
		assert os.read_bytes(path)! == [u8(0xa7), 0xff]
	}
}

fn test_pipe_writer_preserves_zero_progress_transition_and_seek_errors() {
	$if !windows {
		mut fds := [2]int{}
		assert C.witty_stream_probe_pipe(&fds[0]) == 0
		defer {
			C.witty_stream_probe_close(fds[0])
			C.witty_stream_probe_close(fds[1])
		}
		mut buffer := []u8{}
		mut stream := WriteStream.init_file(os.File{ fd: fds[1] }, mut buffer)
		assert stream.write('abc'.bytes())! == 0
		assert stream.get_pos() == 0
		mut bytes := []u8{len: 3}
		assert C.witty_stream_probe_read(fds[0], bytes.data, 3) < 0
		assert stream.write('abc'.bytes())! == 3
		assert stream.get_pos() == 3
		assert C.witty_stream_probe_read(fds[0], bytes.data, 3) == 3
		assert bytes.bytestr() == 'abc'
		stream.seek_to(0) or { assert err.msg() == 'Unseekable' }
		stream.seek_to(2) or { assert err.msg() == 'Unseekable' }
		stream.write_byte(`d`)!
		assert stream.get_pos() == 4
	}
}

fn test_pipe_writer_flush_retries_mode_transition_with_pending_bytes() {
	$if !windows {
		mut fds := [2]int{}
		assert C.witty_stream_probe_pipe(&fds[0]) == 0
		defer {
			C.witty_stream_probe_close(fds[0])
			C.witty_stream_probe_close(fds[1])
		}
		mut buffer := []u8{len: 4}
		mut stream := WriteStream.init_file(os.File{ fd: fds[1] }, mut buffer)
		stream.write_all('abc'.bytes())!
		assert stream.get_pos() == 3 && stream.buffered().bytestr() == 'abc'
		stream.flush()!
		assert stream.get_pos() == 3 && stream.buffered().len == 0
		mut bytes := []u8{len: 3}
		assert C.witty_stream_probe_read(fds[0], bytes.data, 3) == 3
		assert bytes.bytestr() == 'abc'
	}
}

fn test_streaming_adapters_exchange_pipe_bytes_without_positional_transition() {
	$if !windows {
		mut fds := [2]int{}
		assert C.witty_stream_probe_pipe(&fds[0]) == 0
		mut output_closed := false
		defer {
			C.witty_stream_probe_close(fds[0])
			if !output_closed { C.witty_stream_probe_close(fds[1]) }
		}
		mut output_buffer := []u8{len: 2}
		mut output := WriteStream.init_file_streaming(os.File{ fd: fds[1] }, mut output_buffer)
		assert output.write('abc'.bytes())! == 3
		output.flush()!
		assert output.get_pos() == 3
		assert C.witty_stream_probe_close(fds[1]) == 0
		output_closed = true
		mut input_buffer := []u8{len: 8}
		mut input := ReadStream.init_file_streaming(os.File{ fd: fds[0] }, mut input_buffer)
		mut missing_size := false
		input.get_end_pos() or {
			missing_size = true
			assert err.msg() == 'Streaming'
		}
		assert missing_size
		assert input.peek(1)!.bytestr() == 'a'
		assert input.buffered_len() == 3
		assert input.take(3)!.bytestr() == 'abc'
		assert input.buffered_len() == 0
		mut reached_end := false
		input.take_byte() or {
			reached_end = true
			assert err.msg() == 'EndOfStream'
		}
		assert reached_end && input.get_end_pos()! == 3
		mut unseekable := false
		input.seek_to(0) or {
			unseekable = true
			assert err.msg() == 'Unseekable'
		}
		assert unseekable && input.get_pos() == 3
	}
}

fn test_file_writer_position_accepts_last_representable_pending_byte() {
	path := os.join_path(os.temp_dir(), 'witty-zigimg-write-position-${os.getpid()}')
	defer { os.rm(path) or {} }
	mut file := os.create(path)!
	defer { file.close() }
	mut buffer := []u8{len: 2}
	mut stream := WriteStream.init_file(file, mut buffer)
	stream.seek_to(u64(0xfffffffffffffffe))!
	stream.write_byte(1)!
	assert stream.get_pos() == u64(0xffffffffffffffff)
	assert stream.buffered() == [u8(1)]
}

fn test_file_reader_rebases_before_refilling_without_consuming_peeked_bytes() {
	path := os.join_path(os.temp_dir(), 'witty-reader-rebase-${os.getpid()}')
	os.write_file(path, '012')!
	defer { os.rm(path) or {} }
	mut file := os.open(path)!
	defer { file.close() }
	mut buffer := []u8{len: 2, init: u8(165)}
	mut stream := ReadStream.init_file(file, mut buffer)
	assert stream.take_byte()! == `0`
	assert stream.peek(2)!.bytestr() == '12'
	assert stream.get_pos() == 1 && stream.buffered_len() == 2
	assert buffer.bytestr() == '12'
	assert stream.take(2)!.bytestr() == '12'
	stream.peek(1) or {
		assert err.msg() == 'EndOfStream'
		assert stream.get_pos() == 3 && stream.buffered_len() == 0
		assert buffer.bytestr() == '12'
		return
	}
	assert false
}

fn test_file_delimiter_eof_preserves_consumed_bytes_when_tail_has_room() {
	path := os.join_path(os.temp_dir(), 'witty-delimiter-eof-${os.getpid()}.bin')
	os.write_file(path, 'a\nb')!
	defer { os.rm(path) or {} }
	mut file := os.open(path)!
	defer { file.close() }
	file.seek(3, .start)!
	mut buffer := []u8{len: 8, init: 165}
	mut stream := ReadStream.init_file(file, mut buffer)
	assert stream.take_delimiter_inclusive(`\n`)!.bytestr() == 'a\n'
	for _ in 0 .. 2 {
		stream.take_delimiter_inclusive(`\n`) or {
			assert err.msg() == 'EndOfStream'
			assert stream.get_pos() == 2 && stream.buffered_len() == 1
			assert buffer == [u8(`a`), `\n`, `b`, 165, 165, 165, 165, 165]
			continue
		}
		assert false
	}
}
