module main

import os
import zigimg

#flag -I @DIR
#include "fixture_shims.h"

fn C.witty_stream_seek_setup(&char) int
fn C.witty_stream_seek_replace(int) int
fn C.witty_stream_seek_seed(usize, usize) int
fn C.witty_stream_seek_shutdown() int
fn C.witty_stream_seek_cleanup() int
fn C.witty_stream_seek_close() int
fn C.witty_stream_seek_valid() int
fn C.witty_stream_seek_refs() int
fn C.witty_stream_seek_drain(&u8, usize) isize

__global (
	observed_path   string
	observed_reader = &zigimg.ReadStream(unsafe { nil })
	observed_buffer []u8
	observed_output []u8
)
fn snapshot(mut reader zigimg.ReadStream, buffer []u8, output []u8) string {
	pending := reader.peek(reader.buffered_len()) or { panic(err) }
	size := reader.get_end_pos() or { panic(err) }
	return '${reader.get_pos()}:${size}:${C.witty_stream_seek_valid()}:${C.witty_stream_seek_refs()}|${buffer.hex()}|${output.hex()}|${pending.hex()}'
}

fn observe() {
	if observed_path == '' { return }
	state := snapshot(mut observed_reader, observed_buffer, observed_output)
	os.write_file(observed_path, state) or { eprintln('OBSERVER ERROR: ${err}') }
	C.witty_stream_seek_cleanup()
}

fn record(line string, path string) string {
	f := line.split('|')
	fd := C.witty_stream_seek_setup(path.str)
	if fd < 0 { panic('Seek setup failed') }
	defer {
		if C.witty_stream_seek_cleanup() != 0 { panic('Seek cleanup failed') }
	}
	mut buffer := []u8{len: f[1].int(), init: 165}
	mut output := []u8{len: f[3].int(), init: 182}
	mut reader := zigimg.ReadStream.init_file(os.File{ fd: fd }, mut buffer)
	observed_reader = &reader
	observed_buffer = unsafe { buffer }
	observed_output = unsafe { output }
	reader.seek_to(f[2].u64()) or { panic(err) }
	if C.witty_stream_seek_replace(0) != 0 { panic('Seek replacement failed') }
	if C.witty_stream_seek_seed(0, usize(f[4].int())) != 0 { panic('Seek seed failed') }
	if f[5] == '1' && C.witty_stream_seek_shutdown() != 0 { panic('Seek shutdown failed') }
	mut out := snapshot(mut reader, buffer, output) + '~'
	for attempt in 0 .. 2 {
		if attempt == 1 && f[5] == '0' && f[6].int() > 0 {
			if C.witty_stream_seek_seed(usize(f[4].int()), usize(f[6].int())) != 0 {
				panic('Seek reseed failed')
			}
		}
		mut status := 'ok'
		if attempt == 0 {
			if f[0] == '0' {
				reader.read_slice_all(mut output) or { status = err.msg() }
			} else {
				value := reader.take(output.len) or {
					status = err.msg()
					[]u8{}
				}
				if status == 'ok' {
					for i, byte in value {
						output[i] = byte
					}
				}
			}
			out += '${status}|' + snapshot(mut reader, buffer, output) + '~'
			status = 'ok'
		}
		if attempt == 0 && f[8] == '1' && C.witty_stream_seek_close() != 0 {
			panic('Seek invalidation failed')
		}
		reader.seek_to(f[7].u64()) or { status = err.msg() }
		out += '${status}|' + snapshot(mut reader, buffer, output) + '~'
		status = 'ok'
		if f[0] == '0' {
			reader.read_slice_all(mut output) or { status = err.msg() }
		} else {
			value := reader.take(output.len) or {
				status = err.msg()
				[]u8{}
			}
			if status == 'ok' {
				for i, byte in value {
					output[i] = byte
				}
			}
		}
		out += '${status}|' + snapshot(mut reader, buffer, output) + '~'
	}
	mut wire := []u8{}
	mut drain := isize(-3)
	for {
		mut bytes := []u8{len: 4096}
		drain = C.witty_stream_seek_drain(bytes.data, usize(bytes.len))
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
