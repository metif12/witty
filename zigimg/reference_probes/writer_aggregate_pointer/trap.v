module main

import os
import zigimg

__global (
	observed_path   string
	observed_writer = &zigimg.WriteStream(unsafe { nil })
	observed_buffer []u8
)

enum Choice {
	zero
	high
}

struct Wrapped {
	choice Choice
}

struct Number {
	value int
}

type Tagged = Choice | bool

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
	options := zigimg.FormatOptions{ width: usize(0) }
	depth := usize(os.args[4].u64())
	value := Choice.high
	match os.args[3] {
		'0' { writer.print_value('any', options, &value, depth) or { status = err.msg() } }
		'1' {
			writer.print_value('any', options, ?&Choice(&value), depth) or { status = err.msg() }
		}
		'2' { writer.print_value('any', options, ?&Choice(none), depth) or { status = err.msg() } }
		'3' {
			wrapped := Wrapped{value}
			writer.print_value('any', options, &wrapped, depth) or { status = err.msg() }
		}
		'4' {
			tagged := Tagged(value)
			writer.print_value('any', options, &tagged, depth) or { status = err.msg() }
		}
		'5' {
			number := Number{7}
			writer.print_value('any', zigimg.FormatOptions{ width: ~usize(0), alignment: .left, fill: `_` }, &number, depth) or { status = err.msg() }
		}
		else { panic('invalid control') }
	}

	println(status)
}

fn main() {
	run() or { panic(err) }
}
