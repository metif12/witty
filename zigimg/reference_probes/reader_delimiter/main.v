module main

import os
import zigimg

#flag -I @DIR
#include "fixture_shims.h"

fn C.witty_reader_delimiter_setup(&char) int
fn C.witty_reader_delimiter_replace(int) int
fn C.witty_reader_delimiter_seed(uint, uint) int
fn C.witty_reader_delimiter_shutdown() int
fn C.witty_reader_delimiter_cleanup() int
fn C.witty_reader_delimiter_valid() int
fn C.witty_reader_delimiter_refs() int
fn C.witty_reader_delimiter_drain(&u8, uint) int

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
	size := reader.get_end_pos() or { panic(err) }
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

fn read(mut reader zigimg.ReadStream, mut output []u8, api int, delimiter u8) string {
	value := if api == 0 {
		reader.peek_delimiter_inclusive(delimiter) or { return err.msg() }
	} else {
		reader.take_delimiter_inclusive(delimiter) or { return err.msg() }
	}
	output = value.clone()
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
	reader.toss(uint(f[3].int()))
	mut out := snapshot(mut reader, buffer, output) + '~'
	if C.witty_reader_delimiter_replace(0) != 0 { panic('Delimiter replacement failed') }
	if C.witty_reader_delimiter_seed(0, uint(f[5].int())) != 0 { panic('Delimiter seed failed') }
	if f[6] == '1' && C.witty_reader_delimiter_shutdown() != 0 { panic('Delimiter shutdown failed') }
	out += 'rebound|' + snapshot(mut reader, buffer, output) + '~'
	if f[9] == '1' {
		observed_status = 'ok'
		reader.peek(buffer.len) or { observed_status = err.msg() }
		if f[10] == '1' { reader.toss(uint(reader.buffered_len())) }
		out += 'primed-${observed_status}|' + snapshot(mut reader, buffer, output) + '~'
	} else {
		out += 'primed-skip|' + snapshot(mut reader, buffer, output) + '~'
	}
	observed_status = read(mut reader, mut output, f[0].int(), u8(f[4].int()))
	observed_output = unsafe { output }
	out += '${observed_status}|' + snapshot(mut reader, buffer, output) + '~'
	observed_status = 'ok'
	reader.seek_by(f[8].i64()) or { observed_status = err.msg() }
	observed_output = unsafe { output }
	out += '${observed_status}|' + snapshot(mut reader, buffer, output) + '~'
	if f[6] == '0' && f[7].int() > 0 {
		if C.witty_reader_delimiter_seed(uint(f[5].int()), uint(f[7].int())) != 0 {
			panic('Delimiter reseed failed')
		}
	}
	observed_status = read(mut reader, mut output, f[0].int(), u8(f[4].int()))
	observed_output = unsafe { output }
	out += '${observed_status}|' + snapshot(mut reader, buffer, output) + '~'
	mut wire := []u8{}
	mut drain := int(-3)
	for {
		mut bytes := []u8{len: 4096}
		drain = C.witty_reader_delimiter_drain(bytes.data, uint(bytes.len))
		if drain <= 0 { break
		 }
		wire << bytes[..int(drain)]
	}
	return out + '${drain}:${wire.hex()}'
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
