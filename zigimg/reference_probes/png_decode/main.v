module main

import encoding.hex
import os
import zigimg

fn mix(mut hash []u64, value u64) { hash[0] = (hash[0] ^ value) * u64(1099511628211) }

fn pixels_hash(pixels zigimg.PixelStorage) u64 {
	mut hash := [u64(14695981039346656037)]
	mix(mut hash, u64(pixels.pixel_format())); mix(mut hash, u64(pixels.len()))
	for byte in pixels.as_const_bytes() { mix(mut hash, byte) }
	if palette := pixels.get_palette() {
		mix(mut hash, u64(palette.len))
		for c in palette { for byte in [c.r, c.g, c.b, c.a] { mix(mut hash, byte) } }
	}
	return hash[0]
}

fn main() {
	for line in os.read_lines(os.args[1]) or { panic(err) } {
		fields := line.split('|')
		mode := fields[0].int()
		mut stream := zigimg.ReadStream.init_memory(hex.decode(fields[1]) or { panic(err) })
		mut trns := zigimg.PngTrnsProcessor{}
		mut plte := zigimg.PngPlteProcessor{}
		mut diagnostics := []u8{len: 8192, init: 0xa5}
		mut writer := zigimg.WriteStream.init_memory(mut diagnostics)
		mut info := zigimg.PngInfoProcessor.init(&writer)
		mut options := zigimg.PngReaderOptions{}
		if mode in [1, 3, 7] { options.processors << trns.processor() }
		if mode in [2, 3] { options.processors << plte.processor() }
		if mode == 4 { options.processors << info.processor() }
		mut status := 'ok'
		mut width := usize(0)
		mut height := usize(0)
		mut hash := u64(0)
		if mode in [6, 7] {
			mut header := zigimg.png_load_header(mut stream) or { status = err.msg(); zigimg.PngHeaderData{} }
			if status == 'ok' {
				width = usize(header.width); height = usize(header.height)
				pixels := zigimg.png_load_with_header(mut stream, &header, options) or { status = err.msg(); zigimg.PixelStorage(zigimg.InvalidPixels{}) }
				if status == 'ok' { hash = pixels_hash(pixels) }
			}
		} else {
			image := if mode == 5 {
				zigimg.PNG.read_image(mut stream) or { status = err.msg(); zigimg.ImageUnmanaged{} }
			} else { zigimg.png_load(mut stream, options) or { status = err.msg(); zigimg.ImageUnmanaged{} } }
			if status == 'ok' { width = image.width; height = image.height; hash = pixels_hash(image.pixels) }
		}
		mut output_hash := [u64(14695981039346656037)]
		for byte in diagnostics { mix(mut output_hash, byte) }
		println('${status}|${stream.get_pos()}|${width}|${height}|${hash:016x}|${trns.processed}|${plte.processed}|${info.idat_count}|${info.idat_size}|${writer.get_pos()}|${output_hash[0]:016x}')
	}
}
