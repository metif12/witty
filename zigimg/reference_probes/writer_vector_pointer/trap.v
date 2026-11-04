module main

import os
import zigimg

__global (
	observed_path   string
	observed_writer = &zigimg.WriteStream(unsafe { nil })
	observed_buffer []u8
)

fn observe() {
	writer := observed_writer
	state := '${writer.buffered().len}|${observed_buffer.hex()}|${writer.buffered().hex()}|${writer.unused_capacity_slice().hex()}'
	os.write_file(observed_path, state) or { eprintln('observer failed: ${err}') }
}

fn run() ! {
	observed_path = os.args[1]
	mut buffer := []u8{len: os.args[2].int(), init: 0xa5}
	mut writer := zigimg.WriteStream.init_memory(mut buffer)
	observed_writer = &writer
	observed_buffer = unsafe { buffer }
	at_exit(observe)!
	mut status := 'ok'
	options := zigimg.FormatOptions{ width: ~usize(0), precision: ~usize(0), alignment: .left, fill: `_` }
	depth := usize(os.args[4].u64())
	pointer := unsafe { &u8(usize(0x12)) }
	present := ?&u8(pointer)
	absent := ?&u8(none)
	match os.args[3] {
		'0' {
			writer.print_vector('any', options, [pointer, pointer]!, depth) or { status = err.msg() }
		}
		'1' {
			writer.print_vector('any', options, [present, present]!, depth) or { status = err.msg() }
		}
		'2' {
			writer.print_vector('any', options, [voidptr(usize(0x12)), voidptr(usize(0x12))]!, depth) or { status = err.msg() }
		}
		'3' {
			writer.print_vector('any', options, [absent, present]!, depth) or { status = err.msg() }
		}
		'4' {
			writer.print_vector('*', options, [pointer, pointer]!, depth) or { status = err.msg() }
		}
		else { panic('invalid control') }
	}

	println(status)
}

fn main() {
	run() or { panic(err) }
}
