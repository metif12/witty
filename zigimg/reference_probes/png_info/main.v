module main

import encoding.hex
import os
import zigimg

__global (
	observed_processor = &zigimg.PngInfoProcessor(unsafe { nil })
	observed_writer    = &zigimg.WriteStream(unsafe { nil })
	observed_input     = &zigimg.ReadStream(unsafe { nil })
	observed_bytes     []u8
	observed_path      string
)

fn observe() {
	if observed_processor == unsafe { nil } { return }
	os.write_file(observed_path,
		'${observed_processor.idat_count}|${observed_processor.idat_size}|${observed_input.get_pos()}|${observed_writer.get_pos()}|${buffer_hash(observed_bytes):016x}') or {}
}

fn buffer_hash(bytes []u8) u64 {
	mut hash := u64(14695981039346656037)
	for byte in bytes {
		hash = (hash ^ byte) * u64(1099511628211)
	}
	return hash
}

fn bounds(name string, path string) {
	unknown := u8('255'.int())
	mut bytes := []u8{len: 4096}
	mut writer := zigimg.WriteStream.init_memory(mut bytes)
	mut input := zigimg.ReadStream.init_memory([]u8{len: 20, init: 1})
	mut processor := zigimg.PngInfoProcessor.init(&writer)
	mut header := zigimg.PngHeaderData{
		width:            17
		height:           3
		bit_depth:        8
		interlace_method: .adam7
	}
	mut data := zigimg.PngChunkProcessData{
		read_stream:    &input
		header:         &header
		current_format: .grayscale8
	}
	match name {
		'count_overflow' {
			data.chunk_id = zigimg.png_chunk_idat.id
			processor.idat_count = 0xffffffff
		}
		'both_overflow' {
			data.chunk_id = zigimg.png_chunk_idat.id
			data.chunk_length = 1
			processor.idat_count = 0xffffffff
			processor.idat_size = ~u64(0)
		}
		'size_overflow' {
			data.chunk_id = zigimg.png_chunk_idat.id
			data.chunk_length = 1
			processor.idat_size = ~u64(0)
		}
		'compression_tag' {
			data.chunk_id = zigimg.png_chunk_ihdr.id
			header.compression_method = unsafe { zigimg.PngCompressionMethod(unknown) }
		}
		'filter_tag' {
			data.chunk_id = zigimg.png_chunk_ihdr.id
			header.filter_method = unsafe { zigimg.PngFilterMethod(unknown) }
		}
		'color_tag' {
			data.chunk_id = zigimg.png_chunk_ihdr.id
			header.color_type = unsafe { zigimg.PngColorType(unknown) }
		}
		'interlace_tag' {
			data.chunk_id = zigimg.png_chunk_ihdr.id
			header.interlace_method = unsafe { zigimg.PngInterlaceMethod(unknown) }
		}
		'text_null' {
			data.chunk_id = zigimg.png_chunk_text.id
			data.chunk_length = 6
		}
		'ztxt_null' {
			data.chunk_id = zigimg.png_chunk_ztxt.id
			data.chunk_length = 6
		}
		'ztxt_method' {
			data.chunk_id = zigimg.png_chunk_ztxt.id
			data.chunk_length = 1
			input = zigimg.ReadStream.init_memory([u8(0), 0, 0, 0, 0, 0])
		}
		'itxt_one_no', 'itxt_one_yes', 'itxt_one_unknown' {
			data.chunk_id = zigimg.png_chunk_itxt.id
			data.chunk_length = 2
			input = zigimg.ReadStream.init_memory([u8(0),
				u8(if name == 'itxt_one_yes' {
					1
				} else if name == 'itxt_one_no' {
					0
				} else {
					2
				})])
		}
		'itxt_flags', 'itxt_language', 'itxt_translation' {
			data.chunk_id = zigimg.png_chunk_itxt.id
			contents := if name == 'itxt_flags' {
				[u8(0)]
			} else if name == 'itxt_language' {
				[u8(0), 0, 0, 1]
			} else {
				[u8(0), 0, 0, 0, 1]
			}
			data.chunk_length = u32(contents.len)
			input = zigimg.ReadStream.init_memory(contents)
		}
		else {
			eprintln('UNEXPECTED: unknown case')
			return
		}
	}

	observed_processor = unsafe { &processor }
	observed_writer = unsafe { &writer }
	observed_input = unsafe { &input }
	observed_bytes = unsafe { bytes }
	observed_path = path
	at_exit(observe) or { panic(err) }
	callback := processor.processor()
	_ = callback.process_chunk(mut data) or {
		eprintln('UNEXPECTED: ${err}')
		return
	}
	eprintln('UNEXPECTED: PNG info returned')
}

fn main() {
	if os.args[1] == '--bounds' {
		bounds(os.args[2], os.args[3])
		return
	}
	if os.args[1] == '--contracts' {
		contracts()
		return
	}
	for line in os.read_lines(os.args[1]) or { panic(err) } {
		fields := line.split('|')
		assert fields.len == 9 || fields.len == 12
		mut bytes := []u8{len: fields[4].int(), init: 0xa5}
		mut writer := zigimg.WriteStream.init_memory(mut bytes)
		mut input := zigimg.ReadStream.init_memory(hex.decode(fields[5]) or { panic(err) })
		mut processor := zigimg.PngInfoProcessor.init(&writer)
		processor.idat_count = fields[6].u32()
		processor.idat_size = fields[7].u64()
		mut header := zigimg.PngHeaderData{
			width:              17
			height:             3
			bit_depth:          u8(fields[3].int())
			color_type:         unsafe { zigimg.PngColorType(fields[2].int()) }
			compression_method: unsafe {
				zigimg.PngCompressionMethod(if fields.len == 12 {
					fields[9].int()
				} else {
					0
				})
			}
			filter_method:      unsafe {
				zigimg.PngFilterMethod(if fields.len == 12 {
					fields[10].int()
				} else {
					0
				})
			}
			interlace_method:   unsafe {
				zigimg.PngInterlaceMethod(if fields.len == 12 {
					fields[11].int()
				} else {
					1
				})
			}
		}
		callback := processor.processor()
		mut status := 'ok'
		mut result := zigimg.PixelFormat.grayscale8
		if fields[8] == '0' {
			mut data := zigimg.PngChunkProcessData{
				read_stream:    &input
				header:         &header
				current_format: .grayscale8
				chunk_id:       fields[0].u32()
				chunk_length:   fields[1].u32()
			}
			result = callback.process_chunk(mut data) or {
				status = err.msg()
				zigimg.PixelFormat.invalid
			}
		} else {
			mut data := zigimg.PngPaletteProcessData{
				palette: []zigimg.Rgba32{len: fields[1].int()}
			}
			callback.process_palette(mut data) or { status = err.msg() }
		}
		println('${status}|${input.get_pos()}|${u32(result)}|${processor.idat_count}|${processor.idat_size}|${writer.get_pos()}|${buffer_hash(bytes):016x}')
	}
}

fn contracts() {
	mut bytes := []u8{len: 256, init: 0xa5}
	mut writer := zigimg.WriteStream.init_memory(mut bytes)
	mut original := zigimg.PngInfoProcessor{
		writer: &writer
	}
	initialized := zigimg.PngInfoProcessor.init(&writer)
	mut result := '${original.idat_count}|${original.idat_size}|${initialized.idat_count}|${initialized.idat_size}|${int(original.writer == initialized.writer)}|'
	original.idat_count = 17
	original.idat_size = 23
	mut copy := original
	mut input := zigimg.ReadStream.init_memory([]u8{})
	mut header := zigimg.PngHeaderData{
		width:            17
		height:           3
		bit_depth:        8
		interlace_method: .adam7
	}
	mut data := zigimg.PngChunkProcessData{
		read_stream:    &input
		header:         &header
		chunk_id:       zigimg.png_chunk_idat.id
		chunk_length:   7
		current_format: .grayscale8
	}
	callback := copy.processor()
	callback.process_chunk(mut data) or { panic(err) }
	data.chunk_id = zigimg.png_chunk_iend.id
	callback.process_chunk(mut data) or { panic(err) }
	result += '${original.idat_count}|${original.idat_size}|${copy.idat_count}|${copy.idat_size}|${int(copy.writer == original.writer)}|${writer.get_pos()}|${buffer_hash(bytes):016x}'
	println(result)
}
