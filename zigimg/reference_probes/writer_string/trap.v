module main

import os
import zigimg

__global (
	observed_path   string
	observed_writer = &zigimg.WriteStream(unsafe { nil })
	observed_buffer []u8
)

struct StringRecord {
	text string
}

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
	text := 'A'
	options := zigimg.FormatOptions{ width: ~usize(0), alignment: .left, fill: `_` }
	match os.args[3] {
		'0' {
			writer.print_value('x', zigimg.FormatOptions{ width: usize(0) }, text, 0) or { status = err.msg() }
		}
		'1' {
			writer.print_value('x', zigimg.FormatOptions{ precision: usize(0) }, text, 0) or { status = err.msg() }
		}
		'2' {
			writer.print_value('X', zigimg.FormatOptions{ width: usize(0), precision: usize(0) }, text, 0) or { status = err.msg() }
		}
		'3' {
			writer.print_value('b64', zigimg.FormatOptions{ width: usize(0) }, text, 0) or { status = err.msg() }
		}
		'4' {
			writer.print_value('?x', zigimg.FormatOptions{ width: usize(0) }, ?string(text), 0) or { status = err.msg() }
		}
		'5' {
			writer.print_value('?x', zigimg.FormatOptions{ width: usize(0) }, ?string(none), 0) or { status = err.msg() }
		}
		'6' { writer.print_value('any', options, text, 1) or { status = err.msg() } }
		'7' { writer.print_value('any', options, StringRecord{text}, 2) or { status = err.msg() } }
		'8' { writer.print_value('s', options, text, 0) or { status = err.msg() } }
		'9' { writer.print_value('any', options, StringRecord{text}, 1) or { status = err.msg() } }
		'10' { writer.print_value('any', options, text, 0) or { status = err.msg() } }
		else { panic('invalid control') }
	}

	println(status)
}

fn main() {
	run() or { panic(err) }
}
