module main

import crypto.sha256
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

fn numbers16(text string) []u16 {
	if text == '' { return []u16{} }
	return text.split(',').map(it.u16())
}

fn numbers32(text string) []u32 {
	if text == '' { return []u32{} }
	return text.split(',').map(it.u32())
}

fn optional(text string) ?[]u32 {
	if text == 'n' { return none }
	return numbers32(text[2..])
}

fn colors(text string) []p.Rgba32 {
	bytes := hex.decode(text) or { panic(err) }
	assert bytes.len % 4 == 0
	mut result := []p.Rgba32{}
	for i := 0; i < bytes.len; i += 4 {
		result << p.Rgba32{
			r: bytes[i]
			g: bytes[i + 1]
			b: bytes[i + 2]
			a: bytes[i + 3]
		}
	}
	return result
}

fn view(text string) (int, int) {
	f := text.split(':')
	return f[1].int(), f[2].int()
}

fn alias_words(data []u16, storage &[8]u16) int {
	if data.len == 0 { return -2 }
	for i in 0 .. 8 {
		if unsafe { voidptr(data.data) == voidptr(&storage[i]) } { return i }
	}
	return -1
}

fn alias_colors(data []p.Rgba32, storage &[256]p.Rgba32) int {
	if data.len == 0 { return -2 }
	for i in 0 .. 256 {
		if unsafe { voidptr(data.data) == voidptr(&storage[i]) } { return i }
	}
	return -1
}

fn color_words(values []p.Rgba32) string {
	mut result := []u8{}
	for c in values {
		result << [c.r, c.g, c.b, c.a]
	}
	return result.hex()
}

fn opt_words(value ?[]u32) string {
	if data := value { return 'a:' + data.map(it.str()).join(',') }
	return 'n'
}

fn state(b &p.TiffBitmapDescriptor) string {
	scalars := '${u16(b.compression)}:${b.image_width}:${b.image_height}:${b.photometric_interpretation}:${b.rows_per_strip}:${b.x_resolution[0]}:${b.x_resolution[1]}:${b.y_resolution[0]}:${b.y_resolution[1]}:${u16(b.resolution_unit)}:${b.new_subfile_type}:${b.samples_per_pixel}:${b.fill_order}:${b.planar_configuration}:${b.predictor};'
	bits := b.bits_per_sample.data.map(it.str()).join(',') +
		'@${alias_words(b.bits_per_sample.data, &b.bits_per_sample.storage)}:' +
		b.bits_per_sample.storage[..].map(it.str()).join(',') + ';'
	extra := b.extra_samples.data.map(it.str()).join(',') +
		'@${alias_words(b.extra_samples.data, &b.extra_samples.storage)}:' +
		b.extra_samples.storage[..].map(it.str()).join(',') + ';'
	palette := color_words(b.color_map.data) +
		'@${alias_colors(b.color_map.data, &b.color_map.storage)}:' +
		color_words(b.color_map.storage[..]) + ';'
	return sha256.hexhash(scalars + opt_words(b.strip_offsets) + ';' +
		opt_words(b.strip_byte_counts) + ';' + bits + extra + palette)
}

fn main() {
	mut capture := &Capture{}
	log.set_logger(capture)
	logger_level = if os.args[2] == '1' { log.Level.debug } else { log.Level.info }
	mut out := strings.new_builder(65536)
	for line in os.read_lines(os.args[1]) or { panic(err) } {
		f := line.split('|')
		assert f.len == 24
		mut b := p.TiffBitmapDescriptor{
			compression:                unsafe { p.TiffCompressionType(f[1].u16()) }
			image_width:                f[2].u32()
			image_height:               f[3].u32()
			photometric_interpretation: f[4].u16()
			rows_per_strip:             f[5].u32()
			x_resolution:               [f[6].u32(), f[7].u32()]!
			y_resolution:               [f[8].u32(), f[9].u32()]!
			resolution_unit:            unsafe { p.TiffResolutionUnit(f[10].u16()) }
			new_subfile_type:           f[11].u32()
			samples_per_pixel:          f[12].u16()
			fill_order:                 f[13].u16()
			planar_configuration:       f[14].u16()
			predictor:                  f[15].u16()
			strip_offsets:              optional(f[16])
			strip_byte_counts:          optional(f[17])
		}
		bits := numbers16(f[18])
		extra := numbers16(f[20])
		palette := colors(f[22])
		assert bits.len == 8 && extra.len == 8 && palette.len == 256
		for i, v in bits {
			b.bits_per_sample.storage[i] = v
		}
		for i, v in extra {
			b.extra_samples.storage[i] = v
		}
		for i, v in palette {
			b.color_map.storage[i] = v
		}
		if f[19].starts_with('e:') {
			b.bits_per_sample.data = numbers16(f[19][2..])
		} else {
			start, len := view(f[19])
			b.bits_per_sample.resize(8)
			b.bits_per_sample.data = unsafe { b.bits_per_sample.data[start..start + len] }
		}
		if f[21].starts_with('e:') {
			b.extra_samples.data = numbers16(f[21][2..])
		} else {
			start, len := view(f[21])
			b.extra_samples.resize(8)
			b.extra_samples.data = unsafe { b.extra_samples.data[start..start + len] }
		}
		if f[23].starts_with('e:') {
			b.color_map.data = colors(f[23][2..])
		} else {
			start, len := view(f[23])
			b.color_map.resize(256)
			b.color_map.data = unsafe { b.color_map.data[start..start + len] }
		}
		messages = []string{}
		before := state(&b)
		for _ in 0 .. f[0].int() {
			b.debug()
		}
		after := state(&b)
		out.write_string('${messages.len}|')
		for message in messages {
			out.write_string('debug:default:' + message.bytes().hex() + ';')
		}
		out.write_string('|' + before + '|' + after + '\n')
	}
	print(out.str())
}
