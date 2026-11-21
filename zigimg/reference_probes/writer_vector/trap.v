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
	depth := uint(os.args[4].u64())
	if os.args[3] == '0' {
		writer.print_vector('x', zigimg.FormatOptions{ precision: uint(64) }, [
			f32(1.5),
			2.5,
		]!, depth) or { status = err.msg() }
	} else {
		writer.print_vector('x', zigimg.FormatOptions{ precision: uint(64) }, [
			f64(1.5),
			2.5,
		]!, depth) or { status = err.msg() }
	}

	println(status)
}

fn main() {
	run() or { panic(err) }
}
