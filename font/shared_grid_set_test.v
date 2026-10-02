module font

// Tests for SharedGridSet.
// Translated from ghostty/src/font/SharedGridSet.zig tests.

fn test_gridset_local_tag_layouts_and_source_ordinals() {
	assert sizeof(MetricsKey) == 1
	mut metric_count := 0
	$for enum_value in MetricsKey.values {
		assert u8(enum_value.value) == u8(metric_count)
		metric_count++
	}
	assert metric_count == 17
	assert u8(MetricsKey.cell_width) == 0
	assert u8(MetricsKey.icon_height) == 12
	assert u8(MetricsKey.face_y) == 16
}

fn test_gridset_derived_config_init_clones_owned_values() {
	mut source := DerivedConfig{
		font_family: ['Menlo']
		font_variation: [Variation{
			id: VariationId.init('wght')
			value: 500
		}]
	}
	source.font_codepoint_map.add(CodepointMapEntry{
		range: [u32(`A`), u32(`Z`)]!
		descriptor: Descriptor{ family: 'Menlo' }
	})
	mut cloned := DerivedConfig.init(&source)!
	defer { cloned.deinit() }

	source.font_family[0] = 'Changed'
	source.font_variation[0] = Variation{
		id: VariationId.init('wght')
		value: 700
	}
	source.font_codepoint_map.entries[0].descriptor.family = 'Changed'
	assert cloned.font_family == ['Menlo']
	assert cloned.font_variation[0].value == 500
	assert cloned.font_codepoint_map.entries[0].descriptor.family or { '' } == 'Menlo'
}

fn test_gridset_key_init() {
	cfg := DerivedConfig{}
	mut k := Key.init(&cfg, DesiredSize{ points: 12 })!
	defer { k.deinit() }

	mut k2 := Key.init(&cfg, DesiredSize{ points: 12 })!
	defer { k2.deinit() }

	assert k.hashcode() > 0
	assert k.hashcode() == k2.hashcode()
}

fn test_gridset_key_hash_matches_source() {
	cfg := DerivedConfig{}
	mut key := Key.init(&cfg, DesiredSize{ points: 12 })!
	defer { key.deinit() }

	// Independently calculated with Zig 0.15.2 for the source's FreeType and
	// CoreText (void FreeType flags) key layouts. DesiredSize defaults to 72 DPI on macOS and 96 elsewhere.
	$if macos {
		assert key.hashcode() == if Backend.selected_().has_freetype() { u64(0x3a322c8692e38d75) } else { u64(0x9c528e55acd4539d) }
	} $else {
		assert key.hashcode() == if Backend.selected_().has_freetype() { u64(0xc78b44b38c1a7e47) } else { u64(0xf43e656d384883da) }
	}
	mut hasher := SourceHash{}
	key.hash(mut hasher)
	assert hasher.final() == key.hashcode()
}

fn test_gridset_key_metric_key_tags_match_source() {
	mut modifiers := MetricsModifierSet{}
	modifiers.put(.cursor_thickness, MetricsModifier(MetricsModifierPercent{ value: 1.25 }))
	modifiers.put(.cursor_height, MetricsModifier(MetricsModifierAbsolute{ value: -3 }))
	mut key := Key{
		metric_modifiers: modifiers
		font_size: DesiredSize{ points: 12 }
	}
	defer { key.deinit() }

	// Metrics.Key is generated from source declaration order: thickness is
	// tag 10 and height is tag 11. The values were calculated by Zig 0.15.2.
	$if macos {
		assert key.hashcode() == if Backend.selected_().has_freetype() { u64(0x7ed58b28da079a17) } else { u64(0x4e1a6cac06c0e8aa) }
	} $else {
		assert key.hashcode() == if Backend.selected_().has_freetype() { u64(0x0626e065a30c30bb) } else { u64(0x637b756d071d3817) }
	}
}

fn test_gridset_key_different_font_points() {
	cfg := DerivedConfig{}
	mut k := Key.init(&cfg, DesiredSize{ points: 12 })!
	defer { k.deinit() }

	mut k2 := Key.init(&cfg, DesiredSize{ points: 16 })!
	defer { k2.deinit() }

	assert k.hashcode() != k2.hashcode()
}

fn test_gridset_key_preserves_exact_font_point_bits() {
	cfg := DerivedConfig{}
	mut k := Key.init(&cfg, DesiredSize{ points: f32(12.000001) })!
	defer { k.deinit() }

	mut k2 := Key.init(&cfg, DesiredSize{ points: f32(12.000002) })!
	defer { k2.deinit() }

	assert k.font_size.points != k2.font_size.points
	assert k.hashcode() != k2.hashcode()
}

fn test_gridset_key_different_font_dpi() {
	cfg := DerivedConfig{}
	mut k := Key.init(&cfg, DesiredSize{ points: 12, xdpi: 1 })!
	defer { k.deinit() }

	mut k2 := Key.init(&cfg, DesiredSize{ points: 12, xdpi: 2 })!
	defer { k2.deinit() }

	assert k.hashcode() != k2.hashcode()
}

fn test_gridset_key_with_families() {
	// Test that keys with different font families produce different hashes.
	mut cfg1 := DerivedConfig{
		font_family: ['Fira Code']
	}
	mut cfg2 := DerivedConfig{
		font_family: ['JetBrains Mono']
	}

	mut k1 := Key.init(&cfg1, DesiredSize{ points: 12 })!
	defer { k1.deinit() }
	mut k2 := Key.init(&cfg2, DesiredSize{ points: 12 })!
	defer { k2.deinit() }

	assert k1.hashcode() != k2.hashcode()
}

fn test_gridset_key_descriptors_for_style() {
	cfg := DerivedConfig{
		font_family: ['Regular Font']
		font_family_bold: ['Bold Font']
		font_family_italic: ['Italic Font']
		font_family_bold_italic: ['BoldItalic Font']
	}
	k := Key.init(&cfg, DesiredSize{ points: 12 })!

	regular := k.descriptors_for_style(.regular)
	assert regular.len == 1
	assert regular[0].family or { '' } == 'Regular Font'

	bold := k.descriptors_for_style(.bold)
	assert bold.len == 1
	assert bold[0].family or { '' } == 'Bold Font'

	italic := k.descriptors_for_style(.italic)
	assert italic.len == 1
	assert italic[0].family or { '' } == 'Italic Font'

	bold_italic := k.descriptors_for_style(.bold_italic)
	assert bold_italic.len == 1
	assert bold_italic[0].family or { '' } == 'BoldItalic Font'
}

fn test_gridset_key_metric_modifiers() {
	// Test that keys with different metric modifiers produce different hashes.
	cfg1 := DerivedConfig{
		adjust_cell_width: MetricsModifier(MetricsModifierPercent{ value: 1.2 })
	}
	cfg2 := DerivedConfig{}

	mut k1 := Key.init(&cfg1, DesiredSize{ points: 12 })!
	defer { k1.deinit() }
	mut k2 := Key.init(&cfg2, DesiredSize{ points: 12 })!
	defer { k2.deinit() }

	assert k1.hashcode() != k2.hashcode()
}

fn test_gridset_key_preserves_exact_metric_modifier_bits() {
	cfg1 := DerivedConfig{
		adjust_cell_width: MetricsModifier(MetricsModifierPercent{ value: 1.200001 })
	}
	cfg2 := DerivedConfig{
		adjust_cell_width: MetricsModifier(MetricsModifierPercent{ value: 1.200002 })
	}

	mut k1 := Key.init(&cfg1, DesiredSize{ points: 12 })!
	defer { k1.deinit() }
	mut k2 := Key.init(&cfg2, DesiredSize{ points: 12 })!
	defer { k2.deinit() }

	assert k1.hashcode() != k2.hashcode()
}

fn test_metrics_modifier_hashes_active_payload() {
	percent1 := MetricsModifier(MetricsModifierPercent{ value: 1.25 })
	percent2 := MetricsModifier(MetricsModifierPercent{ value: 1.25 })
	mut percent1_hash := SourceHash{}
	percent1.hash(mut percent1_hash)
	mut percent2_hash := SourceHash{}
	percent2.hash(mut percent2_hash)
	assert percent1_hash.final() == percent2_hash.final()

	absolute1 := MetricsModifier(MetricsModifierAbsolute{ value: 3 })
	absolute2 := MetricsModifier(MetricsModifierAbsolute{ value: 3 })
	mut absolute1_hash := SourceHash{}
	absolute1.hash(mut absolute1_hash)
	mut absolute2_hash := SourceHash{}
	absolute2.hash(mut absolute2_hash)
	assert absolute1_hash.final() == absolute2_hash.final()
}

fn test_gridset_metrics_modifier_set() {
	mut set := MetricsModifierSet{}
	assert set.count() == 0

	set.put(.cell_width, MetricsModifier(MetricsModifierPercent{ value: 1.2 }))
	assert set.count() == 1

	if m := set.get(.cell_width) {
		assert m is MetricsModifierPercent
		assert m.value == 1.2
	} else {
		assert false
	}

	assert set.get(.cell_height) == none
}

fn test_gridset_derived_config_defaults() {
	cfg := DerivedConfig{}
	assert cfg.font_family.len == 0
	assert cfg.font_synthetic_style.bold() == true
	assert cfg.font_synthetic_style.italic() == true
	assert cfg.freetype_load_flags.hinting() == true
	assert cfg.freetype_load_flags.light() == true
}

fn test_shared_grid_set_init_deinit() {
	mut set := SharedGridSet.init() or {
		assert false, err.msg()
		return
	}
	defer { set.deinit() }
	assert set.count() == 0
}

fn test_shared_grid_set_ref_deref() {
	mut set := SharedGridSet.init() or {
		assert false, err.msg()
		return
	}
	defer { set.deinit() }

	cfg := DerivedConfig{}

	key1, grid1 := set.ref(&cfg, DesiredSize{ points: 12 }) or {
		assert false, err.msg()
		return
	}
	assert set.count() == 1

	key2, grid2 := set.ref(&cfg, DesiredSize{ points: 12 }) or {
		assert false, err.msg()
		return
	}
	assert set.count() == 1
	assert voidptr(grid1) == voidptr(grid2)

	set.deref(key2)
	assert set.count() == 1

	set.deref(key1)
	assert set.count() == 0
}

fn test_gridset_key_ignores_freetype_flags_without_freetype_backend() ! {
	mut first := Key.init(&DerivedConfig{}, DesiredSize{ points: 12 })!
	defer { first.deinit() }
	mut second := Key.init(&DerivedConfig{ freetype_load_flags: FreetypeLoadFlags.init(false, true, true, false, false) }, DesiredSize{ points: 12 })!
	defer { second.deinit() }
	assert (first.hashcode() != second.hashcode()) == Backend.selected_().has_freetype()
}
