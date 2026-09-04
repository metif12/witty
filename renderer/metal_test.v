module renderer

fn test_clamped_metal_surface_dimension() {
	assert clamped_metal_surface_dimension(0, 16_384) == 0
	assert clamped_metal_surface_dimension(-1, 16_384) == 0
	assert clamped_metal_surface_dimension(639.9, 16_384) == 639
	assert clamped_metal_surface_dimension(16_384, 16_384) == 16_384
	assert clamped_metal_surface_dimension(20_000, 16_384) == 16_384
	assert clamped_metal_surface_dimension(100, 0) == 0
}

fn test_metal_surface_size_without_layer_is_zero() {
	api := MetalAPI{
		max_texture_size: 16_384
	}
	width, height := api.surface_size()
	assert width == 0
	assert height == 0
}
