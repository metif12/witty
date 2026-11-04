module main

import encoding.hex
import os
import zigimg

#flag -I @DIR
#include "fixture_shims.h"

fn C.witty_writer_seek_setup(&char) int
fn C.witty_writer_seek_replace(int) int
fn C.witty_writer_seek_restore(&char, usize) int
fn C.witty_writer_seek_close() int
fn C.witty_writer_seek_cleanup() int
fn C.witty_writer_seek_valid() int
fn C.witty_writer_seek_view(&u8, usize) isize
fn C.witty_writer_seek_drain(&u8, usize) isize

__global (
	seen string
)

type Word0 = u8
type Array0 = [3]Word0
type Word1 = u16
type Array1 = [3]Word1
type Word2 = u32
type Array2 = [3]Word2
type Word3 = u64
type Array3 = [3]Word3
type Word4 = usize
type Array4 = [3]Word4
type Word5 = i8
type Array5 = [3]Word5
type Word6 = i16
type Array6 = [3]Word6
type Word7 = int
type Array7 = [3]Word7
type Word8 = i64
type Array8 = [3]Word8
type Word9 = isize
type Array9 = [3]Word9
type Word10 = f32
type Array10 = [3]Word10
type Word11 = f64
type Array11 = [3]Word11
type Word12 = bool
type Array12 = [3]Word12

fn operate(mut writer zigimg.WriteStream, f []string) ! {
	format := (hex.decode(f[1])!).bytestr()
	raw := usize(f[8].u64())
	options := zigimg.FormatOptions{
		width:     if f[10] == '-' {
			?usize(none)
		} else {
			?usize(usize(f[10].u64()))
		}
		precision: if f[11] == '-' { ?usize(none) } else { ?usize(usize(f[11].u64())) }
		alignment: unsafe { zigimg.Alignment(f[14].int()) }
		fill:      u8(f[15].int())
	}
	depth := usize(f[13].u64())
	seen = raw.str()
	match f[0].int() {
		0 {
			match f[12].int() {
				0 { writer.print_value(format, options, unsafe { &[3]u8(voidptr(raw)) }, depth)! }
				1 { writer.print_value(format, options, unsafe { &Array0(voidptr(raw)) }, depth)! }
				2 {
					writer.print_value(format, options, unsafe { &[2][3]u8(voidptr(raw)) }, depth)!
				}
				3 { writer.print_value(format, options, unsafe { &[1]u8(voidptr(raw)) }, depth)! }
				else { panic('invalid form') }
			}
		}
		1 {
			match f[12].int() {
				0 { writer.print_value(format, options, unsafe { &[3]u16(voidptr(raw)) }, depth)! }
				1 { writer.print_value(format, options, unsafe { &Array1(voidptr(raw)) }, depth)! }
				2 {
					writer.print_value(format, options, unsafe { &[2][3]u16(voidptr(raw)) }, depth)!
				}
				3 { writer.print_value(format, options, unsafe { &[1]u16(voidptr(raw)) }, depth)! }
				else { panic('invalid form') }
			}
		}
		2 {
			match f[12].int() {
				0 { writer.print_value(format, options, unsafe { &[3]u32(voidptr(raw)) }, depth)! }
				1 { writer.print_value(format, options, unsafe { &Array2(voidptr(raw)) }, depth)! }
				2 {
					writer.print_value(format, options, unsafe { &[2][3]u32(voidptr(raw)) }, depth)!
				}
				3 { writer.print_value(format, options, unsafe { &[1]u32(voidptr(raw)) }, depth)! }
				else { panic('invalid form') }
			}
		}
		3 {
			match f[12].int() {
				0 { writer.print_value(format, options, unsafe { &[3]u64(voidptr(raw)) }, depth)! }
				1 { writer.print_value(format, options, unsafe { &Array3(voidptr(raw)) }, depth)! }
				2 {
					writer.print_value(format, options, unsafe { &[2][3]u64(voidptr(raw)) }, depth)!
				}
				3 { writer.print_value(format, options, unsafe { &[1]u64(voidptr(raw)) }, depth)! }
				else { panic('invalid form') }
			}
		}
		4 {
			match f[12].int() {
				0 {
					writer.print_value(format, options, unsafe { &[3]usize(voidptr(raw)) }, depth)!
				}
				1 { writer.print_value(format, options, unsafe { &Array4(voidptr(raw)) }, depth)! }
				2 {
					writer.print_value(format, options, unsafe { &[2][3]usize(voidptr(raw)) }, depth)!
				}
				3 {
					writer.print_value(format, options, unsafe { &[1]usize(voidptr(raw)) }, depth)!
				}
				else { panic('invalid form') }
			}
		}
		5 {
			match f[12].int() {
				0 { writer.print_value(format, options, unsafe { &[3]i8(voidptr(raw)) }, depth)! }
				1 { writer.print_value(format, options, unsafe { &Array5(voidptr(raw)) }, depth)! }
				2 {
					writer.print_value(format, options, unsafe { &[2][3]i8(voidptr(raw)) }, depth)!
				}
				3 { writer.print_value(format, options, unsafe { &[1]i8(voidptr(raw)) }, depth)! }
				else { panic('invalid form') }
			}
		}
		6 {
			match f[12].int() {
				0 { writer.print_value(format, options, unsafe { &[3]i16(voidptr(raw)) }, depth)! }
				1 { writer.print_value(format, options, unsafe { &Array6(voidptr(raw)) }, depth)! }
				2 {
					writer.print_value(format, options, unsafe { &[2][3]i16(voidptr(raw)) }, depth)!
				}
				3 { writer.print_value(format, options, unsafe { &[1]i16(voidptr(raw)) }, depth)! }
				else { panic('invalid form') }
			}
		}
		7 {
			match f[12].int() {
				0 { writer.print_value(format, options, unsafe { &[3]int(voidptr(raw)) }, depth)! }
				1 { writer.print_value(format, options, unsafe { &Array7(voidptr(raw)) }, depth)! }
				2 {
					writer.print_value(format, options, unsafe { &[2][3]int(voidptr(raw)) }, depth)!
				}
				3 { writer.print_value(format, options, unsafe { &[1]int(voidptr(raw)) }, depth)! }
				else { panic('invalid form') }
			}
		}
		8 {
			match f[12].int() {
				0 { writer.print_value(format, options, unsafe { &[3]i64(voidptr(raw)) }, depth)! }
				1 { writer.print_value(format, options, unsafe { &Array8(voidptr(raw)) }, depth)! }
				2 {
					writer.print_value(format, options, unsafe { &[2][3]i64(voidptr(raw)) }, depth)!
				}
				3 { writer.print_value(format, options, unsafe { &[1]i64(voidptr(raw)) }, depth)! }
				else { panic('invalid form') }
			}
		}
		9 {
			match f[12].int() {
				0 {
					writer.print_value(format, options, unsafe { &[3]isize(voidptr(raw)) }, depth)!
				}
				1 { writer.print_value(format, options, unsafe { &Array9(voidptr(raw)) }, depth)! }
				2 {
					writer.print_value(format, options, unsafe { &[2][3]isize(voidptr(raw)) }, depth)!
				}
				3 {
					writer.print_value(format, options, unsafe { &[1]isize(voidptr(raw)) }, depth)!
				}
				else { panic('invalid form') }
			}
		}
		10 {
			match f[12].int() {
				0 { writer.print_value(format, options, unsafe { &[3]f32(voidptr(raw)) }, depth)! }
				1 { writer.print_value(format, options, unsafe { &Array10(voidptr(raw)) }, depth)! }
				2 {
					writer.print_value(format, options, unsafe { &[2][3]f32(voidptr(raw)) }, depth)!
				}
				3 { writer.print_value(format, options, unsafe { &[1]f32(voidptr(raw)) }, depth)! }
				else { panic('invalid form') }
			}
		}
		11 {
			match f[12].int() {
				0 { writer.print_value(format, options, unsafe { &[3]f64(voidptr(raw)) }, depth)! }
				1 { writer.print_value(format, options, unsafe { &Array11(voidptr(raw)) }, depth)! }
				2 {
					writer.print_value(format, options, unsafe { &[2][3]f64(voidptr(raw)) }, depth)!
				}
				3 { writer.print_value(format, options, unsafe { &[1]f64(voidptr(raw)) }, depth)! }
				else { panic('invalid form') }
			}
		}
		12 {
			match f[12].int() {
				0 { writer.print_value(format, options, unsafe { &[3]bool(voidptr(raw)) }, depth)! }
				1 { writer.print_value(format, options, unsafe { &Array12(voidptr(raw)) }, depth)! }
				2 {
					writer.print_value(format, options, unsafe { &[2][3]bool(voidptr(raw)) }, depth)!
				}
				3 { writer.print_value(format, options, unsafe { &[1]bool(voidptr(raw)) }, depth)! }
				else { panic('invalid form') }
			}
		}
		else { panic('invalid type') }
	}
}

fn snapshot(status string, writer zigimg.WriteStream, buffer []u8, file bool) string {
	mut contents := []u8{len: 4096}
	n := if file { C.witty_writer_seek_view(contents.data, usize(contents.len)) } else { isize(0) }
	if n < 0 { panic('observer failed') }
	valid := if file { C.witty_writer_seek_valid() } else { 0 }
	unused := writer.unused_capacity_slice()
	offset := if buffer.len == 0 { usize(0) } else { usize(unused.data) - usize(buffer.data) }
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
	mut drain := isize(-3)
	mut wire := []u8{}
	if kind > 0 && binding == 1 {
		for {
			mut bytes := []u8{len: 4096}
			drain = C.witty_writer_seek_drain(bytes.data, usize(bytes.len))
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
