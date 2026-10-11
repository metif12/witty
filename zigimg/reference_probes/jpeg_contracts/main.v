module main

import zigimg as p
import encoding.hex
import os

__global (
	observed_stream = &p.ReadStream(unsafe { nil })
	observed_reader = &p.JpegHuffmanReader(unsafe { nil })
	observed_path   string
)

fn reader_state(r &p.JpegHuffmanReader) string {
	return '${r.bit_buffer},${r.bit_count},${r.stream.get_pos()}'
}

fn observe() {
	state := if observed_reader != unsafe { nil } {
		reader_state(observed_reader)
	} else {
		'${observed_stream.get_pos()}'
	}
	os.write_file(observed_path, state) or { eprintln('OBSERVER ERROR: ${err}') }
}

fn hash_bytes(bytes []u8) u64 {
	mut h := u64(14695981039346656037)
	for b in bytes {
		h = (h ^ b) * u64(1099511628211)
	}
	return h
}

fn table_state(t p.JpegHuffmanTable) string {
	mut out := '${t.table_class}|${hex.encode(t.code_counts[..])}|'
	mut keys := t.code_map.keys()
	keys.sort()
	for key in keys {
		out += '${key}:${t.code_map[key]},'
	}
	return out + '|${hex.encode(t.fast_table[..])}|${hex.encode(t.fast_size[..])}'
}

fn reader_op(mut r p.JpegHuffmanReader, op string, value u8) string {
	match op {
		'p' {
			v := r.peek_bits(value) or { return 'E${err.msg()}' }
			return '${v}'
		}
		'r' {
			v := r.read_bits(value) or { return 'E${err.msg()}' }
			return '${v}'
		}
		'f' {
			r.fill_bits(value) or { return 'E${err.msg()}' }
			return 'ok'
		}
		'c' {
			r.consume_bits(value)
			return 'ok'
		}
		'z' {
			r.flush_bits()
			return 'ok'
		}
		'm' {
			v := r.read_magnitude_coded(value) or { return 'E${err.msg()}' }
			return '${v}'
		}
		'h' {
			v := r.read_code() or { return 'E${err.msg()}' }
			return '${v}'
		}
		else {
			panic('invalid fixture operation')
		}
	}
}

fn record(a []string, id int, file_path string) string {
	bytes := hex.decode(a[2]) or { panic(err) }
	mut buffer := []u8{len: a[1].int()}
	mut stream := p.ReadStream.init_memory(bytes)
	mut file := os.File{}
	if buffer.len > 0 {
		os.write_file_array(file_path, bytes) or { panic(err) }
		file = os.open(file_path) or { panic(err) }
		stream = p.ReadStream.init_file(file, mut buffer)
	}
	defer {
		if buffer.len > 0 { file.close() }
	}
	if observed_path != '' { observed_stream = &stream }
	mut out := '${id}|'
	match a[0] {
		'F' {
			h := p.JpegFrameHeader.read(mut stream) or {
				return out + 'E${err.msg()}|${stream.get_pos()}\n'
			}
			out += '${h.sample_precision},${h.height},${h.width}|'
			for c in h.components {
				out += '${c.id},${c.horizontal_sampling_factor},${c.vertical_sampling_factor},${c.quantization_table_id};'
			}
			out += '|${h.max_horizontal_sampling_factor()},${h.max_vertical_sampling_factor()}'
		}
		'J' {
			h := p.JpegJfifHeader.read(mut stream) or {
				return out + 'E${err.msg()}|${stream.get_pos()}\n'
			}
			out += '${h.jfif_revision},${u8(h.density_unit)},${h.x_density},${h.y_density}'
		}
		'Q', 'X' {
			mut t := p.JpegQuantizationTable{}
			if a[0] == 'Q' {
				t = p.JpegQuantizationTable.read(u8(a[3].int()), mut stream) or {
					return out + 'E${err.msg()}|${stream.get_pos()}\n'
				}
			} else {
				h := p.JpegQuantizationHeader.read(mut stream) or {
					return out + 'E${err.msg()}|${stream.get_pos()}\n'
				}
				t = h.table
				out += '${h.table_precision},${h.table_destination}|'
			}
			out += '${t.precision}|'
			for i in 0 .. 64 {
				out += '${if t.precision == 0 { u16(t.q8[i]) } else { t.q16[i] }},'
			}
		}
		'T' {
			t := p.JpegHuffmanTable.read(u8(a[3].int()), mut stream) or {
				return out + 'E${err.msg()}|${stream.get_pos()}\n'
			}
			out += table_state(t)
		}
		'R', 'B' {
			mut r := p.JpegHuffmanReader.init(mut stream)
			r.bit_buffer = a[3].u32()
			r.bit_count = u8(a[4].int())
			mut t := p.JpegHuffmanTable{
				fast_table: [512]u8{init: 255}
			}
			if a[0] == 'B' {
				t.fast_table[0] = u8(a[6].int())
				t.fast_size[0] = 1
				r.set_huffman_table(&t)
				// This replacement must be visible through the borrowed pointer.
				t.fast_table[0] = u8(a[7].int())
			}
			for command in a[5].split(',') {
				out += reader_op(mut r, command[..1], u8(command[1..].int())) + ':' +
					reader_state(&r) + ';'
			}
		}
		'D' {
			mut jpeg := p.JPEG.init()
			mut pixels := p.JpegPixels{
				value: p.Grayscale8Pixels{
					data: [p.Grayscale8{ value: 17 }]
				}
			}
			frame := jpeg.read(mut stream, mut pixels) or {
				return out +
					'E${err.msg()}|${u8(pixels.value != none)},${u8(jpeg.frame != none)}|${stream.get_pos()}\n'
			}
			decoded := pixels.value or { panic('UNEXPECTED no pixels') }
			out += '${frame.frame_header.width},${frame.frame_header.height},${decoded.pixel_format()}|${hash_bytes(decoded.as_bytes()):016x}'
		}
		else {
			panic('invalid fixture record')
		}
	}

	return out + '|${stream.get_pos()}\n'
}

fn trap(name string, path string, op string, bytes []u8, value u8) {
	mut stream := p.ReadStream.init_memory(bytes)
	mut r := p.JpegHuffmanReader.init(mut stream)
	observed_stream = &stream
	observed_path = path
	at_exit(observe) or { panic(err) }
	if op == 'R' {
		observed_reader = &r
		if name == 'fill_overflow' {
			r.bit_count = 24
			r.bit_buffer = 0x12345600
			r.fill_bits(25) or { panic('UNEXPECTED ${err}') }
		} else if name == 'fill_shift' {
			r.bit_count = 25
			r.fill_bits(26) or { panic('UNEXPECTED ${err}') }
		} else if name == 'consume' {
			r.consume_bits(1)
		} else if name == 'consume17' {
			r.bit_count = 24
			r.consume_bits(17)
		} else if name == 'missing_table' {
			r.read_code() or { panic('UNEXPECTED ${err}') }
		} else {
			r.peek_bits(value) or { panic('UNEXPECTED ${err}') }
		}
	} else {
		_ = record([op, '0', hex.encode(bytes), '${value}'], 0, '')
	}
	panic('UNEXPECTED returning trap')
}

fn main() {
	if os.args.len > 2 && os.args[1] == '--trap' {
		bytes := hex.decode(os.args[5]) or { panic(err) }
		trap(os.args[2], os.args[3], os.args[4], bytes, u8(os.args[6].int()))
		return
	}
	input := os.read_file(os.args[1]) or { panic(err) }
	for id, line in input.split_into_lines() {
		if line != '' { print(record(line.split('|'), id, os.args[1] + '.jpg')) }
	}
}
