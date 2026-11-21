module main

import zigimg as p
import encoding.hex
import os

@[heap]
struct Pixels {
mut:
	value p.PixelStorage
}

__global (
	observed_frame  = &p.JpegFrame(unsafe { nil })
	observed_stream = &p.ReadStream(unsafe { nil })
	observed_pixels = &Pixels(unsafe { nil })
	observed_path   string
)

fn hash(bytes []u8) u64 {
	mut h := u64(14695981039346656037)
	for b in bytes {
		h = (h ^ b) * u64(1099511628211)
	}
	return h
}

fn blocks_hash(blocks []p.JpegBlockComponents) u64 {
	mut bytes := []u8{}
	for b in blocks {
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

fn state(f &p.JpegFrame) string {
	return '${f.frame_header.width},${f.frame_header.height},${f.frame_header.components.len},${f.frame_type},${f.block_width},${f.block_height},${f.block_width_actual},${f.block_height_actual},${f.horizontal_sampling_factor_max},${f.vertical_sampling_factor_max},${f.block_storage.len}'
}

fn observe() {
	mut out := '${observed_stream.get_pos()}'
	if observed_frame != unsafe { nil } {
		out += '|${state(observed_frame)}|${blocks_hash(observed_frame.block_storage)}'
	}
	if observed_pixels != unsafe { nil } {
		out += '|${hash(observed_pixels.value.as_const_bytes())}'
	}
	os.write_file(observed_path, out) or { eprintln('OBSERVER ERROR: ${err}') }
}

fn initialized_blocks(count int, seed int, rgb bool) []p.JpegBlockComponents {
	mut blocks := []p.JpegBlockComponents{len: count}
	for bi in 0 .. count {
		for ci in 0 .. 3 {
			for i in 0 .. 64 {
				blocks[bi].blocks[ci].values[i] = if rgb {
					(seed * 17 + bi * 13 + ci * 29 + i * 19) % 256
				} else {
					(seed * 17 + bi * 13 + ci * 29 + i * 19) % 513 - 256
				}
			}
		}
	}
	return blocks
}

fn record(a []string) string {
	mut q := p.JpegQuantizationTables{
		values: unsafe { [4]?p.JpegQuantizationTable{init: none} }
	}
	mut dc := p.JpegHuffmanTables{
		values: [4]?p.JpegHuffmanTable{init: none}
	}
	mut ac := p.JpegHuffmanTables{
		values: [4]?p.JpegHuffmanTable{init: none}
	}
	mut stream := p.ReadStream.init_memory(hex.decode(a[1]) or { panic(err) })
	if observed_path != '' { observed_stream = &stream }
	if a[0] == 'J' {
		mut jpeg := p.JPEG.init()
		mut pixels := p.JpegPixels{}
		mut returned := jpeg.read(mut stream, mut pixels) or {
			return 'E${err.msg()}|${stream.get_pos()}'
		}
		copied := returned
		returned.frame_header.width++
		returned.block_width++
		if returned.block_storage.len > 0 { returned.block_storage[0].blocks[0].values[0] = 42 }
		stored := jpeg.frame or { panic('frame') }
		jpeg.quantization_tables.values[0] = none
		return '${state(&returned)}|${state(&copied)}|${state(&stored)}|${if stored.block_storage.len > 0 {
			stored.block_storage[0].blocks[0].values[0]
		} else {
			0
		}}|${u8(returned.quantization_tables.values[0] != none)}|${stream.get_pos()}'
	}
	if a[0] == 'F' {
		mut f := p.JpegFrame.read(u16(a[2].int()), &q, &dc, &ac, mut stream) or {
			return 'E${err.msg()}|${stream.get_pos()}'
		}
		out := '${state(&f)}|${stream.get_pos()}'
		f.deinit()
		return out
	}
	mut components := []p.JpegComponent{}
	for i in 0 .. a[2].int() {
		components << p.JpegComponent{
			id:                         u8(i + 1)
			horizontal_sampling_factor: u8(if a[6].u64() > 15 { u64(15) } else { a[6].u64() })
			vertical_sampling_factor:   u8(if a[7].u64() > 15 { u64(15) } else { a[7].u64() })
			quantization_table_id:      u8(i)
		}
	}
	mut f := p.JpegFrame{
		frame_header:                   p.JpegFrameHeader{
			sample_precision: 8
			width:            u16(a[3].int())
			height:           u16(a[4].int())
			components:       components
		}
		quantization_tables:            &q
		dc_huffman_tables:              &dc
		ac_huffman_tables:              &ac
		block_storage:                  initialized_blocks(a[5].int(), if a[0] in [
			'D',
			'I',
		] {
			0
		} else {
			a[8].int()
		}, a[0] == 'R')
		frame_type:                     0xffc0
		block_width:                    u32(a[9].u64())
		block_height:                   u32(a[10].u64())
		block_width_actual:             u32(a[11].u64())
		block_height_actual:            u32(a[12].u64())
		horizontal_sampling_factor_max: uint(a[6].u64())
		vertical_sampling_factor_max:   uint(a[7].u64())
	}
	if observed_path != '' { observed_frame = &f }
	mut pixels := Pixels{
		value: p.InvalidPixels{}
	}
	if a[0] in ['R', 'A'] { pixels.value = p.Rgb24Pixels{
			data: []p.Rgb24{len: a[13].int(), init: p.Rgb24{
				r: 17
				g: 18
				b: 19
			}}
		} }
	if a[0] == 'G' { pixels.value = p.Grayscale8Pixels{
			data: []p.Grayscale8{len: a[13].int(), init: p.Grayscale8{
				value: 17
			}}
		} }
	if observed_path != '' { observed_pixels = &pixels }
	match a[0] {
		'B' {
			if a[15] == '1' {
				f.ycbcr_to_rgb_block(mut f.block_storage[0], &f.block_storage[0],
					uint(a[13].u64()), uint(a[14].u64()))
			} else {
				f.ycbcr_to_rgb_block(mut f.block_storage[0], &f.block_storage[1],
					uint(a[13].u64()), uint(a[14].u64()))
			}
		}
		'C' {
			f.ycbcr_to_rgb() or { return 'E${err.msg()}' }
		}
		'D', 'I' {
			for bi in 0 .. f.block_storage.len {
				for ci in 0 .. 3 {
					for i in 0 .. 64 {
						f.block_storage[bi].blocks[ci].values[i] = if i == 0 {
							a[8].int()
						} else {
							0
						}
					}
				}
			}
			for i in 0 .. 4 {
				q.values[i] = p.JpegQuantization8{
					values: [64]u8{init: u8(a[13].int())}
				}
			}
			if a[0] == 'D' {
				f.dequantize_blocks() or { return 'E${err.msg()}|${blocks_hash(f.block_storage)}' }
			} else {
				f.idct_blocks()
			}
		}
		'R' {
			if a.len > 14 {
				f.block_storage[0].blocks[a[14].int()].values[a[15].int()] = a[16].int()
			}
			mut rgb := pixels.value as p.Rgb24Pixels
			f.render_to_pixels_rgb(mut rgb.data) or { return 'E${err.msg()}' }
		}
		'G' {
			if a.len > 14 { f.block_storage[0].blocks[0].values[a[14].int()] = a[15].int() }
			f.render_to_pixels(mut pixels.value) or { return 'E${err.msg()}' }
		}
		'A' {
			f.render_to_pixels(mut pixels.value) or { return 'E${err.msg()}' }
		}
		'U' {
			f.render_to_pixels(mut pixels.value) or { return 'E${err.msg()}' }
		}
		'N' {
			mut copy := f
			f.frame_header.width = 7
			f.block_width = 11
			q.values[0] = p.JpegQuantization8{
				values: [64]u8{init: 1}
			}
			f.block_storage[0].blocks[0].values[0] = 42
			mut jpeg := p.JPEG.init()
			jpeg.frame = f
			jpeg.quantization_tables.values[0] = p.JpegQuantization8{
				values: [64]u8{init: 1}
			}
			old := jpeg
			jpeg.restart_interval = 9
			jpeg.quantization_tables.values[0] = none
			returned := jpeg.frame or { panic('frame') }
			copy.frame_header.height = 9
			return '${state(&f)}|${state(&copy)}|${blocks_hash(copy.block_storage)}|${u8(copy.quantization_tables.values[0] != none)}|${old.restart_interval},${jpeg.restart_interval},${u8(old.quantization_tables.values[0] != none)},${u8(jpeg.quantization_tables.values[0] != none)}|${state(&returned)}'
		}
		else {
			panic('fixture operation')
		}
	}

	return '${state(&f)}|${blocks_hash(f.block_storage)}|${hash(pixels.value.as_const_bytes())}'
}

fn main() {
	if os.args.len > 1 && os.args[1] == '--trap' {
		observed_path = os.args[2]
		at_exit(observe) or { panic(err) }
		println(record(os.args[3].split('|')))
		return
	}
	for row in os.read_lines(os.args[1]) or { panic(err) } {
		println(record(row.split('|')))
	}
}
