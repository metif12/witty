module main

import os
import encoding.hex
import zigimg as p

__global (
	observed_path   string
	observed_codec  = &p.IFF(unsafe { nil })
	observed_reader = &p.ReadStream(unsafe { nil })
	observed_data   []u8
	observed_op     int
	observed_buffer []u8
	observed_output []u8
	observed_disk   string
	observed_ready  string
)

fn header_bytes(header p.IffHeader) string {
	return match header {
		p.BmhdHeader { 'b:' + unsafe { (&u8(&header)).vbytes(20).hex() } }
		p.DgblHeader { 'd:' + unsafe { (&u8(&header)).vbytes(8).hex() } }
	}
}

fn palette(codec &p.IFF) string {
	data := codec.palette.data
	return unsafe { (&u8(data.data)).vbytes(data.len * 4).hex() }
}

fn state() string {
	mut out := '${observed_reader.get_pos()}:${observed_reader.buffered_len()}|${observed_buffer.hex()}|${observed_output.hex()}|'
	if observed_op == 3 || observed_op == 4 {
		out += '-'
	} else {
		codec := observed_codec
		out += '${codec.cmap_bits}:${u8(codec.format_id)}:${header_bytes(codec.header)}:${codec.pitch}:${codec.pixel_byte_size}:${codec.viewport_mode}:${palette(codec)}'
	}
	return out + '|${observed_data.hex()}|' + if observed_disk != '' {
		(os.read_bytes(observed_disk) or { panic(err) }).hex()
	} else {
		'-'
	}
}

fn observe() {
	if observed_path != '' {
		os.write_file(observed_path, state()) or { eprintln('OBSERVER ERROR: ${err}') }
	}
}

fn run_case(fields []string, mut data []u8, path string) {
	op := fields[0].int()
	mut codec := p.IFF{
		format_id:       unsafe { p.IffFormat(fields[2].u8()) }
		header:          if fields[1] == '0' {
			p.IffHeader(p.BmhdHeader{
				width:             fields[3].u16()
				height:            fields[4].u16()
				x:                 -7
				y:                 -9
				planes:            fields[5].u8()
				mask_type:         .has_lasso
				compression_type:  unsafe { p.IlbmCompressionType(fields[13].u8()) }
				pad:               19
				transparent_color: 513
				x_asoect:          23
				y_aspect:          29
				page_width:        31
				page_height:       37
			})
		} else {
			p.IffHeader(p.DgblHeader{
				width:            fields[3].u16()
				height:           fields[4].u16()
				compression_type: .jpeg
				x_aspect:         23
				y_aspect:         29
			})
		}
		cmap_bits:       fields[6].u8()
		pitch:           fields[7].u16()
		pixel_byte_size: 47
		viewport_mode:   fields[8].u32()
	}
	codec.palette.resize(256)
	for i in 0 .. 256 {
		codec.palette.data[i] = p.Rgba32{
			r: u8(i * 31)
			g: u8(i * 71)
			b: u8(i * 47)
			a: 99
		}
	}
	codec.palette.resize(usize(fields[9].u64()))
	cap := fields[15].int()
	mut buffer := []u8{len: if cap < 0 { 0 } else { cap }, init: 165}
	mut output := []u8{len: fields[17].int(), init: 165}
	observed_buffer = unsafe { buffer }
	observed_output = unsafe { output }
	observed_disk = ''
	mut file := os.File{}
	defer {
		if cap >= 0 { file.close() }
	}
	mut reader := p.ReadStream.init_memory(data)
	if cap >= 0 {
		os.write_file_array(path, data) or { panic(err) }
		file = os.open(path) or { panic(err) }
		file.seek(i64(data.len), .start) or { panic(err) }
		reader = p.ReadStream.init_file(file, mut buffer)
		observed_disk = path
	}
	start := fields[11].int()
	if start > 0 { reader.discard_all(usize(start)) or { panic(err) } }
	observed_codec = &codec
	observed_reader = &reader
	observed_data = unsafe { data[..] }
	observed_op = op
	if observed_ready != '' {
		os.write_file(observed_ready, state()) or { panic(err) }
	}
	for _ in 0 .. fields[16].int() {
		if op >= 5 {
			mut status := 'ok'
			if op == 5 || op == 6 {
				iface := p.IFF.format_interface()
				found := if op == 5 {
					p.IFF.format_detect(mut reader) or {
						status = err.msg()
						false
					}
				} else {
					iface.format_detect(mut reader) or {
						status = err.msg()
						false
					}
				}
				print('${status}:${int(found)}|${state()}~')
				continue
			} else if op == 7 || op == 8 {
				found := if op == 7 {
					p.peek_iff_format_id(mut reader) or {
						status = err.msg()
						p.IffFormat.bad
					}
				} else {
					p.take_iff_format_id(mut reader) or {
						status = err.msg()
						p.IffFormat.bad
					}
				}
				print('${status}:${u8(found)}|${state()}~')
				continue
			} else if op == 9 {
				codec.decode_cmap_chunk(mut reader, p.IffChunkHeader{
					type_:  37
					length: fields[10].u32()
				}) or { status = err.msg() }
			} else if op == 10 {
				codec.decode_camg_chunk(mut reader) or { status = err.msg() }
			} else {
				codec.decode_byte_run2(mut reader, mut output) or { status = err.msg() }
			}
			print('${status}|${state()}~')
			continue
		}
		mut image := p.ImageUnmanaged{}
		if op < 3 {
			pixels := if op == 0 {
				codec.decode_ilbm_pixel_chunk(mut reader, p.IffChunkHeader{
					type_:  fields[14].u32()
					length: fields[10].u32()
				}) or {
					print('${err.msg()}|${state()}~')
					continue
				}
			} else if op == 1 {
				codec.decode_chunks(mut reader) or {
					print('${err.msg()}|${state()}~')
					continue
				}
			} else {
				codec.read(mut reader) or {
					print('${err.msg()}|${state()}~')
					continue
				}
			}
			image = p.ImageUnmanaged{
				width:  codec.width()
				height: codec.height()
				pixels: pixels
			}
		} else {
			iface := p.IFF.format_interface()
			image = if op == 3 {
				p.IFF.read_image(mut reader) or {
					print('${err.msg()}|${state()}~')
					continue
				}
			} else {
				iface.read_image(mut reader) or {
					print('${err.msg()}|${state()}~')
					continue
				}
			}
		}
		mut raw := image.raw_bytes()
		before := raw.hex()
		mut independent := '-'
		if raw.len > 0 {
			ptr := usize(raw.data)
			independent = if ptr < usize(data.data) || ptr >= usize(data.data) + usize(data.len) {
				'1'
			} else {
				'0'
			}
			raw[0] ^= 1
		}
		mut palette_before := '-'
		mut palette_after := '-'
		mut separate := '-'
		if pal := image.pixels.get_palette() {
			mut view := unsafe { pal }
			palette_before = unsafe { (&u8(view.data)).vbytes(view.len * 4).hex() }
			if view.len > 0 {
				separate = if op < 3 && usize(view.data) == usize(codec.palette.data.data) {
					'0'
				} else {
					'1'
				}
				view[0].g ^= 85
			}
			palette_after = unsafe { (&u8(view.data)).vbytes(view.len * 4).hex() }
		}
		print(
			'ok|${image.width}|${image.height}|${u32(image.pixel_format())}|${image.pixels.len()}|${before}|${raw.hex()}|${independent}|${palette_before}|${palette_after}|${separate}|' +
			state() + '~')
	}
	println('')
}

fn line_case(line string, path string) {
	fields := line.split('|')
	mut data := hex.decode(fields[12]) or { panic(err) }
	run_case(fields, mut data, path)
}

fn main() {
	if os.args[1] == '--corpus' {
		for line in os.read_lines(os.args[2]) or { panic(err) } {
			line_case(line, os.args[2] + '.v.bin')
		}
	} else {
		observed_path = os.args[2]
		if os.args[1] == '--loop' { observed_ready = observed_path + '.ready' }
		at_exit(observe) or { panic(err) }
		line_case(os.args[3], observed_path + '.bin')
	}
}
