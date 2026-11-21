module main

import os
import zigimg as p

type Text = string

__global (
	path     string
	observed = &p.WriteStream(unsafe { nil })
	backing  []u8
)

fn save() {
	w := observed
	os.write_file(path, '${w.buffered().len}|${backing.hex()}|${w.buffered().hex()}|${w.unused_capacity_slice().hex()}') or { panic(err) }
}

fn borrowed(bits uint, length int) string {
	return unsafe { (&u8(voidptr(bits))).vstring_with_len(length) }
}

fn run() ! {
	path = os.args[1]
	mut buffer := []u8{len: os.args[2].int(), init: 0xa5}
	mut w := p.WriteStream.init_memory(mut buffer)
	observed = &w
	backing = unsafe { buffer }
	at_exit(save)!
	mut status := 'ok'
	value := borrowed(uint(0x1234), 3)
	options := p.FormatOptions{ width: ~uint(0), precision: ~uint(0) }
	match os.args[3] {
		'0' { w.print_address(value) or { status = err.msg() } }
		'1' { w.print_address(Text(value)) or { status = err.msg() } }
		'2' { w.print_value('*', options, value, 0) or { status = err.msg() } }
		'3' { w.print_value('?*', options, ?string(borrowed(~uint(0), 0)), 0) or { status = err.msg() } }
		'4' {
			w.print_value('?*', p.FormatOptions{ width: 6, fill: `_` }, ?string(none), 0) or { status = err.msg() }
		}
		'5' {
			w.print_value('?*', p.FormatOptions{ width: ~uint(0), fill: `_` }, ?string(none), 0) or { status = err.msg() }
		}
		else { panic('invalid control') }
	}

	println(status)
}

fn main() { run() or { panic(err) } }
