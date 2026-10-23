module main

import os
import zigimg

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
	observed_payload  []u8
	observed_vectors  [][]u8
	observed_options  zigimg.FormatOptions
	observed_base     u8
	observed_case     usize
	observed_tag      int
	observed_length   int
	observed_elements []u8
	observed_shape    string
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
	mut headers := []string{}
	for bytes in observed_vectors {
		headers << '${usize(bytes.data) - usize(observed_payload.data)},${bytes.len}'
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

type Signed = i64
type Flag = bool
type Bytes = []u8

struct Group {
	number int
	active bool
}

struct Problem {
	name string
}

pub fn (e Problem) msg() string {
	return e.name
}

pub fn (e Problem) code() int {
	panic('code must not be called')
}

type Inner = i16 | u16
type Choice = Bytes | Flag | Group | Inner | Problem | Signed
type Alias = Choice

struct UnionRecord[T] {
	choice T
}

fn make(raw u64, payload []u8) Choice {
	return match raw % 6 {
		0 {
			Choice(Signed(i64(raw)))
		}
		1 {
			Choice(Flag(raw & 8 != 0))
		}
		2 {
			Choice(Bytes(unsafe { payload[10..13] }))
		}
		3 {
			Choice(Group{int(raw), raw & 8 != 0})
		}
		4 {
			Choice(Problem{if raw & 8 == 0 { 'Alpha' } else { 'Bad Name' }})
		}
		else {
			inner := if raw & 8 == 0 { Inner(i16(raw)) } else { Inner(u16(raw)) }
			Choice(inner)
		}
	}
}

fn packed(bytes []u8) []u8 {
	mut out := []u8{len: 8, init: u8(u64(bytes.len) >> (index * 8))}
	out << bytes
	return out
}

fn describe(value Choice) []u8 {
	$for variant in Choice.variants {
		if value is variant {
			mut out := packed(typeof(variant.typ).name.bytes())
			mut bytes := []u8{}
			$if variant.typ is Signed {
				bytes = []u8{len: 8, init: u8(u64(value) >> (index * 8))}
			} $else $if variant.typ is Flag {
				bytes = [u8(if value { 1 } else { 0 })]
			} $else $if variant.typ is Bytes {
				bytes = value.clone()
			} $else $if variant.typ is Group {
				bytes = []u8{len: 4, init: u8(u32(value.number) >> (index * 8))}
				bytes << u8(if value.active { 1 } else { 0 })
			} $else $if variant.typ is Problem {
				bytes = value.msg().bytes()
			} $else {
				inner := value
				match inner {
					u16 {
						bytes = packed('u16'.bytes())
						bytes << u8(inner)
						bytes << u8(inner >> 8)
					}
					i16 {
						bytes = packed('i16'.bytes())
						bytes << u8(u16(inner))
						bytes << u8(u16(inner) >> 8)
					}
				}
			}
			out << packed(bytes)
			return out
		}
	}
	panic('invalid union')
}

fn operate[T](mut writer zigimg.WriteStream, value T, values []T, nested [][]T, shape int, options zigimg.FormatOptions, depth usize, format int) string {
	if shape == 0 {
		formats := ['', 'any', 't']
		writer.print_value(formats[format], options, value, depth) or { return err.msg() }
	} else if shape == 1 {
		writer.print_value('any', options, values, depth) or { return err.msg() }
	} else if shape == 2 {
		writer.print_value('any', options, nested, depth) or { return err.msg() }
	} else {
		writer.print_value('any', options, UnionRecord[T]{value}, depth) or { return err.msg() }
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
	observed_case = usize(f[15].u64())
	observed_tag = f[14].int()
	precision := if f[12] == '-' { ?usize(none) } else { ?usize(usize(f[12].u64())) }
	width := if f[11] == '1' { ?usize(usize(f[5].u64())) } else { ?usize(none) }
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

	value := T(make(raw, payload))
	value_count := if observed_length == 0 || observed_length == 3 { 1 } else { 3 }
	values := []T{len: value_count, init: value}
	nested := [values[..1], values[1..], []T{}]
	mut elements := []u8{}
	for item in values {
		elements << describe(Choice(item))
	}
	observed_elements = elements.clone()
	observed_shape = ['scalar', 'slice:3', 'nested:1,2,0', 'record'][observed_length]
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
		usize(f[15].u64()), f[4].int())
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

fn record(line string, path string) string {
	return match line.split('|')[14].int() {
		0 { typed_record[Choice](line, path) }
		1 { typed_record[Alias](line, path) }
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
