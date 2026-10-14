module main

import os
import zigimg

#flag -I @DIR
#include "fixture_shims.h"

fn C.witty_stream_transition_setup(&char) int
fn C.witty_stream_transition_replace(int) int
fn C.witty_stream_transition_seed(usize, usize) int
fn C.witty_stream_transition_shutdown() int
fn C.witty_stream_transition_cleanup() int
fn C.witty_stream_transition_valid() int
fn C.witty_stream_transition_refs() int
fn C.witty_stream_transition_drain(&u8, usize) isize

fn snapshot(mut reader zigimg.ReadStream, writer zigimg.WriteStream, buffer []u8, output []u8, writing bool) string {
	position := if writing { writer.get_pos() } else { reader.get_pos() }
	pending := if writing { writer.buffered() } else { reader.peek(reader.buffered_len()) or {
			panic(err)} }
	mut size := '-'
	if !writing {
		value := reader.get_end_pos() or { panic(err) }
		size = value.str()
	}
	return '${position}:${size}:${C.witty_stream_transition_valid()}:${C.witty_stream_transition_refs()}|${buffer.hex()}|${output.hex()}|${pending.hex()}'
}

fn record(line string, path string) string {
	f := line.split('|')
	op := f[0].int()
	writing := op >= 2
	fd := C.witty_stream_transition_setup(path.str)
	if fd < 0 { panic('Transition setup failed') }
	defer {
		if C.witty_stream_transition_cleanup() != 0 { panic('Transition cleanup failed') }
	}
	file := os.File{
		fd: fd
	}
	mut buffer := []u8{len: f[1].int(), init: 165}
	mut output := []u8{len: f[3].int(), init: 182}
	mut reader := zigimg.ReadStream.init_file(file, mut buffer)
	mut writer := zigimg.WriteStream.init_file(file, mut buffer)
	if writing {
		writer.seek_to(f[2].u64()) or { panic(err) }
	} else {
		reader.seek_to(f[2].u64()) or { panic(err) }
	}
	if C.witty_stream_transition_replace(int(writing)) != 0 {
		panic('Transition replacement failed')
	}
	if !writing && C.witty_stream_transition_seed(0, usize(f[4].int())) != 0 {
		panic('Transition seed failed')
	}
	if f[5] == '1' && C.witty_stream_transition_shutdown() != 0 {
		panic('Transition shutdown failed')
	}
	mut out := snapshot(mut reader, writer, buffer, output, writing) + '~'
	payload := []u8{len: output.len, init: u8(index * 17 + 11)}
	for attempt in 0 .. 2 {
		if attempt == 1 && !writing && f[5] == '0' && f[6].int() > 0 {
			if C.witty_stream_transition_seed(usize(f[4].int()), usize(f[6].int())) != 0 {
				panic('Transition reseed failed')
			}
		}
		mut status := 'ok'
		mut result := '-'
		if op == 0 {
			reader.read_slice_all(mut output) or { status = err.msg() }
		} else if op == 1 {
			value := reader.take(output.len) or {
				status = err.msg()
				[]u8{}
			}
			if status == 'ok' {
				for i, byte in value {
					output[i] = byte
				}
			}
		} else if op == 2 {
			n := writer.write(payload) or {
				status = err.msg()
				usize(0)
			}
			if status == 'ok' { result = n.str() }
		} else {
			writer.write_all(payload) or { status = err.msg() }
		}
		if writing && f[7] == '1' { writer.flush() or { status += ':flush-' + err.msg() } }
		out += '${status}:${result}|' + snapshot(mut reader, writer, buffer, output, writing) + '~'
	}
	mut wire := []u8{}
	mut drain := isize(-3)
	for {
		mut bytes := []u8{len: 4096}
		drain = C.witty_stream_transition_drain(bytes.data, usize(bytes.len))
		if drain <= 0 { break
		 }
		wire << bytes[..int(drain)]
	}
	return out + '${drain}:${wire.hex()}'
}

fn main() {
	for i, line in (os.read_lines(os.args[1]) or { panic(err) }) {
		println(record(line, os.args[1] + '.${i}.owned'))
	}
}
