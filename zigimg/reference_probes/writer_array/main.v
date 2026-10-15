module main

import os
import zigimg
import encoding.hex

#flag -I @DIR
#flag -I @DIR/..
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
	observed_path     string
	observed_writer   = &zigimg.WriteStream(unsafe { nil })
	observed_buffer   []u8
	observed_file     bool
	observed_status   string
	observed_saved    []u8
	observed_borrowed bool
)

fn state(writer zigimg.WriteStream, buffer []u8) string {
	mut contents := []u8{len: 4096}
	n := if observed_file {
		C.witty_writer_seek_view(contents.data, usize(contents.len))
	} else {
		isize(0)
	}
	if n < 0 { panic('Writer observer failed') }
	valid := if observed_file { C.witty_writer_seek_valid() } else { 0 }
	refs := if observed_file { C.witty_writer_seek_refs() } else { 0 }
	unused := writer.unused_capacity_slice()
	offset := if buffer.len == 0 { usize(0) } else { usize(unused.data) - usize(buffer.data) }
	mut saved := '-'
	if observed_borrowed {
		saved_offset := if buffer.len == 0 {
			usize(0)
		} else {
			usize(observed_saved.data) - usize(buffer.data)
		}
		saved = '${saved_offset}:${observed_saved.len}:${observed_saved.hex()}'
	}
	return '${writer.get_pos()}:${writer.unused_capacity_len()}:${writer.buffered().len}:${offset}:${valid}:${refs}|${buffer.hex()}|${writer.buffered().hex()}|${unused.hex()}|${saved}|${contents[..int(n)].hex()}'
}

fn observe() {
	if observed_path == '' { return }
	retained := observed_status + '|' + state(*observed_writer, observed_buffer)
	os.write_file(observed_path, retained) or { eprintln('OBSERVER ERROR: ${err}') }
	if observed_file { C.witty_writer_seek_cleanup() }
}

fn change(mut bytes []u8, mode int, mask u8) {
	if mode == 0 || bytes.len == 0 { return }
	index := if mode == 1 { 0 } else { bytes.len - 1 }
	bytes[index] ^= mask
}

type ByteAlias = u8
type Bytes1 = [1]u8
type Bytes2 = [2]u8
type Bytes4 = [4]u8
type Bytes8 = [8]u8
type Bytes16 = [16]u8
type Bytes32 = [32]u8
type AliasedBytes = [2]ByteAlias

fn view_0(mut writer zigimg.WriteStream) ![]u8 {
	value := writer.writable_array[[1]u8]()!
	return unsafe { (&u8(value.value)).vbytes(1) }
}

fn view_1(mut writer zigimg.WriteStream) ![]u8 {
	value := writer.writable_array[[2]u8]()!
	return unsafe { (&u8(value.value)).vbytes(2) }
}

fn view_2(mut writer zigimg.WriteStream) ![]u8 {
	value := writer.writable_array[[4]u8]()!
	return unsafe { (&u8(value.value)).vbytes(4) }
}

fn view_3(mut writer zigimg.WriteStream) ![]u8 {
	value := writer.writable_array[[8]u8]()!
	return unsafe { (&u8(value.value)).vbytes(8) }
}

fn view_4(mut writer zigimg.WriteStream) ![]u8 {
	value := writer.writable_array[[16]u8]()!
	return unsafe { (&u8(value.value)).vbytes(16) }
}

fn view_5(mut writer zigimg.WriteStream) ![]u8 {
	value := writer.writable_array[[32]u8]()!
	return unsafe { (&u8(value.value)).vbytes(32) }
}

fn view_6(mut writer zigimg.WriteStream) ![]u8 {
	value := writer.writable_array[Bytes1]()!
	return unsafe { (&u8(value.value)).vbytes(1) }
}

fn view_7(mut writer zigimg.WriteStream) ![]u8 {
	value := writer.writable_array[Bytes2]()!
	return unsafe { (&u8(value.value)).vbytes(2) }
}

fn view_8(mut writer zigimg.WriteStream) ![]u8 {
	value := writer.writable_array[Bytes4]()!
	return unsafe { (&u8(value.value)).vbytes(4) }
}

fn view_9(mut writer zigimg.WriteStream) ![]u8 {
	value := writer.writable_array[Bytes8]()!
	return unsafe { (&u8(value.value)).vbytes(8) }
}

fn view_10(mut writer zigimg.WriteStream) ![]u8 {
	value := writer.writable_array[Bytes16]()!
	return unsafe { (&u8(value.value)).vbytes(16) }
}

fn view_11(mut writer zigimg.WriteStream) ![]u8 {
	value := writer.writable_array[Bytes32]()!
	return unsafe { (&u8(value.value)).vbytes(32) }
}

fn view_12(mut writer zigimg.WriteStream) ![]u8 {
	value := writer.writable_array[AliasedBytes]()!
	return unsafe { (&u8(value.value)).vbytes(2) }
}

fn array_view(mut writer zigimg.WriteStream, tag int) ![]u8 {
	return match tag {
		0 { view_0(mut writer)! }
		1 { view_1(mut writer)! }
		2 { view_2(mut writer)! }
		3 { view_3(mut writer)! }
		4 { view_4(mut writer)! }
		5 { view_5(mut writer)! }
		6 { view_6(mut writer)! }
		7 { view_7(mut writer)! }
		8 { view_8(mut writer)! }
		9 { view_9(mut writer)! }
		10 { view_10(mut writer)! }
		11 { view_11(mut writer)! }
		12 { view_12(mut writer)! }
		else { panic('Invalid array type') }
	}
}

// kind|capacity|start|prefix-length|preserve|array-type-or-byte|binding|finish|method|mask
fn record(line string, path string) string {
	f := line.split('|')
	kind, cap, start := f[0].int(), f[1].int(), f[2].u64()
	mut buffer := []u8{len: cap, init: u8(index * 17 + 165)}
	mut writer := zigimg.WriteStream.init_memory(mut buffer)
	if kind > 0 {
		fd := C.witty_writer_seek_setup(path.str)
		restored := path + '.restored'
		if fd < 0 || C.witty_writer_seek_restore(restored.str, 32) != 0 {
			panic('Writer setup failed')
		}
		writer = if kind == 1 { zigimg.WriteStream.init_file(os.File{ fd: fd }, mut buffer) } else { zigimg.WriteStream.init_file_streaming(os.File{
				fd: fd
			}, mut buffer) }
	}
	defer {
		if kind > 0 && C.witty_writer_seek_cleanup() != 0 { panic('Writer cleanup failed') }
	}
	observed_writer = unsafe { &writer }
	observed_buffer = unsafe { buffer }
	observed_file = kind > 0
	observed_borrowed = false
	observed_saved = []u8{}
	observed_status = 'setup'
	writer.seek_to(start) or {}
	writer.write_all([]u8{len: f[3].int(), init: u8(index * 31 + 7)}) or {
		panic('Prefix failed: ${err}')
	}
	if kind > 0 {
		if f[6] == '1' && C.witty_writer_seek_replace(1) != 0 { panic('Writer replacement failed') }
		if f[6] == '2' && C.witty_writer_seek_close() != 0 { panic('Writer close failed') }
	}
	mut out := 'setup|' + state(writer, buffer) + '~'
	mut adapter := writer.writer()
	observed_status = 'operation'
	mut status := 'ok'
	mut saved := []u8{}
	method := f[8].int()
	if method == 0 {
		saved = array_view(mut adapter, f[5].int()) or {
			status = err.msg()
			[]u8{}
		}
		if status == 'ok' {
			observed_saved = unsafe { saved }
			observed_borrowed = true
		}
	} else {
		adapter.write_byte_preserve(usize(f[4].u64()), u8(f[5].int())) or { status = err.msg() }
	}
	out += status + '|' + state(writer, buffer) + '~'
	change(mut buffer, 1, u8(f[9].int()))
	out += 'caller|' + state(writer, buffer) + '~'
	change(mut saved, 2, u8(f[9].int()))
	out += 'saved|' + state(writer, buffer) + '~'
	status = 'skip'
	if f[7] == '1' {
		status = 'ok'
		writer.flush() or { status = err.msg() }
	}
	out += status + '|' + state(writer, buffer) + '~'
	mut drain := isize(-3)
	mut wire := []u8{}
	if kind > 0 && f[6] == '1' {
		for {
			mut bytes := []u8{len: 4096}
			drain = C.witty_writer_seek_drain(bytes.data, usize(bytes.len))
			if drain <= 0 { break
			 }
			wire << bytes[..int(drain)]
		}
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
