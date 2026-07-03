module font

fn test_metrics_apply_absolute_and_percent_modifiers() {
	mut metrics := default_grid_metrics(10, 20)
	mut modifiers := MetricsModifierSet{}
	modifiers.put(.cell_width, MetricsModifier{
		absolute: 2
	})
	modifiers.put(.cell_height, MetricsModifier{
		is_percent: true
		percent:    1.5
	})
	modifiers.put(.underline_thickness, MetricsModifier{
		absolute: 3
	})
	modifiers.put(.icon_height, MetricsModifier{
		is_percent: true
		percent:    0.5
	})

	metrics.apply(modifiers)

	assert metrics.cell_width == 12
	assert metrics.cell_height == 30
	assert metrics.underline_thickness == 5
	assert metrics.icon_height == 10.0
}

fn test_metrics_apply_clamps_sizes() {
	mut metrics := default_grid_metrics(10, 20)
	mut modifiers := MetricsModifierSet{}
	modifiers.put(.cell_width, MetricsModifier{
		absolute: -100
	})
	modifiers.put(.underline_position, MetricsModifier{
		absolute: -100
	})

	metrics.apply(modifiers)

	assert metrics.cell_width == 1
	assert metrics.underline_position == 0
}

// metrics_zero returns a Metrics value with all fields set to zero, matching
// ghostty's private Metrics.init() used by the Metrics tests.
fn metrics_zero() Metrics {
	return Metrics{
		cell_width:              0
		cell_height:             0
		cell_baseline:           0
		underline_position:      0
		underline_thickness:     0
		strikethrough_position:  0
		strikethrough_thickness: 0
		overline_position:       0
		overline_thickness:      0
		box_thickness:           0
		cursor_thickness:        0
		cursor_height:           0
		icon_height:             0.0
		icon_height_single:      0.0
		face_width:              0.0
		face_height:             0.0
		face_y:                  0.0
	}
}

// ghostty: test "Metrics: apply modifiers"
fn test_metrics_apply_modifiers() {
	mut set := MetricsModifierSet{}
	set.put(.cell_width, MetricsModifier{
		is_percent: true
		percent:    1.2
	})

	mut m := metrics_zero()
	m.cell_width = 100
	m.apply(set)
	assert m.cell_width == u32(120)
}

// ghostty: test "Metrics: adjust cell height smaller"
fn test_metrics_adjust_cell_height_smaller() {
	mut set := MetricsModifierSet{}
	set.put(.cell_height, MetricsModifier{
		is_percent: true
		percent:    0.75
	})

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
	set.put(.cell_height, MetricsModifier{
		is_percent: true
		percent:    1.75
	})

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
	set.put(.icon_height, MetricsModifier{
		is_percent: true
		percent:    0.75
	})

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
	set.put(.icon_height, MetricsModifier{
		is_percent: false
		absolute:   -5
	})

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
	assert m1.is_percent == false
	assert m1.absolute == i32(100)

	m2 := MetricsModifier.parse('-100')!
	assert m2.is_percent == false
	assert m2.absolute == i32(-100)
}

// ghostty: test "Modifier: parse percent"
fn test_modifier_parse_percent() {
	m1 := MetricsModifier.parse('20%')!
	assert m1.is_percent == true
	assert m1.percent == 1.2

	m2 := MetricsModifier.parse('-20%')!
	assert m2.is_percent == true
	assert m2.percent == 0.8

	m3 := MetricsModifier.parse('0%')!
	assert m3.is_percent == true
	assert m3.percent == 1.0
}

// ghostty: test "Modifier: percent"
fn test_modifier_percent() {
	m1 := MetricsModifier{
		is_percent: true
		percent:    0.8
	}
	assert m1.apply(u32(100)) == u32(80)

	m2 := MetricsModifier{
		is_percent: true
		percent:    1.8
	}
	assert m2.apply(u32(100)) == u32(180)
}

// ghostty: test "Modifier: absolute"
fn test_modifier_absolute() {
	m1 := MetricsModifier{
		is_percent: false
		absolute:   -100
	}
	assert m1.apply(u32(100)) == u32(0)

	m2 := MetricsModifier{
		is_percent: false
		absolute:   -120
	}
	assert m2.apply(u32(100)) == u32(0)

	m3 := MetricsModifier{
		is_percent: false
		absolute:   100
	}
	assert m3.apply(u32(100)) == u32(200)
}
