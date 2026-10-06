module zigimg

fn test_tiff_record_scalars_copy_independently_and_remain_mutable() {
	mut header := TiffHeader{
		version:    65535
		idf_offset: 0xffffffff
	}
	copy_header := header
	header.version = 42
	header.idf_offset = 8
	assert copy_header.version == 65535 && copy_header.idf_offset == 0xffffffff
	mut packed := TiffPackedTag{
		tag_id:      256
		data_type:   3
		data_count:  1
		data_offset: 0x12345678
	}
	copy_packed := packed
	packed.data_offset = 0
	assert copy_packed.data_offset == 0x12345678
	mut tag := TiffTagField{
		data_type:   3
		data_count:  1
		data_offset: 0x12345678
	}
	copy_tag := tag
	tag.data_type = 4
	tag.data_offset = 9
	assert copy_tag.to_long() == 0x12345678
	assert copy_tag.to_short(.big) == 0x1234 && copy_tag.to_short(.little) == 0x5678
	assert tag.to_long_or_short(.big) == 9
	assert sizeof(TiffHeader) == 6 && sizeof(TiffPackedTag) == 12 && sizeof(TiffTagField) == 10
}

fn test_tiff_ifd_copies_borrow_the_stream_and_existing_map_entries() {
	mut stream := ReadStream.init_memory([u8(1), 2, 3, 4])
	mut original := TiffIFD{
		tags_map:    TiffTagMap{}
		read_stream: &stream
	}
	assert original.ifd_offset == 0 && original.num_tag_entries == 0
		&& original.next_ifd_offset == 0
	original.tags_map.put(.image_width, TiffTagField{ data_type: 4, data_count: 1, data_offset: 100 })!
	mut copied := original
	copied.ifd_offset = 17
	mut borrowed := unsafe { copied.read_stream }
	borrowed.seek_to(2)!
	original.tags_map.put(.image_width, TiffTagField{ data_type: 4, data_count: 1, data_offset: 200 })!
	assert original.ifd_offset == 0 && copied.ifd_offset == 17
	assert original.read_stream.get_pos() == 2 && copied.read_stream.get_pos() == 2
	assert (copied.tags_map.get(.image_width) or { panic('missing') }).data_offset == 200
	initialized := TiffIFD.init(&stream, 42)!
	assert initialized.ifd_offset == 42 && initialized.tags_map.count() == 0
	assert initialized.read_stream == &stream
}

fn test_tiff_bitmap_copy_preserves_borrowed_views_until_resize() {
	mut offsets := [u32(3), 4]
	mut original := TiffBitmapDescriptor{
		image_width:   100
		strip_offsets: offsets
	}
	original.bits_per_sample.resize(2)
	original.bits_per_sample.data[0] = 7
	original.bits_per_sample.data[1] = 8
	mut copied := original
	original.image_width = 101
	original.bits_per_sample.data[0] = 9
	offsets[1] = 42
	assert copied.image_width == 100
	assert (copied.strip_offsets or { panic('missing') })[1] == 42
	assert copied.bits_per_sample.data[0] == 9 && copied.bits_per_sample.storage[0] == 7
	copied.bits_per_sample.resize(1)
	copied.bits_per_sample.data[0] = 10
	assert original.bits_per_sample.data[0] == 9 && copied.bits_per_sample.data[0] == 10
}

fn test_tiff_default_bitmap_and_outer_codec_keep_defined_representation() {
	bitmap := TiffBitmapDescriptor{}
	assert bitmap.compression == .uncompressed && bitmap.resolution_unit == .no_unit
	assert bitmap.samples_per_pixel == 1 && bitmap.fill_order == 1
	assert bitmap.planar_configuration == 1 && bitmap.predictor == 1
	assert bitmap.bits_per_sample.data.len == 0 && bitmap.color_map.data.len == 0
	assert bitmap.extra_samples.data.len == 0 && bitmap.strip_offsets == none
	assert bitmap.strip_byte_counts == none
	// This zero state adapts Source TIFF's undefined defaults; it is not native parity.
	codec := TIFF{}
	assert codec.header.version == 0 && codec.header.idf_offset == 0
	assert codec.ifd.tags_map.count() == 0 && codec.ifd.read_stream == unsafe { nil }
}
