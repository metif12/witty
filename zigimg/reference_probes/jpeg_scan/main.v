module main

import encoding.hex
import os
import zigimg as p

__global (
	observed_frame  = &p.JpegFrame(unsafe { nil })
	observed_stream = &p.ReadStream(unsafe { nil })
	observed_path   string
)

fn block_hash(f &p.JpegFrame) u64 {
	mut hash := u64(14695981039346656037)
	for b in f.block_storage {
		for c in b.blocks {
			for value in c.values {
				for shift in [0, 8, 16, 24] {
					hash = (hash ^ u8(u32(value) >> shift)) * u64(1099511628211)
				}
			}
		}
	}
	return hash
}

fn observe() {
	mut state := '${observed_stream.get_pos()}'
	if observed_frame != unsafe { nil } { state += '|${block_hash(observed_frame)}' }
	os.write_file(observed_path, state) or { eprintln('OBSERVER ERROR: ${err}') }
}

fn table(symbol u8, cls u8) p.JpegHuffmanTable {
	return p.JpegHuffmanTable{
		code_counts: [16]u8{}
		code_map:    {
			u32(0): symbol
		}
		fast_table:  [512]u8{init: symbol}
		fast_size:   [512]u8{init: 1}
		table_class: cls
	}
}

fn scan_state(s &p.JpegScan) string {
	mut result := '${s.component_count},${s.start_of_spectral_selection},${s.end_of_spectral_selection},${s.approximation_high},${s.approximation_low}|'
	for entry in s.components {
		if c := entry {
			result += '${c.component_id},${c.dc_table_selector},${c.ac_table_selector};'
		} else {
			result += '-;'
		}
	}
	return result +
		'|${s.prediction_values[0]},${s.prediction_values[1]},${s.prediction_values[2]}|${s.reader.bit_buffer},${s.reader.bit_count},${u8(s.reader.table != none)},${s.reader.stream.get_pos()}|${s.frame.block_width}'
}

fn record(a []string) string {
	mut stream := p.ReadStream.init_memory(hex.decode(a[1]) or { panic(err) })
	if observed_path != '' { observed_stream = &stream }
	if a[0] == 'C' {
		c := p.JpegScanComponentSpec.read(mut stream) or {
			return 'E${err.msg()}|${stream.get_pos()}'
		}
		return '${c.component_id},${c.dc_table_selector},${c.ac_table_selector}|${stream.get_pos()}'
	}
	mut jpeg := p.JPEG.init()
	for i in 0 .. 4 {
		if a[4].u32() & (u32(1) << i) != 0 {
			jpeg.dc_huffman_tables.values[i] = table(u8(a[14].int()), 0)
		}
		if a[4].u32() & (u32(1) << (i + 4)) != 0 {
			jpeg.ac_huffman_tables.values[i] = table(u8(a[15].int()), 1)
		}
	}
	mut components := []p.JpegComponent{}
	if a[3] != '' {
		for id in a[3].split(',') {
			components << p.JpegComponent{
				id:                         u8(id.int())
				horizontal_sampling_factor: u8(a[12].int() >> 4)
				vertical_sampling_factor:   u8(a[12].int() & 15)
				quantization_table_id:      0
			}
		}
	}
	mut frame := p.JpegFrame{
		frame_header:                   p.JpegFrameHeader{
			sample_precision: 8
			width:            0
			height:           0
			components:       components
		}
		quantization_tables:            &jpeg.quantization_tables
		dc_huffman_tables:              &jpeg.dc_huffman_tables
		ac_huffman_tables:              &jpeg.ac_huffman_tables
		block_storage:                  []p.JpegBlockComponents{len: a[10].int()}
		frame_type:                     u16(a[2].int())
		block_width:                    u32(a[7].u64())
		block_height:                   u32(a[8].u64())
		block_width_actual:             u32(a[9].u64())
		block_height_actual:            4
		horizontal_sampling_factor_max: usize(a[5].u64())
		vertical_sampling_factor_max:   usize(a[6].u64())
	}
	for bi in 0 .. frame.block_storage.len {
		for ci in 0 .. 3 {
			for i in 0 .. 64 {
				frame.block_storage[bi].blocks[ci].values[i] = (bi * 13 + ci * 29 + i * 19) % 513 - 256
			}
		}
	}
	if observed_path != '' { observed_frame = &frame }
	if a[0] == 'P' {
		p.JpegScan.perform_scan(&frame, u16(a[11].int()), mut stream) or {
			return 'E${err.msg()}|${stream.get_pos()}|${block_hash(&frame)}'
		}
		return 'ok|${stream.get_pos()}|${block_hash(&frame)}'
	}
	mut scan := p.JpegScan.init(&frame, mut stream) or {
		return 'E${err.msg()}|${stream.get_pos()}'
	}
	if a[0] == 'I' {
		return scan_state(&scan) +
			'|${u8(scan.frame == &frame)},${u8(scan.reader.stream == &stream)}'
	}
	if a[0] != 'R' { panic('fixture operation') }
	mut copy := scan
	scan.component_count = u8(a[13].int())
	scan.start_of_spectral_selection = u8(a[13].int())
	scan.end_of_spectral_selection = u8(a[13].int())
	scan.approximation_high = u8(a[13].int() & 15)
	scan.approximation_low = u8(a[13].int() & 15)
	scan.prediction_values[0] = a[13].int() - 128
	scan.reader.bit_buffer = a[13].u32()
	scan.reader.bit_count = u8(a[13].int() & 31)
	// V unwraps optional struct values into a local copy. Write the modified
	// value back to its fixed slot to express Source's payload field update.
	if mut c := scan.components[0] {
		c.component_id = u8(a[13].int())
		scan.components[0] = c
	}
	frame.block_width = u32(a[13].int())
	copy.components[1] = none
	copy.prediction_values[1] = 42
	return scan_state(&scan) + '|' + scan_state(&copy) + '|${stream.get_pos()}'
}

fn main() {
	if os.args.len > 1 && os.args[1] == '--trap' {
		observed_path = os.args[2]
		at_exit(observe) or { panic(err) }
		println(record(os.args[3].split('|')))
		return
	}
	for line in os.read_lines(os.args[1]) or { panic(err) } {
		println(record(line.split('|')))
	}
}
