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

fn test_gridset_key_different_font_points() {
	cfg := GridSetDerivedConfig{}
	mut k := GridSetKey.init(&cfg, DesiredSize{ points: 12 })
	defer { k.deinit() }

	mut k2 := GridSetKey.init(&cfg, DesiredSize{ points: 16 })
	defer { k2.deinit() }

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
	assert GridSetFontStyleConfig.default_.name_value() == none
	assert GridSetFontStyleConfig.false_.name_value() == none
}

fn test_gridset_derived_config_defaults() {
	cfg := GridSetDerivedConfig{}
	assert cfg.font_family.len == 0
	assert cfg.font_synthetic_style.bold == true
	assert cfg.font_synthetic_style.italic == true
	assert cfg.freetype_load_flags.hinting == true
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
