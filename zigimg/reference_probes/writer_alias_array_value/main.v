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

type Word0 = u8
type Pointer0 = &Word0
type Word1 = u16
type Pointer1 = &Word1
type Word2 = u32
type Pointer2 = &Word2
type Word3 = u64
type Pointer3 = &Word3
type Word4 = uint
type Pointer4 = &Word4
type Word5 = i8
type Pointer5 = &Word5
type Word6 = i16
type Pointer6 = &Word6
type Word7 = int
type Pointer7 = &Word7
type Word8 = i64
type Pointer8 = &Word8
type Word9 = int
type Pointer9 = &Word9
type Word10 = f32
type Pointer10 = &Word10
type Word11 = f64
type Pointer11 = &Word11
type Word12 = bool
type Pointer12 = &Word12

type Pointer13 = voidptr

fn operate(mut writer zigimg.WriteStream, f []string) ! {
	raw := uint(f[8].u64())
	other := raw ^ uint(0x444c)
	options := zigimg.FormatOptions{ width: if f[10] == '-' {
		?uint(none)
	} else {
		?uint(uint(f[10].u64()))
	}, precision: if f[11] == '-' { ?uint(none) } else { ?uint(uint(f[11].u64())) }, alignment: unsafe { zigimg.Alignment(f[14].int()) }, fill: u8(f[15].int()) }
	depth := uint(f[13].u64())
	seen = '${raw}:${other}:2'
	match f[0].int() {
		0 {
			p := unsafe { &Word0(voidptr(raw)) }
			q := unsafe { &Word0(voidptr(other)) }
			value := [p, q]!
			match f[12].int() {
				0 { writer.print_value('any', options, value, depth)! }
				1 {
					aliases := [Pointer0(p), Pointer0(q)]!
					writer.print_value('any', options, aliases, depth)!
				}
				2 {
					nested := [value, value]!
					writer.print_value('any', options, nested, depth)!
				}
				3 { writer.print_value('any', options, &value, depth)! }
				4 { writer.print_value('any', options, value[..], depth)! }
				5 {
					plain := [unsafe { &u8(voidptr(raw)) }, unsafe { &u8(voidptr(other)) }]!
					writer.print_value('any', options, plain, depth)!
				}
				else { panic('invalid shape') }
			}
		}
		1 {
			p := unsafe { &Word1(voidptr(raw)) }
			q := unsafe { &Word1(voidptr(other)) }
			value := [p, q]!
			match f[12].int() {
				0 { writer.print_value('any', options, value, depth)! }
				1 {
					aliases := [Pointer1(p), Pointer1(q)]!
					writer.print_value('any', options, aliases, depth)!
				}
				2 {
					nested := [value, value]!
					writer.print_value('any', options, nested, depth)!
				}
				3 { writer.print_value('any', options, &value, depth)! }
				4 { writer.print_value('any', options, value[..], depth)! }
				5 {
					plain := [unsafe { &u16(voidptr(raw)) }, unsafe { &u16(voidptr(other)) }]!
					writer.print_value('any', options, plain, depth)!
				}
				else { panic('invalid shape') }
			}
		}
		2 {
			p := unsafe { &Word2(voidptr(raw)) }
			q := unsafe { &Word2(voidptr(other)) }
			value := [p, q]!
			match f[12].int() {
				0 { writer.print_value('any', options, value, depth)! }
				1 {
					aliases := [Pointer2(p), Pointer2(q)]!
					writer.print_value('any', options, aliases, depth)!
				}
				2 {
					nested := [value, value]!
					writer.print_value('any', options, nested, depth)!
				}
				3 { writer.print_value('any', options, &value, depth)! }
				4 { writer.print_value('any', options, value[..], depth)! }
				5 {
					plain := [unsafe { &u32(voidptr(raw)) }, unsafe { &u32(voidptr(other)) }]!
					writer.print_value('any', options, plain, depth)!
				}
				else { panic('invalid shape') }
			}
		}
		3 {
			p := unsafe { &Word3(voidptr(raw)) }
			q := unsafe { &Word3(voidptr(other)) }
			value := [p, q]!
			match f[12].int() {
				0 { writer.print_value('any', options, value, depth)! }
				1 {
					aliases := [Pointer3(p), Pointer3(q)]!
					writer.print_value('any', options, aliases, depth)!
				}
				2 {
					nested := [value, value]!
					writer.print_value('any', options, nested, depth)!
				}
				3 { writer.print_value('any', options, &value, depth)! }
				4 { writer.print_value('any', options, value[..], depth)! }
				5 {
					plain := [unsafe { &u64(voidptr(raw)) }, unsafe { &u64(voidptr(other)) }]!
					writer.print_value('any', options, plain, depth)!
				}
				else { panic('invalid shape') }
			}
		}
		4 {
			p := unsafe { &Word4(voidptr(raw)) }
			q := unsafe { &Word4(voidptr(other)) }
			value := [p, q]!
			match f[12].int() {
				0 { writer.print_value('any', options, value, depth)! }
				1 {
					aliases := [Pointer4(p), Pointer4(q)]!
					writer.print_value('any', options, aliases, depth)!
				}
				2 {
					nested := [value, value]!
					writer.print_value('any', options, nested, depth)!
				}
				3 { writer.print_value('any', options, &value, depth)! }
				4 { writer.print_value('any', options, value[..], depth)! }
				5 {
					plain := [unsafe { &uint(voidptr(raw)) }, unsafe { &uint(voidptr(other)) }]!
					writer.print_value('any', options, plain, depth)!
				}
				else { panic('invalid shape') }
			}
		}
		5 {
			p := unsafe { &Word5(voidptr(raw)) }
			q := unsafe { &Word5(voidptr(other)) }
			value := [p, q]!
			match f[12].int() {
				0 { writer.print_value('any', options, value, depth)! }
				1 {
					aliases := [Pointer5(p), Pointer5(q)]!
					writer.print_value('any', options, aliases, depth)!
				}
				2 {
					nested := [value, value]!
					writer.print_value('any', options, nested, depth)!
				}
				3 { writer.print_value('any', options, &value, depth)! }
				4 { writer.print_value('any', options, value[..], depth)! }
				5 {
					plain := [unsafe { &i8(voidptr(raw)) }, unsafe { &i8(voidptr(other)) }]!
					writer.print_value('any', options, plain, depth)!
				}
				else { panic('invalid shape') }
			}
		}
		6 {
			p := unsafe { &Word6(voidptr(raw)) }
			q := unsafe { &Word6(voidptr(other)) }
			value := [p, q]!
			match f[12].int() {
				0 { writer.print_value('any', options, value, depth)! }
				1 {
					aliases := [Pointer6(p), Pointer6(q)]!
					writer.print_value('any', options, aliases, depth)!
				}
				2 {
					nested := [value, value]!
					writer.print_value('any', options, nested, depth)!
				}
				3 { writer.print_value('any', options, &value, depth)! }
				4 { writer.print_value('any', options, value[..], depth)! }
				5 {
					plain := [unsafe { &i16(voidptr(raw)) }, unsafe { &i16(voidptr(other)) }]!
					writer.print_value('any', options, plain, depth)!
				}
				else { panic('invalid shape') }
			}
		}
		7 {
			p := unsafe { &Word7(voidptr(raw)) }
			q := unsafe { &Word7(voidptr(other)) }
			value := [p, q]!
			match f[12].int() {
				0 { writer.print_value('any', options, value, depth)! }
				1 {
					aliases := [Pointer7(p), Pointer7(q)]!
					writer.print_value('any', options, aliases, depth)!
				}
				2 {
					nested := [value, value]!
					writer.print_value('any', options, nested, depth)!
				}
				3 { writer.print_value('any', options, &value, depth)! }
				4 { writer.print_value('any', options, value[..], depth)! }
				5 {
					plain := [unsafe { &int(voidptr(raw)) }, unsafe { &int(voidptr(other)) }]!
					writer.print_value('any', options, plain, depth)!
				}
				else { panic('invalid shape') }
			}
		}
		8 {
			p := unsafe { &Word8(voidptr(raw)) }
			q := unsafe { &Word8(voidptr(other)) }
			value := [p, q]!
			match f[12].int() {
				0 { writer.print_value('any', options, value, depth)! }
				1 {
					aliases := [Pointer8(p), Pointer8(q)]!
					writer.print_value('any', options, aliases, depth)!
				}
				2 {
					nested := [value, value]!
					writer.print_value('any', options, nested, depth)!
				}
				3 { writer.print_value('any', options, &value, depth)! }
				4 { writer.print_value('any', options, value[..], depth)! }
				5 {
					plain := [unsafe { &i64(voidptr(raw)) }, unsafe { &i64(voidptr(other)) }]!
					writer.print_value('any', options, plain, depth)!
				}
				else { panic('invalid shape') }
			}
		}
		9 {
			p := unsafe { &Word9(voidptr(raw)) }
			q := unsafe { &Word9(voidptr(other)) }
			value := [p, q]!
			match f[12].int() {
				0 { writer.print_value('any', options, value, depth)! }
				1 {
					aliases := [Pointer9(p), Pointer9(q)]!
					writer.print_value('any', options, aliases, depth)!
				}
				2 {
					nested := [value, value]!
					writer.print_value('any', options, nested, depth)!
				}
				3 { writer.print_value('any', options, &value, depth)! }
				4 { writer.print_value('any', options, value[..], depth)! }
				5 {
					plain := [unsafe { &int(voidptr(raw)) }, unsafe { &int(voidptr(other)) }]!
					writer.print_value('any', options, plain, depth)!
				}
				else { panic('invalid shape') }
			}
		}
		10 {
			p := unsafe { &Word10(voidptr(raw)) }
			q := unsafe { &Word10(voidptr(other)) }
			value := [p, q]!
			match f[12].int() {
				0 { writer.print_value('any', options, value, depth)! }
				1 {
					aliases := [Pointer10(p), Pointer10(q)]!
					writer.print_value('any', options, aliases, depth)!
				}
				2 {
					nested := [value, value]!
					writer.print_value('any', options, nested, depth)!
				}
				3 { writer.print_value('any', options, &value, depth)! }
				4 { writer.print_value('any', options, value[..], depth)! }
				5 {
					plain := [unsafe { &f32(voidptr(raw)) }, unsafe { &f32(voidptr(other)) }]!
					writer.print_value('any', options, plain, depth)!
				}
				else { panic('invalid shape') }
			}
		}
		11 {
			p := unsafe { &Word11(voidptr(raw)) }
			q := unsafe { &Word11(voidptr(other)) }
			value := [p, q]!
			match f[12].int() {
				0 { writer.print_value('any', options, value, depth)! }
				1 {
					aliases := [Pointer11(p), Pointer11(q)]!
					writer.print_value('any', options, aliases, depth)!
				}
				2 {
					nested := [value, value]!
					writer.print_value('any', options, nested, depth)!
				}
				3 { writer.print_value('any', options, &value, depth)! }
				4 { writer.print_value('any', options, value[..], depth)! }
				5 {
					plain := [unsafe { &f64(voidptr(raw)) }, unsafe { &f64(voidptr(other)) }]!
					writer.print_value('any', options, plain, depth)!
				}
				else { panic('invalid shape') }
			}
		}
		12 {
			p := unsafe { &Word12(voidptr(raw)) }
			q := unsafe { &Word12(voidptr(other)) }
			value := [p, q]!
			match f[12].int() {
				0 { writer.print_value('any', options, value, depth)! }
				1 {
					aliases := [Pointer12(p), Pointer12(q)]!
					writer.print_value('any', options, aliases, depth)!
				}
				2 {
					nested := [value, value]!
					writer.print_value('any', options, nested, depth)!
				}
				3 { writer.print_value('any', options, &value, depth)! }
				4 { writer.print_value('any', options, value[..], depth)! }
				5 {
					plain := [unsafe { &bool(voidptr(raw)) }, unsafe { &bool(voidptr(other)) }]!
					writer.print_value('any', options, plain, depth)!
				}
				else { panic('invalid shape') }
			}
		}
		13 {
			p := voidptr(raw)
			q := voidptr(other)
			value := [p, q]!
			match f[12].int() {
				0 { writer.print_value('any', options, value, depth)! }
				1 {
					aliases := [Pointer13(p), Pointer13(q)]!
					writer.print_value('any', options, aliases, depth)!
				}
				2 {
					nested := [value, value]!
					writer.print_value('any', options, nested, depth)!
				}
				3 { writer.print_value('any', options, &value, depth)! }
				4 { writer.print_value('any', options, value[..], depth)! }
				5 {
					plain := [voidptr(raw), voidptr(other)]!
					writer.print_value('any', options, plain, depth)!
				}
				else { panic('invalid shape') }
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
