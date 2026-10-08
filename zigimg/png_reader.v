module zigimg

import hash.crc32

const png_reader_crc = crc32.new(crc32.ieee)

// Keep the pinned decoder's checked-width arithmetic explicit under -prod.
fn png_reader_u32_add(a u32, b u32) u32 {
	if a > u32(0xffffffff) - b { panic('integer overflow') }
	return a + b
}

fn png_reader_u32_mul(a u32, b u32) u32 {
	if b != 0 && a > u32(0xffffffff) / b { panic('integer overflow') }
	return a * b
}

fn png_reader_u8_add(a u8, b u8) u8 {
	if a > u8(255) - b { panic('integer overflow') }
	return a + b
}

fn png_reader_u8_mul(a u8, b u8) u8 {
	if b != 0 && a > u8(255) / b { panic('integer overflow') }
	return a * b
}

fn png_reader_assert(condition bool) {
	if !condition { panic('reached unreachable code') }
}

// The pinned IDatChunksReader plus its std.Io.Reader default buffered methods.
struct PngIDatReader {
mut:
	source     &ReadStream = unsafe { nil }
	processors []PngReaderProcessor
	data       &PngChunkProcessData = unsafe { nil }
	remaining  u32
	crc        u32
	buffer     []u8 = []u8{len: 4096}
	position   int
	end        int
}

fn (mut reader PngIDatReader) stream_into(mut destination []u8) !int {
	if reader.remaining == 0 { return error('EndOfStream') }
	count := if reader.remaining < u32(destination.len) {
		int(reader.remaining)
	} else {
		destination.len
	}
	mut target := unsafe { destination[..count] }
	reader.source.read_slice_all(mut target)!
	reader.crc = png_reader_crc.update(reader.crc, target)
	reader.remaining -= u32(count)
	if reader.remaining == 0 {
		expected := read_be_u32(reader.source.take(4)!)
		if expected != reader.crc { return error('ReadFailed') }
		png_call_chunk_processors(reader.processors, mut reader.data) or {
			return error('ReadFailed')
		}
		reader.crc = crc32.sum('IDAT'.bytes())
		chunk := reader.source.peek(8)!
		if read_be_u32(chunk[4..]) == png_chunk_idat.id {
			reader.source.toss(8)
			reader.remaining = read_be_u32(chunk[..4])
		}
	}
	return count
}

fn (mut reader PngIDatReader) default_read_vec(mut destination []u8) !int {
	if destination.len >= reader.buffer.len - reader.end {
		return reader.stream_into(mut destination)
	}
	mut target := unsafe { reader.buffer[reader.end..] }
	count := reader.stream_into(mut target)!
	reader.end += count
	return 0
}

fn (mut reader PngIDatReader) peek(count int) ![]u8 {
	png_reader_assert(count >= 0)
	if reader.position + count > reader.end {
		if reader.buffer.len - reader.position < count {
			remaining := reader.end - reader.position
			for index in 0 .. remaining {
				reader.buffer[index] = reader.buffer[reader.position + index]
			}
			reader.position = 0
			reader.end = remaining
			png_reader_assert(count <= reader.buffer.len)
		}
		for reader.end < reader.position + count {
			mut empty := []u8{}
			reader.default_read_vec(mut empty)!
		}
	}
	return unsafe { reader.buffer[reader.position..reader.position + count] }
}

fn (mut reader PngIDatReader) take(count int) ![]u8 {
	bytes := reader.peek(count)!
	reader.position += count
	return bytes
}

fn (mut reader PngIDatReader) flate_fill_word() ! {
	reader.peek(int(sizeof(usize)))!
}

fn (reader PngIDatReader) flate_buffered_len() int {
	return reader.end - reader.position
}

fn (mut reader PngIDatReader) flate_read_vec(mut destination []u8) !int {
	remaining := reader.flate_buffered_len()
	count := if remaining < destination.len { remaining } else { destination.len }
	copy(mut destination, reader.take(count)!)
	if count == destination.len { return count }
	mut target := unsafe { destination[count..] }
	next := reader.default_read_vec(mut target) or {
		if err.msg() == 'EndOfStream' && count > 0 { return count }
		return err
	}
	return count + next
}

fn png_decode_short(mut decoder TiffFlate, mut input PngIDatReader, mut destination []u8) !int {
	mut filled := 0
	for filled < destination.len {
		if decoder.seek < decoder.end {
			available := decoder.end - decoder.seek
			needed := destination.len - filled
			count := if available < needed { available } else { needed }
			for index in 0 .. count {
				destination[filled + index] = decoder.window[decoder.seek + index]
			}
			decoder.seek += count
			filled += count
		} else {
			decoder.fill_window(mut input) or {
				if err.msg() == 'EndOfStream' && decoder.state == .end { return filled }
				return error('InvalidData')
			}
		}
	}
	return filled
}

fn png_decode_all(mut decoder TiffFlate, mut input PngIDatReader, mut destination []u8) ! {
	if png_decode_short(mut decoder, mut input, mut destination)! != destination.len {
		return error('EndOfStream')
	}
}

pub fn png_load(mut stream ReadStream, options PngReaderOptions) !ImageUnmanaged {
	mut header := png_load_header(mut stream)!
	pixels := png_load_with_header(mut stream, &header, options)!
	return ImageUnmanaged{
		width:  usize(header.width)
		height: usize(header.height)
		pixels: pixels
	}
}

pub fn PNG.read_image(mut stream ReadStream) !ImageUnmanaged {
	mut options := PngDefaultOptions.init(PngTrnsProcessor{})
	return png_load(mut stream, options.get())
}

pub fn png_load_with_header(mut stream ReadStream, header &PngHeaderData, options PngReaderOptions) !PixelStorage {
	mut palette := []Rgb24{}
	mut data_found := false
	mut result := PixelStorage(InvalidPixels{})
	mut data := PngChunkProcessData{
		read_stream:    unsafe { &stream }
		header:         unsafe { header }
		chunk_id:       png_chunk_ihdr.id
		chunk_length:   13
		current_format: header.get_pixel_format()
	}
	png_call_chunk_processors(options.processors, mut data)!
	for {
		chunk := stream.take(8)!
		length := read_be_u32(chunk[..4])
		id := read_be_u32(chunk[4..])
		data.chunk_id = id
		data.chunk_length = length
		match id {
			png_chunk_ihdr.id {
				return error('InvalidData')
			}
			png_chunk_iend.id {
				if !data_found { return error('InvalidData') }
				stream.take(4)!
				png_call_chunk_processors(options.processors, mut data)!
				return result
			}
			png_chunk_idat.id {
				if data_found || (header.color_type == .indexed && palette.len == 0) {
					return error('InvalidData')
				}
				result = png_read_all_data(mut stream, header, palette, options, mut data)!
				data_found = true
			}
			png_chunk_plte.id {
				if !header.allows_palette() || palette.len > 0 { return error('InvalidData') }
				if data_found {
					stream.seek_by(i64(png_reader_u32_add(length, 4)))!
				} else {
					if length % 3 != 0 || length / 3 > header.max_palette_size() {
						return error('InvalidData')
					}
					mut bytes := []u8{len: int(length)}
					stream.read_slice_all(mut bytes)!
					palette = []Rgb24{len: int(length / 3)}
					for index in 0 .. palette.len {
						palette[index] = Rgb24{
							r: bytes[index * 3]
							g: bytes[index * 3 + 1]
							b: bytes[index * 3 + 2]
						}
					}
					expected := read_be_u32(stream.take(4)!)
					crc := png_reader_crc.update(crc32.sum('PLTE'.bytes()), bytes)
					if expected != crc { return error('InvalidData') }
					png_call_chunk_processors(options.processors, mut data)!
				}
			}
			else {
				png_call_chunk_processors(options.processors, mut data)!
			}
		}
	}
	return result
}

fn png_read_all_data(mut stream ReadStream, header &PngHeaderData, palette []Rgb24, options PngReaderOptions, mut data PngChunkProcessData) !PixelStorage {
	width := header.width
	height := header.height
	channels := header.channel_count()
	format := data.current_format
	mut result := PixelStorage.init(format, usize(png_reader_u32_mul(width, height)))!
	mut input := PngIDatReader{
		source:     unsafe { &stream }
		processors: unsafe { options.processors }
		data:       unsafe { &data }
		remaining:  data.chunk_length
		crc:        crc32.sum('IDAT'.bytes())
	}
	mut decoder := TiffFlate{}
	if palette.len > 0 {
		mut destination_palette := []Rgba32{}
		if result.is_indexed() {
			result.resize_palette(usize(palette.len))
			destination_palette = unsafe { result.get_palette() or { []Rgba32{} } }
		} else {
			destination_palette = []Rgba32{len: palette.len}
		}
		for index, entry in palette {
			destination_palette[index] = Rgba32{
				r: entry.r
				g: entry.g
				b: entry.b
				a: 255
			}
		}
		png_call_palette_processors(options, mut destination_palette)!
	}
	mut destination := result.as_bytes()
	filter_stride := png_reader_u8_mul(png_reader_u8_add(header.bit_depth, 7) / 8, channels)
	line_bytes := header.line_bytes()
	virtual_bytes := png_reader_u32_add(line_bytes, filter_stride)
	if height == 0 { panic('division by zero') }
	result_bytes := usize(destination.len) / usize(height)
	if result_bytes > usize(0xffffffff) { panic('integer cast truncated bits') }
	result_line_bytes := u32(result_bytes)
	mut temporary_bytes := png_reader_u32_mul(2, virtual_bytes)
	if header.interlace_method == .adam7 {
		temporary_bytes = png_reader_u32_add(temporary_bytes, result_line_bytes)
	}
	mut temporary := []u8{len: int(temporary_bytes)}
	mut previous := unsafe { temporary[..int(virtual_bytes)] }
	mut current := unsafe { temporary[int(virtual_bytes)..int(virtual_bytes * 2)] }
	if width == 0 { panic('division by zero') }
	if result_line_bytes / width > 255 { panic('integer cast truncated bits') }
	stride := u8(result_line_bytes / width)
	png_reader_assert(stride == format.pixel_stride())
	mut row := PngRowProcessData{
		dest_row: []u8{}

		src_format:  header.get_pixel_format()
		dest_format: format
		header:      unsafe { header }
	}
	byteswap := $if little_endian { true } $else { false }
	if header.interlace_method == .none {
		for _ in 0 .. int(height) {
			mut encoded := unsafe { current[int(filter_stride) - 1..] }
			png_decode_all(mut decoder, mut input, mut encoded)!
			png_defilter(mut current, previous, filter_stride)!
			row.dest_row = unsafe { destination[..int(result_line_bytes)] }
			destination = unsafe { destination[int(result_line_bytes)..] }
			png_spread_row_data(mut row.dest_row, current[int(filter_stride)..], header.bit_depth,
				channels, stride, byteswap)
			if png_call_row_processors(options.processors, mut row)! != format {
				return error('InvalidData')
			}
			unsafe {
				previous, current = current, previous
			}
		}
	} else {
		starts_x := [u8(0), 4, 0, 2, 0, 1, 0]!
		starts_y := [u8(0), 0, 4, 0, 2, 0, 1]!
		increments_x := [u8(8), 8, 4, 4, 2, 2, 1]!
		increments_y := [u8(8), 8, 8, 4, 4, 2, 2]!
		pass_widths := [png_reader_u32_add(width, 7) / 8, png_reader_u32_add(width, 3) / 8,
			png_reader_u32_add(width, 3) / 4, png_reader_u32_add(width, 1) / 4,
			png_reader_u32_add(width, 1) / 2, width / 2, width]!
		pass_heights := [png_reader_u32_add(height, 7) / 8, png_reader_u32_add(height, 7) / 8,
			png_reader_u32_add(height, 3) / 8, png_reader_u32_add(height, 3) / 4,
			png_reader_u32_add(height, 1) / 4, png_reader_u32_add(height, 1) / 2, height / 2]!
		pixel_bits := header.pixel_bits()
		depth := if header.bit_depth <= 8 { u8(8) } else { u8(16) }
		mut dest_row := unsafe { temporary[int(virtual_bytes * 2)..] }
		for pass in 0 .. 7 {
			pass_width := pass_widths[pass]
			if pass_width == 0 || pass_heights[pass] == 0 { continue
			 }
			pass_bytes := png_reader_u32_add(png_reader_u32_mul(pixel_bits, pass_width), 7) / 8
			pass_length := png_reader_u32_add(pass_bytes, filter_stride)
			result_pass_bytes := png_reader_u32_mul(stride, pass_width)
			deinterlace_stride := png_reader_u8_mul(increments_x[pass], stride)
			for mut byte in previous {
				byte = 0
			}
			dest_x := png_reader_u8_mul(starts_x[pass], stride)
			mut dest_y := starts_y[pass]
			for _ in 0 .. int(pass_heights[pass]) {
				mut encoded := unsafe { current[int(filter_stride) - 1..int(pass_length)] }
				png_decode_all(mut decoder, mut input, mut encoded)!
				mut active_current := unsafe { current[..int(pass_length)] }
				png_defilter(mut active_current, previous[..int(pass_length)], filter_stride)!
				row.dest_row = unsafe { dest_row[..int(result_pass_bytes)] }
				png_spread_row_data(mut row.dest_row, current[int(filter_stride)..],
					header.bit_depth, channels, stride, byteswap)
				result_format := png_call_row_processors(options.processors, mut row)!
				if result_format != format { return error('InvalidData') }
				line_start := png_reader_u32_mul(dest_y, result_line_bytes)
				start_byte := png_reader_u32_add(line_start, dest_x)
				end_byte := png_reader_u32_add(line_start, result_line_bytes)
				mut final_row := unsafe { destination[int(start_byte)..int(end_byte)] }
				png_spread_row_data(mut final_row, row.dest_row, depth,
					result_format.channel_count(), deinterlace_stride, false)
				dest_y = png_reader_u8_add(dest_y, increments_y[pass])
				unsafe {
					previous, current = current, previous
				}
			}
		}
	}
	mut extra := []u8{len: 8}
	should_be_zero := png_decode_short(mut decoder, mut input, mut extra)!
	png_reader_assert(should_be_zero == 0)
	return result
}
