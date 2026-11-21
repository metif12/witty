module main

import os
import encoding.hex
import zigimg as p

__global (
	observed_path    string
	observed_reader  = &p.ReadStream(unsafe { nil })
	observed_writer  = &p.WriteStream(unsafe { nil })
	observed_codec   = &p.CcittDecoder(unsafe { nil })
	observed_input   []u8
	observed_output  []u8
	observed_segment int
)
fn codec_state(codec &p.CcittDecoder) string {
	return '${int(codec.current_color)}:${int(codec.should_reverse)}:${codec.width}:${codec.num_rows}:${codec.white_value}'
}

fn state() string {
	codec := if observed_codec != unsafe { nil } { codec_state(observed_codec) } else { '-' }
	return '${observed_segment}|${observed_reader.get_pos()}|${observed_writer.get_pos()}|${codec}|${observed_input.hex()}|${observed_output.hex()}'
}

fn observe() {
	if observed_path != '' { os.write_file(observed_path, state()) or {
			eprintln('OBSERVER ERROR: ${err}')} }
}

fn code_state(code p.CcittCode) string {
	return '${code.run_length}:${code.code}:${code.code_length}'
}

fn tables() {
	mut hash := u64(14695981039346656037)
	mut count := 0
	for table in [p.ccitt_white_terminating_codes[..], p.ccitt_black_terminating_codes[..], p.ccitt_white_make_up_codes[..],
		p.ccitt_black_make_up_codes[..], p.ccitt_additional_make_up_codes[..]] {
		for item in table {
			for byte in [u8(item.run_length), u8(item.run_length >> 8), u8(item.code),
				u8(item.code >> 8), item.code_length] {
				hash = (hash ^ byte) * u64(1099511628211)
			}
			count++
		}
	}
	println('${count}:${hash}')
}

fn line_case(line string) {
	f := line.split('|')
	observed_codec = unsafe { nil }
	observed_input = []u8{}
	observed_segment = 0
	if f[0] == '4' {
		mut original := p.CcittCode{
			run_length:  f[6].u16()
			code:        f[1].u16()
			code_length: f[7].u8()
		}
		mut copied := original
		copied.run_length ^= 65535
		copied.code ^= 43690
		copied.code_length ^= 255
		before := code_state(original) + '|' + code_state(copied)
		original.code ^= 21845
		println(before + '|' + code_state(original) + '|' + code_state(copied))
		return
	}
	if f[0] == '5' {
		tables()
		return
	}
	if f[0] == '7' {
		mut original := p.CcittDecoder{}
		mut copied := original
		copied.width = uint(f[1].u64())
		copied.num_rows = uint(f[2].u64())
		copied.white_value = f[3].u8()
		copied.current_color = if f[4] == '0' { p.CcittColor.black } else { p.CcittColor.white }
		copied.should_reverse = f[5] == '1'
		before := codec_state(&original) + '|' + codec_state(&copied)
		original.width = 17
		println(before + '|' + codec_state(&original) + '|' + codec_state(&copied))
		return
	}
	mut output := []u8{len: f[8].int(), init: 0xa5}
	mut writer := p.WriteStream.init_memory(mut output)
	mut reader := p.ReadStream.init_memory([]u8{})
	observed_reader = &reader
	observed_writer = &writer
	observed_output = unsafe { output[..] }
	if f[11].u64() > 0 { writer.seek_to(f[11].u64()) or { panic(err) } }
	mut codec := p.CcittDecoder.init(uint(f[1].u64()), uint(f[2].u64()), f[3].u8()) or {
		panic(err)
	}
	observed_codec = &codec
	if f[0] == '6' {
		println('ok|' + state())
		return
	}
	codec.current_color = if f[4] == '0' { p.CcittColor.black } else { p.CcittColor.white }
	codec.should_reverse = f[5] == '1'
	if f[0] != '3' {
		result := match f[0] {
			'0' { codec.get_make_up_code(f[6].u16(), f[7].u8()) }
			'1' { codec.get_terminating_code(f[6].u16(), f[7].u8()) }
			else { codec.get_run_length(f[6].u16(), f[7].u8()) }
		}

		value := if run := result { run.str() } else { '-' }
		println(value + '|' + state())
		return
	}
	mut results := []string{}
	for index, part in f[9].split(',') {
		mut data := hex.decode(part) or { panic(err) }
		reader = p.ReadStream.init_memory(data)
		if index == 0 && f[10].int() > 0 { reader.take(f[10].int()) or { panic(err) } }
		observed_input = unsafe { data[..] }
		observed_segment = index
		mut status := 'ok'
		codec.decode(mut reader, mut writer) or { status = err.msg() }
		results << status + '|' + state()
	}
	println(results.join('~'))
}

fn main() {
	if os.args[1] == '--corpus' {
		for line in os.read_lines(os.args[2]) or { panic(err) } {
			line_case(line)
		}
	} else {
		observed_path = os.args[2]
		at_exit(observe) or { panic(err) }
		line_case(os.args[3])
	}
}
