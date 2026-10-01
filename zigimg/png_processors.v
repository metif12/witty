module zigimg

// Allocator fields are omitted: GC owns the translated temporary storage.
pub struct PngChunkProcessData {
pub mut:
	read_stream    &ReadStream = unsafe { nil }
	chunk_id       u32
	chunk_length   u32
	current_format PixelFormat
	header         &PngHeaderData = unsafe { nil }
}

pub struct PngPaletteProcessData {
pub mut:
	palette []Rgba32
}

pub struct PngRowProcessData {
pub mut:
	dest_row    []u8
	src_format  PixelFormat
	dest_format PixelFormat
	header      &PngHeaderData = unsafe { nil }
}

pub type PngChunkProcessorFn = fn (voidptr, mut PngChunkProcessData) !PixelFormat

pub type PngPaletteProcessorFn = fn (voidptr, mut PngPaletteProcessData) !

pub type PngDataRowProcessorFn = fn (voidptr, mut PngRowProcessData) !PixelFormat

pub struct PngReaderProcessorVTable {
pub:
	chunk_processor    ?PngChunkProcessorFn
	palette_processor  ?PngPaletteProcessorFn
	data_row_processor ?PngDataRowProcessorFn
}

pub struct PngReaderProcessor {
pub mut:
	id      u32
	context voidptr
	vtable  &PngReaderProcessorVTable = unsafe { nil }
}

// V callback signatures take an explicit erased context in place of Zig's
// generated typed-pointer adapters and compile-time function parameters.
pub fn PngReaderProcessor.init(id u32, context voidptr, chunk ?PngChunkProcessorFn, palette ?PngPaletteProcessorFn, row ?PngDataRowProcessorFn) PngReaderProcessor {
	return PngReaderProcessor{
		id:      id
		context: context
		vtable:  &PngReaderProcessorVTable{
			chunk_processor:    chunk
			palette_processor:  palette
			data_row_processor: row
		}
	}
}

pub fn (processor PngReaderProcessor) process_chunk(mut data PngChunkProcessData) !PixelFormat {
	if callback := processor.vtable.chunk_processor { return callback(processor.context, mut data) }
	return data.current_format
}

pub fn (processor PngReaderProcessor) process_palette(mut data PngPaletteProcessData) ! {
	if callback := processor.vtable.palette_processor { callback(processor.context, mut data)! }
}

pub fn (processor PngReaderProcessor) process_data_row(mut data PngRowProcessData) !PixelFormat {
	if callback := processor.vtable.data_row_processor {
		return callback(processor.context, mut data)
	}
	return data.dest_format
}

pub struct PngReaderOptions {
pub mut:
	processors []PngReaderProcessor
}

pub fn PngReaderOptions.init() PngReaderOptions {
	return PngReaderOptions{}
}

pub fn PngReaderOptions.init_with_processors(processors []PngReaderProcessor) PngReaderOptions {
	return PngReaderOptions{
		processors: unsafe { processors[..] }
	}
}

fn png_call_chunk_processors(processors []PngReaderProcessor, mut data PngChunkProcessData) ! {
	id := data.chunk_id
	mut processed := png_is_chunk_critical(id)
	for processor in processors {
		if processor.id == id || processor.id == png_chunk_any.id {
			format := processor.process_chunk(mut data)!
			assert format.pixel_stride() >= data.current_format.pixel_stride()
			data.current_format = format
			if !processed {
				processed = true
				break
			}
		}
	}
	if !processed {
		assert data.chunk_length <= u32(0xffffffff) - 4
		data.read_stream.seek_by(i64(data.chunk_length + 4))!
	}
}

fn png_call_palette_processors(options PngReaderOptions, mut palette []Rgba32) ! {
	mut data := PngPaletteProcessData{
		palette: unsafe { palette }
	}
	for processor in options.processors {
		processor.process_palette(mut data)!
	}
}

fn png_call_row_processors(processors []PngReaderProcessor, mut data PngRowProcessData) !PixelFormat {
	starting_format := data.src_format
	mut result_format := starting_format
	for processor in processors {
		result_format = processor.process_data_row(mut data)!
		data.src_format = result_format
	}
	// An error above leaves the previously advanced source format in place.
	data.src_format = starting_format
	return result_format
}

pub struct PngTrnsUnset {}

pub struct PngTrnsGray {
pub:
	value u16
}

pub struct PngTrnsRGB {
pub:
	color Rgb48
}

pub struct PngTrnsIndexAlpha {
pub mut:
	data []u8
}

pub type PngTrnsData = PngTrnsUnset | PngTrnsGray | PngTrnsRGB | PngTrnsIndexAlpha

pub struct PngTrnsProcessor {
pub mut:
	trns_data PngTrnsData = PngTrnsUnset{}
	processed bool
}

fn png_trns_chunk(context voidptr, mut data PngChunkProcessData) !PixelFormat {
	mut processor := unsafe { &PngTrnsProcessor(context) }
	return processor.process_chunk(mut data)
}

fn png_trns_palette(context voidptr, mut data PngPaletteProcessData) ! {
	mut processor := unsafe { &PngTrnsProcessor(context) }
	processor.process_palette(mut data)!
}

fn png_trns_row(context voidptr, mut data PngRowProcessData) !PixelFormat {
	mut processor := unsafe { &PngTrnsProcessor(context) }
	return processor.process_data_row(mut data)
}

pub fn (mut processor PngTrnsProcessor) processor() PngReaderProcessor {
	return PngReaderProcessor.init(png_chunk_trns.id, unsafe { voidptr(&processor) },
		png_trns_chunk, png_trns_palette, png_trns_row)
}

pub fn (mut processor PngTrnsProcessor) process_chunk(mut data PngChunkProcessData) !PixelFormat {
	mut format := data.current_format
	if processor.processed {
		assert data.chunk_length <= u32(0xffffffff) - 4
		data.read_stream.seek_by(i64(data.chunk_length + 4))!
		return format
	}
	mut stream := data.read_stream
	match data.header.get_pixel_format() {
		.grayscale1, .grayscale2, .grayscale4, .grayscale8, .grayscale16 {
			if data.chunk_length == 2 {
				processor.trns_data = PngTrnsGray{
					value: tiff_u16(stream.take(2)!, .big)
				}
				format = if format == .grayscale16 {
					PixelFormat.grayscale16_alpha
				} else {
					PixelFormat.grayscale8_alpha
				}
			} else {
				stream.seek_by(i64(data.chunk_length))!
			}
		}
		.indexed1, .indexed2, .indexed4, .indexed8, .indexed16 {
			if data.chunk_length <= data.header.max_palette_size() {
				processor.trns_data = PngTrnsIndexAlpha{
					data: []u8{len: int(data.chunk_length)}
				}
				match mut processor.trns_data {
					PngTrnsIndexAlpha { stream.read_slice_all(mut processor.trns_data.data)! }
					else { panic('wrong PNG tRNS arm') }
				}
			} else {
				stream.seek_by(i64(data.chunk_length))!
			}
		}
		.rgb24, .rgb48 {
			if data.chunk_length == 6 {
				bytes := stream.take(6)!
				processor.trns_data = PngTrnsRGB{
					color: Rgb48{
						r: tiff_u16(bytes[..2], .big)
						g: tiff_u16(bytes[2..4], .big)
						b: tiff_u16(bytes[4..6], .big)
					}
				}
				format = if format == .rgb48 { PixelFormat.rgba64 } else { PixelFormat.rgba32 }
			} else {
				stream.seek_by(i64(data.chunk_length))!
			}
		}
		else {
			stream.seek_by(i64(data.chunk_length))!
		}
	}

	stream.seek_by(4)!
	return format
}

pub fn (mut processor PngTrnsProcessor) process_palette(mut data PngPaletteProcessData) ! {
	processor.processed = true
	match processor.trns_data {
		PngTrnsIndexAlpha {
			for index, alpha in processor.trns_data.data {
				data.palette[index].a = alpha
			}
		}
		PngTrnsUnset {}
		else {
			return error('InvalidData')
		}
	}
}

fn png_native_u16(bytes []u8) u16 {
	$if little_endian {
		return tiff_u16(bytes, .little)
	} $else {
		return tiff_u16(bytes, .big)
	}
}

fn png_store_native_u16(mut bytes []u8, index int, value u16) {
	$if little_endian {
		bytes[index] = u8(value)
		bytes[index + 1] = u8(value >> 8)
	} $else {
		bytes[index] = u8(value >> 8)
		bytes[index + 1] = u8(value)
	}
}

pub fn (mut processor PngTrnsProcessor) process_data_row(mut data PngRowProcessData) !PixelFormat {
	processor.processed = true
	if data.src_format.is_indexed() || processor.trns_data is PngTrnsUnset { return data.src_format }
	mut stride := match data.dest_format {
		.grayscale8_alpha, .grayscale16_alpha { 2 }
		.rgba32, .bgra32 { 4 }
		.rgba64 { 8 }
		else { return data.src_format }
	}

	mut position := 0
	match processor.trns_data {
		PngTrnsGray {
			gray := processor.trns_data.value
			match data.src_format {
				.grayscale1, .grayscale2, .grayscale4, .grayscale8 {
					for position + 1 < data.dest_row.len {
						difference := data.dest_row[position] ^ u8(gray)
						$if wasm32 {
							assert difference <= 1
							data.dest_row[position + 1] = difference * u8(255)
						} $else {
							data.dest_row[position + 1] = if difference == 0 {
								u8(0)
							} else {
								u8(255)
							}
						}
						position += stride
					}
					return .grayscale8_alpha
				}
				.grayscale16 {
					assert data.dest_row.len % 2 == 0
					for position + 1 < data.dest_row.len / 2 {
						// The source compares a byte at the u16 sample index, including
						// previously written alpha bytes; it does not read the gray u16.
						difference := u16(data.dest_row[position]) ^ gray
						mut alpha := u16(0)
						$if wasm32 {
							assert difference <= 1
							alpha = difference * u16(65535)
						} $else {
							alpha = if difference == 0 { u16(0) } else { u16(65535) }
						}
						png_store_native_u16(mut data.dest_row, (position + 1) * 2, alpha)
						position += stride
					}
					return .grayscale16_alpha
				}
				else {
					panic('invalid PNG gray transparency source')
				}
			}
		}
		PngTrnsRGB {
			color := processor.trns_data.color
			match data.src_format {
				.rgb24 {
					assert data.dest_row.len % 4 == 0
					stride /= 4
					for position < data.dest_row.len / 4 {
						at := position * 4
						data.dest_row[at + 3] = if data.dest_row[at] == color.r
							&& data.dest_row[at + 1] == color.g && data.dest_row[at + 2] == color.b {
							u8(0)
						} else {
							u8(255)
						}
						position += stride
					}
					return .rgba32
				}
				.rgb48 {
					assert data.dest_row.len % 8 == 0
					for position < data.dest_row.len / 8 {
						at := position * 8
						r := png_native_u16(data.dest_row[at..at + 2])
						g := png_native_u16(data.dest_row[at + 2..at + 4])
						b := png_native_u16(data.dest_row[at + 4..at + 6])
						png_store_native_u16(mut data.dest_row, at + 6, if r == color.r
							&& g == color.g && b == color.b {
							u16(0)
						} else {
							u16(65535)
						})
						position++
					}
					return .rgba64
				}
				else {
					panic('invalid PNG RGB transparency source')
				}
			}
		}
		else {
			panic('invalid PNG transparency data')
		}
	}
}

pub struct PngPlteProcessor {
pub mut:
	palette   []Rgba32
	processed bool
}

fn png_plte_chunk(context voidptr, mut data PngChunkProcessData) !PixelFormat {
	mut processor := unsafe { &PngPlteProcessor(context) }
	return processor.process_chunk(mut data)
}

fn png_plte_palette(context voidptr, mut data PngPaletteProcessData) ! {
	mut processor := unsafe { &PngPlteProcessor(context) }
	processor.process_palette(mut data)!
}

fn png_plte_row(context voidptr, mut data PngRowProcessData) !PixelFormat {
	mut processor := unsafe { &PngPlteProcessor(context) }
	return processor.process_data_row(mut data)
}

pub fn (mut processor PngPlteProcessor) processor() PngReaderProcessor {
	return PngReaderProcessor.init(png_chunk_plte.id, unsafe { voidptr(&processor) },
		png_plte_chunk, png_plte_palette, png_plte_row)
}

pub fn (mut processor PngPlteProcessor) process_chunk(mut data PngChunkProcessData) !PixelFormat {
	if processor.processed || !data.current_format.is_indexed() {
		processor.processed = true
		return data.current_format
	}
	return .rgba32
}

pub fn (mut processor PngPlteProcessor) process_palette(mut data PngPaletteProcessData) ! {
	processor.processed = true
	processor.palette = unsafe { data.palette[..] }
}

pub fn (mut processor PngPlteProcessor) process_data_row(mut data PngRowProcessData) !PixelFormat {
	processor.processed = true
	if !data.src_format.is_indexed() || processor.palette.len == 0 { return data.src_format }
	stride := match data.dest_format {
		.rgba32, .bgra32 { 4 }
		.rgba64 { 8 }
		else { return data.src_format }
	}

	mut position := 0
	for position + 3 < data.dest_row.len {
		index := match data.src_format {
			.indexed1, .indexed2, .indexed4, .indexed8 { u16(data.dest_row[position]) }
			.indexed16 { png_native_u16(data.dest_row[position..position + 2]) }
			else { panic('invalid PNG indexed transparency source') }
		}

		entry := processor.palette[int(index)]
		data.dest_row[position] = entry.r
		data.dest_row[position + 1] = entry.g
		data.dest_row[position + 2] = entry.b
		data.dest_row[position + 3] = entry.a
		position += stride
	}
	return .rgba32
}

pub struct PngCustomReaderOptions1[P] {
pub mut:
	processor  P
	processors [1]PngReaderProcessor
}

pub fn png_custom_reader_options1_init[P](processor P) PngCustomReaderOptions1[P] {
	return PngCustomReaderOptions1[P]{
		processor: processor
	}
}

pub fn PngCustomReaderOptions1.init[P](processor P) PngCustomReaderOptions1[P] {
	return png_custom_reader_options1_init[P](processor)
}

pub fn (mut options PngCustomReaderOptions1[P]) get[P]() PngReaderOptions {
	options.processors[0] = options.processor.processor()
	mut processors := []PngReaderProcessor{}
	unsafe {
		processors.data = &options.processors[0]
		processors.len = 1
		processors.cap = 1
		processors.flags = .nofree
	}
	return PngReaderOptions{
		processors: processors
	}
}

pub struct PngCustomReaderOptions2[P, Q] {
pub mut:
	processor1 P
	processor2 Q
	processors [2]PngReaderProcessor
}

pub fn png_custom_reader_options2_init[P, Q](processor1 P, processor2 Q) PngCustomReaderOptions2[P, Q] {
	return PngCustomReaderOptions2[P, Q]{
		processor1: processor1
		processor2: processor2
	}
}

pub fn PngCustomReaderOptions2.init[P, Q](processor1 P, processor2 Q) PngCustomReaderOptions2[P, Q] {
	return png_custom_reader_options2_init[P, Q](processor1, processor2)
}

pub fn (mut options PngCustomReaderOptions2[P, Q]) get[P, Q]() PngReaderOptions {
	options.processors[0] = options.processor1.processor()
	options.processors[1] = options.processor2.processor()
	mut processors := []PngReaderProcessor{}
	unsafe {
		processors.data = &options.processors[0]
		processors.len = 2
		processors.cap = 2
		processors.flags = .nofree
	}
	return PngReaderOptions{
		processors: processors
	}
}

pub type PngDefaultOptions = PngCustomReaderOptions1[PngTrnsProcessor]
