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
	observed_calls    int
	observed_steps    int
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
		'#${precision}:${width}:${int(observed_options.alignment)}:${observed_options.fill}:${observed_base}:${observed_case}:${observed_tag}:${observed_length}#${observed_elements.hex()}#${observed_shape}:${observed_calls}:${observed_steps}'
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

struct Custom {
	raw  u64
	data []u8
	stop int
}

type CustomAlias = Custom
type CustomChoice = Custom | bool

struct CustomProblem {
	value Custom
}

pub fn (value CustomProblem) msg() string { return 'Alpha' }

pub fn (value CustomProblem) code() int { return 0 }

fn emit(value Custom, mut writer zigimg.WriteStream) ! {
	observed_calls++
	if value.stop == 1 { return error('WriteFailed') }
	writer.write_all('custom('.bytes())!
	observed_steps = 1
	if value.stop == 2 { return error('WriteFailed') }
	writer.print_value('d', zigimg.FormatOptions{}, int(value.raw & 255) - 128, 0)!
	observed_steps = 2
	writer.write_all(':'.bytes())!
	observed_steps = 3
	writer.write_all(value.data)!
	observed_steps = 4
	if value.stop == 3 { return error('WriteFailed') }
	writer.write_all(')'.bytes())!
	observed_steps = 5
}

pub fn (value Custom) format(mut writer zigimg.WriteStream) ! { emit(value, mut writer)! }

pub fn (value CustomProblem) format(mut writer zigimg.WriteStream) ! {
	emit(value.value, mut writer)!
}

pub fn (value CustomChoice) format(mut writer zigimg.WriteStream) ! {
	if value is Custom { emit(value, mut writer)! } else { panic('invalid fixture choice') }
}

fn make[T](value Custom) T {
	$if T.unaliased_typ is CustomProblem {
		return T(CustomProblem{value})
	} $else {
		return T(value)
	}
}

fn operate[T](mut writer zigimg.WriteStream, value T, options zigimg.FormatOptions, depth uint, tag int) string {
	$if T is Custom {
		if tag == 2 || tag == 3 {
			optional := if tag == 3 { ?Custom(none) } else { ?Custom(value) }
			writer.print_value('?f', options, optional, depth) or { return err.msg() }
			return 'ok'
		}
	}
	writer.print_value('f', options, value, depth) or { return err.msg() }
	return 'ok'
}

// kind|capacity|start|prefix-length|stop|width|binding|finish|data-length|fill|alignment|width-present|precision|rawbits|type|depth
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
		writer = if kind == 1 {
			zigimg.WriteStream.init_file(os.File{ fd: fd }, mut buffer)
		} else {
			zigimg.WriteStream.init_file_streaming(os.File{
				fd: fd
			}, mut buffer)
		}
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

	value := make[T](Custom{raw, unsafe { payload[10..10 + observed_length] }, f[4].int()})
	observed_elements = if observed_tag == 3 { [u8(0)] } else { payload[..8].clone() }
	if observed_tag != 3 {
		observed_elements << u8(f[4].int())
		observed_elements << payload[10..10 + observed_length]
	}
	observed_shape = ['record', 'alias', 'optional', 'none', 'union', 'error'][observed_tag]
	observed_calls = 0
	observed_steps = 0
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
	status = operate(mut adapter, value, options, uint(f[15].u64()), observed_tag)
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
			if drain <= 0 {
				break
			}
			wire << bytes[..int(drain)]
		}
	}
	return out + '${drain}:${wire.hex()}'
}

fn record(line string, path string) string {
	return match line.split('|')[14].int() {
		0 { typed_record[Custom](line, path) }
		1 { typed_record[CustomAlias](line, path) }
		2 { typed_record[Custom](line, path) }
		3 { typed_record[Custom](line, path) }
		4 { typed_record[CustomChoice](line, path) }
		5 { typed_record[CustomProblem](line, path) }
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
