module font

// Tests for SharedGridSet.
// Translated from ghostty/src/font/SharedGridSet.zig tests.

fn test_gridset_key_init() {
	cfg := GridSetDerivedConfig{}
	mut k := GridSetKey.init(&cfg, DesiredSize{ points: 12 })
	defer { k.deinit() }

	mut k2 := GridSetKey.init(&cfg, DesiredSize{ points: 12 })
	defer { k2.deinit() }

	assert k.hashcode() > 0
	assert k.hashcode() == k2.hashcode()
}

fn test_gridset_key_hash_matches_source() {
	cfg := GridSetDerivedConfig{}
	mut key := GridSetKey.init(&cfg, DesiredSize{ points: 12 })
	defer { key.deinit() }

	// Independently calculated with Zig 0.15.2 for the source's FreeType key
	// layout. DesiredSize defaults to 72 DPI on macOS and 96 elsewhere.
	$if macos {
		assert key.hashcode() == u64(0x3a322c8692e38d75)
	} $else {
		assert key.hashcode() == u64(0xc78b44b38c1a7e47)
	}
}

fn test_gridset_key_metric_key_tags_match_source() {
	mut modifiers := MetricsModifierSet{}
	modifiers.put(.cursor_thickness, MetricsModifier{
		is_percent: true
		percent: 1.25
	})
	modifiers.put(.cursor_height, MetricsModifier{
		absolute: -3
	})
	mut key := GridSetKey{
		metric_modifiers: modifiers
		font_size: DesiredSize{ points: 12 }
	}
	defer { key.deinit() }

	// Metrics.Key is generated from source declaration order: thickness is
	// tag 10 and height is tag 11. The values were calculated by Zig 0.15.2.
	$if macos {
		assert key.hashcode() == u64(0x7ed58b28da079a17)
	} $else {
		assert key.hashcode() == u64(0x0626e065a30c30bb)
	}
}

fn test_gridset_key_different_font_points() {
	cfg := GridSetDerivedConfig{}
	mut k := GridSetKey.init(&cfg, DesiredSize{ points: 12 })
	defer { k.deinit() }

	mut k2 := GridSetKey.init(&cfg, DesiredSize{ points: 16 })
	defer { k2.deinit() }

	assert k.hashcode() != k2.hashcode()
}

fn test_gridset_key_preserves_exact_font_point_bits() {
	cfg := GridSetDerivedConfig{}
	mut k := GridSetKey.init(&cfg, DesiredSize{ points: f32(12.000001) })
	defer { k.deinit() }

	mut k2 := GridSetKey.init(&cfg, DesiredSize{ points: f32(12.000002) })
	defer { k2.deinit() }

	assert k.font_size.points != k2.font_size.points
	assert k.hashcode() != k2.hashcode()
}

fn test_gridset_key_different_font_dpi() {
	cfg := GridSetDerivedConfig{}
	mut k := GridSetKey.init(&cfg, DesiredSize{ points: 12, xdpi: 1 })
	defer { k.deinit() }

	mut k2 := GridSetKey.init(&cfg, DesiredSize{ points: 12, xdpi: 2 })
	defer { k2.deinit() }

	assert k.hashcode() != k2.hashcode()
}

fn test_gridset_key_with_families() {
	// Test that keys with different font families produce different hashes.
	mut cfg1 := GridSetDerivedConfig{
		font_family: ['Fira Code']
	}
	mut cfg2 := GridSetDerivedConfig{
		font_family: ['JetBrains Mono']
	}

	mut k1 := GridSetKey.init(&cfg1, DesiredSize{ points: 12 })
	defer { k1.deinit() }
	mut k2 := GridSetKey.init(&cfg2, DesiredSize{ points: 12 })
	defer { k2.deinit() }

	assert k1.hashcode() != k2.hashcode()
}

fn test_gridset_key_descriptors_for_style() {
	cfg := GridSetDerivedConfig{
		font_family: ['Regular Font']
		font_family_bold: ['Bold Font']
		font_family_italic: ['Italic Font']
		font_family_bold_italic: ['BoldItalic Font']
	}
	k := GridSetKey.init(&cfg, DesiredSize{ points: 12 })

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
	cfg1 := GridSetDerivedConfig{
		adjust_cell_width: MetricsModifier{
			is_percent: true
			percent: 1.2
		}
	}
	cfg2 := GridSetDerivedConfig{}

	mut k1 := GridSetKey.init(&cfg1, DesiredSize{ points: 12 })
	defer { k1.deinit() }
	mut k2 := GridSetKey.init(&cfg2, DesiredSize{ points: 12 })
	defer { k2.deinit() }

	assert k1.hashcode() != k2.hashcode()
}

fn test_gridset_key_preserves_exact_metric_modifier_bits() {
	cfg1 := GridSetDerivedConfig{
		adjust_cell_width: MetricsModifier{
			is_percent: true
			percent: 1.200001
		}
	}
	cfg2 := GridSetDerivedConfig{
		adjust_cell_width: MetricsModifier{
			is_percent: true
			percent: 1.200002
		}
	}

	mut k1 := GridSetKey.init(&cfg1, DesiredSize{ points: 12 })
	defer { k1.deinit() }
	mut k2 := GridSetKey.init(&cfg2, DesiredSize{ points: 12 })
	defer { k2.deinit() }

	assert k1.hashcode() != k2.hashcode()
}

fn test_metrics_modifier_hash_ignores_inactive_payload() {
	percent1 := MetricsModifier{
		is_percent: true
		percent: 1.25
		absolute: 1
	}
	percent2 := MetricsModifier{
		is_percent: true
		percent: 1.25
		absolute: 999
	}
	assert percent1.hash() == percent2.hash()

	absolute1 := MetricsModifier{
		absolute: 3
		percent: 1.1
	}
	absolute2 := MetricsModifier{
		absolute: 3
		percent: 9.9
	}
	assert absolute1.hash() == absolute2.hash()
}

fn test_gridset_metrics_modifier_set() {
	mut set := MetricsModifierSet{}
	assert set.count() == 0

	set.put(.cell_width, MetricsModifier{ is_percent: true, percent: 1.2 })
	assert set.count() == 1

	if m := set.get(.cell_width) {
		assert m.is_percent == true
		assert m.percent == 1.2
	} else {
		assert false
	}

	assert set.get(.cell_height) == none
}

fn test_gridset_font_style_config() {
	assert GridSetFontStyleConfig{}.name_value() == none
	assert GridSetFontStyleConfig{ kind: .false_ }.name_value() == none
	assert GridSetFontStyleConfig{ kind: .name, name: 'Heavy' }.name_value()? == 'Heavy'
}

fn test_gridset_derived_config_defaults() {
	cfg := GridSetDerivedConfig{}
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

	cfg := GridSetDerivedConfig{}

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
