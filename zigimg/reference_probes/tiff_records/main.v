module main

import zigimg

fn main() {
	words := [u16(0), 1, 32768, 65535]
	longs := [u32(0), 1, 2147483648, 4294967295]
	for version in words {
		for offset in longs {
			mut original := zigimg.TiffHeader{
				version:    version
				idf_offset: offset
			}
			copied := original
			original.version = 42
			original.idf_offset = 17
			println('H|${sizeof(zigimg.TiffHeader)}|${copied.version}|${copied.idf_offset}|${original.version}|${original.idf_offset}')
		}
	}
	for tag_id in words {
		for data_type in words {
			for count in longs {
				for offset in longs {
					mut original := zigimg.TiffPackedTag{
						tag_id:      tag_id
						data_type:   data_type
						data_count:  count
						data_offset: offset
					}
					copied := original
					original.tag_id = 256
					original.data_type = 3
					original.data_count = 1
					original.data_offset = 7
					println('P|${sizeof(zigimg.TiffPackedTag)}|${copied.tag_id}|${copied.data_type}|${copied.data_count}|${copied.data_offset}|${original.tag_id}|${original.data_type}|${original.data_count}|${original.data_offset}')
				}
			}
		}
	}
	for data_type in [u16(0), 3, 4, 65535] {
		for count in longs {
			for offset in longs {
				mut original := zigimg.TiffTagField{
					data_type:   data_type
					data_count:  count
					data_offset: offset
				}
				copied := original
				original.data_type = 4
				original.data_count = 1
				original.data_offset = 9
				println('T|${sizeof(zigimg.TiffTagField)}|${copied.data_type}|${copied.data_count}|${copied.data_offset}|${copied.to_long()}|${copied.to_short(.big)}|${copied.to_short(.little)}|${copied.to_long_or_short(.big)}|${copied.to_long_or_short(.little)}|${original.data_type}|${original.data_count}|${original.data_offset}')
			}
		}
	}
	bitmap := zigimg.TiffBitmapDescriptor{}
	println('D|${u16(bitmap.compression)}|${bitmap.image_width}|${bitmap.image_height}|${bitmap.photometric_interpretation}|${bitmap.rows_per_strip}|${int(bitmap.strip_offsets == none)}|${int(bitmap.strip_byte_counts == none)}|${bitmap.x_resolution[0]}|${bitmap.x_resolution[1]}|${bitmap.y_resolution[0]}|${bitmap.y_resolution[1]}|${u16(bitmap.resolution_unit)}|${bitmap.bits_per_sample.data.len}|${bitmap.new_subfile_type}|${bitmap.color_map.data.len}|${bitmap.samples_per_pixel}|${bitmap.fill_order}|${bitmap.extra_samples.data.len}|${bitmap.planar_configuration}|${bitmap.predictor}')
	mut stream := zigimg.ReadStream.init_memory([u8(1), 2, 3, 4])
	mut directory := zigimg.TiffIFD{
		tags_map:    zigimg.TiffTagMap{}
		read_stream: &stream
	}
	println('I|${directory.ifd_offset}|${directory.num_tag_entries}|${directory.next_ifd_offset}|${directory.tags_map.count()}|${directory.tags_map.capacity()}|${int(directory.read_stream == &stream)}')
	initialized := zigimg.TiffIFD.init(&stream, 17) or { panic(err) }
	println('N|${initialized.ifd_offset}|${initialized.num_tag_entries}|${initialized.next_ifd_offset}|${initialized.tags_map.count()}|${int(initialized.read_stream == &stream)}')
	directory.tags_map.put(.image_width, zigimg.TiffTagField{
		data_type:   4
		data_count:  1
		data_offset: 100
	}) or { panic(err) }
	mut directory_copy := directory
	directory_copy.ifd_offset = 9
	directory_copy.num_tag_entries = 2
	directory_copy.next_ifd_offset = 11
	mut borrowed := unsafe { directory_copy.read_stream }
	borrowed.seek_to(2) or { panic(err) }
	directory.tags_map.put(.image_width, zigimg.TiffTagField{
		data_type:   4
		data_count:  1
		data_offset: 200
	}) or { panic(err) }
	println('C|${directory.ifd_offset}|${directory.num_tag_entries}|${directory.next_ifd_offset}|${directory_copy.ifd_offset}|${directory_copy.num_tag_entries}|${directory_copy.next_ifd_offset}|${stream.get_pos()}|${directory.read_stream.get_pos()}|${directory_copy.read_stream.get_pos()}|${(directory.tags_map.get(.image_width) or {
		panic('missing')
	}).data_offset}|${(directory_copy.tags_map.get(.image_width) or { panic('missing') }).data_offset}')
	mut offsets := [u32(3), 4]
	mut counts := [u32(5), 6]
	mut original := zigimg.TiffBitmapDescriptor{
		image_width:       100
		strip_offsets:     offsets
		strip_byte_counts: counts
	}
	original.bits_per_sample.resize(2)
	original.bits_per_sample.data[0] = 7
	original.bits_per_sample.data[1] = 8
	original.extra_samples.resize(1)
	original.extra_samples.data[0] = 2
	original.color_map.resize(1)
	original.color_map.data[0] = zigimg.Rgba32{
		r: 1
		g: 2
		b: 3
		a: 255
	}
	mut copied := original
	original.image_width = 101
	offsets[1] = 42
	counts[0] = 43
	original.bits_per_sample.data[0] = 9
	original.extra_samples.data[0] = 1
	original.color_map.data[0].r = 44
	copy_offsets := copied.strip_offsets or { panic('missing') }
	copied.strip_offsets = unsafe { copy_offsets[..1] }
	println('B|${original.image_width}|${copied.image_width}|${(original.strip_offsets or {
		panic('missing')
	}).len}|${(copied.strip_offsets or { panic('missing') }).len}|${(original.strip_offsets or {
		panic('missing')
	})[1]}|${(copied.strip_byte_counts or { panic('missing') })[0]}|${copied.bits_per_sample.data[0]}|${copied.bits_per_sample.storage[0]}|${copied.extra_samples.data[0]}|${copied.extra_samples.storage[0]}|${copied.color_map.data[0].r}|${copied.color_map.storage[0].r}')
	copied.bits_per_sample.resize(1)
	copied.extra_samples.resize(1)
	copied.color_map.resize(1)
	copied.bits_per_sample.data[0] = 10
	copied.extra_samples.data[0] = 3
	copied.color_map.data[0].r = 45
	println('R|${original.bits_per_sample.data[0]}|${copied.bits_per_sample.data[0]}|${original.extra_samples.data[0]}|${copied.extra_samples.data[0]}|${original.color_map.data[0].r}|${copied.color_map.data[0].r}')
	mut codec := zigimg.TIFF{}
	codec.endianess = .little
	codec.header = zigimg.TiffHeader{
		version:    42
		idf_offset: 17
	}
	codec.ifd = directory
	codec.bitmap = zigimg.TiffBitmapDescriptor{
		image_width:  12
		image_height: 13
	}
	println('F|${codec.header.version}|${codec.header.idf_offset}|${codec.width()}|${codec.height()}')
}
