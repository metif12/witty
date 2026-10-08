module main

import os
import zigimg as z

__global (
	observed_path string
	observed      = &State(unsafe { nil })
)

struct State {
mut:
	stream            z.ReadStream
	trns              z.PngTrnsProcessor
	plte              z.PngPlteProcessor
	row               z.PngRowProcessData
	palette           []z.Rgba32
	observe_trns_data bool = true
}

fn mix(mut hash []u64, value u64) {
	hash[0] = (hash[0] ^ value) * u64(1099511628211)
}

fn (state &State) hash() u64 {
	mut hash := [u64(14695981039346656037)]
	for value in [state.stream.get_pos(), u64(state.trns.processed), u64(state.plte.processed),
		u64(state.row.src_format), u64(state.row.dest_format), u64(state.row.dest_row.len),
		u64(state.palette.len), u64(state.plte.palette.len)] {
		mix(mut hash, value)
	}
	for byte in state.row.dest_row {
		mix(mut hash, byte)
	}
	for entry in state.palette {
		for byte in [entry.r, entry.g, entry.b, entry.a] {
			mix(mut hash, byte)
		}
	}
	if !state.observe_trns_data { return hash[0] }
	match state.trns.trns_data {
		z.PngTrnsUnset {
			mix(mut hash, 0)
		}
		z.PngTrnsGray {
			mix(mut hash, 1)
			mix(mut hash, state.trns.trns_data.value)
		}
		z.PngTrnsRGB {
			mix(mut hash, 2)
			mix(mut hash, state.trns.trns_data.color.r)
			mix(mut hash, state.trns.trns_data.color.g)
			mix(mut hash, state.trns.trns_data.color.b)
		}
		z.PngTrnsIndexAlpha {
			mix(mut hash, 3)
			mix(mut hash, u64(state.trns.trns_data.data.len))
		}
	}

	return hash[0]
}

fn observe_exit() {
	if observed_path != '' && observed != unsafe { nil } {
		os.write_file(observed_path, '${observed.hash():016x}\n') or {
			eprintln('OBSERVER ERROR: ${err}')
		}
	}
}

fn main() {
	if os.args.len > 2 {
		observed_path = os.args[2]
		at_exit(observe_exit) or { panic(err) }
	}
	for line in os.read_lines(os.args[1]) or { panic(err) } {
		p := line.split('|').map(it.u32())
		op := p[0]
		mut bytes := []u8{len: 64, init: u8(index * 13 + 7)}
		mut header := z.PngHeaderData{
			width:     1
			height:    1
			bit_depth: 8
		}
		row_len := if op <= 2 { int(p[4]) } else { 16 }
		palette_len := if op == 2 || op == 3 { int(p[3]) } else { 4 }
		mut palette := []z.Rgba32{len: palette_len}
		for i in 0 .. palette.len {
			palette[i] = z.Rgba32{
				r: u8(i * 3 + 1)
				g: u8(i * 5 + 2)
				b: u8(i * 7 + 3)
				a: 211
			}
		}
		mut row := []u8{len: row_len, init: u8(u32(index * 13) + p[5])}
		alpha := []u8{len: 16, init: u8(index * 17 + 3)}
		mut state := &State{
			stream:  z.ReadStream.init_memory(unsafe { bytes[..if op == 4 {
				int(p[6])
			} else {
				bytes.len
			}] })
			plte:    z.PngPlteProcessor{
				palette: unsafe { palette[..] }
			}
			row:     z.PngRowProcessData{
				dest_row:    unsafe { row[..] }
				src_format:  if op <= 2 { unsafe { z.PixelFormat(p[1]) } } else { .grayscale8 }
				dest_format: if op <= 2 { unsafe { z.PixelFormat(p[2]) } } else { .rgba32 }
				header:      &header
			}
			palette: unsafe { palette[..] }
		}
		observed = state
		arm := if op <= 1 {
			p[3]
		} else if op == 3 {
			p[1]
		} else {
			u32(0)
		}
		state.trns.trns_data = match arm {
			0 { z.PngTrnsData(z.PngTrnsUnset{}) }
			1 { z.PngTrnsData(z.PngTrnsGray{
					value: 7
				}) }
			2 { z.PngTrnsData(z.PngTrnsRGB{
					color: z.Rgb48{
						r: 7
						g: 18
						b: 29
					}
				}) }
			3 { z.PngTrnsData(z.PngTrnsIndexAlpha{
					data: unsafe { alpha[..if op == 3 { int(p[2]) } else { 2 }] }
				}) }
			else { panic('invalid fixture arm') }
		}

		if op == 2 && palette.len > 0 {
			stride := if state.row.dest_format == .rgba64 { 8 } else { 4 }
			mut pos := 0
			for pos + 3 < row.len {
				index_ := u16(p[5] + if p[6] >= 2 { u32(pos / stride) } else { u32(0) })
				row[pos] = u8(index_)
				if state.row.src_format == .indexed16 {
					$if little_endian {
						row[pos] = u8(index_)
						row[pos + 1] = u8(index_ >> 8)
					} $else {
						row[pos] = u8(index_ >> 8)
						row[pos + 1] = u8(index_)
					}
				}
				pos += stride
			}
		}
		mut result := state.row.src_format
		mut status := 'ok'
		match op {
			0 {
				result = state.trns.process_data_row(mut state.row) or {
					status = err.msg()
					z.PixelFormat.invalid
				}
			}
			1 {
				processor := state.trns.processor()
				result = processor.process_data_row(mut state.row) or {
					status = err.msg()
					z.PixelFormat.invalid
				}
			}
			2 {
				processor := state.plte.processor()
				result = if p[6] == 0 {
					state.plte.process_data_row(mut state.row) or {
						status = err.msg()
						z.PixelFormat.invalid
					}
				} else {
					processor.process_data_row(mut state.row) or {
						status = err.msg()
						z.PixelFormat.invalid
					}
				}
			}
			3 {
				mut data := z.PngPaletteProcessData{
					palette: unsafe { palette[..] }
				}
				if p[6] == 0 {
					state.trns.process_palette(mut data) or { status = err.msg() }
				} else {
					processor := state.trns.processor()
					processor.process_palette(mut data) or { status = err.msg() }
				}
			}
			4, 5 {
				header.color_type = unsafe { z.PngColorType(u8(p[1])) }
				header.bit_depth = u8(p[2])
				state.trns.processed = p[5] != 0
				state.plte.processed = p[5] != 0
				mut data := z.PngChunkProcessData{
					read_stream:    &state.stream
					chunk_id:       0
					chunk_length:   p[4]
					current_format: unsafe { z.PixelFormat(p[3]) }
					header:         &header
				}
				result = if op == 4 {
					state.trns.process_chunk(mut data) or {
						status = err.msg()
						z.PixelFormat.invalid
					}
				} else {
					state.plte.process_chunk(mut data) or {
						status = err.msg()
						z.PixelFormat.invalid
					}
				}
			}
			6 {
				processor :=
					z.PngReaderProcessor.init(0, unsafe { voidptr(state) }, none, none, none)
				mut data := z.PngChunkProcessData{
					read_stream:    &state.stream
					chunk_id:       0
					chunk_length:   0
					current_format: .grayscale16
					header:         &header
				}
				if p[1] == 0 {
					result = processor.process_chunk(mut data) or { panic(err) }
				} else if p[1] == 1 {
					mut pd := z.PngPaletteProcessData{
						palette: unsafe { palette[..] }
					}
					processor.process_palette(mut pd) or { panic(err) }
				} else {
					result = processor.process_data_row(mut state.row) or { panic(err) }
				}
			}
			7 {
				header.width = p[1]
				header.height = p[2]
				input := [u8(0), 0, 0, 0, `I`, `D`, `A`, `T`]
				state.stream = z.ReadStream.init_memory(input)
				_ = z.png_load_with_header(mut state.stream, &header, z.PngReaderOptions{}) or {
					status = err.msg()
					z.PixelStorage(z.InvalidPixels{})
				}
			}
			else {
				panic('invalid fixture op')
			}
		}

		if op == 4 && status != 'ok' { state.observe_trns_data = false }
		println('${status}|${u32(result)}|${state.hash():016x}')
	}
}
