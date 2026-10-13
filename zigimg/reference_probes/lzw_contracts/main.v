module main

import os
import encoding.hex
import zigimg as p

__global (
	observed_path    string
	observed_little  = &p.LzwDecoder[p.LittleEndian](unsafe { nil })
	observed_big     = &p.LzwDecoder[p.BigEndian](unsafe { nil })
	observed_reader  = &p.ReadStream(unsafe { nil })
	observed_writer  = &p.WriteStream(unsafe { nil })
	observed_output  []u8
	observed_input   []u8
	observed_segment int
	observed_endian  int
)

fn dictionary_hash[E](codec &p.LzwDecoder[E]) u64 {
	mut keys := codec.dictionary.keys()
	keys.sort()
	mut hash := u64(14695981039346656037)
	for key in keys {
		value := codec.dictionary[key]
		for number in [u64(key), u64(value.len)] {
			for shift in 0 .. 8 { hash = (hash ^ u8(number >> (shift * 8))) * u64(1099511628211) }
		}
		for byte in value { hash = (hash ^ byte) * u64(1099511628211) }
	}
	return hash
}

fn codec_state[E](codec &p.LzwDecoder[E]) string {
	previous := if value := codec.previous_code { value.str() } else { '-' }
	remaining := if value := codec.remaining_data { value.str() } else { '-' }
	return '${codec.code_size}:${codec.clear_code}:${codec.initial_code_size}:${codec.end_information_code}:${codec.next_code}:${previous}:${remaining}:${codec.remaining_bits}:${codec.early_change}:${codec.dictionary.len}:${dictionary_hash(codec)}'
}

fn state() string {
	mut codec := '-'
	if observed_endian == 0 && observed_little != unsafe { nil } {
		codec = codec_state(observed_little)
	}
	if observed_endian == 1 && observed_big != unsafe { nil } { codec = codec_state(observed_big) }
	return '${observed_segment}|${observed_reader.get_pos()}|${observed_writer.get_pos()}|${codec}|${observed_input.hex()}|${observed_output.hex()}'
}

fn observe() {
	if observed_path != '' {
		os.write_file(observed_path, state()) or { eprintln('OBSERVER ERROR: ${err}') }
	}
}

fn run_case[E](f []string) {
	mut output := []u8{len: f[10].int(), init: 0xa5}
	mut writer := p.WriteStream.init_memory(mut output)
	mut reader := p.ReadStream.init_memory([]u8{})
	if f[14].int() > 0 { writer.seek_to(f[14].u64()) or { panic(err) } }
	observed_reader = &reader
	observed_writer = &writer
	observed_output = unsafe { output[..] }
	mut codec := p.lzw_decoder_init[E](f[1].u8(), f[2].u8()) or { panic(err) }
	$if E is p.LittleEndian {
		observed_little = &codec
	} $else {
		observed_big = &codec
	}
	if f[3] != '-1' { codec.code_size = f[3].u8() }
	if f[4] != '-1' { codec.next_code = f[4].u16() }
	if f[5] != '-1' { codec.previous_code = f[5].u16() }
	if f[6] != '-1' { codec.remaining_data = f[6].u16() }
	if f[7] != '-1' { codec.remaining_bits = f[7].u8() }
	if f[8] != '-1' { codec.initial_code_size = f[8].u8() }
	mut borrowed := [u8(0xa5), 0x5a]
	if f[9] == '1' { codec.dictionary[0] = []u8{} }
	if f[9] == '2' { codec.dictionary[1] = []u8{} }
	if f[9] == '3' {
		codec.dictionary[0] = unsafe { borrowed[..] }
		borrowed[0] ^= 85
	}
	if f[12] == '0' {
		println('ok|' + state())
		return
	}
	mut results := []string{}
	for index, part in f[11].split(',') {
		mut data := hex.decode(part) or { panic(err) }
		reader = p.ReadStream.init_memory(data)
		if index == 0 && f[13].int() > 0 { reader.take(f[13].int()) or { panic(err) } }
		observed_segment = index
		observed_input = unsafe { data[..] }
		codec.decode(mut reader, mut writer) or {
			results << '${err.msg()}|' + state()
			println(results.join('~'))
			return
		}
		results << 'ok|' + state()
	}
	println(results.join('~'))
}

fn line_case(line string) {
	f := line.split('|')
	observed_endian = f[0].int()
	observed_little = unsafe { nil }
	observed_big = unsafe { nil }
	observed_input = []u8{}
	observed_segment = 0
	if observed_endian == 0 { run_case[p.LittleEndian](f) } else { run_case[p.BigEndian](f) }
}

fn main() {
	if os.args[1] == '--corpus' {
		for line in os.read_lines(os.args[2]) or { panic(err) } { line_case(line) }
	} else {
		observed_path = os.args[2]
		at_exit(observe) or { panic(err) }
		line_case(os.args[3])
	}
}
