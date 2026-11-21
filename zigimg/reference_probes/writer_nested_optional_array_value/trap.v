module main

import os
import zigimg as p

type BoolItems = [3]?bool
type BoolValues = []?BoolItems
type SignedItems = [3]?int

struct BoolArgs {
	value []?BoolItems
}

type Pair = [2]int
type Values = []?Pair
type Nested = [2][3]bool
type OptionalItems = [3]?u8

__global (
	path     string
	observed = &p.WriteStream(unsafe { nil })
	backing  []u8
)

fn save() {
	w := observed
	os.write_file(path, '${w.buffered().len}|${backing.hex()}|${w.buffered().hex()}|${w.unused_capacity_slice().hex()}') or { panic(err) }
}

fn borrowed[E](_ E, raw uint, length int) []?E {
	return unsafe { array{ data: voidptr(raw), len: length, cap: length, flags: .nofree, element_size: int(sizeof(?E)) } }
}

fn run() ! {
	path = os.args[1]
	mut buffer := []u8{len: os.args[2].int(), init: 0xa5}
	mut w := p.WriteStream.init_memory(mut buffer)
	observed = &w
	backing = unsafe { buffer }
	at_exit(save)!
	mut status := 'ok'
	zero := Pair{}
	nested := Nested{}
	items := OptionalItems{}
	view := borrowed(zero, uint(0x1234), 0)
	options := p.FormatOptions{ width: ~uint(0), precision: ~uint(0) }
	bool_row := [?bool(true), ?bool(none), ?bool(false)]!
	bool_payload := BoolItems(bool_row)
	bool_some := ?BoolItems(bool_payload)
	bool_values := [bool_some, ?BoolItems(none)]
	int_row := [?int(-7), ?int(none), ?int(8)]!
	int_payload := SignedItems(int_row)
	int_some := ?SignedItems(int_payload)
	int_values := [int_some, ?SignedItems(none)]
	match os.args[3] {
		'0' { w.print_address(view) or { status = err.msg() } }
		'1' { w.print_value('*', options, view, 0) or { status = err.msg() } }
		'2' { w.print_value('?*', options, ?Values(view), 0) or { status = err.msg() } }
		'3' { w.print_address(borrowed(nested, ~uint(0), 3)) or { status = err.msg() } }
		'4' {
			w.print_value('?*', p.FormatOptions{ width: 6, fill: `_` }, ?Values(none), 0) or { status = err.msg() }
		}
		'5' {
			w.print_value('?*', p.FormatOptions{ width: ~uint(0), fill: `_` }, ?Values(none), 0) or { status = err.msg() }
		}
		'6' { w.print_address(borrowed(items, uint(0), 0)) or { status = err.msg() } }
		'7' { w.print_value('any', p.FormatOptions{}, bool_values, 2) or { status = err.msg() } }
		'8' {
			w.print_value('any', p.FormatOptions{ width: 4, fill: `_` }, int_values, 2) or { status = err.msg() }
		}
		'9' {
			w.print_value('?any', p.FormatOptions{ width: 6, fill: `_` }, ?BoolValues(none), 2) or { status = err.msg() }
		}
		'10' { w.print('L{[value]any}R', BoolArgs{bool_values}) or { status = err.msg() } }
		else { panic('invalid control') }
	}
	println(status)
}

fn main() { run() or { panic(err) } }
