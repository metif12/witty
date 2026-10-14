module main

import os
import zigimg

#flag -I @DIR
#include "fixture_shims.h"

fn C.witty_writer_seek_setup(&char) int
fn C.witty_writer_seek_replace(int) int
fn C.witty_writer_seek_restore(&char, usize) int
fn C.witty_writer_seek_close() int
fn C.witty_writer_seek_cleanup() int
fn C.witty_writer_seek_valid() int
fn C.witty_writer_seek_refs() int
fn C.witty_writer_seek_view(&u8, usize) isize
fn C.witty_writer_seek_drain(&u8, usize) isize

__global (
	observed_path   string
	observed_writer = &zigimg.WriteStream(unsafe { nil })
	observed_buffer []u8
)

fn snapshot(writer zigimg.WriteStream, buffer []u8) string {
	mut contents := []u8{len: 4096}
	n := C.witty_writer_seek_view(contents.data, usize(contents.len))
	if n < 0 { panic('Writer observer failed') }
	return '${writer.get_pos()}:${C.witty_writer_seek_valid()}:${C.witty_writer_seek_refs()}|${buffer.hex()}|${writer.buffered().hex()}|${contents[..int(n)].hex()}'
}

fn observe() {
	if observed_path == '' { return }
	state := snapshot(*observed_writer, observed_buffer)
	os.write_file(observed_path, state) or { eprintln('OBSERVER ERROR: ${err}') }
	C.witty_writer_seek_cleanup()
}

fn write(mut writer zigimg.WriteStream, bytes []u8, api int) string {
	if api == 1 {
		writer.write_all(bytes) or { return err.msg() }
		return 'ok'
	}
	n := writer.write(bytes) or { return err.msg() }
	return '${n}'
}

fn restore(path string) {
	restored := path + '.restored'
	if C.witty_writer_seek_restore(restored.str, 32) != 0 { panic('Writer restore failed') }
}

fn record(line string, path string) string {
	f := line.split('|')
	fd := C.witty_writer_seek_setup(path.str)
	if fd < 0 { panic('Writer setup failed') }
	defer {
		if C.witty_writer_seek_cleanup() != 0 { panic('Writer cleanup failed') }
	}
	mut buffer := []u8{len: f[2].int(), init: 165}
	mut writer := if f[1] == '1' {
		zigimg.WriteStream.init_file_streaming(os.File{ fd: fd }, mut buffer)
	} else {
		zigimg.WriteStream.init_file(os.File{ fd: fd }, mut buffer)
	}
	observed_writer = unsafe { &writer }
	observed_buffer = unsafe { buffer }
	writer.seek_to(f[3].u64()) or { panic(err) }
	if C.witty_writer_seek_replace(1) != 0 { panic('Writer replacement failed') }
	mut out := snapshot(writer, buffer) + '~'
	bytes := []u8{len: f[4].int(), init: u8(index * 31 + 7)}
	mut status := write(mut writer, bytes, f[0].int())
	out += '${status}|' + snapshot(writer, buffer) + '~'
	if f[8] == '1' {
		if C.witty_writer_seek_close() != 0 { panic('Writer invalidation failed') }
	} else if f[7] == '1' {
		restore(path)
	}
	out += 'rebound|' + snapshot(writer, buffer) + '~'
	status = 'ok'
	writer.seek_to(f[5].u64()) or { status = err.msg() }
	out += '${status}|' + snapshot(writer, buffer) + '~'
	if f[8] == '2' {
		if C.witty_writer_seek_close() != 0 { panic('Writer invalidation failed') }
	} else if f[7] == '2' {
		restore(path)
	}
	out += 'rebound|' + snapshot(writer, buffer) + '~'
	status = write(mut writer, [u8(209), 210, 211], f[0].int())
	out += '${status}|' + snapshot(writer, buffer) + '~'
	status = 'ok'
	writer.seek_to(f[6].u64()) or { status = err.msg() }
	out += '${status}|' + snapshot(writer, buffer) + '~'
	status = 'ok'
	writer.flush() or { status = err.msg() }
	out += '${status}|' + snapshot(writer, buffer) + '~'
	mut wire := []u8{}
	mut drain := isize(-3)
	for {
		mut bytes_out := []u8{len: 4096}
		drain = C.witty_writer_seek_drain(bytes_out.data, usize(bytes_out.len))
		if drain <= 0 { break
		 }
		wire << bytes_out[..int(drain)]
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
