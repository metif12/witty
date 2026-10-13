module main

import log
import os
import strings
import zigimg as p

__global (
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

fn (mut value Capture) debug(_ string) {
	panic('RAS debug unexpectedly used the logger')
}

fn scalar(h p.RasHeader) string {
	return '${h.width}:${h.height}:${h.depth}:${h.length}:${u32(h.type_)}:${u32(h.color_map_type)}:${h.color_map_length}'
}

fn main() {
	mut capture := &Capture{}
	log.set_logger(capture)
	logger_level = if os.args[2] == '1' { log.Level.debug } else { log.Level.info }
	mut out := strings.new_builder(65536)
	for line in os.read_lines(os.args[1]) or { panic(err) } {
		f := line.split('|')
		assert f.len == 8
		h := p.RasHeader{
			width:            f[1].u32()
			height:           f[2].u32()
			depth:            f[3].u32()
			length:           f[4].u32()
			type_:            unsafe { p.RasType(f[5].u32()) }
			color_map_type:   unsafe { p.RasColorMapType(f[6].u32()) }
			color_map_length: f[7].u32()
		}
		before := scalar(h)
		for _ in 0 .. f[0].int() {
			h.debug()
		}
		out.write_string('${f[0]}|${before}|${scalar(h)}\n')
	}
	print(out.str())
}
