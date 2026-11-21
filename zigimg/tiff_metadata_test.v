module zigimg

import os

fn test_tiff_buffered_ifd_keeps_duplicates_and_inline_enum_halves_on_retry() {
	path := os.join_path(os.temp_dir(), 'witty-tiff-metadata-${os.getpid()}')
	defer { os.rm(path) or {} }
	for endianess in [TiffEndian.little, .big] {
		mut bytes := [u8(99)]
		tiff_test_append(mut bytes, 4, 2, endianess)
		for tag in [
			TiffPackedTag{
				tag_id:      256
				data_type:   4
				data_count:  1
				data_offset: 111
			},
			TiffPackedTag{
				tag_id:      259
				data_type:   5
				data_count:  0
				data_offset: if endianess == .little { u32(0xa35c8005) } else { u32(0x8005a35c) }
			},
			TiffPackedTag{
				tag_id:      256
				data_type:   4
				data_count:  1
				data_offset: 222
			},
			TiffPackedTag{
				tag_id:      296
				data_type:   0
				data_count:  65535
				data_offset: if endianess == .little { u32(0xa35c0002) } else { u32(0x0002a35c) }
			},
		] {
			tiff_test_append(mut bytes, tag.tag_id, 2, endianess)
			tiff_test_append(mut bytes, tag.data_type, 2, endianess)
			tiff_test_append(mut bytes, tag.data_count, 4, endianess)
			tiff_test_append(mut bytes, tag.data_offset, 4, endianess)
		}
		tiff_test_append(mut bytes, 0x12345678, 4, endianess)
		os.write_file_array(path, bytes)!
		mut file := os.open(path)!
		mut buffer := []u8{len: 4, init: 165}
		mut stream := ReadStream.init_file(file, mut buffer)
		mut codec := TIFF{
			endianess: endianess
			ifd:       TiffIFD.init(&stream, 1)!
		}
		for _ in 0 .. 2 {
			codec.ifd.read_tags(endianess)!
			codec.decode_bitmap(mut stream)!
			assert codec.ifd.num_tag_entries == 4
			assert codec.ifd.next_ifd_offset == 0x12345678
			assert codec.ifd.tags_map.count() == 3
			assert codec.bitmap.image_width == 222
			assert codec.bitmap.compression == .packbits
			assert codec.bitmap.resolution_unit == .inch
			assert codec.bitmap.bits_per_sample.data == [u16(1)]
			assert stream.get_pos() == u64(bytes.len)
		}
		file.close()
	}
}

fn test_tiff_file_tag_arrays_can_exceed_the_reader_buffer() {
	path := os.join_path(os.temp_dir(), 'witty-tiff-arrays-${os.getpid()}')
	defer { os.rm(path) or {} }
	for endianess in [TiffEndian.big, .little] {
		for datatype in [u16(3), 4] {
			stride := if datatype == 3 { 2 } else { 4 }
			values := []u32{len: 31, init: u32(index * 1973 + 0x1234)}
			mut bytes := [u8(99)]
			for value in values {
				tiff_test_append(mut bytes, value, stride, endianess)
			}
			bytes << [u8(99), 88, 77]
			os.write_file_array(path, bytes)!
			for capacity in [4, 8, 16, 64] {
				mut file := os.open(path)!
				mut buffer := []u8{len: capacity, init: 165}
				mut stream := ReadStream.init_file(file, mut buffer)
				tag := TiffTagField{
					data_type:   datatype
					data_count:  31
					data_offset: 1
				}
				for _ in 0 .. 2 {
					assert tag.read_tag_data(mut stream, endianess)! == values
					assert stream.get_pos() == u64(1 + 31 * stride)
				}
				file.close()
			}
		}
	}
}

fn test_tiff_long_palette_words_truncate_channels_and_keep_inactive_backing() {
	path := os.join_path(os.temp_dir(), 'witty-tiff-long-palette-${os.getpid()}')
	defer { os.rm(path) or {} }
	for endianess in [TiffEndian.big, .little] {
		mut bytes := [u8(99)]
		for value in [u32(0x12345678), 0xffffffff, 0x87654321, 0x00010000, 0x0000ff00, 0xff001200] {
			tiff_test_append(mut bytes, value, 4, endianess)
		}
		bytes << [u8(99), 88, 77]
		for capacity in [0, 4, 8, 16, 64] {
			mut stream := ReadStream.init_memory(bytes)
			mut buffer := []u8{len: capacity, init: 165}
			mut file := os.File{}
			if capacity > 0 {
				os.write_file_array(path, bytes)!
				file = os.open(path)!
				stream = ReadStream.init_file(file, mut buffer)
			}
			mut codec := TIFF{
				endianess: endianess
			}
			codec.bitmap.color_map.resize(3)
			retained := Rgba32{
				r: 19
				g: 23
				b: 29
				a: 31
			}
			codec.bitmap.color_map.data[2] = retained
			codec.ifd.tags_map.put(.color_map, TiffTagField{
				data_type:   4
				data_count:  6
				data_offset: 1
			})!
			codec.decode_bitmap(mut stream)!
			assert codec.bitmap.bits_per_sample.data == [u16(1)]
			assert codec.bitmap.color_map.data == [
				Rgba32{
					r: 0x56
					g: 0x43
					b: 0xff
					a: 255
				},
				Rgba32{
					r: 0xff
					g: 0
					b: 0x12
					a: 255
				},
			]
			assert codec.bitmap.color_map.storage[2] == retained
			assert stream.get_pos() == 25
			if capacity > 0 { file.close() }
		}
	}
}

fn tiff_test_mix(mut hash []u64, value u64) {
	hash[0] = (hash[0] ^ value) * u64(1099511628211)
}

fn tiff_test_append(mut bytes []u8, value u32, size int, endianess TiffEndian) {
	for index in 0 .. size {
		shift := if endianess == .big { (size - index - 1) * 8 } else { index * 8 }
		bytes << u8(value >> shift)
	}
}

fn test_tiff_records_inline_data_and_rational_positions() {
	assert sizeof(TiffHeader) == 6 && sizeof(TiffPackedTag) == 12 && sizeof(TiffTagField) == 10
	for endianess in [TiffEndian.big, .little] {
		tag := TiffTagField{
			data_type:   3
			data_count:  1
			data_offset: 0x12345678
		}
		assert tag.to_long() == 0x12345678
		assert tag.to_short(endianess) == if endianess == .big {
			u16(0x1234)
		} else {
			u16(0x5678)
		}
		assert tag.to_long_or_short(endianess) == u32(tag.to_short(endianess))
		mut stream := ReadStream.init_memory([]u8{})
		assert tag.read_tag_data(mut stream, endianess)! == [u32(0x12345678)]
		assert stream.get_pos() == 0
		mut bytes := [u8(0)]
		tiff_test_append(mut bytes, 0x12345678, 4, endianess)
		tiff_test_append(mut bytes, 0x87654321, 4, endianess)
		stream = ReadStream.init_memory(bytes)
		rational := TiffTagField{
			data_type:   0
			data_count:  0
			data_offset: 1
		}.read_rational(mut stream, endianess)!
		assert rational == [u32(0x12345678), 0x87654321]!
		assert stream.get_pos() == 9
	}
}

fn test_tiff_tag_arrays_count_zero_and_endian_decoding() {
	for endianess in [TiffEndian.big, .little] {
		for data_type in [u16(3), 4] {
			mut bytes := [u8(0)]
			stride := if data_type == 3 { 2 } else { 4 }
			for value in [u32(0x1234), 0x5678, 0x9abc] {
				tiff_test_append(mut bytes, value, stride, endianess)
			}
			mut stream := ReadStream.init_memory(bytes)
			tag := TiffTagField{
				data_type:   data_type
				data_count:  3
				data_offset: 1
			}
			assert tag.read_tag_data(mut stream, endianess)! == [u32(0x1234), 0x5678, 0x9abc]
			assert stream.get_pos() == u64(1 + stride * 3)
		}
		mut stream := ReadStream.init_memory([u8(0)])
		assert TiffTagField{
			data_count:  0
			data_offset: 0
			data_type:   5
		}.read_tag_data(mut stream, endianess)!.len == 0
		assert stream.get_pos() == 0
		mut partial := [u8(0)]
		tiff_test_append(mut partial, 0x1234, 2, endianess)
		partial << u8(0xab)
		stream = ReadStream.init_memory(partial)
		values := TiffTagField{
			data_type:   3
			data_count:  3
			data_offset: 1
		}.read_tag_data(mut stream, endianess)!
		// Only the first complete sample is defined in the source allocation.
		assert values.len == 3 && values[0] == 0x1234
		assert stream.get_pos() == 4
	}
}

fn test_tiff_ifd_matches_native_hashmap_growth_duplicates_and_iteration() {
	mut hash := [u64(14695981039346656037)]
	for seed in 0 .. 32 {
		mut table := TiffTagMap{}
		for iteration in 0 .. 96 {
			key := tiff_tag_ids[(iteration * 13 + seed * 7) % tiff_tag_ids.len]
			table.put(key, TiffTagField{
				data_type:   0
				data_count:  0
				data_offset: u32(iteration + seed * 100)
			})!
			tiff_test_mix(mut hash, table.capacity())
			tiff_test_mix(mut hash, table.count())
			mut iterator := table.key_iterator()
			for {
				item := iterator.next() or { break }
				tiff_test_mix(mut hash, u64(*item))
				tiff_test_mix(mut hash, (table.get(*item) or { panic('missing') }).data_offset)
			}
		}
	}
	eprintln('TIFF tag map: 3072 insertions, ${hash[0]:016x}')
	assert hash[0] == u64(0x219bfd777d44f15d)
}

fn test_tiff_ifd_parses_endian_records_and_preserves_failure_progress() {
	for endianess in [TiffEndian.big, .little] {
		mut bytes := [u8(0)]
		tiff_test_append(mut bytes, 3, 2, endianess)
		for i in 0 .. 3 {
			tiff_test_append(mut bytes, u32(TiffTagId.image_width), 2, endianess)
			tiff_test_append(mut bytes, 3, 2, endianess)
			tiff_test_append(mut bytes, 1, 4, endianess)
			tiff_test_append(mut bytes, u32(i + 1) << if endianess == .big { 16 } else { 0 }, 4,
				endianess)
		}
		tiff_test_append(mut bytes, 0x12345678, 4, endianess)
		for length in 0 .. bytes.len + 1 {
			mut stream := ReadStream.init_memory(unsafe { bytes[..length] })
			mut directory := TiffIFD.init(&stream, 1)!
			directory.read_tags(endianess) or {
				assert directory.num_tag_entries == 0 && directory.tags_map.count() == 0
				assert stream.get_pos() == if length <= 1 {
					u64(0)
				} else if length < 3 {
					u64(1)
				} else if length < 39 {
					u64(length)
				} else {
					u64(39)
				}
				assert err.msg() == if length <= 1 {
					'Unseekable'
				} else {
					'EndOfStream'
				}
				continue
			}
			assert length == bytes.len
			assert stream.get_pos() == u64(bytes.len)
			assert directory.num_tag_entries == 3 && directory.next_ifd_offset == 0x12345678
			assert directory.tags_map.count() == 1
			assert (directory.tags_map.get(.image_width) or { panic('missing') }).to_short(endianess) == 3
		}
	}
}

fn test_tiff_bitmap_format_and_row_size_match_native_matrix() {
	mut hash := [u64(14695981039346656037)]
	mut cases := 0
	for compression in [TiffCompressionType.uncompressed, .ccitt_rle, .gp_3_fax, .gp_4_fax, .lzw,
		.jpeg, .deflate, .uncompressed_old, .packbits, .pixar_deflate] {
		for photo in 0 .. 6 {
			for count in 1 .. 9 {
				for bits in [u16(1), 4, 8, 16, 255] {
					for extra in 0 .. 4 {
						for flags in 0 .. 4 {
							mut codec := TIFF{}
							codec.bitmap.compression = compression
							codec.bitmap.photometric_interpretation = u16(photo)
							codec.bitmap.fill_order = u16(1 + (flags & 1))
							codec.bitmap.predictor = u16(1 + (flags >> 1))
							codec.bitmap.bits_per_sample.resize(uint(count))
							for i in 0 .. count {
								codec.bitmap.bits_per_sample.data[i] = bits
							}
							codec.bitmap.extra_samples.resize(1)
							codec.bitmap.extra_samples.data[0] = u16(extra)
							format := codec.bitmap.guess_pixel_format() or {
								assert err.msg() == 'Unsupported'
								PixelFormat.invalid
							}
							for value in [u64(compression), u64(photo), u64(count), u64(bits),
								u64(extra), u64(flags), u64(format)] {
								tiff_test_mix(mut hash, value)
							}
							cases++
							for width in [u32(0), 1, 7, 8, 17, 65535] {
								codec.bitmap.image_width = width
								codec.bitmap.samples_per_pixel = u16(count)
								row := codec.cal_row_byte_size() or {
									assert err.msg() == 'Unsupported'
									~uint(0)
								}
								tiff_test_mix(mut hash, u64(row))
								assert codec.width() == uint(width)
							}
						}
					}
				}
			}
		}
	}
	eprintln('TIFF bitmap matrix: ${cases} cases, ${hash[0]:016x}')
	assert cases == 38400
	assert hash[0] == u64(0x31cf888a600f81f5)
}

fn test_tiff_metadata_keeps_defaults_ignored_tags_and_inline_short_words() {
	mut codec := TIFF{
		endianess: .big
	}
	codec.ifd.tags_map.put(.image_width, TiffTagField{
		data_type:   3
		data_count:  1
		data_offset: 7 << 16
	})!
	codec.ifd.tags_map.put(.image_height, TiffTagField{ data_type: 4, data_count: 1, data_offset: 9 })!
	codec.ifd.tags_map.put(.strip_offsets, TiffTagField{
		data_type:   3
		data_count:  1
		data_offset: 12 << 16
	})!
	codec.ifd.tags_map.put(.fill_order, TiffTagField{
		data_type:   3
		data_count:  1
		data_offset: 2 << 16
	})!
	codec.ifd.tags_map.put(.orientation, TiffTagField{ data_type: 0, data_count: 0, data_offset: 42 })!
	codec.ifd.tags_map.put(.new_subfile_type, TiffTagField{
		data_type:   3
		data_count:  1
		data_offset: 3 << 16
	})!
	mut stream := ReadStream.init_memory([]u8{})
	codec.decode_bitmap(mut stream)!
	assert codec.width() == 7 && codec.height() == 9
	assert codec.bitmap.bits_per_sample.data == [u16(1)]
	assert codec.bitmap.fill_order == 1 && codec.bitmap.predictor == 1
	assert codec.bitmap.compression == .uncompressed && codec.bitmap.resolution_unit == .no_unit
	assert codec.bitmap.new_subfile_type == 3 << 16
	assert (codec.bitmap.strip_offsets or { panic('offsets') }) == [u32(12 << 16)]
	assert stream.get_pos() == 0
	assert codec.bitmap.guess_pixel_format()! == .grayscale1
	assert codec.cal_row_byte_size()! == 0
}

fn test_tiff_metadata_component_arrays_truncate_and_ignore_sample_count_for_selection() {
	for endianess in [TiffEndian.big, .little] {
		for count in [3, 4] {
			mut bytes := [u8(0)]
			for i in 0 .. count {
				tiff_test_append(mut bytes, u32((i + 1) << 16) | 8, 4, endianess)
			}
			mut stream := ReadStream.init_memory(bytes)
			mut codec := TIFF{
				endianess: endianess
			}
			codec.bitmap.photometric_interpretation = 2
			codec.bitmap.image_width = 7
			codec.ifd.tags_map.put(.bits_per_sample, TiffTagField{
				data_type:   4
				data_count:  u32(count)
				data_offset: 1
			})!
			if count == 4 {
				codec.ifd.tags_map.put(.extra_samples, TiffTagField{
					data_type:   3
					data_count:  1
					data_offset: if endianess == .big { u32(2 << 16) } else { u32(2) }
				})!
			}
			codec.decode_bitmap(mut stream)!
			assert codec.bitmap.bits_per_sample.data == []u16{len: count, init: 8}
			assert codec.bitmap.samples_per_pixel == 1
			assert codec.bitmap.guess_pixel_format()! == if count == 3 {
				PixelFormat.rgb24
			} else {
				PixelFormat.rgba32
			}
			assert codec.cal_row_byte_size()! == 7
			assert stream.get_pos() == u64(bytes.len)
		}
		for key in [TiffTagId.bits_per_sample, .extra_samples] {
			mut stream := ReadStream.init_memory([]u8{})
			mut codec := TIFF{
				endianess: endianess
			}
			codec.ifd.tags_map.put(key, TiffTagField{ data_offset: 0, data_type: 3, data_count: 2 })!
			mut failed := false
			codec.decode_bitmap(mut stream) or {
				assert err.msg() == 'Unsupported'
				failed = true
			}
			assert failed && stream.get_pos() == 0
			assert if key == .bits_per_sample {
				codec.bitmap.bits_per_sample.data.len == 2
			} else {
				codec.bitmap.extra_samples.data.len == 2
			}
		}
	}
}

fn tiff_test_metadata_tag(key TiffTagId, endianess TiffEndian) TiffTagField {
	value := match key {
		.image_width { u32(7) }
		.image_height { u32(9) }
		.compression, .samples_per_pixel { u32(1) }
		.bits_per_sample { u32(8) }
		.photometric_interpretation, .predictor, .rows_per_strip { u32(3) }
		.strip_offsets { u32(10) }
		.strip_byte_counts { u32(88) }
		.new_subfile_type { u32(42) }
		else { u32(2) }
	}

	if key == .color_map { return TiffTagField{
			data_type:   3
			data_count:  768
			data_offset: 1
		} }
	if key in [.x_resolution, .y_resolution] { return TiffTagField{
			data_type:   5
			data_count:  1
			data_offset: 1537
		} }
	return TiffTagField{
		data_type:   if key in [.image_width, .image_height] { u16(4) } else { u16(3) }
		data_count:  1
		data_offset: if endianess == .big && key !in [.image_width, .image_height] {
			value << 16
		} else {
			value
		}
	}
}

fn test_tiff_metadata_processing_matches_native_tag_order_and_palette_channels() {
	mut hash := [u64(14695981039346656037)]
	mut counts := []int{len: 257}
	for endianess in [TiffEndian.big, .little] {
		mut bytes := [u8(0)]
		for i in 0 .. 768 {
			tiff_test_append(mut bytes, u32((i * 251 + 17) & 65535), 2, endianess)
		}
		tiff_test_append(mut bytes, 10, 4, endianess)
		tiff_test_append(mut bytes, 2, 4, endianess)
		for seed in 0 .. 32 {
			for count in 0 .. 33 {
				for reservation in [u32(0), 200] {
					mut codec := TIFF{
						endianess: endianess
					}
					codec.ifd.tags_map.ensure_total_capacity(reservation)!
					for key in [TiffTagId.bits_per_sample, .color_map, .photometric_interpretation] {
						codec.ifd.tags_map.put(key, tiff_test_metadata_tag(key, endianess))!
					}
					for i in 0 .. count {
						key := tiff_tag_ids[(i * 13 + seed * 7) % tiff_tag_ids.len]
						codec.ifd.tags_map.put(key, tiff_test_metadata_tag(key, endianess))!
					}
					mut stream := ReadStream.init_memory(bytes)
					codec.decode_bitmap(mut stream)!
					bitmap := &codec.bitmap
					for value in [u64(endianess), u64(seed), u64(count), u64(reservation),
						u64(stream.get_pos()), u64(bitmap.compression), u64(bitmap.image_width),
						u64(bitmap.image_height), u64(bitmap.photometric_interpretation),
						u64(bitmap.rows_per_strip), u64(bitmap.resolution_unit),
						u64(bitmap.new_subfile_type), u64(bitmap.samples_per_pixel),
						u64(bitmap.fill_order), u64(bitmap.planar_configuration),
						u64(bitmap.predictor)] {
						tiff_test_mix(mut hash, value)
					}
					for values in [bitmap.bits_per_sample.data, bitmap.extra_samples.data] {
						tiff_test_mix(mut hash, u64(values.len))
						for value in values {
							tiff_test_mix(mut hash, value)
						}
					}
					for optional in [bitmap.strip_offsets, bitmap.strip_byte_counts] {
						values := optional or {
							tiff_test_mix(mut hash, ~u64(0))
							continue
						}

						tiff_test_mix(mut hash, u64(values.len))
						for value in values {
							tiff_test_mix(mut hash, value)
						}
					}
					for value in [bitmap.x_resolution[0], bitmap.x_resolution[1], bitmap.y_resolution[0],
						bitmap.y_resolution[1]] {
						tiff_test_mix(mut hash, value)
					}
					tiff_test_mix(mut hash, u64(bitmap.color_map.data.len))
					assert bitmap.color_map.data.len in [2, 256]
					counts[bitmap.color_map.data.len]++
					for color in bitmap.color_map.data {
						for byte in [color.r, color.g, color.b, color.a] {
							tiff_test_mix(mut hash, byte)
						}
					}
					assert bitmap.guess_pixel_format()! == .indexed8
				}
			}
		}
	}
	eprintln('TIFF metadata matrix: 4224 cases, ${hash[0]:016x}, palettes ${counts[2]}/${counts[256]}')
	assert counts[2] > 0 && counts[256] > 0
	assert hash[0] == u64(0xe34da5c38c1d06cd)
}
