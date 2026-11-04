module main

import os
import zigimg as p

type Numbers = [3]string
type Values = []Numbers
type Nested = [2][3]string

__global (
	path     string
	observed = &p.WriteStream(unsafe { nil })
	backing  []u8
)

fn save() {
	w := observed
	os.write_file(path, '${w.buffered().len}|${backing.hex()}|${w.buffered().hex()}|${w.unused_capacity_slice().hex()}') or { panic(err) }
}

fn borrowed[E](_ E, raw usize, length int) []E {
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
	flat := unsafe { Numbers{} }
	nested := unsafe { Nested{} }
	view := borrowed(flat, usize(0x1234), 0)
	options := p.FormatOptions{ width: ~usize(0), precision: ~usize(0) }
	match os.args[3] {
		'0' {
			w.print_value('*', options, unsafe { &Numbers(voidptr(usize(0x1234))) }, 0) or { status = err.msg() }
		}
		'1' {
			w.print_address(unsafe { &Numbers(voidptr(usize(0x1234))) }) or { status = err.msg() }
		}
		'2' {
			w.print_value('*', options, borrowed(flat, usize(0x1234), 0), 0) or { status = err.msg() }
		}
		'3' { w.print_address(borrowed(flat, usize(0x1234), 3)) or { status = err.msg() } }
		'4' {
			w.print_value('*', options, unsafe { &Nested(voidptr(usize(0))) }, ~usize(0)) or { status = err.msg() }
		}
		'5' { w.print_address(borrowed(nested, ~usize(0), 0)) or { status = err.msg() } }
		'6' {
			w.print_value('?*', p.FormatOptions{ width: 6, fill: `_` }, ?Values(none), 0) or { status = err.msg() }
		}
		'7' { w.print_value('?*', options, ?Values(view), 0) or { status = err.msg() } }
		else { panic('invalid control') }
	}
	println(status)
}

fn main() { run() or { panic(err) } }
