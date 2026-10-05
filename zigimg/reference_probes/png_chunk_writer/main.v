module main

import encoding.hex
import os
import zigimg

fn mix(mut hash []u64, value u64) {
	hash[0] = (hash[0] ^ value) * u64(1099511628211)
}

struct Output {
mut:
	stream    zigimg.WriteStream
	max_write int
	trace     []u64 = [u64(14695981039346656037)]
}

struct Adapter {
mut:
	output &Output
}

pub fn (mut adapter Adapter) write_int[T, E](value T, endian E) ! {
	mix(mut adapter.output.trace, 1)
	mix(mut adapter.output.trace, u64(value))
	adapter.output.stream.write_int(value, endian)!
}

pub fn (mut adapter Adapter) write_all(bytes []u8) ! {
	mix(mut adapter.output.trace, 2)
	mix(mut adapter.output.trace, u64(bytes.len))
	adapter.output.stream.write_all(bytes)!
}

pub fn (mut adapter Adapter) write(bytes []u8) !usize {
	mix(mut adapter.output.trace, 3)
	mix(mut adapter.output.trace, u64(bytes.len))
	count := if adapter.output.max_write > 0 && adapter.output.max_write < bytes.len {
		adapter.output.max_write
	} else {
		bytes.len
	}
	return adapter.output.stream.write(bytes[..count])
}

fn run[B](buffer B, fields []string) {
	mut destination := []u8{len: fields[1].int(), init: 0xa5}
	mut output := Output{
		stream:    zigimg.WriteStream.init_memory(mut destination)
		max_write: fields[2].int()
	}
	mut writer := zigimg.png_chunk_writer_with_buffer[B, Adapter](buffer, Adapter{ output: &output }, [
		u8(`I`),
		`D`,
		`A`,
		`T`,
	]!)
	mut states := []string{}
	if fields[3] in ['overflow', 'bounds'] {
		writer.end = if fields[3] == 'overflow' { ~usize(0) } else { usize(fields[0].int()) + 1 }
		if fields[3] == 'overflow' {
			_ = writer.write([u8(1)]) or {
				eprintln('UNEXPECTED ${err}')
				return
			}
		} else {
			writer.flush() or {
				eprintln('UNEXPECTED ${err}')
				return
			}
		}
		println('UNEXPECTED')
		return
	}
	for operation in fields[3].split(',') {
		mut status := 'ok'
		mut count := usize(0)
		if operation == 'F' {
			writer.flush() or { status = err.msg() }
		} else {
			count = writer.write(hex.decode(operation[1..]) or { panic(err) }) or {
				status = err.msg()
				usize(0)
			}
		}
		mut active := [u64(14695981039346656037)]
		pointer := unsafe { &u8(&writer.buf) }
		for i in 0 .. int(writer.end) {
			mix(mut active, unsafe { pointer[i] })
		}
		states << '${status}:${count}:${writer.end}:${output.stream.get_pos()}:${active[0]:016x}'
	}
	mut hash := [u64(14695981039346656037)]
	for byte in destination {
		mix(mut hash, byte)
	}
	println('${states.join(';')}|${output.trace[0]:016x}|${hash[0]:016x}')
}

fn main() {
	for line in os.read_lines(os.args[1]) or { panic(err) } {
		fields := line.split('|')
		match fields[0].int() {
			0 { run([]u8{}, fields) }
			1 { run([1]u8{}, fields) }
			4 { run([4]u8{}, fields) }
			16 { run([16]u8{}, fields) }
			16384 { run([16384]u8{}, fields) }
			else { panic('unknown buffer size') }
		}
	}
}
