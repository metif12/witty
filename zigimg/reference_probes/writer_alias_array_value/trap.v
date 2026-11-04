module main

import os
import zigimg

type Byte = u8
type Pointer = &Byte

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
	value := [unsafe { &Byte(voidptr(usize(0x1234))) }, unsafe { &Byte(voidptr(usize(0x5678))) }]!
	match os.args[3] {
		'0' {
			writer.print_value('any', zigimg.FormatOptions{}, value, 1) or { status = err.msg() }
		}
		'1' {
			aliases := [Pointer(value[0]), Pointer(value[1])]!
			writer.print_value('any', zigimg.FormatOptions{}, aliases, 1) or { status = err.msg() }
		}
		'2' {
			nested := [value, value]!
			writer.print_value('any', zigimg.FormatOptions{}, nested, 2) or { status = err.msg() }
		}
		'3' {
			writer.print_value('any', zigimg.FormatOptions{}, &value, 1) or { status = err.msg() }
		}
		'4' {
			writer.print_value('any', zigimg.FormatOptions{}, value, 0) or { status = err.msg() }
		}
		'5' {
			writer.print_value('any', zigimg.FormatOptions{ width: 6, alignment: .left, fill: `_`, precision: ~usize(0) }, value, 1) or { status = err.msg() }
		}
		else { panic('invalid control') }
	}

	println(status)
}

fn main() {
	run() or { panic(err) }
}
