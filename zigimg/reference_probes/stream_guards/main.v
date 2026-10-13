module main

import os
import encoding.hex
import zigimg as p

__global (
	observed_reader = &p.ReadStream(unsafe { nil })
	observed_writer = &p.WriteStream(unsafe { nil })
	observed_buffer []u8
	observed_path   string
	observed_op     int
)
fn snapshot(reader &p.ReadStream, writer &p.WriteStream, buffer []u8, op int) string {
	if op == 3 { return '${writer.buffered().hex()}|${buffer.hex()}' }
	buffered := if op == 1 { '-' } else { '${reader.buffered_len()}' }
	return '${reader.get_pos()}|${buffered}|${buffer.hex()}'
}

fn observe() {
	os.write_file(observed_path, snapshot(observed_reader, observed_writer, observed_buffer,
		observed_op)) or { eprintln('OBSERVER ERROR: ${err}') }
}

fn record(line string, path string) string {
	f := line.split('|')
	op := f[0].int()
	capacity := f[1].int()
	prefill := f[2].int()
	consumed := f[3].int()
	data := hex.decode(f[5]) or { panic(err) }
	mut buffer := if capacity < 0 { data.clone() } else { []u8{len: capacity, init: u8(165)} }
	mut reader := p.ReadStream.init_memory(buffer)
	mut writer := p.WriteStream.init_memory(mut buffer)
	mut file := os.File{}
	if capacity >= 0 {
		if op == 3 {
			file = os.create(path) or { panic(err) }
			writer = p.WriteStream.init_file(file, mut buffer)
		} else {
			os.write_file_array(path, data) or { panic(err) }
			file = os.open(path) or { panic(err) }
			reader = p.ReadStream.init_file(file, mut buffer)
		}
	}
	if observed_path != '' {
		observed_reader = &reader
		observed_writer = &writer
		observed_buffer = unsafe { buffer }
		observed_op = op
	}
	mut status := ''
	if op == 3 {
		writer.seek_to(f[4].u64()) or { panic(err) }
		writer.write_all(data[..prefill]) or { panic(err) }
		status = 'ok:${writer.get_pos()}'
	} else {
		if prefill > 0 { reader.peek(prefill) or {
				return 'E${err.msg()}|' + snapshot(&reader, &writer, buffer, op)} }
		reader.take(consumed) or {
			return 'E${err.msg()}|' + snapshot(&reader, &writer, buffer, op)
		}
		match op {
			0 {
				value := reader.peek(f[4].int()) or {
					return 'E${err.msg()}|' + snapshot(&reader, &writer, buffer, op)
				}
				status = 'ok:' + value.hex()
			}
			1 {
				reader.toss(f[4].u64())
				status = 'ok'
			}
			2 {
				reader.seek_by(f[4].i64()) or {
					return 'E${err.msg()}|' + snapshot(&reader, &writer, buffer, op)
				}
				status = 'ok'
			}
			else {
				panic('invalid operation')
			}
		}
	}
	if capacity >= 0 { file.close() }
	return status + '|' + snapshot(&reader, &writer, buffer, op)
}

fn main() {
	if os.args.len == 4 && os.args[1] == '--trap' {
		observed_path = os.args[2]
		at_exit(observe) or { panic(err) }
		println(record(os.args[3], os.args[2] + '.bin'))
		return
	}
	for line in os.read_lines(os.args[1]) or { panic(err) } {
		println(record(line, os.args[1] + '.v.bin'))
	}
}
