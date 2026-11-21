module main

import os
import zigimg

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
	observed_path     string
	observed_writer   = &zigimg.WriteStream(unsafe { nil })
	observed_buffer   []u8
	observed_file     bool
	observed_status   string
	observed_payload  []u8
	observed_vectors  [][]u8
	observed_options  zigimg.FormatOptions
	observed_base     u8
	observed_case     uint
	observed_tag      int
	observed_length   int
	observed_elements []u8
	observed_shape    string
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
	precision := if value := observed_options.precision { '${value}' } else { '-' }
	width := if value := observed_options.width { '${value}' } else { '-' }
	inputs := observed_payload.hex() + '#' + headers.join(';') +
		'#${precision}:${width}:${int(observed_options.alignment)}:${observed_options.fill}:${observed_base}:${observed_case}:${observed_tag}:${observed_length}#${observed_elements.hex()}#${observed_shape}'
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

enum Closed0 as u8 {
	first    = 0
	second   = 2
	third    = 131
	long_tag = 255
}

enum Closed1 as u16 {
	first    = 0
	second   = 2
	third    = 32771
	long_tag = 65535
}

enum Closed2 as u32 {
	first    = 0
	second   = 2
	third    = 2147483651
	long_tag = 4294967295
}

enum Closed3 as u64 {
	first    = 0
	second   = 2
	third    = 9223372036854775811
	long_tag = 18446744073709551615
}

enum Closed4 as i8 {
	first    = -128
	second   = -3
	third    = 0
	long_tag = 126
}

enum Closed5 as i16 {
	first    = -32768
	second   = -3
	third    = 0
	long_tag = 32766
}

enum Closed6 {
	first    = -2147483648
	second   = -3
	third    = 0
	long_tag = 2147483646
}

enum Closed7 as i64 {
	first    = -9223372036854775808
	second   = -3
	third    = 0
	long_tag = 9223372036854775806
}

@[nonexhaustive]
enum Open0 as u8 {
	first    = 0
	second   = 2
	third    = 131
	long_tag = 255
}

@[nonexhaustive]
enum Open1 as u16 {
	first    = 0
	second   = 2
	third    = 32771
	long_tag = 65535
}

@[nonexhaustive]
enum Open2 as u32 {
	first    = 0
	second   = 2
	third    = 2147483651
	long_tag = 4294967295
}

@[nonexhaustive]
enum Open3 as u64 {
	first    = 0
	second   = 2
	third    = 9223372036854775811
	long_tag = 18446744073709551615
}

@[nonexhaustive]
enum Open4 as i8 {
	first    = -128
	second   = -3
	third    = 0
	long_tag = 126
}

@[nonexhaustive]
enum Open5 as i16 {
	first    = -32768
	second   = -3
	third    = 0
	long_tag = 32766
}

@[nonexhaustive]
enum Open6 {
	first    = -2147483648
	second   = -3
	third    = 0
	long_tag = 2147483646
}

@[nonexhaustive]
enum Open7 as i64 {
	first    = -9223372036854775808
	second   = -3
	third    = 0
	long_tag = 9223372036854775806
}
type AliasClosed0 = Closed0
type AliasClosed1 = Closed1
type AliasClosed2 = Closed2
type AliasClosed3 = Closed3
type AliasClosed4 = Closed4
type AliasClosed5 = Closed5
type AliasClosed6 = Closed6
type AliasClosed7 = Closed7
type AliasOpen0 = Open0
type AliasOpen1 = Open1
type AliasOpen2 = Open2
type AliasOpen3 = Open3
type AliasOpen4 = Open4
type AliasOpen5 = Open5
type AliasOpen6 = Open6
type AliasOpen7 = Open7

fn operate[T](mut writer zigimg.WriteStream, value T, values []T, nested [][]T, shape int, options zigimg.FormatOptions, depth uint, format int) string {
	if shape == 0 {
		formats := ['', 'any', 'd', 'b', 'o', 'x', 'X', 't']
		writer.print_value(formats[format], options, value, depth) or { return err.msg() }
	} else if shape == 1 {
		writer.print_value('any', options, values, depth) or { return err.msg() }
	} else {
		writer.print_value('any', options, nested, depth) or { return err.msg() }
	}
	return 'ok'
}

// kind|capacity|start|prefix-length|format|width|binding|finish|shape|fill|alignment|width-present|precision|rawbits|type|depth
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
	raw := f[13].u64()
	mut payload := []u8{len: 8, init: u8(raw >> (index * 8))}
	payload << []u8{len: 256, init: u8(index * 23 + f[9].int())}
	data := unsafe { payload[..8] }
	observed_length = f[8].int()
	observed_base = u8(f[4].int())
	observed_case = uint(f[15].u64())
	observed_tag = f[14].int()
	precision := if f[12] == '-' { ?uint(none) } else { ?uint(uint(f[12].u64())) }
	width := if f[11] == '1' { ?uint(uint(f[5].u64())) } else { ?uint(none) }
	options := zigimg.FormatOptions{
		precision: precision
		width:     width
		alignment: unsafe { zigimg.Alignment(f[10].int()) }
		fill:      u8(f[9].int())
	}
	observed_options = options
	observed_payload = unsafe { payload }
	observed_vectors = [][]u8{}
	observed_vectors << unsafe { data }
	observed_vectors << unsafe { payload[10..10 + observed_length] }

	value := unsafe { T(raw) }
	value_count := if observed_length == 0 { 1 } else { 3 }
	values := []T{len: value_count, init: value}
	nested := [values[..1], values[1..], []T{}]
	observed_elements = unsafe { values.data.vbytes(values.len * int(sizeof(T))) }
	observed_shape = ['scalar', 'slice:3', 'nested:1,2,0'][observed_length]
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
	out += 'ready|' + state(writer, buffer) + '~'
	observed_status = 'write'
	mut status := 'skip'
	status = operate(mut adapter, value, values, nested, observed_length, options,
		uint(f[15].u64()), f[4].int())
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
	return match line.split('|')[14].int() {
		0 { typed_record[Closed0](line, path) }
		1 { typed_record[Closed1](line, path) }
		2 { typed_record[Closed2](line, path) }
		3 { typed_record[Closed3](line, path) }
		4 { typed_record[Closed4](line, path) }
		5 { typed_record[Closed5](line, path) }
		6 { typed_record[Closed6](line, path) }
		7 { typed_record[Closed7](line, path) }
		8 { typed_record[Open0](line, path) }
		9 { typed_record[Open1](line, path) }
		10 { typed_record[Open2](line, path) }
		11 { typed_record[Open3](line, path) }
		12 { typed_record[Open4](line, path) }
		13 { typed_record[Open5](line, path) }
		14 { typed_record[Open6](line, path) }
		15 { typed_record[Open7](line, path) }
		16 { typed_record[AliasClosed0](line, path) }
		17 { typed_record[AliasClosed1](line, path) }
		18 { typed_record[AliasClosed2](line, path) }
		19 { typed_record[AliasClosed3](line, path) }
		20 { typed_record[AliasClosed4](line, path) }
		21 { typed_record[AliasClosed5](line, path) }
		22 { typed_record[AliasClosed6](line, path) }
		23 { typed_record[AliasClosed7](line, path) }
		24 { typed_record[AliasOpen0](line, path) }
		25 { typed_record[AliasOpen1](line, path) }
		26 { typed_record[AliasOpen2](line, path) }
		27 { typed_record[AliasOpen3](line, path) }
		28 { typed_record[AliasOpen4](line, path) }
		29 { typed_record[AliasOpen5](line, path) }
		30 { typed_record[AliasOpen6](line, path) }
		31 { typed_record[AliasOpen7](line, path) }
		else { panic('Invalid tag') }
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
