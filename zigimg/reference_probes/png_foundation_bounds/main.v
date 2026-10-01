module main

import os
import zigimg

fn main() {
	assert os.args.len == 2
	name := os.args[1]
	mut bytes := []u8{len: 32}
	mut writer := zigimg.WriteStream.init_memory(mut bytes)
	mut stream := zigimg.ReadStream.init_memory(bytes)
	mut header := zigimg.PngHeaderData{
		width:     1
		height:    1
		bit_depth: 8
	}
	match name {
		'pixel_bits', 'line_bytes' {
			if name == 'pixel_bits' {
				header.bit_depth = 255
				header.color_type = .rgba_color
				_ = header.pixel_bits()
			} else {
				header.width = 0x1fffffff
				header.bit_depth = 16
				_ = header.line_bytes()
			}
		}
		'short_pixels', 'channels8', 'channels16', 'try_all' {
			format := if name == 'channels16' {
				zigimg.PixelFormat.grayscale16
			} else {
				zigimg.PixelFormat.grayscale8
			}
			pixels := zigimg.PixelStorage.init(format, 1) or {
				eprintln('UNEXPECTED: ${err}')
				return
			}
			if name == 'short_pixels' { header.width = 2 }
			if name in ['channels8', 'channels16'] { header.color_type = .rgba_color }
			if name == 'channels16' { header.bit_depth = 16 }
			choice := if name == 'try_all' { zigimg.PngFilterChoice(zigimg.PngTryAll{}) } else { zigimg.PngFilterChoice(zigimg.PngSpecified{
					filter: .none
				}) }
			zigimg.png_filter(mut writer, pixels, choice, header) or {
				eprintln('UNEXPECTED: ${err}')
				return
			}
		}
		'palette_bounds' {
			mut processor := zigimg.PngTrnsProcessor{
				trns_data: zigimg.PngTrnsIndexAlpha{
					data: [u8(0), 17]
				}
			}
			mut data := zigimg.PngPaletteProcessData{
				palette: [zigimg.Rgba32{}]
			}
			processor.process_palette(mut data) or {
				eprintln('UNEXPECTED: ${err}')
				return
			}
		}
		'skip_overflow' {
			mut processor := zigimg.PngTrnsProcessor{
				processed: true
			}
			mut data := zigimg.PngChunkProcessData{
				read_stream:  &stream
				header:       &header
				chunk_length: 0xffffffff
			}
			_ = processor.process_chunk(mut data) or {
				eprintln('UNEXPECTED: ${err}')
				return
			}
		}
		'plte_index' {
			mut processor := zigimg.PngPlteProcessor{
				palette: [zigimg.Rgba32{}]
			}
			mut data := zigimg.PngRowProcessData{
				src_format:  .indexed8
				dest_format: .rgba32
				dest_row:    [u8(1), 0, 0, 0]
			}
			_ = processor.process_data_row(mut data) or {
				eprintln('UNEXPECTED: ${err}')
				return
			}
		}
		'gray_source', 'rgb_source', 'trns_arm', 'gray16_odd', 'rgb48_odd', 'zero_stride' {
			mut processor := zigimg.PngTrnsProcessor{
				trns_data: zigimg.PngTrnsGray{
					value: 0
				}
			}
			mut data := zigimg.PngRowProcessData{
				src_format:  .rgb24
				dest_format: .rgba32
				dest_row:    [u8(0), 0, 0, 0]
			}
			match name {
				'rgb_source' {
					processor.trns_data = zigimg.PngTrnsRGB{}
					data.src_format = .grayscale8
				}
				'trns_arm' {
					processor.trns_data = zigimg.PngTrnsIndexAlpha{}
					data.src_format = .grayscale8
				}
				'gray16_odd' {
					data.src_format = .grayscale16
					data.dest_format = .grayscale16_alpha
					data.dest_row = [u8(0), 0, 0]
				}
				'rgb48_odd' {
					processor.trns_data = zigimg.PngTrnsRGB{}
					data.src_format = .rgb48
					data.dest_row = [u8(0), 0, 0, 0]
				}
				'zero_stride' {
					processor.trns_data = zigimg.PngTrnsRGB{}
					data.dest_format = .grayscale8_alpha
					eprintln('READY: zero-stride row')
				}
				else {}
			}

			_ = processor.process_data_row(mut data) or {
				eprintln('UNEXPECTED: ${err}')
				return
			}
		}
		else {
			eprintln('UNEXPECTED: unknown probe')
			return
		}
	}

	eprintln('UNEXPECTED: PNG operation returned')
}
