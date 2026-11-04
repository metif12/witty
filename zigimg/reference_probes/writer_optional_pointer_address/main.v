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

type Element0 = &u8
type Slice0 = []?Element0
type Array0 = [2]?Element0
type Element1 = &u16
type Slice1 = []?Element1
type Array1 = [2]?Element1
type Element2 = &u32
type Slice2 = []?Element2
type Array2 = [2]?Element2
type Element3 = &u64
type Slice3 = []?Element3
type Array3 = [2]?Element3
type Element4 = &usize
type Slice4 = []?Element4
type Array4 = [2]?Element4
type Element5 = &i8
type Slice5 = []?Element5
type Array5 = [2]?Element5
type Element6 = &i16
type Slice6 = []?Element6
type Array6 = [2]?Element6
type Element7 = &int
type Slice7 = []?Element7
type Array7 = [2]?Element7
type Element8 = &i64
type Slice8 = []?Element8
type Array8 = [2]?Element8
type Element9 = &isize
type Slice9 = []?Element9
type Array9 = [2]?Element9
type Element10 = &f32
type Slice10 = []?Element10
type Array10 = [2]?Element10
type Element11 = &f64
type Slice11 = []?Element11
type Array11 = [2]?Element11
type Element12 = &bool
type Slice12 = []?Element12
type Array12 = [2]?Element12
type Element13 = voidptr
type Slice13 = []?Element13
type Array13 = [2]?Element13

fn borrowed[E](_ E, raw usize, length int) []E {
	return unsafe { array{ data: voidptr(raw), len: length, cap: length, flags: .nofree, element_size: int(sizeof(E)) } }
}

fn operate(mut writer zigimg.WriteStream, f []string) ! {
	raw := usize(f[8].u64())
	length := f[9].int()
	api := (hex.decode(f[1])!).bytestr()
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
			zero := ?&u8(none)
			view := borrowed(zero, raw, length)
			seen = '${usize(view.data)}:${view.len}'
			if api == 'ds' {
				writer.print_address(view)!
			} else if api == 'os' {
				alias_view := Slice0(view)
				writer.print_value('?*', options, ?Slice0(alias_view), depth)!
			} else {
				writer.print_value('*', options, view, depth)!
			}
		}
		1 {
			zero := ?&u16(none)
			view := borrowed(zero, raw, length)
			seen = '${usize(view.data)}:${view.len}'
			if api == 'ds' {
				writer.print_address(view)!
			} else if api == 'os' {
				alias_view := Slice1(view)
				writer.print_value('?*', options, ?Slice1(alias_view), depth)!
			} else {
				writer.print_value('*', options, view, depth)!
			}
		}
		2 {
			zero := ?&u32(none)
			view := borrowed(zero, raw, length)
			seen = '${usize(view.data)}:${view.len}'
			if api == 'ds' {
				writer.print_address(view)!
			} else if api == 'os' {
				alias_view := Slice2(view)
				writer.print_value('?*', options, ?Slice2(alias_view), depth)!
			} else {
				writer.print_value('*', options, view, depth)!
			}
		}
		3 {
			zero := ?&u64(none)
			view := borrowed(zero, raw, length)
			seen = '${usize(view.data)}:${view.len}'
			if api == 'ds' {
				writer.print_address(view)!
			} else if api == 'os' {
				alias_view := Slice3(view)
				writer.print_value('?*', options, ?Slice3(alias_view), depth)!
			} else {
				writer.print_value('*', options, view, depth)!
			}
		}
		4 {
			zero := ?&usize(none)
			view := borrowed(zero, raw, length)
			seen = '${usize(view.data)}:${view.len}'
			if api == 'ds' {
				writer.print_address(view)!
			} else if api == 'os' {
				alias_view := Slice4(view)
				writer.print_value('?*', options, ?Slice4(alias_view), depth)!
			} else {
				writer.print_value('*', options, view, depth)!
			}
		}
		5 {
			zero := ?&i8(none)
			view := borrowed(zero, raw, length)
			seen = '${usize(view.data)}:${view.len}'
			if api == 'ds' {
				writer.print_address(view)!
			} else if api == 'os' {
				alias_view := Slice5(view)
				writer.print_value('?*', options, ?Slice5(alias_view), depth)!
			} else {
				writer.print_value('*', options, view, depth)!
			}
		}
		6 {
			zero := ?&i16(none)
			view := borrowed(zero, raw, length)
			seen = '${usize(view.data)}:${view.len}'
			if api == 'ds' {
				writer.print_address(view)!
			} else if api == 'os' {
				alias_view := Slice6(view)
				writer.print_value('?*', options, ?Slice6(alias_view), depth)!
			} else {
				writer.print_value('*', options, view, depth)!
			}
		}
		7 {
			zero := ?&int(none)
			view := borrowed(zero, raw, length)
			seen = '${usize(view.data)}:${view.len}'
			if api == 'ds' {
				writer.print_address(view)!
			} else if api == 'os' {
				alias_view := Slice7(view)
				writer.print_value('?*', options, ?Slice7(alias_view), depth)!
			} else {
				writer.print_value('*', options, view, depth)!
			}
		}
		8 {
			zero := ?&i64(none)
			view := borrowed(zero, raw, length)
			seen = '${usize(view.data)}:${view.len}'
			if api == 'ds' {
				writer.print_address(view)!
			} else if api == 'os' {
				alias_view := Slice8(view)
				writer.print_value('?*', options, ?Slice8(alias_view), depth)!
			} else {
				writer.print_value('*', options, view, depth)!
			}
		}
		9 {
			zero := ?&isize(none)
			view := borrowed(zero, raw, length)
			seen = '${usize(view.data)}:${view.len}'
			if api == 'ds' {
				writer.print_address(view)!
			} else if api == 'os' {
				alias_view := Slice9(view)
				writer.print_value('?*', options, ?Slice9(alias_view), depth)!
			} else {
				writer.print_value('*', options, view, depth)!
			}
		}
		10 {
			zero := ?&f32(none)
			view := borrowed(zero, raw, length)
			seen = '${usize(view.data)}:${view.len}'
			if api == 'ds' {
				writer.print_address(view)!
			} else if api == 'os' {
				alias_view := Slice10(view)
				writer.print_value('?*', options, ?Slice10(alias_view), depth)!
			} else {
				writer.print_value('*', options, view, depth)!
			}
		}
		11 {
			zero := ?&f64(none)
			view := borrowed(zero, raw, length)
			seen = '${usize(view.data)}:${view.len}'
			if api == 'ds' {
				writer.print_address(view)!
			} else if api == 'os' {
				alias_view := Slice11(view)
				writer.print_value('?*', options, ?Slice11(alias_view), depth)!
			} else {
				writer.print_value('*', options, view, depth)!
			}
		}
		12 {
			zero := ?&bool(none)
			view := borrowed(zero, raw, length)
			seen = '${usize(view.data)}:${view.len}'
			if api == 'ds' {
				writer.print_address(view)!
			} else if api == 'os' {
				alias_view := Slice12(view)
				writer.print_value('?*', options, ?Slice12(alias_view), depth)!
			} else {
				writer.print_value('*', options, view, depth)!
			}
		}
		13 {
			zero := ?voidptr(none)
			view := borrowed(zero, raw, length)
			seen = '${usize(view.data)}:${view.len}'
			if api == 'ds' {
				writer.print_address(view)!
			} else if api == 'os' {
				alias_view := Slice13(view)
				writer.print_value('?*', options, ?Slice13(alias_view), depth)!
			} else {
				writer.print_value('*', options, view, depth)!
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
