module main

import encoding.hex
import os
import zigimg

__global (
	observed_path    string
	observed_stream  = &zigimg.ReadStream(unsafe { nil })
	observed_trns    = &zigimg.PngTrnsProcessor(unsafe { nil })
	observed_plte    = &zigimg.PngPlteProcessor(unsafe { nil })
	observed_tracker = &Tracker(unsafe { nil })
	observed_palette []zigimg.Rgba32
)

fn state_hash() u64 {
	mut hash := [u64(14695981039346656037)]
	if observed_stream != unsafe { nil } { mix(mut hash, observed_stream.get_pos()) }
	if observed_trns != unsafe { nil } { mix(mut hash, u64(observed_trns.processed)) }
	if observed_plte != unsafe { nil } { mix(mut hash, u64(observed_plte.processed)) }
	if observed_tracker != unsafe { nil } { mix(mut hash, observed_tracker.hash[0]) }
	mix(mut hash, u64(observed_palette.len))
	for entry in observed_palette {
		for byte in [entry.r, entry.g, entry.b, entry.a] {
			mix(mut hash, byte)
		}
	}
	return hash[0]
}

fn observe_exit() {
	if observed_path != '' {
		os.write_file(observed_path, '${state_hash():016x}\n') or {
			eprintln('OBSERVER ERROR: ${err}')
		}
	}
}

fn observe_palette(_ voidptr, mut data zigimg.PngPaletteProcessData) ! {
	observed_palette = unsafe { data.palette[..] }
}

fn observe_row(_ voidptr, mut data zigimg.PngRowProcessData) !zigimg.PixelFormat {
	// Keep the row's source format unchanged while the observer visits it.
	return data.src_format
}

fn mix(mut hash []u64, value u64) {
	hash[0] = (hash[0] ^ value) * u64(1099511628211)
}

fn pixels_hash(pixels zigimg.PixelStorage) u64 {
	mut hash := [u64(14695981039346656037)]
	mix(mut hash, u64(pixels.pixel_format()))
	mix(mut hash, u64(pixels.len()))
	for byte in pixels.as_const_bytes() {
		mix(mut hash, byte)
	}
	if palette := pixels.get_palette() {
		mix(mut hash, u64(palette.len))
		for c in palette {
			for byte in [c.r, c.g, c.b, c.a] {
				mix(mut hash, byte)
			}
		}
	}
	return hash[0]
}

struct Tracker {
mut:
	mode int
	hash []u64 = [u64(14695981039346656037)]
}

fn track_chunk(context voidptr, mut data zigimg.PngChunkProcessData) !zigimg.PixelFormat {
	mut tracker := unsafe { &Tracker(context) }
	for value in [u64(1), data.chunk_id, data.chunk_length, data.read_stream.get_pos(),
		u64(data.current_format)] {
		mix(mut tracker.hash, value)
	}
	if (tracker.mode == 9 && data.chunk_id == zigimg.png_chunk_ihdr.id)
		|| (tracker.mode == 10 && data.chunk_id == zigimg.png_chunk_idat.id) {
		return error('Unsupported')
	}
	if !zigimg.png_is_chunk_critical(data.chunk_id) {
		data.read_stream.seek_by(i64(data.chunk_length) + 4)!
	}
	return if tracker.mode == 15 && data.chunk_id == zigimg.png_chunk_ihdr.id {
		zigimg.PixelFormat.rgb24
	} else {
		data.current_format
	}
}

fn track_palette(context voidptr, mut data zigimg.PngPaletteProcessData) ! {
	mut tracker := unsafe { &Tracker(context) }
	mix(mut tracker.hash, 2)
	mix(mut tracker.hash, u64(data.palette.len))
	for c in data.palette {
		for byte in [c.r, c.g, c.b, c.a] {
			mix(mut tracker.hash, byte)
		}
	}
	if tracker.mode == 12 { return error('Unsupported') }
}

fn track_row(context voidptr, mut data zigimg.PngRowProcessData) !zigimg.PixelFormat {
	mut tracker := unsafe { &Tracker(context) }
	for value in [u64(3), u64(data.src_format), u64(data.dest_format), u64(data.dest_row.len)] {
		mix(mut tracker.hash, value)
	}
	for byte in data.dest_row {
		mix(mut tracker.hash, byte)
	}
	if tracker.mode == 11 { return error('Unsupported') }
	if tracker.mode == 14 { data.dest_row = unsafe { data.dest_row[..1] } }
	return if tracker.mode == 13 { zigimg.PixelFormat.invalid } else { data.dest_format }
}

fn main() {
	if os.args.len > 2 {
		observed_path = os.args[2]
		at_exit(observe_exit) or { panic(err) }
	}
	for line in os.read_lines(os.args[1]) or { panic(err) } {
		fields := line.split('|')
		transport := fields[0].int() / 100
		mode := fields[0].int() % 100
		bytes := hex.decode(fields[1]) or { panic(err) }
		mut stream := zigimg.ReadStream.init_memory(bytes)
		mut file := os.File{}
		if transport > 0 {
			os.write_file_array(os.args[1] + '.png', bytes) or { panic(err) }
			file = os.open(os.args[1] + '.png') or { panic(err) }
			mut buffer := []u8{len: [17, 31, 4096, 16, 33][transport - 1]}
			stream = zigimg.ReadStream.init_file(file, mut buffer)
		}
		mut trns := zigimg.PngTrnsProcessor{}
		mut plte := zigimg.PngPlteProcessor{}
		mut diagnostics := []u8{len: 8192, init: 0xa5}
		mut writer := zigimg.WriteStream.init_memory(mut diagnostics)
		mut info := zigimg.PngInfoProcessor.init(&writer)
		mut options := zigimg.PngReaderOptions{}
		mut tracker := Tracker{
			mode: mode
		}
		if observed_path != '' {
			observed_stream = &stream
			observed_trns = &trns
			observed_plte = &plte
			observed_tracker = &tracker
			options.processors << zigimg.PngReaderProcessor.init(0, unsafe { nil }, none,
				observe_palette, observe_row)
		}
		if mode in [1, 3, 7] { options.processors << trns.processor() }
		if mode in [2, 3] { options.processors << plte.processor() }
		if mode == 4 { options.processors << info.processor() }
		if mode >= 8 {
			options.processors << zigimg.PngReaderProcessor.init(zigimg.png_chunk_any.id,
				unsafe { voidptr(&tracker) }, track_chunk, track_palette, track_row)
		}
		mut status := 'ok'
		mut width := usize(0)
		mut height := usize(0)
		mut hash := u64(0)
		if mode in [6, 7] {
			mut header := zigimg.png_load_header(mut stream) or {
				status = err.msg()
				zigimg.PngHeaderData{
					width:              0
					height:             0
					bit_depth:          0
					color_type:         .grayscale
					compression_method: .deflate
					filter_method:      .adaptive
					interlace_method:   .none
				}
			}
			if status == 'ok' {
				width = usize(header.width)
				height = usize(header.height)
				pixels := zigimg.png_load_with_header(mut stream, &header, options) or {
					status = err.msg()
					zigimg.PixelStorage(zigimg.InvalidPixels{})
				}
				if status == 'ok' { hash = pixels_hash(pixels) }
			}
		} else {
			image := if mode == 5 {
				zigimg.PNG.read_image(mut stream) or {
					status = err.msg()
					zigimg.ImageUnmanaged{}
				}
			} else {
				zigimg.png_load(mut stream, options) or {
					status = err.msg()
					zigimg.ImageUnmanaged{}
				}
			}
			if status == 'ok' {
				width = image.width
				height = image.height
				hash = pixels_hash(image.pixels)
			}
		}
		mut output_hash := [u64(14695981039346656037)]
		for byte in diagnostics {
			mix(mut output_hash, byte)
		}
		println('${status}|${stream.get_pos()}|${width}|${height}|${hash:016x}|${trns.processed}|${plte.processed}|${info.idat_count}|${info.idat_size}|${writer.get_pos()}|${output_hash[0]:016x}|${tracker.hash[0]:016x}')
		if transport > 0 { file.close() }
	}
}
