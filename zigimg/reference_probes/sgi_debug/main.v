module main

import encoding.hex
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

fn scalar(h p.SgiHeader) string {
	return '${u8(h.compression)}:${h.bytes_per_channel}:${u16(h.dimension)}:${h.x_size}:${h.y_size}:${h.z_size}:${h.pix_min}:${h.pix_max}:${h.dummy1}:${h.image_name[..].hex()}:${u32(h.pixel_format)}:${h.dummy2[..].hex()}'
}

fn main() {
	mut capture := &Capture{}
	log.set_logger(capture)
	logger_level = if os.args[2] == '1' { log.Level.debug } else { log.Level.info }
	mut out := strings.new_builder(65536)
	for line in os.read_lines(os.args[1]) or { panic(err) } {
		f := line.split('|')
		name := hex.decode(f[11]) or { panic(err) }
		padding := hex.decode(f[12]) or { panic(err) }
		assert name.len == 80 && padding.len == 404
		mut h := p.SgiHeader{
			compression:       unsafe { p.SgiCompressionFlag(f[1].u8()) }
			bytes_per_channel: f[2].u8()
			dimension:         unsafe { p.SgiDimensions(f[3].u16()) }
			x_size:            f[4].u16()
			y_size:            f[5].u16()
			z_size:            f[6].u16()
			pix_min:           f[7].u32()
			pix_max:           f[8].u32()
			dummy1:            f[9].u32()
			pixel_format:      unsafe { p.SgiPixelFormat(f[10].u32()) }
		}
		for i, byte in name {
			h.image_name[i] = byte
		}
		for i, byte in padding {
			h.dummy2[i] = byte
		}
		messages = []string{}
		before := scalar(h)
		for _ in 0 .. f[0].int() {
			h.debug()
		}
		after := scalar(h)
		out.write_string('${messages.len}|')
		for message in messages {
			out.write_string('debug:default:' + message.bytes().hex() + ';')
		}
		out.write_string('|' + before + '|' + after + '\n')
	}
	print(out.str())
}
