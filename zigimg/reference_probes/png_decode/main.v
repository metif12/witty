module main

import encoding.hex
import os
import zigimg

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
	return data.current_format
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
	return if tracker.mode == 13 { zigimg.PixelFormat.invalid } else { data.dest_format }
}

fn main() {
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
				zigimg.PngHeaderData{}
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
