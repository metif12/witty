module main

import os
import zigimg

fn returning() {
	mut bytes := []u8{len: 48}
	for index in 0 .. bytes.len {
		bytes[index] = u8(index * 37 + 11)
	}
	for endian_index, endianess in [zigimg.TiffEndian.big, .little] {
		for data_type in [u16(0), 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 65535] {
			for count in [u32(0), 1, 2, 3, 8] {
				if count > 1 && data_type != 3 && data_type != 4 { continue
				 }
				mut stream := zigimg.ReadStream.init_memory(bytes)
				tag := zigimg.TiffTagField{
					data_type:   data_type
					data_count:  count
					data_offset: if count == 1 { u32(0x12345678) } else { u32(3) }
				}
				values := tag.read_tag_data(mut stream, endianess) or { panic(err) }
				mut line := 'A|${endian_index}|${data_type}|${count}|${tag.to_long()}|${tag.to_short(endianess)}|${tag.to_long_or_short(endianess)}|${stream.get_pos()}|'
				for value in values {
					line += '${value},'
				}
				println(line)
			}
		}
		for length in 0 .. 9 {
			mut stream := zigimg.ReadStream.init_memory(bytes[..length])
			tag := zigimg.TiffTagField{
				data_type:  5
				data_count: 1
			}
			mut status := 'ok'
			mut values := [u32(0), 0]!
			values = tag.read_rational(mut stream, endianess) or {
				status = err.msg()
				values
			}
			println('R|${endian_index}|${length}|${status}|${stream.get_pos()}|${values[0]}|${values[1]}')
		}
	}
}

fn main() {
	assert os.args.len == 2
	name := os.args[1]
	if name == '--returning' {
		returning()
		return
	}
	mut stream := zigimg.ReadStream.init_memory([]u8{len: 1536})
	mut codec := zigimg.TIFF{
		endianess: .little
	}
	match name {
		'map_capacity_cast', 'map_capacity_power' {
			codec.ifd.tags_map.ensure_total_capacity(if name == 'map_capacity_cast' {
				u32(0xffffffff)
			} else {
				u32(0x80000000)
			}) or { panic(err) }
		}
		'unknown_tag' {
			stream = zigimg.ReadStream.init_memory([u8(1), 0, 0xe7, 3, 3, 0, 1, 0, 0, 0, 0, 0,
				0, 0, 0, 0, 0, 0])
			mut directory := zigimg.TiffIFD.init(&stream, 0) or { panic(err) }
			directory.read_tags(.little) or { panic(err) }
		}
		'compression_enum', 'resolution_enum' {
			key := if name == 'compression_enum' {
				zigimg.TiffTagId.compression
			} else {
				zigimg.TiffTagId.resolution_unit
			}
			codec.ifd.tags_map.put(key, zigimg.TiffTagField{ data_type: 3, data_count: 1 }) or {
				panic(err)
			}
			codec.decode_bitmap(mut stream) or { panic(err) }
		}
		'bits_capacity', 'extra_capacity' {
			key := if name == 'bits_capacity' {
				zigimg.TiffTagId.bits_per_sample
			} else {
				zigimg.TiffTagId.extra_samples
			}
			codec.ifd.tags_map.put(key, zigimg.TiffTagField{ data_type: 3, data_count: 9 }) or {
				panic(err)
			}
			codec.decode_bitmap(mut stream) or { panic(err) }
		}
		'empty_bits' {
			_ = codec.bitmap.guess_pixel_format() or { panic(err) }
		}
		'missing_alpha' {
			codec.bitmap.photometric_interpretation = 2
			codec.bitmap.bits_per_sample.resize(4)
			for i in 0 .. 4 {
				codec.bitmap.bits_per_sample.data[i] = 8
			}
			_ = codec.bitmap.guess_pixel_format() or { panic(err) }
		}
		'row_components' {
			codec.bitmap.samples_per_pixel = 2
			codec.bitmap.bits_per_sample.resize(1)
			codec.bitmap.bits_per_sample.data[0] = 8
			_ = codec.cal_row_byte_size() or { panic(err) }
		}
		'byte_overflow', 'array_type' {
			tag := zigimg.TiffTagField{
				data_type:  if name == 'byte_overflow' { u16(4) } else { u16(5) }
				data_count: if name == 'byte_overflow' { u32(0xffffffff) } else { u32(2) }
			}
			_ = tag.read_tag_data(mut stream, .little) or { panic(err) }
		}
		'palette_capacity', 'palette_power', 'short_palette' {
			if name != 'short_palette' {
				codec.ifd.tags_map.put(.bits_per_sample, zigimg.TiffTagField{
					data_type:   3
					data_count:  1
					data_offset: if name == 'palette_power' { u32(16) } else { u32(9) }
				}) or { panic(err) }
			}
			codec.ifd.tags_map.put(.color_map, zigimg.TiffTagField{
				data_type:  3
				data_count: if name == 'short_palette' { u32(1) } else { u32(768) }
			}) or { panic(err) }
			codec.decode_bitmap(mut stream) or { panic(err) }
		}
		else {
			panic('unknown case')
		}
	}

	eprintln('UNEXPECTED: TIFF metadata operation returned')
}
