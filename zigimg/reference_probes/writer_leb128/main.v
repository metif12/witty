module main

import os
import zigimg
import encoding.hex

#flag -I @DIR
#flag -I @DIR/..
#include "fixture_shims.h"

fn C.witty_writer_seek_setup(&char) int
fn C.witty_writer_seek_replace(int) int
fn C.witty_writer_seek_restore(&char, uint) int
fn C.witty_writer_seek_close() int
fn C.witty_writer_seek_cleanup() int
fn C.witty_writer_seek_valid() int
fn C.witty_writer_seek_refs() int
fn C.witty_writer_seek_view(&u8, uint) int
fn C.witty_writer_seek_drain(&u8, uint) int

__global (
	observed_path   string
	observed_writer = &zigimg.WriteStream(unsafe { nil })
	observed_buffer []u8
	observed_file   bool
	observed_status string
)

fn snapshot(writer zigimg.WriteStream, buffer []u8) string {
	mut contents := []u8{len: 4096}
	n := if observed_file {
		C.witty_writer_seek_view(contents.data, uint(contents.len))
	} else {
		int(0)
	}
	if n < 0 { panic('Writer observer failed') }
	valid := if observed_file { C.witty_writer_seek_valid() } else { 0 }
	refs := if observed_file { C.witty_writer_seek_refs() } else { 0 }
	return '${writer.get_pos()}:${valid}:${refs}|${buffer.hex()}|${writer.buffered().hex()}|${contents[..int(n)].hex()}'
}

fn observe() {
	if observed_path == '' { return }
	state := observed_status + '|' + snapshot(*observed_writer, observed_buffer)
	os.write_file(observed_path, state) or { eprintln('OBSERVER ERROR: ${err}') }
	C.witty_writer_seek_cleanup()
}

type Alias0 = u8
type Alias1 = u16
type Alias2 = u32
type Alias3 = u64
type Alias4 = uint
type Alias5 = i8
type Alias6 = i16
type Alias7 = int
type Alias8 = i64
type Alias9 = int

fn typed_write[T](mut writer zigimg.WriteStream, raw u64, op int) string {
	value := T(raw)
	mut adapter := writer.writer()
	if op == 0 {
		adapter.write_leb128[T](value) or { return err.msg() }
	} else if op == 1 {
		adapter.write_uleb128[T](value) or { return err.msg() }
	} else {
		adapter.write_sleb128[T](value) or { return err.msg() }
	}
	return 'ok'
}

fn operate(mut writer zigimg.WriteStream, raw u64, tag int, op int) string {
	return match tag {
		0 { typed_write[u8](mut writer, raw, op) }
		1 { typed_write[u16](mut writer, raw, op) }
		2 { typed_write[u32](mut writer, raw, op) }
		3 { typed_write[u64](mut writer, raw, op) }
		4 { typed_write[uint](mut writer, raw, op) }
		5 { typed_write[i8](mut writer, raw, op) }
		6 { typed_write[i16](mut writer, raw, op) }
		7 { typed_write[int](mut writer, raw, op) }
		8 { typed_write[i64](mut writer, raw, op) }
		9 { typed_write[int](mut writer, raw, op) }
		10 { typed_write[Alias0](mut writer, raw, op) }
		11 { typed_write[Alias1](mut writer, raw, op) }
		12 { typed_write[Alias2](mut writer, raw, op) }
		13 { typed_write[Alias3](mut writer, raw, op) }
		14 { typed_write[Alias4](mut writer, raw, op) }
		15 { typed_write[Alias5](mut writer, raw, op) }
		16 { typed_write[Alias6](mut writer, raw, op) }
		17 { typed_write[Alias7](mut writer, raw, op) }
		18 { typed_write[Alias8](mut writer, raw, op) }
		19 { typed_write[Alias9](mut writer, raw, op) }
		else { panic('Invalid writer type') }
	}
}

// kind|capacity|start|prefixhex|type|operation|rawbits|replacement|second-seek
fn record(line string, path string) string {
	f := line.split('|')
	kind, capacity, start := f[0].int(), f[1].int(), f[2].u64()
	prefix := hex.decode(f[3]) or { panic(err) }
	mut buffer := []u8{len: capacity, init: 165}
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
	observed_writer = &writer
	observed_buffer = unsafe { buffer }
	observed_file = kind > 0
	observed_status = 'setup'
	mut status := 'ok'
	writer.seek_to(start) or { status = err.msg() }
	mut out := status + '|' + snapshot(writer, buffer) + '~'
	status = 'ok'
	writer.write_all(prefix) or { status = err.msg() }
	if kind > 0 {
		if f[7] == '1' && C.witty_writer_seek_replace(1) != 0 { panic('Writer replacement failed') }
		if f[7] == '2' && C.witty_writer_seek_close() != 0 { panic('Writer close failed') }
	}
	out += status + '|' + snapshot(writer, buffer) + '~'
	for attempt in 0 .. 3 {
		observed_status = 'calling'
		status = operate(mut writer, f[6].u64(), f[4].int(), f[5].int())
		observed_status = status
		out += status + '|' + snapshot(writer, buffer) + '~'
		if attempt == 0 {
			status = 'ok'
			writer.seek_to(f[8].u64()) or { status = err.msg() }
			out += status + '|' + snapshot(writer, buffer) + '~'
		} else {
			status = 'ok'
			writer.flush() or { status = err.msg() }
			out += status + '|' + snapshot(writer, buffer) + '~'
		}
	}
	mut wire := []u8{}
	mut drain := int(-3)
	if kind > 0 && f[7] == '1' {
		for {
			mut bytes := []u8{len: 4096}
			drain = C.witty_writer_seek_drain(bytes.data, uint(bytes.len))
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
