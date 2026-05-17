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
