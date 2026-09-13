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

fn test_metal_pixel_format_complete_source_values() {
	want := [
		u64(0),
		1,
		10,
		11,
		12,
		13,
		14,
		20,
		22,
		23,
		24,
		25,
		30,
		31,
		32,
		33,
		34,
		40,
		41,
		42,
		43,
		53,
		54,
		55,
		60,
		62,
		63,
		64,
		65,
		70,
		71,
		72,
		73,
		74,
		80,
		81,
		90,
		91,
		92,
		93,
		94,
		554,
		555,
		103,
		104,
		105,
		110,
		112,
		113,
		114,
		115,
		552,
		553,
		123,
		124,
		125,
		130,
		131,
		132,
		133,
		134,
		135,
		140,
		141,
		142,
		143,
		150,
		151,
		152,
		153,
		160,
		161,
		162,
		163,
		164,
		165,
		166,
		167,
		170,
		172,
		174,
		176,
		178,
		179,
		180,
		181,
		182,
		183,
		186,
		187,
		188,
		189,
		190,
		192,
		193,
		194,
		195,
		196,
		197,
		198,
		199,
		200,
		204,
		205,
		206,
		207,
		208,
		210,
		211,
		212,
		213,
		214,
		215,
		216,
		217,
		218,
		222,
		223,
		224,
		225,
		226,
		228,
		229,
		230,
		231,
		232,
		233,
		234,
		235,
		236,
		240,
		241,
		250,
		252,
		253,
		255,
		260,
		261,
		262,
	]
	mut got := []u64{}
	$for value in MetalPixelFormat.values {
		got << u64(value.value)
	}
	assert got == want
}

fn test_metal_pixel_format_source_byte_sizes() {
	for format in [MetalPixelFormat.a8unorm, .r8unorm, .r8unorm_srgb, .r8snorm, .r8uint, .r8sint,
		.rg8unorm, .rg8unorm_srgb, .rg8snorm, .rg8uint, .rg8sint, .stencil8] {
		assert bpp_of(format) == 1
	}
	for format in [MetalPixelFormat.r16unorm, .r16snorm, .r16uint, .r16sint, .r16float, .rg16unorm,
		.rg16snorm, .rg16uint, .rg16sint, .rg16float, .b5g6r5unorm, .a1bgr5unorm, .abgr4unorm,
		.bgr5a1unorm, .depth16unorm] {
		assert bpp_of(format) == 2
	}
	for format in [MetalPixelFormat.rgba8unorm, .rgba8unorm_srgb, .rgba8snorm, .rgba8uint, .rgba8sint,
		.bgra8unorm, .bgra8unorm_srgb, .rgb10a2unorm, .rgb10a2uint, .rg11b10float, .rgb9e5float,
		.bgr10a2unorm, .bgr10_xr, .bgr10_xr_srgb, .r32uint, .r32sint, .r32float, .depth32float,
		.depth24unorm_stencil8] {
		assert bpp_of(format) == 4
	}
	for format in [MetalPixelFormat.rg32uint, .rg32sint, .rg32float, .rgba16unorm, .rgba16snorm,
		.rgba16uint, .rgba16sint, .rgba16float, .bgra10_xr, .bgra10_xr_srgb] {
		assert bpp_of(format) == 8
	}
	for format in [MetalPixelFormat.rgba32uint, .rgba32sint, .rgba32float] {
		assert bpp_of(format) == 128
	}
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
