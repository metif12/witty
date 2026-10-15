module main

import os
import strconv
import zigimg as p

fn spec(value p.FormatSpecifier) string {
	return match value {
		p.FormatNone { '-' }
		p.FormatNumber { 'n:${value.value}' }
		p.FormatNamed { 's:' + value.bytes.hex() }
	}
}

fn state(value p.FormatPlaceholder) string {
	return value.specifier_arg.hex() + '|${value.fill}:${int(value.alignment)}|' + spec(value.arg) +
		'|' + spec(value.width) + '|' + spec(value.precision)
}

fn bytes(text string) []u8 {
	mut data := []u8{}
	for i := 0; i < text.len; i += 2 {
		data << u8(strconv.parse_uint(text[i..i + 2], 16, 8) or { panic(err) })
	}
	return data
}

fn main() {
	for line in os.read_lines(os.args[1]) or { panic(err) } {
		mut data := bytes(line)
		value := p.FormatPlaceholder.parse(data) or {
			println('error|' + err.msg().bytes().hex())
			continue
		}
		before := state(value)
		for i in 0 .. data.len {
			data[i] ^= 0x5a
		}
		println(line + '|' + before + '~' + data.hex() + '|' + state(value))
	}
}
