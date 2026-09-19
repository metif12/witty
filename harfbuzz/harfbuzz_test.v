module harfbuzz

fn test_version_surface() {
	current := version()
	assert current.major > 0
	assert version_at_least(Version{
		major: 1
	})
	assert version_string().len > 0
}

fn test_common_enum_layouts() {
	assert sizeof(ContentType) == 1
	assert sizeof(ClusterLevel) == 1
	assert sizeof(Direction) == 1
	assert sizeof(Script) == 4
	assert u8(ClusterLevel.graphemes) == 3
	assert u8(Direction.bit) == 7
	assert u32(Script.common) == 0x5a797979
	assert u32(Script.arabic) == 0x41726162
	assert u32(Script.math) == 0x5a6d7468
	assert u32(Script.invalid) == 0
}

fn test_language_and_feature_roundtrip() {
	language := Language.from_string('en-US')
	assert language.to_string() == 'en-us'
	assert Language.get_default().to_string().len > 0

	feature := Feature.from_string('dlig') or {
		assert false
		return
	}
	mut buf := []u8{len: 64}
	feature.to_string(mut buf)
	text := unsafe { cstring_to_vstring(&char(buf.data)) }
	assert text == 'dlig'
}

fn test_buffer_complete_input_and_property_surface() {
	mut buffer := Buffer.create()!
	defer { buffer.destroy() }
	buffer.reset()
	buffer.set_content_type(.unicode)
	assert buffer.get_content_type() == .unicode
	buffer.set_cluster_level(.characters)
	buffer.set_direction(.ltr)
	assert buffer.get_direction() == .ltr
	buffer.set_script(.arabic)
	assert buffer.get_script() == .arabic
	language := Language.from_string('en')
	buffer.set_language(language)
	assert buffer.get_language().to_string() == 'en'

	buffer.add(u32(`A`), 27)
	buffer.add_codepoints([u32(`B`), u32(`C`)])
	buffer.add_utf32([u32(`D`), u32(`E`)])
	buffer.add_utf16([u16(`F`), u16(`G`)])
	buffer.add_utf8('HI'.bytes())
	buffer.add_latin1('JK'.bytes())
	assert buffer.get_length() == 11
	assert buffer.get_glyph_infos().len == 11
	positions := buffer.get_glyph_positions() or {
		assert false
		return
	}
	assert positions.len == 11

	buffer.reset()
	buffer.add_utf8('abc'.bytes())
	buffer.guess_segment_properties()
	assert buffer.get_direction() == .ltr
	assert buffer.get_script() == .latin
}
