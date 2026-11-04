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
type Pointer0 = &Word0
type Word1 = u16
type Pointer1 = &Word1
type Word2 = u32
type Pointer2 = &Word2
type Word3 = u64
type Pointer3 = &Word3
type Word4 = usize
type Pointer4 = &Word4
type Word5 = i8
type Pointer5 = &Word5
type Word6 = i16
type Pointer6 = &Word6
type Word7 = int
type Pointer7 = &Word7
type Word8 = i64
type Pointer8 = &Word8
type Word9 = isize
type Pointer9 = &Word9
type Word10 = f32
type Pointer10 = &Word10
type Word11 = f64
type Pointer11 = &Word11
type Word12 = bool
type Pointer12 = &Word12

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
	match f[0].int() {
		0 {
			pointer := unsafe { &u8(voidptr(raw)) }
			alias_pointer := Pointer0(unsafe { &Word0(voidptr(raw)) })
			seen = '${usize(voidptr(pointer))}'
			match f[12].int() {
				0 { writer.print_value(format, options, pointer, depth)! }
				1 { writer.print_value(format, options, unsafe { &Word0(voidptr(raw)) }, depth)! }
				2 { writer.print_value(format, options, alias_pointer, depth)! }
				3 { writer.print_value(format, options, ?&u8(pointer), depth)! }
				4 {
					seen = '0'
					writer.print_value(format, options, ?&u8(none), depth)!
				}
				5 { writer.print_value(format, options, ?Pointer0(alias_pointer), depth)! }
				6 {
					seen = '0'
					writer.print_value(format, options, ?Pointer0(none), depth)!
				}
				else { panic('invalid form') }
			}
		}
		1 {
			pointer := unsafe { &u16(voidptr(raw)) }
			alias_pointer := Pointer1(unsafe { &Word1(voidptr(raw)) })
			seen = '${usize(voidptr(pointer))}'
			match f[12].int() {
				0 { writer.print_value(format, options, pointer, depth)! }
				1 { writer.print_value(format, options, unsafe { &Word1(voidptr(raw)) }, depth)! }
				2 { writer.print_value(format, options, alias_pointer, depth)! }
				3 { writer.print_value(format, options, ?&u16(pointer), depth)! }
				4 {
					seen = '0'
					writer.print_value(format, options, ?&u16(none), depth)!
				}
				5 { writer.print_value(format, options, ?Pointer1(alias_pointer), depth)! }
				6 {
					seen = '0'
					writer.print_value(format, options, ?Pointer1(none), depth)!
				}
				else { panic('invalid form') }
			}
		}
		2 {
			pointer := unsafe { &u32(voidptr(raw)) }
			alias_pointer := Pointer2(unsafe { &Word2(voidptr(raw)) })
			seen = '${usize(voidptr(pointer))}'
			match f[12].int() {
				0 { writer.print_value(format, options, pointer, depth)! }
				1 { writer.print_value(format, options, unsafe { &Word2(voidptr(raw)) }, depth)! }
				2 { writer.print_value(format, options, alias_pointer, depth)! }
				3 { writer.print_value(format, options, ?&u32(pointer), depth)! }
				4 {
					seen = '0'
					writer.print_value(format, options, ?&u32(none), depth)!
				}
				5 { writer.print_value(format, options, ?Pointer2(alias_pointer), depth)! }
				6 {
					seen = '0'
					writer.print_value(format, options, ?Pointer2(none), depth)!
				}
				else { panic('invalid form') }
			}
		}
		3 {
			pointer := unsafe { &u64(voidptr(raw)) }
			alias_pointer := Pointer3(unsafe { &Word3(voidptr(raw)) })
			seen = '${usize(voidptr(pointer))}'
			match f[12].int() {
				0 { writer.print_value(format, options, pointer, depth)! }
				1 { writer.print_value(format, options, unsafe { &Word3(voidptr(raw)) }, depth)! }
				2 { writer.print_value(format, options, alias_pointer, depth)! }
				3 { writer.print_value(format, options, ?&u64(pointer), depth)! }
				4 {
					seen = '0'
					writer.print_value(format, options, ?&u64(none), depth)!
				}
				5 { writer.print_value(format, options, ?Pointer3(alias_pointer), depth)! }
				6 {
					seen = '0'
					writer.print_value(format, options, ?Pointer3(none), depth)!
				}
				else { panic('invalid form') }
			}
		}
		4 {
			pointer := unsafe { &usize(voidptr(raw)) }
			alias_pointer := Pointer4(unsafe { &Word4(voidptr(raw)) })
			seen = '${usize(voidptr(pointer))}'
			match f[12].int() {
				0 { writer.print_value(format, options, pointer, depth)! }
				1 { writer.print_value(format, options, unsafe { &Word4(voidptr(raw)) }, depth)! }
				2 { writer.print_value(format, options, alias_pointer, depth)! }
				3 { writer.print_value(format, options, ?&usize(pointer), depth)! }
				4 {
					seen = '0'
					writer.print_value(format, options, ?&usize(none), depth)!
				}
				5 { writer.print_value(format, options, ?Pointer4(alias_pointer), depth)! }
				6 {
					seen = '0'
					writer.print_value(format, options, ?Pointer4(none), depth)!
				}
				else { panic('invalid form') }
			}
		}
		5 {
			pointer := unsafe { &i8(voidptr(raw)) }
			alias_pointer := Pointer5(unsafe { &Word5(voidptr(raw)) })
			seen = '${usize(voidptr(pointer))}'
			match f[12].int() {
				0 { writer.print_value(format, options, pointer, depth)! }
				1 { writer.print_value(format, options, unsafe { &Word5(voidptr(raw)) }, depth)! }
				2 { writer.print_value(format, options, alias_pointer, depth)! }
				3 { writer.print_value(format, options, ?&i8(pointer), depth)! }
				4 {
					seen = '0'
					writer.print_value(format, options, ?&i8(none), depth)!
				}
				5 { writer.print_value(format, options, ?Pointer5(alias_pointer), depth)! }
				6 {
					seen = '0'
					writer.print_value(format, options, ?Pointer5(none), depth)!
				}
				else { panic('invalid form') }
			}
		}
		6 {
			pointer := unsafe { &i16(voidptr(raw)) }
			alias_pointer := Pointer6(unsafe { &Word6(voidptr(raw)) })
			seen = '${usize(voidptr(pointer))}'
			match f[12].int() {
				0 { writer.print_value(format, options, pointer, depth)! }
				1 { writer.print_value(format, options, unsafe { &Word6(voidptr(raw)) }, depth)! }
				2 { writer.print_value(format, options, alias_pointer, depth)! }
				3 { writer.print_value(format, options, ?&i16(pointer), depth)! }
				4 {
					seen = '0'
					writer.print_value(format, options, ?&i16(none), depth)!
				}
				5 { writer.print_value(format, options, ?Pointer6(alias_pointer), depth)! }
				6 {
					seen = '0'
					writer.print_value(format, options, ?Pointer6(none), depth)!
				}
				else { panic('invalid form') }
			}
		}
		7 {
			pointer := unsafe { &int(voidptr(raw)) }
			alias_pointer := Pointer7(unsafe { &Word7(voidptr(raw)) })
			seen = '${usize(voidptr(pointer))}'
			match f[12].int() {
				0 { writer.print_value(format, options, pointer, depth)! }
				1 { writer.print_value(format, options, unsafe { &Word7(voidptr(raw)) }, depth)! }
				2 { writer.print_value(format, options, alias_pointer, depth)! }
				3 { writer.print_value(format, options, ?&int(pointer), depth)! }
				4 {
					seen = '0'
					writer.print_value(format, options, ?&int(none), depth)!
				}
				5 { writer.print_value(format, options, ?Pointer7(alias_pointer), depth)! }
				6 {
					seen = '0'
					writer.print_value(format, options, ?Pointer7(none), depth)!
				}
				else { panic('invalid form') }
			}
		}
		8 {
			pointer := unsafe { &i64(voidptr(raw)) }
			alias_pointer := Pointer8(unsafe { &Word8(voidptr(raw)) })
			seen = '${usize(voidptr(pointer))}'
			match f[12].int() {
				0 { writer.print_value(format, options, pointer, depth)! }
				1 { writer.print_value(format, options, unsafe { &Word8(voidptr(raw)) }, depth)! }
				2 { writer.print_value(format, options, alias_pointer, depth)! }
				3 { writer.print_value(format, options, ?&i64(pointer), depth)! }
				4 {
					seen = '0'
					writer.print_value(format, options, ?&i64(none), depth)!
				}
				5 { writer.print_value(format, options, ?Pointer8(alias_pointer), depth)! }
				6 {
					seen = '0'
					writer.print_value(format, options, ?Pointer8(none), depth)!
				}
				else { panic('invalid form') }
			}
		}
		9 {
			pointer := unsafe { &isize(voidptr(raw)) }
			alias_pointer := Pointer9(unsafe { &Word9(voidptr(raw)) })
			seen = '${usize(voidptr(pointer))}'
			match f[12].int() {
				0 { writer.print_value(format, options, pointer, depth)! }
				1 { writer.print_value(format, options, unsafe { &Word9(voidptr(raw)) }, depth)! }
				2 { writer.print_value(format, options, alias_pointer, depth)! }
				3 { writer.print_value(format, options, ?&isize(pointer), depth)! }
				4 {
					seen = '0'
					writer.print_value(format, options, ?&isize(none), depth)!
				}
				5 { writer.print_value(format, options, ?Pointer9(alias_pointer), depth)! }
				6 {
					seen = '0'
					writer.print_value(format, options, ?Pointer9(none), depth)!
				}
				else { panic('invalid form') }
			}
		}
		10 {
			pointer := unsafe { &f32(voidptr(raw)) }
			alias_pointer := Pointer10(unsafe { &Word10(voidptr(raw)) })
			seen = '${usize(voidptr(pointer))}'
			match f[12].int() {
				0 { writer.print_value(format, options, pointer, depth)! }
				1 { writer.print_value(format, options, unsafe { &Word10(voidptr(raw)) }, depth)! }
				2 { writer.print_value(format, options, alias_pointer, depth)! }
				3 { writer.print_value(format, options, ?&f32(pointer), depth)! }
				4 {
					seen = '0'
					writer.print_value(format, options, ?&f32(none), depth)!
				}
				5 { writer.print_value(format, options, ?Pointer10(alias_pointer), depth)! }
				6 {
					seen = '0'
					writer.print_value(format, options, ?Pointer10(none), depth)!
				}
				else { panic('invalid form') }
			}
		}
		11 {
			pointer := unsafe { &f64(voidptr(raw)) }
			alias_pointer := Pointer11(unsafe { &Word11(voidptr(raw)) })
			seen = '${usize(voidptr(pointer))}'
			match f[12].int() {
				0 { writer.print_value(format, options, pointer, depth)! }
				1 { writer.print_value(format, options, unsafe { &Word11(voidptr(raw)) }, depth)! }
				2 { writer.print_value(format, options, alias_pointer, depth)! }
				3 { writer.print_value(format, options, ?&f64(pointer), depth)! }
				4 {
					seen = '0'
					writer.print_value(format, options, ?&f64(none), depth)!
				}
				5 { writer.print_value(format, options, ?Pointer11(alias_pointer), depth)! }
				6 {
					seen = '0'
					writer.print_value(format, options, ?Pointer11(none), depth)!
				}
				else { panic('invalid form') }
			}
		}
		12 {
			pointer := unsafe { &bool(voidptr(raw)) }
			alias_pointer := Pointer12(unsafe { &Word12(voidptr(raw)) })
			seen = '${usize(voidptr(pointer))}'
			match f[12].int() {
				0 { writer.print_value(format, options, pointer, depth)! }
				1 { writer.print_value(format, options, unsafe { &Word12(voidptr(raw)) }, depth)! }
				2 { writer.print_value(format, options, alias_pointer, depth)! }
				3 { writer.print_value(format, options, ?&bool(pointer), depth)! }
				4 {
					seen = '0'
					writer.print_value(format, options, ?&bool(none), depth)!
				}
				5 { writer.print_value(format, options, ?Pointer12(alias_pointer), depth)! }
				6 {
					seen = '0'
					writer.print_value(format, options, ?Pointer12(none), depth)!
				}
				else { panic('invalid form') }
			}
		}
		13 {
			pointer := voidptr(raw)
			seen = '${usize(pointer)}'
			writer.print_value(format, options, pointer, depth)!
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
