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
	observed_path    string
	observed_writer  = &zigimg.WriteStream(unsafe { nil })
	observed_buffer  []u8
	observed_file    bool
	observed_status  string
	observed_payload []u8
	observed_vectors [][]u8
)

fn state(writer zigimg.WriteStream, buffer []u8) string {
	mut contents := []u8{len: 4096}
	n := if observed_file {
		C.witty_writer_seek_view(contents.data, uint(contents.len))
	} else {
		int(0)
	}
	if n < 0 { panic('Writer observer failed') }
	valid := if observed_file { C.witty_writer_seek_valid() } else { 0 }
	refs := if observed_file { C.witty_writer_seek_refs() } else { 0 }
	unused := writer.unused_capacity_slice()
	offset := if buffer.len == 0 { uint(0) } else { uint(unused.data) - uint(buffer.data) }
	mut headers := []string{}
	for bytes in observed_vectors {
		headers << '${uint(bytes.data) - uint(observed_payload.data)},${bytes.len}'
	}
	inputs := observed_payload.hex() + '#' + headers.join(';')
	return '${writer.get_pos()}:${writer.unused_capacity_len()}:${writer.buffered().len}:${offset}:${valid}:${refs}|${buffer.hex()}|${writer.buffered().hex()}|${unused.hex()}|${inputs}|${contents[..int(n)].hex()}'
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

type OrderBig = zigimg.BigEndian
type OrderLittle = zigimg.LittleEndian

// kind|capacity|start|prefix-length|type|reserved|binding|finish|api|mask|order|count|offset
fn typed_record[T](line string, path string) string {
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
	count, offset := f[11].int(), f[12].int()
	mut values := []T{len: count + 2}
	mut payload := unsafe { values.data.vbytes(values.len * int(sizeof(T))) }
	for i in 0 .. payload.len {
		payload[i] = u8(i * 23 + f[9].int())
	}
	input := unsafe { values[offset..offset + count] }
	input_bytes := unsafe { input.data.vbytes(input.len * int(sizeof(T))) }
	observed_payload = unsafe { payload }
	observed_vectors = [][]u8{}
	observed_vectors << unsafe { input_bytes }
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
	api := f[8].int()
	out += 'ready|' + state(writer, buffer) + '~'
	observed_status = 'write'
	mut status := 'skip'
	if api == 1 {
		adapter.write_slice_swap[T](input) or { status = err.msg() }
	} else {
		match f[10].int() {
			0 {
				adapter.write_slice_endian[T, zigimg.BigEndian](input, zigimg.BigEndian{}) or {
					status = err.msg()
				}
			}
			1 {
				adapter.write_slice_endian[T, zigimg.LittleEndian](input, zigimg.LittleEndian{}) or {
					status = err.msg()
				}
			}
			2 {
				adapter.write_slice_endian[T, OrderBig](input, OrderBig{}) or { status = err.msg() }
			}
			3 {
				adapter.write_slice_endian[T, OrderLittle](input, OrderLittle{}) or {
					status = err.msg()
				}
			}
			else {
				panic('Invalid byte order')
			}
		}
	}
	if status == 'skip' { status = 'ok' }
	out += status + '|' + state(writer, buffer) + '~'
	change(mut buffer, 1, u8(f[9].int()))
	out += 'caller|' + state(writer, buffer) + '~'
	status = 'skip'
	if f[7] == '1' {
		status = 'ok'
		writer.flush() or { status = err.msg() }
	}
	out += status + '|' + state(writer, buffer) + '~'
	mut drain := int(-3)
	mut wire := []u8{}
	if kind > 0 && f[6] == '1' {
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

fn record(line string, path string) string {
	return match line.split('|')[4].int() {
		0 { typed_record[u8](line, path) }
		1 { typed_record[u16](line, path) }
		2 { typed_record[u32](line, path) }
		3 { typed_record[u64](line, path) }
		4 { typed_record[uint](line, path) }
		5 { typed_record[i8](line, path) }
		6 { typed_record[i16](line, path) }
		7 { typed_record[int](line, path) }
		8 { typed_record[i64](line, path) }
		9 { typed_record[int](line, path) }
		10 { typed_record[Alias0](line, path) }
		11 { typed_record[Alias1](line, path) }
		12 { typed_record[Alias2](line, path) }
		13 { typed_record[Alias3](line, path) }
		14 { typed_record[Alias4](line, path) }
		15 { typed_record[Alias5](line, path) }
		16 { typed_record[Alias6](line, path) }
		17 { typed_record[Alias7](line, path) }
		18 { typed_record[Alias8](line, path) }
		19 { typed_record[Alias9](line, path) }
		else { panic('Invalid writer type') }
	}
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
