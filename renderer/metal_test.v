module renderer

fn test_metal_api_enum_values_match_native_contracts() {
	assert sizeof(MetalPixelFormat) == sizeof(u64)
	assert u64(MetalPixelFormat.r8unorm) == 10
	assert u64(MetalPixelFormat.bgra8unorm) == 80
	assert u64(MetalPixelFormat.bgra8unorm_srgb) == 81

	assert sizeof(MetalGPUFamily) == sizeof(i64)
	assert i64(MetalGPUFamily.apple3) == 1003
	assert i64(MetalGPUFamily.apple10) == 1010

	assert u64(MetalVertexFormat.uchar4normalized) == 9
	assert u64(MetalVertexFormat.float) == 28
	assert u64(MetalVertexFormat.uint2) == 37
	assert sizeof(MetalVertexStepFunction) == sizeof(u64)
	assert u64(MetalVertexStepFunction.per_patch_control_point) == 4
	assert u64(MetalSamplerAddressMode.repeat) == 2
	assert u64(MetalSamplerAddressMode.mirror_repeat) == 3
	assert u64(MetalBlendFactor.source_alpha) == 4
	assert u64(MetalBlendFactor.one_minus_source_alpha) == 5
	assert u64(MetalStoreAction.custom_sample_depth_store) == 5

	assert u64(MetalCPUCacheMode.write_combined) == 1
	assert u64(MetalStorageMode.managed) == 1
	assert metal_resource_options(.write_combined, .managed) == 0x11
	assert metal_resource_options(.default, .private) == 0x20
}

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
