module fontconfig

fn test_c_enum_layouts_and_values_match_source() {
	assert sizeof(SubstituteKind) == sizeof(u32)
	assert u32(SubstituteKind.pattern) == 0
	assert u32(SubstituteKind.font) == 1
	assert u32(SubstituteKind.scan) == 2

	assert sizeof(Weight) == sizeof(u32)
	assert u32(Weight.thin) == 0
	assert u32(Weight.extralight) == 40
	assert u32(Weight.light) == 50
	assert u32(Weight.demilight) == 55
	assert u32(Weight.book) == 75
	assert u32(Weight.regular) == 80
	assert u32(Weight.medium) == 100
	assert u32(Weight.demibold) == 180
	assert u32(Weight.bold) == 200
	assert u32(Weight.extrabold) == 205
	assert u32(Weight.black) == 210
	assert u32(Weight.extrablack) == 215

	assert sizeof(Slant) == sizeof(u32)
	assert u32(Slant.roman) == 0
	assert u32(Slant.italic) == 100
	assert u32(Slant.oblique) == 110

	assert sizeof(Spacing) == sizeof(u32)
	assert u32(Spacing.proportional) == 0
	assert u32(Spacing.dual) == 90
	assert u32(Spacing.mono) == 100
	assert u32(Spacing.charcell) == 110

	assert sizeof(MatchResult) == sizeof(u32)
	assert u32(MatchResult.match_) == 0
	assert u32(MatchResult.no_match) == 1
	assert u32(MatchResult.type_mismatch) == 2
	assert u32(MatchResult.no_id) == 3
	assert u32(MatchResult.out_of_memory) == 4
}

fn test_property_cval() {
	assert Property.family.cval() == 'family'
	assert Property.pixel_size.cval() == 'pixelsize'
	assert Property.postscript_name.cval() == 'postscriptname'
}

fn test_version_and_init_load_config() {
	assert fc_init()
	assert version() > 0
	config := init_load_config()
	assert !isnil(config.handle)
	config.destroy()
}

fn test_char_set_create_add_and_has() {
	charset := CharSet.create()
	defer { charset.destroy() }
	assert !charset.has_char(0x20)
	assert charset.add_char(0x20)
	assert charset.has_char(0x20)
}

fn test_lang_set_exact_match() {
	langset := LangSet.create()
	defer { langset.destroy() }
	assert langset.add_lang('en-US')
	assert langset.add_lang('und-zsye')
	assert langset.has_lang('en-US')
	assert langset.has_lang('und-zsye')
	assert !langset.has_lang('fr')
	assert !langset.has_lang('en-GB')
}

fn test_pattern_typed_values_delete_and_filter() {
	pattern := Pattern.create()
	defer { pattern.destroy() }
	assert pattern.add(.family, ValueString{ value: 'monospace' }, false)
	assert pattern.add(.weight, ValueInteger{ value: i32(Weight.bold) }, false)
	assert pattern.add(.dpi, ValueDouble{ value: 96.5 }, false)
	assert pattern.add(.antialias, ValueBool{ value: true }, false)

	family := pattern.get(.family, 0)!
	assert family.tag() == .string_
	assert (family as ValueString).value == 'monospace'
	weight := pattern.get(.weight, 0)!
	assert weight.tag() == .integer
	assert (weight as ValueInteger).value == i32(Weight.bold)
	dpi := pattern.get(.dpi, 0)!
	assert dpi.tag() == .double_
	assert (dpi as ValueDouble).value == 96.5
	antialias := pattern.get(.antialias, 0)!
	assert antialias.tag() == .bool_
	assert (antialias as ValueBool).value

	objects := ObjectSet.create()
	defer { objects.destroy() }
	assert objects.add(.family)
	filtered := pattern.filter(objects)
	defer { filtered.destroy() }
	assert (filtered.get(.family, 0)! as ValueString).value == 'monospace'
	if _ := filtered.get(.weight, 0) {
		assert false
	}

	assert pattern.delete(.family)
	if _ := pattern.get(.family, 0) {
		assert false
	}
}

fn test_pattern_parse() {
	pattern := Pattern.parse(':monospace')
	defer { pattern.destroy() }
	pattern.default_substitute()
	assert !isnil(pattern.handle)
}

fn test_font_list_and_pattern_iteration() {
	config := init_load_config_and_fonts()
	defer { config.destroy() }
	pattern := Pattern.create()
	defer { pattern.destroy() }
	objects := ObjectSet.create()
	defer { objects.destroy() }
	assert objects.add(.family)
	fonts := config.font_list(pattern, objects)
	defer { fonts.destroy() }
	assert fonts.fonts().len > 0

	first := fonts.fonts()[0]
	mut objects_it := first.object_iterator()
	assert objects_it.next()
	assert objects_it.object().len > 0
	assert objects_it.value_len() > 0
	mut values_it := objects_it.value_iterator()
	entry := values_it.next() or {
		assert false
		return
	}
	assert entry.result == .match_
	assert entry.value.tag() != .unknown
}

fn test_font_set_create() {
	fonts := FontSet.create()
	defer { fonts.destroy() }
	assert fonts.fonts().len == 0
}
