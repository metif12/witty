module main

import os
import encoding.hex
import zigimg

#flag -I @DIR
#flag -I @DIR/..
#include "fixture_shims.h"

fn C.witty_reader_exclusive_payload(&char, &u8, uint) int
fn C.witty_reader_delimiter_replace(int) int
fn C.witty_reader_delimiter_seed(uint, uint) int
fn C.witty_reader_delimiter_shutdown() int
fn C.witty_reader_delimiter_cleanup() int
fn C.witty_reader_delimiter_valid() int
fn C.witty_reader_delimiter_refs() int
fn C.witty_reader_delimiter_drain(&u8, uint) int
fn C.witty_delimiter_stream_writer(&char) int
fn C.witty_delimiter_stream_fill() int
fn C.witty_writer_seek_replace(int) int
fn C.witty_writer_seek_cleanup() int
fn C.witty_writer_seek_valid() int
fn C.witty_writer_seek_refs() int
fn C.witty_writer_seek_view(&u8, uint) int
fn C.witty_writer_seek_drain(&u8, uint) int

__global (
	observed_path       string
	observed_status     string
	observed_reader     = &zigimg.ReadStream(unsafe { nil })
	observed_writer     = &zigimg.WriteStream(unsafe { nil })
	observed_input      []u8
	observed_output     []u8
	observed_count      = '-'
	observed_read_file  bool
	observed_write_file bool
)

// Observer queries avoid reader get_pos, whose checked subtraction can panic.
fn state(mut reader zigimg.ReadStream, writer zigimg.WriteStream, input []u8, output []u8) string {
	pending := reader.peek(reader.buffered_len()) or { panic(err) }
	mut size := ''
	length := reader.get_end_pos() or {
		size = err.msg()
		u64(0)
	}
	if size == '' { size = length.str() }
	mut actual := []u8{len: 4096}
	n := if observed_write_file {
		C.witty_writer_seek_view(actual.data, uint(actual.len))
	} else {
		int(0)
	}
	if n < 0 { panic('Writer view failed') }
	read_valid := if observed_read_file { C.witty_reader_delimiter_valid() } else { 0 }
	read_refs := if observed_read_file { C.witty_reader_delimiter_refs() } else { 0 }
	write_valid := if observed_write_file { C.witty_writer_seek_valid() } else { 0 }
	write_refs := if observed_write_file { C.witty_writer_seek_refs() } else { 0 }
	return '${size}:${read_valid}:${read_refs}|${input.hex()}|${pending.hex()}|${writer.get_pos()}:${write_valid}:${write_refs}|${output.hex()}|${writer.buffered().hex()}|${actual[..int(n)].hex()}|${observed_count}'
}

fn snapshot(mut reader zigimg.ReadStream, writer zigimg.WriteStream, input []u8, output []u8) string {
	return '${reader.get_pos()}:' + state(mut reader, writer, input, output)
}

fn observe() {
	if observed_path == '' { return }
	retained := observed_status + '|' +
		state(mut observed_reader, observed_writer, observed_input, observed_output)
	os.write_file(observed_path, retained) or { eprintln('OBSERVER ERROR: ${err}') }
	C.witty_reader_delimiter_cleanup()
	C.witty_writer_seek_cleanup()
}

fn read(mut reader zigimg.ReadStream, mut writer zigimg.WriteStream, api int, delimiter u8, limit uint) string {
	mut adapter := reader.reader()
	mut sink := writer.writer()
	count := match api {
		0 { adapter.stream_delimiter(mut sink, delimiter) or { return err.msg() } }
		1 { adapter.stream_delimiter_ending(mut sink, delimiter) or { return err.msg() } }
		else { adapter.stream_delimiter_limit(mut sink, delimiter, limit) or { return err.msg() } }
	}

	observed_count = count.str()
	return 'ok'
}

fn drain(writing bool, filled int) string {
	mut wire := []u8{}
	mut prefix := filled
	mut status := int(-3)
	for {
		mut bytes := []u8{len: 4096}
		status = if writing {
			C.witty_writer_seek_drain(bytes.data, uint(bytes.len))
		} else {
			C.witty_reader_delimiter_drain(bytes.data, uint(bytes.len))
		}
		if status <= 0 { break
		 }
		for byte in bytes[..int(status)] {
			if prefix > 0 {
				if byte != 211 { panic('Full pipe prefix differs') }
				prefix--
			} else {
				wire << byte
			}
		}
	}
	if prefix != 0 { panic('Full pipe prefix missing') }
	return '${status}:${wire.hex()}'
}

fn record(line string, path string) string {
	f := line.split('|')
	rkind, api, rcap, wkind, wcap, prefill, start, delimiter := f[0].int(), f[1].int(), f[2].int(), f[3].int(), f[4].int(), f[5].int(), f[6].int(), f[7].int()
	limit := uint(f[8].u64())
	data := hex.decode(f[9]) or { panic(err) }
	replace, consumed, seed, prime, delta := f[10].int(), f[11].int(), f[12].int(), f[13].int(), f[14].i64()
	mut input := []u8{len: rcap, init: 165}
	mut reader := zigimg.ReadStream.init_memory(data)
	if rkind == 0 {
		input = unsafe { data }
	} else {
		fd := C.witty_reader_exclusive_payload(path.str, data.data, uint(data.len))
		if fd < 0 { panic('Reader setup failed') }
		reader = if rkind == 1 { zigimg.ReadStream.init_file(os.File{ fd: fd }, mut input) } else { zigimg.ReadStream.init_file_streaming(os.File{
				fd: fd
			}, mut input) }
	}
	mut output := []u8{len: wcap, init: 90}
	mut writer := zigimg.WriteStream.init_memory(mut output)
	mut filled := int(0)
	if wkind > 0 {
		fd := C.witty_delimiter_stream_writer((path + '.writer').str)
		if fd < 0 { panic('Writer setup failed') }
		writer = if wkind in [2, 4, 6] { zigimg.WriteStream.init_file_streaming(os.File{ fd: fd }, mut output) } else { zigimg.WriteStream.init_file(os.File{
				fd: fd
			}, mut output) }
		if wkind >= 3 && C.witty_writer_seek_replace(1) != 0 { panic('Writer replacement failed') }
		if wkind >= 5 {
			filled = C.witty_delimiter_stream_fill()
			if filled <= 0 { panic('Writer fill failed') }
		}
	}
	defer {
		if rkind > 0 && C.witty_reader_delimiter_cleanup() != 0 { panic('Reader cleanup failed') }
		if wkind > 0 && C.witty_writer_seek_cleanup() != 0 { panic('Writer cleanup failed') }
	}
	writer.write_all([]u8{len: prefill, init: u8(225 + index)}) or { panic(err) }
	observed_reader = &reader
	observed_writer = &writer
	observed_input = unsafe { input }
	observed_output = unsafe { output }
	observed_count = '-'
	observed_status = 'ok'
	observed_read_file = rkind > 0
	observed_write_file = wkind > 0
	mut status := 'ok'
	if start > 0 { reader.seek_to(u64(start)) or { status = err.msg() } }
	if replace > 0 {
		reader.peek(rcap) or { panic(err) }
		reader.toss(uint(consumed))
	}
	mut out := '${status}|' + snapshot(mut reader, writer, input, output) + '~'
	if replace > 0 {
		if C.witty_reader_delimiter_replace(0) != 0
			|| C.witty_reader_delimiter_seed(0, uint(seed)) != 0 {
			panic('Reader replacement failed')
		}
		if replace == 2 && C.witty_reader_delimiter_shutdown() != 0 {
			panic('Reader shutdown failed')
		}
	}
	status = 'skip'
	if prime > 0 {
		status = 'ok'
		reader.peek(rcap) or { status = err.msg() }
		if prime == 2 { reader.toss(uint(reader.buffered_len())) }
	}
	out += '${status}|' + snapshot(mut reader, writer, input, output) + '~'
	for attempt in 0 .. 3 {
		observed_status = 'calling'
		status = read(mut reader, mut writer, api, u8(delimiter), limit)
		observed_status = status
		out += '${status}|' + snapshot(mut reader, writer, input, output) + '~'
		if attempt == 0 {
			status = 'ok'
			reader.seek_by(delta) or { status = err.msg() }
			out += '${status}|' + snapshot(mut reader, writer, input, output) + '~'
		}
		if attempt == 1 {
			status = 'ok'
			writer.flush() or { status = err.msg() }
			out += '${status}|' + snapshot(mut reader, writer, input, output) + '~'
		}
	}
	reader_wire := if replace > 0 { drain(false, 0) } else { 'skip' }
	writer_wire := if wkind > 0 { drain(true, filled) } else { 'skip' }
	return out + reader_wire + '/' + writer_wire
}

fn main() {
	if os.args[1] == '--trap' {
		observed_path = os.args[2]
		at_exit(observe) or { panic(err) }
		result := record(os.args[3], os.args[2] + '.owned')
		observed_path = ''
		println(result)
		return
	}
	for i, line in (os.read_lines(os.args[1]) or { panic(err) }) {
		println(record(line, os.args[1] + '.${i}.owned'))
	}
}
