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
	calls int
)

__global (
	steps int
	seen  string
)

struct Hook {
	value i64
	data  []u8
	stop  int
}

type HookAlias = Hook

fn emit(value Hook, mut writer zigimg.WriteStream, label string) ! {
	calls++
	if value.stop == 1 { return error('WriteFailed') }
	writer.write_all(label.bytes())!
	steps = 1
	if value.stop == 2 { return error('WriteFailed') }
	writer.write_all('('.bytes())!
	steps = 2
	writer.print_value('d', zigimg.FormatOptions{}, value.value, 0)!
	steps = 3
	writer.write_all(':'.bytes())!
	steps = 4
	writer.write_all(value.data)!
	steps = 5
	if value.stop == 3 { return error('WriteFailed') }
	writer.write_all(')'.bytes())!
	steps = 6
}

pub fn (value Hook) format_number(mut writer zigimg.WriteStream, options zigimg.NumberFormat) ! {
	precision := if n := options.precision { '${n}' } else { '-' }
	width := if n := options.width { '${n}' } else { '-' }
	seen = 'N:${int(options.mode)}:${int(options.letter_case)}:${precision}:${width}:${int(options.alignment)}:${options.fill}'
	emit(value, mut writer, 'number')!
}

pub fn (value Hook) format_byte_size(mut writer zigimg.WriteStream, units zigimg.ByteSizeUnits) ! {
	seen = 'B:${int(units)}'
	emit(value, mut writer, 'bytes')!
}

pub fn (value Hook) format_duration(mut writer zigimg.WriteStream) ! {
	seen = 'D'
	emit(value, mut writer, 'duration')!
}

fn operate(mut writer zigimg.WriteStream, f []string) ! {
	format := (hex.decode(f[1])!).bytestr()
	value := Hook{f[8].i64(), hex.decode(f[9])!, f[12].int()}
	options := zigimg.FormatOptions{
		width:     if f[10] == '-' { ?uint(none) } else { ?uint(uint(f[10].u64())) }
		precision: if f[11] == '-' { ?uint(none) } else { ?uint(uint(f[11].u64())) }
		alignment: unsafe { zigimg.Alignment(f[14].int()) }
		fill:      u8(f[15].int())
	}
	depth := uint(f[13].u64())
	match f[0] {
		'0' { writer.print_value(format, options, value, depth)! }
		'1' { writer.print_value(format, options, HookAlias(value), depth)! }
		'2' { writer.print_value('?' + format, options, ?Hook(value), depth)! }
		'3' { writer.print_value('?' + format, options, ?Hook(none), depth)! }
		else { panic('invalid carrier') }
	}
}

fn snapshot(status string, writer zigimg.WriteStream, buffer []u8, file bool) string {
	mut contents := []u8{len: 4096}
	n := if file { C.witty_writer_seek_view(contents.data, uint(contents.len)) } else { int(0) }
	if n < 0 { panic('observer failed') }
	valid := if file { C.witty_writer_seek_valid() } else { 0 }
	unused := writer.unused_capacity_slice()
	offset := if buffer.len == 0 { uint(0) } else { uint(unused.data) - uint(buffer.data) }
	return '${status}|${writer.get_pos()}:${writer.unused_capacity_len()}:${writer.buffered().len}:${offset}:${valid}|${buffer.hex()}|${writer.buffered().hex()}|${unused.hex()}|${calls}:${steps}:${seen}|${contents[..int(n)].hex()}'
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
	calls = 0
	steps = 0
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
