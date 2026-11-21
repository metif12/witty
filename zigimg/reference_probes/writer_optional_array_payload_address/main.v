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

type Payload0_0 = [2]u8
type Slice0_0 = []?Payload0_0
type Payload0_1 = [2][3]u8
type Slice0_1 = []?Payload0_1
type Payload0_2 = [3]?u8
type Slice0_2 = []?Payload0_2
type Payload1_0 = [2]u16
type Slice1_0 = []?Payload1_0
type Payload1_1 = [2][3]u16
type Slice1_1 = []?Payload1_1
type Payload1_2 = [3]?u16
type Slice1_2 = []?Payload1_2
type Payload2_0 = [2]u32
type Slice2_0 = []?Payload2_0
type Payload2_1 = [2][3]u32
type Slice2_1 = []?Payload2_1
type Payload2_2 = [3]?u32
type Slice2_2 = []?Payload2_2
type Payload3_0 = [2]u64
type Slice3_0 = []?Payload3_0
type Payload3_1 = [2][3]u64
type Slice3_1 = []?Payload3_1
type Payload3_2 = [3]?u64
type Slice3_2 = []?Payload3_2
type Payload4_0 = [2]uint
type Slice4_0 = []?Payload4_0
type Payload4_1 = [2][3]uint
type Slice4_1 = []?Payload4_1
type Payload4_2 = [3]?uint
type Slice4_2 = []?Payload4_2
type Payload5_0 = [2]i8
type Slice5_0 = []?Payload5_0
type Payload5_1 = [2][3]i8
type Slice5_1 = []?Payload5_1
type Payload5_2 = [3]?i8
type Slice5_2 = []?Payload5_2
type Payload6_0 = [2]i16
type Slice6_0 = []?Payload6_0
type Payload6_1 = [2][3]i16
type Slice6_1 = []?Payload6_1
type Payload6_2 = [3]?i16
type Slice6_2 = []?Payload6_2
type Payload7_0 = [2]int
type Slice7_0 = []?Payload7_0
type Payload7_1 = [2][3]int
type Slice7_1 = []?Payload7_1
type Payload7_2 = [3]?int
type Slice7_2 = []?Payload7_2
type Payload8_0 = [2]i64
type Slice8_0 = []?Payload8_0
type Payload8_1 = [2][3]i64
type Slice8_1 = []?Payload8_1
type Payload8_2 = [3]?i64
type Slice8_2 = []?Payload8_2
type Payload9_0 = [2]int
type Slice9_0 = []?Payload9_0
type Payload9_1 = [2][3]int
type Slice9_1 = []?Payload9_1
type Payload9_2 = [3]?int
type Slice9_2 = []?Payload9_2
type Payload10_0 = [2]f32
type Slice10_0 = []?Payload10_0
type Payload10_1 = [2][3]f32
type Slice10_1 = []?Payload10_1
type Payload10_2 = [3]?f32
type Slice10_2 = []?Payload10_2
type Payload11_0 = [2]f64
type Slice11_0 = []?Payload11_0
type Payload11_1 = [2][3]f64
type Slice11_1 = []?Payload11_1
type Payload11_2 = [3]?f64
type Slice11_2 = []?Payload11_2
type Payload12_0 = [2]bool
type Slice12_0 = []?Payload12_0
type Payload12_1 = [2][3]bool
type Slice12_1 = []?Payload12_1
type Payload12_2 = [3]?bool
type Slice12_2 = []?Payload12_2

fn borrowed[E](_ E, raw uint, length int) []?E {
	return unsafe { array{ data: voidptr(raw), len: length, cap: length, flags: .nofree, element_size: int(sizeof(?E)) } }
}

fn operate(mut writer zigimg.WriteStream, f []string) ! {
	raw := uint(f[8].u64())
	length := f[9].int()
	api := (hex.decode(f[1])!).bytestr()
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
			match f[12].int() {
				0 {
					zero := Payload0_0{}
					view := borrowed(zero, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					if api == 'ds' {
						writer.print_address(view)!
					} else if api == 'os' {
						writer.print_value('?*', options, ?Slice0_0(view), depth)!
					} else {
						writer.print_value('*', options, view, depth)!
					}
				}
				1 {
					zero := Payload0_1{}
					view := borrowed(zero, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					if api == 'ds' {
						writer.print_address(view)!
					} else if api == 'os' {
						writer.print_value('?*', options, ?Slice0_1(view), depth)!
					} else {
						writer.print_value('*', options, view, depth)!
					}
				}
				2 {
					zero := Payload0_2{}
					view := borrowed(zero, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					if api != 'ds' { panic('unsupported optional-element value fixture') }
					writer.print_address(view)!
				}
				else { panic('invalid shape') }
			}
		}
		1 {
			match f[12].int() {
				0 {
					zero := Payload1_0{}
					view := borrowed(zero, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					if api == 'ds' {
						writer.print_address(view)!
					} else if api == 'os' {
						writer.print_value('?*', options, ?Slice1_0(view), depth)!
					} else {
						writer.print_value('*', options, view, depth)!
					}
				}
				1 {
					zero := Payload1_1{}
					view := borrowed(zero, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					if api == 'ds' {
						writer.print_address(view)!
					} else if api == 'os' {
						writer.print_value('?*', options, ?Slice1_1(view), depth)!
					} else {
						writer.print_value('*', options, view, depth)!
					}
				}
				2 {
					zero := Payload1_2{}
					view := borrowed(zero, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					if api != 'ds' { panic('unsupported optional-element value fixture') }
					writer.print_address(view)!
				}
				else { panic('invalid shape') }
			}
		}
		2 {
			match f[12].int() {
				0 {
					zero := Payload2_0{}
					view := borrowed(zero, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					if api == 'ds' {
						writer.print_address(view)!
					} else if api == 'os' {
						writer.print_value('?*', options, ?Slice2_0(view), depth)!
					} else {
						writer.print_value('*', options, view, depth)!
					}
				}
				1 {
					zero := Payload2_1{}
					view := borrowed(zero, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					if api == 'ds' {
						writer.print_address(view)!
					} else if api == 'os' {
						writer.print_value('?*', options, ?Slice2_1(view), depth)!
					} else {
						writer.print_value('*', options, view, depth)!
					}
				}
				2 {
					zero := Payload2_2{}
					view := borrowed(zero, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					if api != 'ds' { panic('unsupported optional-element value fixture') }
					writer.print_address(view)!
				}
				else { panic('invalid shape') }
			}
		}
		3 {
			match f[12].int() {
				0 {
					zero := Payload3_0{}
					view := borrowed(zero, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					if api == 'ds' {
						writer.print_address(view)!
					} else if api == 'os' {
						writer.print_value('?*', options, ?Slice3_0(view), depth)!
					} else {
						writer.print_value('*', options, view, depth)!
					}
				}
				1 {
					zero := Payload3_1{}
					view := borrowed(zero, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					if api == 'ds' {
						writer.print_address(view)!
					} else if api == 'os' {
						writer.print_value('?*', options, ?Slice3_1(view), depth)!
					} else {
						writer.print_value('*', options, view, depth)!
					}
				}
				2 {
					zero := Payload3_2{}
					view := borrowed(zero, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					if api != 'ds' { panic('unsupported optional-element value fixture') }
					writer.print_address(view)!
				}
				else { panic('invalid shape') }
			}
		}
		4 {
			match f[12].int() {
				0 {
					zero := Payload4_0{}
					view := borrowed(zero, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					if api == 'ds' {
						writer.print_address(view)!
					} else if api == 'os' {
						writer.print_value('?*', options, ?Slice4_0(view), depth)!
					} else {
						writer.print_value('*', options, view, depth)!
					}
				}
				1 {
					zero := Payload4_1{}
					view := borrowed(zero, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					if api == 'ds' {
						writer.print_address(view)!
					} else if api == 'os' {
						writer.print_value('?*', options, ?Slice4_1(view), depth)!
					} else {
						writer.print_value('*', options, view, depth)!
					}
				}
				2 {
					zero := Payload4_2{}
					view := borrowed(zero, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					if api != 'ds' { panic('unsupported optional-element value fixture') }
					writer.print_address(view)!
				}
				else { panic('invalid shape') }
			}
		}
		5 {
			match f[12].int() {
				0 {
					zero := Payload5_0{}
					view := borrowed(zero, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					if api == 'ds' {
						writer.print_address(view)!
					} else if api == 'os' {
						writer.print_value('?*', options, ?Slice5_0(view), depth)!
					} else {
						writer.print_value('*', options, view, depth)!
					}
				}
				1 {
					zero := Payload5_1{}
					view := borrowed(zero, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					if api == 'ds' {
						writer.print_address(view)!
					} else if api == 'os' {
						writer.print_value('?*', options, ?Slice5_1(view), depth)!
					} else {
						writer.print_value('*', options, view, depth)!
					}
				}
				2 {
					zero := Payload5_2{}
					view := borrowed(zero, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					if api != 'ds' { panic('unsupported optional-element value fixture') }
					writer.print_address(view)!
				}
				else { panic('invalid shape') }
			}
		}
		6 {
			match f[12].int() {
				0 {
					zero := Payload6_0{}
					view := borrowed(zero, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					if api == 'ds' {
						writer.print_address(view)!
					} else if api == 'os' {
						writer.print_value('?*', options, ?Slice6_0(view), depth)!
					} else {
						writer.print_value('*', options, view, depth)!
					}
				}
				1 {
					zero := Payload6_1{}
					view := borrowed(zero, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					if api == 'ds' {
						writer.print_address(view)!
					} else if api == 'os' {
						writer.print_value('?*', options, ?Slice6_1(view), depth)!
					} else {
						writer.print_value('*', options, view, depth)!
					}
				}
				2 {
					zero := Payload6_2{}
					view := borrowed(zero, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					if api != 'ds' { panic('unsupported optional-element value fixture') }
					writer.print_address(view)!
				}
				else { panic('invalid shape') }
			}
		}
		7 {
			match f[12].int() {
				0 {
					zero := Payload7_0{}
					view := borrowed(zero, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					if api == 'ds' {
						writer.print_address(view)!
					} else if api == 'os' {
						writer.print_value('?*', options, ?Slice7_0(view), depth)!
					} else {
						writer.print_value('*', options, view, depth)!
					}
				}
				1 {
					zero := Payload7_1{}
					view := borrowed(zero, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					if api == 'ds' {
						writer.print_address(view)!
					} else if api == 'os' {
						writer.print_value('?*', options, ?Slice7_1(view), depth)!
					} else {
						writer.print_value('*', options, view, depth)!
					}
				}
				2 {
					zero := Payload7_2{}
					view := borrowed(zero, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					if api != 'ds' { panic('unsupported optional-element value fixture') }
					writer.print_address(view)!
				}
				else { panic('invalid shape') }
			}
		}
		8 {
			match f[12].int() {
				0 {
					zero := Payload8_0{}
					view := borrowed(zero, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					if api == 'ds' {
						writer.print_address(view)!
					} else if api == 'os' {
						writer.print_value('?*', options, ?Slice8_0(view), depth)!
					} else {
						writer.print_value('*', options, view, depth)!
					}
				}
				1 {
					zero := Payload8_1{}
					view := borrowed(zero, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					if api == 'ds' {
						writer.print_address(view)!
					} else if api == 'os' {
						writer.print_value('?*', options, ?Slice8_1(view), depth)!
					} else {
						writer.print_value('*', options, view, depth)!
					}
				}
				2 {
					zero := Payload8_2{}
					view := borrowed(zero, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					if api != 'ds' { panic('unsupported optional-element value fixture') }
					writer.print_address(view)!
				}
				else { panic('invalid shape') }
			}
		}
		9 {
			match f[12].int() {
				0 {
					zero := Payload9_0{}
					view := borrowed(zero, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					if api == 'ds' {
						writer.print_address(view)!
					} else if api == 'os' {
						writer.print_value('?*', options, ?Slice9_0(view), depth)!
					} else {
						writer.print_value('*', options, view, depth)!
					}
				}
				1 {
					zero := Payload9_1{}
					view := borrowed(zero, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					if api == 'ds' {
						writer.print_address(view)!
					} else if api == 'os' {
						writer.print_value('?*', options, ?Slice9_1(view), depth)!
					} else {
						writer.print_value('*', options, view, depth)!
					}
				}
				2 {
					zero := Payload9_2{}
					view := borrowed(zero, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					if api != 'ds' { panic('unsupported optional-element value fixture') }
					writer.print_address(view)!
				}
				else { panic('invalid shape') }
			}
		}
		10 {
			match f[12].int() {
				0 {
					zero := Payload10_0{}
					view := borrowed(zero, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					if api == 'ds' {
						writer.print_address(view)!
					} else if api == 'os' {
						writer.print_value('?*', options, ?Slice10_0(view), depth)!
					} else {
						writer.print_value('*', options, view, depth)!
					}
				}
				1 {
					zero := Payload10_1{}
					view := borrowed(zero, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					if api == 'ds' {
						writer.print_address(view)!
					} else if api == 'os' {
						writer.print_value('?*', options, ?Slice10_1(view), depth)!
					} else {
						writer.print_value('*', options, view, depth)!
					}
				}
				2 {
					zero := Payload10_2{}
					view := borrowed(zero, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					if api != 'ds' { panic('unsupported optional-element value fixture') }
					writer.print_address(view)!
				}
				else { panic('invalid shape') }
			}
		}
		11 {
			match f[12].int() {
				0 {
					zero := Payload11_0{}
					view := borrowed(zero, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					if api == 'ds' {
						writer.print_address(view)!
					} else if api == 'os' {
						writer.print_value('?*', options, ?Slice11_0(view), depth)!
					} else {
						writer.print_value('*', options, view, depth)!
					}
				}
				1 {
					zero := Payload11_1{}
					view := borrowed(zero, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					if api == 'ds' {
						writer.print_address(view)!
					} else if api == 'os' {
						writer.print_value('?*', options, ?Slice11_1(view), depth)!
					} else {
						writer.print_value('*', options, view, depth)!
					}
				}
				2 {
					zero := Payload11_2{}
					view := borrowed(zero, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					if api != 'ds' { panic('unsupported optional-element value fixture') }
					writer.print_address(view)!
				}
				else { panic('invalid shape') }
			}
		}
		12 {
			match f[12].int() {
				0 {
					zero := Payload12_0{}
					view := borrowed(zero, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					if api == 'ds' {
						writer.print_address(view)!
					} else if api == 'os' {
						writer.print_value('?*', options, ?Slice12_0(view), depth)!
					} else {
						writer.print_value('*', options, view, depth)!
					}
				}
				1 {
					zero := Payload12_1{}
					view := borrowed(zero, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					if api == 'ds' {
						writer.print_address(view)!
					} else if api == 'os' {
						writer.print_value('?*', options, ?Slice12_1(view), depth)!
					} else {
						writer.print_value('*', options, view, depth)!
					}
				}
				2 {
					zero := Payload12_2{}
					view := borrowed(zero, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					if api != 'ds' { panic('unsupported optional-element value fixture') }
					writer.print_address(view)!
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
