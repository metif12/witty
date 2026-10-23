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

struct Empty {}

struct Numbers {
	n     i64
	u     u64
	truth bool
}

struct Sequences {
	bytes []u8
	fixed [2]i16
}

struct Nested {
	child Numbers
	empty Empty
	items []Empty
}

enum Tag {
	zero
	high
}
struct Tagged {
	tag Tag
	n   int
}

struct Custom {
	n int
}

fn (value Custom) format() string {
	return '${value.n}'
}

type AliasEmpty = Empty
type AliasNumbers = Numbers
type AliasSequences = Sequences
type AliasNested = Nested
type AliasTagged = Tagged
type AliasCustom = Custom

fn numbers(raw u64) Numbers {
	return Numbers{unsafe { i64(raw) }, raw, raw & 1 != 0}
}

fn make[T](raw u64, payload []u8) T {
	$if T.unaliased_typ is Empty {
		value := Empty{}
		return T(value)
	} $else $if T.unaliased_typ is Numbers {
		value := numbers(raw)
		return T(value)
	} $else $if T.unaliased_typ is Sequences {
		fixed := [i16(raw), i16(raw >> 16)]!
		value := Sequences{payload[8..11], fixed}
		return T(value)
	} $else $if T.unaliased_typ is Nested {
		value := Nested{numbers(raw), Empty{}, [Empty{}, Empty{}]}
		return T(value)
	} $else $if T.unaliased_typ is Tagged {
		value := Tagged{unsafe { Tag(int(raw & 1)) }, int(raw)}
		return T(value)
	} $else {
		value := Custom{int(raw)}
		return T(value)
	}
}

// Actual scalar bytes in declaration order, excluding padding and descriptors.
fn leaf[T](value T) []u8 {
	return unsafe { (&u8(&value)).vbytes(int(sizeof(T))).clone() }
}

fn number_leaves(value Numbers) []u8 {
	mut out := leaf(value.n)
	out << leaf(value.u)
	out << leaf(value.truth)
	return out
}

fn leaves[T](value T) []u8 {
	mut out := []u8{}
	$if T.unaliased_typ is Numbers {
		out << number_leaves(Numbers(value))
	} $else $if T.unaliased_typ is Sequences {
		out << value.bytes
		out << leaf(value.fixed[0])
		out << leaf(value.fixed[1])
	} $else $if T.unaliased_typ is Nested {
		out << number_leaves(value.child)
	} $else $if T.unaliased_typ is Tagged {
		out << leaf(value.tag)
		out << leaf(value.n)
	} $else $if T.unaliased_typ is Custom {
		out << leaf(value.n)
	}
	return out
}

fn operate[T](mut writer zigimg.WriteStream, value T, values []T, nested [][]T, shape int, options zigimg.FormatOptions, depth usize, format int) string {
	if shape == 0 {
		formats := ['', 'any']
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

	value := make[T](raw, payload)
	value_count := if observed_length == 0 { 1 } else { 3 }
	values := []T{len: value_count, init: value}
	nested := [values[..1], values[1..], []T{}]
	observed_elements = []u8{}
	for item in values {
		observed_elements << leaves(item)
	}
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
		0 { typed_record[Empty](line, path) }
		1 { typed_record[Numbers](line, path) }
		2 { typed_record[Sequences](line, path) }
		3 { typed_record[Nested](line, path) }
		4 { typed_record[Tagged](line, path) }
		5 { typed_record[Custom](line, path) }
		6 { typed_record[AliasEmpty](line, path) }
		7 { typed_record[AliasNumbers](line, path) }
		8 { typed_record[AliasSequences](line, path) }
		9 { typed_record[AliasNested](line, path) }
		10 { typed_record[AliasTagged](line, path) }
		11 { typed_record[AliasCustom](line, path) }
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
