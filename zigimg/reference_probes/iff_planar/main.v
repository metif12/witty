module main

import os
import encoding.hex
import zigimg as p

__global (
	observed_path    string
	observed_reader  = &p.ReadStream(unsafe { nil })
	observed_source  []u8
	observed_output  []u8
	observed_backing []u8
)

fn state() string {
	return '${observed_reader.get_pos()}|${observed_source.hex()}|${observed_output.hex()}|${observed_backing.hex()}'
}

fn observe() {
	if observed_path != '' {
		os.write_file(observed_path, state()) or { eprintln('OBSERVER ERROR: ${err}') }
	}
}

fn line_case(line string) {
	f := line.split('|')
	mut source := hex.decode(f[9]) or { panic(err) }
	mut output := hex.decode(f[10]) or { panic(err) }
	mut backing := []u8{}
	if f[11] != '-' {
		backing = hex.decode(f[11]) or { panic(err) }
		source_offset := f[12].int()
		output_offset := f[13].int()
		source = unsafe { backing[source_offset..source_offset + source.len] }
		output = unsafe { backing[output_offset..output_offset + output.len] }
	}
	codec := p.IFF{
		format_id: unsafe { p.IffFormat(f[2].u8()) }
		header:    if f[1] == '0' {
			p.IffHeader(p.BmhdHeader{
				width:            f[3].u16()
				height:           f[4].u16()
				planes:           f[5].u8()
				compression_type: unsafe { p.IlbmCompressionType(f[6].u8()) }
			})
		} else {
			p.IffHeader(p.DgblHeader{ width: f[3].u16(), height: f[4].u16() })
		}
		pitch:     f[7].u16()
	}
	mut reader := p.ReadStream.init_memory(source)
	start := f[8].int()
	if start > 0 { reader.take(start) or { panic(err) } }
	observed_reader = &reader
	observed_source = unsafe { source[..] }
	observed_output = unsafe { output[..] }
	observed_backing = unsafe { backing[..] }
	if f[0] == '0' {
		codec.planar_to_chunky(source, mut output) or {
			println('${err.msg()}|' + state())
			return
		}
	} else {
		codec.decode_byte_run2(mut reader, mut output) or {
			println('${err.msg()}|' + state())
			return
		}
	}
	println('ok|' + state())
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
