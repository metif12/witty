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
	assert sizeof(MetalResourceOptions) == sizeof(u64)
	managed := MetalResourceOptions.init(.write_combined, .managed, .default)
	assert managed.int_val() == 0x11
	assert managed.cpu_cache_mode() == .write_combined
	assert managed.storage_mode() == .managed
	assert managed.hazard_tracking_mode() == .default
	tracked := MetalResourceOptions.init(.default, .private, .tracked)
	assert tracked.int_val() == 0x220
	assert tracked.storage_mode() == .private
	assert tracked.hazard_tracking_mode() == .tracked
	assert MetalResourceOptions.from_int(0xffff_ffff_ffff_ffff).int_val() == 0xffff_ffff_ffff_ffff

	assert sizeof(MetalTextureUsage) == sizeof(u64)
	usage := MetalTextureUsage.from_int(0x37)
	assert usage.int_val() == 0x37
	assert usage.shader_read()
	assert usage.shader_write()
	assert usage.render_target()
	assert usage.pixel_format_view()
	assert usage.shader_atomic()
	assert MetalTextureUsage.from_int(0xffff_ffff_ffff_ffff).int_val() == 0xffff_ffff_ffff_ffff
}

fn test_metal_vertex_format_complete_source_values() {
	want := [
		u64(0),
		1,
		2,
		3,
		4,
		5,
		6,
		7,
		8,
		9,
		10,
		11,
		12,
		13,
		14,
		15,
		16,
		17,
		18,
		19,
		20,
		21,
		22,
		23,
		24,
		25,
		26,
		27,
		28,
		29,
		30,
		31,
		32,
		33,
		34,
		35,
		36,
		37,
		38,
		39,
		40,
		41,
		42,
		45,
		46,
		47,
		48,
		49,
		50,
		51,
		52,
		53,
		54,
		55,
	]
	mut got := []u64{}
	$for value in MetalVertexFormat.values {
		got << u64(value.value)
	}
	assert got == want
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
