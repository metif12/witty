module main

import zigimg as p
import os

fn component(c p.JpegComponent) string {
	return '${c.id},${c.horizontal_sampling_factor},${c.vertical_sampling_factor},${c.quantization_table_id}'
}

fn table(t p.JpegQuantizationTable) string {
	mut out := ''
	match t {
		p.JpegQuantization8 {
			out = '0|'
			for v in t.values {
				out += '${v},'
			}
		}
		p.JpegQuantization16 {
			out = '1|'
			for v in t.values {
				out += '${v},'
			}
		}
	}

	return out
}

fn boxed() {
	for seed in [u16(0), 1, 255, 256, 32768, 65535] {
		mut q8 := p.JpegQuantizationTable(p.JpegQuantization8{
			values: [64]u8{init: u8(seed)}
		})
		copy8 := q8
		if mut q8 is p.JpegQuantization8 { q8.values[0] = 33 }
		println('Q8|${seed}|${table(q8)}|${table(copy8)}')
		mut q16 := p.JpegQuantizationTable(p.JpegQuantization16{
			values: [64]u16{init: seed}
		})
		copy16 := q16
		if mut q16 is p.JpegQuantization16 { q16.values[0] = 33 }
		println('Q16|${seed}|${table(q16)}|${table(copy16)}')
		mut h := p.JpegQuantizationHeader{
			table_precision:   0
			table_destination: 3
			table:             p.JpegQuantization8{
				values: [64]u8{init: u8(seed)}
			}
		}
		h_copy := h
		if mut h.table is p.JpegQuantization8 { h.table.values[1] = 17 }
		println('H|${seed}|${table(h.table)}|${table(h_copy.table)}')
	}
}

fn main() {
	if os.args.len == 2 && os.args[1] == '--boxed' {
		boxed()
		return
	}
	for id in [u8(0), 1, 255] {
		for sampling in 0 .. 256 {
			for destination in [u8(0), 3, 4, 255] {
				bytes := [id, u8(sampling), destination]
				for length in 0 .. 4 {
					mut stream := p.ReadStream.init_memory(bytes[..length])
					c := p.JpegComponent.read(mut stream) or {
						println('C|${id}|${sampling}|${destination}|${length}|E${err.msg()}|${stream.get_pos()}')
						continue
					}
					println('C|${id}|${sampling}|${destination}|${length}|${component(c)}|${stream.get_pos()}')
				}
			}
		}
	}
	for id in [u8(0), 1, 255] {
		for horizontal in 0 .. 16 {
			for vertical in 0 .. 16 {
				for destination in [u8(0), 3, 4, 255] {
					mut c := p.JpegComponent{
						id:                         id
						horizontal_sampling_factor: u8(horizontal)
						vertical_sampling_factor:   u8(vertical)
						quantization_table_id:      destination
					}
					c_copy := c
					c.id = 17
					mut components := [c, c_copy]
					mut h := p.JpegFrameHeader{
						sample_precision: id
						height:           65535
						width:            1
						components:       components
					}
					h_copy := h
					components[0].horizontal_sampling_factor = 15
					h.components[1].vertical_sampling_factor = 14
					h.sample_precision = 8
					h.height = 7
					h.width = 9
					h.components = h.components[..1]
					println('M|${id}|${horizontal}|${vertical}|${destination}|${component(c_copy)}|${h.sample_precision},${h.height},${h.width},${h.components.len},${h.max_horizontal_sampling_factor()},${h.max_vertical_sampling_factor()}|${h_copy.sample_precision},${h_copy.height},${h_copy.width},${h_copy.components.len},${h_copy.max_horizontal_sampling_factor()},${h_copy.max_vertical_sampling_factor()}|${component(components[0])}|${component(components[1])}')
				}
			}
		}
	}
	for seed in [u16(0), 1, 255, 256, 32768, 65535] {
		for index in 0 .. 64 {
			mut q8 := p.JpegQuantizationTable(p.JpegQuantization8{
				values: [64]u8{init: u8(seed)}
			})
			if mut q8 is p.JpegQuantization8 { q8.values[index] = 33 }
			copy8 := q8
			q8 = p.JpegQuantization16{
				values: [64]u16{init: seed}
			}
			println('Q8|${seed}|${index}|${table(copy8)}|${table(q8)}')
			mut q16 := p.JpegQuantizationTable(p.JpegQuantization16{
				values: [64]u16{init: seed}
			})
			if mut q16 is p.JpegQuantization16 { q16.values[index] = 33 }
			copy16 := q16
			q16 = p.JpegQuantization8{
				values: [64]u8{init: u8(seed)}
			}
			println('Q16|${seed}|${index}|${table(copy16)}|${table(q16)}')
		}
		for precision in 0 .. 16 {
			for destination in 0 .. 16 {
				mut h := p.JpegQuantizationHeader{
					table_precision:   u8(precision)
					table_destination: u8(destination)
					table:             p.JpegQuantization8{
						values: [64]u8{init: u8(seed)}
					}
				}
				copy := h
				h.table_precision = 1
				h.table_destination = 3
				h.table = p.JpegQuantization16{
					values: [64]u16{init: seed}
				}
				println('H|${seed}|${precision}|${destination}|${copy.table_precision},${copy.table_destination},${table(copy.table)}|${h.table_precision},${h.table_destination},${table(h.table)}')
			}
		}
		for unit in 0 .. 3 {
			mut h := p.JpegJfifHeader{
				jfif_revision: seed
				density_unit:  unsafe { p.JpegDensityUnit(unit) }
				x_density:     seed
				y_density:     65535
			}
			copy := h
			h.jfif_revision = 0x102
			h.density_unit = .dots_per_cm
			h.x_density = 72
			h.y_density = 96
			println('J|${seed}|${unit}|${copy.jfif_revision},${u8(copy.density_unit)},${copy.x_density},${copy.y_density}|${h.jfif_revision},${u8(h.density_unit)},${h.x_density},${h.y_density}')
		}
	}
	for value in [u8(0), 1, 17, 254] {
		for length in 0 .. 16 {
			mut t := p.JpegHuffmanTable{
				code_counts: [16]u8{}
				code_map:    map[u32]u8{}
				fast_table:  [512]u8{init: 255}
				fast_size:   [512]u8{}
				table_class: 0
			}
			t.code_counts[length] = 1
			t.code_map[u32(length) << 16] = value
			t.table_class = 1
			copy := t
			t.code_counts[length] = 7
			t.fast_table[0] = value
			t.fast_size[0] = 9
			t.table_class = 0
			mut stream := p.ReadStream.init_memory([u8(0), 0])
			mut reader := p.JpegHuffmanReader.init(mut stream)
			reader.set_huffman_table(&t)
			t.code_map[u32(length) << 16] = 42
			t.fast_table[0] = 77
			decoded := reader.read_code() or { panic(err) }
			println('T|${value}|${length}|${copy.code_counts[length]},${copy.fast_table[0]},${copy.fast_size[0]},${copy.table_class},${copy.code_map[u32(length) << 16]}|${t.code_counts[length]},${t.fast_table[0]},${t.fast_size[0]},${t.table_class}|${decoded},${reader.bit_count},${stream.get_pos()}')
		}
	}
	mut empty := p.JpegFrameHeader{
		sample_precision: 0
		height:           0
		width:            0
		components:       []p.JpegComponent{}
	}
	println('E|${empty.max_horizontal_sampling_factor()},${empty.max_vertical_sampling_factor()}')
	empty.deinit()
}
