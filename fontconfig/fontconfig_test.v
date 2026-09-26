module fontconfig

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
