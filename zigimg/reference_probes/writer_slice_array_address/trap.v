module main

import os
import zigimg as p

type Bytes = [3]u8
type Views = []Bytes

__global (
	path     string
	observed = &p.WriteStream(unsafe { nil })
	backing  []u8
)

fn save() {
	w := observed
	os.write_file(path, '${w.buffered().len}|${backing.hex()}|${w.buffered().hex()}|${w.unused_capacity_slice().hex()}') or { panic(err) }
}

fn borrowed[E](_ E, raw uint, length int) []E {
	return unsafe { array{ data: voidptr(raw), len: length, cap: length, flags: .nofree, element_size: int(sizeof(E)) } }
}

fn run() ! {
	path = os.args[1]
	mut buffer := []u8{len: os.args[2].int(), init: 0xa5}
	mut w := p.WriteStream.init_memory(mut buffer)
	observed = &w
	backing = unsafe { buffer }
	at_exit(save)!
	mut status := 'ok'
	zero := Bytes{}
	nested := [[int(0), 0, 0]!, [int(0), 0, 0]!]!
	single := [f64(0)]!
	view := borrowed(zero, uint(0x1234), 0)
	options := p.FormatOptions{ width: ~uint(0), precision: ~uint(0) }
	match os.args[3] {
		'0' { w.print_value('*', options, view, 0) or { status = err.msg() } }
		'1' {
			w.print_value('*', options, borrowed(nested, uint(0), 3), ~uint(0)) or { status = err.msg() }
		}
		'2' {
			w.print_value('*', options, borrowed(single, ~uint(0), 2), 0) or { status = err.msg() }
		}
		'3' { w.print_value('?*', options, ?[]Bytes(view), 0) or { status = err.msg() } }
		'4' {
			w.print_value('?*', p.FormatOptions{ width: uint(8), alignment: .center, fill: `_` }, ?[]Bytes(none), 0) or { status = err.msg() }
		}
		'5' {
			w.print_value('?*', p.FormatOptions{ width: ~uint(0), alignment: .left, fill: `_` }, ?[]Bytes(none), 0) or { status = err.msg() }
		}
		'6' {
			w.print_value('?*', p.FormatOptions{ width: ~uint(0), alignment: .center, fill: `_` }, ?[]Bytes(none), 0) or { status = err.msg() }
		}
		'7' {
			w.print_value('?*', p.FormatOptions{ width: ~uint(0), alignment: .right, fill: `_` }, ?[]Bytes(none), 0) or { status = err.msg() }
		}
		'8' {
			w.print_value('?*', p.FormatOptions{ width: uint(8), fill: 0 }, ?Views(none), 0) or { status = err.msg() }
		}
		else { panic('invalid control') }
	}
	println(status)
}

fn main() { run() or { panic(err) } }
