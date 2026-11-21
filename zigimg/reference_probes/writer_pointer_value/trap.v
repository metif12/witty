module main

import os
import zigimg

__global (
	observed_path   string
	observed_writer = &zigimg.WriteStream(unsafe { nil })
	observed_buffer []u8
)

type TrapWord = u8
type TrapPointer = &TrapWord

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
	options := zigimg.FormatOptions{ width: ~uint(0), precision: ~uint(0), alignment: .left, fill: `_` }
	pointer := unsafe { &u8(uint(0x12)) }
	match os.args[3] {
		'0' { writer.print_value('any', options, pointer, 0) or { status = err.msg() } }
		'1' { writer.print_value('any', options, ?&u8(pointer), 0) or { status = err.msg() } }
		'2' {
			writer.print_value('any', options, voidptr(uint(0x12)), 0) or { status = err.msg() }
		}
		'3' {
			writer.print_value('any', options, ?TrapPointer(TrapPointer(unsafe { &TrapWord(uint(0x12)) })), 0) or { status = err.msg() }
		}
		'4' { writer.print_value('any', options, ?&u8(none), 0) or { status = err.msg() } }
		'5' { writer.print_value('*', options, pointer, 0) or { status = err.msg() } }
		else { panic('invalid control') }
	}

	println(status)
}

fn main() {
	run() or { panic(err) }
}
