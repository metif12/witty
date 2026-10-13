module main

import log
import os
import strings
import zigimg as p

__global (
	messages     []string
	logger_level log.Level
)
struct Capture {}

fn (value Capture) get_level() log.Level {
	return logger_level
}

fn (mut value Capture) set_level(level log.Level) {
	logger_level = level
}

fn (mut value Capture) set_always_flush(_ bool) {}

fn (mut value Capture) free() {}

fn (mut value Capture) fatal(_ string) {
	panic('unexpected fatal log')
}

fn (mut value Capture) error(_ string) {
	panic('unexpected error log')
}

fn (mut value Capture) warn(_ string) {
	panic('unexpected warning log')
}

fn (mut value Capture) info(_ string) {
	panic('unexpected info log')
}

fn (mut value Capture) debug(text string) {
	if logger_level == .debug { messages << text }
}

fn scalar_bmhd(h p.BmhdHeader) string {
	return '${h.width}:${h.height}:${h.x}:${h.y}:${h.planes}:${u8(h.mask_type)}:${u8(h.compression_type)}:${h.pad}:${h.transparent_color}:${h.x_asoect}:${h.y_aspect}:${h.page_width}:${h.page_height}'
}

fn scalar_dgbl(h p.DgblHeader) string {
	return '${h.width}:${h.height}:${u16(h.compression_type)}:${h.x_aspect}:${h.y_aspect}'
}

fn main() {
	mut capture := &Capture{}
	log.set_logger(capture)
	logger_level = if os.args[2] == '1' { log.Level.debug } else { log.Level.info }
	mut out := strings.new_builder(65536)
	for line in os.read_lines(os.args[1]) or { panic(err) } {
		f := line.split('|')
		messages = []string{}
		mut before := ''
		mut after := ''
		if f[0] == '0' {
			h := p.BmhdHeader{
				width:             f[2].u16()
				height:            f[3].u16()
				x:                 i16(f[4].i32())
				y:                 i16(f[5].i32())
				planes:            f[6].u8()
				mask_type:         unsafe { p.IffMaskType(f[7].u8()) }
				compression_type:  unsafe { p.IlbmCompressionType(f[8].u8()) }
				pad:               f[9].u8()
				transparent_color: f[10].u16()
				x_asoect:          f[11].u8()
				y_aspect:          f[12].u8()
				page_width:        f[13].u16()
				page_height:       f[14].u16()
			}
			before = scalar_bmhd(h)
			for _ in 0 .. f[1].int() {
				h.debug()
			}
			after = scalar_bmhd(h)
		} else {
			h := p.DgblHeader{
				width:            f[2].u16()
				height:           f[3].u16()
				compression_type: unsafe { p.DeepCompressionType(f[4].u16()) }
				x_aspect:         f[5].u8()
				y_aspect:         f[6].u8()
			}
			before = scalar_dgbl(h)
			for _ in 0 .. f[1].int() {
				h.debug()
			}
			after = scalar_dgbl(h)
		}
		out.write_string('${messages.len}|')
		for message in messages {
			out.write_string('debug:default:' + message.bytes().hex() + ';')
		}
		out.write_string('|' + before + '|' + after + '\n')
	}
	print(out.str())
}
