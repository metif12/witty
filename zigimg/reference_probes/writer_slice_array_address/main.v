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
type Array0 = [3]Word0
type Views0 = []Array0
type Word1 = u16
type Array1 = [3]Word1
type Views1 = []Array1
type Word2 = u32
type Array2 = [3]Word2
type Views2 = []Array2
type Word3 = u64
type Array3 = [3]Word3
type Views3 = []Array3
type Word4 = uint
type Array4 = [3]Word4
type Views4 = []Array4
type Word5 = i8
type Array5 = [3]Word5
type Views5 = []Array5
type Word6 = i16
type Array6 = [3]Word6
type Views6 = []Array6
type Word7 = int
type Array7 = [3]Word7
type Views7 = []Array7
type Word8 = i64
type Array8 = [3]Word8
type Views8 = []Array8
type Word9 = int
type Array9 = [3]Word9
type Views9 = []Array9
type Word10 = f32
type Array10 = [3]Word10
type Views10 = []Array10
type Word11 = f64
type Array11 = [3]Word11
type Views11 = []Array11
type Word12 = bool
type Array12 = [3]Word12
type Views12 = []Array12

fn borrowed[E](_ E, raw uint, length int) []E {
	return unsafe { array{ data: voidptr(raw), len: length, cap: length, flags: .nofree, element_size: int(sizeof(E)) } }
}

fn operate(mut writer zigimg.WriteStream, f []string) ! {
	raw := uint(f[8].u64())
	length := f[9].int()
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
	format := (hex.decode(f[1])!).bytestr()
	match f[0].int() {
		0 {
			match f[12].int() {
				0 {
					witness := [3]u8{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					writer.print_value(format, options, view, depth)!
				}
				1 {
					witness := Array0{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					writer.print_value(format, options, view, depth)!
				}
				2 {
					witness := [2][3]u8{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					writer.print_value(format, options, view, depth)!
				}
				3 {
					witness := [1]u8{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					writer.print_value(format, options, view, depth)!
				}
				4 {
					witness := Array0{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					alias_view := Views0(view)
					writer.print_value(format, options, alias_view, depth)!
				}
				5 {
					witness := Array0{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					writer.print_value(format, options, ?[]Array0(view), depth)!
				}
				6 {
					witness := Array0{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					writer.print_value(format, options, ?[]Array0(none), depth)!
				}
				7 {
					witness := Array0{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					alias_view := Views0(view)
					writer.print_value(format, options, ?Views0(alias_view), depth)!
				}
				8 {
					witness := Array0{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					writer.print_value(format, options, ?Views0(none), depth)!
				}
				else { panic('invalid form') }
			}
		}
		1 {
			match f[12].int() {
				0 {
					witness := [3]u16{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					writer.print_value(format, options, view, depth)!
				}
				1 {
					witness := Array1{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					writer.print_value(format, options, view, depth)!
				}
				2 {
					witness := [2][3]u16{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					writer.print_value(format, options, view, depth)!
				}
				3 {
					witness := [1]u16{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					writer.print_value(format, options, view, depth)!
				}
				4 {
					witness := Array1{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					alias_view := Views1(view)
					writer.print_value(format, options, alias_view, depth)!
				}
				5 {
					witness := Array1{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					writer.print_value(format, options, ?[]Array1(view), depth)!
				}
				6 {
					witness := Array1{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					writer.print_value(format, options, ?[]Array1(none), depth)!
				}
				7 {
					witness := Array1{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					alias_view := Views1(view)
					writer.print_value(format, options, ?Views1(alias_view), depth)!
				}
				8 {
					witness := Array1{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					writer.print_value(format, options, ?Views1(none), depth)!
				}
				else { panic('invalid form') }
			}
		}
		2 {
			match f[12].int() {
				0 {
					witness := [3]u32{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					writer.print_value(format, options, view, depth)!
				}
				1 {
					witness := Array2{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					writer.print_value(format, options, view, depth)!
				}
				2 {
					witness := [2][3]u32{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					writer.print_value(format, options, view, depth)!
				}
				3 {
					witness := [1]u32{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					writer.print_value(format, options, view, depth)!
				}
				4 {
					witness := Array2{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					alias_view := Views2(view)
					writer.print_value(format, options, alias_view, depth)!
				}
				5 {
					witness := Array2{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					writer.print_value(format, options, ?[]Array2(view), depth)!
				}
				6 {
					witness := Array2{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					writer.print_value(format, options, ?[]Array2(none), depth)!
				}
				7 {
					witness := Array2{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					alias_view := Views2(view)
					writer.print_value(format, options, ?Views2(alias_view), depth)!
				}
				8 {
					witness := Array2{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					writer.print_value(format, options, ?Views2(none), depth)!
				}
				else { panic('invalid form') }
			}
		}
		3 {
			match f[12].int() {
				0 {
					witness := [3]u64{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					writer.print_value(format, options, view, depth)!
				}
				1 {
					witness := Array3{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					writer.print_value(format, options, view, depth)!
				}
				2 {
					witness := [2][3]u64{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					writer.print_value(format, options, view, depth)!
				}
				3 {
					witness := [1]u64{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					writer.print_value(format, options, view, depth)!
				}
				4 {
					witness := Array3{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					alias_view := Views3(view)
					writer.print_value(format, options, alias_view, depth)!
				}
				5 {
					witness := Array3{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					writer.print_value(format, options, ?[]Array3(view), depth)!
				}
				6 {
					witness := Array3{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					writer.print_value(format, options, ?[]Array3(none), depth)!
				}
				7 {
					witness := Array3{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					alias_view := Views3(view)
					writer.print_value(format, options, ?Views3(alias_view), depth)!
				}
				8 {
					witness := Array3{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					writer.print_value(format, options, ?Views3(none), depth)!
				}
				else { panic('invalid form') }
			}
		}
		4 {
			match f[12].int() {
				0 {
					witness := [3]uint{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					writer.print_value(format, options, view, depth)!
				}
				1 {
					witness := Array4{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					writer.print_value(format, options, view, depth)!
				}
				2 {
					witness := [2][3]uint{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					writer.print_value(format, options, view, depth)!
				}
				3 {
					witness := [1]uint{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					writer.print_value(format, options, view, depth)!
				}
				4 {
					witness := Array4{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					alias_view := Views4(view)
					writer.print_value(format, options, alias_view, depth)!
				}
				5 {
					witness := Array4{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					writer.print_value(format, options, ?[]Array4(view), depth)!
				}
				6 {
					witness := Array4{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					writer.print_value(format, options, ?[]Array4(none), depth)!
				}
				7 {
					witness := Array4{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					alias_view := Views4(view)
					writer.print_value(format, options, ?Views4(alias_view), depth)!
				}
				8 {
					witness := Array4{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					writer.print_value(format, options, ?Views4(none), depth)!
				}
				else { panic('invalid form') }
			}
		}
		5 {
			match f[12].int() {
				0 {
					witness := [3]i8{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					writer.print_value(format, options, view, depth)!
				}
				1 {
					witness := Array5{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					writer.print_value(format, options, view, depth)!
				}
				2 {
					witness := [2][3]i8{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					writer.print_value(format, options, view, depth)!
				}
				3 {
					witness := [1]i8{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					writer.print_value(format, options, view, depth)!
				}
				4 {
					witness := Array5{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					alias_view := Views5(view)
					writer.print_value(format, options, alias_view, depth)!
				}
				5 {
					witness := Array5{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					writer.print_value(format, options, ?[]Array5(view), depth)!
				}
				6 {
					witness := Array5{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					writer.print_value(format, options, ?[]Array5(none), depth)!
				}
				7 {
					witness := Array5{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					alias_view := Views5(view)
					writer.print_value(format, options, ?Views5(alias_view), depth)!
				}
				8 {
					witness := Array5{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					writer.print_value(format, options, ?Views5(none), depth)!
				}
				else { panic('invalid form') }
			}
		}
		6 {
			match f[12].int() {
				0 {
					witness := [3]i16{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					writer.print_value(format, options, view, depth)!
				}
				1 {
					witness := Array6{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					writer.print_value(format, options, view, depth)!
				}
				2 {
					witness := [2][3]i16{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					writer.print_value(format, options, view, depth)!
				}
				3 {
					witness := [1]i16{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					writer.print_value(format, options, view, depth)!
				}
				4 {
					witness := Array6{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					alias_view := Views6(view)
					writer.print_value(format, options, alias_view, depth)!
				}
				5 {
					witness := Array6{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					writer.print_value(format, options, ?[]Array6(view), depth)!
				}
				6 {
					witness := Array6{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					writer.print_value(format, options, ?[]Array6(none), depth)!
				}
				7 {
					witness := Array6{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					alias_view := Views6(view)
					writer.print_value(format, options, ?Views6(alias_view), depth)!
				}
				8 {
					witness := Array6{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					writer.print_value(format, options, ?Views6(none), depth)!
				}
				else { panic('invalid form') }
			}
		}
		7 {
			match f[12].int() {
				0 {
					witness := [3]int{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					writer.print_value(format, options, view, depth)!
				}
				1 {
					witness := Array7{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					writer.print_value(format, options, view, depth)!
				}
				2 {
					witness := [2][3]int{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					writer.print_value(format, options, view, depth)!
				}
				3 {
					witness := [1]int{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					writer.print_value(format, options, view, depth)!
				}
				4 {
					witness := Array7{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					alias_view := Views7(view)
					writer.print_value(format, options, alias_view, depth)!
				}
				5 {
					witness := Array7{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					writer.print_value(format, options, ?[]Array7(view), depth)!
				}
				6 {
					witness := Array7{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					writer.print_value(format, options, ?[]Array7(none), depth)!
				}
				7 {
					witness := Array7{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					alias_view := Views7(view)
					writer.print_value(format, options, ?Views7(alias_view), depth)!
				}
				8 {
					witness := Array7{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					writer.print_value(format, options, ?Views7(none), depth)!
				}
				else { panic('invalid form') }
			}
		}
		8 {
			match f[12].int() {
				0 {
					witness := [3]i64{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					writer.print_value(format, options, view, depth)!
				}
				1 {
					witness := Array8{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					writer.print_value(format, options, view, depth)!
				}
				2 {
					witness := [2][3]i64{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					writer.print_value(format, options, view, depth)!
				}
				3 {
					witness := [1]i64{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					writer.print_value(format, options, view, depth)!
				}
				4 {
					witness := Array8{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					alias_view := Views8(view)
					writer.print_value(format, options, alias_view, depth)!
				}
				5 {
					witness := Array8{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					writer.print_value(format, options, ?[]Array8(view), depth)!
				}
				6 {
					witness := Array8{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					writer.print_value(format, options, ?[]Array8(none), depth)!
				}
				7 {
					witness := Array8{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					alias_view := Views8(view)
					writer.print_value(format, options, ?Views8(alias_view), depth)!
				}
				8 {
					witness := Array8{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					writer.print_value(format, options, ?Views8(none), depth)!
				}
				else { panic('invalid form') }
			}
		}
		9 {
			match f[12].int() {
				0 {
					witness := [3]int{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					writer.print_value(format, options, view, depth)!
				}
				1 {
					witness := Array9{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					writer.print_value(format, options, view, depth)!
				}
				2 {
					witness := [2][3]int{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					writer.print_value(format, options, view, depth)!
				}
				3 {
					witness := [1]int{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					writer.print_value(format, options, view, depth)!
				}
				4 {
					witness := Array9{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					alias_view := Views9(view)
					writer.print_value(format, options, alias_view, depth)!
				}
				5 {
					witness := Array9{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					writer.print_value(format, options, ?[]Array9(view), depth)!
				}
				6 {
					witness := Array9{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					writer.print_value(format, options, ?[]Array9(none), depth)!
				}
				7 {
					witness := Array9{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					alias_view := Views9(view)
					writer.print_value(format, options, ?Views9(alias_view), depth)!
				}
				8 {
					witness := Array9{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					writer.print_value(format, options, ?Views9(none), depth)!
				}
				else { panic('invalid form') }
			}
		}
		10 {
			match f[12].int() {
				0 {
					witness := [3]f32{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					writer.print_value(format, options, view, depth)!
				}
				1 {
					witness := Array10{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					writer.print_value(format, options, view, depth)!
				}
				2 {
					witness := [2][3]f32{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					writer.print_value(format, options, view, depth)!
				}
				3 {
					witness := [1]f32{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					writer.print_value(format, options, view, depth)!
				}
				4 {
					witness := Array10{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					alias_view := Views10(view)
					writer.print_value(format, options, alias_view, depth)!
				}
				5 {
					witness := Array10{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					writer.print_value(format, options, ?[]Array10(view), depth)!
				}
				6 {
					witness := Array10{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					writer.print_value(format, options, ?[]Array10(none), depth)!
				}
				7 {
					witness := Array10{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					alias_view := Views10(view)
					writer.print_value(format, options, ?Views10(alias_view), depth)!
				}
				8 {
					witness := Array10{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					writer.print_value(format, options, ?Views10(none), depth)!
				}
				else { panic('invalid form') }
			}
		}
		11 {
			match f[12].int() {
				0 {
					witness := [3]f64{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					writer.print_value(format, options, view, depth)!
				}
				1 {
					witness := Array11{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					writer.print_value(format, options, view, depth)!
				}
				2 {
					witness := [2][3]f64{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					writer.print_value(format, options, view, depth)!
				}
				3 {
					witness := [1]f64{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					writer.print_value(format, options, view, depth)!
				}
				4 {
					witness := Array11{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					alias_view := Views11(view)
					writer.print_value(format, options, alias_view, depth)!
				}
				5 {
					witness := Array11{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					writer.print_value(format, options, ?[]Array11(view), depth)!
				}
				6 {
					witness := Array11{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					writer.print_value(format, options, ?[]Array11(none), depth)!
				}
				7 {
					witness := Array11{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					alias_view := Views11(view)
					writer.print_value(format, options, ?Views11(alias_view), depth)!
				}
				8 {
					witness := Array11{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					writer.print_value(format, options, ?Views11(none), depth)!
				}
				else { panic('invalid form') }
			}
		}
		12 {
			match f[12].int() {
				0 {
					witness := [3]bool{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					writer.print_value(format, options, view, depth)!
				}
				1 {
					witness := Array12{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					writer.print_value(format, options, view, depth)!
				}
				2 {
					witness := [2][3]bool{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					writer.print_value(format, options, view, depth)!
				}
				3 {
					witness := [1]bool{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					writer.print_value(format, options, view, depth)!
				}
				4 {
					witness := Array12{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					alias_view := Views12(view)
					writer.print_value(format, options, alias_view, depth)!
				}
				5 {
					witness := Array12{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					writer.print_value(format, options, ?[]Array12(view), depth)!
				}
				6 {
					witness := Array12{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					writer.print_value(format, options, ?[]Array12(none), depth)!
				}
				7 {
					witness := Array12{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					alias_view := Views12(view)
					writer.print_value(format, options, ?Views12(alias_view), depth)!
				}
				8 {
					witness := Array12{}
					view := borrowed(witness, raw, length)
					seen = '${uint(view.data)}:${view.len}'
					writer.print_value(format, options, ?Views12(none), depth)!
				}
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
