module main

import encoding.hex
import os
import zigimg

#flag -I @DIR
#include "fixture_shims.h"

fn C.witty_writer_seek_setup(&char) int
fn C.witty_writer_seek_replace(int) int
fn C.witty_writer_seek_restore(&char, uint) int
fn C.witty_writer_seek_close() int
fn C.witty_writer_seek_cleanup() int
fn C.witty_writer_seek_valid() int
fn C.witty_writer_seek_view(&u8, uint) int
fn C.witty_writer_seek_drain(&u8, uint) int

__global (
	seen string
)

struct Record {
	value i64
	flag  bool
}

enum Choice as u8 {
	zero = 0
	high = 255
}

type Sum = Record | bool
type Outer = Sum | u64

struct Empty {}

struct Node {
	value i64
mut:
	next ?&Node
}

type RecordAlias = Record
type ChoiceAlias = Choice
type EmptyAlias = Empty
type NodeAlias = Node
type RecordPointer = &RecordAlias
type ChoicePointer = &ChoiceAlias
type EmptyPointer = &EmptyAlias
type NodePointer = &NodeAlias

fn record_seen(value Record) string { return '${u64(value.value)}:${int(value.flag)}' }

fn sum_seen(value Sum) string {
	return match value {
		Record { 'R' + record_seen(value) }
		bool { 'B${int(value)}' }
	}
}

fn outer_seen(value Outer) string {
	return match value {
		Sum { 'S' + sum_seen(value) }
		u64 { 'U${value}' }
	}
}

fn operate(mut writer zigimg.WriteStream, f []string) ! {
	format := (hex.decode(f[1])!).bytestr()
	raw := f[8].u64()
	options := zigimg.FormatOptions{
		width:     if f[10] == '-' {
			?uint(none)
		} else {
			?uint(uint(f[10].u64()))
		}
		precision: if f[11] == '-' { ?uint(none) } else { ?uint(uint(f[11].u64())) }
		alignment: unsafe { zigimg.Alignment(f[14].int()) }
		fill:      u8(f[15].int())
	}
	depth := uint(f[13].u64())
	match f[0].int() {
		0 {
			value := Record{i64(raw), raw & 1 != 0}
			seen = record_seen(value)
			defer { seen = record_seen(value) }
			alias_value := RecordAlias(value)
			alias_pointer := RecordPointer(&alias_value)
			match f[12].int() {
				0 { writer.print_value(format, options, &value, depth)! }
				1 { writer.print_value(format, options, &alias_value, depth)! }
				2 { writer.print_value(format, options, alias_pointer, depth)! }
				3 { writer.print_value(format, options, ?&Record(&value), depth)! }
				4 { writer.print_value(format, options, ?&Record(none), depth)! }
				5 { writer.print_value(format, options, ?RecordPointer(alias_pointer), depth)! }
				6 { writer.print_value(format, options, ?RecordPointer(none), depth)! }
				else { panic('invalid form') }
			}
		}
		1 {
			value := if raw & 1 != 0 { Choice.high } else { Choice.zero }
			seen = '${int(value)}'
			defer { seen = '${int(value)}' }
			alias_value := ChoiceAlias(value)
			alias_pointer := ChoicePointer(&alias_value)
			match f[12].int() {
				0 { writer.print_value(format, options, &value, depth)! }
				1 { writer.print_value(format, options, &alias_value, depth)! }
				2 { writer.print_value(format, options, alias_pointer, depth)! }
				3 { writer.print_value(format, options, ?&Choice(&value), depth)! }
				4 { writer.print_value(format, options, ?&Choice(none), depth)! }
				5 { writer.print_value(format, options, ?ChoicePointer(alias_pointer), depth)! }
				6 { writer.print_value(format, options, ?ChoicePointer(none), depth)! }
				else { panic('invalid form') }
			}
		}
		2 {
			inner := if raw & 2 != 0 {
				Sum(bool(raw & 4 != 0))
			} else {
				Sum(Record{i64(raw), raw & 1 != 0})
			}
			value := inner
			seen = sum_seen(value)
			defer { seen = sum_seen(value) }
			match f[12].int() {
				0 { writer.print_value(format, options, &value, depth)! }
				3 { writer.print_value(format, options, ?&Sum(&value), depth)! }
				4 { writer.print_value(format, options, ?&Sum(none), depth)! }
				else { panic('invalid form') }
			}
		}
		3 {
			inner := if raw & 2 != 0 {
				Sum(bool(raw & 4 != 0))
			} else {
				Sum(Record{i64(raw), raw & 1 != 0})
			}
			value := if raw & 1 != 0 { Outer(raw) } else { Outer(inner) }
			seen = outer_seen(value)
			defer { seen = outer_seen(value) }
			match f[12].int() {
				0 { writer.print_value(format, options, &value, depth)! }
				3 { writer.print_value(format, options, ?&Outer(&value), depth)! }
				4 { writer.print_value(format, options, ?&Outer(none), depth)! }
				else { panic('invalid form') }
			}
		}
		4 {
			value := Empty{}
			seen = 'empty'
			defer { seen = 'empty' }
			alias_value := EmptyAlias(value)
			alias_pointer := EmptyPointer(&alias_value)
			match f[12].int() {
				0 { writer.print_value(format, options, &value, depth)! }
				1 { writer.print_value(format, options, &alias_value, depth)! }
				2 { writer.print_value(format, options, alias_pointer, depth)! }
				3 { writer.print_value(format, options, ?&Empty(&value), depth)! }
				4 { writer.print_value(format, options, ?&Empty(none), depth)! }
				5 { writer.print_value(format, options, ?EmptyPointer(alias_pointer), depth)! }
				6 { writer.print_value(format, options, ?EmptyPointer(none), depth)! }
				else { panic('invalid form') }
			}
		}
		5 {
			mut value := Node{ value: i64(raw) }
			if raw & 1 != 0 { value.next = &value }
			seen = 'N${u64(value.value)}:${int(value.next != none)}'
			defer { seen = 'N${u64(value.value)}:${int(value.next != none)}' }
			alias_value := NodeAlias(value)
			alias_pointer := NodePointer(&alias_value)
			match f[12].int() {
				0 { writer.print_value(format, options, &value, depth)! }
				1 { writer.print_value(format, options, &alias_value, depth)! }
				2 { writer.print_value(format, options, alias_pointer, depth)! }
				3 { writer.print_value(format, options, ?&Node(&value), depth)! }
				4 { writer.print_value(format, options, ?&Node(none), depth)! }
				5 { writer.print_value(format, options, ?NodePointer(alias_pointer), depth)! }
				6 { writer.print_value(format, options, ?NodePointer(none), depth)! }
				else { panic('invalid form') }
			}
		}
		else { panic('invalid type') }
	}
}

fn snapshot(status string, writer zigimg.WriteStream, buffer []u8, file bool) string {
	mut contents := []u8{len: 4096}
	n := if file { C.witty_writer_seek_view(contents.data, uint(contents.len)) } else { int(0) }
	if n < 0 { panic('observer failed') }
	valid := if file { C.witty_writer_seek_valid() } else { 0 }
	unused := writer.unused_capacity_slice()
	offset := if buffer.len == 0 { uint(0) } else { uint(unused.data) - uint(buffer.data) }
	return '${status}|${writer.get_pos()}:${writer.unused_capacity_len()}:${writer.buffered().len}:${offset}:${valid}|${buffer.hex()}|${writer.buffered().hex()}|${unused.hex()}|${seen}|${contents[..int(n)].hex()}'
}

fn record(line string, path string) string {
	f := line.split('|')
	kind, cap, start, prefix, binding := f[2].int(), f[3].int(), f[4].u64(), f[5].int(), f[6].int()
	mut buffer := []u8{len: cap, init: u8(index * 17 + 165)}
	mut writer := zigimg.WriteStream.init_memory(mut buffer)
	if kind > 0 {
		fd := C.witty_writer_seek_setup(path.str)
		if fd < 0 || C.witty_writer_seek_restore((path + '.restored').str, 32) != 0 {
			panic('setup failed')
		}
		writer = if kind == 1 {
			zigimg.WriteStream.init_file(os.File{ fd: fd }, mut buffer)
		} else {
			zigimg.WriteStream.init_file_streaming(os.File{ fd: fd }, mut buffer)
		}
	}
	defer { if kind > 0 && C.witty_writer_seek_cleanup() != 0 { panic('cleanup failed') } }
	writer.seek_to(start) or {}
	writer.write_all([]u8{len: prefix, init: u8(index * 31 + 7)}) or { panic('prefix failed') }
	if kind > 0 {
		if binding == 1 && C.witty_writer_seek_replace(1) != 0 { panic('replace failed') }
		if binding == 2 && C.witty_writer_seek_close() != 0 { panic('close failed') }
	}
	seen = '-'
	mut out := snapshot('ready', writer, buffer, kind > 0) + '~'
	mut status := 'ok'
	mut adapter := writer.writer()
	operate(mut adapter, f) or { status = err.msg() }
	out += snapshot(status, writer, buffer, kind > 0) + '~'
	if buffer.len > 0 { buffer[0] ^= 0x5a }
	out += snapshot('caller', writer, buffer, kind > 0) + '~'
	status = 'skip'
	if f[7] == '1' {
		status = 'ok'
		writer.flush() or { status = err.msg() }
	}
	out += snapshot(status, writer, buffer, kind > 0) + '~'
	mut drain := int(-3)
	mut wire := []u8{}
	if kind > 0 && binding == 1 {
		for {
			mut bytes := []u8{len: 4096}
			drain = C.witty_writer_seek_drain(bytes.data, uint(bytes.len))
			if drain <= 0 { break }
			wire << bytes[..int(drain)]
		}
	}
	return out + '${drain}:${wire.hex()}'
}

fn main() {
	for i, line in (os.read_lines(os.args[1]) or { panic(err) }) {
		println(record(line, os.args[1] + '.${i}.owned'))
	}
}
