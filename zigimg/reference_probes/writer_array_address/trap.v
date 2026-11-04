module main

import os
import zigimg as p

__global (
	observed_path   string
	observed_writer = &p.WriteStream(unsafe { nil })
	observed_buffer []u8
)

fn observe() {
	w := observed_writer
	os.write_file(observed_path, '${w.buffered().len}|${observed_buffer.hex()}|${w.buffered().hex()}|${w.unused_capacity_slice().hex()}') or { panic(err) }
}

fn run() ! {
	observed_path = os.args[1]
	mut buffer := []u8{len: os.args[2].int(), init: 0xa5}
	mut w := p.WriteStream.init_memory(mut buffer)
	observed_writer = &w
	observed_buffer = unsafe { buffer }
	at_exit(observe)!
	mut status := 'ok'
	options := p.FormatOptions{ width: ~usize(0), precision: ~usize(0) }
	match os.args[3] {
		'0' {
			w.print_value('*', options, unsafe { &[3]u8(usize(0x1234)) }, 0) or { status = err.msg() }
		}
		'1' {
			w.print_value('*', options, unsafe { &[2][3]int(usize(0)) }, ~usize(0)) or { status = err.msg() }
		}
		'2' {
			w.print_value('*', options, unsafe { &[1]f64(~usize(0)) }, 0) or { status = err.msg() }
		}
		else { panic('invalid control') }
	}
	println(status)
}

fn main() { run() or { panic(err) } }
