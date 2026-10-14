module main

import os
import encoding.hex
import zigimg

#flag -I @DIR
#flag -I @DIR/..
#include "fixture_shims.h"

fn C.witty_reader_exclusive_payload(&char, &u8, usize) int
fn C.witty_reader_delimiter_setup(&char) int
fn C.witty_reader_delimiter_replace(int) int
fn C.witty_reader_delimiter_seed(usize, usize) int
fn C.witty_reader_delimiter_shutdown() int
fn C.witty_reader_delimiter_cleanup() int
fn C.witty_reader_delimiter_valid() int
fn C.witty_reader_delimiter_refs() int
fn C.witty_reader_delimiter_drain(&u8, usize) isize

__global (
	observed_path   string
	observed_status string
	observed_reader = &zigimg.ReadStream(unsafe { nil })
	observed_buffer []u8
	observed_output []u8
)

// The panic observer omits get_pos: that public query is the checked operation.
fn state(mut reader zigimg.ReadStream, buffer []u8, output []u8) string {
	pending := reader.peek(reader.buffered_len()) or { panic(err) }
	size := reader.get_end_pos() or {
		return '${err.msg()}:${C.witty_reader_delimiter_valid()}:${C.witty_reader_delimiter_refs()}|${buffer.hex()}|${output.hex()}|${pending.hex()}'
	}
	return '${size}:${C.witty_reader_delimiter_valid()}:${C.witty_reader_delimiter_refs()}|${buffer.hex()}|${output.hex()}|${pending.hex()}'
}

fn snapshot(mut reader zigimg.ReadStream, buffer []u8, output []u8) string {
	position := reader.get_pos()
	return '${position}:' + state(mut reader, buffer, output)
}

fn observe() {
	if observed_path == '' { return }
	retained := observed_status + '|' + state(mut observed_reader, observed_buffer, observed_output)
	os.write_file(observed_path, retained) or { eprintln('OBSERVER ERROR: ${err}') }
	C.witty_reader_delimiter_cleanup()
}

fn read(mut reader zigimg.ReadStream, mut output []u8, api int, delimiter u8, limit usize) string {
	count := match api {
		0 { reader.discard_delimiter_exclusive(delimiter) or { return err.msg() } }
		1 { reader.discard_delimiter_inclusive(delimiter) or { return err.msg() } }
		else { reader.discard_delimiter_limit(delimiter, limit) or { return err.msg() } }
	}

	output = []u8{len: 8, init: u8(u64(count) >> (index * 8))}
	return 'ok'
}

fn record(line string, path string) string {
	f := line.split('|')
	fd := C.witty_reader_delimiter_setup(path.str)
	if fd < 0 { panic('Delimiter setup failed') }
	defer {
		if C.witty_reader_delimiter_cleanup() != 0 { panic('Delimiter cleanup failed') }
	}
	mut buffer := []u8{len: f[1].int(), init: 165}
	mut output := []u8{}
	mut reader := zigimg.ReadStream.init_file(os.File{ fd: fd }, mut buffer)
	observed_reader = &reader
	observed_buffer = unsafe { buffer }
	observed_output = unsafe { output }
	reader.seek_to(f[2].u64()) or { panic(err) }
	reader.peek(buffer.len) or { panic(err) }
	reader.toss(usize(f[3].int()))
	mut out := snapshot(mut reader, buffer, output) + '~'
	if C.witty_reader_delimiter_replace(0) != 0 { panic('Delimiter replacement failed') }
	if C.witty_reader_delimiter_seed(0, usize(f[5].int())) != 0 { panic('Delimiter seed failed') }
	if f[6] == '1' && C.witty_reader_delimiter_shutdown() != 0 { panic('Delimiter shutdown failed') }
	out += 'rebound|' + snapshot(mut reader, buffer, output) + '~'
	if f[9] == '1' {
		observed_status = 'ok'
		reader.peek(buffer.len) or { observed_status = err.msg() }
		if f[10] == '1' { reader.toss(usize(reader.buffered_len())) }
		out += 'primed-${observed_status}|' + snapshot(mut reader, buffer, output) + '~'
	} else {
		out += 'primed-skip|' + snapshot(mut reader, buffer, output) + '~'
	}
	observed_status = read(mut reader, mut output, f[0].int(), u8(f[4].int()), usize(f[11].u64()))
	observed_output = unsafe { output }
	out += '${observed_status}|' + snapshot(mut reader, buffer, output) + '~'
	observed_status = 'ok'
	reader.seek_by(f[8].i64()) or { observed_status = err.msg() }
	observed_output = unsafe { output }
	out += '${observed_status}|' + snapshot(mut reader, buffer, output) + '~'
	if f[6] == '0' && f[7].int() > 0 {
		if C.witty_reader_delimiter_seed(usize(f[5].int()), usize(f[7].int())) != 0 {
			panic('Delimiter reseed failed')
		}
	}
	observed_status = read(mut reader, mut output, f[0].int(), u8(f[4].int()), usize(f[11].u64()))
	observed_output = unsafe { output }
	out += '${observed_status}|' + snapshot(mut reader, buffer, output) + '~'
	mut wire := []u8{}
	mut drain := isize(-3)
	for {
		mut bytes := []u8{len: 4096}
		drain = C.witty_reader_delimiter_drain(bytes.data, usize(bytes.len))
		if drain <= 0 { break
		 }
		wire << bytes[..int(drain)]
	}
	return out + '${drain}:${wire.hex()}'
}

fn simple_snapshot(mut reader zigimg.ReadStream, buffer []u8, output []u8) string {
	pending := reader.peek(reader.buffered_len()) or { panic(err) }
	size := reader.get_end_pos() or {
		return '${reader.get_pos()}:${err.msg()}|${buffer.hex()}|${output.hex()}|${pending.hex()}'
	}
	return '${reader.get_pos()}:${size}|${buffer.hex()}|${output.hex()}|${pending.hex()}'
}

fn simple_record(line string, path string) string {
	f := line.split('|')
	data := hex.decode(f[6]) or { panic(err) }
	mut buffer := []u8{len: f[2].int(), init: 165}
	mut reader := zigimg.ReadStream.init_memory(data)
	if f[0] != '0' {
		fd := C.witty_reader_exclusive_payload(path.str, data.data, usize(data.len))
		if fd < 0 { panic('Exclusive payload setup failed') }
		reader = if f[0] == '1' { zigimg.ReadStream.init_file(os.File{ fd: fd }, mut buffer) } else { zigimg.ReadStream.init_file_streaming(os.File{
				fd: fd
			}, mut buffer) }
	} else {
		buffer = unsafe { data }
	}
	defer {
		if f[0] != '0' && C.witty_reader_delimiter_cleanup() != 0 {
			panic('Exclusive payload cleanup failed')
		}
	}
	mut output := []u8{}
	observed_reader = &reader
	observed_buffer = unsafe { buffer }
	observed_output = unsafe { output }
	mut status := 'ok'
	if f[3].int() > 0 { reader.seek_to(f[3].u64()) or { status = err.msg() } }
	mut out := '${status}|' + simple_snapshot(mut reader, buffer, output) + '~'
	for attempt in 0 .. 3 {
		observed_status = 'calling'
		status = read(mut reader, mut output, f[1].int(), u8(f[4].int()), usize(f[7].u64()))
		observed_status = status
		observed_output = unsafe { output }
		out += '${status}|' + simple_snapshot(mut reader, buffer, output) + '~'
		if attempt == 0 {
			status = 'ok'
			reader.seek_by(f[5].i64()) or { status = err.msg() }
			observed_status = status
			observed_output = unsafe { output }
			out += '${status}|' + simple_snapshot(mut reader, buffer, output) + '~'
		}
	}
	return out
}

fn main() {
	if os.args[1] == '--simple-trap' {
		observed_path = os.args[2]
		at_exit(observe) or { panic(err) }
		result := simple_record(os.args[3], os.args[2] + '.owned')
		observed_path = ''
		println(result)
		return
	}
	if os.args[1] == '--simple' {
		for i, line in (os.read_lines(os.args[2]) or { panic(err) }) {
			println(simple_record(line, os.args[2] + '.${i}.owned'))
		}
		return
	}
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
