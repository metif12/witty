module font

fn test_metrics_apply_absolute_and_percent_modifiers() {
	mut metrics := default_grid_metrics(10, 20)
	mut modifiers := MetricsModifierSet{}
	modifiers.put(.cell_width, MetricsModifier(MetricsModifierAbsolute{ value: 2 }))
	modifiers.put(.cell_height, MetricsModifier(MetricsModifierPercent{ value: 1.5 }))
	modifiers.put(.underline_thickness, MetricsModifier(MetricsModifierAbsolute{ value: 3 }))
	modifiers.put(.icon_height, MetricsModifier(MetricsModifierPercent{ value: 0.5 }))

	metrics.apply(modifiers)

	assert metrics.cell_width == 12
	assert metrics.cell_height == 30
	assert metrics.underline_thickness == 5
	assert metrics.icon_height == 10.0
}

fn test_metrics_apply_clamps_sizes() {
	mut metrics := default_grid_metrics(10, 20)
	mut modifiers := MetricsModifierSet{}
	modifiers.put(.cell_width, MetricsModifier(MetricsModifierAbsolute{ value: -100 }))
	modifiers.put(.underline_position, MetricsModifier(MetricsModifierAbsolute{ value: -100 }))

	metrics.apply(modifiers)

	assert metrics.cell_width == 1
	assert metrics.underline_position == 0
}

// metrics_zero returns a Metrics value with all fields set to zero, matching
// ghostty's private Metrics.init() used by the Metrics tests.
fn metrics_zero() Metrics {
	return Metrics{
		cell_width: 0
		cell_height: 0
		cell_baseline: 0
		underline_position: 0
		underline_thickness: 0
		strikethrough_position: 0
		strikethrough_thickness: 0
		overline_position: 0
		overline_thickness: 0
		box_thickness: 0
		cursor_thickness: 0
		cursor_height: 0
		icon_height: 0.0
		icon_height_single: 0.0
		face_width: 0.0
		face_height: 0.0
		face_y: 0.0
	}
}

// ghostty: test "Metrics: apply modifiers"
fn test_metrics_apply_modifiers() {
	mut set := MetricsModifierSet{}
	set.put(.cell_width, MetricsModifier(MetricsModifierPercent{ value: 1.2 }))

	mut m := metrics_zero()
	m.cell_width = 100
	m.apply(set)
	assert m.cell_width == u32(120)
}

// ghostty: test "Metrics: adjust cell height smaller"
fn test_metrics_adjust_cell_height_smaller() {
	mut set := MetricsModifierSet{}
	set.put(.cell_height, MetricsModifier(MetricsModifierPercent{ value: 0.75 }))

	mut m := metrics_zero()
	m.face_y = 0.33
	m.cell_baseline = 50
	m.underline_position = 55
	m.strikethrough_position = 30
	m.overline_position = 0
	m.cell_height = 100
	m.face_height = 99.67
	m.cursor_height = 100
	m.apply(set)
	assert m.face_y == -12.67
	assert m.cell_height == u32(75)
	assert m.cell_baseline == u32(37)
	assert m.underline_position == u32(43)
	assert m.strikethrough_position == u32(18)
	assert m.overline_position == i32(-12)
	// Cursor height is separate from cell height and does not follow it.
	assert m.cursor_height == u32(100)
}

// ghostty: test "Metrics: adjust cell height larger"
fn test_metrics_adjust_cell_height_larger() {
	mut set := MetricsModifierSet{}
	set.put(.cell_height, MetricsModifier(MetricsModifierPercent{ value: 1.75 }))

	mut m := metrics_zero()
	m.face_y = 0.33
	m.cell_baseline = 50
	m.underline_position = 55
	m.strikethrough_position = 30
	m.overline_position = 0
	m.cell_height = 100
	m.face_height = 99.67
	m.cursor_height = 100
	m.apply(set)
	assert m.face_y == 37.33
	assert m.cell_height == u32(175)
	assert m.cell_baseline == u32(87)
	assert m.underline_position == u32(93)
	assert m.strikethrough_position == u32(68)
	assert m.overline_position == i32(38)
	// Cursor height is separate from cell height and does not follow it.
	assert m.cursor_height == u32(100)
}

// ghostty: test "Metrics: adjust icon height by percentage"
fn test_metrics_adjust_icon_height_by_percentage() {
	mut set := MetricsModifierSet{}
	set.put(.icon_height, MetricsModifier(MetricsModifierPercent{ value: 0.75 }))

	mut m := metrics_zero()
	m.icon_height = 100.0
	m.icon_height_single = 80.0
	m.face_height = 100.0
	m.face_y = 1.0
	m.apply(set)
	assert m.icon_height == 75.0
	assert m.icon_height_single == 60.0
	// Face metrics not affected.
	assert m.face_height == 100.0
	assert m.face_y == 1.0
}

// ghostty: test "Metrics: adjust icon height by absolute pixels"
fn test_metrics_adjust_icon_height_by_absolute_pixels() {
	mut set := MetricsModifierSet{}
	set.put(.icon_height, MetricsModifier(MetricsModifierAbsolute{ value: -5 }))

	mut m := metrics_zero()
	m.icon_height = 100.0
	m.icon_height_single = 80.0
	m.face_height = 100.0
	m.face_y = 1.0
	m.apply(set)
	assert m.icon_height == 95.0
	assert m.icon_height_single == 75.0
	// Face metrics not affected.
	assert m.face_height == 100.0
	assert m.face_y == 1.0
}

// ghostty: test "Modifier: parse absolute"
fn test_modifier_parse_absolute() {
	m1 := MetricsModifier.parse('100')!
	assert m1 is MetricsModifierAbsolute
	assert m1.value == i32(100)

	m2 := MetricsModifier.parse('-100')!
	assert m2 is MetricsModifierAbsolute
	assert m2.value == i32(-100)
}

fn test_modifier_parse_cli() {
	m := MetricsModifier.parse_cli('20%')!
	assert m is MetricsModifierPercent
	assert m.value == 1.2
	MetricsModifier.parse_cli(none) or {
		assert err.msg() == 'value required'
		return
	}
	assert false, 'expected absent CLI value to fail'
}

fn test_modifier_parse_absolute_matches_zig_i32_boundaries() {
	for input, expected in {
		'+42':        i32(42)
		'1__2':       i32(12)
		'2147483647': i32(2147483647)
		'-2147483648': i32(-2147483647 - 1)
	} {
		m := MetricsModifier.parse(input)!
		assert m is MetricsModifierAbsolute
		assert m.value == expected
	}
	for invalid in ['', '+', '-', '_1', '1_', '1x', '2147483648', '-2147483649'] {
		MetricsModifier.parse(invalid) or { continue }
		assert false, 'expected ${invalid} to fail'
	}
}

// ghostty: test "Modifier: parse percent"
fn test_modifier_parse_percent() {
	m1 := MetricsModifier.parse('20%')!
	assert m1 is MetricsModifierPercent
	assert m1.value == 1.2

	m2 := MetricsModifier.parse('-20%')!
	assert m2 is MetricsModifierPercent
	assert m2.value == 0.8

	m3 := MetricsModifier.parse('0%')!
	assert m3 is MetricsModifierPercent
	assert m3.value == 1.0

	m4 := MetricsModifier.parse('2_0%')!
	assert m4 is MetricsModifierPercent
	assert m4.value == 1.2
	m5 := MetricsModifier.parse('0x14p0%')!
	assert m5 is MetricsModifierPercent
	assert m5.value == 1.2
	if _ := MetricsModifier.parse(' 20%') {
		assert false, 'expected leading whitespace to fail'
	}
}

// ghostty: test "Modifier: percent"
fn test_modifier_percent() {
	m1 := MetricsModifier(MetricsModifierPercent{ value: 0.8 })
	assert m1.apply(u32(100)) == u32(80)

	m2 := MetricsModifier(MetricsModifierPercent{ value: 1.8 })
	assert m2.apply(u32(100)) == u32(180)
	assert m1.apply(i32(100)) == i32(80)
	assert m1.apply(f64(100)) == f64(80)
}

// ghostty: test "Modifier: absolute"
fn test_modifier_absolute() {
	m1 := MetricsModifier(MetricsModifierAbsolute{ value: -100 })
	assert m1.apply(u32(100)) == u32(0)

	m2 := MetricsModifier(MetricsModifierAbsolute{ value: -120 })
	assert m2.apply(u32(100)) == u32(0)

	m3 := MetricsModifier(MetricsModifierAbsolute{ value: 100 })
	assert m3.apply(u32(100)) == u32(200)
	assert MetricsModifier(MetricsModifierAbsolute{ value: -1 }).apply(i32(-2147483647 - 1)) == i32(-2147483647)
	assert MetricsModifier(MetricsModifierAbsolute{ value: 1 }).apply(i32(2147483647)) == i32(2147483647)
}
