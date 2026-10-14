module main

import os
import encoding.hex
import zigimg as p

__global (
	observed_codec = &p.GIF(unsafe { nil })
	observed_path  string
)

fn info_text(info p.GifApplicationExtension) string {
	return '${info.application_identifier[..].hex()}${info.authentification_code[..].hex()}:${info.data.hex()}'
}

fn snapshot(codec &p.GIF) string {
	mut out := '${codec.application_infos.len}|'
	for info in codec.application_infos {
		out += info_text(info) + ';'
	}
	return out
}

fn observe() {
	os.write_file(observed_path, snapshot(observed_codec)) or { eprintln('OBSERVER ERROR: ${err}') }
}

fn record(line string) string {
	f := line.split('|')
	op := f[0].int()
	index := f[1].int()
	mut codec := p.GIF.init()
	for text in f[2].split(';') {
		if text == '' { continue
		 }
		raw := hex.decode(text) or { panic(err) }
		codec.application_infos << p.GifApplicationExtension{
			application_identifier: [raw[0], raw[1], raw[2], raw[3], raw[4], raw[5], raw[6], raw[7]]!
			authentification_code:  [raw[8], raw[9], raw[10]]!
			data:                   raw[11..].clone()
		}
	}
	observed_codec = &codec
	mut out := '${codec.loop_count()}|'
	if op == 1 {
		mut data := unsafe { codec.application_infos[index].data }
		data[0] ^= 85
		out += '${codec.loop_count()}|'
		data[1] ^= 51
		data[2] ^= 119
		out += '${codec.loop_count()}|'
	} else if op == 2 {
		mut copy := codec.application_infos[index]
		copy.application_identifier[0] ^= 85
		copy.authentification_code[0] ^= 51
		copy.data[1] ^= 51
		out += '${codec.loop_count()}|${info_text(copy)}|'
	}
	return out + snapshot(&codec)
}

fn main() {
	if os.args[1] == '--trap' {
		observed_path = os.args[2]
		at_exit(observe) or { panic(err) }
		println(record(os.args[3]))
		return
	}
	for line in (os.read_file(os.args[1]) or { panic(err) }).split_into_lines() {
		if line != '' { println(record(line)) }
	}
}
