module main

import os
import strings
import zigimg as p

type AliasBig = p.BigEndian
type AliasLittle = p.LittleEndian

fn run[E](mut writer strings.Builder, kind int, raw u8, count u8, capacity int, repeats int) {
	if kind == 0 {
		mut data := [u8(0xab), 0xcd]
		mut input := p.ReadStream.init_memory(data)
		mut bits := p.BitReader[E]{
			reader: &input
			bits:   raw
			count:  count
		}
		copied := bits
		bits.align_to_byte()
		writer.write_string('${raw}:${count}:${input.get_pos()}|${bits.bits}:${bits.count}:${copied.bits}:${copied.count}|')
		input.seek_to(1) or { panic(err) }
		bits.align_to_byte()
		writer.write_string('${input.get_pos()}:${bits.bits}:${bits.count}:${int(bits.reader == copied.reader)}\n')
		return
	}
	mut data := []u8{len: capacity, init: 0xa5}
	mut output := p.WriteStream.init_memory(mut data)
	mut bits := p.BitWriter[E]{
		writer: &output
		bits:   raw
		count:  count
	}
	copied := bits
	writer.write_string('${copied.bits}:${copied.count}|')
	for _ in 0 .. repeats {
		mut status := 'ok'
		bits.flush_bits() or { status = err.msg() }
		writer.write_string('${status}:${output.get_pos()}:${bits.bits}:${bits.count}:${data.hex()}|')
	}
	writer.write_string('${copied.bits}:${copied.count}:${int(bits.writer == copied.writer)}\n')
}

fn main() {
	mut writer := strings.new_builder(64 * 1024)
	for line in os.read_lines(os.args[1]) or { panic(err) } {
		v := line.split('|').map(it.int())
		match v[1] {
			0 { run[p.LittleEndian](mut writer, v[0], u8(v[2]), u8(v[3]), v[4], v[5]) }
			1 { run[p.BigEndian](mut writer, v[0], u8(v[2]), u8(v[3]), v[4], v[5]) }
			2 { run[AliasLittle](mut writer, v[0], u8(v[2]), u8(v[3]), v[4], v[5]) }
			3 { run[AliasBig](mut writer, v[0], u8(v[2]), u8(v[3]), v[4], v[5]) }
			else { panic('invalid fixture order') }
		}
	}
	print(writer.str())
}
