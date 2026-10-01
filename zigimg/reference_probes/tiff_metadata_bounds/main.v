module main

import os
import zigimg

fn main() {
	assert os.args.len == 2
	name := os.args[1]
	mut stream := zigimg.ReadStream.init_memory([]u8{len: 1536})
	mut codec := zigimg.TIFF{
		endianess: .little
	}
	match name {
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
