module main

import os
import zigimg

__global (
	observed_path   string
	observed_writer = &zigimg.WriteStream(unsafe { nil })
	observed_buffer []u8
)

type Text = string
type Elements = [2]&string

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
	value := unsafe { &string(voidptr(uint(0x1234))) }
	match os.args[3] {
		'0' {
			writer.print_value('any', zigimg.FormatOptions{}, value, 0) or { status = err.msg() }
		}
		'1' { writer.print_address(value) or { status = err.msg() } }
		'2' {
			writer.print_value('*', zigimg.FormatOptions{ width: ~uint(0) }, unsafe { &string(nil) }, 0) or { status = err.msg() }
		}
		'3' {
			writer.print_value('?*', zigimg.FormatOptions{}, ?&string(unsafe { &string(voidptr(uint(0x1000))) }), 0) or { status = err.msg() }
		}
		'4' {
			writer.print_value('?*', zigimg.FormatOptions{ width: 6, fill: `_` }, ?&string(none), 0) or { status = err.msg() }
		}
		'5' { writer.print_address(?&string(none)) or { status = err.msg() } }
		'6' {
			writer.print_address(unsafe { &Elements(voidptr(uint(0x1234))) }) or { status = err.msg() }
		}
		else { panic('invalid control') }
	}

	println(status)
}

fn main() {
	run() or { panic(err) }
}
