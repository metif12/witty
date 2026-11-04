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

type Slice0 = []u8
type Ref0 = &Slice0
type Slice1 = []int
type Ref1 = &Slice1

fn operate(mut writer zigimg.WriteStream, f []string) ! {
	raw := usize(f[8].u64())
	format := (hex.decode(f[1])!).bytestr()
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
	seen = '${raw}'
	match f[0].int() {
		0 {
			match f[12].int() {
				0 {
					value := unsafe { &[]u8(voidptr(raw)) }
					if format == 'addr' {
						writer.print_address(value)!
					} else {
						writer.print_value(format, options, value, depth)!
					}
				}
				1 {
					mut value := $zero(&Slice0)
					unsafe { vmemcpy(&value, &raw, int(sizeof(usize))) }
					if format == 'addr' {
						writer.print_address(value)!
					} else {
						writer.print_value(format, options, value, depth)!
					}
				}
				2 {
					value := unsafe { Ref0(voidptr(raw)) }
					if format == 'addr' {
						writer.print_address(value)!
					} else {
						writer.print_value(format, options, value, depth)!
					}
				}
				3 {
					value := ?&[]u8(unsafe { &[]u8(voidptr(raw)) })
					if format == 'addr' {
						writer.print_address(value)!
					} else {
						writer.print_value(format, options, value, depth)!
					}
				}
				4 {
					value := ?&[]u8(none)
					if format == 'addr' {
						writer.print_address(value)!
					} else {
						writer.print_value(format, options, value, depth)!
					}
				}
				5 {
					value := ?Ref0(unsafe { Ref0(voidptr(raw)) })
					if format == 'addr' {
						writer.print_address(value)!
					} else {
						writer.print_value(format, options, value, depth)!
					}
				}
				6 {
					value := ?Ref0(none)
					if format == 'addr' {
						writer.print_address(value)!
					} else {
						writer.print_value(format, options, value, depth)!
					}
				}
				else { panic('invalid carrier') }
			}
		}
		1 {
			match f[12].int() {
				0 {
					value := unsafe { &[]int(voidptr(raw)) }
					if format == 'addr' {
						writer.print_address(value)!
					} else {
						writer.print_value(format, options, value, depth)!
					}
				}
				1 {
					mut value := $zero(&Slice1)
					unsafe { vmemcpy(&value, &raw, int(sizeof(usize))) }
					if format == 'addr' {
						writer.print_address(value)!
					} else {
						writer.print_value(format, options, value, depth)!
					}
				}
				2 {
					value := unsafe { Ref1(voidptr(raw)) }
					if format == 'addr' {
						writer.print_address(value)!
					} else {
						writer.print_value(format, options, value, depth)!
					}
				}
				3 {
					value := ?&[]int(unsafe { &[]int(voidptr(raw)) })
					if format == 'addr' {
						writer.print_address(value)!
					} else {
						writer.print_value(format, options, value, depth)!
					}
				}
				4 {
					value := ?&[]int(none)
					if format == 'addr' {
						writer.print_address(value)!
					} else {
						writer.print_value(format, options, value, depth)!
					}
				}
				5 {
					value := ?Ref1(unsafe { Ref1(voidptr(raw)) })
					if format == 'addr' {
						writer.print_address(value)!
					} else {
						writer.print_value(format, options, value, depth)!
					}
				}
				6 {
					value := ?Ref1(none)
					if format == 'addr' {
						writer.print_address(value)!
					} else {
						writer.print_value(format, options, value, depth)!
					}
				}
				else { panic('invalid carrier') }
			}
		}
		else { panic('invalid family') }
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
