module main

import encoding.hex
import os
import zigimg as p

__global (
	observed_jpeg   = &p.JPEG(unsafe { nil })
	observed_pixels = &p.JpegPixels(unsafe { nil })
	observed_stream = &p.ReadStream(unsafe { nil })
	observed_known  bool
	observed_path   string
)

fn hash(bytes []u8) u64 {
	mut h := u64(14695981039346656037)
	for b in bytes {
		h = (h ^ b) * u64(1099511628211)
	}
	return h
}

fn block_hash(f p.JpegFrame) u64 {
	mut bytes := []u8{}
	for b in f.block_storage {
		for c in b.blocks {
			for v in c.values {
				for shift in [0, 8, 16, 24] {
					bytes << u8(u32(v) >> shift)
				}
			}
		}
	}
	return hash(bytes)
}

fn table_hash(t p.JpegHuffmanTable) u64 {
	mut bytes := [t.table_class]
	bytes << t.code_counts[..]
	bytes << t.fast_table[..]
	bytes << t.fast_size[..]
	mut keys := t.code_map.keys()
	keys.sort()
	for key in keys {
		for shift in [0, 8, 16, 24] {
			bytes << u8(key >> shift)
		}
		bytes << t.code_map[key]
	}
	return hash(bytes)
}

fn snapshot(jpeg &p.JPEG, pixels &p.JpegPixels, known bool) string {
	mut out := '${jpeg.restart_interval}|'
	if f := jpeg.frame {
		out += '${f.frame_header.width},${f.frame_header.height},${f.frame_header.components.len},${f.block_width},${f.block_height},${f.block_width_actual},${f.block_height_actual},${f.block_storage.len},'
		out += if known { '${block_hash(f)}' } else { '?' }
	} else {
		out += '-'
	}
	out += '|'
	for entry in jpeg.quantization_tables.values {
		if t := entry {
			if t is p.JpegQuantization8 {
				out += '0:${hash(t.values[..])};'
			} else if t is p.JpegQuantization16 {
				mut bytes := []u8{}
				for v in t.values {
					bytes << u8(v)
					bytes << u8(v >> 8)
				}
				out += '1:${hash(bytes)};'
			}
		} else {
			out += '-;'
		}
	}
	out += '|'
	for entry in jpeg.dc_huffman_tables.values {
		if t := entry {
			out += '${table_hash(t)};'
		} else {
			out += '-;'
		}
	}
	out += '|'
	for entry in jpeg.ac_huffman_tables.values {
		if t := entry {
			out += '${table_hash(t)};'
		} else {
			out += '-;'
		}
	}
	out += '|'
	if pix := pixels.value {
		out += '${pix.pixel_format()},${pix.len()},'
		out += if known || jpeg.frame == none { '${hash(pix.as_const_bytes())}' } else { '?' }
	} else {
		out += '-'
	}
	return out
}

fn observe() {
	out := '${observed_stream.get_pos()}|' +
		snapshot(observed_jpeg, observed_pixels, observed_known)
	os.write_file(observed_path, out) or { eprintln('OBSERVER ERROR: ${err}') }
}

fn initial_pixels(kind int, count int) p.JpegPixels {
	mut result := p.JpegPixels{}
	match kind {
		0 {}
		1 {
			result.value = p.InvalidPixels{}
		}
		2 {
			result.value = p.Grayscale8Pixels{
				data: []p.Grayscale8{len: count, init: p.Grayscale8{
					value: 17
				}}
			}
		}
		3 {
			result.value = p.Rgb24Pixels{
				data: []p.Rgb24{len: count, init: p.Rgb24{
					r: 17
					g: 18
					b: 19
				}}
			}
		}
		else {
			panic('pixel fixture')
		}
	}

	return result
}

fn record(a []string, file_path string) string {
	mut jpeg := p.JPEG.init()
	jpeg.restart_interval = u16(a[10].int())
	mut pixels := initial_pixels(a[8].int(), a[9].int())
	for i in 0 .. 4 {
		if a[6] == '1' { jpeg.quantization_tables.values[i] = p.JpegQuantization8{
				values: [64]u8{init: u8(a[7].int())}
			} }
		if a[6] == '2' { jpeg.quantization_tables.values[i] = p.JpegQuantization16{
				values: [64]u16{init: u16(a[7].int())}
			} }
		for cls in 0 .. 2 {
			if a[11].u32() & (u32(1) << (i + cls * 4)) == 0 { continue
			 }
			mut s := p.ReadStream.init_memory([u8(1), 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
				0, 42])
			t := p.JpegHuffmanTable.read(u8(cls), mut s) or { panic(err) }
			if cls == 0 {
				jpeg.dc_huffman_tables.values[i] = t
			} else {
				jpeg.ac_huffman_tables.values[i] = t
			}
		}
	}
	known := a[1] == '1'
	if known {
		mut components := []p.JpegComponent{}
		for i in 0 .. a[2].int() {
			components << p.JpegComponent{
				id:                         u8(i + 1)
				horizontal_sampling_factor: 1
				vertical_sampling_factor:   1
				quantization_table_id:      u8(i)
			}
		}
		bw, bh := (a[3].int() + 7) / 8, (a[4].int() + 7) / 8
		mut f := p.JpegFrame{
			frame_header:                   p.JpegFrameHeader{
				sample_precision: 8
				width:            u16(a[3].int())
				height:           u16(a[4].int())
				components:       components
			}
			quantization_tables:            &jpeg.quantization_tables
			dc_huffman_tables:              &jpeg.dc_huffman_tables
			ac_huffman_tables:              &jpeg.ac_huffman_tables
			block_storage:                  []p.JpegBlockComponents{len: bw * bh}
			frame_type:                     0xffc0
			block_width:                    u32(bw)
			block_height:                   u32(bh)
			block_width_actual:             u32(bw)
			block_height_actual:            u32(bh)
			horizontal_sampling_factor_max: 1
			vertical_sampling_factor_max:   1
		}
		for bi in 0 .. f.block_storage.len {
			for ci in 0 .. 3 {
				f.block_storage[bi].blocks[ci].values = [64]int{}
				f.block_storage[bi].blocks[ci].values[0] = a[5].int()
			}
		}
		jpeg.frame = f
	}
	if observed_path != '' {
		observed_jpeg = &jpeg
		observed_pixels = &pixels
		observed_known = known
	}
	mut out := ''
	for index, encoded in a[0].split(',') {
		if index > 0 && a[12] == '1' { pixels = initial_pixels(a[8].int(), a[9].int()) }
		bytes := hex.decode(encoded) or { panic(err) }
		mut buffer := []u8{len: a[13].int()}
		mut stream := p.ReadStream.init_memory(bytes)
		mut file := os.File{}
		if buffer.len > 0 {
			os.write_file_array(file_path, bytes) or { panic(err) }
			file = os.open(file_path) or { panic(err) }
			stream = p.ReadStream.init_file(file, mut buffer)
		}
		if observed_path != '' { observed_stream = &stream }
		mut status := 'ok'
		jpeg.read(mut stream, mut pixels) or { status = 'E${err.msg()}' }
		out += status + '|${stream.get_pos()}|' + snapshot(&jpeg, &pixels, known) + '~'
		if buffer.len > 0 { file.close() }
	}
	return out
}

fn main() {
	if os.args.len > 1 && os.args[1] == '--trap' {
		observed_path = os.args[2]
		at_exit(observe) or { panic(err) }
		println(record(os.args[3].split('|'), os.args[2] + '.bin'))
		return
	}
	for line in os.read_lines(os.args[1]) or { panic(err) } {
		println(record(line.split('|'), os.args[1] + '.bin'))
	}
}
