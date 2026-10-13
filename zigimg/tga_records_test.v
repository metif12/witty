module zigimg

fn test_tga_packed_mutation_preserves_other_fields_and_copies() {
	for raw in 0 .. 256 {
		mut flags := TGAImageType{
			raw: u8(raw)
		}
		copied := flags
		flags.set_indexed(!flags.indexed())
		assert flags.raw == u8(raw ^ 1)
		flags.set_truecolor(!flags.truecolor())
		flags.set_pad0(!flags.pad0())
		flags.set_run_length(!flags.run_length())
		flags.set_pad1(15 - flags.pad1())
		assert flags.raw == u8(raw ^ 255)
		assert copied.raw == u8(raw)
		mut descriptor := TGADescriptor{
			raw: u8(raw)
		}
		descriptor_copy := descriptor
		descriptor.set_num_attributes_bit(15 - descriptor.num_attributes_bit())
		descriptor.set_right_to_left(!descriptor.right_to_left())
		descriptor.set_top_to_bottom(!descriptor.top_to_bottom())
		descriptor.set_pad(3 - descriptor.pad())
		assert descriptor.raw == u8(raw ^ 255)
		assert descriptor_copy.raw == u8(raw)
	}
}

fn test_tga_options_and_nested_record_mutation() {
	mut options := TgaEncoderOptions{}
	assert options.rle_compressed && options.top_to_bottom_image
	assert options.color_map_depth == 24 && options.software_version.letter == ` `
	options.rle_compressed = false
	options.top_to_bottom_image = false
	options.color_map_depth = 16
	options.author_name = 'author'
	options.author_comment.lines[3][79] = 42
	options.timestamp.year = 2026
	options.job_time.seconds = 17
	options.software_version.number = 123
	copied := options
	options.author_comment.lines[3][79] = 9
	options.timestamp.year = 1
	options.software_version.number = 1
	assert copied.author_comment.lines[3][79] == 42
	assert copied.timestamp.year == 2026 && copied.software_version.number == 123
	mut header := TGAHeader{}
	header.image_type.set_truecolor(true)
	header.image_spec.descriptor.set_top_to_bottom(true)
	header.image_spec.descriptor.set_num_attributes_bit(8)
	assert header.image_type.raw == 2 && header.image_spec.descriptor.raw == 40
	assert header.is_valid()
}
